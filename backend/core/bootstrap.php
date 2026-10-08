<?php
/**
 * File ini di-require oleh SETIAP endpoint API.
 * Tugasnya: menyiapkan header JSON + CORS, zona waktu, penanganan error,
 * dan memuat fungsi-fungsi bantu (respon, koneksi database, autentikasi).
 */

$GLOBALS['config_app'] = require __DIR__ . '/../config/app.php';

date_default_timezone_set($GLOBALS['config_app']['timezone']);
ini_set('display_errors', '0');
error_reporting(E_ALL);

require_once __DIR__ . '/respon.php';
require_once __DIR__ . '/koneksi.php';
require_once __DIR__ . '/auth.php';

// CORS: agar aplikasi Flutter versi web (yang berjalan di port berbeda)
// tetap boleh memanggil API ini.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json; charset=utf-8');

// Browser selalu mengirim request OPTIONS (preflight) sebelum request asli.
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Semua error yang tidak tertangkap dikembalikan dalam format JSON.
set_exception_handler(function ($e) {
    error_log((string) $e);
    $pesan = $GLOBALS['config_app']['tampilkan_error']
        ? 'Kesalahan server: ' . $e->getMessage()
        : 'Terjadi kesalahan pada server. Silakan coba lagi.';
    kirim_json(500, false, $pesan);
});

set_error_handler(function ($level, $pesan, $file, $baris) {
    if (!(error_reporting() & $level)) {
        return false;
    }
    throw new ErrorException($pesan, 0, $level, $file, $baris);
});
