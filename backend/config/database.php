<?php
/**
 * Konfigurasi koneksi database MySQL.
 *
 * Nilai default di bawah ini sudah cocok untuk Laragon maupun XAMPP
 * (user "root" tanpa kata sandi, port 3306). Saat aplikasi dipindah ke hosting,
 * cukup ganti nilai-nilai di file ini.
 */
return [
    'host'     => '127.0.0.1',
    'port'     => 3306,
    'database' => 'db_kepegawaian_guru',
    'username' => 'root',
    'password' => '',
    'charset'  => 'utf8mb4',
];
