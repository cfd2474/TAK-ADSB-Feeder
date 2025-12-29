# ADS-B Feeder Quick Start Guide
### Prerequisites

**Hardware per feeder:**
- Raspberry Pi 3B or newer
- FlightAware USB SDR dongle (or compatible RTL-SDR)
- MicroSD card (16GB minimum, Class 10)
- Power supply (5V 2.5A minimum)
- Internet connection (WiFi or Ethernet)

**Software:**
- Raspberry Pi Bookwork OS Lite (64-bit recommended)
- SSH enabled


### 🚀 Quick Deploy (5 Minutes to First Aircraft!)

---

## Step 1: Prepare the SD Card

**Using Raspberry Pi Imager:**

1. Download **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Insert SD card (16GB+ recommended)
3. Click **"Choose OS"** → **"Raspberry Pi OS (other)"** → **"Raspberry Pi OS Lite Bookworm (64-bit)"**
4. Click **"Choose Storage"** → Select your SD card
5. Click **⚙️ (Settings)**:
   - ✅ Set hostname: `adsb-pi-01` (increment for each feeder)
   - ✅ Enable SSH
   - ✅ Set username/password (default: `pi` / your password)
   - ✅ Configure WiFi (if using wireless)
   - ✅ Set locale settings
6. Click **"Write"** and wait for completion

**Important:** Note the hostname you set - you'll need it to SSH in!

---

## Step 2: Boot and Connect

1. Insert SD card into Raspberry Pi
2. Connect antenna to RTL-SDR dongle
3. Connect RTL-SDR to Pi USB port
4. Power on the Pi
5. Wait 1-2 minutes for first boot

**Find your Pi's IP address:**
```bash
# On your Mac/Linux:
ping adsb-pi-01.local

# Or check your router's DHCP table
# Or use: nmap -sn 192.168.1.0/24
```

---

## Step 3: Copy and Run Installer

**From your Mac/computer:**

```bash
# Copy installer to the Pi
scp adsb_feeder_installer_v2.sh pi@adsb-pi-01.local:~/

# SSH into the Pi
ssh pi@adsb-pi-01.local

# On the Pi - make executable and run
chmod +x adsb_feeder_installer_v2.sh
./adsb_feeder_installer_v2.sh
```

**The installer will:**
- ✅ Update the system
- ✅ Install all dependencies
- ✅ Install and authenticate Tailscale (using your auth key)
- ✅ Configure RTL-SDR drivers
- ✅ Build and install readsb
- ✅ Build and install mlat-client
- ✅ Create and start services
- ✅ Verify connections

**Installation takes ~15-20 minutes** (mostly compiling readsb)

---

## Step 4: Enter Location Details

When prompted, enter your feeder's location:

```
Enter feeder latitude (e.g., 33.834378): 33.834378
Enter feeder longitude (e.g., -117.573072): -117.573072
Enter feeder altitude in meters (e.g., 380): 380
```

**To find your location:**
- Google Maps: Right-click → "What's here?" → Copy coordinates
- Altitude: https://www.whatismyelevation.com/

---

## Step 5: Verify Everything Works

**Automatically shown after installation:**

```
Service Status:
  readsb:       ✓ Running
  mlat-client:  ✓ Running
  tailscale:    ✓ Connected

Network Connections:
  Beast (30004): ✓ Connected
  MLAT (30105):  ✓ Connected
```

**Manual verification:**
```bash
# Check connections
netstat -tn | grep 100.117.34.88

# Expected output:
# tcp  0  0  100.x.x.x:XXXXX  100.117.34.88:30004  ESTABLISHED
# tcp  0  0  100.x.x.x:XXXXX  100.117.34.88:30105  ESTABLISHED

# View live aircraft (press 'q' to quit)
/usr/local/bin/viewadsb
```

---

## Step 6: Check Aggregator

**On your aggregator server:**

```bash
# See connected feeders
sudo netstat -tn | grep 30004
sudo netstat -tn | grep 30105

# Open web interface
# http://100.117.34.88:8080
```

**You should now see aircraft from your new feeder!** 🎉

---

## 🔧 Troubleshooting

### Pi won't boot / can't find it on network

