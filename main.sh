#!/bin/bash

set -a
DIRECTORY="$(readlink -f "$(dirname "$0")")"

error() {
  echo -e "\e[91m$1\e[39m" | sed 's|<b>|| ; |</b>||g' 1>&2
  zenity --error --width 300 --text "$(echo -e "$1" | sed 's/&/&amp;/g')"
  kill $(cat "${DIRECTORY}/mypid") $(list_descendants $(cat "${DIRECTORY}/mypid")) 2>/dev/null
  exit 1
}

errorback() {
  echo -e "\e[91m$1\e[39m" | sed 's|<b>||g' | sed 's|</b>||g' 1>&2
  zenity --error --width 300 --text "$(echo -e "$1" | sed 's/&/&amp;/g' | tr -d '<>')"
  back
}

warning() { #just like error, but doesn't exit
  echo -e "\e[91m$1\e[39m" | sed 's|<b>||g ; s|</b>||g' 1>&2
  zenity --error --width 300 --text "$(echo -e "$1" | sed 's/&/&amp;/g')"
}

#Displays something meaningful to the user that is brighter than normal output
echobright() {
  echo -e "\e[97m$@\e[39m"
}

#displays a command CloudBuddy is running.
echocommand() {
  echo -e "\e[32mRunning this command: \e[96m$@\e[39m"
}

#Yellow text with clock to display things like "Creating new drive..."
echoprogress() {
  echo -e "\e[33m🕑 $@\e[39m"
}

list_descendants() { #list descent PIDs to the given parent PID.
  #This is used to kill yad when a parent script is killed.
  #https://unix.stackexchange.com/a/124148/369481
  local children=$(ps -o pid= --ppid "$1")
  
  for pid in $children
  do
    list_descendants "$pid"
  done
  
  echo "$children"
}

back() { #handy function to go back to the main start page
  "$0" &
  kill -s SIGHUP $$
  exit 0
}

drivetype() { #determine the type of a $1-specified drive. 'gdrive', 'dropbox', 'onedrive'
  [ -z "$1" ] && error "drivetype(): requires an argument"
  
  #ordinary rclone config file location: $HOME/.config/rclone/rclone.conf
  if [ ! -f "$(rclone config file | sed -n 2p)" ];then
    warning "drivetype(): rclone config file not found!\nIt is: $(rclone config file)" 1>&2
    echo other
    return 0
  fi
  
  drivetype="$(cat "$HOME/.config/rclone/rclone.conf" | grep -x "\[$1\]" --after=1 | sed -n 2p | sed 's/type = //g' | \
    sed 's/^drive$/gdrive/g')"
  
  #rename drivetype variable to 'other' if unknown
  if [ "$drivetype" != gdrive ] && [ "$drivetype" != onedrive ] && [ "$drivetype" != dropbox ];then
    drivetype=other
  fi
  echo "$drivetype"
}

choosedrive() { #gui selector for drives
  #Variable 1 is the text prompt, if set. 
  useicons=1
  LIST=''
  if [ ! -z "$useicons" ] && [ "$useicons" == 1 ];then
    IFS=$'\n'
    for drive in $(echo "$remotes" | sed 's/:$//g') ;do
      LIST="$LIST
${DIRECTORY}/icons/$(drivetype "$drive")-24.png
$drive"
    done
    LIST="$(echo "$LIST" | grep .)"
    #echo "$LIST"
    
    echo "$LIST" | yad "${yadflags[@]}" --list \
      --width=260 --height=300 \
      --column=':IMG' --column='' --print-column=2 --no-headers --text="$([ -z "$1" ] && echo "Select a drive to continue." || echo "$1")"
  else #no icons in list - faster
    echo "$remotes" | sed 's/:$//g' | yad "${yadflags[@]}" --list \
      --width=260 --height=300 \
      --column='' --no-headers --text="Select a drive to continue."
  fi
}

#get OS architecture (32-bit or 64-bit)
if [ "$(od -An -t x1 -j 4 -N 1 "$(readlink -f /sbin/init)")" = ' 02' ];then
  arch=64
elif [ "$(od -An -t x1 -j 4 -N 1 "$(readlink -f /sbin/init)")" = ' 01' ];then
  arch=32
else
  error "Failed to detect OS CPU architecture! Something is very wrong."
fi

[ "$1" == source ] && return 0 #this script's functions can be sourced, then immediately exit, if you run 'main.sh source'
#END OF FUNCTIONS, BEGINNING OF SCRIPT

#kill other instances of this script. Necessary for yad's --form buttons as they spawn child processes
if [ -f "${DIRECTORY}/mypid" ] ;then
  #echo -e "parent: $(cat "${DIRECTORY}/mypid")\nchildren: $(list_descendants $(cat "${DIRECTORY}/mypid"))"
  kill -s SIGHUP $(cat "${DIRECTORY}/mypid") $(list_descendants $(cat "${DIRECTORY}/mypid")) 2>/dev/null
fi
mypid=$$
echo $mypid > "${DIRECTORY}/mypid"

