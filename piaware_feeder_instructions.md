# How to Feed Your PiAware Receiver to My ADS-B Aggregator

This guide will walk you through configuring your existing **PiAware** (FlightAware) feeder to also send ADS-B data to my aggregator at **104.225.219.254**. This will NOT disrupt your existing FlightAware feed or MLAT participation. 

**Follow [MLAT Guide](MLAT_config.md) to add MLAT service after completing this process**

## Prerequisites

- A working PiAware feeder (SD card image or package install)
- Internet connectivity
- SSH client (built into Mac/Linux, use PuTTY on Windows)
- 10 minutes of time

## Important Notes

- This setup creates an ADDITIONAL feed to my aggregator
- Your FlightAware feed will continue working normally
- MLAT results received from FlightAware will NOT be forwarded to my aggregator
- No configuration changes are needed to your existing PiAware setup

## Step 1: Connect to Your PiAware via SSH

1. **Find your PiAware IP address**
   - Check your router's DHCP leases, or
   - Look at the FlightAware stats page for your feeder

2. **Open your terminal/SSH client**
   - **Mac/Linux**: Open Terminal
   - **Windows**: Use PuTTY or Windows Terminal

3. **SSH into your PiAware**
   ```bash
   ssh pi@192.168.X.XX
   ```
   Replace `192.168.X.XX` with your actual PiAware IP address.

4. **Enter the password when prompted**
   - PiAware SD card image default password: `flightaware`
   - Package install on Raspberry Pi OS: default is `raspberry`
   - Note: You won't see characters as you type the password

5. **You should now see a prompt like:**
   ```
   pi@piaware:~ $
   ```

## Step 2: Verify Your dump1090-fa Installation

Your PiAware uses dump1090-fa to decode ADS-B data. Let's confirm it's running:

```bash
sudo systemctl status dump1090-fa
```

You should see `active (running)` in green. Press `q` to exit.

## Step 3: Check Available Ports

dump1090-fa provides data on several ports. Let's see what's available:

```bash
sudo netstat -tlnp | grep dump1090-fa
```

Look for these ports (you should see several):
- `30005` - Beast binary output (this is what we need)
- `30003` - SBS/BaseStation format
- `30002` - Raw format

If you see `127.0.0.1:30005` or `0.0.0.0:30005`, you're all set.

## Step 4: Install socat (Data Forwarding Tool)

We'll use `socat` to forward your Beast data to my aggregator:

```bash
sudo apt-get update && sudo apt-get install -y socat
```

This may take 1-2 minutes. Type `y` if prompted.

## Step 5: Create the Feed Service

1. **Create a new systemd service file:**
   ```bash
   sudo nano /etc/systemd/system/aggregator-feed.service
   ```

2. **Copy and paste this configuration:**
   
   Press `Ctrl+Shift+V` to paste (or `Shift+Insert` on some systems):

   ```ini
   [Unit]
   Description=ADS-B Feed to External Aggregator
   After=network.target dump1090-fa.service
   Requires=dump1090-fa.service
   Wants=network.target

   [Service]
   Type=simple
   User=dump1090
   ExecStart=/usr/bin/socat -d -d TCP:127.0.0.1:30005 TCP:104.225.219.254:30005
   Restart=always
   RestartSec=30
   StandardOutput=journal
   StandardError=journal

   [Install]
   WantedBy=multi-user.target
   ```

   **Note:** If Step 3 showed dump1090-fa on a different port (not 30005), change the first port number in the `ExecStart` line to match.

3. **Save and exit nano:**
   - Press `Ctrl+X`
   - Press `Y` to confirm save
   - Press `Enter` to confirm filename

## Step 6: Enable and Start the Service

Run these commands one at a time:

1. **Reload systemd:**
   ```bash
   sudo systemctl daemon-reload
   ```

2. **Enable the service to start on boot:**
   ```bash
   sudo systemctl enable aggregator-feed.service
   ```

3. **Start the service now:**
   ```bash
   sudo systemctl start aggregator-feed.service
   ```

## Step 7: Verify Everything is Working

1. **Check the service status:**
   ```bash
   sudo systemctl status aggregator-feed.service
   ```

   You should see:
   - `Active: active (running)` in green
   - No error messages
   - Press `q` to exit

2. **Check the live logs:**
   ```bash
   sudo journalctl -u aggregator-feed.service -f
   ```

   You should see messages like:
   ```
   starting data transfer loop with FDs [5,5] and [7,7]
   ```

   This means data is flowing! Press `Ctrl+C` to exit.

3. **Verify the connection:**
   ```bash
   sudo ss -tnp | grep 30005
   ```

   You should see a line with `ESTAB` (established) connecting to `104.225.219.254:30005`.

4. **Test connectivity to the aggregator:**
   ```bash
   ping -c 4 104.225.219.254
   ```

   You should see 4 successful replies with times (like `time=25.3 ms`).

