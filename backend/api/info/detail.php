<?php
/**
 * GET /api/info/detail.php?id=<id_info>
 * Header: Authorization: Bearer <token>
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/info.php';

wajib_method('GET');
$pengguna = wajib_login();

$idInfo = (int) ($_GET['id'] ?? 0);

$stmt = db()->prepare(SQL_INFO_DASAR . ' AND i.id_info = ? LIMIT 1');
$stmt->execute([(int) $pengguna['id_pengguna'], $idInfo]);
$info = $stmt->fetch();

if (!$info) {
    kirim_json(404, false, 'Info kegiatan tidak ditemukan atau sudah dihapus.');
}

kirim_json(200, true, 'Detail info kegiatan.', ['info' => data_info_publik($info)]);
