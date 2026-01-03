#!/bin/bash
# ADS-B Feeder Auto-Installer for Raspberry Pi
# Configures RTL-SDR dongle to feed ADS-B data to aggregation server via Tailscale
# Version 2.0 - Production Ready

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ADS-B Feeder Installer v2.0             ║${NC}"
echo -e "${GREEN}║   with Tailscale Integration              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# CONFIGURATION - EDIT THESE VALUES FOR YOUR DEPLOYMENT
# ============================================================================

# Aggregator Tailscale IP (update this to match your aggregator)
AGGREGATOR_TAILSCALE_IP="100.117.34.88"
AGGREGATOR_BEAST_PORT="30004"
AGGREGATOR_MLAT_PORT="30105"

# Tailscale auth key (get from https://login.tailscale.com/admin/settings/keys)
# Leave empty to authenticate manually during installation
TAILSCALE_AUTH_KEY="tskey-auth-k3xBs92iA311CNTRL-S7VXRw4MaT4i5FH6gAuCU4sbWyvfYprT6"

# Default location (will prompt if empty)
FEEDER_LAT=""
FEEDER_LON=""
FEEDER_ALT=""  # Altitude in meters

# RTL-SDR Configuration
RTL_GAIN="-10"  # -10 for auto gain, or specific value like 49.6
RTL_PPM="0"     # PPM correction

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: Do not run this script as root!${NC}"
    echo "Run as: ./adsb_feeder_installer_v2.sh"
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
echo "  Location:         $FEEDER_LAT, $FEEDER_LON"
echo "  Altitude:         ${FEEDER_ALT}m"
echo "  Aggregator IP:    $AGGREGATOR_TAILSCALE_IP"
echo "  Beast Port:       $AGGREGATOR_BEAST_PORT"
echo "  MLAT Port:        $AGGREGATOR_MLAT_PORT"
echo "  RTL-SDR Gain:     $RTL_GAIN"
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
echo -e "${GREEN}[1/9] Updating system packages...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

echo ""
echo -e "${GREEN}[2/9] Installing dependencies...${NC}"
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
    pkg-config

echo ""
echo -e "${GREEN}[3/9] Installing Tailscale...${NC}"

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
        echo -e "${YELLOW}Please authenticate Tailscale:${NC}"
        sudo tailscale up --accept-routes
        echo "Press Enter when authentication is complete..."
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
echo -e "${GREEN}[4/9] Configuring RTL-SDR drivers...${NC}"

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
echo -e "${GREEN}[5/9] Building and installing readsb...${NC}"
cd /tmp
rm -rf readsb 2>/dev/null || true
git clone https://github.com/wiedehopf/readsb.git
cd readsb
make -j$(nproc) RTLSDR=yes

# Install binaries
sudo cp readsb /usr/local/bin/
sudo cp viewadsb /usr/local/bin/
sudo chmod +x /usr/local/bin/readsb
sudo chmod +x /usr/local/bin/viewadsb

# Verify installation
if ! /usr/local/bin/readsb --help > /dev/null 2>&1; then
    echo -e "${RED}ERROR: readsb installation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ readsb installed successfully${NC}"

echo ""
echo -e "${GREEN}[6/9] Creating readsb user and directories...${NC}"
sudo useradd -r -M -s /usr/sbin/nologin readsb 2>/dev/null || echo "User readsb already exists"
sudo usermod -a -G plugdev readsb
sudo mkdir -p /run/readsb
sudo chown readsb:readsb /run/readsb

echo ""
echo -e "${GREEN}[7/9] Creating readsb service...${NC}"

# Create configuration file (for reference, but not used by systemd)
sudo tee /etc/default/readsb > /dev/null <<EOF
# Readsb configuration for feeder: $FEEDER_NAME
# NOTE: This file is for reference only - systemd service uses hardcoded values

# RTL-SDR device configuration
RECEIVER_OPTIONS="--device-type rtlsdr --gain $RTL_GAIN --ppm $RTL_PPM --net"

# Decoder options with location
DECODER_OPTIONS="--lat $FEEDER_LAT --lon $FEEDER_LON --max-range 360"

# Network configuration - Forward to aggregator via Tailscale
NET_OPTIONS="--net-connector $AGGREGATOR_TAILSCALE_IP,$AGGREGATOR_BEAST_PORT,beast_out"

# Local Beast output (for monitoring/debugging)
NET_OPTIONS="\$NET_OPTIONS --net-bo-port 30005"

# Enable stats
RECEIVER_OPTIONS="\$RECEIVER_OPTIONS --stats-every 3600"

# Combined options
READSB_EXTRA_ARGS="\$RECEIVER_OPTIONS \$DECODER_OPTIONS \$NET_OPTIONS"
EOF

# Create systemd service with hardcoded values (lessons learned!)
sudo tee /etc/systemd/system/readsb.service > /dev/null <<EOF
[Unit]
Description=readsb ADS-B decoder
Wants=network.target tailscaled.service
After=network.target tailscaled.service

[Service]
User=readsb
Type=simple
Restart=always
RestartSec=30
ExecStart=/usr/local/bin/readsb --device-type rtlsdr --gain $RTL_GAIN --ppm $RTL_PPM --net --lat $FEEDER_LAT --lon $FEEDER_LON --max-range 360 --net-connector $AGGREGATOR_TAILSCALE_IP,$AGGREGATOR_BEAST_PORT,beast_out --net-bo-port 30005 --stats-every 3600
SyslogIdentifier=readsb
Nice=-5

[Install]
WantedBy=default.target
EOF

