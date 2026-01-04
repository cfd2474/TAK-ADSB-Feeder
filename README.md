# TAK-ADSB-Feeder

Automated installer for Raspberry Pi ADS-B feeders with Tailscale integration and **local tar1090 web interface**. Feed real-time aircraft tracking data to your aggregation server over a secure mesh network while monitoring individual feeder performance.

## 🚀 Quick Install

On a Raspberry Pi running Bookworm Lite:

```bash
wget https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/adsb_feeder_installer_v4.1.sh
chmod +x adsb_feeder_installer_v4.1.sh
./adsb_feeder_installer_v4.1.sh
```

That's it! Enter your location when prompted and wait 15-20 minutes.

> **💡 Tip:** Name your Pi using its zip code (e.g., `adsb-pi-92882`) for easy identification!

## ✨ What's New in v4.0

- 🌐 **Local tar1090 web interface** on each Pi feeder
- 📊 **Per-feeder statistics** and coverage visualization
- 📍 **Dual monitoring**: View individual Pi coverage AND network-wide aggregation (from aggregator)
- 🔍 **Better diagnostics** with local aircraft counts and performance metrics (from aggregator)
- 🚀 **Still aggregates** to central server for network-wide view

## 📋 What This Does

The installer automatically:
- ✅ Installs and configures Tailscale VPN
- ✅ Installs RTL-SDR drivers and tools
- ✅ Builds and installs `readsb` ADS-B decoder
- ✅ Builds and installs `mlat-client` for multilateration
- ✅ **NEW:** Installs `tar1090` locally on each Pi
- ✅ **NEW:** Installs `lighttpd` web server
- ✅ Creates systemd services for automatic startup
- ✅ Connects to your aggregation server
- ✅ Verifies everything is working

## 🛠️ Requirements

### Hardware
- Raspberry Pi 3B or newer
- RTL-SDR USB dongle (FlightAware Pro Stick recommended)
- 1090 MHz ADS-B antenna
- MicroSD card (16GB+ recommended)
- 5V 2.5A power supply

### Software
- Raspberry Pi OS Bookworm Lite (64-bit recommended)
- Internet connection (WiFi or Ethernet)
- SSH access enabled

## 📖 Documentation

- **[QUICK_START.md](QUICK_START.md)** - Fast-track setup guide
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete reference for scaling to multiple feeders

## 🔧 Configuration

The installer is pre-configured with:
- **Aggregator IP**: `100.117.34.88` (Tailscale)
- **Beast Port**: `30004`
- **MLAT Port**: `30105`

