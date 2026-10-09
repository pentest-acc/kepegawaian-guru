<?php
/**
 * GET /api/admin/jadwal/daftar.php?id_pengguna=2      (KHUSUS ADMIN)
 *
 * Seluruh jadwal mingguan seorang guru.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/jadwal.php';

wajib_method('GET');
wajib_login('admin');

$idGuru = (int) ($_GET['id_pengguna'] ?? 0);
$cek = db()->prepare("SELECT id_pengguna FROM pengguna WHERE id_pengguna = ? AND role = 'guru'");
$cek->execute([$idGuru]);
if (!$cek->fetch()) {
    kirim_json(404, false, 'Guru tidak ditemukan.');
}

$stmt = db()->prepare('SELECT j.* FROM jadwal_mengajar j WHERE j.id_pengguna = ? ' . SQL_URUT_JADWAL);
$stmt->execute([$idGuru]);

kirim_json(200, true, 'Jadwal mengajar guru.', [
    'jadwal' => array_map('data_jadwal_publik', $stmt->fetchAll()),
]);
