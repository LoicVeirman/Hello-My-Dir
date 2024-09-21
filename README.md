<img src="https://github.com/LoicVeirman/Pimp-My-Directory/assets/85032445/0dc7aeeb-04b8-4c45-8d76-804ba9799c4f" alt="repo logo" width="200"/>

# Hello My Dir!
#### Release 01.01.02.001 - *Hello My DC!*

## Important notice  
You should always update your existing HmD repository with the latest edition and run the below command to adapt your configuration file:
```PS
Invoke-HelloMyDir.ps1 -UpdateConfigFile
```  

## They talk about it (and we thanks them ;))
https://www.it-connect.fr/comment-creer-un-domaine-active-directory-respectueux-des-bonnes-pratiques-de-securite/

## Project description  
This project is specifically made for brand new directories and ease their creation with all security rules in place:
> - Remove legacy protocols/setup used by Microsoft for compliance purposes
> - Enforce the use of modern alogrithm for cyphering and authentication
> - Enforce LDAPS when a client requests a connection to your DC 
> - Enforce the default password strategy to match with modern expectation
> - Add other Domain Controllers to your secured domain

The script will automate the answer file by itself at first run, but can modify it by using the parameter *-Prepare*.
The documentation is in place in the folder "Documentation" and explain how you can run it.

## Release history
**01.01.01: Self-Signed Certificate Update**
> - the self-signed certificate now contains DC Name, DC Full-Qualified Domain Name and Domain name as cert name and alternatives.

**01.01.00: Hello My DC!**  
> - Add the ability to promote a Domain Controller in your domain.
> - Add a new group named "*LS-DELEG-DomainJoin-Extended*" intended to delegate right on computer objet at location *CN=Computers,DC-Your,DC=Domain*.
> - Add a  new user named "*DLGUSER01*" intended to join computer to the domain. The user is a member of "*LS-DELEG-DomainJoin-Extended*" and have a PSO applied on it (*PSO-ServiceAccounts-ADdelegatedRight*).
> - Set a delegation on *CN=Computers,DC-Your,DC=Domain* to allow "*LS-DELEG-DomainJoin-Extended*"'s group members to manage computer objects (domain joining).

**01.00.00: Hello My Dir!**  
> - Script creation. Allow you to create a brand new domain/forest fully secured.

## Auditing with Ping Castle and Purple Knight
While diving around the script, we have ensured that both well known AD security auditing tools will give you the maximum score you can expect right after building up your domain. 
To achieve our goal, we have tested our delivery against the below versions of their respective Community Edition:
> - Ping Castle 3.2.0.1
> - Purple Knight 4.2 

Tests were made upon Windows Servers 2016 to 2022 (English edition), and Functional Level were tested from 2008 up to 2022.

## Does it be enough for securing AD?
Certainly... Not. Well, securing AD is a journey and depend on whatever you want to do with (or associate with). 
This project is a good starting point however, but it will be up to you to maintain it at the best level.
The first two things you will have to do is:
1. Build a second Domain Controller to fulfill redondancy requirement
2. Assign to the second Domain Controller,a self-signed certificate (at least) to enable LDAPS (you can reuse the code from the function *Resolve-LDAPSrequired*). 

Then, we strongly recommend you to define a Tier Model Policy, such as the one we have built through the Harden AD project (https://hardenad.net).

Of course, you still can contact us to assist you in elaborating your brand new Active Directory: we'll be glad to help!

## Why do you create this project, when harden AD may be able to do the trick?
It's a good question. The short answer will be: *to avoid complexity*. But here's the long story...
When creating my own labs (which I do quite often), I use to run my own scripts in a specific order to create a new AD, create an OU topology, add users, groups and many more other minor things. 
Then, once everything is ready, I turn on HardenAD. It's not fun, it's a waste of time, blah blah blah... But it cools my brain when I need to rest or get angry over a piece of code.
So, let's have some fun: let's create a script that does all of this in one way! 
That's when I suddenly realized that this might also be the most effective tool we can offer the AD community for hardening the security of a default directory: by making it usable for production...

## Will you merge the two projects (*harden AD* and *Hello my Dir*) one day?
Why not? However, we are not thinking about it yet. Let's first see how this project will unfold...

## Can we use your project to build AD for our customers?
You can sell an Active Directory installation service using this project by explicitly mentioning the Harden community as the author of the latter and of the deployed model (security, etc.) and by crediting the authors of this project. By doing so, you will help improve the visibility of the community and strengthen its notoriety, which will benefit even more people for a safer AD environment!

## Any last word?
"Aaaaaargggghhhh..." - the Killing Joke.
