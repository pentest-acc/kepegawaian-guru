<?php
/**
 * POST /api/info/tandai.php
 * Header: Authorization: Bearer <token>
 * Body JSON: { "id_info": 1, "penting": true }
 *
 * Menandai (bintang) atau melepas tanda "penting" pada sebuah info.
 * Tanda ini milik masing-masing guru, tidak terlihat oleh guru lain.
 */
require_once __DIR__ . '/../../core/bootstrap.php';

wajib_method('POST');
$pengguna = wajib_login();

$input   = ambil_input();
$idInfo  = (int) ($input['id_info'] ?? 0);
$penting = filter_var($input['penting'] ?? false, FILTER_VALIDATE_BOOLEAN);

$cek = db()->prepare('SELECT id_info FROM info_kegiatan WHERE id_info = ? AND status = \'terbit\'');
$cek->execute([$idInfo]);
if (!$cek->fetch()) {
    kirim_json(404, false, 'Info kegiatan tidak ditemukan atau sudah dihapus.');
}

if ($penting) {
    $stmt = db()->prepare('INSERT IGNORE INTO info_penting (id_pengguna, id_info) VALUES (?, ?)');
} else {
    $stmt = db()->prepare('DELETE FROM info_penting WHERE id_pengguna = ? AND id_info = ?');
}
$stmt->execute([(int) $pengguna['id_pengguna'], $idInfo]);

kirim_json(200, true, $penting ? 'Ditandai sebagai penting.' : 'Tanda penting dihapus.', [
    'id_info' => $idInfo,
    'penting' => $penting,
]);
