/*
 * =====================================================
 * LED CONTROL - FINAL ROBUST FIRMWARE
 * =====================================================
 * 
 * PINS CONFIGURATION (8 Onboard + 6 External):
 * -----------------------------------------
 * R1-R8 (Onboard)  ---> GPIO 32, 33, 25, 26, 27, 14, 12, 23
 * R9-R14 (External) ---> GPIO 22, 21, 19, 18, 5, 17
 */

#if defined(ESP32)
  #include <WiFi.h>
#elif defined(ESP8266)
  #include <ESP8266WiFi.h>
#endif

#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

/* ========== WIFI SETTINGS ========== */
#define WIFI_SSID "YOUR_WIFI_SSID"          // <-- CHANGE THIS
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"  // <-- CHANGE THIS
/* =================================== */

#define API_KEY "AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU"
#define DATABASE_URL "https://led-on-off-8ef7b-default-rtdb.asia-southeast1.firebasedatabase.app" 
#define HOME_ID "yourname" // Get this from the Lumina App profile section (e.g., 'sanap', 'rahul')

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool signupOK = false;

// ===== HARDWARE CONFIGURATION =====
#if defined(ESP8266)
  #define STATUS_LED LED_BUILTIN
#else
  #define STATUS_LED 2 // Built-in LED for ESP32
#endif

const int NUM_RELAYS = 14;
const int RELAY_PINS[NUM_RELAYS] = {32, 33, 25, 26, 27, 14, 12, 23, 22, 21, 19, 18, 5, 17};

#include <time.h>

// ===== NTP SETTINGS =====
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 19800; // IST (India Standard Time) is UTC +5:30 -> 5.5 * 3600 = 19800
const int   daylightOffset_sec = 0;

// Map to track states to avoid redundant digitalWrite
bool relayStates[NUM_RELAYS] = {false};
String firebaseIds[NUM_RELAYS] = {""}; // Store Firebase IDs for each relay
int start_h[NUM_RELAYS], start_m[NUM_RELAYS], end_h[NUM_RELAYS], end_m[NUM_RELAYS];
bool lastSwitchStates[NUM_RELAYS] = {false};

// ===== PHYSICAL SWITCH CONFIGURATION =====
// Map your wall switches to these GPIOs. 
// Match them with the RELAY_PINS order.
// Use -1 for no switch. (Switch connected to GND)
int SWITCH_PINS[NUM_RELAYS] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1}; 

unsigned long sendDataPrevMillis = 0;
unsigned long lastScheduleCheckMillis = 0;

void printLocalTime() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    Serial.println("Failed to obtain time");
    return;
  }
  Serial.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");
}

