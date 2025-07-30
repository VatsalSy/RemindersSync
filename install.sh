#!/bin/bash

# RemindersSync Installation Script
# This script builds and installs RemindersSync tools system-wide

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run this script with sudo:${NC}"
    echo "sudo ./install.sh"
    exit 1
fi

echo -e "${GREEN}RemindersSync Installation Script${NC}"
echo "=================================="

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "\n${YELLOW}Step 1: Building release version...${NC}"
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! Please check the error messages above.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Creating /usr/local/bin directory if needed...${NC}"
mkdir -p /usr/local/bin

echo -e "\n${YELLOW}Step 3: Installing executables...${NC}"

# Define the mapping of executables to their system names
declare -A executables=(
    ["RemindersSync"]="obsidian-reminders"
    ["ScanVault"]="obsidian-scan"
    ["ExportOtherReminders"]="obsidian-export"
    ["ReSyncReminders"]="obsidian-resync"
    ["CleanUp"]="obsidian-cleanup"
)

# Install each executable
for exe in "${!executables[@]}"; do
    system_name="${executables[$exe]}"
    if [ -f ".build/release/$exe" ]; then
        echo "Installing $exe as $system_name..."
        cp ".build/release/$exe" "/usr/local/bin/$system_name"
        chmod +x "/usr/local/bin/$system_name"
        echo -e "  ${GREEN}✓${NC} $system_name installed"
    else
        echo -e "  ${RED}✗${NC} $exe not found in .build/release/"
    fi
done

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\nYou can now use the following commands from anywhere:"
echo "  obsidian-reminders /path/to/vault  # Full two-way sync"
echo "  obsidian-scan /path/to/vault       # One-way sync"
echo "  obsidian-export /path/to/vault     # Export only"
echo "  obsidian-resync /path/to/vault     # Clean vault for fresh sync"
echo "  obsidian-cleanup /path/to/vault    # Remove completed tasks only"

echo -e "\n${YELLOW}Optional:${NC} Add these aliases to your ~/.zshrc or ~/.bashrc:"
echo 'alias sync-obsidian="obsidian-reminders /path/to/your/vault"'
echo 'alias scan-obsidian="obsidian-scan /path/to/your/vault"'
echo 'alias export-reminders="obsidian-export /path/to/your/vault"'
echo 'alias resync-obsidian="obsidian-resync /path/to/your/vault"'
echo 'alias cleanup-obsidian="obsidian-cleanup /path/to/your/vault"'