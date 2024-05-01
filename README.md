<img src="https://github.com/LoicVeirman/Pimp-My-Directory/assets/85032445/0dc7aeeb-04b8-4c45-8d76-804ba9799c4f" alt="repo logo" width="200"/>

# Hello My Dir!

This project is specifically made for brand new directories and ease their creation with all security rules in place. It is build upon the Harden AD project and tailored in a way where:
> - You can create your own OU topology, based on the hAD model
> - You can automate the administrative accounts creation
> - You can automate the groups creation used to manage your IT services
> - You can automate the users creation used by your company 

The script will automate the answer file by itself but it will **not** be compliant with the *tasksSequence_HardenAD.xml* file - so do not switch them ;)

## Why do you create this project, when harden AD may be able to do the trick?
It's a good question. The short answer will be: *to avoid complexity*. But here's the long story...
When creating my own labs (which I do quite often), I use to run my own scripts in a specific order to create a new AD, create an OR topology, add users, groups and many more. other minor things. 
Then, once everything is ready, I turn on HardenAD. It's not fun, it's a waste of time, blah blah blah... But it cools my brain when I need to rest or get angry over a piece of code.
So, let's have some fun: let's create a script that does all of this in one way! 
That's when I suddenly realized that this might also be the most effective tool we can offer the AD community for hardening the security of a default directory: by making it usable for production...

## Will you merge the two projects (*harden AD* and *Hello my Dir*) one day?
Why not? However, we are not thinking about it yet. Let's first see how this project will unfold...

## Can we use your project to build AD for our customers?
you can sell an Active Directory installation service using this project by explicitly mentioning the Harden community as the author of the latter and of the deployed model (security, etc.) and by crediting the authors of this project. 
By doing so, you will help improve the visibility of the community and strengthen its notoriety, which will benefit even more people for a safer AD environment!
