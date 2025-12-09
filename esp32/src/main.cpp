/**
 * REM - ESP32 Continuous Audio Recording System
 * Continuously records audio, stores locally, uploads to AWS when WiFi available
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <SPIFFS.h>
#include <ArduinoJson.h>
#include <driver/i2s.h>
#include <time.h>
#include <WiFiManager.h>
#include "config.h"
#include "secrets.h"

// Global State
struct RecordingState {
  File currentFile;
  String currentFilename;
  unsigned long chunkStartTime;
  unsigned long chunkStartMillis;
  size_t bytesWritten;
  bool isRecording;
} recording;

struct UploadState {
  unsigned long lastWiFiCheck;
  unsigned long lastUploadAttempt;
  int consecutiveFailures;
  bool isConnected;
} uploadState;

String deviceId;
StaticJsonDocument<4096> uploadIndex;
WiFiManager wifiManager;

// Button state for config mode
unsigned long configButtonPressTime = 0;
bool configButtonPressed = false;

// Forward declarations
void setupI2S();
void setupWiFi();
void checkConfigButton();
void enterConfigMode();
void setupTime();
void setupStorage();
String getDeviceId();
void writeWavHeader(File &file, uint32_t sr, uint16_t bps, uint16_t ch);
void updateWavHeader(File &file);
void startNewRecordingChunk();
void audioRecordingTask();
void uploadTask();
void loadUploadIndex();
void saveUploadIndex();
void markFileAsUploaded(const String &fn);
bool isFileUploaded(const String &fn);
bool uploadFile(const String &fp);
void cleanupStorage();
String getCurrentTimestamp();
String getISOTimestamp(unsigned long ut);
unsigned long getUnixTime();

void setup() {
  Serial.begin(115200);
  delay(1000);
  DEBUG_PRINTLN("\n=== REM ESP32 Firmware v1.0 ===\n");

  // Setup config button
  pinMode(CONFIG_BUTTON_PIN, INPUT_PULLUP);

  deviceId = getDeviceId();
  DEBUG_PRINTF("Device ID: %s\n", deviceId.c_str());

  setupStorage();
  setupWiFi();
  setupTime();
  setupI2S();

  recording.isRecording = false;
  uploadState.lastWiFiCheck = 0;
  uploadState.consecutiveFailures = 0;
  uploadState.isConnected = false;

  loadUploadIndex();
  startNewRecordingChunk();
  DEBUG_PRINTLN("Setup complete\n");
}

void loop() {
  checkConfigButton();
  audioRecordingTask();
  uploadTask();
  delay(1);
}

void setupI2S() {
  DEBUG_PRINTLN("Init I2S...");
  i2s_config_t cfg = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 8,
    .dma_buf_len = 1024,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0
  };
  i2s_pin_config_t pins = {
    .bck_io_num = I2S_SCK,
    .ws_io_num = I2S_WS,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num = I2S_SD
  };
  i2s_driver_install(I2S_PORT, &cfg, 0, NULL);
  i2s_set_pin(I2S_PORT, &pins);
  DEBUG_PRINTLN("I2S OK");
}

void setupWiFi() {
  WiFi.mode(WIFI_STA);

  // Configure WiFiManager
  wifiManager.setConfigPortalTimeout(CONFIG_PORTAL_TIMEOUT);
  wifiManager.setAPCallback([](WiFiManager *mgr) {
    DEBUG_PRINTLN("\n=== WiFi Config Mode ===");
    DEBUG_PRINTF("Connect to: %s\n", CONFIG_AP_NAME);
    DEBUG_PRINTF("Password: %s\n", CONFIG_AP_PASSWORD);
    DEBUG_PRINTLN("Open browser to: 192.168.4.1");
    DEBUG_PRINTLN("========================\n");
  });

  // Try to auto-connect with saved credentials
  DEBUG_PRINTLN("Connecting to WiFi...");
  if (!wifiManager.autoConnect(CONFIG_AP_NAME, CONFIG_AP_PASSWORD)) {
    DEBUG_PRINTLN("Failed to connect, will retry later");
    // Don't block - continue with recording even without WiFi
  } else {
    DEBUG_PRINTLN("WiFi connected!");
    DEBUG_PRINTF("IP: %s\n", WiFi.localIP().toString().c_str());
  }
}

void checkConfigButton() {
  // Check if config button is pressed (active LOW)
  if (digitalRead(CONFIG_BUTTON_PIN) == LOW) {
    if (!configButtonPressed) {
      configButtonPressed = true;
      configButtonPressTime = millis();
      DEBUG_PRINTLN("Config button pressed...");
    } else {
      // Check if held long enough
      if (millis() - configButtonPressTime >= CONFIG_BUTTON_HOLD_MS) {
        DEBUG_PRINTLN("Entering WiFi config mode!");
        enterConfigMode();
        configButtonPressed = false;
      }
    }
  } else {
    if (configButtonPressed) {
      DEBUG_PRINTLN("Config button released");
      configButtonPressed = false;
    }
  }
}

void enterConfigMode() {
  DEBUG_PRINTLN("\n=================================");
  DEBUG_PRINTLN("WiFi Configuration Mode");
  DEBUG_PRINTLN("=================================");
  DEBUG_PRINTF("1. Connect to WiFi: %s\n", CONFIG_AP_NAME);
  DEBUG_PRINTF("2. Password: %s\n", CONFIG_AP_PASSWORD);
  DEBUG_PRINTLN("3. Open browser to: 192.168.4.1");
  DEBUG_PRINTLN("4. Enter your WiFi credentials");
  DEBUG_PRINTLN("=================================\n");

  // Reset WiFi settings and start config portal
  wifiManager.resetSettings();

  // Start config portal (blocking)
  if (wifiManager.startConfigPortal(CONFIG_AP_NAME, CONFIG_AP_PASSWORD)) {
    DEBUG_PRINTLN("\nWiFi configured successfully!");
    DEBUG_PRINTF("Connected to: %s\n", WiFi.SSID().c_str());
    DEBUG_PRINTF("IP Address: %s\n", WiFi.localIP().toString().c_str());

    // Restart to apply new settings
    DEBUG_PRINTLN("Restarting in 3 seconds...");
    delay(3000);
    ESP.restart();
  } else {
    DEBUG_PRINTLN("\nConfig portal timeout - continuing with recording");
  }
}

void setupTime() {
  configTime(0, 0, "pool.ntp.org");
}

void setupStorage() {
  if (!SPIFFS.begin(true)) {
    DEBUG_PRINTLN("SPIFFS FAIL");
    return;
  }
  DEBUG_PRINTF("SPIFFS: %d/%d bytes\n", SPIFFS.usedBytes(), SPIFFS.totalBytes());
  if (!SPIFFS.exists(RECORDING_DIR)) SPIFFS.mkdir(RECORDING_DIR);
}

String getDeviceId() {
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char s[18];
  sprintf(s, "%02X%02X%02X%02X%02X%02X", mac[0],mac[1],mac[2],mac[3],mac[4],mac[5]);
  return "esp32-" + String(s);
}

void writeWavHeader(File &f, uint32_t sr, uint16_t bps, uint16_t ch) {
  uint32_t br = sr * ch * bps / 8;
  uint16_t ba = ch * bps / 8;
  uint32_t ds = 0xFFFFFFFF - 44;
  f.write("RIFF", 4);
  uint32_t cs = ds + 36;
  f.write((uint8_t*)&cs, 4);
  f.write("WAVE", 4);
  f.write("fmt ", 4);
  uint32_t fs = 16;
  f.write((uint8_t*)&fs, 4);
  uint16_t af = 1;
  f.write((uint8_t*)&af, 2);
  f.write((uint8_t*)&ch, 2);
  f.write((uint8_t*)&sr, 4);
  f.write((uint8_t*)&br, 4);
  f.write((uint8_t*)&ba, 2);
  f.write((uint8_t*)&bps, 2);
  f.write("data", 4);
  f.write((uint8_t*)&ds, 4);
}

void updateWavHeader(File &f) {
  uint32_t sz = f.size();
  uint32_t ds = sz - WAV_HEADER_SIZE;
  uint32_t cs = sz - 8;
  f.seek(4);
  f.write((uint8_t*)&cs, 4);
  f.seek(40);
  f.write((uint8_t*)&ds, 4);
}

String getCurrentTimestamp() {
  time_t now;
  struct tm ti;
  time(&now);
  localtime_r(&now, &ti);
  char ts[20];
  strftime(ts, sizeof(ts), "%Y%m%d_%H%M%S", &ti);
  return String(ts);
}

String getISOTimestamp(unsigned long ut) {
  time_t t = (time_t)ut;
  struct tm ti;
  gmtime_r(&t, &ti);
  char iso[25];
  strftime(iso, sizeof(iso), "%Y-%m-%dT%H:%M:%SZ", &ti);
  return String(iso);
}

unsigned long getUnixTime() {
  time_t now;
  time(&now);
  return (unsigned long)now;
}

void startNewRecordingChunk() {
  if (recording.currentFile) {
    updateWavHeader(recording.currentFile);
    recording.currentFile.close();
    DEBUG_PRINTF("Closed: %s\n", recording.currentFilename.c_str());
  }
  
  String ts = getCurrentTimestamp();
  recording.currentFilename = String(RECORDING_DIR) + "/" + ts + ".wav";
  DEBUG_PRINTF("New chunk: %s\n", recording.currentFilename.c_str());
  
  recording.currentFile = SPIFFS.open(recording.currentFilename, FILE_WRITE);
  if (!recording.currentFile) {
    DEBUG_PRINTLN("File create FAIL");
    recording.isRecording = false;
    return;
  }
  
  writeWavHeader(recording.currentFile, SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS);
  recording.chunkStartTime = getUnixTime();
  recording.chunkStartMillis = millis();
  recording.bytesWritten = WAV_HEADER_SIZE;
  recording.isRecording = true;
}

void audioRecordingTask() {
  if (!recording.isRecording) return;
  
  if (millis() - recording.chunkStartMillis >= CHUNK_DURATION_MS) {
    startNewRecordingChunk();
    cleanupStorage();
    return;
  }
  
  uint8_t buf[I2S_READ_LEN];
  size_t br = 0;
  if (i2s_read(I2S_PORT, buf, I2S_READ_LEN, &br, portMAX_DELAY) == ESP_OK && br > 0) {
    recording.bytesWritten += recording.currentFile.write(buf, br);
  }
}

void loadUploadIndex() {
  File f = SPIFFS.open(UPLOAD_INDEX_FILE, FILE_READ);
  if (f) {
    deserializeJson(uploadIndex, f);
    f.close();
  }
}

void saveUploadIndex() {
  File f = SPIFFS.open(UPLOAD_INDEX_FILE, FILE_WRITE);
  if (f) {
    serializeJson(uploadIndex, f);
    f.close();
  }
}

void markFileAsUploaded(const String &fn) {
  uploadIndex[fn] = true;
  saveUploadIndex();
}

bool isFileUploaded(const String &fn) {
  return uploadIndex.containsKey(fn) && uploadIndex[fn];
}

void cleanupStorage() {
  size_t used = SPIFFS.usedBytes();
  size_t total = SPIFFS.totalBytes();
  
  if (used < MAX_STORAGE_BYTES) return;
  
  DEBUG_PRINTLN("Cleanup storage...");
  File root = SPIFFS.open(RECORDING_DIR);
  File f = root.openNextFile();
  
  while (f) {
    String fn = String(f.name());
    if (fn.endsWith(".wav") && isFileUploaded(fn)) {
      DEBUG_PRINTF("Delete: %s\n", fn.c_str());
      f.close();
      SPIFFS.remove(fn);
      if (SPIFFS.usedBytes() < MAX_STORAGE_BYTES - MIN_FREE_SPACE) break;
    }
    f = root.openNextFile();
  }
}

bool uploadFile(const String &fp) {
  File f = SPIFFS.open(fp, FILE_READ);
  if (!f) return false;
  
  size_t sz = f.size();
  UPLOAD_DEBUG_PRINTF("Upload: %s (%d bytes)\n", fp.c_str(), sz);
  
  HTTPClient http;
  http.begin(API_GATEWAY_URL);
  http.addHeader("x-api-key", API_KEY);
  http.setTimeout(HTTP_TIMEOUT_MS);
  
  String boundary = "----REM" + String(millis());
  String ct = "multipart/form-data; boundary=" + boundary;
  http.addHeader("Content-Type", ct);
  
  String fn = fp.substring(fp.lastIndexOf('/') + 1);
  fn.replace(".wav", "");
  
  unsigned long st = recording.chunkStartTime;
  unsigned long et = st + CHUNK_DURATION_SEC;
  
  String body = "--" + boundary + "\r\n";
  body += "Content-Disposition: form-data; name=\"deviceId\"\r\n\r\n";
  body += deviceId + "\r\n";
  body += "--" + boundary + "\r\n";
  body += "Content-Disposition: form-data; name=\"startedAt\"\r\n\r\n";
  body += getISOTimestamp(st) + "\r\n";
  body += "--" + boundary + "\r\n";
  body += "Content-Disposition: form-data; name=\"endedAt\"\r\n\r\n";
  body += getISOTimestamp(et) + "\r\n";
  body += "--" + boundary + "\r\n";
  body += "Content-Disposition: form-data; name=\"file\"; filename=\"" + fn + ".wav\"\r\n";
  body += "Content-Type: audio/wav\r\n\r\n";
  
  String footer = "\r\n--" + boundary + "--\r\n";
  
  size_t totalLen = body.length() + sz + footer.length();
  
  http.addHeader("Content-Length", String(totalLen));
  
  WiFiClient *stream = http.getStreamPtr();
  stream->print(body);
  
  uint8_t buf[512];
  while (f.available()) {
    size_t r = f.read(buf, sizeof(buf));
    stream->write(buf, r);
  }
  f.close();
  
  stream->print(footer);
  
  int code = http.GET();
  http.end();
  
  if (code >= 200 && code < 300) {
    UPLOAD_DEBUG_PRINTF("Upload OK: %d\n", code);
    markFileAsUploaded(fp);
    SPIFFS.remove(fp);
    return true;
  }
  
  UPLOAD_DEBUG_PRINTF("Upload FAIL: %d\n", code);
  return false;
}

void uploadTask() {
  unsigned long now = millis();
  
  if (now - uploadState.lastWiFiCheck < WIFI_CHECK_INTERVAL_MS) return;
  uploadState.lastWiFiCheck = now;
  
  if (WiFi.status() != WL_CONNECTED) {
    if (uploadState.isConnected) {
      DEBUG_PRINTLN("WiFi lost");
      uploadState.isConnected = false;
    }
    return;
  }
  
  if (!uploadState.isConnected) {
    DEBUG_PRINTLN("WiFi connected");
    uploadState.isConnected = true;
  }
  
  File root = SPIFFS.open(RECORDING_DIR);
  File f = root.openNextFile();
  
  while (f) {
    String fn = String(f.name());
    f.close();
    
    if (fn.endsWith(".wav") && !isFileUploaded(fn) && fn != recording.currentFilename) {
      if (uploadFile(fn)) {
        uploadState.consecutiveFailures = 0;
      } else {
        uploadState.consecutiveFailures++;
        if (uploadState.consecutiveFailures >= UPLOAD_MAX_RETRIES) {
          DEBUG_PRINTLN("Max retries reached");
          delay(UPLOAD_RETRY_MAX_MS);
          uploadState.consecutiveFailures = 0;
        }
        break;
      }
    }
    
    f = root.openNextFile();
  }
}
