<?php
/**
 * POST /api/admin/lokasi/hapus.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * {"id_lokasi": 2}
 *
 * Riwayat absensi yang pernah memakai lokasi ini tetap ada (jaraknya tetap
 * tersimpan, hanya nama lokasinya yang kosong). Jika hanya ingin menutup
 * lokasi sementara, lebih baik nonaktifkan lewat simpan.php ("aktif": false).
 */
require_once __DIR__ . '/../../../core/bootstrap.php';

wajib_method('POST');
wajib_login('admin');

$input    = ambil_input();
$idLokasi = (int) ($input['id_lokasi'] ?? 0);

$stmt = db()->prepare('DELETE FROM lokasi_absen WHERE id_lokasi = ?');
$stmt->execute([$idLokasi]);
if ($stmt->rowCount() === 0) {
    kirim_json(404, false, 'Lokasi absen tidak ditemukan.');
}

kirim_json(200, true, 'Lokasi absen dihapus.', ['id_lokasi' => $idLokasi]);
