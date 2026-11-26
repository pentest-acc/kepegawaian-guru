# Backend API (PHP + MySQL)

API sederhana tanpa framework: **satu file PHP = satu endpoint**. Aplikasi Flutter memanggil API ini lewat HTTP dan menerima jawaban berformat JSON.

## Struktur folder

```
backend/
├── .htaccess          # meneruskan header Authorization ke PHP (Apache Laragon/XAMPP)
├── config/
│   ├── app.php        # zona waktu, masa berlaku token, batas gagal login, ukuran foto absen, tampilkan error
│   └── database.php   # host, nama database, user, password MySQL (bisa diisi lewat variabel lingkungan, dipakai Docker)
├── core/              # fungsi bantu yang dipakai semua endpoint
│   ├── bootstrap.php  # header JSON + CORS, penanganan error
│   ├── koneksi.php    # koneksi PDO ke MySQL -> db()
│   ├── respon.php     # kirim_json(), ambil_input(), url_backend(), dll.
│   ├── auth.php       # buat token, cek login (wajib_login), dll.
│   ├── info.php       # query & format data info kegiatan
│   ├── jadwal.php     # daftar hari/unit, urutan & format data jadwal mengajar (+ gedung)
│   ├── absen.php      # aturan absen per mapel: status terlambat, libur, jarak GPS, simpan foto
│   └── cuti.php       # aturan cuti/izin/sakit: hari kerja, kuota, bertumpuk, lampiran
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
│   │   ├── hari_ini.php   # mapel hari ini + status absen masing-masing + daftar lokasi
│   │   ├── kirim.php      # absen satu mapel (foto + GPS)
│   │   ├── riwayat.php    # riwayat absen satu bulan (kalender Riwayat Absen)
│   │   └── foto.php       # ambil foto absen (wajib login)
│   ├── cuti/
│   │   ├── saya.php       # kuota cuti + daftar pengajuan guru yang login
│   │   ├── hitung.php     # pratinjau: hari kerja, mapel yang ditinggalkan, sisa kuota
│   │   ├── ajukan.php     # kirim pengajuan (+ foto lampiran)
│   │   ├── batal.php      # batalkan pengajuan yang masih menunggu
│   │   └── lampiran.php   # ambil foto lampiran (wajib login)
│   └── admin/             # khusus role admin
│       ├── guru.php       # daftar guru (untuk memilih guru)
│       ├── absensi/
│       │   ├── harian.php # monitoring absensi semua guru pada satu tanggal
│       │   └── ubah.php   # admin menandai / mengubah kehadiran satu mapel
│       ├── cuti/
│       │   ├── daftar.php # daftar pengajuan per status
│       │   ├── detail.php # detail + kuota + mapel yang ditinggalkan
│       │   └── proses.php # setujui / tolak
│       ├── jadwal/
│       │   ├── daftar.php
│       │   ├── simpan.php # tambah / ubah + cek jadwal bentrok
│       │   └── hapus.php
│       ├── lokasi/          # banyak lokasi absen (mis. 3 gedung)
│       │   ├── daftar.php
│       │   ├── simpan.php   # tambah / ubah
│       │   └── hapus.php
│       └── pengaturan/
│           ├── absen.php        # toleransi terlambat, absen dibuka sebelum mapel, kuota cuti
│           └── simpan_absen.php
└── uploads/
    ├── .htaccess      # melarang file PHP dijalankan di folder unggahan
    ├── lampiran/      # file lampiran info kegiatan (PDF, dll.)
    ├── absen/         # foto absen (PRIBADI: tidak bisa dibuka langsung, tidak ikut di-commit)
    └── cuti/          # foto lampiran cuti, mis. surat dokter (PRIBADI, tidak ikut di-commit)
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
| POST | `/admin/jadwal/simpan.php` | Admin | Tambah jadwal, atau ubah jika mengirim `id_jadwal` (termasuk gedung `id_lokasi`) |
| POST | `/admin/jadwal/hapus.php` | Admin | Hapus jadwal: `{"id_jadwal": 5}` |
| GET | `/absen/hari_ini.php` | Guru | Jam server, libur, cuti/izin/sakit yang disetujui hari ini (`cuti`), toleransi, jam buka absen, daftar lokasi absen aktif, dan **daftar mapel hari ini** beserta absensinya (`mapel`) |
| POST | `/absen/kirim.php` | Guru | Absen satu mapel, **multipart/form-data**: `id_jadwal`, `foto`, `lat`, `lng`, `lokasi_palsu` (opsional) |
| GET | `/absen/riwayat.php?bulan=2026-11` | Guru / Admin | Riwayat absen satu bulan: setiap tanggal berisi libur, cuti yang disetujui, dan mapel beserta absensinya (default bulan ini). Admin wajib menambah `&id_pengguna=2` |
| GET | `/absen/foto.php?id_absensi=5` | Ya | File foto absen. Guru hanya fotonya sendiri, admin semua |
| GET | `/admin/absensi/harian.php?tanggal=2026-11-23` | Admin | Monitoring: semua guru yang mengajar pada tanggal itu + kehadiran setiap mapelnya (default hari ini) |
| POST | `/admin/absensi/ubah.php` | Admin | Tandai / ubah kehadiran satu mapel (lihat contoh di bawah) |
| GET | `/admin/lokasi/daftar.php` | Admin | Semua lokasi absen (aktif & nonaktif) beserta nomor urutnya (Lokasi 1, 2, 3, ...) |
| POST | `/admin/lokasi/simpan.php` | Admin | Tambah lokasi, atau ubah jika mengirim `id_lokasi` (lihat contoh di bawah) |
| POST | `/admin/lokasi/hapus.php` | Admin | Hapus lokasi: `{"id_lokasi": 2}` (riwayat absen tetap ada) |
| GET | `/cuti/saya.php` | Guru | Kuota cuti tahun ini (`?tahun=` opsional) + semua pengajuan milik guru |
| GET | `/cuti/hitung.php?jenis=cuti&tanggal_mulai=…&tanggal_selesai=…` | Guru | Pratinjau sebelum mengajukan (aturan sama dengan `ajukan.php`, tidak menyimpan apa pun) |
| POST | `/cuti/ajukan.php` | Guru | Ajukan cuti/izin/sakit, **multipart/form-data**: `jenis`, `tanggal_mulai`, `tanggal_selesai`, `alasan`, `lampiran` (foto, opsional) |
| POST | `/cuti/batal.php` | Guru | Batalkan pengajuan yang masih menunggu: `{"id_cuti": 5}` |
| GET | `/cuti/lampiran.php?id_cuti=5` | Ya | File foto lampiran. Guru hanya miliknya sendiri, admin semua |
| GET | `/admin/cuti/daftar.php?status=menunggu` | Admin | Daftar pengajuan semua guru (`menunggu`, `disetujui`, `ditolak`, `semua`; `cari` opsional) + `jumlah_menunggu` |
| GET | `/admin/cuti/detail.php?id_cuti=5` | Admin | Detail pengajuan + mapel yang ditinggalkan per tanggal + kuota guru |
| POST | `/admin/cuti/proses.php` | Admin | Setujui / tolak (lihat contoh di bawah) |
| GET | `/admin/pengaturan/absen.php` | Admin | Pengaturan absen & cuti (toleransi terlambat, absen dibuka sebelum mapel, kuota cuti tahunan, jumlah lokasi aktif) |
| POST | `/admin/pengaturan/simpan_absen.php` | Admin | Simpan pengaturan absen & cuti (lihat contoh di bawah) |

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
        "mata_pelajaran": "Bahasa Indonesia",
        "id_lokasi": 2,
        "lokasi": "Gedung SD"
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
  "mata_pelajaran": "Bahasa Indonesia",
  "id_lokasi": 2
}
```

