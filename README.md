
![program icon](https://raw.githubusercontent.com/Botspot/cloudbuddy/main/icons/cloud.png)
# CloudBuddy
Bash-based GUI client for [`rclone`](https://rclone.org/). This was written by Botspot on 7/29/2021.
![2021-07-28-204821_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127436113-56ac9a1d-2bc5-4812-b927-82d16b80565d.png)

## Installation:
[![badge](https://github.com/Botspot/pi-apps/blob/master/icons/badge.png?raw=true)](https://github.com/Botspot/pi-apps)  
### Or, to download manually:
```
git clone https://github.com/Botspot/cloudbuddy
```
CloudBuddy is portable and can be executed from anywhere on your filesystem. For simplicity, this README will assume CloudBuddy is located in your `$HOME` directory.
## First run:
```
~/cloudbuddy/main.sh
```
When running for the first time, CloudBuddy will:
- Check and install **dependencies**: `yad`, `xclip`, `expect`, `rclone`.  Note: If `rclone` is already installed with **`apt`**, consider uninstalling it so CloudBuddy can install the latest version of [`rclone` from source](https://rclone.org/downloads/).
- Add a **Main menu launcher**. (`~/.local/share/applications/cloudbuddy.desktop`) This launcher is located under the **Internet** category.
- Make sure the "**`fuse`**" kernel module has been loaded so that `rclone` can mount drives. If fuse is not loaded, CloudBuddy will attempt to load it by running `sudo modprobe fuse`. If that fails, CloudBuddy's mounting capabilities will be disabled and hidden.
- **Check for updates**. If the last local commit and the latest online commit do not match, CloudBuddy will run `git pull` and refresh the script if it was modified. Note: If you make a fork of this repository, you should change the github URL in the script to point to your repository. To disable update-checking, create a file at: `~/cloudbuddy/no-update`.

## Usage
Note: CloudBuddy is intended to be **self-explanatory**. Everything should proceed in a logical fashon and nearly all users will have no problem using this program.
But for those few users who wish to get acquainted with CloudBuddy before they try it out, **here you go.**
## Connecting to a new cloud drive
This automates the [`rclone config`](https://rclone.org/commands/rclone_config/) process. Feel free to manually run `rclone config` for more options and a wider selection of cloud storage providers. 
1. In the main window, click this button:  
![Screenshot from 2021-07-30 09-28-46](https://user-images.githubusercontent.com/54716352/127683887-ddb82be7-6db6-4f73-a0f0-9bb9b27fff4b.png)
2. Choose a name for the new cloud drive, and select which type of drive it is.  
![Screenshot from 2021-07-30 09-35-38](https://user-images.githubusercontent.com/54716352/127683918-b338f9ba-9973-4636-9ac8-6c840c6894ac.png)
3. Within seconds, a web browser will appear for authorization.  
![2021-07-30-095030_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127684335-7ab585ff-b2ff-45ea-9505-f64110e98a57.png)
4. That's it!
## Disconnecting from a cloud drive
1. In the main window, click this button:  
![Screenshot from 2021-07-30 10-04-22](https://user-images.githubusercontent.com/54716352/127684538-d8026d21-ce9f-43dd-b101-3cbe4e354e5d.png)
2. Choose a cloud drive to sign out of.  
![Screenshot from 2021-07-30 10-05-22](https://user-images.githubusercontent.com/54716352/127712410-aa9c1272-df5c-46c7-a787-3e3234a5c088.png)
3. That's it! First, this uses [`rclone config disconnect`](https://rclone.org/commands/rclone_config_disconnect/) to ask the cloud to revoke rclone's API key, then deletes the cloud drive from `rclone`'s config file using [`rclone config delete`](https://rclone.org/commands/rclone_config_delete/).
## Mounting a drive
This uses [rclone's `mount` command](https://rclone.org/commands/rclone_mount/) to view your cloud drive as if it was an external data disk.
1. In the main window, click this button:  
![Screenshot from 2021-07-30 10-12-08](https://user-images.githubusercontent.com/54716352/127685235-1efae846-d9ec-4203-b01b-f6e41b83791e.png)
2. Select a drive to continue.  
![Screenshot from 2021-07-30 10-17-07](https://user-images.githubusercontent.com/54716352/127712269-991703a1-d8f7-43d1-901d-d191f254cbd1.png)
3. Choose an empty directory to mount the cloud drive to.  
![Screenshot from 2021-07-30 10-22-20](https://user-images.githubusercontent.com/54716352/127685584-86ee15fc-6d2f-4d56-b43c-5d30ea9fb9d5.png)
4. Wait for it...  
![2021-07-30-103150_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127685725-bfc3eb94-7236-41e5-aa22-4c8a262bfbbf.png)
5. Done!
## Unmounting a drive
1. In the main window, click this button:  
![Screenshot from 2021-07-30 10-35-26](https://user-images.githubusercontent.com/54716352/127685787-d97a4c2a-27e5-419e-ad43-2c1ae822fd62.png)
2. Choose a drive to be unmounted.  
![Screenshot from 2021-07-30 10-39-19](https://user-images.githubusercontent.com/54716352/127686225-93ad674d-478f-4fed-918d-3add6a0a1bdc.png)
3. Done!
## Browsing a drive
1. In the main window, click this button:  
![Screenshot from 2021-07-30 10-41-39](https://user-images.githubusercontent.com/54716352/127687406-6382a4e8-6658-467e-abb2-688068ef0727.png)
2. Select a drive to continue.  
![Screenshot from 2021-07-30 10-17-07](https://user-images.githubusercontent.com/54716352/127712269-991703a1-d8f7-43d1-901d-d191f254cbd1.png)
3. This is CloudBuddy's built-in file browser. It exclusively uses rclone commands for navigation and all operations are performed server-side.  
![Screenshot from 2021-07-30 10-45-49](https://user-images.githubusercontent.com/54716352/127714250-17785459-cedc-4fdc-9e9b-0cf79de1357a.png)  
The file browser is capable of:  
  - **Uploading** files or folders with this handy drag-n-drop window:  
  ![Screenshot from 2021-07-30 11-04-10](https://user-images.githubusercontent.com/54716352/127687058-53d6b01c-b84a-4055-9805-fe83df54ea42.png)
  - **Downloading** the selected file(s) or folder(s) from the list to $HOME/Downloads. This takes advantage of [`rclone copy`](https://rclone.org/commands/rclone_copy/). Just look at that pretty terminal output!  
  ![2021-07-30-121153_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127688484-5a97dafc-7561-456b-a26a-ca0d5c2a9cd9.png)
  - **Moving** or **Renaming** an item. This uses [the `rclone moveto` command](https://rclone.org/commands/rclone_moveto/) - it makes an API call to the cloud drive to perform the operation so no large downloads or uploads have to occur.  
  ![Screenshot from 2021-07-30 12-17-19](https://user-images.githubusercontent.com/54716352/127690463-465ee964-08e4-427a-9798-61d3ce6fe069.png)
  - **Deleting** the selected file(s) or folder(s) from the cloud drive. This uses [`rclone purge`](https://rclone.org/commands/rclone_purge/) or [`rclone deletefile`](https://rclone.org/commands/rclone_deletefile/) commands. Keep in mind that most cloud drives will keep deleted items in a recovery folder for a while.  
  - **Creating a publically sharable link** to the selected file or folder.  
  ![Screenshot from 2021-07-30 12-40-19](https://user-images.githubusercontent.com/54716352/127691403-3da765ae-9fc1-47d2-bd49-3f32876986f6.png)  
  Notice the above **Copy** button. Because it uses `xclip` to copy the URL, CloudBuddy treats `xclip` as a required dependency.
## Web Interface
This simple button runs [rclone's built-in browser interface](https://rclone.org/gui/).  
1. In the main window, click this button:  
![Screenshot from 2021-07-30 20-51-07](https://user-images.githubusercontent.com/54716352/127725151-a9b37210-5d39-431f-8fd0-b7d1671a62ba.png)
2. A web browser should open with rclone's HTML-based interface.  
Fun fact: I (Botspot, the maker of CloudBuddy) was not aware rclone had this feature until *after* CloudBuddy was mostly complete.

And with that, the GUI usage tutorial comes to an end. If CloudBuddy was designed correctly, you didn't have to read this to use CloudBuddy.

## Command-line options
CloudBuddy is run by a single bash ***megascript***. It's not that long a script though, so why do I call it called a *mega*script?  
Because CloudBuddy's `main.sh` script is actually **many bash scripts in one**.  
When you launch CloudBuddy, it will start at the top of the script, run [a little preliminary stuff](https://github.com/Botspot/cloudbuddy#first-run) like update-checking, then ***skip*** nearly all the way to the end of the script and launch the main choice window. When you click a button, *that window will run another background instance* of CloudBuddy's `main.sh` with a command-line flag to preserve which button you clicked.  
This approach has its downsides, but it is necessary for the main window to have a button layout of **3-by-2**. Otherwise, all 6 buttons would be in one long row - which would look horrible and would prevent additional buttons from being added due to space constraints.  
Did I mention that all CloudBuddy windows use **`yad`**? This dialog box utility is the most robust GTK dialog available for bash scripting, and is the basis of [Pi-Apps](https://github.com/Botspot/pi-apps), [Pi Power Tools](https://github.com/Botspot/Pi-Power-Tools), [YouTubuddy](https://github.com/Botspot/youtubuddy), [Update Buddy](https://github.com/Botspot/update-buddy), [The TwisterOS Patcher](https://github.com/Botspot/TwistUP), and [Windows Screensavers for RPi](https://github.com/Botspot/Screensavers). YAD is not perfect though, and its inability to display multiple rows of exit-code-type buttons is a major hindrance.  
**Enough said. Command-line options for CloudBuddy are below.**  
PRO TIP: if you run CloudBuddy in a terminal, it will dynamically generate a custom-tailored command to instantly reach the exact same place later. For example, if I was using the file browser and wanted to quickly reach a deep subdirectory later, this information would be very helpful:  
![2021-07-30-133534_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127697304-cdffa962-d336-4e66-9cc7-1bfdf5ae2d50.png)  
#### Set up CloudBuddy and then exit
On every launch, CloudBuddy checks for dependencies and creates a menu launcher. To run this preliminary stuff and then exit immediately, use this command-line flag:
```
~/cloudbuddy/main.sh setup
```
#### Source CloudBuddy's functions and then exit
Necessary for when CloudBuddy is downloading or uploading something in a terminal and we want to reuse CloudBuddy's colorized-`echo` functions.
```
source ~/cloudbuddy/main.sh source
```
More functions may be added in the future, but at the time of writing this they are: `error`, `warning`, `echobright`, `echocommand`, `echoprogress`, `list_descendants`, `back`, `drivetype`, and `choosedrive`.
#### New drive
```
~/cloudbuddy/main.sh newdrive
```
Optionally, a drive name and drive type can be specified (in that order) on the command-line to skip launching the selection window.
#### Remove drive
```
~/cloudbuddy/main.sh removedrive
```
Optionally, a drive name can be specified on the command-line to skip launching the selection window.
#### Mount drive
```
~/cloudbuddy/main.sh mountdrive
```
Optionally, a drive name and mountpoint can be specified (in that order) on the command-line to skip launching the selection window.
#### Unmount drive
```
~/cloudbuddy/main.sh unmountdrive
```
Optionally, a drive name, OR a mountpoint can be specified on the command-line to skip launching the selection window.
#### Browse drive
```
~/cloudbuddy/main.sh browsedrive
```
Optionally, a drive can be specified on the command-line to skip launching the selection window. Additionally, you can specify a subfolder to begin in, like this:
```
~/cloudbuddy/main.sh browsedrive "My Google Drive:Attachments/old stuff"
```
Additionally, a simpler, faster file browser can be launched if the `fastmode` variable is set to **`1`**, like this:
```
fastmode=1 ~/cloudbuddy/main.sh browsedrive
```
#### Web Interface
```
~/cloudbuddy/main.sh webinterface
```
