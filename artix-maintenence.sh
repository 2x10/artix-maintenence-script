#!/usr/bin/env bash
# =============================================
#  Artix Linux Maintenance Script (with logging)
# =============================================

#set -e
export LC_ALL=C

DATE=$(date "+%d.%m.%Y_%H-%M") 
LOGFILE="$HOME/.logs/system_maintenance_${DATE}.log"

mkdir -p "$(dirname "$LOGFILE")"

# ----- LOGGING SETUP -----
exec > >(tee -a "$LOGFILE") 2>&1

# ----- COLORS -----
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}=== Artix System Maintenance Started ===${RESET}"
echo "Log file: $LOGFILE"

# ----- update system -----
echo -e "\n${YELLOW}Updating system packages (pacman)...${RESET}"
sudo pacman -Syu --noconfirm

echo -e "\n${YELLOW}Updating AUR packages (paru)...${RESET}"
paru -Syu --noconfirm

# ----- remove unneeded packages -----
echo -e "\n${YELLOW}Removing orphaned packages...${RESET}"
orphans=$(pacman -Qdtq || true)
if [[ -n "$orphans" ]]; then
    sudo pacman -Rns $orphans --noconfirm
else
    echo "No orphaned packages found."
fi

# ----- flatpak maintenance -----
if command -v flatpak >/dev/null 2>&1; then
    echo -e "\n${YELLOW}Updating Flatpak apps and runtimes...${RESET}"
    flatpak update -y

    echo -e "\n${YELLOW}Removing unused Flatpak runtimes...${RESET}"
    flatpak uninstall --unused -y

    echo -e "\n${YELLOW}Cleaning Flatpak cache...${RESET}"
    rm -rf ~/.var/app/*/cache/*
else
    echo -e "${YELLOW}Flatpak not found — skipping Flatpak maintenance.${RESET}"
fi

# ----- pacman cache -----
echo -e "\n${YELLOW}Cleaning pacman cache...${RESET}"
sudo paccache -r -k1

# ----- temporary files -----
echo -e "\n${YELLOW}Cleaning /tmp and user cache...${RESET}"
sudo find /tmp -mindepth 1 -mtime +1 -delete
rm -rf ~/.cache/*

# ----- cache clearing -----
echo -e "\n${YELLOW}Cleaning app-specific caches...${RESET}"

# Steam
rm -rf ~/.steam/steam/appcache/* \
       ~/.steam/steam/config/htmlcache/* \
       ~/.steam/steam/htmlcache/* 2>/dev/null || true

# Firefox
find ~/.mozilla/firefox -type d -name "cache2" -exec rm -rf {} + 2>/dev/null || true

# ----- font cache -----
echo -e "\n${YELLOW}Rebuilding font cache...${RESET}"
fc-cache -rv

# ----- pacnew/pacsave -----
echo -e "\n${YELLOW}Checking for leftover config files (pacnew/pacsave)...${RESET}"
sudo find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \)

# ----- disk usage -----
echo -e "\n${YELLOW}Disk usage summary:${RESET}"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs

# ----- failed services -----
echo -e "\n${YELLOW}Checking for failed services...${RESET}"
rc-status --crashed

# ----- DONE -----
echo -e "\n${GREEN}=== System maintenance complete! ===${RESET}"
echo "Finished at: $(date)"