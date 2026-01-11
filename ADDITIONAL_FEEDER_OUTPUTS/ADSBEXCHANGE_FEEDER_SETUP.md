# ADS-B Exchange Feeder Setup Guide

## Overview
This guide covers adding ADS-B Exchange feeding to your existing readsb-based ADS-B feeder. The ADSBx feeder client will run alongside your current setup without conflicts.

## What is ADS-B Exchange?
ADS-B Exchange is the world's largest unfiltered flight tracking network:
- Complete, unfiltered aircraft data (including military, private, VIP)
- Community-driven and independent
- Free API access (with limits)
- MLAT (multilateration) support
- Optional stats package with local map

## Prerequisites
- Working readsb installation
- Beast output enabled on port 30005
- Active internet connection
- SSH access to your Pi

## Installation

### Step 1: Find Your Coordinates and Elevation

Use this tool to find your precise location:
https://www.freemaptools.com/elevation-finder.htm

You'll need:
- **Latitude** in decimal format (e.g., 33.6235)
- **Longitude** in decimal format (e.g., -117.1271)  
- **Elevation** in feet above sea level (e.g., 1440)

### Step 2: Install the ADS-B Exchange Feed Client

Run the automated installer:

```bash
curl -L -o /tmp/axfeed.sh https://www.adsbexchange.com/feed.sh
sudo bash /tmp/axfeed.sh
```

The installer will:
1. Prompt for your antenna coordinates and elevation
2. Detect your existing readsb installation
3. Configure the feed client automatically
4. Set up systemd services for automatic startup
5. Configure MLAT client

**During installation:**
- Enter your precise coordinates when prompted
- Provide elevation in **feet** (not meters like other services)
- The script will auto-detect your readsb Beast output on `127.0.0.1:30005`
- The script will not disrupt your existing feeds

### Step 3: Verify the Feed is Working

Check your feeder status on the ADS-B Exchange website:

**https://www.adsbexchange.com/myip/**

You should see:
- Your feeder listed as "Connected"
- Number of aircraft being received
- Data rate statistics
- Your approximate location

Check that network connections are established:

```bash
netstat -t -n | grep -E '30004|31090'
```

**Expected output shows connections to ADS-B Exchange servers**

### Step 4: Check MLAT Synchronization

Visit the MLAT sync map:

**https://map.adsbexchange.com/mlat-map/**

Your feeder should appear on the map once MLAT synchronization is achieved (may take 10-30 minutes after first connection).

## Optional: Install Stats Package

The stats package provides a local web interface showing only aircraft received by your feeder:

```bash
curl -L -o /tmp/axstats.sh https://www.adsbexchange.com/stats.sh
sudo bash /tmp/axstats.sh
```

After installation, access your local stats at:
```
http://[PI_IP]/adsbx-stats/
```

**Features:**
- Map showing only your received aircraft
- Performance graphs
- Range and coverage statistics
- Local aircraft database

## Service Management

### Check Service Status

```bash
# Check feed client status
sudo systemctl status adsbexchange-feed

# Check MLAT client status  
sudo systemctl status adsbexchange-mlat
```

### View Logs

```bash
# Feed client logs
sudo journalctl -u adsbexchange-feed -f

# MLAT client logs
sudo journalctl -u adsbexchange-mlat -f
```

### Restart Services

```bash
# Restart feed client
sudo systemctl restart adsbexchange-feed

# Restart MLAT client
sudo systemctl restart adsbexchange-mlat
```

## Configuration

The configuration is stored in:
```
/etc/default/adsbexchange
```

To modify settings:

```bash
sudo nano /etc/default/adsbexchange
```

**Key settings:**
```bash
INPUT="127.0.0.1:30005"          # Beast input from readsb
INPUT_TYPE="beast"               # Data format
LAT="33.6235"                    # Your latitude
LON="-117.1271"                  # Your longitude  
ALT="1440"                       # Elevation in feet
RECEIVER_NAME="adsb-pi-92563"    # Your feeder name
```

After making changes:
```bash
sudo systemctl restart adsbexchange-feed
sudo systemctl restart adsbexchange-mlat
```

## Updating the Feed Client

To update to the latest version:

```bash
curl -L -o /tmp/axupdate.sh https://www.adsbexchange.com/feed-update.sh
sudo bash /tmp/axupdate.sh
```

The update process will preserve your existing configuration.

## Troubleshooting

### Issue: Not Showing on myip Page

**Wait 5-10 minutes** after installation for the feeder to appear.

