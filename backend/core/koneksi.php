<?php
/**
 * Koneksi ke database MySQL menggunakan PDO.
 * Panggil db() di mana saja untuk mendapatkan koneksi yang sama.
 */
function db()
{
    static $pdo = null;

    if ($pdo === null) {
        $c   = require __DIR__ . '/../config/database.php';
        $dsn = 'mysql:host=' . $c['host'] . ';port=' . $c['port']
             . ';dbname=' . $c['database'] . ';charset=' . $c['charset'];

        try {
            $pdo = new PDO($dsn, $c['username'], $c['password'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
            // Samakan zona waktu MySQL dengan WIB
            $pdo->exec("SET time_zone = '+07:00'");
        } catch (PDOException $e) {
            error_log((string) $e);
            kirim_json(
                500,
                false,
                'Gagal terhubung ke database. Pastikan MySQL di XAMPP sudah berjalan '
                . 'dan database "' . $c['database'] . '" sudah di-import.'
            );
        }
    }

    return $pdo;
}
