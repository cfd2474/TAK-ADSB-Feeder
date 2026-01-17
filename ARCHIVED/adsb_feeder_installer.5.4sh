#!/bin/bash
# ADS-B Feeder Auto-Installer for Raspberry Pi
# Configures RTL-SDR dongle to feed ADS-B data to aggregation server via Tailscale
# Version 5.4 - Added MLAT opt-out feature

set -e

# ============================================================================
# SCRIPT VERSION AND UPDATE CONFIGURATION
# ============================================================================

SCRIPT_VERSION="5.4"
GITHUB_RAW_URL="https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/adsb_feeder_installer.sh"
SCRIPT_NAME="adsb_feeder_installer.sh"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Capture absolute script path at the very beginning (before any directory changes)
SCRIPT_PATH="$(readlink -f "$0")"

# ============================================================================
# SELF-UPDATE FUNCTIONALITY
# ============================================================================

update_script() {
    echo -e "${BLUE}Checking for updates...${NC}"
    
    # Download latest version to temp file
    TEMP_SCRIPT=$(mktemp)
    if curl -fsSL "$GITHUB_RAW_URL" -o "$TEMP_SCRIPT" 2>/dev/null || wget -q "$GITHUB_RAW_URL" -O "$TEMP_SCRIPT" 2>/dev/null; then
        # Extract version from downloaded script
        LATEST_VERSION=$(grep '^SCRIPT_VERSION=' "$TEMP_SCRIPT" | head -1 | cut -d'"' -f2)
        
        if [ -z "$LATEST_VERSION" ]; then
            echo -e "${RED}Could not determine latest version${NC}"
            rm -f "$TEMP_SCRIPT"
            return 1
        fi
        
        echo -e "${BLUE}Current version: $SCRIPT_VERSION${NC}"
        echo -e "${BLUE}Latest version:  $LATEST_VERSION${NC}"
        echo ""
        
        if [ "$SCRIPT_VERSION" = "$LATEST_VERSION" ]; then
            echo -e "${GREEN}✓ You are running the latest version!${NC}"
            rm -f "$TEMP_SCRIPT"
            return 0
        fi
        
        echo -e "${YELLOW}Update available: v$SCRIPT_VERSION → v$LATEST_VERSION${NC}"
        read -p "Update to version $LATEST_VERSION? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Backup current script with timestamp
            BACKUP_NAME="${SCRIPT_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$SCRIPT_PATH" "$BACKUP_NAME"
            echo -e "${GREEN}✓ Backed up current script to $BACKUP_NAME${NC}"
            
            # Replace current script with new version
            cp "$TEMP_SCRIPT" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            
            echo -e "${GREEN}✓ Script updated to version $LATEST_VERSION${NC}"
            echo -e "${YELLOW}Restarting with new version...${NC}"
            echo ""
            
            rm -f "$TEMP_SCRIPT"
            exec "$SCRIPT_PATH" "$@"
        else
            echo -e "${YELLOW}Update cancelled${NC}"
            rm -f "$TEMP_SCRIPT"
            return 0
        fi
    else
        echo -e "${RED}Failed to download update from GitHub${NC}"
        echo -e "${YELLOW}Please check your internet connection and try again${NC}"
        rm -f "$TEMP_SCRIPT"
        return 1
    fi
}

# Check for --update flag
if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ADS-B Feeder Installer Updater          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    update_script
    exit $?
fi

# Check for --version flag
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "ADS-B Feeder Installer v$SCRIPT_VERSION"
    echo "GitHub: https://github.com/cfd2474/TAK-ADSB-Feeder"
    exit 0
fi

# Check for --help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "ADS-B Feeder Installer v$SCRIPT_VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --update, -u     Update installer to latest version from GitHub"
    echo "  --version, -v    Show version information"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Without options, runs the installation process."
    echo ""
    echo "GitHub: https://github.com/cfd2474/TAK-ADSB-Feeder"
    exit 0
fi

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ADS-B Feeder Installer v$SCRIPT_VERSION             ║${NC}"
echo -e "${GREEN}║   with Local tar1090 & Tailscale          ║${NC}"
echo -e "${GREEN}║   + SSH Security for Remote Access        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# CONFIGURATION - EDIT THESE VALUES FOR YOUR DEPLOYMENT
# ============================================================================

# Installation directory
INSTALL_DIR="/opt/TAK_ADSB"

# Aggregator Tailscale IP (update this to match your aggregator)
AGGREGATOR_TAILSCALE_IP="100.117.34.88"
AGGREGATOR_BEAST_PORT="30004"
AGGREGATOR_MLAT_PORT="30105"

