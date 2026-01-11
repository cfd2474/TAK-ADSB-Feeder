# airplanes.live Feeder Setup Guide

## Overview
This guide covers adding airplanes.live feeding to your existing readsb-based ADS-B feeder. The airplanes.live feeder client will run alongside your current setup without conflicts.

## What is airplanes.live?
airplanes.live is a community-driven, unfiltered ADS-B aggregator that provides:
- Complete, unfiltered aircraft data
- MLAT (multilateration) capability
- Free API access for non-commercial use
- Privacy-focused approach

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
- **Elevation** in meters above sea level (e.g., 439)

### Step 2: Install the airplanes.live Feed Client

Run the automated installer:

```bash
curl -L -o /tmp/feed.sh https://raw.githubusercontent.com/airplanes-live/feed/main/install.sh
sudo bash /tmp/feed.sh
```

The installer will:
1. Prompt for your antenna coordinates and elevation
2. Detect your existing readsb installation
3. Configure the feed client automatically
4. Set up systemd services for automatic startup
5. Configure MLAT client

**During installation:**
- Confirm your readsb data source (should auto-detect `127.0.0.1:30005`)
- Enter your precise coordinates when prompted
- The script will not disrupt your existing feeds

### Step 3: Verify the Feed is Working

Check that data is flowing to airplanes.live:

```bash
netstat -t -n | grep -E '30004|31090'
```

**Expected output:**
```
tcp 0 182 localhost:43530 78.46.234.18:31090 ESTABLISHED  
tcp 0 410 localhost:47332 78.46.234.18:30004 ESTABLISHED
```

- **Port 30004**: ADS-B data (Beast format)
- **Port 31090**: MLAT data

### Step 4: Check Your Feed Status

Visit the airplanes.live MyFeed page to see your feeder status:

**https://airplanes.live/myfeed**

You should see:
- Your feeder listed as online
- Aircraft count being received
- MLAT synchronization status
- Coverage statistics

## Service Management

### Check Service Status

```bash
# Check feed client status
sudo systemctl status airplanes-feed

# Check MLAT client status
sudo systemctl status airplanes-mlat
```

### View Logs

```bash
# Feed client logs
sudo journalctl -u airplanes-feed -f

# MLAT client logs
sudo journalctl -u airplanes-mlat -f
```

### Restart Services

```bash
# Restart feed client
sudo systemctl restart airplanes-feed

# Restart MLAT client
sudo systemctl restart airplanes-mlat
```

## Configuration

The configuration is stored in:
```
/etc/default/airplanes
```

To modify settings:

```bash
sudo nano /etc/default/airplanes
```

**Key settings:**
```bash
INPUT="127.0.0.1:30005"      # Beast input from readsb
LAT="33.6235"                # Your latitude
LON="-117.1271"              # Your longitude
ALT="439m"                   # Elevation in meters
USER="airplanes"             # Feed client username
```

After making changes:
```bash
sudo systemctl restart airplanes-feed
sudo systemctl restart airplanes-mlat
```

## Troubleshooting

### Issue: No Connection to airplanes.live

**Check network connectivity:**
```bash
ping 78.46.234.18
```

**Verify readsb is running:**
```bash
systemctl status readsb
timeout 3 nc 127.0.0.1 30005 | hexdump -C | head -5
```

### Issue: MLAT Not Syncing

**Requirements for MLAT:**
- Precise coordinates (within a few meters)
- Stable clock/time sync
- At least 3 other nearby MLAT-enabled feeders

**Check time sync:**
```bash
timedatectl status
```

**View MLAT logs for sync messages:**
```bash
sudo journalctl -u airplanes-mlat | grep -i sync
```

### Issue: Services Not Starting

**Check for errors:**
```bash
sudo journalctl -u airplanes-feed -n 50
sudo journalctl -u airplanes-mlat -n 50
```

**Common causes:**
- Incorrect coordinates format
- readsb not running
- Port 30005 not accessible

### Issue: Low Aircraft Count

**Verify readsb is seeing aircraft:**
```bash
curl -s http://127.0.0.1/tar1090/data/aircraft.json | grep -o '"flight"' | wc -l
```

If readsb shows aircraft but airplanes.live doesn't:
- Check feed client is running
- Verify network connection
- Check logs for errors

## Updating the Feed Client

To update to the latest version:

```bash
curl -L -o /tmp/feed.sh https://raw.githubusercontent.com/airplanes-live/feed/main/install.sh
sudo bash /tmp/feed.sh
```

The update process will preserve your existing configuration.

## Uninstalling

To remove the airplanes.live feeder:

```bash
# Stop and disable services
sudo systemctl stop airplanes-feed airplanes-mlat
sudo systemctl disable airplanes-feed airplanes-mlat

# Remove service files
sudo rm /etc/systemd/system/airplanes-feed.service
sudo rm /etc/systemd/system/airplanes-mlat.service

# Remove configuration
sudo rm /etc/default/airplanes

# Remove client software
sudo rm -rf /usr/local/share/airplanes

# Reload systemd
sudo systemctl daemon-reload
```

## Benefits

- **Unfiltered data**: See all aircraft, including military and private
- **MLAT support**: Multilateration for aircraft without ADS-B
- **Free API**: Access your data via their API
- **Privacy-focused**: Community-driven, not commercial
- **No account required**: Feed anonymously if desired

## Port Usage

The airplanes.live feeder uses:

| Port | Direction | Purpose | Protocol |
|------|-----------|---------|----------|
| 30005 | Input (from readsb) | Beast data | TCP |
| 30004 | Output (to airplanes.live) | ADS-B feed | TCP |
| 31090 | Output (to airplanes.live) | MLAT feed | TCP |

## Related Links

- **Feed Status**: https://airplanes.live/myfeed
- **Network Map**: https://airplanes.live/network
- **Tracking Map**: https://globe.airplanes.live
- **GitHub**: https://github.com/airplanes-live/feed
- **Discord**: https://discord.gg/jfVRF2XRwF

## Key Takeaways

1. **Simple installation** - One script handles everything
2. **No account needed** - Start feeding immediately
3. **Works alongside other feeders** - Won't interfere with existing feeds
4. **Automatic MLAT** - Configured during installation
5. **Unfiltered data** - Complete aircraft coverage

---

*Last updated: January 2026*
