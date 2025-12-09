# REM ESP32 Firmware

Continuous audio recording firmware for ESP32 with I2S microphone support.

## Hardware Requirements

- ESP32 development board (ESP32-DevKitC or similar)
- I2S MEMS microphone (e.g., INMP441, ICS-43434, SPH0645)
- USB cable for programming and power
- **Config Button**: GPIO 0 (BOOT button) - built-in on most ESP32 boards

## I2S Microphone Wiring

Default pin configuration (can be changed in `include/config.h`):

| I2S Signal | ESP32 Pin | Description |
|------------|-----------|-------------|
| SCK (BCLK) | GPIO 14   | Bit Clock   |
| WS (LRCLK) | GPIO 15   | Word Select |
| SD (DOUT)  | GPIO 32   | Serial Data |
| VDD        | 3.3V      | Power       |
| GND        | GND       | Ground      |

## Setup Instructions

### 1. Install PlatformIO

```bash
# Using VS Code
# Install the PlatformIO IDE extension

# Or using CLI
pip install platformio
```

### 2. Configure Secrets

```bash
cd esp32
cp include/secrets.h.example include/secrets.h
```

Edit `include/secrets.h` with your API credentials:
- API Gateway URL (from Terraform output)
- API Key
- User ID

**Note:** WiFi credentials can now be configured via the web portal (see "WiFi Configuration" section below), so you can leave `WIFI_SSID` and `WIFI_PASSWORD` empty in `secrets.h`.

### 3. Build and Upload

```bash
# Install dependencies first
cd esp32
pio lib install

# Build the firmware
pio run

# Upload to ESP32
pio run --target upload

# Monitor serial output
pio device monitor
```

## WiFi Configuration

### Method 1: Web Portal (Recommended)

The easiest way to configure WiFi is using the built-in web portal:

1. **Enter Config Mode**:
   - Press and hold the **BOOT button** (GPIO 0) for **3 seconds**
   - Serial monitor will show: "Entering WiFi config mode!"

2. **Connect to ESP32**:
   - On your phone/laptop, connect to WiFi network: **`REM-Setup`**
   - Password: **`rem12345`**

3. **Configure WiFi**:
   - Browser should auto-open to `192.168.4.1` (if not, navigate manually)
   - Click "Configure WiFi"
   - Select your WiFi network from the list
   - Enter your WiFi password
   - Click "Save"

4. **Done!**:
   - ESP32 will restart and connect to your WiFi
   - Credentials are saved permanently in flash memory
   - No need to re-flash firmware!

### Method 2: Hard-coded in secrets.h (Legacy)

You can also hard-code WiFi credentials in `include/secrets.h`:

```cpp
#define WIFI_SSID "YourWiFiNetwork"
#define WIFI_PASSWORD "YourPassword"
```

**Note:** Web portal method is preferred as it allows changing WiFi without re-flashing.

### Changing WiFi Networks

To connect to a different WiFi network:
- Press and hold BOOT button for 3 seconds
- Follow the web portal steps above
- Old credentials will be replaced

## Configuration

### Audio Settings (`include/config.h`)

- `SAMPLE_RATE`: 16000 Hz (16 kHz)
- `BITS_PER_SAMPLE`: 16-bit
- `CHANNELS`: 1 (mono)
- `CHUNK_DURATION_MS`: 300000 (5 minutes)

### Storage Settings

- `MAX_STORAGE_BYTES`: 3 MB (adjust based on your ESP32 partition)
- `MIN_FREE_SPACE`: 512 KB

### WiFi and Upload

- `WIFI_CHECK_INTERVAL_MS`: 1800000 (30 minutes) - how often to check WiFi and upload
- `UPLOAD_MAX_RETRIES`: 5
- `HTTP_TIMEOUT_MS`: 30000 (30 seconds)
- `CONFIG_BUTTON_PIN`: 0 (GPIO 0 / BOOT button)
- `CONFIG_BUTTON_HOLD_MS`: 3000 (3 seconds to enter config mode)

## How It Works

