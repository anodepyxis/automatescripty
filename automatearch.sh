#!/bin/bash

# Arch Automate Script
# By Anode Pyxis

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

STARTTIME=$(date +%s)

# Report folder setup
REPORT_DIR=~/Report
mkdir -p "$REPORT_DIR"
find "$REPORT_DIR" -type f -mtime +10 -delete
LOGFILE="$REPORT_DIR/arch-maintenance-$(date +%F-%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

notify() {
    notify-send "Arch Automate Script" "$1"
}

echo -e "${CYAN}======================================"
echo "Arch Automate Scirpt Shall Begin"
echo -e "        Log: $LOGFILE"
echo -e "======================================${NC}\n"

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
    notify "$1"
}

# Record current kernel
CURRENT_KERNEL=$(uname -r)

# System package updates
section "Updating system packages (pacman)"
sudo pacman -Syu --noconfirm

# AUR package updates (if yay/paru)
if command -v paru &> /dev/null; then
    section "Updating AUR packages (paru)"
    paru -Syu --noconfirm
elif command -v yay &> /dev/null; then
    section "Updating AUR packages (yay)"
    yay -Syu --noconfirm
else
    echo -e "${YELLOW}No AUR helper (paru/yay) found. Skipping AUR updates.${NC}"
fi

# Firmware updates
section "Checking for firmware updates"
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update

# Flatpak updates
if command -v flatpak &> /dev/null; then
    section "Updating Flatpaks"
    flatpak update -y

    section "Removing unused Flatpak runtimes"
    flatpak uninstall --unused -y
else
    echo -e "${YELLOW}Flatpak not installed. Skipping...${NC}"
fi

# Snap updates
if command -v snap &> /dev/null; then
    section "Updating Snaps"
    sudo snap refresh
else
    echo -e "${YELLOW}Snap not installed. Skipping...${NC}"
fi

# Pip updates
if command -v pip3 &> /dev/null; then
    section "Updating pip3 packages"
    pip3 list --outdated --format=freeze | cut -d = -f1 | xargs -n1 pip3 install --user --upgrade
else
    echo -e "${YELLOW}pip3 not installed. Skipping...${NC}"
fi

# NPM global updates
if command -v npm &> /dev/null; then
    section "Updating npm global packages"
    sudo npm install -g npm
    npm update -g
else
    echo -e "${YELLOW}npm not installed. Skipping...${NC}"
fi

# Clear pacman cache
section "Cleaning pacman cache"
sudo paccache -r

# Clear journal logs
section "Cleaning system logs"
sudo journalctl --vacuum-time=2weeks

# Empty trash
section "Emptying user trash"
rm -rf ~/.local/share/Trash/files/*
rm -rf ~/.local/share/Trash/info/*

# Largest files report
section "Finding largest files (Top 10)"
sudo find / -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -10 | awk '{print $1/1024/1024 " MB - " $2}'

# Zombie processes scan
section "Scanning for zombie processes"
ZOMBIES=$(ps -aux | grep defunct | grep -v grep)
if [ -z "$ZOMBIES" ]; then
    echo -e "${GREEN}No zombie processes found.${NC}"
else
    echo -e "${RED}Zombie processes detected:${NC}"
    echo "$ZOMBIES"
fi

# Firewall status
section "Checking firewall status"
sudo systemctl status firewalld || echo -e "${YELLOW}firewalld service not running.${NC}"
sudo firewall-cmd --state || echo -e "${YELLOW}Firewall not active.${NC}"

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

# Installed kernels (only one normally on Arch, but confirm)
section "Installed kernels"
pacman -Q linux linux-lts || echo -e "${YELLOW}Kernel package names may differ.${NC}"

# Backup fstab and hosts
section "Backing up system configs"
BACKUP_DIR=~/SystemBackups
mkdir -p "$BACKUP_DIR"
cp /etc/fstab "$BACKUP_DIR/fstab.backup.$(date +%F)"
cp /etc/hosts "$BACKUP_DIR/hosts.backup.$(date +%F)"
echo -e "${GREEN}Configs backed up to $BACKUP_DIR${NC}"

# Quick ping test
section "Testing internet connectivity"
ping -c 3 8.8.8.8

# Check if kernel changed and suggest reboot
NEW_KERNEL=$(uname -r)
if [[ "$CURRENT_KERNEL" != "$NEW_KERNEL" ]]; then
    echo -e "${YELLOW}A new kernel was installed. Current: $CURRENT_KERNEL, New: $NEW_KERNEL${NC}"
    notify "New kernel installed — reboot recommended."
    echo -e "${RED}Please reboot your system to apply the new kernel.${NC}"
fi

# Timer end
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))

notify "Arch maintenance complete in ${RUNTIME}s"
echo -e "\n${GREEN}======================================"
echo "  All done in $RUNTIME seconds!"
echo "  Report saved to $LOGFILE"
echo -e "======================================${NC}\n"
