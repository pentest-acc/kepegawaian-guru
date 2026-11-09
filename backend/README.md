# Backend API (PHP + MySQL)

API sederhana tanpa framework: **satu file PHP = satu endpoint**. Aplikasi Flutter memanggil API ini lewat HTTP dan menerima jawaban berformat JSON.

## Struktur folder

```
backend/
├── .htaccess          # meneruskan header Authorization ke PHP (Apache Laragon/XAMPP)
├── config/
│   ├── app.php        # zona waktu, masa berlaku token, batas gagal login, jam buka absen, tampilkan error
│   └── database.php   # host, nama database, user, password MySQL (bisa diisi lewat variabel lingkungan, dipakai Docker)
├── core/              # fungsi bantu yang dipakai semua endpoint
│   ├── bootstrap.php  # header JSON + CORS, penanganan error
│   ├── koneksi.php    # koneksi PDO ke MySQL -> db()
│   ├── respon.php     # kirim_json(), ambil_input(), url_backend(), dll.
│   ├── auth.php       # buat token, cek login (wajib_login), dll.
│   ├── info.php       # query & format data info kegiatan
│   ├── jadwal.php     # daftar hari/unit, urutan & format data jadwal mengajar
│   └── absen.php      # aturan absen: jam kerja unit, libur, jarak GPS, simpan foto
├── api/
│   ├── index.php      # cek API & database
│   ├── auth/
│   │   ├── login.php
│   │   ├── register.php
│   │   ├── profil.php
│   │   └── logout.php
│   ├── info/
│   │   ├── daftar.php
│   │   ├── detail.php
│   │   └── tandai.php
│   ├── jadwal/
│   │   └── saya.php       # jadwal mengajar guru yang sedang login
│   ├── absen/
│   │   ├── hari_ini.php   # status absen hari ini + aturan (jam kerja, lokasi)
│   │   ├── masuk.php      # absen masuk (foto + GPS)
│   │   ├── pulang.php     # absen pulang (foto + GPS)
│   │   └── foto.php       # ambil foto absen (wajib login)
│   └── admin/             # khusus role admin
│       ├── guru.php       # daftar guru (untuk memilih guru)
│       ├── jadwal/
│       │   ├── daftar.php
│       │   ├── simpan.php # tambah / ubah + cek jadwal bentrok
│       │   └── hapus.php
│       └── pengaturan/
│           ├── absen.php        # lokasi sekolah, radius, toleransi, jam kerja unit
│           └── simpan_absen.php
└── uploads/
    ├── .htaccess      # melarang file PHP dijalankan di folder unggahan
    ├── lampiran/      # file lampiran info kegiatan (PDF, dll.)
    └── absen/         # foto absen (PRIBADI: tidak bisa dibuka langsung, tidak ikut di-commit)
```

## Format jawaban

Semua endpoint menjawab dengan format yang sama:

```json
{ "sukses": true, "pesan": "Login berhasil.", "data": { ... } }
```

Jika gagal, `sukses` bernilai `false`, `pesan` berisi alasan yang siap ditampilkan, dan kode HTTP-nya 4xx/5xx.

## Daftar endpoint

Alamat dasar (Laragon/XAMPP): `http://localhost/kepegawaian-guru/backend/api`