#check for updates and auto-update if the no-update files does not exist
if [ ! -f "${DIRECTORY}/no-update" ];then
  prepwd="$(pwd)"
  cd "$DIRECTORY"
  localhash="$(git rev-parse HEAD)"
  latesthash="$(git ls-remote https://github.com/Botspot/cloudbuddy HEAD | awk '{print $1}')"
  
  if [ "$localhash" != "$latesthash" ] && [ ! -z "$latesthash" ] && [ ! -z "$localhash" ];then
    echobright "CloudBuddy is out of date. Downloading new version..."
    echobright "To prevent update checking from now on, create a file at ${DIRECTORY}/no-update"
    sleep 1
    
    #get file hash of this running script to compare it later
    oldhash="$(shasum "$0")"
    
    echobright "running 'git pull'..."
    git pull
    
    if [ "$oldhash" == "$(shasum "$0")" ];then
      #this script not modified by git pull
      echobright "git pull finished. Proceeding..."
    else
      echobright "git pull finished. Reloading script..."
      #run updated script in background
      ( "$0" "$@" ) &
      exit 0
    fi
  fi
  cd "$prepwd"
fi

#install dependencies
command -v yad >/dev/null || (echobright "Installing 'yad'..." ; sudo apt update && sudo apt install -y yad || error "Failed to install yad!")
command -v xclip >/dev/null || (echobright "Installing 'xclip'..." ; sudo apt update && sudo apt install -y xclip || error "Failed to install xclip!")
#rclone installation - if rclone command missing ------------ or if armhf rclone is installed on a 64-bit system ------------------------------- or if installed version is out of date
if ! command -v rclone >/dev/null || ([ "$arch" == 64 ] && [ "$(od -An -t x1 -j 4 -N 1 /usr/bin/rclone)" == ' 01' ]) || (version="$(cat /tmp/rclone-version >/dev/null || wget -O /tmp/rclone-version https://downloads.rclone.org/version.txt && cat /tmp/rclone-version)" && [ -s /tmp/rclone-version ] && [ "$(rclone --version | head -n1)" != "$version" ]);then
  echobright "Installing 'rclone'..."
  
  archname=arm
  if [ "$arch" == 64 ];then
    archname=arm64
  fi
  echocommand "wget https://downloads.rclone.org/rclone-current-linux-$archname.zip -O rclone-current-linux-$archname.zip"
  wget https://downloads.rclone.org/rclone-current-linux-$archname.zip -O rclone-current-linux-$archname.zip || error "Failed to download rclone from downloads.rclone.org!"
  
  echocommand "unzip -j -o -d rclone-temp rclone-current-linux-$archname.zip"
  unzip -j -o -d rclone-temp rclone-current-linux-$archname.zip || error "Failed to extract rclone-current-linux-$archname.zip"
  
  echocommand "sudo mv rclone-temp/rclone /usr/bin/rclone"
  sudo mv -f rclone-temp/rclone /usr/bin/rclone || error "Failed to move rclone binary to /usr/bin/rclone"
  echobright "sudo mv rclone-temp/rclone.1 /usr/share/man/man1/rclone.1"
  sudo mv -f rclone-temp/rclone.1 /usr/share/man/man1/rclone.1
  
  echocommand "sudo chown root: /usr/bin/rclone"
  sudo chown root: /usr/bin/rclone
  echocommand "rm -rf rclone-current-linux-$archname.zip rclone-temp"
  rm -rf rclone-current-linux-$archname.zip rclone-temp
  echobright "Rclone installation successful. Proceeding..."
fi

#check for fuse kernel module. Launch it if necessary. If still not running, set usefuse var to zero.
usefuse=1
if ! ls /sys/module | awk '{print $1}' | grep -qFx fuse ;then
  echobright "Kernel module 'fuse' not found. Attempting to load it..."
  echocommand "sudo modprobe fuse"
  sudo modprobe fuse
  
  #check again to ensure fuse module running
  if ! ls /sys/module | awk '{print $1}' | grep -qFx fuse ;then
    usefuse=0
    warning "Failed to load kernel module 'fuse'!\nAs a result, rclone cannot mount cloud drives."
  fi
fi

#menu button
if [ ! -f ~/.local/share/applications/cloudbuddy.desktop ];then
  echobright "Creating menu button..."
  mkdir -p ~/.local/share/applications
  echo "[Desktop Entry]
Name=CloudBuddy
Comment=The ultimate cloud storage manager.
Exec=$0
Icon=${DIRECTORY}/icons/cloud-square.png
Terminal=false
Type=Application
Categories=Application;Network;RemoteAccess;
StartupNotify=true" > ~/.local/share/applications/cloudbuddy.desktop
fi

if [ "$1" == setup ];then
  echo "CloudBuddy setup complete."
  exit 0
fi

if [ -d /dev/shm ];then
  #if linux kernel's RAM disk directory exists, use it for signaling
  useshm=1
else
  useshm=0
fi

yadflags=(--center --title="CloudBuddy" --separator='\n' --window-icon="${DIRECTORY}/icons/cloud-square.png")

#generate list of remotes that rclone currently knows about
remotes="$(rclone listremotes)"

