# How to Add MLAT Feed to the TAK-ADSB Aggregator

This guide will help you configure your ADS-B feeder to participate in my MLAT (Multilateration) network at **104.225.219.254**. MLAT allows us to track aircraft without ADS-B transponders by using time-difference-of-arrival calculations from multiple receivers.

## What is MLAT?

MLAT (Multilateration) calculates aircraft positions by measuring the time difference between when multiple receivers detect the same aircraft signal. Your receiver will:
- Send timestamped Mode-S messages to my MLAT server
- Receive calculated positions back from the server
- Display those positions on your local map alongside regular ADS-B data

**Important:** This MLAT feed is SEPARATE from any existing MLAT feeds you may have (ADSBx, FR24, etc.). You can run multiple MLAT clients simultaneously without conflicts.

## Prerequisites

- A working ADS-B feeder (airplanes.live, ADSBx, PiAware, etc.)
- Already feeding Beast data to my aggregator (if not, complete that setup first)
- Internet connectivity
- SSH access to your receiver
- 10-15 minutes of time

## Important Notes

- This setup ADDS another MLAT client - it won't affect existing MLAT feeds
- Your existing MLAT feeds (if any) will continue working normally
- Multiple MLAT clients can run simultaneously and share the same data sources

## Step 1: Connect to Your Receiver via SSH

```bash
ssh pi@192.168.X.XX
```

Replace `192.168.X.XX` with your receiver's IP address. Default passwords:
- airplanes.live: `adsb123`
- PiAware: `flightaware`
- ADSBx: `adsb123`

## Step 2: Check if mlat-client is Already Installed

Run this command to check:

```bash
which mlat-client
```

**If you see a path like `/usr/bin/mlat-client`:**
- ✅ mlat-client is installed - **skip to Step 4**

**If you see nothing or "not found":**
- ❌ mlat-client is not installed - **continue to Step 3**

## Step 3: Install mlat-client (Only if Not Already Installed)

If Step 2 showed mlat-client is not installed, run:

```bash
sudo apt-get update && sudo apt-get install -y mlat-client
```

This will take 1-2 minutes. Type `y` if prompted.

**Verify installation:**
```bash
mlat-client --version
```

You should see version information. If you see an error, try:
```bash
sudo apt-get install -y python3-pip
sudo pip3 install mlat-client
```

## Step 4: Gather Your Location Information

Your MLAT client needs your exact receiver location. You may already have this from your existing setup.

**Find your coordinates from existing config:**

For **airplanes.live** feeders:
```bash
cat /boot/adsb-config.txt | grep -E 'LATITUDE|LONGITUDE|ALTITUDE'
```

For **ADSBx** feeders:
```bash
cat /etc/default/adsbexchange | grep -E 'LAT|LON|ALT'
```

For **PiAware** feeders:
```bash
piaware-config -show | grep location
```

**If you can't find your coordinates:**
1. Visit https://www.latlong.net/
2. Find your location on the map
3. Note your latitude, longitude, and altitude

**Write down these values:**
- **Latitude**: Example: `40.7128` (North is positive, South is negative)
- **Longitude**: Example: `-74.0060` (East is positive, West is negative)  
- **Altitude**: Example: `150ft` or `45m` (antenna height above sea level)

## Step 5: Choose a Unique Feeder Name

Pick a name that identifies your feeder. This helps me identify your station in the MLAT network.

**Good examples:**
- `john-seattle-wa`
- `adsbx-newyork-rooftop`
- `n2xyz-mobile`
- `kc1abc-basement`

**Avoid:**
- Generic names like `feeder` or `user1`
- Names already used by your other MLAT feeds (check existing services)

**Write down your chosen name:** `_________________`

## Step 6: Create the MLAT Service File

Create a new systemd service for the aggregator MLAT feed:

```bash
sudo nano /etc/systemd/system/aggregator-mlat.service
```

## Step 7: Add the Service Configuration

Copy and paste this configuration. Press `Ctrl+Shift+V` (or `Shift+Insert`):

