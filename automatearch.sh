#!/bin/bash

# Arch Automate Scripty
# Author: Anode Pyxis
# Version: 1.0 (Last Update Date: 23rd June 2026)

# Set strict mode
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

# Logging setup (Process substitution)
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

    # AUR Helper Detection
    local AUR_HELPER
    AUR_HELPER=$(command -v paru || command -v yay || true)
    if [ -n "$AUR_HELPER" ]; then
        section "AUR Updates ($AUR_HELPER)"
        if [ "$DRY_RUN" = true ]; then
            $AUR_HELPER -Syu --print
        else
            $AUR_HELPER -Syu --noconfirm
        fi
    fi

    # Flatpak Updates (Optional/Conditional)
    if command -v flatpak &> /dev/null; then
        section "Flatpak Updates"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would update flatpak packages"
        else
            flatpak update --noninteractive
        fi
    fi
}

clean_up() {
    section "System Cleanup"
    
    # Orphans
    local ORPHANS
    ORPHANS=$(pacman -Qdtq || true)
    if [ -n "$ORPHANS" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would remove orphans: $ORPHANS"
        else
            sudo pacman -Rns $ORPHANS --noconfirm
        fi
    else
        echo -e "${GREEN}No orphans to remove.${NC}"
    fi

    # Cache/Logs
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would vacuum journal, clear pacman cache, and empty trash."
    else
        echo "Cleaning pacman package cache..."
        sudo paccache -r     # Keeps last 3 versions of installed pkgs
        sudo paccache -ruk0  # Removes ALL versions of uninstalled pkgs
        
        echo "Vacuuming systemd journal..."
        sudo journalctl --vacuum-time=2weeks
        
        echo "Emptying user trash..."
        rm -rf "$HOME/.local/share/Trash/files/"* 2>/dev/null || true
        echo -e "${GREEN}Cleanup complete.${NC}"
    fi
}

security_audit() {
    section "Security Audit"
    
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --state 2>/dev/null || echo "Firewall: Inactive"
    else
        echo "firewalld is not installed."
    fi
    
    if command -v lynis &> /dev/null; then
        sudo lynis audit system --quick
    else
        echo "Lynis audit tool not found. Skipping."
    fi
}

check_kernel() {
    section "Checking Kernel Integrity"
    # If the directory containing modules for the running kernel version is gone,
    # it means pacman swapped it out during a system update.
    if [ ! -d "/usr/lib/modules/$(uname -r)" ]; then
        echo -e "${RED}!! KERNEL MISMATCH DETECTED !!${NC}"
        echo "The active kernel modules directory has been updated or removed."
        echo "A system reboot is highly recommended to sync the kernel."
        notify "Kernel update detected. Reboot needed."
    else
        echo -e "${GREEN}Kernel is consistent. No reboot required.${NC}"
    fi
}

# --- Interface ---

show_menu() {
    clear
    echo -e "${CYAN}======================================"
    echo "      Arch Automate Pro (Hardened)"
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

# Ensure we get sudo elevation early unless exiting or running a dry run
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

# Check kernel status after any operations are completed
if [ "$DRY_RUN" = false ] && [ "$OPT" -eq 1 ] || [ "$OPT" -eq 4 ]; then
    check_kernel
fi

ENDTIME=$(date +%s)
RUNTIME=$((ENDTIME - STARTTIME))
echo -e "\n${GREEN}Success! Finished in ${RUNTIME}s.${NC}"
echo "Log: $LOGFILE"