# Tailscale auth key will be prompted during installation
# Key is NOT stored in this script for security reasons

# Default location (will prompt if empty)
FEEDER_LAT=""
FEEDER_LON=""
FEEDER_ALT=""  # Altitude in meters

# RTL-SDR Configuration
RTL_GAIN="-10"  # -10 for auto gain, or specific value like 49.6
RTL_PPM="0"     # PPM correction

# Remote user configuration
REMOTE_USER="remote"
REMOTE_PASSWORD="adsb"

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: Do not run this script as root!${NC}"
    echo "Run as: ./adsb_feeder_installer.sh"
    exit 1
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}WARNING: This doesn't appear to be a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================================================
# GATHER CONFIGURATION
# ============================================================================

echo -e "${BLUE}=== Configuration Setup ===${NC}"
echo ""

# Prompt for Tailscale auth key
echo -e "${YELLOW}╔═══════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Tailscale Authentication Required       ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "Get your reusable auth key from:"
echo "  https://login.tailscale.com/admin/settings/keys"
echo ""
echo -e "${BLUE}When generating the key, make sure to:${NC}"
echo "  ✓ Check 'Reusable' (allows use on multiple devices)"
echo "  ✓ Check 'Pre-authorized' (skip manual approval)"
echo "  ✗ DO NOT check 'Ephemeral' (makes key single-use)"
echo ""
echo -e "${YELLOW}The key should look like: tskey-auth-k...${NC}"
echo ""
read -p "Enter Tailscale auth key (or press Enter to authenticate manually later): " TAILSCALE_AUTH_KEY
echo ""

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo -e "${YELLOW}No key provided - you will need to authenticate manually via browser${NC}"
    echo ""
fi

# Prompt for MLAT enablement
echo -e "${YELLOW}╔═══════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  MLAT Configuration                       ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "MLAT (Multilateration) improves aircraft position accuracy by"
echo "coordinating with other receivers, but uses more network bandwidth."
echo ""
echo -e "${YELLOW}⚠ WARNING: MLAT increases data usage significantly${NC}"
echo "  If using a metered connection (LTE/cellular with data cap),"
echo "  you may want to disable MLAT to conserve data."
echo ""
read -p "Enable MLAT? (Y/n) " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    ENABLE_MLAT=false
    echo -e "${YELLOW}MLAT will be installed but disabled${NC}"
    echo -e "${BLUE}You can enable it later with: sudo systemctl enable mlat-client && sudo systemctl start mlat-client${NC}"
else
    ENABLE_MLAT=true
    echo -e "${GREEN}MLAT will be enabled${NC}"
fi
echo ""

# Prompt for location if not set
if [ -z "$FEEDER_LAT" ]; then
    read -p "Enter feeder latitude (e.g., 33.834378): " FEEDER_LAT
fi

if [ -z "$FEEDER_LON" ]; then
    read -p "Enter feeder longitude (e.g., -117.573072): " FEEDER_LON
fi

if [ -z "$FEEDER_ALT" ]; then
    read -p "Enter feeder altitude in meters (e.g., 380): " FEEDER_ALT
fi

# Generate unique feeder name
FEEDER_NAME="${HOSTNAME}_$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':' | tail -c 7 || echo "unknown")"

# Display configuration
echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Feeder Configuration                     ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════╝${NC}"
echo "  Feeder Name:      $FEEDER_NAME"
echo "  Install Dir:      $INSTALL_DIR"
echo "  Location:         $FEEDER_LAT, $FEEDER_LON"
echo "  Altitude:         ${FEEDER_ALT}m"
echo "  Aggregator IP:    $AGGREGATOR_TAILSCALE_IP"
echo "  Beast Port:       $AGGREGATOR_BEAST_PORT"
echo "  MLAT Port:        $AGGREGATOR_MLAT_PORT"
echo "  RTL-SDR Gain:     $RTL_GAIN"
echo "  Local tar1090:    Enabled"
if [ "$ENABLE_MLAT" = true ]; then
    echo "  MLAT:             Enabled"
else
    echo "  MLAT:             Disabled (installed but not enabled)"
fi
echo "  Remote User:      $REMOTE_USER (Tailscale access only)"
echo "  vnstat:           90 day retention"
if [ -n "$TAILSCALE_AUTH_KEY" ]; then
    echo "  Tailscale Auth:   Key provided (auto-authenticate)"
else
    echo "  Tailscale Auth:   Manual authentication (browser)"
fi
echo ""
read -p "Continue with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 1
fi

# ============================================================================
# INSTALLATION STEPS
# ============================================================================