- Tanpa `id_jadwal` = tambah baru (`201`), dengan `id_jadwal` = ubah (`200`). Jawaban berisi `data.jadwal` yang tersimpan.
- `hari`: Senin–Sabtu; `unit`: KB/TK/SD; `kelas` ditulis huruf besar otomatis (mis. `3b` → `3B`).
- `id_lokasi` (opsional) = gedung tempat mengajar, dari tabel `lokasi_absen`; kosong/`0` = belum ditentukan. Gedung ini hanya informasi untuk guru, guru tetap boleh absen di lokasi absen mana pun.
- `422` isian tidak valid (jam selesai harus setelah jam mulai, dll.), `404` guru/jadwal tidak ditemukan.
- `409` **jadwal bentrok**, yaitu jam yang tumpang tindih dengan:
  - jadwal lain milik guru yang sama di hari itu, atau
  - jadwal guru lain di kelas & unit yang sama pada hari itu.

  Contoh pesan: `"Kelas SD 3B pada jam itu sudah diajar oleh Ahmad Fauzi, S.Pd.I. (Pendidikan Agama Islam, 09:30-10:40)."`

### Aturan absen (per mata pelajaran)

| Aturan | Penjelasan |
|---|---|
| Satu mapel = satu absen | Setiap jadwal mengajar hari itu diabsen sendiri-sendiri (guru dengan 2 mapel absen 2 kali). Satu baris `absensi` per jadwal per tanggal; absen kedua kali dijawab `409`. Tidak ada jam masuk/pulang per unit: jam masuk = mapel pertama, boleh pulang setelah mapel terakhir selesai. |
| Jam absen | Selalu memakai jam **server** (bukan jam HP). |
| Hari tanpa absen | Hari Minggu dan tanggal di tabel `hari_libur` (`422`). Jadwal yang bukan hari ini juga ditolak (`422`). Guru yang cuti/izin/sakitnya sudah disetujui admin untuk hari itu tidak perlu absen (`409`). |
| Kapan dibuka | Mulai `buka_absen_menit` (tabel `pengaturan`, bawaan 30) **sebelum** jam mulai mapel, sampai akhir hari. |
| Terlambat | Lewat dari jam mulai + `toleransi_terlambat` (bawaan 15 menit) = status `terlambat`, `menit_terlambat` dihitung dari jam mulai. **Tetap boleh absen**, bahkan setelah jam pelajarannya selesai (`lewat_jam: true`, ditandai merah di Monitoring Absensi). |
| Ditandai admin | Admin bisa menandai kehadiran lewat `admin/absensi/ubah.php` (mis. guru lupa absen, izin, sakit, alpa). Jika mapel sudah ditandai admin, guru tidak bisa absen lagi untuk mapel itu (`409`). |
| Lokasi | Admin bisa menambah **banyak lokasi absen** (tabel `lokasi_absen`). Guru harus berada di dalam radius **salah satu** lokasi yang aktif (jarak dihitung dengan rumus Haversine); yang dicatat adalah lokasi terdekat beserta jaraknya (`id_lokasi`, `jarak`). Gedung di jadwal mengajar tidak membatasi lokasi absen. Jika belum ada lokasi sama sekali, lokasi guru tetap disimpan tanpa pengecekan jarak. `lokasi_palsu=1` (Fake GPS terdeteksi di HP) ditolak. |
| Foto | Wajib, JPG/PNG/WEBP (dicek isinya, bukan hanya nama file), maks. `maks_foto_absen_kb` (bawaan 5 MB). Disimpan di `uploads/absen/TAHUN-BULAN/` dengan nama acak. |
| Data mapel | Nama mapel, unit, kelas, dan jamnya ikut disalin ke baris absensi, sehingga riwayat absen tidak berubah walaupun jadwal diubah/dihapus admin. |

