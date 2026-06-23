#!/bin/bash

# Fedora Automate Scripty
# Author: Anode Pyxis
# Version: 1.0 (Last Update Date: 23rd June 2026)

# Strict Mode
set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths & Variables
STARTTIME=$(date +%s)
TIMESTAMP=$(date +%F-%H-%M-%S)
DRY_RUN=false

# Configuration Thresholds
LOG_RETENTION_DAYS=10
LARGEST_FILES_COUNT=10

# Capture authentic user variables before any elevation quirks
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

REPORT_DIR="$REAL_HOME/Documents/Maintenance_Reports"
LOGFILE="$REPORT_DIR/fedora-maintenance-$TIMESTAMP.log"
PKG_LIST="$REAL_HOME/installed_packages.txt"

# Setup directory structure safely
mkdir -p "$REPORT_DIR"

# Logging Setup (Process substitution)
exec > >(tee -a "$LOGFILE") 2>&1

# Global Exit Trap Handler
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}!! Script terminated unexpectedly with exit code $exit_code !!${NC}"
    fi
}
trap cleanup_on_exit EXIT

notify() {
    # Safely forward desktop notifications out of root isolation to user's DBus session
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$REAL_USER")/bus notify-send "Fedora Automate" "$1" || true
}

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
}

run_cmd() {
    echo -e "${CYAN}→ $*${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run Simulation Mode Enabled]"
    else
        if ! "$@"; then
            echo -e "${RED}✖ Command failed: $*${NC}" >&2
        fi
    fi
}

# --- Core Modules ---

update_package_manifest() {
    section "Updating Package Manifest"
    echo "# Fedora Package List - Generated $(date)" > "$PKG_LIST"
    rpm -qa --qf "%{NAME}\n" | sort >> "$PKG_LIST"
    echo -e "${GREEN}Manifest updated: $PKG_LIST${NC}"
}

update_system() {
    section "System Updates (DNF)"
    if [ "$DRY_RUN" = true ]; then
        sudo dnf upgrade --refresh --assumeno
    else
        sudo dnf upgrade --refresh -y
        sudo dnf distro-sync -y
    fi

    # Firmware (fwupd)
    if command -v fwupdmgr &> /dev/null; then
        section "Checking Firmware Status"
        if [ "$DRY_RUN" = true ]; then
             echo "[Dry-Run] Would check and refresh firmware layers."
        else
            sudo fwupdmgr refresh --force || true
            sudo fwupdmgr get-updates || echo "No firmware updates available."
        fi
    fi

    # Flatpaks
    if command -v flatpak &> /dev/null; then
        section "Updating Flatpaks"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would upgrade flatpak dependencies"
        else
            flatpak update -y
            flatpak uninstall --unused -y
        fi
    fi

    # Snaps
    if command -v snap &> /dev/null; then
        section "Updating Snaps"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would refresh snap applications"
        else
            sudo snap refresh
        fi
    fi

    # Python User-Space Packages
    if command -v pip3 &> /dev/null; then
        section "Updating User pip3 Packages"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would query and update pip modules under user environment"
        else
            # Execute cleanly inside user scope safely bypassing system packages
            sudo -u "$REAL_USER" pip3 list --outdated --format=freeze 2>/dev/null | cut -d = -f1 | xargs -n1 sudo -u "$REAL_USER" pip3 install --upgrade || true
        fi
    fi
}

clean_up() {
    section "System Cleanup & Purging"
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would drop orphans, reset package caches, clear logs, and empty bins."
        sudo dnf autoremove --assumeno || true
    else
        echo "Removing dangling dependency orphans..."
        sudo dnf autoremove -y
        
        echo "Clearing system local DNF cache data..."
        sudo dnf clean all
        
        echo "Vacuuming systemd journal metrics..."
        sudo journalctl --vacuum-time=2weeks
        
        echo "Purging old localized maintenance reports..."
        find "$REPORT_DIR" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
        
        echo "Emptying isolated desktop trash bins & thumbnail pools..."
        rm -rf "$REAL_HOME/.local/share/Trash/files/"* 2>/dev/null || true
        rm -rf "$REAL_HOME/.local/share/Trash/info/"* 2>/dev/null || true
        rm -rf "$REAL_HOME/.cache/thumbnails/"* 2>/dev/null || true
        echo -e "${GREEN}Cleanup workflows finalized successfully.${NC}"
    fi
}