1. **Continuous Recording**: Records audio from I2S microphone in 5-minute chunks
2. **Local Storage**: Saves WAV files to SPIFFS with timestamp filenames
3. **WiFi Upload**: Periodically checks for WiFi and uploads pending files
4. **Storage Management**: Automatically deletes uploaded files when storage is low
5. **Retry Logic**: Exponential backoff for failed uploads

## File Structure

```
/recordings/
  20251209_143022.wav
  20251209_143522.wav
  ...
/upload_index.json  (tracks uploaded files)
```

## Troubleshooting

### WiFi Configuration Issues

**Can't enter config mode:**
- Make sure you're holding the BOOT button for full 3 seconds
- Check serial monitor for "Config button pressed..." message
- Try pressing the button labeled "BOOT" or "IO0" on your ESP32 board

**Can't see REM-Setup WiFi network:**
- Wait 10-15 seconds after entering config mode
- Check that your phone's WiFi is enabled
- Make sure you're looking for 2.4GHz networks (ESP32 doesn't support 5GHz)
- Try restarting the ESP32 and entering config mode again

**Can't connect to REM-Setup:**
- Password is: `rem12345` (all lowercase)
- Some phones require you to stay on the network even if it says "No Internet"

**Browser doesn't open automatically:**
- Manually navigate to: `http://192.168.4.1`
- Try different browsers (Chrome, Safari, Firefox)

**Config portal times out:**
- Default timeout is 5 minutes
- If timeout occurs, ESP32 continues recording
- Just enter config mode again to retry

**ESP32 won't connect to my WiFi:**
- Double-check WiFi password (case-sensitive!)
- Ensure your WiFi is 2.4GHz (not 5GHz only)
- Check that WiFi network is in range
- Some enterprise WiFi networks with special authentication may not work

### No audio recorded
- Check I2S microphone wiring
- Verify microphone power (3.3V)
- Check serial monitor for I2S initialization errors

### Upload failures
- First, ensure WiFi is connected (check serial monitor)
- Verify API Gateway URL and API key in `secrets.h`
- Monitor serial output for HTTP error codes
- Check that API Gateway is deployed (run `terraform output`)

### Storage full
- Increase `MAX_STORAGE_BYTES` if you have larger partition
- Decrease `CHUNK_DURATION_MS` for smaller files
- Ensure WiFi connectivity for regular uploads

## Serial Debug Output

Enable/disable debug output in `include/config.h`:

- `DEBUG_SERIAL`: General debug messages
- `DEBUG_AUDIO`: Verbose audio recording debug
- `DEBUG_UPLOAD`: Upload process debug

## LED Indicators (Optional)

You can add LED indicators by modifying the code:
- Recording: Blink during audio capture
- WiFi: Solid when connected
- Upload: Flash during file upload




## Battery Life

### Estimated Runtime

With an **18650 3.7V 2200mAh Li-ion battery**:

**Current configuration (WiFi check every 30 minutes):**
- **~40-45 hours** of continuous recording

**Power consumption breakdown:**
- Recording only (WiFi off): ~85mA
- WiFi active (uploading): ~200mA
- Average with 30-min WiFi interval: ~88mA

### Optimizing Battery Life

**1. Reduce WiFi Check Frequency** (in `include/config.h`):
```cpp
// Check every hour instead of 30 minutes
#define WIFI_CHECK_INTERVAL_MS   (60 * 60 * 1000)  // 60 minutes
// Result: ~50-55 hours
```

**2. Use Larger Battery:**
- 3000mAh: ~60 hours
- 5000mAh: ~100 hours
- 10000mAh power bank: ~200 hours

**3. Lower Sample Rate** (in `include/config.h`):
```cpp
#define SAMPLE_RATE 8000  // Instead of 16000
// Result: ~25% battery savings, but lower audio quality
```

**4. Add Deep Sleep** (advanced):
- Record for 5 minutes, sleep for 55 minutes
- Can extend to 200+ hours (8+ days)
- Requires code modifications

**5. Solar Power:**
- Add 5V solar panel + charge controller
- Enables indefinite operation in daylight
