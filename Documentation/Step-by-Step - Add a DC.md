# Step-By-Step: adding a DC with Hello-my-Dir
This procedure will guide you through the process of adding a second DC to your domain. 

## Step 1: prepare the hole grass
+ Build your new windows server and assign it a static IP. the DNS client should be set to your running domain controller.  
+ Update your server to the latest patch from Microsoft - so to say: be up-to-date.  
+ Create a folder to your receipt the HmD files (**c:\HmD**)  

## Step 2: send your seed to the hole
+ Login to your existing DC (on which the Hello-my-Dir binaries is...).  
+ Fire-Up PowerShell (elevated or not).  
+ Copy the content of your existing **c:\HmD** to your new server (same path, but this not mandatory). The following method let you proceed to a network copy by creating a temporary network share accessible only to _DLGUSER01_ in reading mode:  
`New-SmbShare -Temporary -ReadAccess HELLO\DLGUSER01 -Path C:\HmD -Name HmD` 
+ Log back to your futur DC and fire-up powershell as administrator.  
+ Create a mount point on your system (replace the domain name with yours):  
`net use z: \\your.dc.fqdn\c$\HmD /user:DLGUSER01@hello.y.dir` 
+ When prompted, type in the DLGUSER01 password. The drive map should then succeed.  
+ Next, copy the HmD binaries from the existing DC to your server:  
`robocopy z:\ C:\HmD /MIR` 
+ Wait for the copy to end, then hunt for any error during transfert. If everything ran smoothly, unmount the drive:  
`net use z: /delete` 
+ quit powershell.  

## Step 3: A DC is born...
+ Fire-up PowerShell with admin rights (id est runas administrator).  
+ Run the script, without the specific parameter AddDC:  
`cd c:\HmD`  
`.\invoke-helloMyDir.ps1` 
+ The scripts deploys mandatory binaries, then it will prompt you to provide the password for the account _DLGUSER01_.  
+ Once the domain joining is done, the script will reboot (you have to press a key first). Wait a few minutes for the joining process to fullfill its needs...  
+ Once the reboot is done, logging back _as the domain administrator, or any other account with domain admins rights_.
+ > **beware**: if you use the builtin administrator account, you will not be logged in as a domain user if you do not specify the domain name (_administrator@hello.my.dir_ or _hello\administrator_ as login name.)  
+ Fire-up PowerShell with admin rights again (id est runas administrator).  
+ rebase yourself to c:\HmD, then run the script once more with the AddDC parameter:  
`cd c:\HmD`  
`.\invoke-helloMyDir.ps1 -addDC` 
+ Wait for the script to proceed and write-down the DSRM password when invited to do so.  
+ Press a key to let the server reboot.  

And here you are: a new DC is now present in your domain! Just reboot your primary DC or delete the HmD share as it is no more requiered.
