#!/bin/bash
# Fedora Maintenance & Security Automation Script 
# Author: Anode Pyxis 

set -euo pipefail
IFS=$'\n\t'

# ==============================
# Configuration
# ==============================
LOG_RETENTION_DAYS=10
TRASH_DAYS=14
LARGEST_FILES_COUNT=10

# Detect the real user if running via sudo
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ==============================
# Colors
# ==============================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

STARTTIME=$(date +%s)
TIMESTAMP=$(date +%F-%H-%M-%S)

# ==============================
# Root Check
# ==============================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root or with sudo privileges.${NC}"
    exit 1
fi

# ==============================
# Logging setup
# ==============================
REPORT_DIR="$REAL_HOME/Documents/Maintenance_Reports"
mkdir -p "$REPORT_DIR"
find "$REPORT_DIR" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
LOGFILE="$REPORT_DIR/fedora-maintenance-$TIMESTAMP.log"

# Standardize output to log and console
exec > >(tee -a "$LOGFILE") 2>&1

# ==============================
# Functions
# ==============================
notify() {
    # Send notification to the logged-in user's desktop
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$REAL_USER")/bus notify-send "Fedora Automate" "$1" || true
}

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
}

run_cmd() {
    echo -e "${CYAN}→ $*${NC}"
    if ! "$@"; then
        echo -e "${RED}✖ Command failed: $*${NC}" >&2
    fi
}

# ==============================
# Maintenance Tasks
# ==============================
section "Updating system packages"
CURRENT_KERNEL=$(uname -r)
run_cmd dnf upgrade --refresh -y

section "Checking for firmware updates"
run_cmd fwupdmgr refresh --force || true
run_cmd fwupdmgr get-updates || echo "No firmware updates available."
# run_cmd fwupdmgr update # Uncomment if you want this fully automated

section "Aligning DNF packages with repository"
run_cmd dnf distro-sync -y
# Get the highest versioned kernel installed
LATEST_KERNEL=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)

if command -v flatpak &>/dev/null; then
    section "Updating Flatpaks"
    run_cmd flatpak update -y
    run_cmd flatpak uninstall --unused -y
fi

if command -v snap &>/dev/null; then
    section "Updating Snaps"
    run_cmd snap refresh
fi

if command -v pip3 &>/dev/null; then
    section "Updating user pip3 packages"
    # Added --user to ensure we don't mess with system-level site-packages
    sudo -u "$REAL_USER" pip3 list --outdated --format=freeze | cut -d = -f1 | xargs -n1 sudo -u "$REAL_USER" pip3 install --upgrade || true
fi

section "Cleaning System"
run_cmd dnf autoremove -y
run_cmd dnf clean all
run_cmd journalctl --vacuum-time=2weeks

section "Emptying user trash & cache"
rm -rf "$REAL_HOME/.local/share/Trash/files/"*
rm -rf "$REAL_HOME/.local/share/Trash/info/"*
rm -rf "$REAL_HOME/.cache/thumbnails/"*

section "Finding largest files"
find / -type f -size +100M -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" \
    -printf '%s %p\n' 2>/dev/null | sort -nr | head -"$LARGEST_FILES_COUNT" | \
    awk '{print $1/1024/1024 " MB - " $2}'

section "Security & Network Status"
ZOMBIES=$(ps -eo stat,ppid,pid,cmd | grep -w 'Z' | grep -v grep || true)
[[ -z "$ZOMBIES" ]] && echo -e "${GREEN}No zombie processes found.${NC}" || echo -e "${RED}Zombies detected:${NC}\n$ZOMBIES"

run_cmd firewall-cmd --state
echo -e "${CYAN}SELinux Status:${NC} $(getenforce)"

section "Backing up critical configs"
BACKUP_DIR="$REAL_HOME/SystemBackups/$(date +%F)"
mkdir -p "$BACKUP_DIR"
cp /etc/fstab "$BACKUP_DIR/"
cp /etc/hosts "$BACKUP_DIR/"
echo -e "${GREEN}Configs backed up to $BACKUP_DIR${NC}"

# ==============================
# Hardware Health
# ==============================
section "Hardware Health"
PRIMARY_DISK=$(lsblk -no NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
if command -v smartctl &>/dev/null && [[ -n "$PRIMARY_DISK" ]]; then
    echo -e "${CYAN}Checking Disk: $PRIMARY_DISK${NC}"
    smartctl -H "$PRIMARY_DISK" | grep "test" || echo "SMART check passed"
fi

# ==============================
# Kernel reboot reminder
# ==============================
REBOOT_REQ=false
if [[ "$CURRENT_KERNEL" != *"$LATEST_KERNEL"* ]]; then
    echo -e "${RED}!!! REBOOT REQUIRED !!!${NC}"
    echo -e "${YELLOW}Current: $CURRENT_KERNEL${NC}"
    echo -e "${GREEN}Latest:  $LATEST_KERNEL${NC}"
    REBOOT_REQ=true
fi

# ==============================
# Summary
# ==============================
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))

echo -e "\n${GREEN}======================================"
echo "  ✅ All done in $RUNTIME seconds!"
echo "  📄 Log: $LOGFILE"
echo -e "======================================${NC}\n"

if [ "$REBOOT_REQ" = true ]; then
    notify "Maintenance complete. REBOOT REQUIRED."
else
    notify "Fedora maintenance completed successfully 🎉"
fi
