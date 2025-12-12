/**
 * REM ESP32 Configuration
 * Main configuration constants for the recording system
 */

#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// Audio Recording Configuration
// ============================================================================

// I2S Microphone Configuration (adjust for your specific I2S mic)
#define I2S_WS              15    // Word Select (LRCLK)
#define I2S_SD              32    // Serial Data (DOUT)
#define I2S_SCK             14    // Serial Clock (BCLK)
#define I2S_PORT            I2S_NUM_0

// Audio format
#define SAMPLE_RATE         16000  // 16 kHz
#define BITS_PER_SAMPLE     16     // 16-bit
#define CHANNELS            1      // Mono
#define I2S_READ_LEN        (1024 * 4)

// Recording chunk duration (5 minutes)
#define CHUNK_DURATION_MS   (5 * 60 * 1000)
#define CHUNK_DURATION_SEC  (CHUNK_DURATION_MS / 1000)

// WAV file header size
#define WAV_HEADER_SIZE     44

// ============================================================================
// Voice Activity Detection (VAD) Configuration
// ============================================================================

// Enable/disable VAD (set to 0 to record continuously like before)
#define VAD_ENABLED         1

// RMS threshold for speech detection (0-32767 for 16-bit audio)
// Lower = more sensitive, Higher = less sensitive
// Typical values: 200-500 for quiet room, 500-1000 for noisy environment
#define VAD_THRESHOLD       300

// How long speech must be detected to start recording (ms)
// Prevents triggering on brief noises
#define VAD_SPEECH_START_MS 100

// How long silence must last to stop recording (ms)
// Keeps recording through brief pauses in speech
#define VAD_SILENCE_TIMEOUT_MS  3000

// Pre-buffer duration (ms) - captures audio before speech is detected
// So we don't miss the beginning of words
#define VAD_PREBUFFER_MS    500

// Minimum chunk duration to save (ms)
// Don't save very short recordings (likely just noise)
#define VAD_MIN_CHUNK_MS    2000

// Maximum silence in a chunk before forcing save (ms)
// Even if speech continues, save periodically
#define VAD_MAX_CHUNK_MS    CHUNK_DURATION_MS

// Debug VAD decisions
#define DEBUG_VAD           0

#if DEBUG_VAD
  #define VAD_DEBUG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define VAD_DEBUG_PRINTF(...)
#endif

// ============================================================================
// Storage Configuration
// ============================================================================

// Maximum storage usage (bytes) - leave some space for filesystem overhead
#define MAX_STORAGE_BYTES   (3 * 1024 * 1024)  // 3 MB for SPIFFS

// Minimum free space to maintain
#define MIN_FREE_SPACE      (512 * 1024)  // 512 KB

// Upload tracking file
#define UPLOAD_INDEX_FILE   "/upload_index.json"

// Recording directory
#define RECORDING_DIR       "/recordings"

// ============================================================================
// WiFi and Upload Configuration
// ============================================================================

// WiFi connection timeout
#define WIFI_CONNECT_TIMEOUT_MS  10000  // 10 seconds

// WiFi check interval when disconnected (how often to try uploading)
#define WIFI_CHECK_INTERVAL_MS   (30 * 60 * 1000)  // 30 minutes

// Upload retry configuration
#define UPLOAD_MAX_RETRIES       5
#define UPLOAD_RETRY_BASE_MS     1000   // Start with 1 second
#define UPLOAD_RETRY_MAX_MS      60000  // Max 60 seconds

// HTTP timeout
#define HTTP_TIMEOUT_MS          30000  // 30 seconds

// ============================================================================
// Device Configuration
// ============================================================================

// Device ID will be generated from MAC address
// Format: "esp32-XXXXXXXXXXXX"

// ============================================================================
// WiFi Configuration Button
// ============================================================================

// Button to enter WiFi configuration mode
#define CONFIG_BUTTON_PIN       0      // GPIO 0 (BOOT button on most ESP32 boards)
#define CONFIG_BUTTON_HOLD_MS   3000   // Hold for 3 seconds to enter config mode

// WiFi Manager AP settings
#define CONFIG_AP_NAME          "REM-Setup"  // Access Point name
#define CONFIG_AP_PASSWORD      "rem12345"   // Access Point password (min 8 chars)
#define CONFIG_PORTAL_TIMEOUT   300          // Portal timeout in seconds (5 minutes)

// ============================================================================
// Debug Configuration
// ============================================================================

#define DEBUG_SERIAL        1  // Enable serial debug output
#define DEBUG_AUDIO         0  // Enable audio debug (verbose)
#define DEBUG_UPLOAD        1  // Enable upload debug

// ============================================================================
// Macros
// ============================================================================

#if DEBUG_SERIAL
  #define DEBUG_PRINT(x)    Serial.print(x)
  #define DEBUG_PRINTLN(x)  Serial.println(x)
  #define DEBUG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
  #define DEBUG_PRINTF(...)
#endif

#if DEBUG_AUDIO
  #define AUDIO_DEBUG_PRINT(x)    Serial.print(x)
  #define AUDIO_DEBUG_PRINTLN(x)  Serial.println(x)
#else
  #define AUDIO_DEBUG_PRINT(x)
  #define AUDIO_DEBUG_PRINTLN(x)
#endif

#if DEBUG_UPLOAD
  #define UPLOAD_DEBUG_PRINT(x)    Serial.print(x)
  #define UPLOAD_DEBUG_PRINTLN(x)  Serial.println(x)
  #define UPLOAD_DEBUG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define UPLOAD_DEBUG_PRINT(x)
  #define UPLOAD_DEBUG_PRINTLN(x)
  #define UPLOAD_DEBUG_PRINTF(...)
#endif

#endif // CONFIG_H

