<?php
/**
 * POST /api/admin/pengaturan/simpan_absen.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * Lokasi absen diatur terpisah di admin/lokasi/*.php (bisa banyak lokasi).
 *
 * {
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
$pdo->prepare('UPDATE pengaturan SET toleransi_terlambat = ? WHERE id_pengaturan = 1')
    ->execute([$toleransi]);

$simpanJam = $pdo->prepare(
    'INSERT INTO jam_kerja_unit (unit, jam_masuk, jam_pulang) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE jam_masuk = VALUES(jam_masuk), jam_pulang = VALUES(jam_pulang)'
);
foreach ($jamKerja as $unit => $jam) {
    $simpanJam->execute([$unit, $jam[0] . ':00', $jam[1] . ':00']);
}
$pdo->commit();

kirim_json(200, true, 'Pengaturan absen disimpan.', data_pengaturan_absen_admin());