#COMMAND-LINE SUBSCRIPTS
if [ "$1" == newdrive ];then
  #Usage: main.sh newdrive driveName drivetype
  echobright "New drive"
  drive="$3"
  drivetype="$2"
  
  while [ -z "$drive" ];do #skip the drive selection window if drive is cli-specified
    drive="$(yad "${yadflags[@]}" --form --no-escape \
      --field="Name of new drive: " '' \
      --button='Google Drive'!"${DIRECTORY}/icons/gdrive.png":4 \
      --button='OneDrive'!"${DIRECTORY}/icons/onedrive.png":2 \
      --button='Dropbox'!"${DIRECTORY}/icons/dropbox.png":0)"
    button=$?
    
    #If window closed some other way than the drive selection buttons, go back to start page
    if [ $button != 4 ] && [ $button != 2 ] && [ $button != 0 ];then
      echobright "User did not choose a drive type to create. Going back..."
      break
    fi
    
    if [ -z "$drive" ];then
      yad "${yadflags[@]}" --text="  A Drive must be given a name.  " \
        --button=OK:0 || back
    fi
    #change button number to script-readable drive type
    drivetype="$(echo "$button" | sed s/4/drive/g | sed s/2/onedrive/g | sed s/0/dropbox/g)"
  done #past this point, $drive is populated and a valid drive type has been selected.
  
  if [ $button == 4 ] || [ $button == 2 ] || [ $button == 0 ] || [ ! -z "$drivetype" ];then #this will be skipped if "Going back..."
    echobright "To get here from the command line, run this:\n$0 newdrive "\""$drive"\"" "\""$drivetype"\"""
    
    configfile="$((rclone config file || echo $'\n'"$HOME/.config/rclone/rclone.conf") | tail -n +2)"
    mkdir -p "$(dirname "$configfile")"
    echocommand "rclone config create "\""$drive"\"" "\""$drivetype"\"" env_auth=false >> "\""$configfile"\"""
    
    rclone config create "$drive" "$drivetype" env_auth=false >> "$configfile" &
    rclonepid=$!
    echo "$rclonepid"
    
    (yad "${yadflags[@]}" --text="A web browser should appear to authorize the connection." --button='   Cancel operation   ':0
    button=$?
    if [ $button != 0 ];then
      sleep infinity
    fi
    ) &
    yadpid=$!
    
    while true;do
      #if rclone finishes, then close cancel-button window
      if [ ! -e /proc/$rclonepid ];then
        kill $yadpid $(list_descendants $yadpid)
        break
      fi
      #if cancel-button window closes, then kill rclone as user must have clicked 'Cancel'
      if [ ! -e /proc/$yadpid ];then
        kill $rclonepid
        break
      fi
      sleep 1
    done
  fi #everything in the above if statement is skipped if $button is not 0, 2, or 4
  
elif [ "$1" == removedrive ];then
  #Usage: main.sh removedrive driveName
  echobright "Remove drive"
  drive="$(echo "$2" | sed 's/:$//g')"
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echobright "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    drive="$(choosedrive "Choose a cloud drive to sign out of.")"
  fi
  [ -z "$drive" ] && back
  
  echobright "To get here from the command line, run this:\n$0 removedrive "\""$drive"\"""
  
  echocommand "rclone config disconnect "\""$drive:"\"""
  rclone config disconnect "$drive": || echobright "Don't worry - rclone errors above this point are normal and expected for certain cloud storage providers."
  
  echocommand "rclone config delete "\""$drive"\"""
  rclone config delete "$drive" #this rclone option DOES NOT ACCEPT A COLON!
  
