<?php
/**
 * GET /api/auth/profil.php
 * Header: Authorization: Bearer <token>
 *
 * Dipakai splash screen untuk mengecek apakah token masih berlaku,
 * sekaligus mengambil data pengguna terbaru.
 */
require_once __DIR__ . '/../../core/bootstrap.php';

wajib_method('GET');

$pengguna = wajib_login();

kirim_json(200, true, 'Sesi masih berlaku.', [
    'pengguna' => data_pengguna_publik($pengguna),
]);
