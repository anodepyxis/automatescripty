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
# Logging setup
# ==============================
REPORT_DIR=~/Report
mkdir -p "$REPORT_DIR"
find "$REPORT_DIR" -type f -mtime +$LOG_RETENTION_DAYS -delete
LOGFILE="$REPORT_DIR/fedora-maintenance-$TIMESTAMP.log"
exec > >(tee -a "$LOGFILE") 2>&1

# ==============================
# Functions
# ==============================
notify() {
    notify-send "Fedora Automate" "$1" || true
}

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
    notify "$1"
}

run_cmd() {
    echo -e "${CYAN}→ $*${NC}"
    if ! "$@"; then
        echo -e "${RED}✖ Command failed: $*${NC}" >&2
    fi
}

# ==============================
# Root Check
# ==============================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root or with sudo privileges.${NC}"
    exit 1
fi

# ==============================
# Maintenance Tasks
# ==============================
section "Updating system packages"
CURRENT_KERNEL=$(uname -r)
run_cmd dnf upgrade --refresh -y

section "Checking for firmware updates"
run_cmd fwupdmgr refresh
run_cmd fwupdmgr get-updates
run_cmd fwupdmgr update

section "Aligning DNF packages with repository"
run_cmd dnf distro-sync -y
LATEST_KERNEL=$(rpm -q --last kernel | head -n1 | awk '{print $1}' | sed 's/kernel-//')

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
    section "Updating pip3 packages"
    pip3 list --outdated --format=freeze | cut -d = -f1 | xargs -n1 pip3 install --user --upgrade || true
fi

if command -v npm &>/dev/null; then
    section "Updating npm global packages"
    run_cmd npm install -g npm
    run_cmd npm update -g
fi

section "Removing orphaned packages"
run_cmd dnf autoremove -y

section "Cleaning DNF cache"
run_cmd dnf clean all

section "Cleaning old system logs"
run_cmd journalctl --vacuum-time=2weeks

section "Emptying user trash"
rm -rf ~/.local/share/Trash/{files,info}/*

section "Clearing thumbnail cache"
rm -rf ~/.cache/thumbnails/*

section "Checking for broken packages"
run_cmd dnf check

section "Finding largest files"
sudo find / -type f -size +100M -not -path "/proc/*" -not -path "/sys/*" \
    -printf '%s %p\n' 2>/dev/null | sort -nr | head -$LARGEST_FILES_COUNT | \
    awk '{print $1/1024/1024 " MB - " $2}'

section "Checking for zombie processes"
ZOMBIES=$(ps -eo stat,ppid,pid,cmd | grep -w 'Z')
[[ -z "$ZOMBIES" ]] && echo -e "${GREEN}No zombie processes found.${NC}" || echo -e "${RED}Zombie processes detected:${NC}\n$ZOMBIES"

section "Firewall status"
run_cmd firewall-cmd --state
run_cmd firewall-cmd --list-all

section "Listing open ports"
run_cmd ss -tulnp

section "Disk usage"
df -h

section "Memory usage"
free -h

section "CPU info"
lscpu

section "Installed kernels"
rpm -q kernel

section "Backing up critical configs"
BACKUP_DIR=~/SystemBackups
mkdir -p "$BACKUP_DIR"
cp /etc/fstab "$BACKUP_DIR/fstab.backup.$(date +%F)"
cp /etc/hosts "$BACKUP_DIR/hosts.backup.$(date +%F)"
echo -e "${GREEN}Configs backed up to $BACKUP_DIR${NC}"

section "Testing internet connectivity"
run_cmd ping -c 3 8.8.8.8

section "Running security audit (Lynis)"
if command -v lynis &>/dev/null; then
    run_cmd lynis audit system --quiet
else
    echo -e "${YELLOW}Lynis not installed. Install with: sudo dnf install lynis${NC}"
fi

section "Rootkit scan (Rkhunter)"
if command -v rkhunter &>/dev/null; then
    run_cmd rkhunter --update
    run_cmd rkhunter --check --sk
else
    echo -e "${YELLOW}Rkhunter not installed. Install with: sudo dnf install rkhunter${NC}"
fi

# ==============================
# 2 - Hardware Health & Monitoring
# ==============================
section "Hardware Health Check"
if command -v smartctl &>/dev/null; then
    echo -e "${CYAN}SMART Disk Health:${NC}"
    smartctl --all /dev/sda | grep -E "Model|Health|Temp" || true
else
    echo -e "${YELLOW}smartmontools not installed. Install with: sudo dnf install smartmontools${NC}"
fi

if command -v sensors &>/dev/null; then
    echo -e "${CYAN}Temperature Sensors:${NC}"
    sensors
else
    echo -e "${YELLOW}lm_sensors not installed. Install with: sudo dnf install lm_sensors${NC}"
fi

# ==============================
# 4 - System Optimization
# ==============================
section "System Optimization"
run_cmd fc-cache -fv
run_cmd updatedb
echo -e "${CYAN}Removing old kernels (keeping latest two)${NC}"
dnf remove -y $(dnf repoquery --installonly --latest-limit=-2 -q) || true

# ==============================
# 5 - Network Checks
# ==============================
section "Network Information"
echo -e "${CYAN}Public IP:${NC} $(curl -s ifconfig.me || echo 'Unavailable')"
echo -e "${CYAN}DNS Test:${NC}"
dig google.com +short || true
if command -v speedtest-cli &>/dev/null; then
    echo -e "${CYAN}Network Speed Test:${NC}"
    speedtest-cli --simple
else
    echo -e "${YELLOW}speedtest-cli not installed. Install with: sudo dnf install speedtest-cli${NC}"
fi

# ==============================
# 7 - Extra Security Hardening
# ==============================
section "Security Hardening Checks"
echo -e "${CYAN}SELinux Status:${NC}"
getenforce || true
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}Fail2ban is running.${NC}"
else
    echo -e "${YELLOW}Fail2ban not running or not installed.${NC}"
fi

echo -e "${CYAN}Firewall Rule Count:${NC}"
firewall-cmd --list-all | wc -l

# ==============================
# Kernel reboot reminder
# ==============================
if [[ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ]]; then
    echo -e "${YELLOW}A new kernel ($LATEST_KERNEL) was installed. Please reboot.${NC}"
    notify "Reboot recommended: new kernel installed."
fi

# ==============================
# Summary
# ==============================
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))
notify "Fedora maintenance completed in ${RUNTIME}s 🎉"

echo -e "\n${GREEN}======================================"
echo "  ✅ All done in $RUNTIME seconds!"
echo "  📄 Log: $LOGFILE"
echo -e "======================================${NC}\n"
