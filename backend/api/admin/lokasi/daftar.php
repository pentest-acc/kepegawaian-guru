<?php
/**
 * GET /api/admin/lokasi/daftar.php   (khusus admin)
 * Header: Authorization: Bearer <token>
 *
 * Semua lokasi absen (aktif & nonaktif), urut dibuat: Lokasi 1, 2, 3, ...
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/absen.php';

wajib_method('GET');
wajib_login('admin');

$lokasi = array_map('data_lokasi_publik', daftar_lokasi_absen());
kirim_json(200, true, count($lokasi) . ' lokasi absen.', ['lokasi' => $lokasi]);
