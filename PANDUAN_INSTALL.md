# 📱 PANDUAN BUILD APK TANPA LAPTOP
## KL CNC Controller — Cukup Pakai HP & Browser

---

## ✅ CARA 1: GitHub Actions (Gratis, APK Otomatis)

### LANGKAH 1 — Daftar GitHub

1. Buka browser HP → **github.com**
2. Tap **Sign up**
3. Isi email, password, username
4. Verifikasi email
5. Login

---

### LANGKAH 2 — Buat Repository Baru

1. Tap tombol **+** (pojok kanan atas) → **New repository**
2. Isi:
   - **Repository name:** `kl-cnc-controller`
   - **Visibility:** Public ✅
3. Tap **Create repository**

---

### LANGKAH 3 — Upload File Project

Kamu perlu upload SEMUA file dari ZIP ini ke GitHub.

**Cara termudah — pakai github.dev (VS Code online):**

1. Setelah repository dibuat, di address bar browser ubah:
   ```
   github.com/USERNAMEMU/kl-cnc-controller
   ```
   Jadi:
   ```
   github.dev/USERNAMEMU/kl-cnc-controller
   ```
   *(ganti .com → .dev)*

2. VS Code akan terbuka di browser

3. Di panel kiri, buat struktur folder ini satu per satu:
   ```
   📁 .github/
      📁 workflows/
         📄 build.yml
   📁 android/
      📁 app/
         📁 src/main/
            📁 res/xml/
               📄 device_filter.xml
            📄 AndroidManifest.xml
         📄 build.gradle
   📁 lib/
      📁 models/
         📄 grbl_state.dart
      📁 services/
         📄 connection_service.dart
         📄 grbl_service.dart
      📁 screens/
         📄 kontrol_screen.dart
         📄 spindle_screen.dart
         📄 terminal_screen.dart
         📄 settings_screen.dart
      📁 widgets/
         📄 canvas_painter.dart
         📄 connection_dialog.dart
      📄 main.dart
      📄 theme.dart
   📄 pubspec.yaml
   📄 codemagic.yaml
   📄 .gitignore
   ```

4. Copy-paste isi setiap file dari ZIP ke file yang sesuai

5. Tekan **Ctrl+Shift+P** → ketik **Commit** → **Git: Commit All**
6. Isi pesan commit: `Initial commit`
7. Tekan **Ctrl+Shift+P** → **Git: Push**

---

### LANGKAH 4 — Lihat Build Berjalan

1. Balik ke **github.com/USERNAMEMU/kl-cnc-controller**
2. Tap tab **Actions**
3. Kamu akan lihat workflow **"Build APK"** berjalan
4. Tunggu ±5-10 menit sampai ✅ hijau

---

### LANGKAH 5 — Download APK

1. Tap workflow yang sudah selesai (✅ hijau)
2. Scroll ke bawah → bagian **Artifacts**
3. Tap **KL-CNC-Controller-RELEASE**
4. File ZIP akan terdownload berisi APK
5. Ekstrak ZIP → ada file `app-release.apk`
6. Tap file APK → Install di HP

> ⚠️ Saat install, HP akan minta izin
> **"Install aplikasi dari sumber tidak dikenal"** → Izinkan

---

---

## ✅ CARA 2: Codemagic (Lebih Mudah, Ada UI)

### LANGKAH 1 — Daftar Codemagic

1. Buka **codemagic.io**
2. Tap **Start for free**
3. Pilih **Continue with GitHub**
4. Izinkan akses GitHub

### LANGKAH 2 — Tambah Project

1. Tap **Add application**
2. Pilih repository `kl-cnc-controller`
3. Pilih **Flutter App**
4. Tap **Finish: Add application**

### LANGKAH 3 — Build

1. Di halaman project, tap **Start your first build**
2. Pilih branch: **main**
3. Pilih workflow: **android-workflow**
4. Tap **Start new build**
5. Tunggu 5-10 menit

### LANGKAH 4 — Download APK

1. Build selesai → tap **Download artifacts**
2. Download `app-release.apk`
3. Install di HP

---

## 🔧 CARA TRIGGER BUILD ULANG

Kalau ada perubahan kode:

**GitHub Actions:**
1. Buka repository → tab **Actions**
2. Pilih workflow **Build APK**
3. Tap **Run workflow** → **Run workflow**

**Codemagic:**
1. Tap **New build**
2. Pilih branch → Start

---

## ❓ MASALAH UMUM

### Build gagal — "pubspec.yaml not found"
→ Pastikan `pubspec.yaml` ada di root folder (bukan di dalam subfolder)

### Build gagal — "compileSdkVersion"
→ Edit `android/app/build.gradle`, tambahkan:
```
compileSdkVersion 34
```

### APK tidak bisa diinstall
→ Aktifkan **Sumber tidak dikenal** di:
Pengaturan → Keamanan → Install aplikasi tidak dikenal

### USB OTG tidak terdeteksi
→ Pastikan HP support USB OTG (cek spesifikasi HP)
→ Coba kabel OTG yang berbeda

---

## 📞 Butuh Bantuan?

Kirim screenshot error ke chat ini, saya bantu debug.
