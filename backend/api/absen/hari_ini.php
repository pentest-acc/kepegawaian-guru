<?php
/**
 * GET /api/absen/hari_ini.php
 * Header: Authorization: Bearer <token>   (khusus guru)
 *
 * Semua yang dibutuhkan halaman Absen: tanggal & jam server, status libur,
 * aturan absen (toleransi terlambat, jam buka absen), daftar lokasi absen
 * yang aktif, dan DAFTAR MAPEL guru hari ini beserta absensinya masing-masing.
 * Setiap mapel = satu kali absen.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/jadwal.php';
require_once __DIR__ . '/../../core/absen.php';

wajib_method('GET');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

$sekarang   = time();
$tanggal    = date('Y-m-d', $sekarang);
$hari       = NAMA_HARI[(int) date('N', $sekarang)];
$pengaturan = pengaturan_absen();

$jadwal = db()->prepare(SQL_JADWAL . ' WHERE j.id_pengguna = ? AND j.hari = ? ORDER BY j.jam_mulai');
$jadwal->execute([$idGuru, $hari]);

$absensi = db()->prepare(SQL_ABSENSI . ' WHERE a.id_pengguna = ? AND a.tanggal = ?');
$absensi->execute([$idGuru, $tanggal]);

kirim_json(200, true, 'Data absen hari ini.', [
    'tanggal'          => $tanggal,
    'hari'             => $hari,
    'waktu_server'     => date('Y-m-d H:i:s', $sekarang),
    'libur'            => info_libur($tanggal),
    'toleransi_menit'  => (int) $pengaturan['toleransi_terlambat'],
    'buka_absen_menit' => (int) $pengaturan['buka_absen_menit'],
    'lokasi_absen'     => array_map('data_lokasi_publik', daftar_lokasi_absen(true)),
    'mapel'            => gabung_jadwal_absensi($jadwal->fetchAll(), $absensi->fetchAll()),
]);
