<?php
/**
 * GET /api/
 * Cek cepat apakah backend & database sudah berjalan.
 * Buka di browser: http://localhost/kepegawaian-guru/backend/api/
 */
require_once __DIR__ . '/../core/bootstrap.php';

$jumlahPengguna = (int) db()->query('SELECT COUNT(*) FROM pengguna')->fetchColumn();

kirim_json(200, true, 'API Kepegawaian Guru berjalan dengan baik.', [
    'aplikasi'        => 'Sistem Informasi Kepegawaian Guru - Yayasan Tiara Harapan Jaya',
    'versi_api'       => '0.1.0',
    'waktu_server'    => date('Y-m-d H:i:s'),
    'database'        => 'terhubung',
    'jumlah_pengguna' => $jumlahPengguna,
]);
