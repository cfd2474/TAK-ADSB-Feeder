# How to Feed Your airplanes.live Receiver to My ADS-B Aggregator

This guide will walk you through configuring your existing **airplanes.live** feeder to also send ADS-B data to my aggregator. This will NOT disrupt your existing airplanes.live feed.

**Follow [MLAT Guide](MLAT_config.md) to add MLAT service after completing this process**

## Prerequisites

- A working airplanes.live feeder (using their Pi image or feed client)
- Internet connectivity
- SSH client (built into Mac/Linux, use PuTTY on Windows)
- 10 minutes of time

## Important Notes

- This setup creates an ADDITIONAL feed to my aggregator
- Your airplanes.live feed will continue working normally
- You can feed via public IP (104.225.219.254) or Tailscale (100.117.34.88)
- **Tailscale is recommended** for better security and reliability

## Connection Information

Choose ONE of these connection methods:

### Option A: Tailscale Connection (Recommended)
- **Aggregator IP**: `100.117.34.88`
- **Beast Port**: `30004`
- **MLAT Port**: `30105`
- **Requirements**: Join the Tailscale network (contact for invite)

### Option B: Public IP Connection
- **Aggregator IP**: `104.225.219.254`
- **Beast Port**: `30004`
- **MLAT Port**: `30105`
- **Requirements**: None, but less secure than Tailscale

## Step 1: SSH into Your airplanes.live Feeder
```bash
ssh pi@<your-feeder-ip>
# Default password is usually 'adsb' or 'raspberry'
```

## Step 2: Locate Your readsb Configuration

The airplanes.live image uses readsb. Find the configuration file:
```bash
# Check which config file exists
ls -la /etc/default/readsb
ls -la /etc/default/readsb-net

# Typically it's one of these:
sudo nano /etc/default/readsb
# OR
sudo nano /etc/default/readsb-net
```

## Step 3: Add the Additional Feed

Look for the line that starts with `READSB_NET_CONNECTOR=` or `NET_OPTIONS=`.

### If Using Tailscale (Recommended):

Add this to the existing `READSB_NET_CONNECTOR` line:
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;100.117.34.88,30004,beast_out"
```

**Full example of what your config might look like:**
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;100.117.34.88,30004,beast_out"
```

### If Using Public IP:
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;104.225.219.254,30004,beast_out"
```

**Note:** The semicolon (`;`) separates multiple feed destinations.

## Step 4: Verify Your Configuration

Double-check your configuration:
```bash
# View the full configuration
cat /etc/default/readsb
```

**What to verify:**
- ✅ Original airplanes.live feed still present (`feed.adsb.lol,30004`)
- ✅ New aggregator feed added with **port 30004** (not 30005!)
- ✅ Semicolon separating the feeds
- ✅ Correct IP address (Tailscale `100.117.34.88` or public `104.225.219.254`)

## Step 5: Restart readsb Service
```bash
sudo systemctl restart readsb
```

Wait about 30 seconds for the service to fully restart.

## Step 6: Verify the Connection

### Check Service Status
```bash
sudo systemctl status readsb
```

Should show `active (running)` in green.

### Check Network Connections

**If using Tailscale:**
```bash
netstat -tn | grep 100.117.34.88
```

**If using public IP:**
```bash
netstat -tn | grep 104.225.219.254
```

You should see an `ESTABLISHED` connection on port 30004.

### View Logs
```bash
sudo journalctl -u readsb -f
```

Look for messages indicating successful connection to the aggregator. Press `Ctrl+C` to exit.

## Step 7: Verify Data on Aggregator

After a few minutes, check that your feeder appears on the aggregator:

**Network Statistics:**
```
http://104.225.219.254/graphs1090/
```

Your feeder should appear in the list with aircraft counts.

**Network Map:**
```
http://104.225.219.254/tar1090/
```

You should see aircraft from your feeder appearing on the map.

## Troubleshooting

### Connection Not Established

**Check if readsb is running:**
```bash
sudo systemctl status readsb
```

**View detailed logs:**
```bash
sudo journalctl -u readsb -n 100 --no-pager
```

**Verify configuration syntax:**
```bash
grep READSB_NET_CONNECTOR /etc/default/readsb
```

### airplanes.live Feed Stopped Working

If you accidentally broke your airplanes.live feed:

1. Check that `feed.adsb.lol,30004,beast_reduce_plus_out` is still in your config
2. Verify the semicolon separator is present
3. Restart readsb: `sudo systemctl restart readsb`

### Wrong Port Error

**Common mistake:** Using port 30005 instead of 30004

The aggregator expects Beast input on **port 30004**. If you see connection refused errors, verify you're using the correct port:
```bash
grep "30004" /etc/default/readsb
```

Should show your aggregator connection with port **30004**, not 30005.

### Still Having Issues?

**Check your configuration matches one of these exactly:**

**Tailscale:**
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;100.117.34.88,30004,beast_out"
```

**Public IP:**
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;104.225.219.254,30004,beast_out"
```

## Adding MLAT Support

Once your Beast feed is working, add MLAT support by following the **[MLAT Configuration Guide](MLAT_config.md)**.

MLAT enables multilateration, which improves aircraft position accuracy by combining data from multiple feeders.

## What's Happening?

Your airplanes.live feeder is now sending data to TWO destinations:
1. **airplanes.live** - Your original feed continues unchanged
2. **My Aggregator** - Additional feed on port 30004 (Beast protocol)

Both feeds operate independently. If one stops working, the other continues normally.

## Configuration Breakdown
```bash
READSB_NET_CONNECTOR="feed.adsb.lol,30004,beast_reduce_plus_out;100.117.34.88,30004,beast_out"
```

- `feed.adsb.lol,30004,beast_reduce_plus_out` - Original airplanes.live feed
- `;` - Separator between multiple feeds
- `100.117.34.88,30004,beast_out` - New aggregator feed
  - `100.117.34.88` - Aggregator Tailscale IP
  - `30004` - Beast input port (CORRECT)
  - `beast_out` - Protocol type

## Network Ports Reference

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Aggregator Beast | **30004** | Beast | Main ADS-B data feed (USE THIS) |
| Aggregator MLAT | 30105 | MLAT | Multilateration server |
| Local Beast Output | 30005 | Beast | Local readsb output (NOT for aggregator) |
| airplanes.live | 30004 | Beast | Original feed destination |

## Need Help?

- Open a GitHub issue for problems with this guide
- Check the main [README.md](../README.md) for general information
- Review [MLAT_config.md](MLAT_config.md) for MLAT setup

---

**Summary:** Your airplanes.live feeder now feeds BOTH airplanes.live AND my aggregator. Nothing is broken, everything continues to work, and you're contributing to multiple networks! 🎉