echo ""
echo -e "${GREEN}[1/15] Creating installation directory...${NC}"
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR/bin"
sudo mkdir -p "$INSTALL_DIR/data"
sudo mkdir -p "$INSTALL_DIR/run"
sudo mkdir -p "$INSTALL_DIR/logs"
sudo mkdir -p "$INSTALL_DIR/scripts"

echo ""
echo -e "${GREEN}[2/15] Updating system packages...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

echo ""
echo -e "${GREEN}[3/15] Installing dependencies...${NC}"
sudo apt-get install -y \
    build-essential \
    debhelper \
    libusb-1.0-0-dev \
    librtlsdr-dev \
    libncurses5-dev \
    zlib1g-dev \
    libzstd-dev \
    git \
    wget \
    curl \
    netcat-openbsd \
    python3-pip \
    python3-dev \
    python3-numpy \
    pkg-config \
    lighttpd \
    vnstat

echo ""
echo -e "${GREEN}[4/15] Configuring vnstat with 90-day retention...${NC}"
# Configure vnstat to keep 90 days of data
sudo tee /etc/vnstat.conf > /dev/null <<EOF
# vnStat 2.x configuration

# Database directory
DatabaseDir "/var/lib/vnstat"

# Locale
Locale "-"

# Date output formats
DayFormat    "%Y-%m-%d"
MonthFormat  "%Y-%m"
TopFormat    "%Y-%m-%d"

# Characters used for bars
RxCharacter       "%"
TxCharacter       ":"
RxHourCharacter   "r"
TxHourCharacter   "t"

# Data retention (90 days)
5MinuteHours   48      # 48 hours of 5-minute data
HourlyDays     7       # 7 days of hourly data
DailyDays      90      # 90 days of daily data (increased from default 30)
MonthlyMonths  25      # 25 months of monthly data
YearlyYears    -1      # all years

# Update interval for daemon (seconds)
UpdateInterval 30

# Save interval (minutes)
SaveInterval 5

# Use UTC time
UseUTC 0

# Query mode
QueryMode 0
EOF

# Enable and start vnstat
sudo systemctl enable vnstat
sudo systemctl restart vnstat

# Initialize vnstat for all interfaces
echo -e "${BLUE}Initializing vnstat for network interfaces...${NC}"
for iface in $(ls /sys/class/net/ | grep -v lo); do
    sudo vnstat --add -i "$iface" 2>/dev/null || echo "Interface $iface already monitored"
done

echo -e "${GREEN}✓ vnstat configured with 90-day retention${NC}"

echo ""
echo -e "${GREEN}[5/15] Creating remote user...${NC}"
# Create remote user with home directory
if id "$REMOTE_USER" &>/dev/null; then
    echo -e "${YELLOW}User $REMOTE_USER already exists${NC}"
else
    sudo useradd -m -s /bin/bash "$REMOTE_USER"
    echo "$REMOTE_USER:$REMOTE_PASSWORD" | sudo chpasswd
    echo -e "${GREEN}✓ Created user $REMOTE_USER with password${NC}"
fi

# Add remote user to necessary groups
sudo usermod -a -G plugdev,sudo "$REMOTE_USER"

# Give remote user ownership of installation directory
sudo chown -R "$REMOTE_USER:$REMOTE_USER" "$INSTALL_DIR"

# Create sudoers entry for password-free sudo access (optional, for easier management)
echo -e "${BLUE}Configuring sudo access for $REMOTE_USER...${NC}"
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart readsb" | sudo tee "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl status readsb" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl status mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/journalctl" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
echo "$REMOTE_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop mlat-client" | sudo tee -a "/etc/sudoers.d/$REMOTE_USER" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/$REMOTE_USER"

# ============================================================================
# RESTRICT REMOTE USER SSH ACCESS TO TAILSCALE NETWORK ONLY
# ============================================================================
echo ""
echo -e "${BLUE}Configuring SSH security for $REMOTE_USER...${NC}"
echo -e "${YELLOW}Restricting $REMOTE_USER SSH access to Tailscale network only${NC}"

# Backup original sshd_config if not already backed up
if [ ! -f /etc/ssh/sshd_config.backup ]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    echo -e "${GREEN}✓ Backed up original sshd_config${NC}"
fi

# Add SSH restriction for remote user at the end of sshd_config
# Check if restriction already exists
if ! sudo grep -q "Match User $REMOTE_USER" /etc/ssh/sshd_config; then
    sudo tee -a /etc/ssh/sshd_config > /dev/null <<EOF

# ============================================================================
# Security: Restrict $REMOTE_USER to Tailscale network only
# Added by ADS-B Feeder Installer v$SCRIPT_VERSION
# ============================================================================
# Allow $REMOTE_USER only from Tailscale network (100.x.x.x)
Match User $REMOTE_USER Address 100.*.*.*
    PasswordAuthentication yes
    PubkeyAuthentication yes

