![program icon](https://raw.githubusercontent.com/Botspot/cloudbuddy/main/icons/cloud.png)
# CloudBuddy
Bash-based GUI client for [`rclone`](https://rclone.org/). This was written by Botspot on 7/29/2021.
![2021-07-28-204821_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127436113-56ac9a1d-2bc5-4812-b927-82d16b80565d.png)

## Installation:
**Download**
```
git clone https://github.com/Botspot/cloudbuddy
```
## First run:
```
~/cloudbuddy/main.sh
```
When running for the first time, CloudBuddy will:
- Check and install **dependencies**: `yad`, `xclip`, `expect`, `rclone`.  Note: If `rclone` is already installed with **`apt`**, consider uninstalling it so CloudBuddy can install the **latest version** of `rclone` [from source](https://rclone.org/downloads/).
- 
When running for the first time, CloudBuddy will add a launcher to the Main Menu. (`~/.local/share/applications/cloudbuddy.desktop`)  
Assuming `rclone` has not been configured with any remotes, CloudBuddy will display these buttons:  
![2021-07-29-152600_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127561081-23ef3f79-a711-448a-b0cf-d1a6525b03f8.png)  
If `rclone` is aware of one or more remotes, CloudBuddy will display these buttons:  
![2021-07-29-153643_1366x768_scrot](https://user-images.githubusercontent.com/54716352/127562358-b200238d-b873-4849-b111-671698553bb7.png)