```bash
# Check connections:
# - Power supply adequate? (5V 2.5A minimum)
# - Ethernet cable connected?
# - WiFi credentials correct?

# Try connecting monitor + keyboard
# Or re-flash SD card with SSH definitely enabled
```

### "Connection refused" when trying to SSH

```bash
# Wait longer - first boot can take 2-3 minutes
# Verify SSH was enabled in Pi Imager settings
# Check firewall on your computer
```

### Installer fails during compilation

```bash
# Usually means low memory
# For Pi 3B, this is normal - just let it finish
# If it crashes, increase swap:
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Change CONF_SWAPSIZE=100 to CONF_SWAPSIZE=1024
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
# Re-run installer
```

### Services running but no connection to aggregator

```bash
# Check Tailscale is connected
sudo tailscale status

# Ping aggregator
ping 100.117.34.88

# Check readsb has --net flag
ps aux | grep readsb | grep -- --net

# If missing, it didn't install correctly
# Re-run installer or manually edit service:
sudo nano /etc/systemd/system/readsb.service
# Add --net after --ppm 0
sudo systemctl daemon-reload
sudo systemctl restart readsb
```

### RTL-SDR not detected

```bash
# Check USB connection
lsusb | grep RTL

# Should show: "Realtek Semiconductor Corp. RTL2838 DVB-T"

# If not:
# 1. Try different USB port
# 2. Check dongle LED (should be lit)
# 3. Try dongle on another computer
# 4. Reboot Pi: sudo reboot
```

---

## 📝 For Multiple Feeders

### Naming Convention

For each new feeder:
1. Change hostname in Pi Imager: `adsb-pi-01`, `adsb-pi-02`, etc.
2. Each gets unique Tailscale IP automatically
3. Each auto-generates unique feeder name

### Parallel Deployment

**You can run multiple installations simultaneously:**

```bash
# Terminal 1
scp adsb_feeder_installer_v2.sh pi@adsb-pi-01.local:~/
ssh pi@adsb-pi-01.local "./adsb_feeder_installer_v2.sh"

# Terminal 2
scp adsb_feeder_installer_v2.sh pi@adsb-pi-02.local:~/
ssh pi@adsb-pi-02.local "./adsb_feeder_installer_v2.sh"

# etc...
```

### Inventory Tracking

**Create a spreadsheet with:**
- Hostname
- Tailscale IP
- Feeder Name
- Location (lat/lon/alt)
- MAC address
- Installation date
- Serial number (if labeled)

**Or pull from each Pi:**
```bash
ssh pi@adsb-pi-01.local "cat /etc/adsb-feeder-info.txt"
```

---

## 🎯 Production Assembly Line

**For maximum efficiency:**

1. **Batch flash SD cards** (5-10 at a time)
   - Use unique hostnames
   - Same WiFi/SSH settings
   - Label cards with hostname

2. **Physical assembly**
   - Attach antenna to dongle
   - Label each Pi with hostname
   - Pre-position for deployment

3. **Parallel installation**
   - Power on all Pis
   - Run installers in parallel (multiple terminals)
   - Each takes ~15-20 minutes

4. **Verification**
   - Check aggregator shows all feeders
   - Record Tailscale IPs
   - Add to inventory

**Time per feeder:** ~20 minutes (can overlap multiple)

---

## ⚡ Speed Tips

### Skip the prompts entirely

**Edit installer before copying to Pi:**

```bash
# In adsb_feeder_installer_v2.sh, set these:
FEEDER_LAT="33.834378"      # Your location
FEEDER_LON="-117.573072"
FEEDER_ALT="380"            # In meters
TAILSCALE_AUTH_KEY="tskey-auth-kSQ4LgPRaL11CNTRL-KP6wnd6pnXLdGtYjBp5TYL4YkkvS5hKJ"  # Already set!
```

**Then copy and run with one command:**

```bash
scp adsb_feeder_installer_v2.sh pi@adsb-pi-01.local:~/ && \
ssh pi@adsb-pi-01.local "chmod +x adsb_feeder_installer_v2.sh && ./adsb_feeder_installer_v2.sh"
```

**Zero interaction needed!** Just watch it complete.

### Pre-configured master image

**After first successful install:**