# Deny $REMOTE_USER from all other addresses (non-Tailscale)
Match User $REMOTE_USER Address *,!100.*.*.*
    DenyUsers $REMOTE_USER

# Reset to defaults for all other users
Match all

EOF
    echo -e "${GREEN}✓ Added SSH access restriction for $REMOTE_USER${NC}"
else
    echo -e "${YELLOW}SSH restriction for $REMOTE_USER already exists in config${NC}"
fi

# Validate sshd_config before restarting
echo -e "${BLUE}Validating SSH configuration...${NC}"
if sudo sshd -t; then
    echo -e "${GREEN}✓ SSH configuration is valid${NC}"
    
    # Restart SSH service to apply changes
    echo -e "${BLUE}Restarting SSH service...${NC}"
    sudo systemctl restart sshd
    echo -e "${GREEN}✓ SSH service restarted with new security rules${NC}"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SSH Security Configuration Applied       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}User: $REMOTE_USER${NC}"
    echo -e "${YELLOW}  ✓ Can SSH from: Any Tailscale device (100.x.x.x)${NC}"
    echo -e "${YELLOW}  ✗ Blocked from: Public internet and non-Tailscale IPs${NC}"
    echo ""
    echo -e "${GREEN}All other users (including device owner):${NC}"
    echo -e "${GREEN}  ✓ Can SSH from anywhere (unrestricted)${NC}"
    echo ""
else
    echo -e "${RED}ERROR: SSH configuration validation failed!${NC}"
    echo -e "${YELLOW}Restoring backup configuration...${NC}"
    sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    sudo systemctl restart sshd
    echo -e "${RED}SSH restriction NOT applied - please check configuration manually${NC}"
fi

echo ""
echo -e "${GREEN}[6/15] Installing Tailscale...${NC}"

# Check if Tailscale is already installed
if command -v tailscale &> /dev/null; then
    echo -e "${YELLOW}Tailscale already installed, checking status...${NC}"
    sudo tailscale status || true
else
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Authenticate Tailscale
    if [ -n "$TAILSCALE_AUTH_KEY" ]; then
        echo -e "${BLUE}Authenticating Tailscale with auth key...${NC}"
        sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --accept-routes
    else
        echo ""
        echo -e "${YELLOW}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  Manual Tailscale Authentication          ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        echo "A browser window should open for authentication."
        echo "If not, copy and paste the URL shown below into a browser."
        echo ""
        sudo tailscale up --accept-routes
        echo ""
        echo -e "${GREEN}Press Enter when authentication is complete...${NC}"
        read
    fi
fi

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)
echo -e "${GREEN}Tailscale connected! This feeder's IP: $TAILSCALE_IP${NC}"

# Test connectivity to aggregator
echo -e "${BLUE}Testing connectivity to aggregator...${NC}"
if timeout 5 bash -c "nc -zv $AGGREGATOR_TAILSCALE_IP $AGGREGATOR_BEAST_PORT" 2>&1; then
    echo -e "${GREEN}✓ Successfully connected to aggregator Beast port${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not connect to aggregator (may start later)${NC}"
fi

echo ""
echo -e "${GREEN}[7/15] Configuring RTL-SDR drivers...${NC}"

# Blacklist DVB-T drivers
sudo tee /etc/modprobe.d/blacklist-rtl.conf > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF

# Create udev rules for RTL-SDR
sudo tee /etc/udev/rules.d/rtl-sdr.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2832", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="60a1", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo -e "${GREEN}[8/15] Building and installing readsb...${NC}"
cd /tmp
# Force cleanup of any existing directory
sudo rm -rf readsb 2>/dev/null || true
git clone https://github.com/wiedehopf/readsb.git
cd readsb
make -j$(nproc) RTLSDR=yes

# Install binaries to dedicated directory
sudo cp readsb "$INSTALL_DIR/bin/"
sudo cp viewadsb "$INSTALL_DIR/bin/"
sudo chmod +x "$INSTALL_DIR/bin/readsb"
sudo chmod +x "$INSTALL_DIR/bin/viewadsb"

# Create symlinks for system-wide access
sudo ln -sf "$INSTALL_DIR/bin/readsb" /usr/local/bin/readsb
sudo ln -sf "$INSTALL_DIR/bin/viewadsb" /usr/local/bin/viewadsb

# Verify installation
if ! "$INSTALL_DIR/bin/readsb" --help > /dev/null 2>&1; then
    echo -e "${RED}ERROR: readsb installation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ readsb installed successfully to $INSTALL_DIR/bin/${NC}"

