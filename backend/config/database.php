<?php
/**
 * Konfigurasi koneksi database MySQL.
 *
 * Nilai bawaan di bawah ini sudah cocok untuk Laragon maupun XAMPP
 * (user "root" tanpa kata sandi, port 3306).
 *
 * Saat dijalankan dengan Docker (atau di hosting), nilai bisa diatur lewat
 * environment variable DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
 * tanpa perlu mengubah file ini.
 */
return [
    'host'     => getenv('DB_HOST') ?: '127.0.0.1',
    'port'     => (int) (getenv('DB_PORT') ?: 3306),
    'database' => getenv('DB_NAME') ?: 'db_kepegawaian_guru',
    'username' => getenv('DB_USER') ?: 'root',
    'password' => getenv('DB_PASSWORD') !== false ? getenv('DB_PASSWORD') : '',
    'charset'  => 'utf8mb4',
];