### GET `/absen/hari_ini.php`

Contoh jawaban (dipotong):

```json
{
  "sukses": true,
  "pesan": "Data absen hari ini.",
  "data": {
    "tanggal": "2026-11-23",
    "hari": "Senin",
    "waktu_server": "2026-11-23 07:20:00",
    "libur": null,
    "toleransi_menit": 15,
    "buka_absen_menit": 30,
    "lokasi_absen": [ { "id_lokasi": 1, "nomor": 1, "nama": "Gedung SD", "lat": -6.17, "lng": 107.03, "radius": 150, "aktif": true } ],
    "mapel": [
      {
        "id_jadwal": 1,
        "mata_pelajaran": "Bahasa Indonesia",
        "unit": "SD",
        "kelas": "3B",
        "jam_mulai": "07:30",
        "jam_selesai": "09:00",
        "id_lokasi": 1,
        "lokasi": "Gedung SD",
        "absensi": null
      }
    ]
  }
}
```

`absensi` berisi data absen mapel tersebut (format sama dengan contoh di bawah) atau `null` jika belum absen.

### POST `/absen/kirim.php`

```powershell
curl.exe -X POST http://localhost/kepegawaian-guru/backend/api/absen/kirim.php `
  -H "Authorization: Bearer <token>" `
  -F "id_jadwal=1" -F "foto=@selfie.jpg" -F "lat=-6.1703500" -F "lng=107.0252500"
```

