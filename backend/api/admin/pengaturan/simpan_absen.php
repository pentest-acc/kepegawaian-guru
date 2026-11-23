<?php
/**
 * POST /api/admin/pengaturan/simpan_absen.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * Jam absen setiap guru mengikuti jadwal mengajarnya (per mapel), jadi yang
 * diatur di sini hanya:
 * {
 *   "toleransi_terlambat": 15,   (menit setelah jam mulai mapel, 0-180)
 *   "buka_absen_menit": 30       (absen dibuka sekian menit sebelum jam mulai, 0-180)
 * }
 * Lokasi absen diatur terpisah di admin/lokasi/*.php.
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
$buka = filter_var($input['buka_absen_menit'] ?? null, FILTER_VALIDATE_INT);
if ($buka === false || $buka < 0 || $buka > 180) {
    $kesalahan['buka_absen_menit'] = 'Absen dibuka 0 sampai 180 menit sebelum mapel.';
}
if (!empty($kesalahan)) {
    kirim_json(422, false, reset($kesalahan), ['kesalahan' => $kesalahan]);
}

db()->prepare('UPDATE pengaturan SET toleransi_terlambat = ?, buka_absen_menit = ? WHERE id_pengaturan = 1')
    ->execute([$toleransi, $buka]);

kirim_json(200, true, 'Pengaturan absen disimpan.', data_pengaturan_absen_admin());
