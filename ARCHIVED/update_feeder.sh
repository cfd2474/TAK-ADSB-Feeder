#!/bin/bash
# ADS-B Feeder Update Script
# Quick updater to download latest installer from GitHub
# Part of: https://github.com/cfd2474/TAK-ADSB-Feeder

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_RAW_URL="https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/adsb_feeder_installer.sh"
INSTALL_SCRIPT="adsb_feeder_installer.sh"

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ADS-B Feeder Installer Updater          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Downloading latest version from GitHub...${NC}"
echo -e "${BLUE}Repository: https://github.com/cfd2474/TAK-ADSB-Feeder${NC}"
echo ""

# Download latest version
TEMP_SCRIPT=$(mktemp)
if curl -fsSL "$GITHUB_RAW_URL" -o "$TEMP_SCRIPT" 2>/dev/null || wget -q "$GITHUB_RAW_URL" -O "$TEMP_SCRIPT" 2>/dev/null; then
    # Get versions
    if [ -f "$INSTALL_SCRIPT" ]; then
        CURRENT_VERSION=$(grep '^SCRIPT_VERSION=' "$INSTALL_SCRIPT" 2>/dev/null | head -1 | cut -d'"' -f2)
    else
        CURRENT_VERSION="Not installed"
    fi
    
    LATEST_VERSION=$(grep '^SCRIPT_VERSION=' "$TEMP_SCRIPT" 2>/dev/null | head -1 | cut -d'"' -f2)
    
    echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"
    echo -e "${BLUE}Latest version:  ${LATEST_VERSION}${NC}"
    echo ""
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "Not installed" ]; then
        echo -e "${GREEN}✓ You already have the latest version!${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 0
    fi
    
    # Show what's new in latest version
    if [ "$LATEST_VERSION" = "5.4" ]; then
        echo -e "${YELLOW}What's new in v5.4:${NC}"
        echo "  • MLAT opt-out option during installation"
        echo "  • Bandwidth warnings for metered connections"
        echo "  • Enable/disable MLAT post-installation"
        echo ""
    fi
    
    # Backup if exists
    if [ -f "$INSTALL_SCRIPT" ]; then
        BACKUP_NAME="${INSTALL_SCRIPT}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$INSTALL_SCRIPT" "$BACKUP_NAME"
        echo -e "${GREEN}✓ Backed up current version to $BACKUP_NAME${NC}"
    fi
    
    # Install new version
    mv "$TEMP_SCRIPT" "$INSTALL_SCRIPT"
    chmod +x "$INSTALL_SCRIPT"
    
    echo -e "${GREEN}✓ Successfully updated to version $LATEST_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}Run the installer with:${NC}"
    echo "  ./$INSTALL_SCRIPT"
    echo ""
    echo -e "${YELLOW}Check version info:${NC}"
    echo "  ./$INSTALL_SCRIPT --version"
    echo ""
    echo -e "${YELLOW}Or run installation immediately:${NC}"
    read -p "Run installation now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec "./$INSTALL_SCRIPT"
    fi
    
else
    echo -e "${RED}✗ Failed to download update${NC}"
    echo -e "${YELLOW}Please check your internet connection and try again${NC}"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi
