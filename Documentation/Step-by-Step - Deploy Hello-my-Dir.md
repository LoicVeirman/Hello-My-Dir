# Step-By-Step: Deploying Hello-my-Dir 
This procedure will guide you through the process of deploying Hello-my-Dir. 

## Step 1: planting the Seeds
+ Build your new windows server and assign it a static IP. the DNS client should be set to your final resolver, id est the ones to which your DC will forward unkown request - most oftenly a public DNS server like google's one.
+ Update your server to the latest patch from Microsoft - so to say: be up-to-date.
+ Download the latest HmD release package from github (https://github.com/LoicVeirman/Hello-My-Dir/releases)
+ Unzip the binaries to __c:\HmD__ 
+ Fire-up a powerShell console with elevated rgihts (i.e. runas admin)
+ Unblock the files by running the command:  
`get-ChildItem c:\HmD -recurse | unblock-file`  
+ Run the script once to create the setup file:  
`cd c:\HmD`  
`.\invoke-HelloMyDir.ps1`    
+ Take time to answer to each question accordingly to your need until it ends you back to the prompt.

# Step 2: blooming of a tree
+ Run the script to begin the domain installation:  
`.\invoke-helloMyDir.ps1`  
+ Press a key to confirm your will of building the new forest/domain, then wait until the script prompts you to write-down the DSRM password (do it, or do not but... You can reset it anyway).
+ Press a key once ready: the server will reboot and took some time to finalize the domain install.

# Step 3: harden the wood
+ Logon to your DC with the Builtin _Administrator_ account  
+ fire-up a powerShell console with elevated rgihts (i.e. runas admin)  
+ Run the script to begin the hardening steps:  
`.\invoke-helloMyDir.ps1`  
+ write-down the password generated for the _DLGUSER_ user account ; this account is able to join a computer to the domain if the computer object is preexisting in the _Computers_ container.  
+ job's done: you're domain is ready and hardened!  
