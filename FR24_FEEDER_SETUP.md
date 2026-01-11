# FlightRadar24 Feeder Setup Guide

## Overview
This guide covers installing and configuring FR24feed to share ADS-B data with FlightRadar24 when you already have readsb running on your system.

## Prerequisites
- Working readsb installation with Beast output enabled on port 30005
- Active internet connection
- Precise antenna coordinates (latitude, longitude, altitude)

## Installation

### 1. Download and Install FR24feed

```bash
# Download the latest FR24feed package (arm64 for Raspberry Pi 4/5)
wget https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.54-0_arm64.deb

# Install the package
sudo dpkg -i fr24feed_1.0.54-0_arm64.deb

# If you get dependency errors, fix them with:
sudo apt-get install -f
```

### 2. Initial Configuration

**IMPORTANT:** Before running the signup wizard, gather this information:
- Your antenna's **precise coordinates** (use Google Maps or GPS)
  - Latitude in decimal format (e.g., 33.6235)
  - Longitude in decimal format (e.g., -117.1271)
  - Altitude in feet above sea level (not ground level)
- Your existing FR24 sharing key (if you've fed before), or leave empty for a new one

Run the signup wizard:

```bash
sudo fr24feed --signup
```

### 3. Signup Wizard Answers

When prompted, provide these answers:

| Question | Answer | Notes |
|----------|--------|-------|
| Email address | your@email.com | Your FR24 account email |
| Sharing key | [existing key or ENTER] | Leave empty if new signup |
| MLAT participation | **yes** | Required to configure position |
| Latitude | XX.XXXX | 4 decimal places recommended |
| Longitude | -XXX.XXXX | 4 decimal places recommended |
| Altitude (feet) | XXXX | Feet above sea level |
| Receiver type | **4** | Mode-S Beast (USB/Network) |
| Connection type | **1** | Network connection |
| Host/IP address | **127.0.0.1:30005** | Local readsb Beast output |
| RAW data feed port 30334 | **no** | readsb already provides this |
| BaseStation feed port 30003 | **no** | readsb already provides this |

### 4. Critical Configuration Fix

**IMPORTANT:** The signup wizard may configure `receiver="avr-tcp"` by default, but readsb outputs Beast format. You must manually fix this.

Edit the configuration file:

```bash
sudo nano /etc/fr24feed.ini
```

Change this line:
```ini
receiver="avr-tcp"
```

To this:
```ini
receiver="beast-tcp"
```

Your complete configuration should look like:

```ini
receiver="beast-tcp"
fr24key="YOUR_SHARING_KEY"
host="127.0.0.1:30005"
bs="no"
raw="no"
mlat="yes"
mlat-without-gps="yes"
lat=XX.XXXX
lon=-XXX.XXXX
alt=XXXX
```

**Save and exit** (Ctrl+X, Y, Enter)

### 5. Start and Enable FR24feed

```bash
# Enable service to start on boot
sudo systemctl enable fr24feed

# Start the service
sudo systemctl start fr24feed

# Wait 30-60 seconds for initialization
sleep 30

# Check status
fr24feed-status
```

## Verifying Operation

### Check FR24feed Status

```bash
fr24feed-status
```

Expected output when working correctly:
```
FR24 Feeder/Decoder Process: running.
FR24 Stats Timestamp: 2026-01-11 03:42:52.
FR24 Link: connected [TCP].
FR24 Radar: T-XXXXXX.
FR24 Tracked AC: 23.
Receiver: connected (14225 MSGS/0 SYNC).
```

**Key indicators:**
- ✅ `FR24 Link: connected` - Successfully feeding to FR24 servers
- ✅ `Receiver: connected` - Successfully receiving data from readsb
- ✅ `FR24 Tracked AC: >0` - Actually tracking aircraft
- ✅ High message count - Data flowing properly

### Check Logs

```bash
# View recent logs
journalctl -u fr24feed -n 50

# Follow logs in real-time
journalctl -u fr24feed -f
```

### Web Interface

Access the FR24feed web interface:
```
http://[PI_IP_ADDRESS]:8754
```

### Monitor on FR24 Website

Check your feeder status:
1. Go to https://www.flightradar24.com/account/data-sharing
2. Look for your Radar ID (T-XXXXXX)
3. Verify it shows as online and feeding

## Troubleshooting

### Issue: "FR24 Tracked AC: 0"

**Cause:** Wrong receiver type (avr-tcp instead of beast-tcp)

**Solution:**
```bash
sudo nano /etc/fr24feed.ini
# Change receiver="avr-tcp" to receiver="beast-tcp"
sudo systemctl restart fr24feed
```

### Issue: "Receiver: down ... failed!"

**Causes:**
1. readsb not running
2. Wrong host/port in config
3. readsb not outputting Beast format on port 30005

**Solutions:**
```bash
# Verify readsb is running
systemctl status readsb

# Check Beast output is available
timeout 3 nc 127.0.0.1 30005 | hexdump -C | head -5

# Verify readsb command includes: --net-bo-port 30005
ps aux | grep readsb
```

### Issue: "FR24 Link: unknown ... failed!"

**Causes:**
1. NTP time sync failure
2. Network connectivity issues
3. Missing coordinates in config

**Solutions:**
```bash
# Fix time sync
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd

# Verify coordinates are in config
grep -E "lat|lon|alt" /etc/fr24feed.ini

# Test internet connectivity
ping -c 3 8.8.8.8
```

### Issue: "MLAT not working"

**Error in logs:** `[mlat][e]Receiver not compatible with MLAT, timestamps in wrong format!`

**Cause:** readsb not outputting timestamps in the format FR24 expects

**Impact:** MLAT won't work, but regular ADS-B feeding will work fine

**Solution (optional):** This is a known limitation when using readsb with FR24. Regular ADS-B feeding (which is the primary benefit) works perfectly without MLAT.

### Issue: Missing log directory

```bash
# Create log directory manually
sudo mkdir -p /var/log/fr24feed
sudo chown fr24:fr24 /var/log/fr24feed

# Enable logging in config
sudo nano /etc/fr24feed.ini
# Add these lines:
# logmode="2"
# logpath="/var/log/fr24feed"

sudo systemctl restart fr24feed
```

## Complete Removal (if needed)

To completely remove FR24feed:

```bash
# Stop and disable service
sudo systemctl stop fr24feed
sudo systemctl disable fr24feed

# Remove package
sudo dpkg --purge fr24feed

# Remove configuration and logs
sudo rm -rf /etc/fr24feed.ini
sudo rm -rf /var/log/fr24feed/
sudo rm -f /dev/shm/decoder.txt

# Remove user (if desired)
sudo userdel -r fr24 2>/dev/null

# Clean up
sudo apt autoremove
```

## Port Usage

FR24feed uses these ports:

| Port | Purpose | Notes |
|------|---------|-------|
| 8754 | Web interface | Access at http://[PI_IP]:8754 |
| 30005 | Beast input (client) | Connects to readsb's Beast output |

FR24feed does **not** need to serve data on ports 30002, 30003, or 30334 because readsb already provides those feeds for other applications.

## Benefits of FR24 Feeding

Once you maintain consistent uptime feeding FR24:
- **Business Subscription** - Normally $499/year, free for active feeders
- Access to enhanced features on FlightRadar24.com
- Support the global ADS-B network

## Key Takeaways

1. **Use `receiver="beast-tcp"`** - Not `avr-tcp` - when connecting to readsb
2. **Precise coordinates are critical** - Use 4+ decimal places for MLAT
3. **Disable RAW/BS feeds** - Let readsb handle those ports
4. **Be patient** - Can take 5-10 minutes to show tracked aircraft after startup
5. **MLAT limitation** - Works fine without it; regular ADS-B feeding is the primary value

## Related Documentation

- [readsb Setup Guide](link_to_your_readsb_docs)
- [ADS-B Aggregator Setup](link_to_your_aggregator_docs)
- [Official FR24 Manual](https://repo-feed.flightradar24.com/fr24feed-manual.pdf)

---

*Last updated: January 2026*
