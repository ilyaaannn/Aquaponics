#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <NewPing.h>
#include <Adafruit_AHTX0.h>
#include "ScioSense_ENS160.h"
#include <ArduinoJson.h> 
#include <LiquidCrystal_I2C.h> // Library LCD I2C

// ================= KONFIGURASI LCD ==================
// Sesuaikan alamat I2C (biasanya 0x27 atau 0x3F) dan ukuran (20x4 atau 16x2)
LiquidCrystal_I2C lcd(0x27, 20, 4); 

// ================= KONFIGURASI LOGIKA RELAY ==================
#define RELAY_NYALA   LOW
#define RELAY_MATI    HIGH 

// ================= PIN DEFINITIONS ==================
#define DO_PIN        A0   
#define TDS_PIN       A1   
#define TURB_PIN      A2   
#define PH_PIN        A3   
#define TDS_PWR_PIN   22   
#define TRIG_PIN      7    
#define ECHO_PIN      6    
#define ONE_WIRE_BUS  8    
#define MHZ19_PWM_PIN 11  
#define SDA_PIN       20   
#define SCL_PIN       21   
#define PIN_POMPA     12    
#define PIN_OKSIGEN   13   

// ================= OBJECTS =====================
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature ds(&oneWire);
NewPing sonar(TRIG_PIN, ECHO_PIN, 400); 
Adafruit_AHTX0 aht;
ScioSense_ENS160 ens160(ENS160_I2CADDR_1); 

// ================= KALIBRASI =================
// Catatan: Lakukan kalibrasi fisik pada probe pH Anda menggunakan cairan buffer 4.0 & 6.86
float PH_SLOPE  = -5.70;
float PH_OFFSET =  21.34;
float TDS_K_VALUE = 0.82;

// ================= VARIABEL SISTEM =================
unsigned long lastSendTime = 0;
const long sendInterval = 2000; 
bool statusPompa = false;
bool statusOksigen = false;

// ================= FUNGSI BACA SENSOR ================
int readCO2PWM() {
  unsigned long duration = pulseIn(MHZ19_PWM_PIN, HIGH, 2000000);
  if (duration == 0) return -1; 
  long durationMs = duration / 1000;
  long ppm = 5000 * (durationMs - 2) / (1004 - 4);
  return (int)constrain(ppm, 0, 5000);
}

// Fungsi untuk membaca voltase aktual dari pin Analog (untuk sensor lain)
float readVoltageAvg(uint8_t pin, int n = 16) {
  long acc = 0;
  for (int i = 0; i < n; i++) {
    acc += analogRead(pin);
    delayMicroseconds(500);
  }
  return (acc / (float)n) * (5.0 / 1023.0); 
}

// Fungsi Filter khusus untuk stabilitas data pH (Bubble sort & rata-rata tengah)
float getFilteredAnalogValue(uint8_t pin) {
  int samples[10];
  for(int i = 0; i < 10; i++) {
    samples[i] = analogRead(pin);
    delay(20);
  }
  
  // Sort data (Bubble sort sederhana)
  for(int i = 0; i < 9; i++) {
    for(int j = i + 1; j < 10; j++) {
      if(samples[i] > samples[j]) {
        int temp = samples[i];
        samples[i] = samples[j];
        samples[j] = temp;
      }
    }
  }
  
  // Rata-rata 6 nilai tengah
  float sum = 0;
  for(int i = 2; i < 8; i++) {
    sum += samples[i];
  }
  return sum / 6.0;
}

// ================== SETUP =======================
void setup() {
  Serial.begin(115200); 
  Wire.begin();

  // Inisialisasi LCD
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Memulai Sistem...");

  pinMode(MHZ19_PWM_PIN, INPUT);
  
  if (!aht.begin()) Serial.println(F("LOG: AHT21 gagal"));
  if (!ens160.begin()) Serial.println(F("LOG: ENS160 gagal"));
  else ens160.setMode(ENS160_OPMODE_STD);
  
  ds.begin();
  pinMode(TDS_PWR_PIN, OUTPUT); digitalWrite(TDS_PWR_PIN, HIGH); 
  pinMode(PIN_POMPA, OUTPUT); digitalWrite(PIN_POMPA, RELAY_MATI);   
  pinMode(PIN_OKSIGEN, OUTPUT); digitalWrite(PIN_OKSIGEN, RELAY_MATI); 

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Sistem Siap!");
  delay(1000);
}

// ================== LOOP =======================
void loop() {
  checkSerialCommands(); // Terus memantau perintah dari USB (Raspberry Pi)

  unsigned long currentTime = millis();
  if (currentTime - lastSendTime >= sendInterval) {
    lastSendTime = currentTime;
    readAndSendSensors();
  }
}

// ================== COMMAND LISTENER =======================
void checkSerialCommands() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim(); 
    
    if (command.startsWith("POMPA:")) {
      int state = command.substring(6).toInt(); 
      statusPompa = (state == 1); 
      digitalWrite(PIN_POMPA, statusPompa ? RELAY_NYALA : RELAY_MATI);
    }
    else if (command.startsWith("OKSIGEN:")) {
      int state = command.substring(8).toInt();
      statusOksigen = (state == 1);
      digitalWrite(PIN_OKSIGEN, statusOksigen ? RELAY_NYALA : RELAY_MATI);
    }
  }
}

