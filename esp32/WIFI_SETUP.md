# WiFi Setup Guide - REM ESP32

Quick visual guide for setting up WiFi on your REM ESP32 device.

## 🔧 What You Need

- REM ESP32 device (already flashed with firmware)
- Smartphone or laptop with WiFi
- Your WiFi network name and password

## 📱 Step-by-Step Setup

### Step 1: Enter Configuration Mode

1. **Locate the BOOT button** on your ESP32 board
   - Usually labeled "BOOT", "IO0", or "FLASH"
   - On ESP32-DevKitC: It's the button next to the USB port

2. **Press and HOLD the BOOT button for 3 seconds**
   - You'll see the LED blink
   - Serial monitor shows: "Entering WiFi config mode!"

3. **Release the button**
   - ESP32 is now in configuration mode
   - It creates a WiFi access point

### Step 2: Connect Your Phone

1. **Open WiFi settings** on your phone/laptop

2. **Look for network named:** `REM-Setup`

3. **Connect to REM-Setup**
   - Password: `rem12345`
   - Your phone may warn "No Internet" - that's OK, stay connected!

### Step 3: Configure WiFi

1. **Browser should auto-open** to configuration page
   - If not, manually go to: `http://192.168.4.1`

2. **Click "Configure WiFi"** button

3. **Select your WiFi network** from the list
   - Or manually enter SSID if hidden

4. **Enter your WiFi password**
   - Make sure it's correct (case-sensitive!)

5. **Click "Save"**

### Step 4: Done!

1. **ESP32 will restart** automatically

2. **It connects to your WiFi** network
   - Serial monitor shows: "WiFi connected!"
   - Shows IP address

3. **Recording continues** and uploads will work!

## 🔄 Changing WiFi Networks

Need to connect to a different WiFi? Just repeat the process:

1. Press and hold BOOT button for 3 seconds
2. Connect to `REM-Setup` again
3. Enter new WiFi credentials
4. Save and restart

The old WiFi credentials will be replaced with the new ones.

## ❓ Troubleshooting

### "I don't see REM-Setup network"

- Wait 15-20 seconds after pressing the button
- Make sure you're looking at 2.4GHz networks (not 5GHz)
- Try restarting ESP32 and entering config mode again

### "Can't connect to REM-Setup"

- Password is: `rem12345` (all lowercase, no spaces)
- Some phones ask if you want to stay connected despite "no internet" - say YES

### "Browser doesn't open automatically"

- Manually type in browser: `http://192.168.4.1`
- Try different browser (Chrome, Safari, Firefox)
- Make sure you're still connected to REM-Setup WiFi

### "ESP32 won't connect to my WiFi"

- Double-check password (it's case-sensitive!)
- Make sure your WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Check WiFi signal strength - ESP32 needs to be in range
- Some enterprise/hotel WiFi with special login pages won't work

### "Config portal timed out"

- Default timeout is 5 minutes
- ESP32 will continue recording even if config times out
- Just enter config mode again to retry

## 🔒 Security Notes

- **Change the AP password**: Edit `CONFIG_AP_PASSWORD` in `include/config.h` if you want a different password for REM-Setup
- **WiFi credentials are stored securely** in ESP32 flash memory
- **Not transmitted** anywhere except to your WiFi router

## 💡 Pro Tips

1. **First-time setup**: If you leave WiFi credentials empty in `secrets.h`, the ESP32 will automatically enter config mode on first boot

2. **Multiple devices**: Each ESP32 creates its own `REM-Setup` network, so you can configure multiple devices

3. **No re-flashing needed**: Once configured, WiFi credentials persist across reboots and power cycles

4. **Serial monitor**: Always helpful to have serial monitor open during setup to see what's happening

## 📊 What Happens After Setup?

Once WiFi is configured:

1. ✅ ESP32 connects to your WiFi automatically on boot
2. ✅ Records audio continuously (5-minute chunks)
3. ✅ Uploads to AWS every 30 minutes when WiFi is available
4. ✅ Stores recordings locally until uploaded
5. ✅ Cleans up old files after successful upload

## 🆘 Still Having Issues?

Check the serial monitor output:
```bash
pio device monitor
```

Look for:
- "WiFi connected!" - Good! ✅
- "Failed to connect" - Check password and signal strength
- "Config portal timeout" - Try again, you have 5 minutes

---

**Need more help?** Check the main [README.md](README.md) or the [Troubleshooting section](README.md#troubleshooting).

