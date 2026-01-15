# How to Feed Your Stratux to My ADS-B Aggregator

This guide will walk you through configuring your Stratux device to send ADS-B data to my aggregator at **104.225.219.254**. These instructions assume you have basic terminal/command line experience. 
**Follow [MLAT Guide](MLAT_config.md) to add MLAT service after completing this process**

## Prerequisites

- A working Stratux device with ADS-B reception
- Stratux must have internet connectivity (not just WiFi AP mode)
- SSH client (built into Mac/Linux, use PuTTY on Windows)
- 10-15 minutes of time

## Step 1: Connect to Your Stratux via SSH

1. **Find your Stratux IP address**
   - If Stratux is in AP mode: `192.168.10.1`
   - If Stratux is on your network: Check your router's DHCP leases or use the Stratux web interface

2. **Open your terminal/SSH client**
   - **Mac/Linux**: Open Terminal
   - **Windows**: Use PuTTY or Windows Terminal

3. **SSH into Stratux**
   ```bash
   ssh pi@192.168.10.1
   ```
   Replace `192.168.10.1` with your Stratux's actual IP if different.

4. **Enter the password when prompted**
   - Default password: `raspberry`
   - Note: You won't see characters as you type the password

5. **You should now see a prompt like:**
   ```
   pi@stratux:~ $
   ```

## Step 2: Install Required Software

We'll use `socat` to forward ADS-B data. Run these commands one at a time:

```bash
sudo apt-get update
```

Wait for this to complete (may take 1-2 minutes), then:

```bash
sudo apt-get install -y socat
```

Type `y` if prompted to confirm installation.

## Step 3: Find Your Local dump1090 Port

Stratux runs dump1090-fa internally. We need to find which port it's using:

```bash
sudo netstat -tlnp | grep dump1090
```

Look for a line that shows `127.0.0.1:30005` or similar. The port (30005) is what we need.

**Common ports:**
- `30005` - Beast binary output (most common)
- `30002` - Raw data output

If you see `30005`, proceed with that. If you see a different port, use that number in the next steps.

## Step 4: Create the Forwarding Service

1. **Create a new systemd service file:**
   ```bash
   sudo nano /etc/systemd/system/stratux-aggregator-feed.service
   ```

2. **Copy and paste this entire configuration:**
   
   Press `Ctrl+Shift+V` to paste (or `Shift+Insert` on some systems):

   ```ini
   [Unit]
   Description=Stratux to ADS-B Aggregator Feed
   After=network.target dump1090-fa.service
   Wants=network.target

   [Service]
   Type=simple
   User=pi
   ExecStart=/usr/bin/socat -d -d TCP:127.0.0.1:30005 TCP:104.225.219.254:30005
   Restart=always
   RestartSec=30
   StandardOutput=journal
   StandardError=journal

   [Install]
   WantedBy=multi-user.target
   ```

   **Important:** If your dump1090 port from Step 3 was NOT 30005, change `127.0.0.1:30005` to use your port number.

3. **Save and exit nano:**
   - Press `Ctrl+X`
   - Press `Y` to confirm save
   - Press `Enter` to confirm filename

## Step 5: Enable and Start the Service

Run these commands one at a time:

1. **Reload systemd to recognize the new service:**
   ```bash
   sudo systemctl daemon-reload
   ```

2. **Enable the service to start on boot:**
   ```bash
   sudo systemctl enable stratux-aggregator-feed.service
   ```

3. **Start the service now:**
   ```bash
   sudo systemctl start stratux-aggregator-feed.service
   ```

## Step 6: Verify Everything is Working

1. **Check the service status:**
   ```bash
   sudo systemctl status stratux-aggregator-feed.service
   ```

   You should see:
   - `Active: active (running)` in green
   - No error messages

2. **Check the live logs:**
   ```bash
   sudo journalctl -u stratux-aggregator-feed.service -f
   ```

   You should see output like:
   ```
   starting data transfer loop with FDs [5,5] and [7,7]
   ```

   Press `Ctrl+C` to exit the log view.

3. **Test internet connectivity to the aggregator:**
   ```bash
   ping -c 4 104.225.219.254
   ```

   You should see replies. If you see "Destination Host Unreachable" or timeouts, check your Stratux internet connection.

## Step 7: Confirm Data is Flowing (Optional)

If you want to see data being sent:

```bash
sudo tcpdump -i any host 104.225.219.254 and port 30005 -c 20
```

You should see packets being transmitted. Press `Ctrl+C` to stop.

## Troubleshooting

### Service won't start or keeps failing

**Check the service logs:**
```bash
sudo journalctl -u stratux-aggregator-feed.service -n 50
```

**Common issues:**
- **"Connection refused"** from 127.0.0.1:30005 - dump1090 isn't running or using a different port
  - Check with: `sudo systemctl status dump1090-fa`
  - Verify the port: `sudo netstat -tlnp | grep dump1090`
  
- **"Network is unreachable"** or timeout to 104.225.219.254 - No internet connection
  - Verify Stratux has internet: `ping -c 4 8.8.8.8`
  - Check your WiFi/network configuration in Stratux web interface

### No data appearing on aggregator

1. **Ensure Stratux is receiving ADS-B signals:**
   - Check Stratux web interface (http://192.168.10.1 or your Stratux IP)
   - Look for aircraft count > 0

2. **Verify the service is running:**
   ```bash
   sudo systemctl status stratux-aggregator-feed.service
   ```

3. **Check for connection:**
   ```bash
   sudo ss -tnp | grep 30005
   ```
   You should see an ESTABLISHED connection to 104.225.219.254

### Stratux is in WiFi AP mode and has no internet

Your Stratux needs internet access to reach the aggregator. Options:

1. **Connect Stratux to your WiFi network as a client** (preferred)
   - Use Stratux web interface: Settings → WiFi
   - Change mode from AP to Client
   - Connect to your home WiFi

2. **Use WiFi AP + Client mode** (if Stratux supports it)
   - Allows Stratux to be an AP AND connect to your WiFi
   - Check your Stratux version for this feature

3. **Use Ethernet** (if you have a Pi with Ethernet or USB-Ethernet adapter)
   - Plug in Ethernet cable
   - Stratux should get internet automatically via DHCP

## Stopping or Disabling the Feed

If you need to stop sending data:

**Stop the service temporarily:**
```bash
sudo systemctl stop stratux-aggregator-feed.service
```

**Disable it from starting on boot:**
```bash
sudo systemctl disable stratux-aggregator-feed.service
```

**Remove it completely:**
```bash
sudo systemctl stop stratux-aggregator-feed.service
sudo systemctl disable stratux-aggregator-feed.service
sudo rm /etc/systemd/system/stratux-aggregator-feed.service
sudo systemctl daemon-reload
```

## What Data Gets Sent?

Your Stratux will send:
- All ADS-B aircraft positions (1090MHz)
- UAT traffic if your Stratux has a 978MHz receiver
- Data is sent in "Beast binary format" - the standard for ADS-B aggregation
- Only aircraft data is sent - no personal information from your device

## Support

If you've followed these steps and still have issues:
1. Include the output of: `sudo journalctl -u stratux-aggregator-feed.service -n 100`
2. Include the output of: `sudo netstat -tlnp | grep dump1090`
3. Include the output of: `ping -c 4 104.225.219.254`

## Credits

Thanks for contributing to the ADS-B tracking network! Your data helps improve flight tracking coverage.
