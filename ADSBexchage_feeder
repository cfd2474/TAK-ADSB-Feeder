# Feeding ADS-B Exchange Image to Custom Aggregator

This guide will help you configure your ADS-B Exchange feeder to also send data to the TAK-ADSB aggregator at `104.225.219.254`.

## Overview

The ADS-B Exchange feeder image already has `readsb` running and collecting aircraft data. We'll configure it to send a copy of this data to the aggregator using Beast format output.

## Prerequisites

- Working ADS-B Exchange feeder (any supported hardware)
- SSH access to your feeder
- Basic command line knowledge

## Configuration Steps

### Step 1: Access Your Feeder

SSH into your ADS-B Exchange feeder:

```bash
ssh pi@<your-feeder-ip>
```

Default password is typically `adsb` or `raspberry` (check ADS-B Exchange documentation if needed).

### Step 2: Edit the Readsb Configuration

We need to add an additional Beast output to the existing readsb configuration.

```bash
sudo nano /etc/default/adsbexchange
```

### Step 3: Add the Aggregator Output

Find the line that starts with `RECEIVER_OPTIONS=` or `READSB_NET_CONNECTOR=`. 

Add the following to send data to the aggregator:

```bash
--net-connector 104.225.219.254,30004,beast_out
```

**Example of what it might look like:**

If your config has:
```bash
RECEIVER_OPTIONS="--net-connector feed.adsbexchange.com,30004,beast_out"
```

Change it to:
```bash
RECEIVER_OPTIONS="--net-connector feed.adsbexchange.com,30004,beast_out --net-connector 104.225.219.254,30004,beast_out"
```

Save the file with `Ctrl+X`, then `Y`, then `Enter`.

### Step 4: Restart the Service

Restart the ADS-B Exchange feeder service to apply changes:

```bash
sudo systemctl restart adsbexchange-feed
```

Or try:

```bash
sudo systemctl restart readsb
```

(The exact service name depends on your ADS-B Exchange image version)

### Step 5: Verify Connection

Check that the service restarted successfully:

```bash
sudo systemctl status adsbexchange-feed
```

You should see the service as `active (running)` with no errors.

## Troubleshooting

### Service Won't Start

Check the service logs:
```bash
sudo journalctl -u adsbexchange-feed -n 50
```

### Not Seeing Your Feed on the Aggregator

1. Verify your internet connection is working
2. Check that port 30004 is not blocked by your firewall
3. Confirm the service is running: `sudo systemctl status adsbexchange-feed`
4. Wait 2-5 minutes for the connection to establish

### Finding the Right Configuration File

If `/etc/default/adsbexchange` doesn't exist, try:
- `/etc/default/readsb`
- `/boot/adsbx-env`

Or search for it:
```bash
sudo find /etc -name "*adsb*" -o -name "*readsb*"
```

## Alternative: Using Tailscale (Optional)

If you're using Tailscale VPN, you can connect through the VPN instead:

1. Install Tailscale on your feeder
2. Connect to Mike's tailnet
3. Use the Tailscale IP instead of `104.225.219.254` in the configuration above

## Support

If you encounter issues:
- Check the GitHub repository for updates
- Open an issue on GitHub with your service logs
- Ensure your ADS-B Exchange feeder is working correctly first

## What Happens Next

Once configured:
- Your feeder will send aircraft data to both ADS-B Exchange AND the aggregator
- The aggregator will display your feeder with a location-based name
- You can view the aggregated data at the web interface
- Your ADS-B Exchange feeding is not affected

---

**Note:** This configuration does not interfere with your existing ADS-B Exchange feeding. You're simply adding an additional output destination for your data.
