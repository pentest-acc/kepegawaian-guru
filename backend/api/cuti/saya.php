<?php
/**
 * GET /api/cuti/saya.php?tahun=2026   (khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Kuota cuti guru pada tahun itu (bawaan tahun ini) dan semua pengajuan
 * cuti / izin / sakit miliknya (terbaru di atas).
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('GET');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

$tahun = (int) ($_GET['tahun'] ?? date('Y'));
if ($tahun < 2000 || $tahun > 2100) {
    kirim_json(422, false, 'Tahun tidak valid.');
}

$stmt = db()->prepare(SQL_CUTI . ' WHERE c.id_pengguna = ? ORDER BY c.tanggal_mulai DESC, c.id_cuti DESC LIMIT 200');
$stmt->execute([$idGuru]);

kirim_json(200, true, 'Daftar pengajuan cuti/izin.', [
    'hari_ini'  => date('Y-m-d'),
    'kuota'     => kuota_cuti($idGuru, $tahun),
    'pengajuan' => array_map('data_cuti_publik', $stmt->fetchAll()),
]);
