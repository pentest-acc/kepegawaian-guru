# Sistem Informasi Kepegawaian Guru
### Yayasan Tiara Harapan Jaya (KB / TK / SD)

Aplikasi kepegawaian guru berbasis **Flutter** (bisa dijalankan di **Android** dan **web/Chrome**) dengan backend **PHP + MySQL** yang dijalankan memakai **Laragon** (XAMPP juga bisa).
Proyek tugas kelompok mata kuliah Manajemen Proyek Perangkat Lunak (MPPL), Universitas Bina Sarana Informatika.

---

## Progres pengembangan

Dikerjakan bertahap, mulai dari dasar seperti programmer pada umumnya.

| Sesi | Isi | Status |
|---|---|---|
| **1** | Fondasi proyek, rancangan database lengkap, API login/register, animasi splash & loading, Login, Register, Beranda Guru | ✅ Selesai |
| **2** | Info Kegiatan (daftar, cari, tandai penting, detail, unduh lampiran), banner info bergulir otomatis di Beranda, logo & foto Yayasan, nama + gelar terpisah, pengamanan login | ✅ Selesai |
| 3 | Jadwal Mengajar (tab Senin–Jumat) | ⏳ Berikutnya |
| 4 | Absen (foto + GPS, jam masuk/pulang) | ⏳ |
| 5 | Riwayat Absen (rekap per bulan, jam kerja) | ⏳ |
| 6 | Cuti / Izin (pengajuan, sisa kuota, status) | ⏳ |
| 7 | Pengaturan & Profil | ⏳ |
| 8+ | Halaman Admin: dashboard, data guru, kelola info & jadwal, monitoring absensi, persetujuan cuti, laporan PDF/Excel, pengaturan sistem | ⏳ |

### Yang baru di Sesi 2

- **Info Kegiatan** (menu pertama di Beranda) sesuai desain: kolom pencarian, kartu info berisi tanggal dibuat & judul, **bintang** untuk menandai info penting, tombol **Penting** di kanan atas untuk menampilkan info yang ditandai saja, tombol **unduh** untuk info yang punya lampiran (contoh: PDF jadwal pengambilan raport), dan halaman **detail** info.
- **Banner Informasi Akademik** di Beranda kini berisi 5 info terbaru yang **bergulir otomatis ke atas setiap 5 detik** (bisa juga digeser manual). Setiap info menampilkan kategori dan tanggal dibuat; ketuk untuk membuka detailnya.
- **Logo Yayasan** menggantikan ikon toga (splash, login, Beranda, ikon aplikasi Android & web).
- **Foto bersama Yayasan** menjadi latar header halaman Login (filter navy) dan Beranda (memudar ke putih).
- Label unit (KB/TK/SD) di kartu hijau Beranda dihapus.
- Form register: **Nama Lengkap** dan **Gelar** (dropdown) dipisah. Nama tampil otomatis dengan gelar, mis. *Siti Aminah, S.Pd.* atau *Drs. Budi Santoso*.
- **Pengamanan login**: setelah 5 kali salah kata sandi, akun dikunci sementara 15 menit (berlaku untuk login lewat email maupun NIY).

### Yang sudah bisa dicoba (Sesi 1)

- **Splash screen** dengan animasi logo + animasi loading titik memantul, sekaligus cek otomatis apakah masih login.
- **Login** memakai email **atau** Nomor Induk Yayasan (NIY), tombol lihat/sembunyikan kata sandi, overlay loading.
- **Register** akun guru dengan validasi lengkap (nama, NIY, email, no. HP, unit, jenis kelamin, kata sandi).
- **Beranda Guru** sesuai desain: header foto sekolah + logo, foto profil, kartu identitas hijau (Nama, NIY, Jabatan), banner Informasi Akademik, dan 7 menu.
- **Logout**, dan sesi tetap tersimpan (tidak perlu login ulang setiap membuka aplikasi).
- Login sebagai **admin** masuk ke halaman Dashboard Admin sementara.
- Menu yang belum dibuat membuka halaman "Sedang dalam tahap pengembangan".

---

## Struktur folder

```
kepegawaian-guru/
├── aplikasi/     -> aplikasi Flutter (Android + Web)
│   ├── lib/
│   │   ├── config/     (alamat API, warna, tema, daftar halaman)
│   │   ├── models/     (bentuk data, mis. Pengguna)
│   │   ├── services/   (komunikasi ke API & penyimpanan sesi)
│   │   ├── screens/    (halaman: splash, login, register, beranda, ...)
│   │   ├── widgets/    (komponen yang dipakai ulang: tombol, input, loading)
│   │   └── utils/      (validasi form, pesan snackbar)
│   ├── assets/   (font Poppins & gambar)
│   └── test/     (unit test & widget test)
├── backend/      -> API PHP (lihat backend/README.md)
├── database/     -> file SQL + ERD & Kamus Data (lihat database/README.md)
└── .vscode/      -> konfigurasi tombol Run (F5) di VS Code
```