echo ""
echo -e "${GREEN}[9/15] Creating readsb user and directories...${NC}"
sudo useradd -r -M -s /usr/sbin/nologin readsb 2>/dev/null || echo "User readsb already exists"
sudo usermod -a -G plugdev readsb

# Create /run/readsb directory (will be recreated on boot via tmpfiles.d)
sudo mkdir -p /run/readsb
sudo chown readsb:readsb /run/readsb

# Set permissions on data directory
sudo chown -R readsb:readsb "$INSTALL_DIR/run"
sudo chown -R readsb:readsb "$INSTALL_DIR/data"
sudo chown -R readsb:readsb "$INSTALL_DIR/logs"

# Allow remote user to access these directories
sudo usermod -a -G readsb "$REMOTE_USER"

# Ensure /run/readsb persists across reboots (tmpfs is cleared on boot)
sudo tee /etc/tmpfiles.d/readsb.conf > /dev/null <<EOF
# Create /run/readsb directory on boot for readsb JSON output
d /run/readsb 0755 readsb readsb - -
EOF

echo -e "${BLUE}Created tmpfiles.d config to ensure /run/readsb persists across reboots${NC}"

echo ""
echo -e "${GREEN}[10/15] Installing tar1090 for local web interface...${NC}"
cd /tmp
sudo rm -rf /usr/local/share/tar1090 2>/dev/null || true
sudo git clone https://github.com/wiedehopf/tar1090.git /usr/local/share/tar1090
cd /usr/local/share/tar1090
sudo ./install.sh /run/readsb

echo ""
echo -e "${GREEN}[11/15] Creating readsb service...${NC}"

# Create configuration file (for reference, but not used by systemd)
sudo tee "$INSTALL_DIR/readsb.conf" > /dev/null <<EOF
# Readsb configuration for feeder: $FEEDER_NAME
# Installation Directory: $INSTALL_DIR
# NOTE: This file is for reference only - systemd service uses hardcoded values

# RTL-SDR device configuration
RECEIVER_OPTIONS="--device-type rtlsdr --gain $RTL_GAIN --ppm $RTL_PPM --net"

# Decoder options with location
DECODER_OPTIONS="--lat $FEEDER_LAT --lon $FEEDER_LON --max-range 360"

# Network configuration - Forward to aggregator via Tailscale
NET_OPTIONS="--net-connector $AGGREGATOR_TAILSCALE_IP,$AGGREGATOR_BEAST_PORT,beast_out"

# Local Beast output (for monitoring/debugging)
NET_OPTIONS="\$NET_OPTIONS --net-bo-port 30005"

# Local JSON output for tar1090
JSON_OPTIONS="--write-json /run/readsb --write-json-every 1"

# Enable stats
RECEIVER_OPTIONS="\$RECEIVER_OPTIONS --stats-every 3600"

# Combined options
READSB_EXTRA_ARGS="\$RECEIVER_OPTIONS \$DECODER_OPTIONS \$NET_OPTIONS \$JSON_OPTIONS"
EOF

# Create systemd service with hardcoded values
sudo tee /etc/systemd/system/readsb.service > /dev/null <<EOF
[Unit]
Description=readsb ADS-B decoder with local tar1090
Wants=network.target tailscaled.service
After=network.target tailscaled.service

[Service]
User=readsb
Type=simple
Restart=always
RestartSec=30
ExecStart=$INSTALL_DIR/bin/readsb --device-type rtlsdr --gain $RTL_GAIN --ppm $RTL_PPM --net --lat $FEEDER_LAT --lon $FEEDER_LON --max-range 360 --net-connector $AGGREGATOR_TAILSCALE_IP,$AGGREGATOR_BEAST_PORT,beast_out --net-bo-port 30005 --write-json /run/readsb --write-json-every 1 --stats-every 3600
SyslogIdentifier=readsb
Nice=-5

[Install]
WantedBy=default.target
EOF

echo ""
echo -e "${GREEN}[12/15] Installing mlat-client...${NC}"
cd /tmp
# Force cleanup of any existing directory
sudo rm -rf mlat-client 2>/dev/null || true
git clone https://github.com/wiedehopf/mlat-client.git
cd mlat-client
sudo python3 setup.py install

# Verify installation
if ! command -v mlat-client &> /dev/null; then
    echo -e "${RED}ERROR: mlat-client installation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ mlat-client installed successfully${NC}"

echo ""
echo -e "${GREEN}[13/15] Creating mlat-client service...${NC}"