**Check services are running:**
```bash
sudo systemctl status adsbexchange-feed
sudo systemctl status adsbexchange-mlat
```

**Check network connectivity:**
```bash
# Test connection to ADS-B Exchange
ping feed.adsbexchange.com
```

**Verify readsb is running:**
```bash
systemctl status readsb
timeout 3 nc 127.0.0.1 30005 | hexdump -C | head -5
```

### Issue: MLAT Not Syncing

**Requirements for MLAT:**
- Precise coordinates (within a few meters)
- Stable system time/NTP sync
- At least 3-4 other nearby MLAT-enabled feeders
- Good aircraft reception (50+ messages/sec recommended)

**Check time synchronization:**
```bash
timedatectl status
```

**View MLAT logs:**
```bash
sudo journalctl -u adsbexchange-mlat | grep -i sync
```

**MLAT can take 10-30 minutes to synchronize** after first connection.

### Issue: Low Aircraft Count

**Verify readsb is seeing aircraft:**
```bash
curl -s http://127.0.0.1/tar1090/data/aircraft.json | grep -o '"flight"' | wc -l
```

**Check feed client logs for errors:**
```bash
sudo journalctl -u adsbexchange-feed -n 50
```

**Common causes:**
- readsb not running
- Wrong Beast port configuration
- Network connectivity issues
- Firewall blocking outbound connections

### Issue: Services Won't Start

**Check configuration file:**
```bash
cat /etc/default/adsbexchange
```

**Look for configuration errors:**
- Invalid coordinate format
- Missing required fields
- Incorrect Beast input address

**Check detailed error messages:**
```bash
sudo journalctl -u adsbexchange-feed -n 50
sudo journalctl -u adsbexchange-mlat -n 50
```

## Uninstalling

To remove the ADS-B Exchange feeder:

```bash
# Stop and disable services
sudo systemctl stop adsbexchange-feed adsbexchange-mlat
sudo systemctl disable adsbexchange-feed adsbexchange-mlat

# Remove service files
sudo rm /etc/systemd/system/adsbexchange-feed.service
sudo rm /etc/systemd/system/adsbexchange-mlat.service

# Remove configuration
sudo rm /etc/default/adsbexchange

# Remove client software
sudo rm -rf /usr/local/share/adsbexchange

# Remove stats package (if installed)
sudo bash /usr/local/share/adsbexchange-stats/uninstall.sh

# Reload systemd
sudo systemctl daemon-reload
```

## Benefits

- **Largest network**: World's biggest unfiltered ADS-B aggregator
- **Complete coverage**: No filtering of military, private, or VIP aircraft
- **Community-driven**: Independent from commercial tracking services
- **MLAT support**: Multilateration for non-ADS-B equipped aircraft
- **API access**: Free tier available for personal use
- **Stats package**: Local performance monitoring

## Port Usage

The ADS-B Exchange feeder uses:

| Port | Direction | Purpose | Protocol |
|------|-----------|---------|----------|
| 30005 | Input (from readsb) | Beast data | TCP |
| 30004 | Output (to ADSBx) | ADS-B feed | TCP |
| 31090 | Output (to ADSBx) | MLAT feed | TCP |

## Comparison with Other Services

**ADS-B Exchange vs FlightRadar24:**
- ✅ Unfiltered data (ADSBx shows ALL aircraft)
- ✅ No account required
- ✅ Free API access
- ✅ Community-driven (non-profit)

**ADS-B Exchange vs airplanes.live:**
- Both provide unfiltered data
- ADSBx has larger network and more resources
- airplanes.live is newer, fully community-driven
- Both support MLAT
- Can feed both simultaneously

## Related Links

- **Feed Status**: https://www.adsbexchange.com/myip/
- **MLAT Map**: https://map.adsbexchange.com/mlat-map/
- **Tracking Map**: https://globe.adsbexchange.com
- **Leaderboard**: https://globe.adsbexchange.com/leaderboard/
- **GitHub**: https://github.com/adsbexchange/
- **Discord**: Check ADS-B Exchange website for invite

## Key Takeaways

1. **Simple installation** - One script, auto-configuration
2. **No account needed** - Start feeding immediately
3. **Works alongside other feeders** - Won't interfere with existing feeds
4. **Unfiltered data** - Complete aircraft coverage including military
5. **Optional stats** - Local web interface for performance monitoring
6. **Large community** - Biggest unfiltered aggregator worldwide

---

*Last updated: January 2026*