---

## 1. Persiapan (cukup sekali)

Pasang aplikasi berikut di laptop (Windows):

1. **Laragon** (berisi Apache + MySQL + PHP + HeidiSQL) — <https://laragon.org/download>
2. **Git** — <https://git-scm.com/download/win>
3. **Flutter SDK** versi **3.41 atau lebih baru** (disarankan versi stable terbaru) — ikuti panduan <https://docs.flutter.dev/get-started/install/windows>
4. **Android Studio** — dibutuhkan untuk Android SDK (agar bisa menjalankan di HP).
5. **VS Code** + ekstensi **Flutter** dan **Dart** (VS Code akan menyarankannya otomatis saat folder proyek dibuka).

Cek instalasi Flutter di terminal VS Code (`Ctrl + ~`):

```bash
flutter --version
flutter doctor
```

Pastikan `flutter doctor` tidak menunjukkan tanda ❌ pada bagian Flutter, Android toolchain, dan Chrome.

> **Pengaturan Laragon yang dipakai proyek ini** (semuanya bawaan Laragon, tidak perlu diubah):
> web server **Apache**, MySQL port **3306**, user **root** tanpa kata sandi.
> Jika kamu pernah memberi kata sandi pada user root MySQL, isi kata sandinya di `backend/config/database.php`.

---

## 2. Mengambil proyek dari GitHub (pertama kali)

Proyek diletakkan di folder `www` milik Laragon supaya backend PHP langsung bisa diakses Apache.
Buka VS Code → **Terminal → New Terminal**, lalu jalankan:

```bash
cd C:\laragon\www
git clone https://github.com/pentest-acc/kepegawaian-guru.git
cd kepegawaian-guru
code .
```

> - Jika diminta login GitHub, login dengan akun pemilik repository.
> - `code .` membuka folder proyek di VS Code (atau buka manual: **File → Open Folder** → `C:\laragon\www\kepegawaian-guru`).
> - Lokasi folder `www` bisa dicek lewat tombol **Root** di Laragon. Jika Laragon dipasang di drive lain (mis. `D:\laragon`), sesuaikan perintah `cd`-nya.

Lalu unduh paket-paket Flutter:

```bash
cd aplikasi
flutter pub get
```

## 3. Menyalakan Laragon & menyiapkan database

1. Buka **Laragon**, klik **Start All** (Apache dan MySQL menyala).
   Jika Windows menampilkan peringatan Firewall untuk Apache/httpd, centang **Private networks** lalu klik **Allow access** (dibutuhkan agar HP bisa terhubung).
2. Import database, pilih salah satu cara:

   **Cara A — phpMyAdmin (lewat tombol Database di Laragon)**

   File SQL proyek ini **sudah berisi perintah untuk membuat database-nya sendiri**, jadi kamu **tidak perlu** membuat database baru dulu dan **tidak perlu** memilih database apa pun di panel kiri.

   1. Di Laragon klik tombol **Database**. Browser akan membuka phpMyAdmin.
      Jika muncul halaman login, isi **Username** `root`, **kosongkan Password**, lalu klik **Log in** (atau **Go**).

      ![Login phpMyAdmin](docs/gambar/import-1-login.png)

   2. Di deretan menu atas, klik tab **Import** (jika phpMyAdmin berbahasa Indonesia: **Impor**).

      ![Tab Import](docs/gambar/import-2-tab-import.png)

   3. Pada bagian **File to import**, klik **Choose File** (atau **Browse** / **Pilih File**), lalu buka file
      `C:\laragon\www\kepegawaian-guru\database\db_kepegawaian_guru.sql`.
      Pengaturan lain (Character set `utf-8`, Format `SQL`) biarkan apa adanya.

      ![Pilih file SQL](docs/gambar/import-3-pilih-file.png)

   4. Gulir ke paling bawah, klik tombol **Import** (atau **Go** / **Kirim**).

      ![Klik Import](docs/gambar/import-4-klik-import.png)

   5. Jika berhasil, muncul kotak hijau **"Import has been successfully finished, 29 queries executed"** dan database `db_kepegawaian_guru` muncul di panel kiri (klik untuk melihat 9 tabelnya).

      ![Import berhasil](docs/gambar/import-5-berhasil.png)

   > **Cara cadangan** jika tombol Choose File bermasalah: buka file `database/db_kepegawaian_guru.sql` di VS Code → tekan `Ctrl + A` lalu `Ctrl + C` → di phpMyAdmin klik tab **SQL** → klik kotak teksnya, tekan `Ctrl + V` → klik **Go** (pojok kanan bawah). Hasilnya beberapa kotak hijau, dan `db_kepegawaian_guru` muncul di panel kiri setelah halaman di-refresh (`F5`).
   >
   > Laragon versi lama membuka **HeidiSQL** (bukan phpMyAdmin) saat tombol Database diklik. Di HeidiSQL: klik **Open** → menu **File → Run SQL file...** → pilih file SQL di atas → tekan **F5** untuk refresh.

   **Cara B — Terminal Laragon**
   Di Laragon klik tombol **Terminal**, lalu ketik:

   ```bash
   cd C:\laragon\www\kepegawaian-guru
   mysql -u root -e "source database/db_kepegawaian_guru.sql"
   ```

   > Perintah `mysql` bisa juga dipakai di terminal VS Code setelah mengaktifkan
   > **Menu Laragon → Tools → Path → Add Laragon to Path**, lalu tutup & buka lagi VS Code.

