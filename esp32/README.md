# REM ESP32 Firmware

Continuous audio recording firmware for ESP32 with I2S microphone support.

## Hardware Requirements

- ESP32 development board (ESP32-DevKitC or similar)
- I2S MEMS microphone (e.g., INMP441, ICS-43434, SPH0645)
- USB cable for programming and power

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

Edit `include/secrets.h` with your credentials:
- WiFi SSID and password
- API Gateway URL (from Terraform output)
- API Key

### 3. Build and Upload

```bash
# Build the firmware
pio run

# Upload to ESP32
pio run --target upload

# Monitor serial output
pio device monitor
```

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

- `WIFI_CHECK_INTERVAL_MS`: 30000 (30 seconds)
- `UPLOAD_MAX_RETRIES`: 5
- `HTTP_TIMEOUT_MS`: 30000 (30 seconds)

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

### No audio recorded
- Check I2S microphone wiring
- Verify microphone power (3.3V)
- Check serial monitor for I2S initialization errors

### Upload failures
- Verify WiFi credentials in `secrets.h`
- Check API Gateway URL and API key
- Monitor serial output for HTTP error codes

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

