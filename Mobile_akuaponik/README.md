# Klasifikasi Kualitas Air pada Akuaponik Berbasis Mobile dengan Pendekatan Machine Learning

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Google Colab](https://img.shields.io/badge/Google_Colab-F9AB00?style=for-the-badge&logo=googlecolab&logoColor=white)

Repositori ini berisi kode sumber lengkap untuk sistem pemantauan dan klasifikasi kualitas air pada ekosistem akuaponik. Sistem ini memanfaatkan **Machine Learning** untuk mengklasifikasikan kondisi air secara *real-time*, disajikan melalui aplikasi **Mobile berbasis Flutter**, dan terhubung ke REST API berbasis **Flask**.

---

## 📌 Ikhtisar Arsitektur

Sistem terdiri dari 3 komponen utama:
1. **Machine Learning Model (`/machine-learning`)**: Model dikembangkan di Google Colab, dilatih menggunakan data parameter air akuaponik dengan memanfaatkan repositori public `kaggle` (pH, suhu, TDS dan DO) dengan algoritma K-Nesrest Neightbor, lalu diekspor ke format `.pkl`.
2. **Back-End REST API (`/backend`)**: Dibuat menggunakan Flask (Python) untuk memproses permintaan data data sensor secara real-time, memuat model ML, mengembalikan hasil prediksi klasifikasi dan mengontrol seluruh /api/ yang terhubung ke backend.
3. **Front-End Mobile App (`/frontend`)**: Aplikasi Android yang dibangun dengan Flutter & Dart untuk menampilkan indikator visual kualitas air, grafik pemantauan, status prediksi, riwayat data sensor serta notifikasi, preset ekosistem hingga kontrol perangkat.

---

## 📁 Struktur Repositori

```text
.
├── backend/                            # Kode Back-End (Flask REST API)
│   ├── app.py                          # Main script Flask
│   ├── water_quality_reference.py      # referensi notifikasi status bahaya
│   ├── models/                         # Model Machine Learning hasil export (.pkl)
│   ├── requirements.txt                # Dependency Python
│   ├── model_metadata.txt              # Rangkuman Hasil Pemelajaran serta Pelatihan Model Machine Learning
│   └── README.md
│
├── frontend/                           # Kode Front-End Mobile (Flutter)
│   ├── lib/                            # Logika aplikasi & UI (Dart)
│   ├── assets/                         # Keperluan Desain berupa logo Aplikasi
│   ├── pubspec.yaml                    # Dependency Flutter
│   └── README.md
│
├── machine-learning/                   # Notebook & Eksperimen Model
│   ├── dataset/                        # Dataset pelatihan (.csv)
│   ├── aquaponics_ml.ipynb             # Google Colab Notebook
│   └── README.md
│
└── README.md                 # Dokumentasi Utama
```

---

## 🚀 Panduan Memulai (Quick Start)

### 1. Pelatihan Model Machine Learning (Google Colab)
* Buka file `aquaponics_ml.ipynb` di direktori `/machine-learning` menggunakan **Google Colab**.
* Jalankan seluruh cell untuk memproses dataset, melatih model, dan mengevaluasi performa (akurasi, confusion matrix).
* Unduh file model terproses (misal: `model.pkl`) dan letakkan di dalam folder `backend/models/`.

### 2. Menjalankan Back-End (Flask API)
1. Masuk ke direktori `backend`:
   ```bash
   cd backend
   ```
2. Buat virtual environment (opsional tetapi disarankan) dan aktifkan:
   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/macOS
   # atau: venv\Scripts\activate  # Windows
   ```
3. Install seluruh dependency:
   ```bash
   pip install -r requirements.txt
   ```
4. Jalankan server Flask:
   ```bash
   python app.py
   ```
   *Server API akan berjalan secara lokal di `http://127.0.0.1:5000`.*

### 3. Menjalankan Front-End (Flutter App)
1. Pastikan Flutter SDK sudah terpasang di perangkat kamu.
2. Masuk ke direktori `frontend`:
   ```bash
   cd frontend
   ```
3. Ambil dependency Flutter:
   ```bash
   flutter pub get
   ```
4. Sesuaikan URL Base API pada konfigurasi aplikasi Flutter (arahkan ke IP server Flask kamu).
5. Jalankan aplikasi pada emulator atau perangkat fisik:
   ```bash
   flutter run
   ```

---

## ⚙️ Parameter Kualitas Air

Model mengklasifikasikan status kualitas air akuaponik berdasarkan parameter berikut:

| Parameter | Satuan | Keterangan |
| --- | --- | --- |
| **pH** | pH scale | Tingkat keasaman / kebasaan air |
| **Suhu** | °C | Suhu air akuaponik |
| **TDS** | PPM | Total Dissolved Solids (Nutrisi/Kepekatan) |
| **DO** | mg/L | Dissolved Oxygen (Oksigen Terlarut) |

---

## 🛠️ Teknologi yang Digunakan

* **Bahasa Pemrograman:** Dart, Python
* **Framework Mobile:** Flutter
* **Framework Back-End:** Flask
* **Machine Learning & Data Science:** Google Colab, Scikit-Learn / TensorFlow, Pandas, NumPy
* **Protokol Komunikasi:** HTTP / REST API (JSON)

---

## 📄 Lisensi

Proyek ini dibuat untuk keperluan akademik/skripsi. Silakan gunakan atau kembangkan kode ini dengan tetap mencantumkan atribusi.