3. Cek backend: buka <http://localhost/kepegawaian-guru/backend/api/> di browser. Jika tampil tulisan seperti ini, backend sudah siap:

   ```json
   {"sukses":true,"pesan":"API Kepegawaian Guru berjalan dengan baik.", ...}
   ```

   (Laragon juga otomatis membuat alamat cantik <http://kepegawaian-guru.test/backend/api/> setelah Laragon di-*Reload*. Alamat `.test` ini hanya bisa dibuka dari laptop, jadi aplikasi tetap memakai alamat `localhost`/IP laptop.)

## 4. Menjalankan aplikasi di Chrome (paling mudah)

Dari folder `aplikasi`:

```bash
flutter run -d chrome
```

Atau di VS Code tekan **F5** → pilih **"Aplikasi - Chrome (web)"**.

## 5. Menjalankan aplikasi di HP Android

1. **Sambungkan HP dan laptop ke Wi-Fi yang sama.**
2. Cari IP laptop: buka CMD/terminal, ketik `ipconfig`, lihat **IPv4 Address** di bagian Wi-Fi (contoh `192.168.1.7`).
3. Buka file `aplikasi/lib/config/api_config.dart`, ganti nilai `ipLaptop`:
   ```dart
   static const String ipLaptop = '192.168.1.7';
   ```
4. Tes dulu dari **browser HP**: buka `http://192.168.1.7/kepegawaian-guru/backend/api/`.
   Jika JSON-nya tampil, HP sudah bisa menghubungi laptop. Jika tidak, izinkan **Apache** di Windows Firewall (lihat Troubleshooting).
5. Aktifkan **Opsi Pengembang** di HP (Pengaturan → Tentang ponsel → ketuk **Nomor versi/Build number** 7×), lalu nyalakan **Debugging USB**.
6. Colok HP ke laptop dengan kabel USB, izinkan debugging di HP, lalu jalankan:
   ```bash
   flutter devices
   flutter run
   ```
   Atau tekan **F5** di VS Code → **"Aplikasi - HP Android / perangkat terpilih"** (pilih HP di pojok kanan bawah VS Code).

Membuat file APK untuk dipasang/dibagikan:

```bash
flutter build apk --release
```

File APK ada di `aplikasi/build/app/outputs/flutter-apk/app-release.apk`.

## 6. Akun demo

| Role | Login (Email atau NIY) | Kata sandi |
|---|---|---|
| Guru | `guru@contoh.test` atau `12345678910` | `guru123` |
| Admin | `admin@contoh.test` atau `ADM001` | `admin123` |

Bisa juga membuat akun guru sendiri lewat tombol **Daftar di sini** di halaman login.

---

## 7. Mengambil pembaruan dari sesi berikutnya

Setiap sesi selesai, hasilnya dikirim sebagai **Pull Request** ke branch `main`. Setelah Pull Request di-*merge* di GitHub, ambil kode terbarunya dari terminal VS Code:

```bash
cd C:\laragon\www\kepegawaian-guru
git checkout main
git pull
cd aplikasi
flutter pub get
```

> Jika sesi berikutnya mengubah database, akan ada file SQL tambahan + petunjuknya. Jangan import ulang `db_kepegawaian_guru.sql` kalau database sudah berisi data asli, karena file itu menghapus tabel lama.

### Pembaruan database Sesi 2 (wajib, cukup sekali)

Sesi 2 menambah kolom `gelar`, tabel `percobaan_login`, dan info kegiatan contoh. Pilih **salah satu**:

- **Cara mudah (data lama boleh hilang)** — import ulang `database/db_kepegawaian_guru.sql` lewat phpMyAdmin seperti langkah 3. Semua tabel dibuat ulang (akun yang pernah kamu daftarkan sendiri ikut terhapus; akun demo tetap ada).
- **Cara aman (data lama dipertahankan)** — di phpMyAdmin klik tab **Import**, pilih file `database/migrasi/2026-10-09_sesi2.sql`, lalu klik **Import**. Nama yang sudah berisi gelar (mis. "Siti Aminah, S.Pd.") otomatis dipisah menjadi nama + gelar.

Setelah itu jalankan ulang aplikasi (`flutter run`), karena ada gambar & paket baru (`url_launcher`).

### Memakai XAMPP (opsional)

Proyek ini juga berjalan di XAMPP tanpa perubahan kode: clone ke `C:\xampp\htdocs` (bukan `C:\laragon\www`), nyalakan Apache & MySQL dari XAMPP Control Panel, lalu import SQL lewat <http://localhost/phpmyadmin> (tab **Import**).

---

## Gambar Yayasan (logo & foto header)

Gambar ada di `aplikasi/assets/images/`:

- `logo_yayasan.png` — logo Yayasan (splash, login, Beranda)
- `header_sekolah.jpg` — foto bersama untuk latar header Login & Beranda

Untuk mengganti, timpa file tersebut dengan gambar baru (nama file sama), **stop** aplikasi, lalu jalankan ulang (`flutter run`). Ikon aplikasi Android ada di `aplikasi/android/app/src/main/res/mipmap-*/ic_launcher.png` dan ikon web di `aplikasi/web/`.

## Keamanan login

- Login bisa memakai **email** atau **Nomor Induk Yayasan (NIY)**. Keduanya hanya berfungsi sebagai *nama pengguna*; yang benar-benar melindungi akun adalah **kata sandi** (disimpan sebagai hash bcrypt, tidak bisa dibaca siapa pun).
- Untuk mencegah orang menebak-nebak kata sandi, akun dikunci **15 menit** setelah **5 kali** salah kata sandi (dihitung per akun, jadi tidak bisa diakali dengan bergantian memakai email lalu NIY). Angka ini bisa diubah di `backend/config/app.php`.

## Menjalankan test

```bash
cd aplikasi
flutter analyze
flutter test
```

---

## Troubleshooting

| Masalah | Solusi |
|---|---|
| "Tidak dapat terhubung ke server" | Pastikan Laragon sudah **Start All**. Di HP: cek `ipLaptop` di `api_config.dart` dan HP satu Wi-Fi dengan laptop. |
| Browser HP tidak bisa membuka `http://IP-laptop/...` | Windows Firewall memblokir Apache. Buka **Windows Defender Firewall → Allow an app** → centang **Apache HTTP Server** (httpd) untuk jaringan **Private**. Pastikan jaringan Wi-Fi di Windows diset sebagai *Private*. |
| phpMyAdmin menolak login (`#1045 Access denied` atau *"Login without a password is forbidden"*) | Login dengan username `root` dan password kosong. Jika muncul pesan *forbidden*, buka file `config.inc.php` milik phpMyAdmin di Laragon (biasanya `C:\laragon\etc\apps\phpMyAdmin\config.inc.php`) lalu tambahkan baris `$cfg['Servers'][$i]['AllowNoPassword'] = true;`. Jika root MySQL kamu memakai password, isi password itu juga di `backend/config/database.php`. |
| "Gagal terhubung ke database" | MySQL di Laragon belum menyala, atau database belum di-import (langkah 3). Jika user root MySQL memakai kata sandi, isi di `backend/config/database.php`. |
| Setiap aplikasi dibuka ulang selalu kembali ke halaman Login | Apache membuang header token. Pastikan file `backend/.htaccess` ikut ter-clone (file tersembunyi) dan Laragon memakai **Apache** (Menu → Preferences → Services & Ports). |
| Apache tidak mau menyala karena port 80 dipakai | Matikan aplikasi yang memakai port 80 (mis. IIS/Skype), atau ganti port Apache di Laragon (Menu → Preferences → Services & Ports) lalu jalankan aplikasi dengan `flutter run --dart-define=API_URL=http://localhost:PORT/kepegawaian-guru/backend/api`. |
| `flutter pub get` gagal karena versi SDK | Perbarui Flutter: `flutter upgrade`. |
| Folder proyek bukan `kepegawaian-guru` | Ubah `folderProyek` di `aplikasi/lib/config/api_config.dart`. |