security_audit() {
    section "Security & Environment Audit"
    
    # Zombie Processes Monitor
    local zombies
    zombies=$(ps -eo stat,ppid,pid,cmd | grep -w 'Z' | grep -v grep || true)
    if [[ -z "$zombies" ]]; then
        echo -e "${GREEN}No zombie process flags detected.${NC}"
    else
        echo -e "${RED}Warning: Zombie execution points active:${NC}\n$zombies"
    fi

    # Firewall Integration
    if command -v firewall-cmd &> /dev/null; then
        echo -ne "${CYAN}Firewalld Status: ${NC}"
        sudo firewall-cmd --state || echo "Inactive"
    fi
    
    # SELinux Operational Assessment
    if command -v getenforce &> /dev/null; then
        echo -e "${CYAN}SELinux Structural Policy State:${NC} $(getenforce)"
    fi

    # Core Asset Configurations Backup
    if [ "$DRY_RUN" = false ]; then
        local backup_destination="$REAL_HOME/SystemBackups/$(date +%F)"
        mkdir -p "$backup_destination"
        cp /etc/fstab "$backup_destination/"
        cp /etc/hosts "$backup_destination/"
        echo -e "${GREEN}Critical files backed up structurally to: $backup_destination${NC}"
    fi

    # Storage Infrastructure Integrity Diagnostics
    local primary_drive
    primary_drive=$(lsblk -no NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
    if command -v smartctl &>/dev/null && [[ -n "$primary_drive" ]]; then
        echo -e "${CYAN}Validating Device Telemetry: $primary_drive${NC}"
        sudo smartctl -H "$primary_drive" | grep -E "test|PASSED" || echo "SMART status metrics confirmed healthy."
    fi

    # Large Disk Space Consumers Discovery
    section "Top $LARGEST_FILES_COUNT Space Consuming Files (>100M)"
    find / -type f -size +100M -not -path "/proc/*" -not -path "/sys/*" -not -path "/dev/*" \
        -printf '%s %p\n' 2>/dev/null | sort -nr | head -"$LARGEST_FILES_COUNT" | \
        awk '{print $1/1024/1024 " MB - " $2}' || echo "No files exceeded sizing constraints."
}

check_kernel() {
    section "Post-Maintenance Boot Validation"
    local current_kernel
    current_kernel=$(uname -r)
    
    # Acquire highest versioned build available in RPM databases safely
    local latest_kernel
    latest_kernel=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V | tail -n 1 || true)

    if [[ -n "$latest_kernel" && "$current_kernel" != *"$latest_kernel"* ]]; then
        echo -e "${RED}!!! PENDING REBOOT REQUIRED !!!${NC}"
        echo -e "${YELLOW}Active Running Target:  $current_kernel${NC}"
        echo -e "${GREEN}Upgraded Disk Target:  $latest_kernel${NC}"
        notify "Maintenance complete. REBOOT REQUIRED."
    else
        echo -e "${GREEN}Kernel environment synchronized. No reboot required.${NC}"
        notify "Fedora maintenance completed successfully 🎉"
    fi
}

# --- Interface Layout ---

show_menu() {
    clear
    echo -e "${CYAN}======================================"
    echo "    Fedora Automate Pro (Hardened)"
    echo -e "======================================${NC}"
    echo "1) Full Maintenance (Manifest + Update + Clean + Audit)"
    echo "2) Dry Run (Simulate Updates & Cleanup)"
    echo "3) Security & System Health Audit Only"
    echo "4) Cleanup & Asset Purge Only"
    echo "5) Exit"
    echo -n "Selection: "
}

# --- Runtime Orchestration ---

show_menu
read -r OPT || exit 0

# Prime sudo credentials gracefully upfront before triggering logic paths
if [[ "$OPT" =~ ^[1234]$ ]]; then
    sudo -v
fi

case $OPT in
    1)
        update_package_manifest
        update_system
        clean_up
        security_audit
        check_kernel
        ;;
    2)
        DRY_RUN=true
        section "SIMULATING FEDORA MAINTENANCE PROFILE"
        update_system
        clean_up
        ;;
    3)
        security_audit
        ;;
    4)
        clean_up
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice selection profile determined."
        exit 1
        ;;
esac

# Calculate execution performance benchmarks cleanly
ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))

echo -e "\n${GREEN}======================================"
echo "  ✅ Operational steps finished in $RUNTIME seconds!"
echo "  📄 Execution Ledger: $LOGFILE"
echo -e "======================================${NC}\n"
