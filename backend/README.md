# Backend API (PHP + MySQL)

API sederhana tanpa framework: **satu file PHP = satu endpoint**. Aplikasi Flutter memanggil API ini lewat HTTP dan menerima jawaban berformat JSON.

## Struktur folder

```
backend/
├── .htaccess          # meneruskan header Authorization ke PHP (penting di XAMPP)
├── config/
│   ├── app.php        # zona waktu, masa berlaku token, tampilkan error
│   └── database.php   # host, nama database, user, password MySQL
├── core/              # fungsi bantu yang dipakai semua endpoint
│   ├── bootstrap.php  # header JSON + CORS, penanganan error
│   ├── koneksi.php    # koneksi PDO ke MySQL -> db()
│   ├── respon.php     # kirim_json(), ambil_input(), dll.
│   └── auth.php       # buat token, cek login (wajib_login), dll.
└── api/
    ├── index.php      # cek API & database
    └── auth/
        ├── login.php
        ├── register.php
        ├── profil.php
        └── logout.php
```

## Format jawaban

Semua endpoint menjawab dengan format yang sama:

```json
{ "sukses": true, "pesan": "Login berhasil.", "data": { ... } }
```

Jika gagal, `sukses` bernilai `false`, `pesan` berisi alasan yang siap ditampilkan, dan kode HTTP-nya 4xx/5xx.

## Daftar endpoint (Sesi 1)

Alamat dasar (XAMPP): `http://localhost/kepegawaian-guru/backend/api`

| Method | Endpoint | Login? | Keterangan |
|---|---|---|---|
| GET | `/` | Tidak | Cek API & koneksi database |
| POST | `/auth/login.php` | Tidak | Login pakai email **atau** nomor induk |
| POST | `/auth/register.php` | Tidak | Daftar akun guru baru |
| GET | `/auth/profil.php` | Ya | Cek token masih berlaku + data pengguna terbaru |
| POST | `/auth/logout.php` | Ya | Hapus token perangkat ini |

Endpoint yang butuh login wajib mengirim header:

```
Authorization: Bearer <token dari login>
```

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

Kode gagal: `422` isian kosong, `401` email/NIY atau kata sandi salah, `403` akun nonaktif.

### POST `/auth/register.php`

```json
{
  "nama_lengkap": "Siti Aminah, S.Pd.",
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
- `422` isian tidak valid; `data.kesalahan` berisi pesan per kolom.
- `409` email atau nomor induk sudah terdaftar.

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
- Saat sudah di hosting: ubah `tampilkan_error` menjadi `false` di `config/app.php` dan pakai user database selain `root`.