elif [ "$1" == mountdrive ];then
  #Usage: main.sh mountdrive driveName /path/to/mountpoint
  echobright "Mount drive"
  if [ "$usefuse" == 0 ];then
    errorback "Rclone cannot mount a drive when the 'fuse' kernel module is not loaded.\nRun this command to load the kernel module: 'sudo modprobe fuse'"
  fi
  
  drive="$(echo "$2" | sed 's/:$//g')"
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echobright "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    echo "Choosing drive..."
    drive="$(choosedrive)"
  fi
  [ -z "$drive" ] && back
  
  directory="$3" #attempt to mount to folder specified by command-line
  while true;do
    if [ -z "$directory" ];then
      echo "Choosing mountpoint..."
      directory="$(yad "${yadflags[@]}" --file --directory --mime-filter="Directories | inode/directory" --width=600 --height=400 \
        --text="Choose an empty directory to mount <b>$drive</b> to.")"
      [ $? != 0 ] && back
    fi
    
    if [ -z "$directory" ];then
      echobright "No directory chosen!"
      yad "${yadflags[@]}" --text="No directory chosen!" --button="Try again"
    elif [ ! -d "$directory" ];then
      echobright "Directory $directory does not exist!"
      yad "${yadflags[@]}" --text="No directory chosen!" --button="Try again"
    elif [ ! -z "$(ls -A "$directory")" ];then
      echobright "Directory $directory contains files!"
      yad "${yadflags[@]}" --text="  Directory $directory contains files!  "$'\n'"  It <b>must</b> be empty.  " --button="Choose another folder"
    else
      break
    fi
    directory=''
  done #past this point, a valid directory is selected that contains no files 
  
  echobright "To get here from the command line, run this:\n$0 mountdrive "\""$drive"\"" "\""$directory"\"""
  
  #this will run for a minimum of 7 seconds before returning to the main window.
  sleep 7 &
  sleeppid=$!
  (echo "# "; [ "$useshm" == 1 ] && [ "$fastmode" == 0 ] && tail -F /dev/shm/cloudbuddy_current_file || sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title=Mounting \
    --text="Mounting: <b>$drive</b>"$'\n'"To: <b>$directory</b>..." \
    --width=300 --height=100 --center --auto-close --auto-kill \
    --no-buttons 2>/dev/null &
  loader_pid=$!
  echocommand "rclone mount "\""$drive:"\"" "\""$directory"\"""
  setsid bash -c 'errors="$(rclone mount "'"$drive"'": "'"$directory"'" 2>&1)"
    [ $? != 0 ] && warning "Rclone failed to mount <b>'"$drive"'</b> to <b>'"$directory"'</b>!'$'\n''Errors: $errors"' &
  wait $sleeppid
  kill $loader_pid
  
elif [ "$1" == unmountdrive ];then
  #Usage: main.sh unmountdrive driveName, OR main.sh unmountdrive /path/to/mountpoint
  echobright "Unmount drive"
  
  if [ "$usefuse" == 0 ];then
    errorback "Rclone cannot unmount a drive when the 'fuse' kernel module is not loaded.\nRun this command to load the kernel module: 'sudo modprobe fuse'"
  fi
  
  mounts="$(mount | grep fuse.rclone | sed 's/ type fuse.rclone (.*)//g' | sed 's/: on /:/g')"
  
  drives="$(echo "$mounts" | sed 's/:.*//g')"
  mountdirs="$(echo "$mounts" | sed 's/.*://g')"
  #echobright "Mounted drives: $drives\nMountdirs: $mountdirs"
  
  if [ ! -z "$2" ] && echo "$drives" | grep -xq "$(echo "$2" | sed 's/:$//g')" ;then
    #cli-specified drive name to unmount
    mountpoint="$(echo "$mounts" | grep "$(echo "$2" | sed 's/:$//g'):" | sed 's/.*://g')"
  elif [ ! -z "$2" ] && echo "$mountdirs" | grep -q "$2" ;then
    #cli-specified directory to unmount
    mountpoint="$2"
  else
    mountpoint="$(echo "$mounts" | sed 's|:|</b> mounted on <b>|g' | sed 's|^|<b>|g' | sed 's|$|</b>|g' | yad "${yadflags[@]}" --list \
    --width=430 --height=200 \
    --column='' --no-headers --text="Which drive to unmount?")" || back 
    
    #change yad output back to script-readable: only mountpoint remains
    mountpoint="$(echo "$mountpoint" | sed 's|<b>||g' | sed 's|</b>||g' | sed 's/.*mounted on //g')"
  fi
  
  #for the terminal-usage announcement, determine what drive is associated with the mountpoint.
  drive="$(echo "$mounts" | grep ":$(echo "$mountpoint" | sed 's|/$||g')" | sed 's/:.*//g')"
  echobright "To get here from the command line, run this:\n$0 unmountdrive "\""$mountpoint"\""\nOr you could specify the drive name like this:\n$0 unmountdrive "\""$drive"\"""
  
  echocommand "fusermount -u "\""$mountpoint"\"""
  fusermount -u "$mountpoint" || (echocommand "sudo umount "\""$mountpoint"\"""; sudo umount "$mountpoint") || errorback "Failed to unmount <b>$mountpoint</b>!\nErrors: $(fusermount -u "$mountpoint" 2>&1)"
  
elif [ "$1" == browsedrive ];then
  #Usage: main.sh browsedrive driveName:prefix
  echobright "Browse drive"
  
  drive="$(echo "$2" | sed 's/:.*//g')"
  prefix="$(echo "$2" | sed 's/.*://g')" #variable to store subfolder information for the interactive file browser
  
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echo "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    drive="$(choosedrive)"
  fi
  [ -z "$drive" ] && back
  
  #CloudBuddy is equipped with two file browsers: a faster one and a slower one. The fast one has fewer bells and whistles, but it's load time is significantly shorter when dealing with hundreds of files.
  if [ -z "$fastmode" ];then
    fastmode=0 #Set fastmode=0 for more detailed file browser, set fastmode=1 for a simpler, more streamlined file browser
  fi
  
  while true;do
    
    #ensure prefix has a trailing slash. This GUI does this by design, but there is no guarantee it will be there if cli-specified.
    if [ ! -z "$prefix" ];then
      prefix="$(echo "$prefix"/ | sed 's|//$|/|g')"
    fi
    
    echobright "To get here from the command line, run this:\n$0 browsedrive "\""$(echo "$drive:$prefix" | sed 's|/$||g' | sed 's/:$//g')"\"""
    
    [ $useshm == 1 ] && echo '' > /dev/shm/cloudbuddy_current_file
    (echo "# "; [ $useshm == 1 ] && [ $fastmode == 0 ] && tail -F /dev/shm/cloudbuddy_current_file || sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title=Scanning \
      --text="Scanning <b>$(echo "$drive:$prefix" | sed 's/:$//g' | sed 's|/$||g')</b>..." \
      --width=300 --height=100 --center --auto-close --auto-kill \
      --no-buttons 2>/dev/null &
    loader_pid=$!
    
    if [ $fastmode == 0 ];then
      #get detailed information about each file in current folder.
      echocommand "rclone lsjson "\""$drive:$(echo "$prefix" | sed 's|/$||g')"\"""
      #Json format converted to parsable raw text. Example line:
      #Path=Tripod.JPG,Name=Tripod.JPG,Size=1472358,MimeType=image/jpeg,ModTime=2018-09-02T04:12:36.807Z,IsDir=false,ID=1229VLzjsD1XUm5LgdwlfoWEqwpzbWU9p
      filelist="$(rclone lsjson "$drive:$(echo "$prefix" | sed 's|/$||g')" 2>&1 | sed 's/":"/=/g' | sed 's/":/=/g' | sed 's/^{"//g' | sed 's/","/,/g' | sed 's/,"/,/g' | sed 's/"}$//g' | sed 's/},$//g' | sed 's/"},$//g' | sed 's/}$//g' | sed '/^\]$/d' | sed '/^\[$/d')"
      [ $? != 0 ] && errorback "rclone failed to acquire a file list from <b>$drive:$prefix</b>!\nErrors: $filelist"
      #echo "$filelist"
      
      #Don't kill the loading window now, kill it when list parsing is done.
      #kill $loader_pid #close the progress bar window
      
      IFS=$'\n'
      LIST=''
      for file in $filelist ;do
        #echo "File info: $file"
        
        #read in values. Unneeded values are commented out to save time
        path="$(echo "$file" | sed 's/^Path=//g' | sed 's/,Name=.*//g')"
        name="$(echo "$file" | sed 's/.*,Name=//g' | sed 's/,Size=.*//g')"
        #size="$(echo "$file" | sed 's/.*Size=//g' | sed 's/,MimeType=.*//g')"
        #mimetype="$(echo "$file" | sed 's/.*MimeType=//g' | sed 's/,ModTime=.*//g')"
        #modtime="$(echo "$file" | sed 's/.*ModTime=//g' | sed 's/,IsDir=.*//g')"
        #isdir="$(echo "$file" | sed 's/.*IsDir=//g' | sed 's/,ID=.*//g')"
        #id="$(echo "$file" | sed 's/.*ID=//g')"
        
        #to prevent commas in filenames from borking up remainder of parsing, remove Path= and Name= from $file before proceeding
        file=",,Size=$(echo "$file" | sed 's/.*,Size=//g')"
        
        #path="$(echo "$file" | awk -F, '{print $1}')"
        #name="$(echo "$file" | awk -F, '{print $2}')"
        size="$(echo "$file" | awk -F, '{print $3}')"
        mimetype="$(echo "$file" | awk -F, '{print $4}')"
        modtime="$(echo "$file" | awk -F, '{print $5}')"
        isdir="$(echo "$file" | awk -F, '{print $6}')"
        id="$(echo "$file" | awk -F, '{print $7}')"
        
        #if current file is a directory, add a trailing slash to filename
        if [ "$isdir" == 'IsDir=true' ];then
          #file="$(echo "$file" | sed 's|,Size=|/,Size=|g')"
          [ ! -z "$name" ] && name="${name}/"
          icon="${DIRECTORY}/icons/folder.png"
        else
          icon="${DIRECTORY}/icons/none-24.png"
        fi
        
        echo "# $name" >> /dev/shm/cloudbuddy_current_file
        
        #LIST="$LIST
#$icon
#$file"
        LIST="$LIST
$icon
$path
$name
$size
$mimetype
$modtime
$isdir
$id"
      #echo -e "Debug info:\nPath: $path\nName: $name\nSize: $size\nMimeType: $mimetype\nModTime: $modtime\nIsDir: $isdir\nID: $id\n"
      done
      #ABOVE THIS POINT, $LIST CONTAINS THE "XXXX=" TAKEN FROM THE JSON.
      LIST="$(echo "$LIST" | sed 's/.*=//g' | tail -n +2 | sed 's/^-1$/0/g')"
      #echo "$LIST"
      
      #Now that list parsing is done, kill the loading window.
      kill $loader_pid #close the progress bar window
      
    else #fastmode == 1
      #simpler file browser mode with less GUI features but it loads faster
      echocommand "rclone lsf "\""$drive:$(echo "$prefix" | sed 's|/$||g')"\"""
      filelist="$(rclone lsf "$drive:$(echo "$prefix" | sed 's|/$||g')" 2>&1)"
      [ $? != 0 ] && errorback "rclone failed to acquire a file list from <b>$drive:$prefix</b>!\nErrors: $filelist"
      kill $loader_pid #close the progress bar window
      filelist="$(echo "$filelist" | tac | sed 's/$/\n/g' | sed "s|/"'$'"|/\n${DIRECTORY}/icons/folder.png|g" | tac | sed -z "s|\n${DIRECTORY}/icons/folder.png|${DIRECTORY}/icons/folder.png|g" | sed -z "s|\n\n|\n${DIRECTORY}/icons/none-24.png\n|g" | sed -z "s|^\n|${DIRECTORY}/icons/none-24.png\n|g")"
      #echo "$filelist"
    fi
    
    #array of buttons to send to file browser window
    buttons=()
    if [ ! -z "$prefix" ];then
      buttons+=(--button=Back!"${DIRECTORY}/icons/back.png"!"Up one level to <b>$(echo "$drive:$(dirname "$prefix" | sed 's/^.$//g')" | sed 's/:$//g')</b>":2)
    fi
    buttons+=(--button='Add files'!"${DIRECTORY}/icons/upload.png"!"Upload files to the current folder, or into a subfolder if one is selected.":10 \
      --button=Download!"${DIRECTORY}/icons/download.png"!"Download selected item(s) to your local Downloads folder.":8 \
      --button=Move!"${DIRECTORY}/icons/move.png"!"Move the selected file/folder to another location on this drive."$'\n'"If you select multiple items, only the Delete button will be available.":6 \
      --button=Link!"${DIRECTORY}/icons/link.png"!"Generate a link to publicly share the selected file/folder.":4)
    
    if [ $fastmode == 0 ];then
      output="$(echo "$LIST" | sed 's/&/&amp;/g' | yad "${yadflags[@]}" --list --multiple --separator='\n' --title="CloudBuddy - browsing $(echo "$drive:$prefix" | sed 's/:$//g' | sed 's|/$||g')" \
        --column=:IMG --column=Name --column=echoName:HD --column=Size:SZ --column=MimeType:HD --column=ModTime --column=IsDir:HD --column=ID:HD --print-column=3 \
        --width=560 --height=400 --text="$([ ! -z "$prefix" ] && echo -e "Currently in <b>$(echo "$prefix" | sed 's|/$||g')</b>.\r")Double-click to open files/folders." \
       "${buttons[@]}" )"
      button=$?
    else
      output="$(echo "$filelist" | sed 's/&/&amp;/g' | yad "${yadflags[@]}" --list --multiple --separator='\n' \
        --column=:IMG --column=Name --print-column=2 \
        --width=300 --height=400 --text="$([ ! -z "$prefix" ] && echo -e "Currently in <b>$(echo "$prefix" | sed 's|/$||g')</b>.\r")Double-click to open files/folders." \
       "${buttons[@]}" )"
      button=$?
    fi
    
    output="$(echo "$output" | grep .)"
    echo "Prefix is $prefix, Output is '$output'"
    
    if [ $button == 2 ];then
      #back button: go up a directory in prefix.
      prefix="$(dirname "$prefix" | sed 's/^.$//g')"
    elif [ $button == 4 ] && [ ! "$(echo "$output" | wc -l)" -gt 1 ];then
      #get link for selected
      if [ -z "$output" ];then
        warning "In order to generate a link, you must select a file or folder."
      else
        (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title="CloudBuddy" \
          --text="Generating link..." \
          --width=300 --height=100 --center --auto-close --auto-kill \
          --no-buttons 2>/dev/null &
        loader_pid=$!
        echocommand "rclone link "\""$drive:$prefix$output"\"""
        link="$(rclone link "$drive:$prefix$output" 2>&1)"
        exitcode=$?
        kill $loader_pid
        if [ $exitcode != 0 ];then
          warning "Failed to generate a link for <b>$drive:$prefix$output</b>\nErrors: $link"
        else
          yad "${yadflags[@]}" --form --columns=2 --width=400 \
            --image="${DIRECTORY}/icons/$(drivetype "$drive").png" \
            --text="Public link below." \
            --field='' "$link" --field=Copy:FBTN "bash -c 'echo "\""$link"\"" | xclip -sel clip'" \
            --button=Close:0
        fi
      fi
    elif [ $button == 6 ];then
      #move selected
      if [ -z "$output" ];then
        warning "A file or folder must be selected in order to move it!"
      else
        if [ "$(echo "$output" | wc -l)" -gt 1 ];then
          #multiple items selected, only display Delete option.
          moveto="$(echo -en "$output" | yad "${yadflags[@]}" --text-info --fontname=12 --wrap \
            --width=400 --text="When multiple items are selected, only the <b>Delete</b> option is available."$'\n'"These items were selected:" \
            --button=Cancel:1 \
            --button=Delete!"${DIRECTORY}/icons/trash.png"!" Delete the selected <b>$(echo "$output" | wc -l) items</b> from the cloud."$'\n'" Note: Most cloud storage providers will save deleted items in a recovery folder. ":2)"
          button=$?
        else
          #single file/folder selected, display the usual 'Move' options.
          moveto="$(yad "${yadflags[@]}" --form --width=400 --text="  Enter a path to move the chosen file:" \
            --field="From ":RO "$prefix$(echo "$output" | sed 's|/$||g')" \
            --field="To " "$prefix$(echo "$output" | sed 's|/$||g')" \
            --button=Cancel:1 \
            --button=Delete!"${DIRECTORY}/icons/trash.png"!"Delete <b>$drive:$prefix$(echo "$output" | sed 's|/$||g')</b> from the cloud."$'\n'"Note: Most cloud storage providers will save deleted items in a recovery folder.":2 \
            --button=Move!"${DIRECTORY}/icons/move.png":0)"
          button=$?
        fi
        
        if [ $button == 0 ];then
          #move file
          
          #remove trailing and leading slashes from output, and only keep second line
          moveto="$(echo "$moveto" | grep . | sed 's|^/||g' | sed 's|/$||g' | sed -n 2p)"
          
          (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title="Moving..." \
            --text="Moving <b>$prefix$output</b>"$'\n'"to <b>$moveto</b>..." \
            --width=300 --height=100 --center --auto-close --auto-kill \
            --no-buttons 2>/dev/null &
          loader_pid=$!
          echocommand "rclone moveto "\""$drive:$prefix$output"\"" "\""$drive:$moveto"\"""
          errors="$(rclone moveto "$drive:$prefix$output" "$drive:$moveto" 2>&1)"
          if [ $? != 0 ];then
            warning "Failed to move <b>$prefix$output</b> to <b>$moveto</b>.\nErrors: $errors"
          fi
          kill $loader_pid
          
        elif [ $button == 2 ];then
          #delete file
          
          #delete every file found in $output, one at a time
          IFS=$'\n'
          for file in $output ;do
            (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title="Deleting..." \
              --text="Deleting <b>$drive:$prefix$file</b>..." \
              --width=300 --height=100 --center --auto-close --auto-kill \
              --no-buttons 2>/dev/null &
            loader_pid=$!
            if [[ "$file" == */ ]];then
              #if folder, delete folder
              echocommand "rclone purge "\""$drive:$prefix$file"\"""
              set -o pipefail
              errors="$(rclone purge "$drive:$prefix$file" 2>&1 | tee /dev/stderr)"
              exitcode=$?
            else
              echocommand "rclone deletefile "\""$drive:$prefix$file"\"""
              set -o pipefail
              errors="$(rclone deletefile "$drive:$prefix$file" 2>&1 | tee /dev/stderr)"
              exitcode=$?
            fi
            [ $exitcode != 0 ] && warning "Rclone failed to delete <b>$drive:$prefix$file</b>. Errors:\n$errors" &
            kill $loader_pid #close the progress bar window
          done
        fi
      fi
    elif [ $button == 8 ];then
      #download selected item(s)
      echo Download
      if [ -z "$output" ];then
        warning "At least one file or folder must be selected in order the Download button to do anything!"
      else
        destinationdir="$HOME/Downloads"
        
        "${DIRECTORY}/terminal-run" "
          trap 'sleep infinity' EXIT
          output="\""$output"\""
          source "\""$0"\"" source
          IFS=$'\n'
          failed=0
          for file in "\$"output ;do
            echoprogress "\""Downloading "\"""\\""\"""\""$drive:$prefix"\$"file"\"""\\""\"""\"""\""
            if [[ "\"""\$"file"\"" == */ ]];then
              #if downloading directory, create subdirectory on destination to preserve structure
              echocommand "\""rclone copy -P --stats-one-line "\"""\\""\"""\""$drive:$prefix"\$"file"\"""\\""\"""\"" "\"""\\""\"""\""$destinationdir/"\$"file"\"""\\""\"""\"""\""
              rclone copy -P --stats-one-line "\""$drive:$prefix"\$"file"\"" "\""$destinationdir/"\$"file"\""
              exitcode="\$"?
            else
              echocommand "\""rclone copy -P --stats-one-line "\"""\\""\"""\""$drive:$prefix"\$"file"\"""\\""\"""\"" "\"""\\""\"""\""$destinationdir"\"""\\""\"""\"""\""
              rclone copy -P --stats-one-line "\""$drive:$prefix"\$"file"\"" "\""$destinationdir"\""
              exitcode="\$"?
            fi
            if [ "\$"exitcode != 0 ];then
              failed=1
            fi
          done
          if [ "\$"failed == 0 ];then
            echo -e '\e[102m\e[30mDownload succeeded! Close this window to exit.\e[39m\e[49m'
          else
            echo -e '\e[101m\e[30mDownload failed! Errors above.\e[39m\e[49m'
          fi
        " "Downloading $(echo "$output" | wc -l) file$([ $(echo "$output" | wc -l) != 1 ] && echo s) to $(echo "$destinationdir" | sed "s|$HOME/|~/|g")"
      fi
    elif [ $button == 10 ] && [ ! "$(echo "$output" | wc -l)" -gt 1 ];then
      #upload files
      if [ ! -z "$output" ] && [[ "$output" == */ ]];then
        #if folder selected, destination is prefix/output
        destinationdir="$prefix$output"
      else
        destinationdir="$prefix"
      fi
      destinationdir="$(echo "$destinationdir" | sed 's|/$||g')"
      
      output="$(yad "${yadflags[@]}" --dnd --on-top --text="  Drag-n-drop files here to upload them to <b>$(echo "$drive:$destinationdir" | sed 's/:$//g')</b>.  " \
        --button=Cancel!!"Go back":1 --button=Upload!"${DIRECTORY}/icons/upload.png"!"Upload the files you have dropped onto this window":0)"
      button=$?
      #convert output from "file://" format to absolute paths format
      output="$(echo "$output" | sed 's|^file://||')"
      
      if [ $button == 0 ] && [ ! -z "$output" ];then
        #upload each file at a time with rclone
        "${DIRECTORY}/terminal-run" "
          trap 'sleep infinity' EXIT
          output="\""$output"\""
          source "\""$0"\"" source
          IFS=$'\n'
          failed=0
          for file in "\$"output ;do
            echoprogress "\""Copying "\$"file..."\""
            
            if [ -d "\"""\$"file"\"" ];then
              #if uploading directory, create subdirectory on destination to preserve structure
              echocommand rclone copy -P --stats-one-line "\"""\$"file"\"" "\""$drive:$destinationdir/"\$"(basename "\"""\$"file"\"")"\""
              rclone copy -P --stats-one-line "\"""\$"file"\"" "\""$drive:$destinationdir/"\$"(basename "\"""\$"file"\"")"\""
              exitcode="\$"?
            else
              echocommand rclone copy -P --stats-one-line "\"""\$"file"\"" "\""$drive:$destinationdir"\""
              rclone copy -P --stats-one-line "\"""\$"file"\"" "\""$drive:$destinationdir"\""
              exitcode="\$"?
            fi
            if [ "\$"exitcode != 0 ];then
              failed=1
            fi
          done
          if [ "\$"failed == 0 ];then
            echo -e '\e[102m\e[30mUpload succeeded! Close this window to exit.\e[39m\e[49m'
          else
            echo -e '\e[101m\e[30mUpload failed! Errors above.\e[39m\e[49m'
          fi
          #create yad button-box to refresh main window
          yad "\\"-"\\"-title=Refresh? --text="\""Upload complete. Refresh the file list?"\"" --width=300 --height=100 --center --on-top --focus --window-icon="\""${DIRECTORY}/icons/cloud-square.png"\"" --button=Refresh:0 && "\""$0"\"" browsedrive "\""$drive:$prefix"\""
        " "Uploading $(echo "$output" | wc -l) file$([ $(echo "$output" | wc -l) != 1 ] && echo s) to $(echo "$drive:$destinationdir" | sed 's/:$//g')"
      elif [ $button == 0 ] && [ -z "$output" ];then
        warning "No files were dropped onto the Upload window.\nAs a result, no files will be uploaded to $(echo "$drive:$destinationdir" | sed 's/:$//g')."
      fi
      
    elif [ $button == 0 ] && [ ! "$(echo "$output" | wc -l)" -gt 1 ];then
      #open file/folder - double-clicked
      if [[ "$output" == */ ]];then
        echobright "Folder selected: $(echo "$output" | sed 's|/$||g')"
        if [ ! -z $prefix ];then
          prefix="$prefix$output"
        else
          prefix="$output"
        fi
      else
        echobright "File selected: $(echo "$output")"
        
        #download file
        tmpdir="$(mktemp -d)"
        
        set -o pipefail
        (echo "# "; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title=Downloading \
          --text="Downloading:"$'\n'"<b>$drive:$prefix$output</b>"$'\n'"To: <b>$tmpdir</b>..." \
          --width=300 --height=100 --center --auto-close --auto-kill \
          --button=Cancel:"bash -c '$0 browsedrive "\""$drive"\$"(echo Ogo= | base64 -d)$prefix"\""; kill $$ $(list_descendants $$)'" &
        loader_pid=$!
        
        echocommand "rclone copy -P --stats-one-line "\""$drive:$prefix$output\""" "\""$tmpdir"\"""
        set -o pipefail
        errors="$(rclone copy -P --stats-one-line "$drive:$prefix$output" "$tmpdir" 2>&1 | tee /dev/stderr)"
        exitcode=$?
        kill $loader_pid #close the progress bar window
        
        if [ $button == 1 ];then
          true #cancel button clicked
        elif [ ! -f "$tmpdir/$output" ];then
          #check for output file existence
          warning "Rclone succeeded to download <b>$output</b>, but <b>$tmpdir/$output</b> does not exist.\nErrors: $errors"
        else
          #open file
          xdg-open "$tmpdir/$output"
        fi
      fi
    elif [ "$(echo "$output" | wc -l)" -gt 1 ] && ([ $button == 0 ] || [ $button == 4 ] || [ $button == 10 ]);then
      #multiple items selected
      warning "This button cannot work when multiple items are selected!"
    else #unknown button
      break
    fi
  done #end of interactive file browser - forever loop

elif [ "$1" == webinterface ];then
  echobright "Web Interface"
  echobright "To get here from the command line, run this:\n$0 webinterface"
  "${DIRECTORY}/terminal-run" "trap 'sleep infinity' EXIT
    source "\""$0"\"" source
    echocommand 'rclone rcd --rc-web-gui'
    rclone rcd --rc-web-gui
    " "Running Rclone Web Interface"
fi #END OF COMMAND-LINE subscripts

#Run main window as a child process if command-line flags were used above for a subscript. This prevents subsequent subscripts from reading undesired cli values.
if [ ! -z "$1" ];then
  back
fi

#if rclone drive mounted anywhere, display button to unmount drives
if [ ! -z "$(mount | grep fuse.rclone)" ] && [ "$usefuse" == 1 ];then
  unmountbutton=(--field="Unmount Drive"!"${DIRECTORY}/icons/eject.png"!"Unmount a cloud drive from your filesystem":FBTN "$0 unmountdrive")
fi

#if user has configured at least 1 drive, display these buttons:
if [ ! -z "$remotes" ];then
  if [ "$usefuse" == 1 ];then
    mountbutton=(--field="Mount Drive"!"${DIRECTORY}/icons/mount.png"!"Connect a cloud drive to your computer like a USB drive":FBTN "$0 mountdrive")
  fi
  browsebutton=(--field="Browse Drive"!"${DIRECTORY}/icons/browse.png"!"A built-in file browser to create sharable links, upload files, download files, move files, or delete files.":FBTN "$0 browsedrive")
  removebutton=(--field="Remove Drive"!"${DIRECTORY}/icons/remove.png"!"Sign out of an existing cloud drive":FBTN "$0 removedrive")
fi

yad "${yadflags[@]}" --width=400 --form --columns=2 --no-buttons \
  --field="New Drive"!"${DIRECTORY}/icons/new.png"!"Connect to a new cloud drive":FBTN "$0 newdrive" \
  "${mountbutton[@]}" \
  "${browsebutton[@]}" \
  "${removebutton[@]}" \
  "${unmountbutton[@]}" \
  --field="Web Interface"!"${DIRECTORY}/icons/webinterface.png"!"Launch rclone's built-in browser interface.":FBTN "$0 webinterface" \