```ini
[Unit]
Description=MLAT Feed to External Aggregator
After=network.target readsb.service
Requires=readsb.service
Wants=network.target

[Service]
Type=simple
User=readsb
ExecStart=/usr/bin/mlat-client \
    --input-type auto \
    --input-connect localhost:30005 \
    --server 104.225.219.254:30105 \
    --lat YOUR_LATITUDE \
    --lon YOUR_LONGITUDE \
    --alt YOUR_ALTITUDE \
    --user YOUR_FEEDER_NAME \
    --results beast,connect,localhost:30104
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Step 8: Customize the Configuration

**You MUST replace these placeholders with your actual values:**

1. **Replace `YOUR_LATITUDE`** with your latitude
   - Example: `40.7128` or `-33.8688`
   
2. **Replace `YOUR_LONGITUDE`** with your longitude
   - Example: `-74.0060` or `151.2093`
   
3. **Replace `YOUR_ALTITUDE`** with your altitude
   - Examples: `150ft` or `45m` or `1200ft`
   - Use `ft` for feet or `m` for meters
   
4. **Replace `YOUR_FEEDER_NAME`** with your unique name
   - Example: `john-seattle-wa`

**Example of completed configuration:**

```ini
ExecStart=/usr/bin/mlat-client \
    --input-type auto \
    --input-connect localhost:30005 \
    --server 104.225.219.254:30105 \
    --lat 40.7128 \
    --lon -74.0060 \
    --alt 150ft \
    --user john-seattle-wa \
    --results beast,connect,localhost:30104
```

**Save and exit nano:**
- Press `Ctrl+X`
- Press `Y` to confirm save
- Press `Enter` to confirm filename

## Step 9: Handle User Permissions (If Needed)

The service runs as user `readsb`. If this user doesn't exist on your system:

**Check if user exists:**
```bash
id readsb
```

**If you see "no such user":**

Edit the service file:
```bash
sudo nano /etc/systemd/system/aggregator-mlat.service
```

Change this line:
```ini
User=readsb
```

To:
```ini
User=pi
```

Save and exit (Ctrl+X, Y, Enter).

## Step 10: Enable and Start the Service

Run these commands one at a time:

1. **Reload systemd:**
   ```bash
   sudo systemctl daemon-reload
   ```

2. **Enable the service to start on boot:**
   ```bash
   sudo systemctl enable aggregator-mlat.service
   ```

3. **Start the service now:**
   ```bash
   sudo systemctl start aggregator-mlat.service
   ```

## Step 11: Verify Everything is Working

### Check Service Status

```bash
sudo systemctl status aggregator-mlat.service
```

**What to look for:**
- ✅ `Active: active (running)` in green
- ✅ No error messages
- ✅ Messages like "Connected to multilateration server"

Press `q` to exit.

### Watch Live Logs

```bash
sudo journalctl -u aggregator-mlat.service -f
```

**Good signs:**
```
Connected to multilateration server at 104.225.219.254:30105
Server says: Client successfully registered
Accepted sync from server
```

**Press `Ctrl+C` to exit.**

### Verify Network Connection

```bash
sudo ss -tnp | grep 31090
```

You should see:
```
ESTAB ... 104.225.219.254:30105
```

This confirms connection to the MLAT server.

### Test Connectivity

```bash
ping -c 4 104.225.219.254
```

You should see 4 successful replies with response times.

## Step 12: Confirm Existing MLAT Feeds Still Work

If you have existing MLAT services (ADSBx, FR24, etc.), verify they're still running:

```bash
# List all mlat services
sudo systemctl list-units | grep mlat

