#!/bin/bash

# RemindersSync Uninstallation Script
# This script removes RemindersSync tools from system

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run this script with sudo:${NC}"
    echo "sudo ./uninstall.sh"
    exit 1
fi

echo -e "${GREEN}RemindersSync Uninstallation Script${NC}"
echo "===================================="

echo -e "\n${YELLOW}Removing installed executables...${NC}"

# List of executables to remove
executables=(
    "obsidian-reminders"
    "obsidian-scan"
    "obsidian-export"
    "obsidian-resync"
    "obsidian-cleanup"
)

removed_count=0

for exe in "${executables[@]}"; do
    if [ -f "/usr/local/bin/$exe" ]; then
        echo "Removing $exe..."
        rm -f "/usr/local/bin/$exe"
        echo -e "  ${GREEN}✓${NC} $exe removed"
        ((removed_count++))
    else
        echo -e "  ${YELLOW}-${NC} $exe not found (already removed?)"
    fi
done

if [ $removed_count -gt 0 ]; then
    echo -e "\n${GREEN}Uninstallation complete!${NC}"
    echo "Removed $removed_count executable(s) from /usr/local/bin"
else
    echo -e "\n${YELLOW}No executables found to remove.${NC}"
fi

echo -e "\n${YELLOW}Note:${NC} This script does not remove:"
echo "  - The RemindersSync source code directory"
echo "  - Any aliases you may have added to your shell configuration"
echo "  - State files in your Obsidian vault (._*.json files)"
echo ""
echo "To completely remove RemindersSync, you may also want to:"
echo "  1. Delete the source directory"
echo "  2. Remove any aliases from ~/.zshrc or ~/.bashrc"
echo "  3. Remove state files from your vault (if desired)"