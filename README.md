# TAK-ADSB-Feeder

Automated installer for Raspberry Pi ADS-B feeders with Tailscale integration. Feed real-time aircraft tracking data to your aggregation server over a secure mesh network.

## 🚀 Quick Install

On a Raspberry Pi running Bookworm Lite:

```bash
wget https://raw.githubusercontent.com/cfd2474/TAK-ADSB-Feeder/main/adsb_feeder_installer_v2.sh
chmod +x adsb_feeder_installer_v2.sh
./adsb_feeder_installer_v2.sh
```

That's it! Enter your location when prompted and wait 15-20 minutes.

> **💡 Tip:** Name your Pi using its zip code (e.g., `adsb-pi-92882`) for easy identification!

## 📋 What This Does

The installer automatically:
- ✅ Installs and configures Tailscale VPN
- ✅ Installs RTL-SDR drivers and tools
- ✅ Builds and installs `readsb` ADS-B decoder
- ✅ Builds and installs `mlat-client` for multilateration
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
- **Tailscale Auth**: Embedded (auto-authenticates)

You'll be prompted for:
- Latitude (e.g., `33.834378`)
- Longitude (e.g., `-117.573072`)
- Altitude in meters (e.g., `380`)

## 🌐 Network Architecture

```
┌─────────────────┐
│  RTL-SDR Dongle │
│   (1090 MHz)    │
└────────┬────────┘
         │
         │ USB
         │
┌────────▼────────┐      Tailscale VPN      ┌──────────────────┐
│  Raspberry Pi   │◄────────────────────────►│   Aggregator     │
│   (readsb +     │   Beast: Port 30004      │   Server         │
│   mlat-client)  │   MLAT:  Port 30105      │   (tar1090)      │
└─────────────────┘                          └──────────────────┘
```

All communication happens over **Tailscale** - no port forwarding or public IPs needed!

## 📊 What You'll See

After installation, aircraft data feeds to your aggregator server where you can view:
- Real-time aircraft positions on a map
- Flight details (callsign, altitude, speed, heading)
- Aircraft tracks and history
- Combined data from all your feeders

Access the web interface at: `http://104.225.219.254/tar1090/`

## 🔍 Verification

After installation completes, check:

```bash
# Service status
sudo systemctl status readsb
sudo systemctl status mlat-client

# Network connections
netstat -tn | grep 100.117.34.88

# Live aircraft data
/usr/local/bin/viewadsb
```

## 🐛 Troubleshooting

### Services won't start
```bash
sudo journalctl -fu readsb
sudo journalctl -fu mlat-client
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

## 🔄 Updating

To update an existing feeder:

```bash
# Update readsb
cd /tmp
git clone https://github.com/wiedehopf/readsb.git
cd readsb
make -j$(nproc) RTLSDR=yes
sudo systemctl stop readsb
sudo cp readsb /usr/local/bin/
sudo systemctl start readsb

# Update mlat-client
cd /tmp
git clone https://github.com/wiedehopf/mlat-client.git
cd mlat-client
sudo python3 setup.py install
sudo systemctl restart mlat-client
```

## 📈 Scaling to Multiple Feeders

Each feeder gets a unique name automatically: `hostname_MAC`

Deploy multiple feeders by:
1. Flashing SD cards with zip code hostnames (e.g., `adsb-pi-92882`, `adsb-pi-90210`)
2. Running the installer on each Pi
3. All feeders auto-connect to the same aggregator

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for mass production strategies.

## 🔒 Security

- **Tailscale** provides end-to-end encryption
- **No public ports** exposed
- Auth key is embedded but rotatable
- SSH access controlled per your Pi settings

## 🤝 Contributing

Found a bug? Have a suggestion? Open an issue or pull request!

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Credits

Built on top of:
- [readsb](https://github.com/wiedehopf/readsb) by wiedehopf
- [mlat-client](https://github.com/wiedehopf/mlat-client) by wiedehopf
- [Tailscale](https://tailscale.com) for secure networking
- [tar1090](https://github.com/wiedehopf/tar1090) for visualization

## 📧 Support

For issues specific to this installer, open a GitHub issue.

For readsb/mlat-client questions, see their respective repositories.

---

**Happy plane spotting!** ✈️

*Last updated: December 28, 2024*