# Create configuration file (for reference)
sudo tee "$INSTALL_DIR/mlat-client.conf" > /dev/null <<EOF
# MLAT Client configuration for feeder: $FEEDER_NAME
# Installation Directory: $INSTALL_DIR
# NOTE: This file is for reference only - systemd service uses hardcoded values

MLAT_OPTIONS="--input-type auto"
MLAT_OPTIONS="\$MLAT_OPTIONS --input-connect localhost:30005"
MLAT_OPTIONS="\$MLAT_OPTIONS --server $AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_MLAT_PORT"
MLAT_OPTIONS="\$MLAT_OPTIONS --lat $FEEDER_LAT --lon $FEEDER_LON --alt $FEEDER_ALT"
MLAT_OPTIONS="\$MLAT_OPTIONS --user $FEEDER_NAME"
MLAT_OPTIONS="\$MLAT_OPTIONS --results beast,connect,localhost:30104"
EOF

# Create systemd service
sudo tee /etc/systemd/system/mlat-client.service > /dev/null <<EOF
[Unit]
Description=MLAT Client for ADS-B aggregator
Wants=network.target tailscaled.service readsb.service
After=network.target tailscaled.service readsb.service

[Service]
Type=simple
Restart=always
RestartSec=30
ExecStart=/usr/local/bin/mlat-client --input-type auto --input-connect localhost:30005 --server $AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_MLAT_PORT --lat $FEEDER_LAT --lon $FEEDER_LON --alt $FEEDER_ALT --user $FEEDER_NAME --results beast,connect,localhost:30104
SyslogIdentifier=mlat-client
User=readsb

[Install]
WantedBy=default.target
EOF

echo ""
echo -e "${GREEN}[14/15] Creating system update command...${NC}"

# Create adsb-update script in system path
sudo tee /usr/local/bin/adsb-update > /dev/null <<'UPDATEEOF'
#!/bin/bash
# ADS-B Feeder System Updater
# Updates components of the ADS-B feeder system

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_RAW_URL="https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/adsb_feeder_installer.sh"
INSTALL_DIR="/opt/TAK_ADSB"

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ADS-B Feeder System Updater             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Show usage if no arguments or --help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: adsb-update [component]"
    echo ""
    echo "Components:"
    echo "  readsb     - Update readsb decoder only"
    echo "  mlat       - Update mlat-client only"
    echo "  tar1090    - Update tar1090 web interface only"
    echo "  system     - Update system packages only"
    echo "  installer  - Update installer script only"
    echo "  all        - Update everything (recommended)"
    echo "  (no args)  - Update installer script only"
    echo ""
    echo "Examples:"
    echo "  adsb-update              # Update installer script"
    echo "  adsb-update all          # Update all components"
    echo "  adsb-update readsb       # Update only readsb"
    echo ""
    exit 0
fi

# Check what needs updating
echo -e "${BLUE}Checking for updates...${NC}"
echo ""

# Update readsb if requested
if [ "$1" = "readsb" ] || [ "$1" = "all" ]; then
    echo -e "${YELLOW}Updating readsb...${NC}"
    cd /tmp
    sudo rm -rf readsb 2>/dev/null || true
    git clone https://github.com/wiedehopf/readsb.git
    cd readsb
    make -j$(nproc) RTLSDR=yes
    sudo systemctl stop readsb
    sudo cp readsb "$INSTALL_DIR/bin/"
    sudo cp viewadsb "$INSTALL_DIR/bin/"
    sudo chmod +x "$INSTALL_DIR/bin/readsb"
    sudo chmod +x "$INSTALL_DIR/bin/viewadsb"
    sudo systemctl start readsb
    echo -e "${GREEN}✓ readsb updated and restarted${NC}"
    echo ""
fi

# Update mlat-client if requested
if [ "$1" = "mlat" ] || [ "$1" = "all" ]; then
    echo -e "${YELLOW}Updating mlat-client...${NC}"
    cd /tmp
    sudo rm -rf mlat-client 2>/dev/null || true
    git clone https://github.com/wiedehopf/mlat-client.git
    cd mlat-client
    sudo systemctl stop mlat-client
    sudo python3 setup.py install
    sudo systemctl start mlat-client
    echo -e "${GREEN}✓ mlat-client updated and restarted${NC}"
    echo ""
fi

# Update tar1090 if requested
if [ "$1" = "tar1090" ] || [ "$1" = "all" ]; then
    echo -e "${YELLOW}Updating tar1090...${NC}"
    cd /tmp
    sudo rm -rf /usr/local/share/tar1090.backup 2>/dev/null || true
    sudo mv /usr/local/share/tar1090 /usr/local/share/tar1090.backup 2>/dev/null || true
    sudo git clone https://github.com/wiedehopf/tar1090.git /usr/local/share/tar1090
    cd /usr/local/share/tar1090
    sudo ./install.sh /run/readsb
    sudo systemctl restart lighttpd
    echo -e "${GREEN}✓ tar1090 updated${NC}"
    echo ""
