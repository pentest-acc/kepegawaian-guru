<?php
/**
 * POST /api/auth/register.php
 * Pendaftaran akun baru untuk GURU (akun admin hanya dibuat lewat database/admin).
 *
 * Body JSON:
 *   {
 *     "nama_lengkap": "... (tanpa gelar)", "gelar": "S.Pd." (boleh kosong),
 *     "nomor_induk": "...", "email": "...",
 *     "no_hp": "08...", "unit": "KB|TK|SD", "jenis_kelamin": "L|P",
 *     "password": "...", "konfirmasi_password": "..."
 *   }
 */
require_once __DIR__ . '/../../core/bootstrap.php';

wajib_method('POST');

$input        = ambil_input();
$namaLengkap  = preg_replace('/\s+/', ' ', input_teks($input, 'nama_lengkap'));
$gelar        = preg_replace('/\s+/', ' ', input_teks($input, 'gelar'));
$nomorInduk   = input_teks($input, 'nomor_induk');
$email        = strtolower(input_teks($input, 'email'));
$noHp         = preg_replace('/[\s-]/', '', input_teks($input, 'no_hp'));
$unit         = strtoupper(input_teks($input, 'unit'));
$jenisKelamin = strtoupper(input_teks($input, 'jenis_kelamin'));
$password     = input_sandi($input, 'password');
$konfirmasi   = input_sandi($input, 'konfirmasi_password');

// ---------- Validasi ----------
$kesalahan = [];

if (mb_strlen($namaLengkap) < 3 || mb_strlen($namaLengkap) > 100) {
    $kesalahan['nama_lengkap'] = 'Nama lengkap minimal 3 dan maksimal 100 karakter.';
} elseif (strpos($namaLengkap, ',') !== false) {
    $kesalahan['nama_lengkap'] = 'Tulis nama tanpa gelar. Gelar dipilih di kolom Gelar.';
}
if (!preg_match('/^[A-Za-z., ]{0,30}$/', $gelar)) {
    $kesalahan['gelar'] = 'Gelar tidak valid.';
}
if (!preg_match('/^[0-9A-Za-z.\-]{4,30}$/', $nomorInduk)) {
    $kesalahan['nomor_induk'] = 'Nomor Induk Yayasan 4-30 karakter (angka/huruf).';
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 100) {
    $kesalahan['email'] = 'Format email tidak valid.';
}
if (!preg_match('/^(\+62|62|0)8[0-9]{7,12}$/', $noHp)) {
    $kesalahan['no_hp'] = 'Nomor HP tidak valid. Contoh: 081234567890.';
}
if (!in_array($unit, ['KB', 'TK', 'SD'], true)) {
    $kesalahan['unit'] = 'Pilih unit tempat mengajar (KB, TK, atau SD).';
}
if (!in_array($jenisKelamin, ['L', 'P'], true)) {
    $kesalahan['jenis_kelamin'] = 'Pilih jenis kelamin.';
}
if (strlen($password) < 6) {
    $kesalahan['password'] = 'Kata sandi minimal 6 karakter.';
}
if ($password !== $konfirmasi) {
    $kesalahan['konfirmasi_password'] = 'Konfirmasi kata sandi tidak sama.';
}

if (!empty($kesalahan)) {
    kirim_json(422, false, reset($kesalahan), ['kesalahan' => $kesalahan]);
}

// ---------- Cek data ganda ----------
$cek = db()->prepare('SELECT email, nomor_induk FROM pengguna WHERE email = ? OR nomor_induk = ?');
$cek->execute([$email, $nomorInduk]);
foreach ($cek->fetchAll() as $baris) {
    if (strcasecmp($baris['email'], $email) === 0) {
        kirim_json(409, false, 'Email sudah terdaftar. Silakan gunakan email lain atau login.');
    }
    if (strcasecmp($baris['nomor_induk'], $nomorInduk) === 0) {
        kirim_json(409, false, 'Nomor Induk Yayasan sudah terdaftar.');
    }
}

// ---------- Simpan ----------
// role selalu 'guru' (tidak diambil dari input supaya tidak bisa daftar sebagai admin)
$simpan = db()->prepare(
    'INSERT INTO pengguna (nomor_induk, nama_lengkap, gelar, email, no_hp, password, role, jabatan, unit, jenis_kelamin)
     VALUES (?, ?, ?, ?, ?, ?, \'guru\', \'Guru\', ?, ?)'
);
$simpan->execute([
    $nomorInduk,
    $namaLengkap,
    $gelar !== '' ? $gelar : null,
    $email,
    $noHp,
    password_hash($password, PASSWORD_DEFAULT),
    $unit,
    $jenisKelamin,
]);

kirim_json(201, true, 'Registrasi berhasil. Silakan login dengan akun baru Anda.', [
    'id_pengguna' => (int) db()->lastInsertId(),
    'email'       => $email,
]);