echo ""
echo -e "${GREEN}[8/9] Installing mlat-client...${NC}"
cd /tmp
rm -rf mlat-client 2>/dev/null || true
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
echo -e "${GREEN}[9/9] Creating mlat-client service...${NC}"

# Create configuration file (for reference)
sudo tee /etc/default/mlat-client > /dev/null <<EOF
# MLAT Client configuration for feeder: $FEEDER_NAME
# NOTE: This file is for reference only - systemd service uses hardcoded values

MLAT_OPTIONS="--input-type auto"
MLAT_OPTIONS="\$MLAT_OPTIONS --input-connect localhost:30005"
MLAT_OPTIONS="\$MLAT_OPTIONS --server $AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_MLAT_PORT"
MLAT_OPTIONS="\$MLAT_OPTIONS --lat $FEEDER_LAT --lon $FEEDER_LON --alt $FEEDER_ALT"
MLAT_OPTIONS="\$MLAT_OPTIONS --user $FEEDER_NAME"

MLAT_EXTRA_ARGS="\$MLAT_OPTIONS"
EOF

# Create systemd service with hardcoded values
sudo tee /etc/systemd/system/mlat-client.service > /dev/null <<EOF
[Unit]
Description=MLAT Client
Wants=network.target readsb.service tailscaled.service
After=network.target readsb.service tailscaled.service

[Service]
Type=simple
Restart=always
RestartSec=30
ExecStart=/usr/local/bin/mlat-client --input-type auto --input-connect localhost:30005 --server $AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_MLAT_PORT --lat $FEEDER_LAT --lon $FEEDER_LON --alt $FEEDER_ALT --user $FEEDER_NAME
SyslogIdentifier=mlat-client
Nice=-5

[Install]
WantedBy=default.target
EOF

# ============================================================================
# START SERVICES
# ============================================================================

echo ""
echo -e "${BLUE}Enabling and starting services...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable readsb
sudo systemctl enable mlat-client

sudo systemctl restart readsb
sleep 5
sudo systemctl restart mlat-client
sleep 3

# ============================================================================
# VERIFICATION
# ============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation Complete!                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Feeder Details:${NC}"
echo "  Name:             $FEEDER_NAME"
echo "  Tailscale IP:     $TAILSCALE_IP"
echo "  Location:         $FEEDER_LAT, $FEEDER_LON @ ${FEEDER_ALT}m"
echo "  Aggregator:       $AGGREGATOR_TAILSCALE_IP"
echo ""

echo -e "${YELLOW}Service Status:${NC}"
if sudo systemctl is-active --quiet readsb; then
    echo -e "  readsb:       ${GREEN}✓ Running${NC}"
else
    echo -e "  readsb:       ${RED}✗ Not running${NC}"
fi

if sudo systemctl is-active --quiet mlat-client; then
    echo -e "  mlat-client:  ${GREEN}✓ Running${NC}"
else
    echo -e "  mlat-client:  ${RED}✗ Not running${NC}"
fi

if sudo systemctl is-active --quiet tailscaled; then
    echo -e "  tailscale:    ${GREEN}✓ Connected${NC}"
else
    echo -e "  tailscale:    ${RED}✗ Not connected${NC}"
fi

echo ""
echo -e "${YELLOW}Network Connections:${NC}"
BEAST_CONN=$(netstat -tn 2>/dev/null | grep "$AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_BEAST_PORT" | grep ESTABLISHED || echo "")
MLAT_CONN=$(netstat -tn 2>/dev/null | grep "$AGGREGATOR_TAILSCALE_IP:$AGGREGATOR_MLAT_PORT" | grep ESTABLISHED || echo "")

if [ -n "$BEAST_CONN" ]; then
    echo -e "  Beast (30004): ${GREEN}✓ Connected${NC}"
else
    echo -e "  Beast (30004): ${YELLOW}⚠ Not connected (may take a moment)${NC}"
fi

if [ -n "$MLAT_CONN" ]; then
    echo -e "  MLAT (30105):  ${GREEN}✓ Connected${NC}"
else
    echo -e "  MLAT (30105):  ${YELLOW}⚠ Not connected (may take a moment)${NC}"
fi

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Check service logs:"
echo "    sudo journalctl -fu readsb"
echo "    sudo journalctl -fu mlat-client"
echo ""
echo "  Check service status:"
echo "    sudo systemctl status readsb"
echo "    sudo systemctl status mlat-client"
echo ""
echo "  Check network connections:"
echo "    netstat -tn | grep $AGGREGATOR_TAILSCALE_IP"
echo ""
echo "  View live aircraft data:"
echo "    /usr/local/bin/viewadsb"
echo ""
echo "  Restart services:"
echo "    sudo systemctl restart readsb"
echo "    sudo systemctl restart mlat-client"
echo ""

# Save feeder info to file
sudo tee /etc/adsb-feeder-info.txt > /dev/null <<EOF
Feeder Name: $FEEDER_NAME
Feeder Tailscale IP: $TAILSCALE_IP
Aggregator IP: $AGGREGATOR_TAILSCALE_IP
Location: $FEEDER_LAT, $FEEDER_LON @ ${FEEDER_ALT}m
Installation Date: $(date)
EOF

echo -e "${GREEN}Feeder information saved to: /etc/adsb-feeder-info.txt${NC}"
echo ""
echo -e "${BLUE}If connections are not showing as established, wait 30-60 seconds${NC}"
echo -e "${BLUE}and check again. Services restart automatically on failure.${NC}"
echo ""
echo -e "${GREEN}Happy plane spotting! ✈️${NC}"
