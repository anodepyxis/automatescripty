#!/bin/bash

# Arch Automate Scripty
# Author: Anode Pyxis
# Version: 

# Set strict mode
# -e: Exit on error
# -u: Exit on unset variables
# -o pipefail: Catch errors in piped commands
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
STARTTIME=$(date +%s)
REPORT_DIR="$HOME/Report"
LOGFILE="$REPORT_DIR/arch-maintenance-$(date +%F-%H-%M-%S).log"
PKG_LIST="$HOME/installed_packages.txt"
DRY_RUN=false

# Setup directory
mkdir -p "$REPORT_DIR"

# Logging setup (Process substitution is safe with -e)
exec > >(tee -a "$LOGFILE") 2>&1

notify() {
    if command -v notify-send &> /dev/null; then
        notify-send "Arch Automate" "$1"
    fi
}

section() {
    echo -e "\n${YELLOW}>>> $1...${NC}\n"
}

# --- Core Modules ---

update_package_manifest() {
    section "Updating Package Manifest"
    echo "# Arch Package List - Generated $(date)" > "$PKG_LIST"
    pacman -Qqe >> "$PKG_LIST"
    echo -e "${GREEN}Manifest updated: $PKG_LIST${NC}"
}

update_system() {
    section "System Updates"
    if [ "$DRY_RUN" = true ]; then
        sudo pacman -Syuup
    else
        sudo pacman -Syu --noconfirm
    fi

    # AUR
    AUR_HELPER=$(command -v paru || command -v yay || true)
    if [ -n "$AUR_HELPER" ]; then
        section "AUR Updates ($AUR_HELPER)"
        if [ "$DRY_RUN" = true ]; then
            $AUR_HELPER -Syu --print
        else
            $AUR_HELPER -Syu --noconfirm
        fi
    fi
}

clean_up() {
    section "System Cleanup"
    # Orphans
    ORPHANS=$(pacman -Qdtq || true)
    if [ -n "$ORPHANS" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would remove: $ORPHANS"
        else
            sudo pacman -Rns $ORPHANS --noconfirm
        fi
    else
        echo -e "${GREEN}No orphans to remove.${NC}"
    fi

    # Cache/Logs
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would vacuum journal and clear pacman cache."
    else
        sudo paccache -r
        sudo journalctl --vacuum-time=2weeks
        rm -rf ~/.local/share/Trash/files/* 2>/dev/null || true
    fi
}

security_audit() {
    section "Security Audit"
    # Consistency in sudo usage
    sudo firewall-cmd --state 2>/dev/null || echo "Firewall: Inactive/Not Installed"
    
    if command -v lynis &> /dev/null; then
        sudo lynis audit system --quick
    else
        echo "Lynis not found. Skipping."
    fi
}

check_kernel() {
    # Check if a reboot is needed by comparing running kernel to on-disk package version
    RUNNING=$(uname -r | cut -d'-' -f1)
    # Using '|| true' because grep returns non-zero if no match found
    INSTALLED=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | cut -d'-' -f1 || true)

    if [[ -n "$INSTALLED" && "$RUNNING" != "$INSTALLED" ]]; then
        echo -e "${RED}!! KERNEL MISMATCH !!${NC}"
        echo "Running: $RUNNING | Installed: $INSTALLED"
        echo "Reboot is highly recommended."
        notify "Kernel update detected. Reboot needed."
    fi
}

# --- Interface ---

show_menu() {
    clear
    echo -e "${CYAN}======================================"
    echo "    Arch Automate Pro (Hardened)"
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
read -r OPT

# Ensure we have sudo permissions early unless it's a dry run
if [ "$OPT" != "5" ] && [ "$OPT" != "2" ]; then
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

check_kernel

ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))
echo -e "\n${GREEN}Success! Finished in ${RUNTIME}s.${NC}"
echo "Log: $LOGFILE"
