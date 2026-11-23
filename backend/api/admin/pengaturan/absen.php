<?php
/**
 * GET /api/admin/pengaturan/absen.php   (khusus admin)
 * Header: Authorization: Bearer <token>
 *
 * Pengaturan absen: toleransi terlambat, jam buka absen sebelum mapel,
 * dan jumlah lokasi absen aktif (lokasinya sendiri ada di admin/lokasi/).
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/absen.php';

wajib_method('GET');
wajib_login('admin');

kirim_json(200, true, 'Pengaturan absen.', data_pengaturan_absen_admin());
