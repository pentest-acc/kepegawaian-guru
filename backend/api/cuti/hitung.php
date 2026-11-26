<?php
/**
 * GET /api/cuti/hitung.php?jenis=cuti&tanggal_mulai=2026-12-01&tanggal_selesai=2026-12-03
 * Header: Authorization: Bearer <token>   (khusus guru)
 *
 * Pratinjau sebelum mengajukan: memeriksa aturan (sama dengan ajukan.php),
 * lalu menghitung jumlah hari kerja, mapel yang ditinggalkan setiap hari,
 * dan sisa kuota (untuk cuti). Tidak menyimpan apa pun.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('GET');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

[$jenis, $mulai, $selesai, $hari] = periksa_pengajuan_cuti($idGuru, $_GET);
$mapel = mapel_ditinggalkan($idGuru, $hari);

kirim_json(200, true, count($hari) . ' hari kerja.', [
    'jenis'           => $jenis,
    'tanggal_mulai'   => $mulai,
    'tanggal_selesai' => $selesai,
    'jumlah_hari'     => count($hari),
    'jumlah_mapel'    => jumlah_mapel_ditinggalkan($mapel),
    'hari'            => $mapel,
    'kuota'           => $jenis === 'cuti' ? kuota_cuti($idGuru, substr($mulai, 0, 4)) : null,
    'wajib_lampiran'  => $jenis === 'sakit' && count($hari) >= CUTI_SAKIT_WAJIB_SURAT,
]);