# Check each one individually
sudo systemctl status adsbexchange-mlat    # if you have ADSBx
sudo systemctl status piaware-mlat-client  # if you have PiAware
sudo systemctl status fr24feed             # if you have FR24
```

All should show `active (running)`. Your existing MLAT feeds are unaffected!

## Troubleshooting

### Service Fails to Start

**Check detailed logs:**
```bash
sudo journalctl -u aggregator-mlat.service -n 100 --no-pager
```

**Common Issues and Solutions:**

#### "Connection refused to localhost:30005"

Your readsb might not be running or using a different port.

**Check readsb status:**
```bash
sudo systemctl status readsb
```

**Find the correct port:**
```bash
sudo netstat -tlnp | grep readsb
```

Look for a port with Beast output (usually 30005). Update your service file if needed.

#### "Connection refused to 104.225.219.254:30105"

Network connectivity issue.

**Test connection:**
```bash
telnet 104.225.219.254 30105
```

If connection fails:
- Check internet: `ping -c 4 8.8.8.8`
- Check aggregator: `ping -c 4 104.225.219.254`
- Check firewall settings

#### "Bad position: invalid latitude/longitude"

Your coordinates are in the wrong format.

**Requirements:**
- Latitude: Decimal degrees (-90 to 90)
- Longitude: Decimal degrees (-180 to 180)
- Altitude: Number followed by `ft` or `m`

**Fix:** Edit the service file and correct your coordinates:
```bash
sudo nano /etc/systemd/system/aggregator-mlat.service
```

Then reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart aggregator-mlat.service
```

#### "User name already in use"

Someone else (or another service) is already using that feeder name.

**Fix:** Choose a different, unique name. Edit the service file:
```bash
sudo nano /etc/systemd/system/aggregator-mlat.service
```

Change `--user YOUR_FEEDER_NAME` to something more unique.

Then reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart aggregator-mlat.service
```

#### "Permission denied" or User Errors

The service can't run as the specified user.

**Fix:** Change user to `pi` (see Step 9 above), then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart aggregator-mlat.service
```

### Service Keeps Restarting

**Check if readsb is healthy:**
```bash
sudo systemctl status readsb
```

If readsb is not running properly, fix that first. MLAT depends on readsb.

**Check for port conflicts:**
```bash
sudo lsof -i :30005
sudo lsof -i :30104
```

You should see readsb and mlat-client processes. Multiple mlat-clients sharing these ports is normal.

### No MLAT Results Appearing

**This is normal and expected:**
- MLAT requires multiple receivers to see the same aircraft
- MLAT only works for aircraft without ADS-B transponders
- MLAT results may be sparse if you're in a low-coverage area
- It can take several minutes after startup for MLAT to begin working

**Verify you're receiving regular ADS-B data:**
- Open your local web interface (tar1090/airplanes)
- You should see aircraft on the map
- If no aircraft at all, check your antenna and SDR

**Check if MLAT results are being received locally:**
```bash
sudo tcpdump -i lo port 30104 -c 20
```

You should see packets. This is MLAT data being injected into your local readsb.

### MLAT Server Says "User Already Exists"

You or someone else is already using that feeder name on my MLAT server.

**Solutions:**
1. **Choose a more unique name** - Add your callsign, location, or random numbers
2. **Edit the service file:**
   ```bash
   sudo nano /etc/systemd/system/aggregator-mlat.service
   ```
3. **Change the `--user` parameter** to your new unique name
4. **Reload and restart:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart aggregator-mlat.service
   ```

## Understanding MLAT Data Flow

Here's how MLAT works in your setup:

```
Your Antenna → SDR → readsb (decodes signals)
                       ↓
                   Port 30005 (Beast output)
                       ↓
                   mlat-client (sends to aggregator)
                       ↓
            104.225.219.254:30105 (MLAT server)
                       ↓
        (calculates positions with other feeders)
                       ↓
                   mlat-client (receives results)
                       ↓
                   Port 30104 (Beast input)
                       ↓
                   readsb (merges MLAT with ADS-B)
                       ↓
                Your local tar1090 map
