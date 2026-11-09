<?php
/**
 * GET /api/absen/hari_ini.php
 * Header: Authorization: Bearer <token>   (khusus guru)
 *
 * Semua yang dibutuhkan halaman Absen: tanggal & jam server, status libur,
 * jam kerja unit guru, jam tombol absen pulang muncul, titik lokasi sekolah,
 * dan absensi guru hari ini (null jika belum absen).
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/absen.php';

wajib_method('GET');
$pengguna = wajib_login('guru');

$sekarang   = time();
$tanggal    = date('Y-m-d', $sekarang);
$jamKerja   = jam_kerja_unit($pengguna['unit']);
$pengaturan = pengaturan_absen();
$absensi    = absensi_guru($pengguna['id_pengguna'], $tanggal);

kirim_json(200, true, 'Data absen hari ini.', [
    'tanggal'      => $tanggal,
    'hari'         => NAMA_HARI[(int) date('N', $sekarang)],
    'waktu_server' => date('Y-m-d H:i:s', $sekarang),
    'libur'        => info_libur($tanggal),
    'jam_kerja'    => [
        'unit'            => $jamKerja['unit'],
        'jam_masuk'       => jam_pendek($jamKerja['jam_masuk']),
        'jam_pulang'      => jam_pendek($jamKerja['jam_pulang']),
        'toleransi_menit' => (int) $pengaturan['toleransi_terlambat'],
    ],
    'absen_masuk_mulai'  => $GLOBALS['config_app']['absen_masuk_mulai'],
    'absen_pulang_mulai' => jam_pendek(jam_buka_absen_pulang()),
    'lokasi_sekolah'     => lokasi_sekolah_publik($pengaturan),
    'absensi'            => $absensi ? data_absensi_publik($absensi) : null,
]);
