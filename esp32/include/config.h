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

// WiFi check interval when disconnected
#define WIFI_CHECK_INTERVAL_MS   30000  // 30 seconds

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

