#!/bin/bash

# Fedora
# By AnodePyxis

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Timer start
STARTTIME=$(date +%s)

# Report directory & log file setup
REPORT_DIR=~/Report
mkdir -p "$REPORT_DIR"
find "$REPORT_DIR" -type f -mtime +10 -delete
LOGFILE="$REPORT_DIR/system-maintenance-$(date +%F-%H-%M-%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOGFILE") 2>&1

notify() {
    notify-send "Fedora Care Pro" "$1"
}

echo -e "${CYAN}======================================"
echo "Fedora System Maintenance"
echo -e "        Log: $LOGFILE"
echo -e "======================================${NC}"
echo

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
    notify "$1"
}

# Capture current kernel before update
CURRENT_KERNEL=$(uname -r)

# DNF system updates
section "Updating system packages (including kernel if available)"
sudo dnf upgrade --refresh -y

# Firmware updates
section "Checking for firmware updates"
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update

# DNF distro sync (optional full system alignment)
section "Distro version alignment check"
sudo dnf distro-sync -y

# Capture installed kernel after update
LATEST_KERNEL=$(rpm -q --last kernel | head -n1 | awk '{print $1}' | sed 's/kernel-//')

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

# NodeJS updates
if command -v npm &> /dev/null; then
    section "Updating npm global packages"
    sudo npm install -g npm
    npm update -g
else
    echo -e "${YELLOW}npm not installed. Skipping...${NC}"
fi

# Cleanups
section "Removing orphaned packages"
sudo dnf autoremove -y

section "Cleaning DNF cache"
sudo dnf clean all

# Clean journal logs
section "Cleaning system logs"
sudo journalctl --vacuum-time=2weeks

# Empty trash
section "Emptying user trash"
rm -rf ~/.local/share/Trash/files/*
rm -rf ~/.local/share/Trash/info/*

# Clear thumbnail cache
section "Clearing thumbnail cache"
rm -rf ~/.cache/thumbnails/*

# DNF health check
section "Checking for broken packages"
sudo dnf check

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
sudo firewall-cmd --state
sudo firewall-cmd --list-all

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

# Installed kernels
section "Listing installed kernels"
rpm -q kernel

# Backup important configs
section "Backing up critical system configs"
BACKUP_DIR=~/SystemBackups
mkdir -p $BACKUP_DIR
cp /etc/fstab $BACKUP_DIR/fstab.backup.$(date +%F)
cp /etc/hosts $BACKUP_DIR/hosts.backup.$(date +%F)
echo -e "${GREEN}Configs backed up to $BACKUP_DIR${NC}"

# Quick ping test
section "Testing internet connectivity"
ping -c 3 8.8.8.8

# Suggest reboot if kernel updated
if [[ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ]]; then
    echo -e "${YELLOW}A new kernel was installed: $LATEST_KERNEL${NC}"
    notify "A new kernel is installed. Reboot recommended."
    echo -e "${RED}Please reboot your system to apply the new kernel.${NC}"
fi

# Timer end
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))

notify "System maintenance complete in ${RUNTIME}s"
echo -e "\n${GREEN}======================================"
echo "  All done in $RUNTIME"
echo "  Report saved to $LOGFILE"
echo -e "======================================${NC}\n"

