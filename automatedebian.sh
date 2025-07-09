#!/bin/bash

# Debian Automate Script by Anode Pyxis

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

STARTTIME=$(date +%s)

# Report directory & log file setup
REPORT_DIR=~/Report
mkdir -p "$REPORT_DIR"
find "$REPORT_DIR" -type f -mtime +10 -delete
LOGFILE="$REPORT_DIR/debian-maintenance-$(date +%F-%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

notify() {
    notify-send "Debian Automate" "$1"
}

echo -e "${CYAN}======================================"
echo "     Debian Automate Script by Anode Pyxis"
echo -e "        Log: $LOGFILE"
echo -e "======================================${NC}\n"

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
    notify "$1"
}

# Current kernel
CURRENT_KERNEL=$(uname -r)

# System updates
section "Updating APT packages"
sudo apt update && sudo apt full-upgrade -y

# Firmware updates
section "Installing firmware updates"
if command -v fwupdmgr &>/dev/null; then
    sudo fwupdmgr refresh
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
else
    echo -e "${YELLOW}fwupdmgr not installed. Skipping firmware updates.${NC}"
fi

# Flatpak updates
if command -v flatpak &> /dev/null; then
    section "Updating Flatpaks"
    flatpak update -y
    section "Removing unused Flatpak runtimes"
    flatpak uninstall --unused -y
fi

# Snap updates
if command -v snap &> /dev/null; then
    section "Updating Snaps"
    sudo snap refresh
fi

# Pip updates
if command -v pip3 &> /dev/null; then
    section "Updating pip3 packages"
    pip3 list --outdated --format=freeze | cut -d = -f1 | xargs -n1 pip3 install --user --upgrade
fi

# NPM global updates
if command -v npm &> /dev/null; then
    section "Updating npm global packages"
    sudo npm install -g npm
    npm update -g
fi

# Orphaned package cleanup
section "Removing unnecessary packages"
sudo apt autoremove -y
sudo apt clean

# Journal cleanup
section "Cleaning journal logs"
sudo journalctl --vacuum-time=2weeks

# Trash and thumbnails
section "Emptying user trash and thumbnails"
rm -rf ~/.local/share/Trash/files/*
rm -rf ~/.local/share/Trash/info/*
rm -rf ~/.cache/thumbnails/*

# Largest files
section "Finding largest files (Top 10)"
sudo find / -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -10 | awk '{print $1/1024/1024 " MB - " $2}'

# Zombie processes
section "Scanning for zombie processes"
ZOMBIES=$(ps -aux | grep defunct | grep -v grep)
if [ -z "$ZOMBIES" ]; then
    echo -e "${GREEN}No zombie processes found.${NC}"
else
    echo -e "${RED}Zombie processes detected:${NC}"
    echo "$ZOMBIES"
fi

# Firewall
section "Checking firewall status"
sudo ufw status verbose || echo -e "${YELLOW}UFW may not be installed or enabled.${NC}"

# Open ports
section "Listing open ports"
sudo ss -tulnp

# Disk usage
section "Checking disk usage"
df -h

# RAM usage
section "Checking memory usage"
free -h

# CPU info
section "CPU info"
lscpu

# Installed kernel
section "Installed kernel(s)"
dpkg --list | grep linux-image

# Config backups
section "Backing up critical configs"
BACKUP_DIR=~/SystemBackups
mkdir -p $BACKUP_DIR
cp /etc/fstab "$BACKUP_DIR/fstab.backup.$(date +%F)"
cp /etc/hosts "$BACKUP_DIR/hosts.backup.$(date +%F)"
echo -e "${GREEN}Configs backed up to $BACKUP_DIR${NC}"

# Ping test
section "Testing internet connectivity"
ping -c 3 8.8.8.8

# Lynis Audit
section "Running security audit with Lynis"
if command -v lynis &> /dev/null; then
    sudo lynis audit system --quiet | tee -a "$LOGFILE"
else
    echo -e "${YELLOW}Lynis not installed. Skipping audit.${NC}"
fi

# Rkhunter scan
section "Scanning for rootkits with Rkhunter"
if command -v rkhunter &> /dev/null; then
    sudo rkhunter --update
    sudo rkhunter --check --sk | tee -a "$LOGFILE"
else
    echo -e "${YELLOW}Rkhunter not installed. Skipping rootkit scan.${NC}"
fi

# Kernel change detection
NEW_KERNEL=$(uname -r)
if [[ "$CURRENT_KERNEL" != "$NEW_KERNEL" ]]; then
    echo -e "${YELLOW}Kernel change detected: $NEW_KERNEL${NC}"
    notify "New kernel installed. Reboot recommended."
    echo -e "${RED}Please reboot your system to apply kernel updates.${NC}"
fi

# Final runtime
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))

notify "Debian maintenance complete in ${RUNTIME}s 🎉"
echo -e "\n${GREEN}======================================"
echo "  All done in $RUNTIME seconds!"
echo "  Report saved to $LOGFILE"
echo -e "======================================${NC}\n"