Jawaban `201`:

```json
{
  "sukses": true,
  "pesan": "Absen Bahasa Indonesia berhasil pukul 08.01 di Gedung SD. Kamu terlambat 31 menit.",
  "data": {
    "absensi": {
      "id_absensi": 1,
      "id_jadwal": 1,
      "tanggal": "2026-11-23",
      "mata_pelajaran": "Bahasa Indonesia",
      "unit": "SD",
      "kelas": "3B",
      "jam_mulai": "07:30",
      "jam_selesai": "09:00",
      "jam_absen": "08:01",
      "status": "terlambat",
      "menit_terlambat": 31,
      "lewat_jam": false,
      "lokasi": "Gedung SD",
      "jarak": 24,
      "ada_foto": true,
      "keterangan": null,
      "diubah_admin": false
    }
  }
}
```

Contoh jawaban gagal:

- `422` `"Absen Bahasa Indonesia dibuka mulai pukul 07.00."`
- `422` `"Kamu berada ± 400 m dari lokasi absen terdekat (Gedung KB). Absen hanya bisa dilakukan dalam radius 100 m dari lokasi tersebut."` (dengan `data.lokasi`, `data.jarak` & `data.radius`)
- `409` `"Kamu sudah absen Bahasa Indonesia pukul 07.25."` / `"Kehadiran mapel ini sudah ditandai admin (izin)."`

### GET `/absen/riwayat.php`

Parameter `bulan` (format `YYYY-MM`, default bulan ini). Contoh jawaban (dipotong):

```json
{
  "sukses": true,
  "pesan": "Riwayat absen 2026-11.",
  "data": {
    "bulan": "2026-11",
    "hari_ini": "2026-11-23",
    "waktu_server": "2026-11-23 10:00:00",
    "mulai": "2026-10-19",
    "toleransi_menit": 15,
    "hari": [
      { "tanggal": "2026-11-01", "hari": "Minggu", "libur": "Hari Minggu", "cuti": null, "mapel": [] },
      {
        "tanggal": "2026-11-02",
        "hari": "Senin",
        "libur": null,
        "cuti": null,
        "mapel": [
          { "id_jadwal": 1, "mata_pelajaran": "Bahasa Indonesia", "jam_mulai": "07:30", "jam_selesai": "09:00", "absensi": { "status": "hadir", "jam_absen": "07:21" } },
          { "id_jadwal": 2, "mata_pelajaran": "Bahasa Indonesia", "jam_mulai": "09:30", "jam_selesai": "10:40", "absensi": null }
        ]
      }
    ]
  }
}
```

- `hari` berisi **setiap tanggal** dalam bulan itu. Format `mapel` sama seperti di `absen/hari_ini.php`; `absensi: null` = tidak absen (atau belum, untuk hari ini & hari mendatang).
- Mapel diambil dari jadwal mingguan yang **sudah dibuat** pada tanggal tersebut (dilihat dari `jadwal_mengajar.dibuat_pada`), ditambah absensi yang jadwalnya sudah dihapus/diubah. Hari Minggu & `hari_libur` tidak berisi jadwal.
- `cuti` = jenis cuti/izin/sakit yang sudah **disetujui** admin (tabel `cuti`) pada tanggal itu.
- `mulai` = tanggal awal riwayat guru (akun dibuat atau absen pertama), dipakai aplikasi untuk membatasi pilihan tahun ajaran.
- Penentuan warna kalender (hadir / sebagian / izin / tidak absen) dan rekap bulan dihitung di aplikasi dari data ini.
- `422` jika format bulan salah.

### GET `/admin/absensi/harian.php`

Parameter `tanggal` (format `YYYY-MM-DD`, default hari ini). Jawaban berisi `tanggal`, `hari`, `waktu_server`, `libur`, `toleransi_menit`, dan `guru`: daftar guru aktif yang punya jadwal di hari itu, masing-masing dengan `mapel` (format sama seperti `mapel` di `absen/hari_ini.php`). Absensi yang jadwalnya sudah dihapus tetap ikut tampil.