void intelligentConnect() {
  Serial.println("\n[WIFI] Initializing Proximity-First Smart Scan...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);

  int n = WiFi.scanNetworks();
  Serial.printf("[WIFI] Scan complete. %d networks found.\n", n);

  bool homeFound = false;
  int bestOpenIdx = -1;
  int maxRSSI = -100;

  for (int i = 0; i < n; ++i) {
    String currentSSID = WiFi.SSID(i);
    int currentRSSI = WiFi.RSSI(i);
    
    #if defined(ESP32)
      bool isOpen = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN);
    #else
      bool isOpen = (WiFi.encryptionType(i) == ENC_TYPE_NONE);
    #endif

    Serial.printf("  - %s (%d dBm) [%s]\n", currentSSID.c_str(), currentRSSI, isOpen ? "OPEN" : "SECURED");

    if (currentSSID == WIFI_SSID) {
      homeFound = true;
      Serial.println("    >>> [PRIORITY] Home WiFi Detected!");
    }

    if (isOpen && currentRSSI > maxRSSI) {
      maxRSSI = currentRSSI;
      bestOpenIdx = i;
    }
  }

  if (homeFound) {
    Serial.printf("[WIFI] Connecting to Home WiFi: %s\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  } else if (bestOpenIdx != -1) {
    String bestOpenSSID = WiFi.SSID(bestOpenIdx);
    Serial.printf("[WIFI] Home WiFi not found. Connecting to Strongest Open Network: %s\n", bestOpenSSID.c_str());
    WiFi.begin(bestOpenSSID.c_str());
  } else {
    Serial.println("[WIFI] No suitable networks found. Retrying in 10s...");
    return;
  }

  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 15000) {
    delay(500);
    Serial.print(".");
    digitalWrite(STATUS_LED, !digitalRead(STATUS_LED)); 
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    digitalWrite(STATUS_LED, LOW); 
  } else {
    Serial.println("\n[WIFI] Connection failed.");
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n================================================");
  Serial.println("   UNIFIED SMART HUB - 17 CHANNEL RELAY SYSTEM");
  Serial.println("            (ESP32-WROOM-32 POWERED)           ");
  Serial.println("================================================\n");
  
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, HIGH);

  Serial.println("[SYSTEM] Initializing 17 Universal Relay Ports...");
  for (int i = 0; i < NUM_RELAYS; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], LOW); 
    start_h[i] = start_m[i] = end_h[i] = end_m[i] = -1; // Initialize schedules to inactive
    
    // Initialize Optional Switches
    if (SWITCH_PINS[i] != -1) {
      pinMode(SWITCH_PINS[i], INPUT_PULLUP);
      lastSwitchStates[i] = digitalRead(SWITCH_PINS[i]);
    }
  }

  for (int i = 0; i < NUM_RELAYS; i++) {
    digitalWrite(RELAY_PINS[i], HIGH);
    delay(30);
    digitalWrite(RELAY_PINS[i], LOW);
  }

  intelligentConnect();

  // Initialize NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  printLocalTime();

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("[CLOUD] Firebase Handshake Successful");
    signupOK = true;
  } else {
    Serial.printf("[ERROR] Firebase Init Failed: %s\n", config.signer.signupError.message.c_str());
  }
  
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // --- WIFI AUTO-RECOVERY ---
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastRetry = 0;
    if (millis() - lastRetry > 30000) {
      lastRetry = millis();
      Serial.println("[WIFI] Connection lost. Re-synchronizing...");
      intelligentConnect();
    }
  }

  // --- MANUAL SWITCH DETECTION & SMART SYNC ---
  // Detects physical toggles and pushes them to the Cloud.
  for (int i = 0; i < NUM_RELAYS; i++) {
    if (SWITCH_PINS[i] != -1) {
      bool currentSwitchState = digitalRead(SWITCH_PINS[i]);
      if (currentSwitchState != lastSwitchStates[i]) {
        delay(30); // Debounce
        if (digitalRead(SWITCH_PINS[i]) == currentSwitchState) {
          lastSwitchStates[i] = currentSwitchState;
          
          // Toggle local state
          relayStates[i] = !relayStates[i];
          digitalWrite(RELAY_PINS[i], relayStates[i] ? HIGH : LOW);
          
          Serial.printf("[LOCAL] Manual Switch %d toggled. Pin %d -> %s\n", 
                        i, RELAY_PINS[i], relayStates[i] ? "ON" : "OFF");
          
          // Update Cloud status so the App reflects the change
          if (signupOK && firebaseIds[i] != "") {
            String path = "users/" + String(HOME_ID) + "/leds/" + firebaseIds[i] + "/isOn";
            Firebase.RTDB.setBool(&fbdo, path.c_str(), relayStates[i]);
          }
        }
      }
    }
  }

  if (Firebase.ready() && signupOK && WiFi.status() == WL_CONNECTED) {
    // --- CLOUD-TO-LOCAL SYNC ---
    static unsigned long lastCloudPoll = 0;
    if (millis() - lastCloudPoll > 350) {
      lastCloudPoll = millis();
      
      String basePath = "users/" + String(HOME_ID) + "/leds";
      if (Firebase.RTDB.getJSON(&fbdo, basePath.c_str())) {
        FirebaseJson &json = fbdo.jsonObject();
        size_t count = json.iteratorBegin();
        
        for (size_t i = 0; i < count; i++) {
          FirebaseJson::IteratorValue value = json.valueAt(i);
          if (value.type == FirebaseJson::JSON_OBJECT) {
            String firebaseKey = value.key; 
            FirebaseJson child;
            child.setJsonData(value.value);
            
            FirebaseJsonData jsonData;
            int assignedPin = -1;
            bool cloudIsOn = false;

            if (child.get(jsonData, "pin")) assignedPin = jsonData.intValue;
            if (child.get(jsonData, "isOn")) cloudIsOn = jsonData.boolValue;

            if (assignedPin != -1) {
              int relayIdx = -1;
              for (int r = 0; r < NUM_RELAYS; r++) {
                if (RELAY_PINS[r] == assignedPin) {
                  relayIdx = r;
                  break;
                }
              }

              if (relayIdx != -1) {
                firebaseIds[relayIdx] = firebaseKey; // Map key
                
                // Get Schedule Info
                if (child.get(jsonData, "start_h")) start_h[relayIdx] = jsonData.intValue; else start_h[relayIdx] = -1;
                if (child.get(jsonData, "start_m")) start_m[relayIdx] = jsonData.intValue; else start_m[relayIdx] = -1;
                if (child.get(jsonData, "end_h")) end_h[relayIdx] = jsonData.intValue; else end_h[relayIdx] = -1;
                if (child.get(jsonData, "end_m")) end_m[relayIdx] = jsonData.intValue; else end_m[relayIdx] = -1;

                // Update local relay ONLY if it differs from app status
                if (relayStates[relayIdx] != cloudIsOn) {
                  relayStates[relayIdx] = cloudIsOn;
                  digitalWrite(assignedPin, cloudIsOn ? HIGH : LOW);
                  Serial.printf("[SYNC] Device on Pin %d updated by Cloud to %s\n", 
                                assignedPin, cloudIsOn ? "ON" : "OFF");
                }
              }
            }
          }
        }
        json.iteratorEnd();
      }
    }

    // --- HARDWARE SCHEDULER ---
    if (millis() - lastScheduleCheckMillis > 30000) { // Check every 30 seconds
      lastScheduleCheckMillis = millis();
      struct tm timeinfo;
      if(getLocalTime(&timeinfo)) {
        int curH = timeinfo.tm_hour;
        int curM = timeinfo.tm_min;
        
        for(int i = 0; i < NUM_RELAYS; i++) {
          if(firebaseIds[i] == "") continue;
          
          // Check ON Schedule
          if(start_h[i] == curH && start_m[i] == curM && !relayStates[i]) {
            relayStates[i] = true;
            digitalWrite(RELAY_PINS[i], HIGH);
            Serial.printf("[SCHEDULE] Auto ON for relay %d\n", RELAY_PINS[i]);
            String path = "users/" + String(HOME_ID) + "/leds/" + firebaseIds[i] + "/isOn";
            Firebase.RTDB.setBool(&fbdo, path.c_str(), true);
          }
          
          // Check OFF Schedule
          if(end_h[i] == curH && end_m[i] == curM && relayStates[i]) {
            relayStates[i] = false;
            digitalWrite(RELAY_PINS[i], LOW);
            Serial.printf("[SCHEDULE] Auto OFF for relay %d\n", RELAY_PINS[i]);
            String path = "users/" + String(HOME_ID) + "/leds/" + firebaseIds[i] + "/isOn";
            Firebase.RTDB.setBool(&fbdo, path.c_str(), false);
          }
        }
      }
    }
    
    // --- UPLOAD HEARTBEAT ---
    if (millis() - sendDataPrevMillis > 5000) {
      sendDataPrevMillis = millis();
      float h = 45.0 + (random(0, 100) / 10.0);
      String humPath = "users/" + String(HOME_ID) + "/humidity";
      String seenPath = "users/" + String(HOME_ID) + "/last_seen";
      Firebase.RTDB.setFloat(&fbdo, humPath.c_str(), h);
      Firebase.RTDB.setInt(&fbdo, seenPath.c_str(), (int)(millis() / 1000)); 
    }
  }
  
  delay(50);
}
