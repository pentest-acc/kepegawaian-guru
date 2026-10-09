<?php
/**
 * POST /api/auth/login.php
 *
 * Body JSON:
 *   { "identitas": "email atau nomor induk", "password": "...", "perangkat": "Android" }
 *
 * Response sukses (200):
 *   { "sukses": true, "pesan": "...", "data": { "token": "...", "pengguna": {...} } }
 *
 * Pengamanan: setelah 5 kali salah kata sandi (lihat config/app.php),
 * email/NIY tersebut dikunci 15 menit (HTTP 429).
 */
require_once __DIR__ . '/../../core/bootstrap.php';

wajib_method('POST');

$input     = ambil_input();
$identitas = input_teks($input, 'identitas');
$password  = input_sandi($input, 'password');
$perangkat = input_teks($input, 'perangkat');

if ($identitas === '' || $password === '') {
    kirim_json(422, false, 'Email/Nomor Induk dan kata sandi wajib diisi.');
}

// ---------- Cari akun berdasarkan email ATAU nomor induk ----------
$stmt = db()->prepare('SELECT * FROM pengguna WHERE email = ? OR nomor_induk = ? LIMIT 1');
$stmt->execute([strtolower($identitas), $identitas]);
$pengguna = $stmt->fetch();

// Kunci pencatatan gagal login dibuat PER AKUN (bukan per tulisan yang
// diketik), supaya tidak bisa diakali dengan bergantian memakai email & NIY.
$kunciLogin = $pengguna
    ? 'akun:' . $pengguna['id_pengguna']
    : mb_strtolower(mb_substr($identitas, 0, 100));
$maksGagal  = (int) $GLOBALS['config_app']['maks_gagal_login'];
$lamaKunci  = (int) $GLOBALS['config_app']['lama_kunci_menit'];

// ---------- Cek apakah akun sedang dikunci karena terlalu sering salah ----------
$cekGagal = db()->prepare(
    'SELECT COUNT(*) AS jumlah,
            TIMESTAMPDIFF(SECOND, NOW(), DATE_ADD(MIN(waktu), INTERVAL ? MINUTE)) AS sisa_detik
       FROM percobaan_login
      WHERE identitas = ? AND waktu > DATE_SUB(NOW(), INTERVAL ? MINUTE)'
);
$cekGagal->execute([$lamaKunci, $kunciLogin, $lamaKunci]);
$gagal = $cekGagal->fetch();

if ((int) $gagal['jumlah'] >= $maksGagal) {
    $sisaMenit = max(1, (int) ceil(((int) $gagal['sisa_detik']) / 60));
    kirim_json(429, false, 'Terlalu banyak percobaan login yang salah. '
        . 'Demi keamanan, coba lagi dalam ' . $sisaMenit . ' menit.');
}

// ---------- Cocokkan kata sandi ----------
// Pesan dibuat sama untuk "akun tidak ada" dan "sandi salah"
// supaya orang lain tidak bisa menebak akun mana yang terdaftar.
if (!$pengguna || !password_verify($password, $pengguna['password'])) {
    $catat = db()->prepare('INSERT INTO percobaan_login (identitas, alamat_ip) VALUES (?, ?)');
    $catat->execute([$kunciLogin, $_SERVER['REMOTE_ADDR'] ?? null]);

    $sisaPercobaan = $maksGagal - ((int) $gagal['jumlah'] + 1);
    $pesan = 'Email/Nomor Induk atau kata sandi salah.';
    if ($sisaPercobaan <= 0) {
        $pesan .= ' Akun dikunci sementara selama ' . $lamaKunci . ' menit.';
    } elseif ($sisaPercobaan <= 2) {
        $pesan .= ' Sisa ' . $sisaPercobaan . ' kali percobaan sebelum dikunci '
            . $lamaKunci . ' menit.';
    }
    kirim_json(401, false, $pesan);
}

if ($pengguna['status'] !== 'aktif') {
    kirim_json(403, false, 'Akun Anda sedang dinonaktifkan. Silakan hubungi admin.');
}

// Perbarui hash jika algoritma bawaan PHP berubah (aman dan otomatis)
if (password_needs_rehash($pengguna['password'], PASSWORD_DEFAULT)) {
    $ubah = db()->prepare('UPDATE pengguna SET password = ? WHERE id_pengguna = ?');
    $ubah->execute([password_hash($password, PASSWORD_DEFAULT), $pengguna['id_pengguna']]);
}

// Login berhasil: hapus catatan gagal akun ini, bersihkan data lama
$hapusGagal = db()->prepare('DELETE FROM percobaan_login WHERE identitas = ?');
$hapusGagal->execute([$kunciLogin]);
db()->exec('DELETE FROM percobaan_login WHERE waktu < DATE_SUB(NOW(), INTERVAL 1 DAY)');
db()->exec('DELETE FROM token_login WHERE kedaluwarsa_pada <= NOW()');

$token = buat_token((int) $pengguna['id_pengguna'], $perangkat);

kirim_json(200, true, 'Login berhasil. Selamat datang, ' . $pengguna['nama_lengkap'] . '!', [
    'token'    => $token,
    'pengguna' => data_pengguna_publik($pengguna),
]);
