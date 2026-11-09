<?php
/**
 * POST /api/admin/pengaturan/simpan_absen.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * {
 *   "lokasi_lat": -6.1234567, "lokasi_lng": 107.0123456,   (null = tanpa cek lokasi)
 *   "radius_absen": 100,              (meter, 20-5000)
 *   "toleransi_terlambat": 15,        (menit, 0-180)
 *   "jam_kerja": [
 *     {"unit": "KB", "jam_masuk": "07:00", "jam_pulang": "13:00"},
 *     {"unit": "TK", "jam_masuk": "07:00", "jam_pulang": "13:00"},
 *     {"unit": "SD", "jam_masuk": "07:00", "jam_pulang": "14:00"}
 *   ]
 * }
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/absen.php';

wajib_method('POST');
wajib_login('admin');

$input     = ambil_input();
$kesalahan = [];

// ---------- Lokasi sekolah ----------
$latTeks = input_teks($input, 'lokasi_lat');
$lngTeks = input_teks($input, 'lokasi_lng');
$lat     = null;
$lng     = null;
if ($latTeks !== '' || $lngTeks !== '') {
    $lat = filter_var($latTeks, FILTER_VALIDATE_FLOAT);
    $lng = filter_var($lngTeks, FILTER_VALIDATE_FLOAT);
    if ($lat === false || abs($lat) > 90) {
        $kesalahan['lokasi_lat'] = 'Latitude harus angka antara -90 dan 90.';
    }
    if ($lng === false || abs($lng) > 180) {
        $kesalahan['lokasi_lng'] = 'Longitude harus angka antara -180 dan 180.';
    }
}

$radius = filter_var($input['radius_absen'] ?? null, FILTER_VALIDATE_INT);
if ($radius === false || $radius < 20 || $radius > 5000) {
    $kesalahan['radius_absen'] = 'Radius absen 20 sampai 5000 meter.';
}
$toleransi = filter_var($input['toleransi_terlambat'] ?? null, FILTER_VALIDATE_INT);
if ($toleransi === false || $toleransi < 0 || $toleransi > 180) {
    $kesalahan['toleransi_terlambat'] = 'Toleransi terlambat 0 sampai 180 menit.';
}

// ---------- Jam kerja per unit ----------
$polaJam  = '/^([01]\d|2[0-3]):[0-5]\d$/';
$jamKerja = [];
foreach (is_array($input['jam_kerja'] ?? null) ? $input['jam_kerja'] : [] as $baris) {
    if (!is_array($baris)) {
        continue;
    }
    $unit   = strtoupper(input_teks($baris, 'unit'));
    $masuk  = input_teks($baris, 'jam_masuk');
    $pulang = input_teks($baris, 'jam_pulang');
    if (!in_array($unit, ['KB', 'TK', 'SD'], true)) {
        continue;
    }
    if (!preg_match($polaJam, $masuk) || !preg_match($polaJam, $pulang)) {
        $kesalahan['jam_kerja_' . $unit] = 'Jam kerja ' . $unit . ' tidak valid (format JJ:MM).';
    } elseif ($pulang <= $masuk) {
        $kesalahan['jam_kerja_' . $unit] = 'Jam pulang ' . $unit . ' harus setelah jam masuk.';
    }
    $jamKerja[$unit] = [$masuk, $pulang];
}
foreach (['KB', 'TK', 'SD'] as $unit) {
    if (!isset($jamKerja[$unit]) && !isset($kesalahan['jam_kerja_' . $unit])) {
        $kesalahan['jam_kerja_' . $unit] = 'Jam kerja unit ' . $unit . ' wajib diisi.';
    }
}

if (!empty($kesalahan)) {
    kirim_json(422, false, reset($kesalahan), ['kesalahan' => $kesalahan]);
}

// ---------- Simpan ----------
$pdo = db();
$pdo->beginTransaction();
$pdo->prepare(
    'UPDATE pengaturan SET lokasi_lat = ?, lokasi_lng = ?, radius_absen = ?, toleransi_terlambat = ?
      WHERE id_pengaturan = 1'
)->execute([$lat, $lng, $radius, $toleransi]);

$simpanJam = $pdo->prepare(
    'INSERT INTO jam_kerja_unit (unit, jam_masuk, jam_pulang) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE jam_masuk = VALUES(jam_masuk), jam_pulang = VALUES(jam_pulang)'
);
foreach ($jamKerja as $unit => $jam) {
    $simpanJam->execute([$unit, $jam[0] . ':00', $jam[1] . ':00']);
}
$pdo->commit();

kirim_json(200, true, 'Pengaturan absen disimpan.', data_pengaturan_absen_admin());
