# PSO MANAGEMENT WITHIN YOUR DOMAIN

## Document goal

This document is intended to assist you in properly use each PSO accordingly to your use-case.
PSO are objects defining a password policy that can be ordered with priority (less is the weight, higher the priority is).

## PSO List

The script automatically add the following Password Strategy Objects (PSO):

```
> PSO-EmergencyAccounts-LongLive......: 5 years,  complex, 30 characters, Weight is 105.
> PSO-ServiceAccounts-Legacy..........: 5 years,  complex, 30 characters, Weight is 105.
> PSO-EmergencyAccounts-Standard......: 1 year,   complex, 30 characters, Weight is 100.
> PSO-Users-ChangeEvery3years.........: 3 year,   complex, 16 characters, Weight is 70.
> PSO-Users-ChangeEvery1year..........: 1 year,   complex, 12 characters, Weight is 60.
> PSO-Users-ChangeEvery3months........: 3 months, complex, 10 characters, Weight is 50.
> PSO-ServiceAccounts-ExtendedLife....: 3 years,  complex, 18 characters, Weight is 35.
> PSO-ServiceAccounts-Standard........: 1 year,   complex, 16 characters, Weight is 30.
> PSO-AdminAccounts-SystemPriveleged..: 6 months, complex, 14 characters, Weight is 20.
> PSO-AdminAccounts-ADdelegatedRight..: 6 months, complex, 16 characters, Weight is 15.
> PSO-ServiceAccounts-ADdelegatedRight: 1 year,   complex, 24 characters, Weight is 15.
> PSO-AdminAccounts-ADhighPrivileges..: 6 months, complex, 20 characters, Weight is 10.
```

Each PSO is linked to its corresponding Global Security Group, which is named the same (you can rename them later if you want). 
Because we are installing a brand new domain where such groups have to be protected, the item will be added in the following path:

> PSO will be added to their default Container (CN=Password Settings Container,CN=System,DC=...)
> Groups will be added to the default Users Container (CN=Users,DC=...)

Groups can be relocated anywhere you want to.

## How applying a PSO

To apply a PSO, simply add your User or Group object to the proper PSO group. 

Example:

> To add Amy SiouSoMuch to the PSO "Users change their password every year",
> add the Amy account to the group 'PSO-Users-ChangeEvery1year'.

This method allow to fine tune your password strategy. If an object belongs to more than one PSO, the one with the lower weight win.

## What about the builtin administrator account.

As this is the only account usable after a domain installation, this one will be added to the groups *PSO-EmergencyAccounts-Standard* and *PSO-AdminAccounts-ADhighPrivileges*.
This will ensure that while the account is being heavily used, the password strategy linked to it will be the most restrictive one. 
*Once you have added your own administration accounts, simply remove the account from the group PSO-AdminAccounts-ADhighPrivileges.*

## PSO Description and usage

### PSO-EmergencyAccounts-LongLive

Used to manage password strategy against Emergency Accounts when no pwd rotation are expected.
An emergency account is one type of user object that should *never* be used on the domain, except when no other administration accounts works (such as the administrator accounts from your domain).
Such accounts should be monitored and their password stored in a safe place, outside your network (best place is in a vault), with a restricted access.

### PSO-ServiceAccounts-Legacy

Used to handle legacy service accounts that could not be changed easily. 
Such accounts belongs to legacy or complex applications and thier password change is either not documented or feasable.
As the usual "time-to-live" for such applications is between 3 to 5 years, this PSO ensure that a legacy account will expire after 5 years if its paswors is not rotated during an upgrade.
Such accounts should be well documented and identified.

### PSO-EmergencyAccounts-Standard

Used to manage password strategy against Emergency Accounts when regular pwd rotation is expected. This should be your default choice for emergency accounts.

### PSO-Users-ChangeEvery3years

This strategy is dedicated to users with access to *uncritical* assets or synchronized with EntraID and using strong authentication factor on the end user system. In other term: the user never type in its password...

### PSO-USers-ChangeEvery1year

This strategy is dedicated to users with access to *uncritical* assets and not synched with EntraID.They may used WhfB to authenticated on their system, however they regularly use the password to authenticate.

### PSO-Users-ChangeEvery3months

This strategy is dedicated to AD only users with access to **critical** assets. 
This strategy should be coupled to a password change auditor tool to avoid carousel...

### PSO-ServiceAccounts-ExtendedLife

Used to handle service accounts used by application or appliance that are considered as safe.
Such account do not need to be cycle oftenly and are only kept in line with the actual password strategy from recomandation. This is oftenly the case for account use to bind to AD with no more rights than a user has.

### PSO-ServiceAccounts-Standard

Used to handle service accounts used by application or appliance.
When an application/appliance needs to work with Active Directory, an account is associated to one or more of their services. Because the appliance or system linked to this service account could be theft, a regular password cycling is needed.
*This should be your default choice regarding service account.*

### PSO-AdminAccounts-SystemPrivileged

This strategy is dedicated to accounts used to maintain system (i.e. accounts that are local admins or close to).
You should use three kinds of administration accounts (as system empowered user, as ad delegated admin user or as ad full empowered user):
> *Empowered User* are dedicated to maintain Windows Systems.
> *AD Delegated User* are kind of account that have specific authorization upon some parts of AD.
> *AD Full Empowered User* are unlimited account having full permission upon AD.

### PSO-AdminAccounts-ADdelegatedRight

This strategy is dedicated to accounts used to manage some specific AD object present in dedicated OU (i.e. accounts that inherit authorization from an AD delegation).
You should use three kinds of administration accounts (as system empowered user, as ad delegated admin user or as ad full empowered user):
> *Empowered User* are dedicated to maintain Windows Systems.
> *AD Delegated User* are kind of account that have specific authorization upon some parts of AD.
> *AD Full Empowered User* are unlimited account having full permission upon AD.

### PSO-AdminAccounts-ADhighPrivileges

This strategy is dedicated to accounts used to maintain active directory (i.e. accounts that are domain admins or close to).
You should use three kinds of administration accounts (as system empowered user, as ad delegated admin user or as ad full empowered user):
> *Empowered User* are dedicated to maintain Windows Systems.
> *AD Delegated User* are kind of account that have specific authorization upon some parts of AD.
> *AD Full Empowered User* are unlimited account having full permission upon AD.
