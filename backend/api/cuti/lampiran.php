<?php
/**
 * GET /api/cuti/lampiran.php?id_cuti=5
 * Header: Authorization: Bearer <token>
 *
 * Mengirim foto lampiran pengajuan (mis. surat dokter). Lampiran bersifat
 * pribadi: hanya guru pemilik pengajuan dan admin yang bisa melihatnya.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('GET');
$pengguna = wajib_login();

$stmt = db()->prepare('SELECT id_pengguna, lampiran FROM cuti WHERE id_cuti = ?');
$stmt->execute([(int) ($_GET['id_cuti'] ?? 0)]);
$cuti = $stmt->fetch();

$boleh   = $cuti && ($pengguna['role'] === 'admin' || (int) $cuti['id_pengguna'] === (int) $pengguna['id_pengguna']);
$relatif = $boleh ? $cuti['lampiran'] : null;
if ($relatif === null) {
    kirim_json(404, false, 'Lampiran tidak ditemukan.');
}

$folder = realpath(__DIR__ . '/../../uploads/cuti');
$lokasi = realpath(__DIR__ . '/../../uploads/' . $relatif);
if ($folder === false || $lokasi === false || strpos($lokasi, $folder . DIRECTORY_SEPARATOR) !== 0) {
    kirim_json(404, false, 'File lampiran tidak ditemukan di server.');
}

$info = @getimagesize($lokasi);
header('Content-Type: ' . ($info['mime'] ?? 'application/octet-stream'));
header('Content-Length: ' . filesize($lokasi));
header('Cache-Control: private, max-age=86400');
header('X-Content-Type-Options: nosniff');
readfile($lokasi);
