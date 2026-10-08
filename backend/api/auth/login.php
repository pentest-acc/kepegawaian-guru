<?php
/**
 * POST /api/auth/login.php
 *
 * Body JSON:
 *   { "identitas": "email atau nomor induk", "password": "...", "perangkat": "Android" }
 *
 * Response sukses (200):
 *   { "sukses": true, "pesan": "...", "data": { "token": "...", "pengguna": {...} } }
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

$stmt = db()->prepare('SELECT * FROM pengguna WHERE email = ? OR nomor_induk = ? LIMIT 1');
$stmt->execute([strtolower($identitas), $identitas]);
$pengguna = $stmt->fetch();

// Pesan dibuat sama untuk "akun tidak ada" dan "sandi salah"
// supaya orang lain tidak bisa menebak akun mana yang terdaftar.
if (!$pengguna || !password_verify($password, $pengguna['password'])) {
    kirim_json(401, false, 'Email/Nomor Induk atau kata sandi salah.');
}

if ($pengguna['status'] !== 'aktif') {
    kirim_json(403, false, 'Akun Anda sedang dinonaktifkan. Silakan hubungi admin.');
}

// Perbarui hash jika algoritma bawaan PHP berubah (aman dan otomatis)
if (password_needs_rehash($pengguna['password'], PASSWORD_DEFAULT)) {
    $ubah = db()->prepare('UPDATE pengguna SET password = ? WHERE id_pengguna = ?');
    $ubah->execute([password_hash($password, PASSWORD_DEFAULT), $pengguna['id_pengguna']]);
}

// Bersihkan token lama yang sudah kedaluwarsa
db()->exec('DELETE FROM token_login WHERE kedaluwarsa_pada <= NOW()');

$token = buat_token((int) $pengguna['id_pengguna'], $perangkat);

kirim_json(200, true, 'Login berhasil. Selamat datang, ' . $pengguna['nama_lengkap'] . '!', [
    'token'    => $token,
    'pengguna' => data_pengguna_publik($pengguna),
]);