| Method | Endpoint | Login? | Keterangan |
|---|---|---|---|
| GET | `/` | Tidak | Cek API & koneksi database |
| POST | `/auth/login.php` | Tidak | Login pakai email **atau** nomor induk |
| POST | `/auth/register.php` | Tidak | Daftar akun guru baru |
| GET | `/auth/profil.php` | Ya | Cek token masih berlaku + data pengguna terbaru |
| POST | `/auth/logout.php` | Ya | Hapus token perangkat ini |
| GET | `/info/daftar.php` | Ya | Daftar info kegiatan terbit (terbaru di atas). Parameter opsional: `cari`, `penting=1`, `batas` |
| GET | `/info/detail.php?id=1` | Ya | Detail satu info |
| POST | `/info/tandai.php` | Ya | Tandai/lepas bintang: `{"id_info": 1, "penting": true}` |
| GET | `/jadwal/saya.php` | Ya | Jadwal mengajar mingguan guru yang login + hari libur pada rentang tanggal. Parameter opsional: `dari`, `sampai` (format `YYYY-MM-DD`, default minggu ini Senin–Sabtu, maks. 62 hari) |
| GET | `/admin/guru.php` | Admin | Daftar guru + jumlah jadwalnya. Parameter opsional: `cari` (nama/NIY) |
| GET | `/admin/jadwal/daftar.php?id_pengguna=2` | Admin | Seluruh jadwal mingguan seorang guru |
| POST | `/admin/jadwal/simpan.php` | Admin | Tambah jadwal, atau ubah jika mengirim `id_jadwal` |
| POST | `/admin/jadwal/hapus.php` | Admin | Hapus jadwal: `{"id_jadwal": 5}` |
| GET | `/absen/hari_ini.php` | Guru | Status absen hari ini + jam server, libur, jam kerja unit, jam tombol pulang muncul, titik lokasi sekolah |
| POST | `/absen/masuk.php` | Guru | Absen masuk, **multipart/form-data**: `foto`, `lat`, `lng`, `lokasi_palsu` (opsional) |
| POST | `/absen/pulang.php` | Guru | Absen pulang, isian sama dengan absen masuk |
| GET | `/absen/foto.php?id_absensi=5&jenis=masuk` | Ya | File foto absen (`masuk`/`pulang`). Guru hanya fotonya sendiri, admin semua |
| GET | `/admin/pengaturan/absen.php` | Admin | Pengaturan absen |
| POST | `/admin/pengaturan/simpan_absen.php` | Admin | Simpan pengaturan absen (lihat contoh di bawah) |

Endpoint yang butuh login wajib mengirim header:

```
Authorization: Bearer <token dari login>
```

Endpoint bertanda **Admin** menjawab `403` jika yang login bukan admin, begitu juga endpoint **Guru** jika yang login bukan guru.

### POST `/auth/login.php`

```json
{ "identitas": "guru@contoh.test", "password": "guru123", "perangkat": "Android" }
```

Jawaban 200:

```json
{
  "sukses": true,
  "pesan": "Login berhasil. Selamat datang, Guru Contoh, S.Pd.!",
  "data": {
    "token": "64 karakter hex",
    "pengguna": { "id_pengguna": 2, "nomor_induk": "12345678910", "nama_lengkap": "...", "role": "guru", "jabatan": "Guru Kelas", "unit": "SD", "...": "..." }
  }
}
```

Kode gagal: `422` isian kosong, `401` email/NIY atau kata sandi salah, `403` akun nonaktif, `429` akun dikunci sementara karena 5 kali salah kata sandi (lihat `maks_gagal_login` & `lama_kunci_menit` di `config/app.php`).

### POST `/auth/register.php`

```json
{
  "nama_lengkap": "Siti Aminah",
  "gelar": "S.Pd.",
  "nomor_induk": "2026001",
  "email": "siti@contoh.test",
  "no_hp": "081234567890",
  "unit": "TK",
  "jenis_kelamin": "P",
  "password": "rahasia1",
  "konfirmasi_password": "rahasia1"
}
```

- `201` berhasil. Akun baru selalu ber-role **guru** dan langsung aktif.
- `nama_lengkap` ditulis **tanpa gelar** (tidak boleh mengandung koma); `gelar` boleh kosong.
- `422` isian tidak valid; `data.kesalahan` berisi pesan per kolom.
- `409` email atau nomor induk sudah terdaftar.

### GET `/info/daftar.php`

Contoh `info/daftar.php?batas=1`:

```json
{
  "sukses": true,
  "pesan": "1 info ditemukan.",
  "data": {
    "info": [
      {
        "id_info": 1,
        "judul": "Pengumuman Pengambilan Raport UAS Semester Ganjil",
        "isi": "...",
        "kategori": "Pengumuman",
        "tanggal_kegiatan": "2026-12-19",
        "dibuat_pada": "2026-10-04 07:30:00",
        "lampiran": {
          "nama": "jadwal-pengambilan-raport-semester-ganjil.pdf",
          "url": "http://localhost/kepegawaian-guru/backend/uploads/lampiran/jadwal-pengambilan-raport-semester-ganjil.pdf"
        },
        "penting": false
      }
    ],
    "jumlah": 1
  }
}
```

