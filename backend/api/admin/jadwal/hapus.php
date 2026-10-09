<?php
/**
 * POST /api/admin/jadwal/hapus.php      (KHUSUS ADMIN)
 * Body JSON: { "id_jadwal": 5 }
 */
require_once __DIR__ . '/../../../core/bootstrap.php';

wajib_method('POST');
wajib_login('admin');

$input    = ambil_input();
$idJadwal = (int) ($input['id_jadwal'] ?? 0);

$stmt = db()->prepare('DELETE FROM jadwal_mengajar WHERE id_jadwal = ?');
$stmt->execute([$idJadwal]);

if ($stmt->rowCount() === 0) {
    kirim_json(404, false, 'Jadwal tidak ditemukan atau sudah dihapus.');
}
kirim_json(200, true, 'Jadwal berhasil dihapus.', ['id_jadwal' => $idJadwal]);
