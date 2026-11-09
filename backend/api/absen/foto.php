<?php
/**
 * GET /api/absen/foto.php?id_absensi=5&jenis=masuk
 * Header: Authorization: Bearer <token>
 *
 * Mengirim file foto absen (masuk/pulang). Foto bersifat pribadi, jadi
 * folder uploads/absen tidak bisa dibuka langsung; hanya guru pemilik
 * absensi dan admin yang bisa melihat fotonya lewat endpoint ini.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/absen.php';

wajib_method('GET');
$pengguna = wajib_login();

$idAbsensi = (int) ($_GET['id_absensi'] ?? 0);
$jenis     = (string) ($_GET['jenis'] ?? 'masuk');
if (!in_array($jenis, ['masuk', 'pulang'], true)) {
    kirim_json(422, false, 'Jenis foto harus "masuk" atau "pulang".');
}

$stmt = db()->prepare('SELECT id_pengguna, foto_masuk, foto_pulang FROM absensi WHERE id_absensi = ?');
$stmt->execute([$idAbsensi]);
$absensi = $stmt->fetch();

// Guru hanya boleh melihat fotonya sendiri
$boleh = $absensi && ($pengguna['role'] === 'admin' || (int) $absensi['id_pengguna'] === (int) $pengguna['id_pengguna']);
$relatif = $boleh ? $absensi['foto_' . $jenis] : null;
if ($relatif === null) {
    kirim_json(404, false, 'Foto absen tidak ditemukan.');
}

$folderAbsen = realpath(__DIR__ . '/../../uploads/absen');
$lokasi      = realpath(__DIR__ . '/../../uploads/' . $relatif);
if ($folderAbsen === false || $lokasi === false || strpos($lokasi, $folderAbsen . DIRECTORY_SEPARATOR) !== 0) {
    kirim_json(404, false, 'File foto absen tidak ditemukan di server.');
}

$info = @getimagesize($lokasi);
header('Content-Type: ' . ($info['mime'] ?? 'application/octet-stream'));
header('Content-Length: ' . filesize($lokasi));
header('Cache-Control: private, max-age=86400');
header('X-Content-Type-Options: nosniff');
readfile($lokasi);