fi

# System packages
if [ "$1" = "system" ] || [ "$1" = "all" ]; then
    echo -e "${YELLOW}Updating system packages...${NC}"
    sudo apt-get update
    sudo apt-get upgrade -y
    echo -e "${GREEN}✓ System packages updated${NC}"
    echo ""
fi

# Download latest installer script
if [ "$1" = "installer" ] || [ "$1" = "all" ] || [ -z "$1" ]; then
    echo -e "${YELLOW}Updating installer script...${NC}"
    TEMP_SCRIPT=$(mktemp)
    if curl -fsSL "$GITHUB_RAW_URL" -o "$TEMP_SCRIPT" 2>/dev/null; then
        # Get current version if it exists
        if [ -f "$INSTALL_DIR/scripts/adsb_feeder_installer.sh" ]; then
            CURRENT_VERSION=$(grep '^SCRIPT_VERSION=' "$INSTALL_DIR/scripts/adsb_feeder_installer.sh" 2>/dev/null | head -1 | cut -d'"' -f2)
        else
            CURRENT_VERSION="Not installed"
        fi
        
        # Get new version
        NEW_VERSION=$(grep '^SCRIPT_VERSION=' "$TEMP_SCRIPT" 2>/dev/null | head -1 | cut -d'"' -f2)
        
        if [ "$CURRENT_VERSION" = "$NEW_VERSION" ] && [ "$CURRENT_VERSION" != "Not installed" ]; then
            echo -e "${GREEN}✓ Installer script is already up to date (v$CURRENT_VERSION)${NC}"
        else
            sudo mkdir -p "$INSTALL_DIR/scripts"
            sudo mv "$TEMP_SCRIPT" "$INSTALL_DIR/scripts/adsb_feeder_installer.sh"
            sudo chmod +x "$INSTALL_DIR/scripts/adsb_feeder_installer.sh"
            echo -e "${GREEN}✓ Installer script updated: v$CURRENT_VERSION → v$NEW_VERSION${NC}"
            echo -e "${BLUE}  Location: $INSTALL_DIR/scripts/adsb_feeder_installer.sh${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to download installer update${NC}"
        rm -f "$TEMP_SCRIPT"
    fi
    echo ""
fi

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Update Complete!                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Service Status:${NC}"
if [ "$1" = "readsb" ] || [ "$1" = "mlat" ] || [ "$1" = "all" ]; then
    systemctl is-active --quiet readsb && echo -e "${GREEN}  ✓ readsb running${NC}" || echo -e "${RED}  ✗ readsb not running${NC}"
    systemctl is-active --quiet mlat-client && echo -e "${GREEN}  ✓ mlat-client running${NC}" || echo -e "${YELLOW}  ⚠ mlat-client status uncertain${NC}"
fi
echo ""
UPDATEEOF

sudo chmod +x /usr/local/bin/adsb-update
echo -e "${GREEN}✓ Created system update command: adsb-update${NC}"

# Save a copy of this installer to the installation directory
echo -e "${BLUE}Saving installer script to $INSTALL_DIR/scripts/${NC}"

if [ -f "$SCRIPT_PATH" ]; then
    sudo cp "$SCRIPT_PATH" "$INSTALL_DIR/scripts/adsb_feeder_installer.sh"
    sudo chmod +x "$INSTALL_DIR/scripts/adsb_feeder_installer.sh"
    echo -e "${GREEN}✓ Installer script saved${NC}"
else
    echo -e "${YELLOW}⚠ Could not save installer script (script path: $SCRIPT_PATH)${NC}"
    echo -e "${YELLOW}  You can manually copy it later if needed${NC}"
fi

echo ""
echo -e "${GREEN}[15/15] Starting services...${NC}"

# Reload systemd
sudo systemctl daemon-reload

# Enable and start services
echo -e "${BLUE}Enabling services to start on boot...${NC}"
sudo systemctl enable readsb

# Enable MLAT only if user opted in
if [ "$ENABLE_MLAT" = true ]; then
    sudo systemctl enable mlat-client
else
    sudo systemctl disable mlat-client 2>/dev/null || true
fi

echo -e "${BLUE}Starting readsb...${NC}"
sudo systemctl restart readsb
sleep 3

# Start MLAT only if user opted in
if [ "$ENABLE_MLAT" = true ]; then
    echo -e "${BLUE}Starting mlat-client...${NC}"
    sudo systemctl restart mlat-client
    sleep 2
