# automatescripty

Aren't you guys tired of updating firmare and stuff individually all the time, and even with all the automatic updates, few of things (firmware and security) seems to be just be out of place right? Guess what! I HATE THAT problem too and so for you guys, you getting your linux system's a big automater script thingy. 

Well I am making this script for linux distributions in hopes of one to use them to automate their updates-upgrades for system, firmware, flatpak, snapd, python3, python3-pip, nodejs, etc. Also checking for security, looking for leaks and getting an overview of your entire system.

These Linux distributions include: Arch, Debian, Fedora. (The big 3 lol) Hence 3 scripts for each. Yes you can automate these scripts to run everyday at a particular time installing and using Cronie or cron, but in this I shall only provide you guys the script to use!

On the basis of these distributions (if you tend to use any subdistros of these, you can run the program that I provide)

Also please do comment and help me out of there is some problem with the scripts that I provide. I would love honest and clear feedback for this work. 


ALSO when you start this script in terminal, it will ask you to type in your password so yeah pay attention to that before the time OUT comes into play!


📦 Some Features Of My Scripts 

    Updates & upgrades your system packages

    Updates Flatpak & Snap packages

    Updates Python (pip) and NodeJS packages

    Checks for security vulnerabilities

    Scans for potential data leaks

    Gives you a quick overview of your system health



  Requirements For Each Distro: 
[closed () brackets are the ones that you guys have, if you dont then when running the script make sure to just ommit the ones you dont have]

    Fedora: lynis, dnf-plugins-core, libnotify (python3, python3-pip, nodejs, flatpak, snapd)

    Debian: ufw, lynis, (python3, python3-pip, nodejs, flatpak, snapd)

    Arch: lynis, (python3, python3-pip, nodejs, flatpak, snapd, yay [if installed])



How to Execute this script! 
  
    Fedora: Get the script in the home directory, open terminal there and give it POWER to run [ chmod +x ./automatefedora.sh ]

    Debian: Get the script in the home directory, open terminal there and give it POWER to run [ chmod +x ./automatedebian.sh ]

    Arch: Get the script in the home directory, open terminal there and give it POWER to run [ chmod +x ./automatearch.sh ]