### POST `/admin/absensi/ubah.php`

Menandai mapel yang belum diabsen (kirim `id_jadwal` + `tanggal`):

```json
{ "id_jadwal": 1, "tanggal": "2026-11-23", "status": "hadir", "keterangan": "Lupa absen, sudah dikonfirmasi" }
```

Atau mengubah absensi yang sudah ada (kirim `id_absensi`):

```json
{ "id_absensi": 12, "status": "izin", "keterangan": "Izin ke dokter" }
```

- `status`: `hadir`, `terlambat`, `izin`, `sakit`, `cuti`, `alpa`, atau `belum` (menghapus tanda dari admin). Jawaban berisi `data.absensi` (`null` jika dihapus); `diubah_admin` menjadi `true`.
- Absen yang berisi foto dari guru tidak bisa dihapus, hanya diubah statusnya (`422`).
- `422` jika hari pada `tanggal` tidak sama dengan hari jadwalnya.

### POST `/admin/lokasi/simpan.php`

```json
{
  "id_lokasi": 2,
  "nama": "Gedung SD",
  "lat": -6.1750000,
  "lng": 107.0300000,
  "radius": 150,
  "aktif": true
}
```

- Tanpa `id_lokasi` = tambah baru (`201`), dengan `id_lokasi` = ubah (`200`). Jawaban berisi `data.lokasi` (termasuk `nomor`).
- Nama 2–100 karakter dan tidak boleh sama dengan lokasi lain (`409`), radius 20–5000 m, maksimal 20 lokasi.
- `"aktif": false` menutup lokasi sementara (tidak dipakai untuk absen, tetapi tidak dihapus).

### POST `/admin/pengaturan/simpan_absen.php`

```json
{
  "toleransi_terlambat": 15,
  "buka_absen_menit": 30,
  "kuota_cuti_tahunan": 12
}
```

Toleransi & jam buka absen 0–180 menit, kuota cuti 0–60 hari kerja per tahun. Jam masuk/pulang tidak diatur di sini karena mengikuti jadwal mengajar setiap guru. Lokasi absen diatur lewat `admin/lokasi/*.php`.

### Aturan cuti / izin / sakit

| Aturan | Penjelasan |
|---|---|
| Jenis | `cuti` memotong kuota tahunan (`pengaturan.kuota_cuti_tahunan`, bawaan 12). `izin` & `sakit` tidak memotong kuota. |
| Jumlah hari | Hari kerja dalam rentang tanggal: hari Minggu & tanggal di `hari_libur` tidak dihitung. Rentang yang hanya berisi hari libur ditolak (`422`). |
| Kapan boleh diajukan | Cuti: hari ini atau tanggal mendatang. Izin & sakit: boleh menyusul, paling lambat 7 hari setelah tanggalnya. Cuti yang melewati pergantian tahun diajukan terpisah. |
| Lama | Maksimal 30 hari kalender per pengajuan. |
| Bertumpuk | Tidak boleh bertumpuk dengan pengajuan lain milik guru yang masih menunggu / sudah disetujui (`409`). |
| Kuota | Dihitung per tahun kalender: `sisa = kuota - terpakai (disetujui) - diajukan (menunggu)`. Pengajuan cuti melebihi sisa ditolak (`422`), dan admin tidak bisa menyetujui cuti yang membuat kuota terlampaui. |
| Lampiran | Foto JPG/PNG/WEBP maks. 5 MB, disimpan di `uploads/cuti/TAHUN-BULAN/`. **Wajib** untuk sakit 2 hari kerja atau lebih. |
| Batal | Guru hanya bisa membatalkan (menghapus) pengajuan yang masih `menunggu`. |
| Proses admin | Hanya pengajuan `menunggu`. Menolak wajib menulis `catatan` (alasan). |
| Setelah disetujui | Hari itu guru tidak perlu absen (`absen/kirim.php` menjawab `409`), `absen/hari_ini.php` berisi `"cuti": "sakit"`, mapel di Monitoring & Riwayat Absen dihitung cuti/izin/sakit, kecuali mapel yang tetap diabsen guru. |

### GET `/cuti/hitung.php`

