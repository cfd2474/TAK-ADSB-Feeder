# Save this as: test_local_tar1090.sh
# Run on a Pi feeder to test

#!/bin/bash

echo "=== Local tar1090 Installation for Pi Feeder ==="
echo ""

# Configuration
AGGREGATOR_IP="100.117.34.88"
AGGREGATOR_PORT="30004"

# Extract existing lat/lon from current readsb service
echo "Detecting existing configuration..."
if [ -f /etc/systemd/system/readsb.service ]; then
    FEEDER_LAT=$(grep "ExecStart" /etc/systemd/system/readsb.service | grep -oP '\-\-lat \K[0-9.-]+')
    FEEDER_LON=$(grep "ExecStart" /etc/systemd/system/readsb.service | grep -oP '\-\-lon \K[0-9.-]+')
    CURRENT_GAIN=$(grep "ExecStart" /etc/systemd/system/readsb.service | grep -oP '\-\-gain \K[^ ]+' || echo "-10")
    CURRENT_PPM=$(grep "ExecStart" /etc/systemd/system/readsb.service | grep -oP '\-\-ppm \K[^ ]+' || echo "0")
    
    echo "  Latitude:  $FEEDER_LAT"
    echo "  Longitude: $FEEDER_LON"
    echo "  Gain:      $CURRENT_GAIN"
    echo "  PPM:       $CURRENT_PPM"
else
    echo "ERROR: No existing readsb service found!"
    echo "This script requires readsb to already be installed and configured."
    exit 1
fi

# Verify we got valid coordinates
if [ -z "$FEEDER_LAT" ] || [ -z "$FEEDER_LON" ]; then
    echo "ERROR: Could not detect lat/lon from existing configuration!"
    echo "Please check /etc/systemd/system/readsb.service"
    exit 1
fi

# Check if readsb is already running
if systemctl is-active --quiet readsb; then
    echo ""
    echo "readsb is currently running. Stopping temporarily..."
    sudo systemctl stop readsb
fi

# Install dependencies
echo ""
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y lighttpd git

# Install tar1090
echo ""
echo "Installing tar1090..."
cd /tmp
sudo rm -rf /usr/local/share/tar1090 2>/dev/null
sudo git clone https://github.com/wiedehopf/tar1090.git /usr/local/share/tar1090
cd /usr/local/share/tar1090
sudo ./install.sh /run/readsb

# Backup current config
echo ""
echo "Backing up current configuration..."
sudo cp /etc/systemd/system/readsb.service /etc/systemd/system/readsb.service.backup.$(date +%Y%m%d_%H%M%S)

# Update readsb service to include local tar1090 support
echo "Updating readsb configuration to support local tar1090..."

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
ExecStart=/usr/local/bin/readsb \\
    --device-type rtlsdr \\
    --gain $CURRENT_GAIN \\
    --ppm $CURRENT_PPM \\
    --net \\
    --lat $FEEDER_LAT \\
    --lon $FEEDER_LON \\
    --max-range 360 \\
    --net-connector $AGGREGATOR_IP,$AGGREGATOR_PORT,beast_out \\
    --net-bo-port 30005 \\
    --write-json /run/readsb \\
    --write-json-every 1 \\
    --stats-every 3600
SyslogIdentifier=readsb
Nice=-5

[Install]
WantedBy=default.target
EOF

# Reload and restart
echo ""
echo "Restarting services..."
sudo systemctl daemon-reload
sudo systemctl enable lighttpd
sudo systemctl start lighttpd
sudo systemctl restart readsb

# Wait for data
echo ""
echo "Waiting 10 seconds for data collection..."
sleep 10

# Get Pi's IP address
PI_IP=$(hostname -I | awk '{print $1}')
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")

# Test
echo ""
echo "================================================================"
echo "=== Installation Complete ==="
echo "================================================================"
echo ""
echo "📍 Location: $FEEDER_LAT, $FEEDER_LON"
echo ""
echo "🌐 Access local tar1090:"
echo "   http://$PI_IP/tar1090/"
if [ "$TAILSCALE_IP" != "N/A" ]; then
    echo "   http://$TAILSCALE_IP/tar1090/ (via Tailscale)"
fi
echo ""
echo "📡 Still feeding aggregator at: $AGGREGATOR_IP:$AGGREGATOR_PORT"
echo ""
echo "✅ Check status:"
echo "   sudo systemctl status readsb"
echo "   sudo systemctl status lighttpd"
echo ""
echo "📊 Test local data:"
echo "   curl http://localhost/tar1090/data/aircraft.json | python3 -m json.tool | head -30"
echo ""
echo "🔍 Compare:"
echo "   Local Pi:    http://$PI_IP/tar1090/"
echo "   Aggregator:  http://104.225.219.254/tar1090/"
echo ""
echo "Original config backed up to:"
echo "   /etc/systemd/system/readsb.service.backup.*"
echo ""