You'll be prompted for:
- **Tailscale Auth Key** (get from https://login.tailscale.com/admin/settings/keys)
  - Make sure to check **"Reusable"** and **"Pre-authorized"**
  - Do NOT check "Ephemeral"
- **Latitude** (e.g., `33.834378`)
- **Longitude** (e.g., `-117.573072`)
- **Altitude** in meters (antenna height above sea level, e.g., `395`)

> **📏 Altitude Tip:** Use your antenna height, not ground level! Calculate as: Ground Elevation + Building Height + Mast Height

## 🌐 Network Architecture

```
┌─────────────────┐
│  RTL-SDR Dongle │
│   (1090 MHz)    │
└────────┬────────┘
         │
         │ USB
         │
┌────────▼────────────────┐      Tailscale VPN      ┌──────────────────┐
│    Raspberry Pi         │◄────────────────────────►│   Aggregator     │
│  ┌────────────────────┐ │   Beast: Port 30004      │   Server         │
│  │ readsb + tar1090   │ │   MLAT:  Port 30105      │   (tar1090)      │
│  │ (Local Coverage)   │ │                          │   (Network View) │
│  └────────────────────┘ │                          └──────────────────┘
│   lighttpd web server   │
└─────────────────────────┘
     │
     │ http://TAILSCALE_IP/tar1090/
     │ (Individual feeder view)
     │
```

All communication happens over **Tailscale** - no port forwarding or public IPs needed!

## 📊 What You'll See

### Individual Feeder View (NEW in v4.0!)
Access each Pi's local coverage at:
```
http://[TAILSCALE_IP]/tar1090/
```

**Example:**
- `http://100.86.194.33/tar1090/` - View adsb-pi-92878's coverage
- `http://100.99.67.46/tar1090/` - View adsb-pi's coverage

Shows:
- Aircraft received by **this specific feeder**
- Individual coverage area and range
- Per-feeder message rates
- Local signal strength

### Network Aggregated View
Access the combined view at:
```
http://104.225.219.254/tar1090/
```

Shows:
- Aircraft from **ALL feeders** combined
- Network-wide coverage map
- Total aircraft count across all sites
- Aggregated statistics

### Network Statistics Dashboard (NEW!)
Access detailed network stats at:
```
http://104.225.219.254/graphs1090/
```

Features:
- Active feeder list (clickable for drill-down)
- Per-feeder connection status
- Network-wide aircraft counts
- Message rates and performance metrics
- **Click any feeder** to see detailed individual stats

## 🔍 Verification

After installation completes, check:

```bash
# Service status
sudo systemctl status readsb
sudo systemctl status mlat-client
sudo systemctl status lighttpd

# Network connections
netstat -tn | grep 100.117.34.88

# Local tar1090 data
curl http://localhost/tar1090/data/aircraft.json

# Live aircraft data
/usr/local/bin/viewadsb
```

**Find your Tailscale IP:**
```bash
tailscale ip -4
# Example output: 100.86.194.33
```

Then access your local tar1090: `http://100.86.194.33/tar1090/`

## 🐛 Troubleshooting

### Services won't start
```bash
sudo journalctl -fu readsb
sudo journalctl -fu mlat-client
sudo journalctl -fu lighttpd
```

### Local tar1090 shows "decoder not working"
```bash
# Check if JSON files are being created
ls -la /run/readsb/

# If directory doesn't exist:
sudo mkdir -p /run/readsb
sudo chown readsb:readsb /run/readsb
sudo systemctl restart readsb
```

### No connection to aggregator
```bash
# Check Tailscale
sudo tailscale status

# Ping aggregator
ping 100.117.34.88
```

### RTL-SDR not detected
```bash
# Check USB
lsusb | grep RTL

# Should show: "Realtek Semiconductor Corp. RTL2838 DVB-T"
```

See [QUICK_START.md](QUICK_START.md) for detailed troubleshooting.

## 🔄 Updating from v3 to v4

To add local tar1090 to an existing v3 installation:

```bash
# Download upgrade script
wget https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/test_local_tar1090.sh
chmod +x test_local_tar1090.sh

# Run upgrade (auto-detects existing config)
sudo ./test_local_tar1090.sh
```

This will:
- Detect your existing lat/lon/gain settings
- Install tar1090 and lighttpd
- Update readsb to output JSON
- Keep feeding to aggregator
- Back up your current configuration

## 📈 Scaling to Multiple Feeders

Each feeder gets a unique name automatically: `hostname_MAC`

**Best Practice - Use Zip Code Naming:**
1. Flash SD card
2. Set hostname to `adsb-pi-ZIPCODE` (e.g., `adsb-pi-92882`)
3. Run installer
4. Each feeder auto-connects to aggregator
5. **Each feeder gets its own tar1090** at its Tailscale IP

**Access all feeders from the aggregator dashboard:**
- Main stats: `http://104.225.219.254/graphs1090/`
- Click any feeder to see individual stats and coverage

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for mass production strategies.

## 🔒 Security

- **Tailscale** provides end-to-end encryption
- **No public ports** exposed
- **Reusable auth keys** for easy deployment
- SSH access controlled per your Pi settings
- **Local web interfaces** only accessible via Tailscale network

> **🔑 Auth Key Security:** Never commit Tailscale auth keys to public repositories. The installer prompts for the key at runtime for maximum security.

## 🎯 Use Cases

**Individual Feeder Monitoring:**
- Check if a specific Pi is receiving aircraft
- Troubleshoot antenna issues at specific locations
- Compare coverage between different sites
- Verify optimal antenna placement

**Network-Wide View:**
- See combined coverage from all feeders
- Total aircraft count across your network
- Network health and performance
- Identify coverage gaps

**Performance Optimization:**
- Compare individual feeder performance
- Identify best performing locations
- Test antenna modifications
- Optimize network placement

## 🤝 Contributing

Found a bug? Have a suggestion? Open an issue or pull request!

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Credits

Built on top of:
- [readsb](https://github.com/wiedehopf/readsb) by wiedehopf
- [mlat-client](https://github.com/wiedehopf/mlat-client) by wiedehopf
- [tar1090](https://github.com/wiedehopf/tar1090) by wiedehopf
- [Tailscale](https://tailscale.com) for secure networking

Special thanks to the ADS-B community for their continued development and support!

## 📧 Support

For issues specific to this installer, open a GitHub issue.

For readsb/mlat-client/tar1090 questions, see their respective repositories.

---

**Happy plane spotting!** ✈️

**Monitor each feeder individually, view your network collectively!**

*Last updated: January 3, 2026*
*Current version: v4.0*
