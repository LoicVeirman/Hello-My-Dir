# HELLO MY DIR! VERSION 01.00.00
## USER MANUAL

### Welcome!
Thank-you for joining-us in the active directory hardening journey!
We sincerly hope this code will ease your day and enforce your basic posture regarding security assessment!

With this code, you will be able to mount a new domain in a new forest and secure it by design.
The code is intended to create any kind of domain (in an existing forest as a child or an independant one), but this release
only cover the unique case of building a new forest - this is just a matter of testing before we update our code and enhance its ability to 
deliver the same in any build context!

Angry to learn how this works? Then let's go deep in details!

### Prerequesites
You must run the script on a system with .Net 4.8 and PowerShell 5.0.
The script has been tested successfully on:
> Windows Server 2022  
> Windows Server 2019  
> Windows Server 2016  

Be advise that our test on a 2012 R2 box has failed - however with some code arrangment, it should possible to run it.

### What does the script do?
First of all, let's discuss how the script will proceed. As everything in the world, any new AD domain begin with a brand new Windows Server System - so to say, a Vanilla one.

Once the script runs, it will proceed this way:
1. It will test for the presence of a file (.\Configuration\RunSetup.xml):
    > If the file is found, then the script will consider that you have provided the requiered information.  
    > If the file is missing, then the script will start by asking you question relative to your new domain build and create it.  
    > (you can update the file manually or by running again the script with the option **-Prepare**)  

2. If the file was present at step 1, then the script will check if your server is a domain member:
    > if not, then the script will proceed to the domain installation (see step 3)  
    > If yes, then the script *always* consider that the domain has just been installed on this server and proceed with hardening (see step 4).  
    > (Well, you are building a new domain, isn't it? So forcefully... Take a time about it.)  

3. Before runing the new forest installation, the script proceed with some extra checking and installation:
    > Install, if needed, the *AD-Domain-Service* windows feature and its toolset  
    > Install, if needed, the *RSAT-AD-Tools* windows feature and its toolset  
    > Install, if needed, the *RSAT-DNS-Server* windows feature and its toolset  
    > Install, if needed, the *RSAT-DFS-Mgmt-Con* windows feature and its toolset  
    > Install, if needed, the *GPMC* windows feature and its toolset  
    > Then, the script will start the forest installation.  
    > Once done, the script will display a random password generated for the Disaster Recovery Mode (write it down or change it later)
    > and ask you to press a ket before rebooting. Cofee time.

4. Once the server is ready to serve with a brand new AD on set, you'll have to login back and rerun the script. The script then detect that this is time for the hardening fest:
    > First, the script will remedy to Ping Castle alerts (S-ADRegistration, S-DC-SubnetMissing, S-PwdNeverExpires, P-RecycleBin, P-SchemaAdmin, P-UnprotectedOU, A-MinPwdLen, A-PreWin2000AuthenticatedUsers, A-LAPS-NOT-Installed,P-Delegated).  
    You can have more details on each remediation here: https://www.pingcastle.com/PingCastleFiles/ad_hc_rules_list.html  

    > Second, the script will remedy to Purple Knight alerts (Protected-Users, LDAPS-required).  
    You can find more details on the semperis web site (https://www.semperis.com/fr/ad-security-vulnerability-assessment/).  

    > Third, the script will add two new GPO to enforce some security default rules:
    >> *Default Domain Security*: replace some messy parameters from Default Domain Policy  
    >> *Default Domain Controllers Security*: replace some deadly parameters from Default Domain Controllers Policy

5. Final step, the script will ask you to perform a last reboot, which will ensure all GPOs are properly applied.

Here is it: AD secured! 

### How to run the script?
First, download the latest release from https://github.com/LoicVeirman/Hello-My-Dir.  
Then, extract the ZIP anywhere on your system - we do use to extract it to *C:\Hello-my-Dir*, but this is not mandatory.  
Fire-up a PowerShell Console (as administrator), and run the below commands (the script will be located in c:\Hello-My-Dir):  
```PS
CD C:\Hello-My-DIR
.\Invoke-HelloMyDir.ps1
```

You can run the configuration setup with the following command:
```PS
.\Invoke-HelloMyDIR.ps1 -Prepare
```
### Troubleshooting
When running, the script will always provide you with a result on each of its action:  
1. **SUCCESS**: the task has been executed as expected.  
2. **WARNING**: the task met an unexpected result, however this is not related to the code and should be review.  
3. **ERROR**: the taks failed to execute and exit abnormally.  

The logging is added to the event-viewer:  
> Open *EventVwr.msc*  
> Navigate to *Applications and Services Logs* 
> Open the log named *HelloMyDir*

Each function has its own Source, which in turn contains the output: you can then review the details of the execution. Warning and Error are equal to the output from the script, whereas Information is meant for SUCCESS.

In any case, you case create a support request in our github repository.

### To conclude
We sincerly hope this script will help non-AD expert to provide a reliable and secure AD to their teams or customers. Fell free to contact-us for any needs!