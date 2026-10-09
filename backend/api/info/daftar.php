<?php
/**
 * GET /api/info/daftar.php
 * Header: Authorization: Bearer <token>
 *
 * Parameter (semua opsional):
 *   cari    = kata yang dicari di judul/isi info
 *   penting = 1 -> hanya info yang ditandai bintang oleh pengguna ini
 *   batas   = jumlah maksimal info (1-100, bawaan 100). Beranda memakai batas=5.
 *
 * Urutan: info yang paling baru dibuat tampil paling atas.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/info.php';

wajib_method('GET');
$pengguna = wajib_login();

$cari    = mb_substr(trim((string) ($_GET['cari'] ?? '')), 0, 100);
$penting = ($_GET['penting'] ?? '') === '1';
$batas   = (int) ($_GET['batas'] ?? 100);
$batas   = max(1, min(100, $batas));

$sql   = SQL_INFO_DASAR;
$nilai = [(int) $pengguna['id_pengguna']];

if ($cari !== '') {
    // Tanda % dan _ di-escape supaya dicari sebagai huruf biasa
    $pola  = '%' . addcslashes($cari, '%_\\') . '%';
    $sql  .= ' AND (i.judul LIKE ? OR i.isi LIKE ?)';
    $nilai[] = $pola;
    $nilai[] = $pola;
}
if ($penting) {
    $sql .= ' AND p.id_info IS NOT NULL';
}
$sql .= ' ORDER BY i.dibuat_pada DESC, i.id_info DESC LIMIT ' . $batas;

$stmt = db()->prepare($sql);
$stmt->execute($nilai);
$daftar = array_map('data_info_publik', $stmt->fetchAll());

kirim_json(200, true, count($daftar) . ' info ditemukan.', [
    'info'   => $daftar,
    'jumlah' => count($daftar),
]);
