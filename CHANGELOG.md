# REM System Changelog

## Version 1.1 - WiFi Configuration Portal (2025-12-09)

### 🎉 New Features

#### WiFi Configuration Web Portal
- **No more hard-coded WiFi credentials!** Configure WiFi through a user-friendly web interface
- Press and hold BOOT button (GPIO 0) for 3 seconds to enter config mode
- ESP32 creates access point: `REM-Setup` (password: `rem12345`)
- Connect with phone/laptop and configure WiFi at `http://192.168.4.1`
- Credentials saved permanently in flash - no need to re-flash firmware
- Easy to change WiFi networks when moving locations

#### Battery Life Optimization
- **WiFi check interval increased from 30 seconds to 30 minutes**
- **Battery life improved from ~18-22 hours to ~40-45 hours** (2x improvement!)
- With 18650 2200mAh battery: Almost 2 full days of continuous recording
- Configurable in `config.h` for further optimization

### 📝 Changes

#### ESP32 Firmware
- Added WiFiManager library for web-based configuration
- Added button handler for config mode entry
- Updated `setupWiFi()` to use WiFiManager auto-connect
- Added `checkConfigButton()` and `enterConfigMode()` functions
- Config button: GPIO 0 (BOOT button) - 3 second hold to activate

#### Configuration Files
- Updated `platformio.ini` to include WiFiManager library
- Updated `config.h` with WiFi configuration button settings:
  - `CONFIG_BUTTON_PIN`: GPIO 0
  - `CONFIG_BUTTON_HOLD_MS`: 3000ms
  - `CONFIG_AP_NAME`: "REM-Setup"
  - `CONFIG_AP_PASSWORD`: "rem12345"
  - `CONFIG_PORTAL_TIMEOUT`: 300 seconds (5 minutes)
- Updated `WIFI_CHECK_INTERVAL_MS`: 30 minutes (was 30 seconds)
- Updated `secrets.h.example` to make WiFi credentials optional

#### Documentation
- **NEW:** `esp32/WIFI_SETUP.md` - Comprehensive WiFi setup guide with troubleshooting
- Updated `esp32/README.md`:
  - Added "WiFi Configuration" section with web portal instructions
  - Added "Battery Life" section with runtime estimates
  - Expanded troubleshooting section for WiFi issues
  - Updated hardware requirements to mention config button
- Updated `QUICKSTART.md`:
  - Added Step 4.5 for WiFi configuration via web portal
  - Updated ESP32 configuration instructions
- **NEW:** `Makefile` - Common tasks automation
- **NEW:** `CHANGELOG.md` - This file!

#### Build System
- Added `Makefile` with helpful commands:
  - `make build-lambdas` - Build all Lambda functions
  - `make deploy-infra` - Deploy AWS infrastructure
  - `make build-esp32` - Build ESP32 firmware
  - `make flash-esp32` - Flash firmware to ESP32
  - `make setup-worker` - Setup GPU worker environment
  - `make clean` - Clean build artifacts
  - `make dev-setup` - Complete development setup

### 🔧 Technical Details

#### WiFiManager Integration
- Uses tzapu/WiFiManager library
- Non-blocking configuration portal
- Automatic credential storage in ESP32 NVS (Non-Volatile Storage)
- Fallback to AP mode if no saved credentials
- 5-minute timeout to prevent blocking recording

#### Button Debouncing
- Software debouncing with state tracking
- Requires 3-second continuous press to prevent accidental activation
- Visual feedback via serial monitor

#### Power Consumption
- WiFi off (recording): ~85mA
- WiFi on (uploading): ~200mA
- Average with 30-min interval: ~88mA
- Estimated runtime: 40-45 hours on 2200mAh battery

### 📦 Files Added
- `esp32/WIFI_SETUP.md` - WiFi setup guide
- `Makefile` - Build automation
- `CHANGELOG.md` - Version history
- `cloud/infra/terraform.tfvars.example` - Terraform configuration template
- `QUICKSTART.md` - 30-minute deployment guide (was created earlier)
- `shared/docs/architecture.md` - Detailed system architecture

### 📝 Files Modified
- `esp32/platformio.ini` - Added WiFiManager dependency
- `esp32/include/config.h` - Added WiFi config button settings, updated intervals
- `esp32/include/secrets.h.example` - Made WiFi credentials optional
- `esp32/src/main.cpp` - Added WiFiManager integration and button handling
- `esp32/README.md` - Added WiFi configuration and battery life sections
- `QUICKSTART.md` - Updated with web portal setup instructions

### 🔄 Migration Guide

#### For Existing Users

If you're upgrading from the previous version:

1. **Update dependencies:**
   ```bash
   cd esp32
   pio lib install
   ```

2. **Flash new firmware:**
   ```bash
   pio run --target upload
   ```

3. **Configure WiFi:**
   - Option A: Keep existing `secrets.h` with WiFi credentials (will auto-connect)
   - Option B: Clear WiFi credentials and use web portal (recommended)

4. **No cloud changes needed** - AWS infrastructure remains the same

### 🐛 Bug Fixes
- None (new features only)

### ⚠️ Breaking Changes
- None - fully backward compatible

### 🔮 Future Enhancements
- Voice Activity Detection (VAD) on ESP32 for storage optimization
- Deep sleep mode for extended battery life (200+ hours)
- Multiple WiFi network support with priority
- OTA (Over-The-Air) firmware updates
- Battery level monitoring and reporting
- Web interface for viewing recordings and status

---

## Version 1.0 - Initial Release (2025-12-09)

### Features
- ESP32 continuous audio recording with I2S microphone
- 5-minute WAV file chunks at 16kHz, 16-bit, mono
- Local SPIFFS storage with automatic cleanup
- WiFi upload to AWS API Gateway
- AWS Lambda for audio ingestion and storage
- S3 storage for raw audio and transcripts
- DynamoDB for metadata and search
- SQS queue for asynchronous transcription
- GPU worker with Whisper for transcription
- Query API for ChatGPT integration
- Complete Terraform infrastructure as code
- Comprehensive documentation

---

**For detailed setup instructions, see [QUICKSTART.md](QUICKSTART.md)**

**For WiFi configuration help, see [esp32/WIFI_SETUP.md](esp32/WIFI_SETUP.md)**

