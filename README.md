# KL CNC Controller — Flutter Android App

Aplikasi controller CNC berbasis Flutter untuk Android.
Support koneksi **USB OTG** (CH340/CP210x/FTDI) dan **WiFi TCP Serial**.

---

## 📁 Struktur Project

```
kl_cnc_controller/
├── lib/
│   ├── main.dart                  ← Entry point + HomeScreen + E-STOP
│   ├── theme.dart                 ← Warna & style neon green
│   ├── models/
│   │   └── grbl_state.dart        ← State mesin (posisi, status, dll)
│   ├── services/
│   │   ├── connection_service.dart ← USB OTG + WiFi TCP konek
│   │   └── grbl_service.dart      ← Semua perintah GRBL
│   ├── screens/
│   │   ├── kontrol_screen.dart    ← Jog, visualizer, run G-code
│   │   ├── spindle_screen.dart    ← RPM, coolant, override
│   │   ├── terminal_screen.dart   ← Serial monitor
│   │   └── settings_screen.dart  ← IP, baud, bed size, dll
│   └── widgets/
│       ├── canvas_painter.dart    ← Tool path visualizer
│       └── connection_dialog.dart ← Dialog konek USB/WiFi
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml    ← USB host permission
│       └── res/xml/device_filter.xml ← Whitelist chip USB
└── pubspec.yaml
```

---

## 🚀 Cara Build

### Prasyarat
- Flutter SDK 3.x → https://flutter.dev/docs/get-started/install
- Android Studio / VS Code
- Android SDK (API 21+)
- USB debugging aktif di HP

### Langkah Build

```bash
# 1. Clone / ekstrak project
cd kl_cnc_controller

# 2. Install dependencies
flutter pub get

# 3. Jalankan di HP (USB debugging aktif)
flutter run

# 4. Build APK release
flutter build apk --release

# APK tersimpan di:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 Fitur

| Fitur | Keterangan |
|---|---|
| **USB OTG Auto-detect** | Otomatis detect saat kabel OTG dicolok |
| **WiFi TCP** | Konek ke ESP32/ESP8266 serial bridge |
| **Jog XYZ** | Tombol arah + long press repeat |
| **Visualizer** | Canvas tool path, pinch zoom, pan |
| **Run G-code** | Load file .nc/.gcode atau ketik manual |
| **Terminal** | Serial monitor real-time |
| **Spindle** | RPM control + preset + override |
| **E-STOP** | Tombol merah emergency stop |
| **Settings** | Simpan preferensi lokal |

---

## 🔌 Koneksi USB OTG

**Chip yang didukung:**
- CH340 / CH341 (Arduino clone Cina)
- CP2102 / CP2104 (Silicon Labs)
- FT232 (FTDI)
- ATmega16U2 (Arduino Uno/Mega asli)
- ATmega32U4 (Arduino Leonardo)
- PL2303 (Prolific)

**Cara pakai:**
1. Hubungkan kabel USB OTG ke HP
2. Sambungkan kabel USB ke Arduino/controller
3. App otomatis detect dan minta izin USB
4. Tap **KONEK** di header
5. Pilih device → tap **KONEK**

---

## 📶 Koneksi WiFi TCP

Upload firmware ESP32 berikut ke ESP32:
```cpp
#include <WiFi.h>

const char* ssid = "NamaWiFi";
const char* password = "PasswordWiFi";
WiFiServer server(23);

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) delay(500);
  server.begin();
}

void loop() {
  WiFiClient client = server.available();
  if (client) {
    while (client.connected()) {
      if (client.available()) Serial.write(client.read());
      if (Serial.available()) client.write(Serial.read());
    }
  }
}
```

Lalu di app, masuk Settings → isi IP ESP32 → port 23 → Save.

---

## ⚙️ GRBL yang Didukung
- GRBL 0.9
- GRBL 1.1 (direkomendasikan)
- GRBL-HAL

---

## 📝 License
MIT — Bebas digunakan dan dimodifikasi.
