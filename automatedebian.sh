#!/bin/bash

# Debian Automate Scripty
# Author: Anode Pyxis
# Version: 1.0 (Last Update Date: 23rd June 2026)

# Strict Mode
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths & Variables
STARTTIME=$(date +%s)
REPORT_DIR="$HOME/Report"
LOGFILE="$REPORT_DIR/debian-maintenance-$(date +%F-%H-%M-%S).log"
PKG_LIST="$HOME/installed_packages.txt"
DRY_RUN=false

# Setup directory
mkdir -p "$REPORT_DIR"

# Logging (Thread-safe redirection via process substitution)
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
    if [[ -n "${DISPLAY:-}" ]] && command -v notify-send &> /dev/null; then
        notify-send "Debian Automate" "$1"
    else
        echo -e "${CYAN}[Notification]${NC} $1"
    fi
}

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
}

# --- Core Modules ---

update_package_manifest() {
    section "Updating Package Manifest"
    echo "# Debian Package List (Manual) - Generated $(date)" > "$PKG_LIST"
    apt-mark showmanual >> "$PKG_LIST"
    echo -e "${GREEN}Manifest updated: $PKG_LIST${NC}"
}

update_system() {
    section "System Updates (APT)"
    
    # Prevent network/mirror failure from crashing the script under set -e
    if ! sudo apt update; then
        echo -e "${RED}Warning: 'apt update' failed or was interrupted. Proceeding with existing cache state.${NC}"
    fi

    if [ "$DRY_RUN" = true ]; then
        sudo apt full-upgrade --simulate
    else
        sudo apt full-upgrade -y
    fi

    # Flatpak
    if command -v flatpak &> /dev/null; then
        section "Updating Flatpaks"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would run: flatpak update"
        else
            flatpak update -y
        fi
    fi

    # Firmware (fwupd)
    if command -v fwupdmgr &> /dev/null; then
        section "Checking Firmware"
        if [ "$DRY_RUN" = true ]; then
             echo "[Dry-Run] Would refresh and check for firmware updates."
        else
            sudo fwupdmgr refresh --force || true
            sudo fwupdmgr update || true
        fi
    fi
}

clean_up() {
    section "System Cleanup"
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would run autoremove, clean cache, and clear logs."
        sudo apt autoremove --simulate
    else
        echo "Removing obsolete packages..."
        sudo apt autoremove -y
        
        echo "Cleaning package cache archives..."
        sudo apt autoclean
        
        echo "Vacuuming systemd journal..."
        sudo journalctl --vacuum-time=2weeks
        
        echo "Clearing user trash and thumbnail caches..."
        rm -rf "$HOME/.local/share/Trash/files/"* 2>/dev/null || true
        rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
        echo -e "${GREEN}Cleanup complete.${NC}"
    fi
}

security_audit() {
    section "Security Audit"
    if command -v ufw &> /dev/null; then
        sudo ufw status verbose
    else
        echo "UFW not found. Checking active listening ports..."
        sudo ss -tulnp
    fi
    
    if command -v lynis &> /dev/null; then
        sudo lynis audit system --quick
    fi
}

check_reboot() {
    section "Post-Maintenance Check"
    if [ -f /var/run/reboot-required ]; then
        echo -e "${RED}!! SYSTEM REBOOT REQUIRED !!${NC}"
        cat /var/run/reboot-required
        notify "System reboot required to apply updates."
    else
        echo -e "${GREEN}No reboot required.${NC}"
    fi
}

# --- Interface ---

show_menu() {
    clear
    echo -e "${CYAN}======================================"
    echo "    Debian Automate Pro (Hardened)"
    echo -e "======================================${NC}"
    echo "1) Full Maintenance (Manifest + Update + Clean + Audit)"
    echo "2) Dry Run (Simulate Updates & Cleanup)"
    echo "3) Security Audit Only"
    echo "4) Cleanup Only"
    echo "5) Exit"
    echo -n "Selection: "
}

# --- Main Logic ---

show_menu
read -r OPT || exit 0

# Dry-runs still require root access to read package files/locks securely
if [[ "$OPT" =~ ^[1234]$ ]]; then
    sudo -v
fi

case $OPT in
    1)
        update_package_manifest
        update_system
        clean_up
        security_audit
        ;;
    2)
        DRY_RUN=true
        section "SIMULATING MAINTENANCE"
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
        echo "Invalid input."
        exit 1
        ;;
esac

# Only verify reboot indicators if real changes were executed
if [ "$DRY_RUN" = false ] && { [ "$OPT" -eq 1 ] || [ "$OPT" -eq 4 ]; }; then
    check_reboot
fi

ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))
echo -e "\n${GREEN}Success! Finished in ${RUNTIME}s.${NC}"
echo "Log: $LOGFILE"
