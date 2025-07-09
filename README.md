# automatescripty

Aren't you guys tired of updating firmare and stuff individually all the time, and even with all the automatic updates, few of things (firmware and security) seems to be just be out of place right? Guess what! I HATE THAT problem too and so for you guys, you getting your linux system's a big automater script thingy. 

Well I am making this script for linux distributions in hopes of one to use them to automate their updates-upgrades for system, firmware, flatpak, snapd, python3, python3-pip, nodejs, etc. Also checking for security, looking for leaks and getting an overview of your entire system.

These Linux distributions include: Arch, Debian, Fedora. (The big 3 lol) Hence 3 scripts for each. Yes you can automate these scripts to run everyday at a particular time installing and using Cronie or cron, but in this I shall only provide you guys the script to use!

On the basis of these distributions (if you tend to use any subdistros of these, you can run the program that I provide)

Also please do comment and help me out of there is some problem with the scripts that I provide. I would love honest and clear feedback for this work. 

IT is in script since I don't want you know your operating system to have more bloat. 

ALSO when you start this script in terminal, it will ask you to type in your password so yeah pay attention to that before the time OUT comes into play!


🚀 Features Of This Script:

    Updates & upgrades system packages

    Updates Flatpak, Snap applications

    Updates Python (pip) and NodeJS global packages

    Performs system security audits (Lynis)

    Scans for rootkits (Rkhunter)

    Scans for potential data leaks and zombie processes

    Provides a clean system overview: disk usage, RAM, open ports, largest files, firewall status, etc.

    Generates detailed log reports in ~/Report/

    Auto-cleans logs older than 10 days


  Requirements For Each Distro: 
(Tools in brackets [ ] are optional — if you don’t have them installed, the script will just skip that part.)

     Fedora: dnf-plugins-core, libnotify, lynis, rkhunter, [python3], [python3-pip], [nodejs], [flatpak], [snapd]

     Debian: ufw, lynis, rkhunter, [python3], [python3-pip], [nodejs], [flatpak], [snapd]
     
     Arch: lynis, rkhunter, [yay], [python3], [python3-pip], [nodejs], [flatpak], [snapd]
  
  
  How to Execute this script! 
(Move the file in the home directory, since it will be easy to navigate) 


 Give Permission To Execute!
 
    chmod +x ./automatefedora.sh   # for Fedora
    chmod +x ./automatedebian.sh   # for Debian
    chmod +x ./automatearch.sh     # for Arch

NOW EXECUTE IN TERMINAL BY PUTTING THIS!

     ./automatefedora.sh



 🔒 Disclaimer
   
    I’m not responsible if you accidentally yeet your system because you ran this without reading the code.
    Always audit scripts before executing them.
