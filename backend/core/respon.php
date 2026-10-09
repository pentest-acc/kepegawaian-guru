<?php
/**
 * Fungsi bantu untuk membaca request dan mengirim response JSON.
 *
 * Semua response API memakai format yang sama:
 *   { "sukses": true/false, "pesan": "....", "data": {...} }
 */

/**
 * Kirim response JSON lalu hentikan script.
 */
function kirim_json($kodeHttp, $sukses, $pesan, $data = null)
{
    http_response_code($kodeHttp);

    $body = [
        'sukses' => (bool) $sukses,
        'pesan'  => (string) $pesan,
    ];
    if ($data !== null) {
        $body['data'] = $data;
    }

    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/**
 * Pastikan endpoint dipanggil dengan method HTTP yang benar (GET/POST).
 */
function wajib_method($method)
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== $method) {
        kirim_json(405, false, 'Metode tidak diizinkan. Gunakan ' . $method . '.');
    }
}

/**
 * Ambil data yang dikirim aplikasi.
 * Mendukung body JSON (dari Flutter) maupun form biasa ($_POST).
 */
function ambil_input()
{
    $raw  = file_get_contents('php://input');
    $data = json_decode($raw ?: '', true);

    if (!is_array($data)) {
        $data = $_POST;
    }
    return $data;
}

/**
 * Ambil satu nilai teks dari input dan buang spasi di awal/akhir.
 */
function input_teks(array $input, $kunci)
{
    $nilai = $input[$kunci] ?? '';
    return is_scalar($nilai) ? trim((string) $nilai) : '';
}

/**
 * Alamat dasar folder backend, mis. http://192.168.1.7/kepegawaian-guru/backend
 * Dipakai untuk membuat link file (lampiran, foto) yang bisa dibuka aplikasi.
 */
function url_backend()
{
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
    $host  = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $skrip = $_SERVER['SCRIPT_NAME'] ?? '';
    $posisi = strpos($skrip, '/api/');
    $folder = $posisi === false ? '' : substr($skrip, 0, $posisi);

    return ($https ? 'https' : 'http') . '://' . $host . $folder;
}

/**
 * Ambil kata sandi dari input apa adanya (tanpa trim, karena spasi
 * bisa jadi bagian dari kata sandi).
 */
function input_sandi(array $input, $kunci)
{
    $nilai = $input[$kunci] ?? '';
    return is_scalar($nilai) ? (string) $nilai : '';
}