```

## Managing Your MLAT Feed

### View Real-Time Logs

```bash
sudo journalctl -u aggregator-mlat.service -f
```

Press `Ctrl+C` to exit.

### Restart the Service

```bash
sudo systemctl restart aggregator-mlat.service
```

### Stop the Service Temporarily

```bash
sudo systemctl stop aggregator-mlat.service
```

### Start the Service Again

```bash
sudo systemctl start aggregator-mlat.service
```

### Disable from Auto-Start

```bash
sudo systemctl disable aggregator-mlat.service
```

### Remove Completely

```bash
sudo systemctl stop aggregator-mlat.service
sudo systemctl disable aggregator-mlat.service
sudo rm /etc/systemd/system/aggregator-mlat.service
sudo systemctl daemon-reload
```

## Running Multiple MLAT Clients

You can (and should!) run multiple MLAT clients to participate in several MLAT networks simultaneously. This is normal and recommended.

**Common setup:**
- `adsbexchange-mlat.service` → Feeds ADSBx MLAT network
- `aggregator-mlat.service` → Feeds my aggregator MLAT network
- `fr24feed.service` → Includes FR24 MLAT
- `piaware-mlat-client.service` → Feeds FlightAware MLAT

**All clients:**
- Read from the same input (localhost:30005)
- Write to the same output (localhost:30104)
- Run simultaneously without conflicts
- Contribute to improving coverage on multiple networks

**To see all your MLAT services:**
```bash
sudo systemctl list-units | grep mlat
```

## Privacy and Data Sharing

**What gets sent to the aggregator:**
- Timestamped Mode-S messages (raw aircraft signals)
- Your receiver's location (lat/lon/alt)
- Your chosen feeder name

**What does NOT get sent:**
- Personal information
- Your IP address (only used for network connection)
- Data from your local network
- Anything except aircraft-related signals

**MLAT results are shared:**
- You receive calculated positions from the MLAT server
- These appear on your local map alongside regular ADS-B data
- MLAT improves tracking of military, general aviation, and older aircraft

## Performance and Resource Usage

MLAT clients are very lightweight:
- Minimal CPU usage (<1%)
- Low memory footprint (~10-20MB)
- Network bandwidth: ~10-50KB/s depending on traffic

**Check resource usage:**
```bash
top -p $(pgrep -f aggregator-mlat)
```

Press `q` to exit.

## Advanced: Multiple Aggregators

To add MLAT feeds to multiple aggregators, create additional service files:

1. **Copy the service:**
   ```bash
   sudo cp /etc/systemd/system/aggregator-mlat.service \
          /etc/systemd/system/aggregator-mlat-2.service
   ```

2. **Edit the copy:**
   ```bash
   sudo nano /etc/systemd/system/aggregator-mlat-2.service
   ```

3. **Change:**
   - Description (for identification)
   - `--server` (different aggregator address)
   - `--user` (different name for that server)

4. **Enable and start:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now aggregator-mlat-2.service
   ```

## Getting Help

If you've followed these steps and still have issues, please provide:

1. **Service status:**
   ```bash
   sudo systemctl status aggregator-mlat.service
   ```

2. **Recent logs (last 100 lines):**
   ```bash
   sudo journalctl -u aggregator-mlat.service -n 100 --no-pager
   ```

3. **Your location info (approximate):**
   - City and state/country
   - Approximate altitude

4. **Network connectivity:**
   ```bash
   ping -c 4 104.225.219.254
   nc -zv 104.225.219.254 30105
   ```

5. **readsb status:**
   ```bash
   sudo systemctl status readsb
   sudo netstat -tlnp | grep readsb
   ```

## Credits and Thanks

Thank you for contributing to the MLAT network! Your participation helps improve aircraft tracking coverage for everyone, especially for aircraft without ADS-B transponders.

**Benefits of MLAT participation:**
- Track military aircraft and helicopters
- See general aviation aircraft without ADS-B
- Improve coverage in your local area
- Contribute to a community-driven network
- Get MLAT results back on your own map

Your existing feeds to other services (ADSBx, FR24, etc.) continue working normally. You're simply adding another valuable contribution to the ADS-B tracking community!

## Quick Reference

**Check service status:**
```bash
sudo systemctl status aggregator-mlat.service
```

**View live logs:**
```bash
sudo journalctl -u aggregator-mlat.service -f
```

**Restart service:**
```bash
sudo systemctl restart aggregator-mlat.service
```

**Check connection:**
```bash
sudo ss -tnp | grep 30105
```

**List all MLAT services:**
```bash
sudo systemctl list-units | grep mlat
```

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Aggregator:** 104.225.219.254:30105
