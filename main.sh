#!/bin/bash

set -a
DIRECTORY="$(readlink -f "$(dirname "$0")")"

error() {
  echo -e "\e[91m$1\e[39m" | sed 's|<b>||g' | sed 's|</b>||g' 1>&2
  zenity --error --width 300 --text "$(echo -e "$1" | sed 's/&/&amp;/g')"
  exit 1
}

warning() { #just like error, but doesn't exit
  echo -e "\e[91m$1\e[39m" | sed 's|<b>||g' | sed 's|</b>||g' 1>&2
  zenity --error --width 300 --text "$(echo -e "$1" | sed 's/&/&amp;/g')"
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
    echo -e "drivetype(): rclone config file not found!\nIt is: $(rclone config file)" 1>&2
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
#END OF FUNCTIONS, BEGINNING OF SCRIPT

#kill other instances of this script. Necessary for yad's --form buttons as they spawn child processes
if [ -f "${DIRECTORY}/mypid" ] ;then
  #echo -e "parent: $(cat "${DIRECTORY}/mypid")\nchildren: $(list_descendants $(cat "${DIRECTORY}/mypid"))"
  kill -s SIGHUP $(list_descendants $(cat "${DIRECTORY}/mypid")) $(cat "${DIRECTORY}/mypid") 2>/dev/null
fi

mypid=$$
echo $mypid > "${DIRECTORY}/mypid"

#install dependencies
command -v yad >/dev/null || (echo "Installing 'yad'..." ; sudo apt install -y yad || error "Failed to install yad!")
command -v xclip >/dev/null || (echo "Installing 'xclip'..." ; sudo apt install -y xclip || error "Failed to install xclip!")
command -v expect >/dev/null || (echo "Installing 'expect'..." ; sudo apt install -y expect || error "Failed to install expect!")

yadflags=(--center --title="CloudBuddy" --separator='\n' --window-icon="${DIRECTORY}/icons/cloud.png")

#generate list of remotes that rclone currently knows about
remotes="$(rclone listremotes)"

#COMMAND-LINE SUBSCRIPTS
if [ "$1" == newdrive ];then
  drive=''
  while [ -z "$drive" ];do
    drive="$(yad "${yadflags[@]}" --form \
      --field="Name of new drive: " '' \
      --button='Google Drive'!"${DIRECTORY}/icons/gdrive.png":4 \
      --button='OneDrive'!"${DIRECTORY}/icons/onedrive.png":2 \
      --button='Dropbox'!"${DIRECTORY}/icons/dropbox.png":0)"
    button=$?
    
    #Window closed some other way than the drive selection buttons, go back to start page
    [ $button != 4 ] && [ $button != 2 ] && [ $button != 0 ] && (echo "User did not choose a drive type to create. Going back..." ; break)
    
    if [ -z "$drive" ];then
      yad "${yadflags[@]}" --text="  A Drive must be given a name.  " \
        --button=OK:0 || back
    fi
  done #past this point, $output is populated and a valid drive type has been selected.
  
  if [ $button == 4 ] || [ $button == 2 ] || [ $button == 0 ];then #this will be skipped if "Going back..."
    #change button number to script-readable drive type
    drivetype="$(echo "$button" | sed s/4/gdrive/g | sed s/2/onedrive/g | sed s/0/dropbox/g)"
    
    #These expect scripts read the "drivename" environment variable.
    drivename="$drive"
    expect "${DIRECTORY}/expect-scripts/${drivetype}.exp" &
    expectpid=$!
    
    (yad "${yadflags[@]}" --button='   Cancel operation   ':0
    button=$?
    if [ $button != 0 ];then
      sleep infinity
    fi
    ) &
    yadpid=$!
    
    while true;do
      #if expect finishes, then close cancel-button window
      if [ ! -e /proc/$expectpid ];then
        kill $yadpid $(list_descendants $yadpid)
        break
      fi
      #if cancel-button window closes, then kill expect as user must have clicked 'Cancel'
      if [ ! -e /proc/$yadpid ];then
        kill $expectpid
        break
      fi
      sleep 1
    done
  fi #everything in the above if statement is skipped if $button is not 0, 2, or 4
  
elif [ "$1" == removedrive ];then
  drive="$(echo "$2" | sed 's/:$//g')"
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echo "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    drive="$(choosedrive "Choose a cloud drive to sign out of.")"
  fi
  [ -z "$drive" ] && back
  
  rclone config disconnect "$drive": || echo "Don't worry - rclone errors above this point are normal and expected for certain cloud storage providers."
  rclone config delete "$drive" #this rclone option DOES NOT ACCEPT A COLON!
  
elif [ "$1" == mountdrive ];then
  echo "Mount drive"
  #usage: main.sh mountdrive driveName /path/to/mountpoint
  drive="$(echo "$2" | sed 's/:$//g')"
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echo "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    drive="$(choosedrive)"
  fi
  [ -z "$drive" ] && back
  
  directory="$3" #attempt to mount to folder specified by command-line
  while true;do
    if [ -z "$directory" ];then
      directory="$(yad "${yadflags[@]}" --file --directory --mime-filter="Directories | inode/directory" --width=600 --height=400 \
        --text="Choose an empty directory to mount <b>$drive</b> to.")"
      [ $? != 0 ] && back
    fi
    
    if [ -z "$directory" ];then
      echo "No directory chosen!"
      yad "${yadflags[@]}" --text="No directory chosen!" --button="Try again"
    elif [ ! -d "$directory" ];then
      echo "Directory $directory does not exist!"
      yad "${yadflags[@]}" --text="No directory chosen!" --button="Try again"
    elif [ ! -z "$(ls -A "$directory")" ];then
      echo "Directory $directory contains files!"
      yad "${yadflags[@]}" --text="  Directory $directory contains files!  "$'\n'"  It <b>must</b> be empty.  " --button="Try again"
    else
      break
    fi
    directory=''
  done #past this point, a valid directory is selected that contains no files 
  
  #this will run for a minimum of 7 seconds before returning to the main window.
  sleep 7 &
  sleeppid=$!
  setsid bash -c 'errors="$(rclone mount "'"$drive"'": "'"$directory"'" 2>&1)"
    [ $? != 0 ] && warning "Rclone failed to mount <b>'"$drive"'</b> to <b>'"$directory"'</b>!'$'\n''Errors: $errors"' &
  wait $sleeppid
  
elif [ "$1" == unmountdrive ];then
  #CLI usage: main.sh unmountdrive driveName
  #Alternative CLI usage: main.sh unmountdrive /path/to/mountpoint
  mounts="$(mount | grep fuse.rclone | sed 's/ type fuse.rclone (.*)//g' | sed 's/: on /:/g')"
  
  drives="$(echo "$mounts" | sed 's/:.*//g')"
  mountdirs="$(echo "$mounts" | sed 's/.*://g')"
  #echo -e "Mounted drives: $drives\nMountdirs: $mountdirs"
  
  if [ ! -z "$2" ] && [ ! -z "$(echo "$drives" | grep -x "$(echo "$2" | sed 's/:$//g')")" ];then
    #cli-specified drive name to unmount
    mountpoint="$(echo "$mounts" | grep "$(echo "$2" | sed 's/:$//g')" | sed 's/.*://g')"
  elif [ ! -z "$2" ] && [ ! -z "$(echo "$mountdirs" | grep "$2")" ];then
    #cli-specified directory to unmount
    mountpoint="$2"
  else
    mountpoint="$(echo "$mounts" | sed 's|:|</b> mounted on <b>|g' | sed 's|^|<b>|g' | sed 's|$|</b>|g' | yad "${yadflags[@]}" --list \
    --width=430 --height=200 \
    --column='' --no-headers --text="Which drive to unmount?")" || back 
    
    #change yad output back to script-readable : only path to mount remains
    mountpoint="$(echo "$mountpoint" | sed 's|<b>||g' | sed 's|</b>||g' | sed 's/.*mounted on //g')"
  fi
  
  fusermount -u "$mountpoint" || sudo umount "$mountpoint" || error "Failed to unmount <b>$mountpoint</b>!\nErrors: $(fusermount -u "$mountpoint" 2>&1)"
  
elif [ "$1" == browsedrive ];then
  echo "Browse drive"
  #usage: main.sh browsedrive driveName prefix
  drive="$(echo "$2" | sed 's/:$//g')"
  if [ -z "$(echo "$remotes" | grep "$drive")" ];then
    echo "CLI-selected drive '$drive' does not exist."
    drive=''
  fi
  if [ -z "$drive" ];then
    drive="$(choosedrive)"
  fi
  [ -z "$drive" ] && back
  
  prefix="$3" #variable to store subfolder information for the interactive file browser
  while true;do
    (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title=Scanning \
      --text="Scanning <b>$(echo "$drive:$prefix" | sed 's/:$//g')</b>..." \
      --width=300 --height=100 --center --auto-close --auto-kill \
      --no-buttons 2>/dev/null &
    loader_pid=$!
    
    filelist="$(rclone lsf "$drive:$prefix" 2>&1)"
    
    [ $? != 0 ] && error "rclone failed to acquire a file list from <b>$drive:$prefix</b>!\nErrors: $filelist"
    kill $loader_pid #close the progress bar window
    
    filelist="$(echo "$filelist" | tac | sed 's/$/\n/g' | sed "s|/"'$'"|/\n${DIRECTORY}/icons/folder.png|g" | tac | sed -z "s|\n${DIRECTORY}/icons/folder.png|${DIRECTORY}/icons/folder.png|g" | sed -z "s|\n\n|\n${DIRECTORY}/icons/none-24.png\n|g" | sed -z "s|^\n|${DIRECTORY}/icons/none-24.png\n|g")"
    #echo "$filelist"
    
    #array of buttons to send to file browser window
    buttons=()
    if [ ! -z "$prefix" ];then
      buttons+=(--button=Back!"${DIRECTORY}/icons/back.png"!"Up one level to <b>$(echo "$drive:$(dirname "$prefix" | sed 's/^.$//g')" | sed 's/:$//g')</b>":2)
    fi
    buttons+=(--button='Add files'!"${DIRECTORY}/icons/upload.png"!"Upload files to the current folder, or into a subfolder if one is selected.":10 \
      --button=Delete!"${DIRECTORY}/icons/trash.png"!"Delete the selected file/folder. Note: most cloud drives let you recover deleted items.":8 \
      --button=Move!"${DIRECTORY}/icons/move.png"!"Move the selected file/folder to another location on this drive.":6 \
      --button=Link!"${DIRECTORY}/icons/link.png"!"Generate a link to share the selected file/folder publicly.":4)
    
    output="$(echo "$filelist" | sed 's/&/&amp;/g' | yad "${yadflags[@]}" --list --column=:IMG --column=file --no-headers --print-column=2 \
      --width=300 --height=400 --text="Double-click to open files/folders." \
     "${buttons[@]}" )"
    button=$?
    
    echo -e "Output is $output\nPrefix is $prefix"
    
    if [ $button == 2 ];then
      #back button: go up a directory in prefix.
      prefix="$(dirname "$prefix" | sed 's/^.$//g')"
    elif [ $button == 4 ];then
      #get link for selected
      if [ -z "$output" ];then
        warning "In order to generate a link, you must select a file or folder."
      else
        link="$(rclone link "$drive:$prefix$output" 2>&1)"
        exitcode=$?
        if [ $exitcode != 0 ];then
          warning "Failed to generate a link for <b>$drive:$prefix$output</b>\nErrors: $link"
        else
          yad "${yadflags[@]}" --form --columns=2 \
            --image="${DIRECTORY}/icons/$(drivetype "$drive").png" \
            --text="Public link below." \
            --field='' "$link" --field=Copy:FBTN "bash -c 'echo "\""$link"\"" | xclip -sel clip'"
        fi
      fi
    elif [ $button == 6 ];then
      #move selected
      if [ -z "$output" ];then
        warning "A file or folder must be selected in order to move it!"
      else
        moveto="$(yad "${yadflags[@]}" --form --width=400 --text="  Enter a path to move the chosen file:" \
          --field="From ":RO "$prefix$output" \
          --field="To " "$prefix$output")"
        button=$?
        
        #remove trailing and leading slashes from output, and only keep second line
        moveto="$(echo "$moveto" | grep . | sed 's|^/||g' | sed 's|/$||g' | sed -n 2p)"
        
        if [ $button == 0 ];then
          (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title="Moving..." \
            --text="Moving <b>$prefix$output</b>"$'\n'"to <b>$moveto</b>..." \
            --width=300 --height=100 --center --auto-close --auto-kill \
            --no-buttons 2>/dev/null &
          loader_pid=$!
          errors="$(rclone moveto "$drive:$prefix$output" "$drive:$moveto" 2>&1)"
          if [ $? != 0 ];then
            warning "Failed to move <b>$prefix$output</b> to <b>$moveto</b>.\nErrors: $errors"
          fi
          kill $loader_pid
        fi
      fi
    elif [ $button == 8 ];then
      #delete selected
      if [ -z "$output" ];then
        warning "A file or folder must be selected in order to delete it!"
      else
        (echo "# "; sleep 20; echo "# This is taking longer than expected to complete."; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title="Deleting..." \
          --text="Deleting <b>$drive:$prefix$output</b>..." \
          --width=300 --height=100 --center --auto-close --auto-kill \
          --no-buttons 2>/dev/null &
        loader_pid=$!
        if [[ "$output" == */ ]];then
          #if folder, delete folder
          rclone purge "$drive:$prefix$output"
        else
          rclone deletefile "$drive:$prefix$output"
        fi
        kill $loader_pid #close the progress bar window
      fi
    elif [ $button == 10 ];then
      #upload files
      if [ ! -z "$output" ] && [[ "$output" == */ ]];then
        #if folder selected, destination is prefix/output
        destinationdir="$prefix$output"
      else
        destinationdir="$prefix"
      fi
      
      output="$(yad "${yadflags[@]}" --dnd --text="  Drag-n-drop files here to upload them to <b>$(echo "$drive:$destinationdir" | sed 's/:$//g')</b>.  " \
        --button=Cancel:1 --button=Upload!"${DIRECTORY}/icons/upload.png":0)"
      button=$?
      #convert output from "file://" format to absolute paths format
      output="$(echo "$output" | sed 's|^file://||')"
      
      if [ $button == 0 ] && [ ! -z "$output" ];then
        #upload each file at a time with rclone
        "${DIRECTORY}/terminal-run" "
          output='$output'
          trap 'sleep infinity' EXIT
          IFS=$'\n'
          failed=0
          for file in "\$"output ;do
            echo '\e[7mCopying '"\"""\$"file"\""'\e[27m'
            rclone copy -P "\"""\$"file"\"" '$drive:$destinationdir' 2>&1
            exitcode=$?
            if [ "\$"exitcode != 0 ];then
              failed=1
            fi
          done
          if [ "\$"failed == 0 ];then
            echo -e '\e[102m\e[30mUpload succeeded! Close this window to exit.\e[39m\e[49m'
          else
            echo -e '\e[101m\e[30mUpload failed! Errors above.\e[39m\e[49m'
          fi
        " "Uploading $(echo "$output" | wc -l) file$([ $(echo "$output" | wc -l) != 1 ] && echo s) to $(echo "$drive:$destinationdir" | sed 's/:$//g')"
      fi
      
    elif [ $button == 0 ];then
      #open file/folder - double-clicked
      if [[ "$output" == */ ]];then
        echo "Folder selected: $(echo "$output" | sed 's|/$||g')"
        if [ ! -z $prefix ];then
          prefix="$prefix/$output"
        else
          prefix="$output"
        fi
      else
        echo "File selected: $(echo "$output")"
        
        #download file
        tmpdir="$(mktemp -d)"
        
        mypid=$$
        set -o pipefail
        (echo "# "; sleep infinity) | yad "${yadflags[@]}" --progress --pulsate --title=Downloading \
          --text="Downloading:"$'\n'"<b>$drive:$prefix$output</b>"$'\n'"To: <b>$tmpdir</b>..." \
          --width=300 --height=100 --center --auto-close --auto-kill \
          --button=Cancel:"bash -c '$0 browsedrive "\""$drive"\"" "\""$prefix"\""; kill $$ $(list_descendants $$)'" &
        loader_pid=$!
        
        errors="$(rclone copy "$drive:$prefix$output" "$tmpdir" 2>&1 | tee /dev/stderr)"
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
    else #unknown button
      break
    fi
  done #end of interactive file browser - forever loop

elif [ "$1" == webinterface ];then
  "${DIRECTORY}/terminal-run" "trap 'sleep infinity' EXIT
    echo 'rclone rcd --rc-web-gui'
    rclone rcd --rc-web-gui
    " "Running rclone web gui"
fi #END OF COMMAND-LINE subscripts

#Run main window as a child process if command-line flags were used above for a subscript. This prevents subsequent subscripts from reading invalid cli values.
if [ ! -z "$1" ];then
  back
fi

#if rclone drive mounted anywhere, display button to unmount drives
if [ ! -z "$(mount | grep fuse.rclone)" ];then
  unmountbutton=(--field="Unmount Drive"!"${DIRECTORY}/icons/eject.png"!"Unmount a cloud drive from your filesystem":FBTN "$0 unmountdrive")
fi

#if user has configured at least 1 drive, display these buttons:
if [ ! -z "$remotes" ];then
  mountbutton=(--field="Mount Drive"!"${DIRECTORY}/icons/search.png"!"Connect a cloud drive to your computer like a USB drive":FBTN "$0 mountdrive")
  browsebutton=(--field="Browse Drive"!"${DIRECTORY}/icons/browse.png"!"A simple file explorer with link creation and file-downloading support":FBTN "$0 browsedrive")
fi

yad "${yadflags[@]}" --width=400 --form --columns=2 \
  --field="New Drive"!"${DIRECTORY}/icons/new.png"!"Connect to a new cloud drive":FBTN "$0 newdrive" \
  "${mountbutton[@]}" \
  "${browsebutton[@]}" \
  --field="Remove Drive"!"${DIRECTORY}/icons/remove.png"!"Sign out of an existing cloud drive":FBTN "$0 removedrive" \
  "${unmountbutton[@]}" \
  --field="Web Interface"!"${DIRECTORY}/icons/webinterface.png"!"Launch rclone's built-in browser interface.":FBTN "$0 webinterface" \

