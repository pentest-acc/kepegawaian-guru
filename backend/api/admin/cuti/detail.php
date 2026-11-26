<?php
/**
 * GET /api/admin/cuti/detail.php?id_cuti=5   (khusus admin)
 * Header: Authorization: Bearer <token>
 *
 * Detail satu pengajuan untuk dipertimbangkan admin:
 * - data pengajuan + guru,
 * - mapel yang ditinggalkan setiap hari (agar bisa mencari guru pengganti),
 * - kuota cuti guru pada tahun itu (tanpa menghitung pengajuan ini),
 * - pengajuan lain yang sudah disetujui dan tanggalnya bertumpuk (jika ada).
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/cuti.php';

wajib_method('GET');
wajib_login('admin');

$cuti = cuti_by_id((int) ($_GET['id_cuti'] ?? 0));
if (!$cuti) {
    kirim_json(404, false, 'Pengajuan tidak ditemukan.');
}

$idGuru = (int) $cuti['id_pengguna'];
$hari   = mapel_ditinggalkan($idGuru, hari_kerja_cuti($cuti['tanggal_mulai'], $cuti['tanggal_selesai']));
$tumpuk = cuti_bertumpuk($idGuru, $cuti['tanggal_mulai'], $cuti['tanggal_selesai'], $cuti['id_cuti'], true);

kirim_json(200, true, 'Detail pengajuan.', [
    'cuti'         => data_cuti_publik($cuti),
    'hari'         => $hari,
    'jumlah_mapel' => jumlah_mapel_ditinggalkan($hari),
    'kuota'        => kuota_cuti($idGuru, substr($cuti['tanggal_mulai'], 0, 4), $cuti['id_cuti']),
    'bertumpuk'    => $tumpuk ? [
        'jenis'           => $tumpuk['jenis'],
        'tanggal_mulai'   => $tumpuk['tanggal_mulai'],
        'tanggal_selesai' => $tumpuk['tanggal_selesai'],
    ] : null,
]);
