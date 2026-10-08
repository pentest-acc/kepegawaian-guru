<?php
/**
 * POST /api/auth/logout.php
 * Header: Authorization: Bearer <token>
 *
 * Menghapus token di perangkat ini sehingga tidak bisa dipakai lagi.
 */
require_once __DIR__ . '/../../core/bootstrap.php';

wajib_method('POST');

hapus_token_request();

kirim_json(200, true, 'Anda berhasil keluar.');