Contoh `cuti/hitung.php?jenis=cuti&tanggal_mulai=2026-12-14&tanggal_selesai=2026-12-15` (dipotong):

```json
{
  "sukses": true,
  "pesan": "2 hari kerja.",
  "data": {
    "jenis": "cuti",
    "tanggal_mulai": "2026-12-14",
    "tanggal_selesai": "2026-12-15",
    "jumlah_hari": 2,
    "jumlah_mapel": 5,
    "hari": [
      { "tanggal": "2026-12-14", "hari": "Senin", "mapel": [ { "jam_mulai": "07:30", "jam_selesai": "09:00", "mata_pelajaran": "Bahasa Indonesia", "unit": "SD", "kelas": "3B", "lokasi": "Gedung SD" } ] }
    ],
    "kuota": { "tahun": 2026, "kuota": 12, "terpakai": 2, "diajukan": 3, "sisa": 7 },
    "wajib_lampiran": false
  }
}
```

Contoh jawaban gagal: `422` `"Cuti tidak bisa diajukan untuk tanggal yang sudah lewat. Gunakan izin atau sakit jika keperluannya mendadak."`, `"Sisa kuota cuti tahun 2026 tinggal 7 hari, sedangkan pengajuan ini 9 hari kerja."`, `409` `"Tanggalnya bertumpuk dengan pengajuan Cuti 1 Des 2026 - 2 Des 2026 yang sudah disetujui."`

### POST `/cuti/ajukan.php`

```powershell
curl.exe -X POST http://localhost/kepegawaian-guru/backend/api/cuti/ajukan.php `
  -H "Authorization: Bearer <token>" `
  -F "jenis=sakit" -F "tanggal_mulai=2026-11-19" -F "tanggal_selesai=2026-11-20" `
  -F "alasan=Demam tinggi, dokter menyarankan istirahat 2 hari." -F "lampiran=@surat_dokter.jpg"
```

Jawaban `201`: `data.cuti` (pengajuan berstatus `menunggu`) dan `data.kuota`. Format satu pengajuan:

```json
{
  "id_cuti": 1,
  "id_pengguna": 2,
  "jenis": "sakit",
  "tanggal_mulai": "2026-11-19",
  "tanggal_selesai": "2026-11-20",
  "jumlah_hari": 2,
  "alasan": "Demam tinggi, dokter menyarankan istirahat 2 hari.",
  "ada_lampiran": true,
  "status": "disetujui",
  "catatan_admin": "Semoga lekas sembuh.",
  "diproses_oleh": "Admin Yayasan",
  "diproses_pada": "2026-11-19 07:10:00",
  "dibuat_pada": "2026-11-18 15:00:00"
}
```

Di endpoint admin, setiap pengajuan juga berisi `guru` (`id_pengguna`, `nomor_induk`, `nama_tampil`, `unit`) dan `jumlah_mapel`.

### POST `/admin/cuti/proses.php`

```json
{ "id_cuti": 5, "keputusan": "disetujui", "catatan": "Semoga lekas sembuh." }
```

- `keputusan`: `disetujui` atau `ditolak`. `catatan` maks. 255 karakter, **wajib** (min. 5 karakter) jika ditolak.
- `409` jika pengajuan sudah diproses atau bertumpuk dengan cuti lain yang sudah disetujui; `422` jika kuota cuti guru tidak cukup.

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
- Folder `uploads/absen/` dan `uploads/cuti/` tertutup sama sekali (`Require all denied`); foto absen dan lampiran cuti hanya bisa diambil lewat `api/absen/foto.php` / `api/cuti/lampiran.php` oleh guru pemiliknya atau admin. Keduanya juga tidak ikut di-commit ke GitHub (lihat `.gitignore`).
- Saat sudah di hosting: ubah `tampilkan_error` menjadi `false` di `config/app.php` dan pakai user database selain `root`.

## Konfigurasi database lewat variabel lingkungan

`config/database.php` membaca `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, dan `DB_PASSWORD` jika ada. Jika tidak ada (Laragon/XAMPP), otomatis memakai bawaan `127.0.0.1:3306`, user `root` tanpa kata sandi. Docker mengisi variabel ini sendiri (lihat `docker-compose.yml`), sehingga file ini tidak perlu diubah.