else
    echo -e "${YELLOW}MLAT disabled - skipping mlat-client start${NC}"
    sudo systemctl stop mlat-client 2>/dev/null || true
fi

# Check service status
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Service Status                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"

if systemctl is-active --quiet readsb; then
    echo -e "${GREEN}✓ readsb is running${NC}"
else
    echo -e "${RED}✗ readsb failed to start${NC}"
    sudo systemctl status readsb --no-pager
fi

if [ "$ENABLE_MLAT" = true ]; then
    if systemctl is-active --quiet mlat-client; then
        echo -e "${GREEN}✓ mlat-client is running${NC}"
    else
        echo -e "${YELLOW}⚠ mlat-client status uncertain (may need aggregator running)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ mlat-client is disabled (not started)${NC}"
fi

# ============================================================================
# INSTALLATION COMPLETE
# ============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}║     Installation Complete! 🎉             ║${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Feeder Information:${NC}"
echo "  Name:              $FEEDER_NAME"
echo "  Location:          $FEEDER_LAT, $FEEDER_LON ($FEEDER_ALT m)"
echo "  Tailscale IP:      $TAILSCALE_IP"
echo "  Installation Dir:  $INSTALL_DIR"
echo ""
echo -e "${YELLOW}Feeding Configuration:${NC}"
echo "  Aggregator:        $AGGREGATOR_TAILSCALE_IP"
echo "  Beast Port:        $AGGREGATOR_BEAST_PORT"
echo "  MLAT Port:         $AGGREGATOR_MLAT_PORT"
if [ "$ENABLE_MLAT" = true ]; then
    echo "  MLAT Status:       Enabled"
else
    echo "  MLAT Status:       Disabled (conserving bandwidth)"
fi
echo ""
echo -e "${YELLOW}Local Services:${NC}"
echo "  tar1090 Map:       http://$(hostname -I | awk '{print $1}')/tar1090/"
echo "  Beast Output:      localhost:30005"
echo "  MLAT Results:      localhost:30104"
echo ""
echo -e "${YELLOW}Remote Access (Tailscale Only):${NC}"
echo "  SSH User:          $REMOTE_USER"
echo "  SSH Password:      $REMOTE_PASSWORD"
echo "  Access:            ssh $REMOTE_USER@$TAILSCALE_IP"
echo "  Restriction:       Only accessible from Tailscale network (100.x.x.x)"
echo ""
echo -e "${YELLOW}Network Monitoring:${NC}"
echo "  vnstat:            90-day data retention enabled"
echo "  Check usage:       vnstat -d (daily) | vnstat -m (monthly)"
echo ""
echo -e "${YELLOW}Update Commands:${NC}"
echo "  Update installer:  ./adsb_feeder_installer.sh --update"
echo "  Update all:        adsb-update all"
echo "  Update readsb:     adsb-update readsb"
echo "  Update mlat:       adsb-update mlat"
echo "  Update tar1090:    adsb-update tar1090"
echo "  Update system:     adsb-update system"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Check readsb:      sudo systemctl status readsb"
echo "  Check MLAT:        sudo systemctl status mlat-client"
echo "  View readsb logs:  sudo journalctl -u readsb -f"
echo "  View MLAT logs:    sudo journalctl -u mlat-client -f"
echo "  Restart readsb:    sudo systemctl restart readsb"
echo "  Restart MLAT:      sudo systemctl restart mlat-client"
echo "  Check Tailscale:   sudo tailscale status"
echo "  View data usage:   vnstat"
echo ""
echo -e "${YELLOW}MLAT Control:${NC}"
echo "  Enable MLAT:       sudo systemctl enable mlat-client && sudo systemctl start mlat-client"
echo "  Disable MLAT:      sudo systemctl stop mlat-client && sudo systemctl disable mlat-client"
echo "  Check MLAT status: sudo systemctl status mlat-client"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Verify aircraft are being tracked: http://$(hostname -I | awk '{print $1}')/tar1090/"
echo "  2. Check aggregator is receiving data (if running)"
echo "  3. Monitor system with: vnstat -l (live traffic)"
if [ "$ENABLE_MLAT" = false ]; then
    echo "  4. To enable MLAT later: sudo systemctl enable mlat-client && sudo systemctl start mlat-client"
fi
echo ""
echo -e "${YELLOW}Security Note:${NC}"
echo "  The '$REMOTE_USER' account can ONLY be accessed from Tailscale network"
echo "  Device owner accounts can SSH from anywhere"
echo ""
echo -e "${GREEN}GitHub Repository: https://github.com/cfd2474/TAK-ADSB-Feeder${NC}"
echo ""
