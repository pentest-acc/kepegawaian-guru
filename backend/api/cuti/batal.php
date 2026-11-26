<?php
/**
 * POST /api/cuti/batal.php   (khusus guru, body JSON)
 * Header: Authorization: Bearer <token>
 * { "id_cuti": 5 }
 *
 * Membatalkan (menghapus) pengajuan milik sendiri yang MASIH MENUNGGU.
 * Pengajuan yang sudah disetujui / ditolak admin tidak bisa dibatalkan.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('POST');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];
$input    = ambil_input();

$stmt = db()->prepare('SELECT * FROM cuti WHERE id_cuti = ? AND id_pengguna = ?');
$stmt->execute([(int) ($input['id_cuti'] ?? 0), $idGuru]);
$cuti = $stmt->fetch();
if (!$cuti) {
    kirim_json(404, false, 'Pengajuan tidak ditemukan.');
}
if ($cuti['status'] !== 'menunggu') {
    kirim_json(409, false, 'Pengajuan yang sudah ' . $cuti['status'] . ' tidak bisa dibatalkan.');
}

db()->prepare("DELETE FROM cuti WHERE id_cuti = ? AND status = 'menunggu'")->execute([$cuti['id_cuti']]);
hapus_lampiran_cuti($cuti['lampiran']);

kirim_json(200, true, 'Pengajuan ' . strtolower(label_jenis_cuti($cuti['jenis'])) . ' dibatalkan.', [
    'kuota' => kuota_cuti($idGuru, date('Y')),
]);