## Step 8: Confirm Your Existing Feeds Still Work

Make sure your FlightAware feed is still working:

```bash
sudo systemctl status piaware
sudo systemctl status dump1090-fa
```

Both should show `active (running)`. Your FlightAware feed and MLAT are unaffected!

Check your FlightAware stats page - everything should look normal.

## Troubleshooting

### Service fails to start

**Check the logs for errors:**
```bash
sudo journalctl -u aggregator-feed.service -n 50 --no-pager
```

**Common issues:**

**"Connection refused" to 127.0.0.1:30005**
- dump1090-fa might be using a different port or not running
- Run: `sudo netstat -tlnp | grep dump1090-fa`
- Update the service file with the correct port number
- If dump1090-fa isn't running: `sudo systemctl restart dump1090-fa`

**"Connection refused" to 104.225.219.254:30005**
- Check internet connectivity: `ping -c 4 8.8.8.8`
- Verify the aggregator address: `ping -c 4 104.225.219.254`
- Check if your firewall is blocking outbound connections

**"Permission denied" or user errors**
- The service runs as user `dump1090`. If this user doesn't exist on your system, change `User=dump1090` to `User=pi` in the service file
- Reload and restart: `sudo systemctl daemon-reload && sudo systemctl restart aggregator-feed.service`

### Service keeps restarting

**Check dump1090-fa status:**
```bash
sudo systemctl status dump1090-fa
```

If dump1090-fa is not running or restarting, fix that first. The feed service depends on it.

**Check for port conflicts:**
```bash
sudo lsof -i :30005
```

You should see `dump1090-fa` listening and possibly `socat` connected. If you see other programs using this port, you may have a conflict.

### No data appearing on aggregator

1. **Verify dump1090-fa is receiving aircraft:**
   - Open your local SkyAware map (usually at `http://192.168.X.XX/skyaware` or `/dump1090-fa`)
   - You should see aircraft on the map
   - If no aircraft appear, check your antenna and SDR connections

2. **Verify socat is connected:**
   ```bash
   sudo ss -tnp | grep 104.225.219.254
   ```
   Should show `ESTAB` connection.

3. **Check if data is flowing:**
   ```bash
   sudo tcpdump -i any host 104.225.219.254 and port 30005 -c 10
   ```
   You should see packets. Press `Ctrl+C` to stop.

### Slow performance or high CPU usage

This is rare, but if you notice issues:
- Check system resources: `top`
- The feed service should use minimal CPU (<1%)
- If socat is using excessive resources, check for network issues

## Stopping or Removing the Feed

If you need to stop feeding data to the aggregator:

**Stop temporarily:**
```bash
sudo systemctl stop aggregator-feed.service
```

**Disable from starting on boot:**
```bash
sudo systemctl disable aggregator-feed.service
```

**Remove completely:**
```bash
sudo systemctl stop aggregator-feed.service
sudo systemctl disable aggregator-feed.service
sudo rm /etc/systemd/system/aggregator-feed.service
sudo systemctl daemon-reload
```

Your FlightAware feed will continue working normally after removal.

## What Data Gets Sent?

This feed sends:
- All ADS-B aircraft positions and data (1090MHz)
- UAT data if you have a 978MHz receiver (US only)
- Data in Beast binary format (industry standard)
- Only aircraft data - no personal information
- MLAT results received FROM FlightAware are NOT forwarded (they stay local)

## Checking Your Feed Status

To view your feed logs at any time:

```bash
sudo journalctl -u aggregator-feed.service -f
```

Press `Ctrl+C` to exit.

## Advanced: Multiple Aggregators

You can add feeds to multiple aggregators by creating additional service files:

1. Copy the service file:
   ```bash
   sudo cp /etc/systemd/system/aggregator-feed.service /etc/systemd/system/aggregator-feed-2.service
   ```

2. Edit the new file and change the destination IP/port:
   ```bash
   sudo nano /etc/systemd/system/aggregator-feed-2.service
   ```

3. Enable and start:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now aggregator-feed-2.service
   ```

## Support

If you've followed these steps and still have issues, please provide:

1. **Service status:**
   ```bash
   sudo systemctl status aggregator-feed.service
   ```

2. **Last 50 log lines:**
   ```bash
   sudo journalctl -u aggregator-feed.service -n 50 --no-pager
   ```

3. **Network connectivity:**
   ```bash
   ping -c 4 104.225.219.254
   ```

4. **Port information:**
   ```bash
   sudo netstat -tlnp | grep dump1090-fa
   ```

## Credits

Thank you for contributing to the ADS-B tracking network! Your data helps improve flight tracking coverage for everyone.

This setup maintains your contribution to FlightAware while also helping expand coverage through independent aggregation.