`penting` milik masing-masing guru (dari tabel `info_penting`). Info berstatus `draf` tidak ikut tampil.

### Jadwal mengajar = jadwal mingguan

Tabel `jadwal_mengajar` menyimpan **pola mingguan** (hari + jam), bukan tanggal. Admin cukup mengisi sekali, lalu jadwal yang sama otomatis berlaku setiap minggu. Tanggal yang ada di tabel `hari_libur` tetap ditampilkan sebagai libur di aplikasi guru.

### GET `/jadwal/saya.php`

Contoh `jadwal/saya.php?dari=2026-10-05&sampai=2026-10-10` (dipotong):

```json
{
  "sukses": true,
  "pesan": "10 jadwal mengajar.",
  "data": {
    "dari": "2026-10-05",
    "sampai": "2026-10-10",
    "jadwal": [
      {
        "id_jadwal": 1,
        "id_pengguna": 2,
        "hari": "Senin",
        "jam_mulai": "07:30",
        "jam_selesai": "09:00",
        "unit": "SD",
        "kelas": "3B",
        "mata_pelajaran": "Bahasa Indonesia"
      }
    ],
    "libur": [ { "tanggal": "2026-10-08", "keterangan": "Libur Yayasan" } ]
  }
}
```

### POST `/admin/jadwal/simpan.php`

```json
{
  "id_jadwal": 5,
  "id_pengguna": 2,
  "hari": "Senin",
  "jam_mulai": "07:30",
  "jam_selesai": "09:00",
  "unit": "SD",
  "kelas": "3B",
  "mata_pelajaran": "Bahasa Indonesia"
}
```

- Tanpa `id_jadwal` = tambah baru (`201`), dengan `id_jadwal` = ubah (`200`). Jawaban berisi `data.jadwal` yang tersimpan.
- `hari`: Senin–Sabtu; `unit`: KB/TK/SD; `kelas` ditulis huruf besar otomatis (mis. `3b` → `3B`).
- `422` isian tidak valid (jam selesai harus setelah jam mulai, dll.), `404` guru/jadwal tidak ditemukan.
- `409` **jadwal bentrok**, yaitu jam yang tumpang tindih dengan:
  - jadwal lain milik guru yang sama di hari itu, atau
  - jadwal guru lain di kelas & unit yang sama pada hari itu.

  Contoh pesan: `"Kelas SD 3B pada jam itu sudah diajar oleh Ahmad Fauzi, S.Pd.I. (Pendidikan Agama Islam, 09:30-10:40)."`

### Aturan absen

| Aturan | Penjelasan |
|---|---|
| Jam absen | Selalu memakai jam **server** (bukan jam HP). |
| Hari tanpa absen | Hari Minggu dan tanggal di tabel `hari_libur` (`422`). Guru berstatus izin/sakit/cuti hari itu juga tidak perlu absen (`409`). |
| Absen masuk | Dibuka mulai `absen_masuk_mulai` (`config/app.php`, bawaan 05.00) sampai jam pulang unit guru. Lewat dari jam masuk unit + toleransi = status `terlambat` dan `menit_terlambat` dihitung dari jam masuk. |
| Absen pulang | Dibuka mulai jam pulang **paling awal** di tabel `jam_kerja_unit` (bawaan 13.00, jam pulang TK). Jika sebelum jam pulang unit guru sendiri, dicatat di `menit_pulang_awal`. |
| Lokasi | Jika admin sudah mengatur titik lokasi sekolah, jarak (rumus Haversine) harus ≤ radius. Jika belum diatur, lokasi tetap disimpan tanpa pengecekan jarak. `lokasi_palsu=1` (Fake GPS terdeteksi di HP) ditolak. |
| Foto | Wajib, JPG/PNG/WEBP (dicek isinya, bukan hanya nama file), maks. `maks_foto_absen_kb` (bawaan 5 MB). Disimpan di `uploads/absen/TAHUN-BULAN/` dengan nama acak. |
| Dobel absen | Satu baris absensi per guru per tanggal; absen masuk/pulang kedua kali dijawab `409`. |

