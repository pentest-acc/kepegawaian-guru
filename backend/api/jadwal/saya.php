<?php
/**
 * GET /api/jadwal/saya.php?dari=2026-10-12&sampai=2026-10-17
 * Header: Authorization: Bearer <token>
 *
 * Jadwal mengajar mingguan milik guru yang sedang login, beserta daftar
 * hari libur di antara tanggal "dari" dan "sampai" (bawaan: minggu ini,
 * Senin s.d. Sabtu). Aplikasi menggabungkan keduanya: jadwal hari Senin
 * berlaku untuk SETIAP Senin, kecuali Senin itu tercatat sebagai libur.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/jadwal.php';

wajib_method('GET');
$pengguna = wajib_login();

$senin  = date('Y-m-d', strtotime('monday this week'));
$dari   = (string) ($_GET['dari'] ?? $senin);
$sampai = (string) ($_GET['sampai'] ?? date('Y-m-d', strtotime($senin . ' +5 days')));

if (!tanggal_valid($dari) || !tanggal_valid($sampai) || $dari > $sampai) {
    kirim_json(422, false, 'Rentang tanggal tidak valid (format YYYY-MM-DD).');
}
if ((strtotime($sampai) - strtotime($dari)) / 86400 > 62) {
    kirim_json(422, false, 'Rentang tanggal maksimal 2 bulan.');
}

$stmt = db()->prepare('SELECT j.* FROM jadwal_mengajar j WHERE j.id_pengguna = ? ' . SQL_URUT_JADWAL);
$stmt->execute([(int) $pengguna['id_pengguna']]);
$jadwal = array_map('data_jadwal_publik', $stmt->fetchAll());

$libur = db()->prepare('SELECT tanggal, keterangan FROM hari_libur WHERE tanggal BETWEEN ? AND ? ORDER BY tanggal');
$libur->execute([$dari, $sampai]);

kirim_json(200, true, count($jadwal) . ' jadwal mengajar.', [
    'dari'   => $dari,
    'sampai' => $sampai,
    'jadwal' => $jadwal,
    'libur'  => $libur->fetchAll(),
]);
