<img src="https://github.com/LoicVeirman/Pimp-My-Directory/assets/85032445/0dc7aeeb-04b8-4c45-8d76-804ba9799c4f" alt="repo logo" width="200"/>

# Hello My Dir!

This project is specifically made for brand new directories and ease their creation with all security rules in place:
> - Remove legacy protocols/setup used by Microsoft for compliance purposes
> - Enforce the use of modern alogrithm for cyphering and authentication
> - Enforce LDAPS when a client requests a connection to your DC 
> - Enforce the default password strategy to match with modern expectation

The script will automate the answer file by itself at first run, but can modify it by using the parameter *-Prepare*.
The documentation is in place in the folder "Documentation" and explain how you can run it.

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