### POST `/absen/masuk.php`

```powershell
curl.exe -X POST http://localhost/kepegawaian-guru/backend/api/absen/masuk.php `
  -H "Authorization: Bearer <token>" `
  -F "foto=@selfie.jpg" -F "lat=-6.1703500" -F "lng=107.0252500"
```

Jawaban `201`:

```json
{
  "sukses": true,
  "pesan": "Absen masuk berhasil pukul 07.21. Kamu terlambat 21 menit.",
  "data": {
    "absensi": {
      "id_absensi": 1,
      "tanggal": "2026-11-10",
      "jam_masuk": "07:21",
      "jam_pulang": null,
      "status": "terlambat",
      "menit_terlambat": 21,
      "menit_pulang_awal": 0,
      "jarak_masuk": 24,
      "jarak_pulang": null,
      "ada_foto_masuk": true,
      "ada_foto_pulang": false,
      "keterangan": null
    }
  }
}
```

Contoh jawaban gagal `422`: `"Kamu berada ± 1,1 km dari sekolah. Absen hanya bisa dilakukan dalam radius 100 m dari sekolah."` (dengan `data.jarak` & `data.radius`).

### POST `/admin/pengaturan/simpan_absen.php`

```json
{
  "lokasi_lat": -6.1702113,
  "lokasi_lng": 107.0251456,
  "radius_absen": 100,
  "toleransi_terlambat": 15,
  "jam_kerja": [
    {"unit": "KB", "jam_masuk": "07:00", "jam_pulang": "13:00"},
    {"unit": "TK", "jam_masuk": "07:00", "jam_pulang": "13:00"},
    {"unit": "SD", "jam_masuk": "07:00", "jam_pulang": "14:00"}
  ]
}
```

`lokasi_lat`/`lokasi_lng` boleh `null` (tanpa cek lokasi). Radius 20–5000 m, toleransi 0–180 menit, ketiga unit wajib ada dan jam pulang harus setelah jam masuk.

## Mencoba API tanpa aplikasi

Buka di browser: <http://localhost/kepegawaian-guru/backend/api/>. Jika muncul `"sukses": true`, berarti PHP dan database sudah tersambung.

Login lewat terminal VS Code (PowerShell):

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost/kepegawaian-guru/backend/api/auth/login.php `
  -ContentType "application/json" -Body '{"identitas":"guru@contoh.test","password":"guru123"}'
```

## Catatan keamanan

- Kata sandi disimpan sebagai hash bcrypt (`password_hash`).
- Yang disimpan di tabel `token_login` hanya hash SHA-256 token, bukan token aslinya.
- Semua query memakai *prepared statement* (aman dari SQL Injection).
- Login dikunci sementara setelah 5 kali salah kata sandi (per akun), mencegah tebak-tebakan kata sandi.
- Folder `uploads/` tidak bisa menjalankan file PHP (lihat `uploads/.htaccess`), jadi file unggahan tidak bisa dipakai untuk menyusupkan skrip.
- Folder `uploads/absen/` tertutup sama sekali (`Require all denied`); foto absen hanya bisa diambil lewat `api/absen/foto.php` oleh guru pemiliknya atau admin. Foto absen juga tidak ikut di-commit ke GitHub (lihat `.gitignore`).
- Saat sudah di hosting: ubah `tampilkan_error` menjadi `false` di `config/app.php` dan pakai user database selain `root`.

## Konfigurasi database lewat variabel lingkungan

`config/database.php` membaca `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, dan `DB_PASSWORD` jika ada. Jika tidak ada (Laragon/XAMPP), otomatis memakai bawaan `127.0.0.1:3306`, user `root` tanpa kata sandi. Docker mengisi variabel ini sendiri (lihat `docker-compose.yml`), sehingga file ini tidak perlu diubah.
