<?php
/**
 * GET /api/admin/guru.php?cari=siti        (KHUSUS ADMIN)
 *
 * Daftar akun guru beserta jumlah jadwal mengajarnya. Dipakai admin untuk
 * memilih guru yang jadwalnya akan diatur.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/jadwal.php';

wajib_method('GET');
wajib_login('admin');

$cari  = mb_substr(trim((string) ($_GET['cari'] ?? '')), 0, 100);
$sql   = "SELECT p.id_pengguna, p.nomor_induk, p.nama_lengkap, p.gelar, p.unit, p.jabatan, p.status,
                 COUNT(j.id_jadwal) AS jumlah_jadwal
            FROM pengguna p
            LEFT JOIN jadwal_mengajar j ON j.id_pengguna = p.id_pengguna
           WHERE p.role = 'guru'";
$nilai = [];
if ($cari !== '') {
    $pola  = '%' . addcslashes($cari, '%_\\') . '%';
    $sql  .= ' AND (p.nama_lengkap LIKE ? OR p.nomor_induk LIKE ?)';
    $nilai = [$pola, $pola];
}
$sql .= ' GROUP BY p.id_pengguna ORDER BY p.status, p.nama_lengkap';

$stmt = db()->prepare($sql);
$stmt->execute($nilai);

$guru = array_map(function ($b) {
    return [
        'id_pengguna'   => (int) $b['id_pengguna'],
        'nomor_induk'   => $b['nomor_induk'],
        'nama_lengkap'  => $b['nama_lengkap'],
        'gelar'         => $b['gelar'],
        'nama_tampil'   => nama_dengan_gelar($b['nama_lengkap'], $b['gelar']),
        'unit'          => $b['unit'],
        'jabatan'       => $b['jabatan'],
        'status'        => $b['status'],
        'jumlah_jadwal' => (int) $b['jumlah_jadwal'],
    ];
}, $stmt->fetchAll());

kirim_json(200, true, count($guru) . ' guru.', ['guru' => $guru]);