```bash
# On your Mac/computer with SD card reader
# Shut down the Pi first!
ssh pi@adsb-pi-01.local "sudo shutdown -h now"

# Remove SD card, insert into Mac
sudo dd if=/dev/diskX of=adsb-feeder-master.img bs=4M status=progress

# Clone to new cards
sudo dd if=adsb-feeder-master.img of=/dev/diskX bs=4M status=progress
```

**Important after cloning:**
- Must change hostname (or Tailscale conflicts)
- Tailscale will auto-reconnect with same auth key
- Each clone gets unique feeder name (based on MAC)

---

## 📊 Monitoring Dashboard

**On aggregator, create monitoring script:**

```bash
#!/bin/bash
# save as: /usr/local/bin/feeder-status.sh

echo "=== ADS-B Feeder Network Status ==="
echo ""
echo "Connected Beast Feeders (Port 30004):"
sudo netstat -tn | grep :30004 | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort
echo ""
echo "Connected MLAT Feeders (Port 30105):"
sudo netstat -tn | grep :30105 | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort
echo ""
echo "Active Connections:"
echo "  Beast: $(sudo netstat -tn | grep :30004 | grep ESTABLISHED | wc -l)"
echo "  MLAT:  $(sudo netstat -tn | grep :30105 | grep ESTABLISHED | wc -l)"
echo ""
echo "Total Aircraft Tracked:"
curl -s http://localhost:8080/data/aircraft.json 2>/dev/null | python3 -c "import sys, json; print(len(json.load(sys.stdin)['aircraft']))" 2>/dev/null || echo "N/A"
```

**Run it:**
```bash
chmod +x /usr/local/bin/feeder-status.sh
feeder-status.sh
```

---

## 🔒 Security Checklist

- [x] Tailscale auth key configured (auto-authenticates)
- [ ] Change default Pi password (do this!)
- [ ] Enable automatic security updates
- [ ] Disable WiFi if using Ethernet
- [ ] Keep Tailscale auth key secure (already in installer)

**Change default password:**
```bash
ssh pi@adsb-pi-01.local
passwd
# Enter new password twice
```

**Enable auto-updates:**
```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## ✅ Final Checklist

**Before closing the box:**
- [ ] Green LED on Pi (power)
- [ ] Flickering activity LED (booting/running)
- [ ] RTL-SDR LED lit
- [ ] Antenna connected
- [ ] Tailscale connected: `sudo tailscale status`
- [ ] Services running: `sudo systemctl status readsb mlat-client`
- [ ] Both connections established: `netstat -tn | grep 100.117.34.88`
- [ ] Aircraft visible: `/usr/local/bin/viewadsb`
- [ ] Aggregator receiving data
- [ ] Feeder info saved: `cat /etc/adsb-feeder-info.txt`

**Expected continuous operation:**
- Services auto-restart on failure
- Survives reboots
- Reconnects to Tailscale automatically
- No maintenance needed (monthly updates recommended)

---

## 🆘 Getting Help

**Check logs:**
```bash
sudo journalctl -fu readsb      # Live readsb logs
sudo journalctl -fu mlat-client # Live MLAT logs
sudo journalctl -u readsb -n 100 # Last 100 readsb lines
```

**Common log messages (normal):**
```
"Stats" - Good! Shows aircraft being decoded
"beast_out: Connection established" - Good! Connected to aggregator
"mlat: Connected to server" - Good! MLAT working
```

**Bad log messages:**
```
"No supported devices found" - RTL-SDR not detected
"Connection refused" - Can't reach aggregator
"Permission denied" - USB permissions issue
```

---

## 🎉 Success Criteria

**You're done when:**

1. ✅ Installer completed without errors
2. ✅ Both services show "✓ Running"
3. ✅ Both connections show "✓ Connected"
4. ✅ `viewadsb` shows aircraft
5. ✅ Aggregator web UI shows aircraft from this feeder
6. ✅ Feeder info saved to `/etc/adsb-feeder-info.txt`

**Typical timeline:**
- Flash SD card: 5 minutes
- First boot: 2 minutes
- Copy installer: 30 seconds
- Run installer: 15-20 minutes
- Verification: 2 minutes

**Total: ~25 minutes per feeder**

---

*Ready to build your ADS-B network!* ✈️🛰️

**Next feeder:** Just repeat steps 1-6 with a new hostname!