// ================== FUNGSI UTAMA =======================
void readAndSendSensors() {
  // --- A. BACA SENSOR AIR ---
  ds.requestTemperatures();
  float tAir = ds.getTempCByIndex(0);
  
  // Jika sensor suhu rusak/kabel putus, jadikan 25.0 C agar rumus kompensasi tidak error
  if (tAir == -127.00) tAir = 25.0; 

  // 1. BACA SENSOR pH (Dengan filter bubble sort)
  digitalWrite(TDS_PWR_PIN, LOW); delay(800); 
  
  float analogValPH = getFilteredAnalogValue(PH_PIN);  // Ambil data analog terfilter
  float Vph = analogValPH * (5.0 / 1023.0);            // Konversi ke tegangan
  float pH = (PH_SLOPE * Vph) + PH_OFFSET;             // Hitung pH akhir
  
  digitalWrite(TDS_PWR_PIN, HIGH); 

  // 2. BACA SENSOR TDS
  float Vtds = readVoltageAvg(TDS_PIN, 30);
  float compensationCoefficient = 1.0 + 0.02 * (tAir - 25.0); 
  float voltageTDS = Vtds / compensationCoefficient;

  // Rumus standar (raw) DFRobot TDS
  float tdsRaw = (133.42 * voltageTDS * voltageTDS * voltageTDS - 255.86 * voltageTDS * voltageTDS + 857.39 * voltageTDS) * 0.5;

  // 1. Terapkan K-Value dasar
  float tdsValue = tdsRaw * TDS_K_VALUE;

  // 2. KOREKSI OFFSET UDARA (Titik Nol)
  tdsValue = tdsValue - 9.0;
  if (tdsValue < 0) {
    tdsValue = 0; 
  }

  // 3. KALIBRASI DUA-TITIK (Penyempurnaan Skala Atas)
  // Menyesuaikan angka tertinggi ke 887, menjaga angka terendah di 13
  tdsValue = (tdsValue * 1.224) - 1.69;
  // 4. PENGUNCI BATAS BAWAH FINAL
  if (tdsValue < 2.0) {
    tdsValue = 0;
  }

  // 3. BACA SENSOR TURBIDITY / KEKERUHAN (Standar DFRobot Gravity - Hasil dalam NTU)
  float Vturb = readVoltageAvg(TURB_PIN, 10);
  float turbidityNTU = 0;
  if (Vturb < 2.5) {
    turbidityNTU = 3000.0; // Air sangat keruh
  } else if (Vturb > 4.2) {
    turbidityNTU = 0.0;    // Air sangat jernih
  } else {
    turbidityNTU = -1120.4 * (Vturb * Vturb) + 5742.3 * Vturb - 4353.8;
    if (turbidityNTU < 0) turbidityNTU = 0;
  }

  // 4. BACA SENSOR DO (Dissolved Oxygen - Hasil dalam mg/L)
  float Vdo = readVoltageAvg(DO_PIN, 10); 
  float Vdo_kalibrasi_udara = 1.6; // <- Ganti angka ini dengan hasil bacaan Vdo di udara terbuka!
  float DO_saturasi_25C = 8.24; 
  float doValue = (Vdo / Vdo_kalibrasi_udara) * DO_saturasi_25C;
  if (doValue < 0) doValue = 0;

  // --- B. BACA SENSOR UDARA ---
  int co2ppm = readCO2PWM(); 
  
  sensors_event_t humidity, temperature;
  aht.getEvent(&humidity, &temperature);
  float tUdara = temperature.temperature;
  float hUdara = humidity.relative_humidity;
  
  ens160.set_envdata(tUdara, hUdara); 
  ens160.measure();
  int eco2 = ens160.geteCO2();
  int tvoc = ens160.getTVOC();

  // --- C. BACA JARAK ---
  float jarak = sonar.ping_cm();
  if (jarak == 0 || jarak > 400) jarak = 0; 

  // --- D. UPDATE LCD MONITOR ---
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("pH:"); lcd.print(pH, 1);
  lcd.setCursor(9, 0); lcd.print("TDS:"); lcd.print((int)tdsValue);
  lcd.setCursor(0, 1); lcd.print("TAir:"); lcd.print(tAir, 1); lcd.print("C");
  lcd.setCursor(10, 1); lcd.print("CO2:"); lcd.print(co2ppm);
  
  lcd.setCursor(0, 2); lcd.print("Pmp:"); lcd.print(statusPompa ? "ON " : "OFF");
  lcd.setCursor(9, 2); lcd.print("Oxy:"); lcd.print(statusOksigen ? "ON " : "OFF");
  lcd.setCursor(0, 3); lcd.print("--> Data JSON Dikirim");

  // --- E. PACKING & KIRIM DATA KE JSON VIA USB ---
  StaticJsonDocument<768> doc;

  doc["temp_water"] = tAir;
  doc["ph"]         = pH;
  doc["tds"]        = tdsValue;       
  doc["do"]         = doValue;        
  doc["turbidity"]  = turbidityNTU;   
  doc["water_lvl"]  = jarak;
  
  doc["co2"]        = co2ppm;   
  doc["eco2"]       = eco2;     
  doc["tvoc"]       = tvoc;
  doc["temp_air"]   = tUdara;
  doc["humidity"]   = hUdara;

  doc["pump_status"] = statusPompa ? 1 : 0;
  doc["oxy_status"]  = statusOksigen ? 1 : 0;

  // Cetak langsung ke jalur Serial (USB)
  serializeJson(doc, Serial);
  Serial.println(); 
}