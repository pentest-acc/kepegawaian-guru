<?php
/**
 * Fungsi bantu autentikasi berbasis token.
 *
 * Alur singkat:
 *  1. Saat login berhasil, server membuat token acak lalu mengirimkannya
 *     ke aplikasi. Yang disimpan di database hanya hash SHA-256 token itu.
 *  2. Aplikasi menyimpan token, lalu mengirimkannya di setiap request:
 *        Authorization: Bearer <token>
 *  3. Endpoint yang butuh login memanggil wajib_login() untuk mengecek token.
 */

/**
 * Buat token login baru untuk pengguna dan simpan hash-nya ke database.
 */
function buat_token($idPengguna, $perangkat)
{
    $token   = bin2hex(random_bytes(32));
    $berlaku = (int) $GLOBALS['config_app']['token_berlaku_hari'];

    $stmt = db()->prepare(
        'INSERT INTO token_login (id_pengguna, token_hash, perangkat, kedaluwarsa_pada)
         VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))'
    );
    $stmt->execute([
        $idPengguna,
        hash('sha256', $token),
        mb_substr($perangkat !== '' ? $perangkat : 'Tidak diketahui', 0, 100),
        $berlaku,
    ]);

    return $token;
}

/**
 * Ambil token dari header "Authorization: Bearer <token>".
 * Apache (Laragon/XAMPP) kadang membuang header Authorization, jadi dicek dari
 * beberapa tempat sekaligus.
 */
function ambil_token_request()
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';

    if ($header === '' && function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $nama => $nilai) {
            if (strtolower($nama) === 'authorization') {
                $header = $nilai;
                break;
            }
        }
    }

    if (preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($header), $cocok)) {
        return strtolower($cocok[1]);
    }
    return null;
}

/**
 * Pastikan request berasal dari pengguna yang sudah login.
 * Mengembalikan data pengguna (array) jika token valid.
 *
 * @param string|null $role isi 'guru' atau 'admin' jika endpoint khusus role tertentu
 */
function wajib_login($role = null)
{
    $token = ambil_token_request();
    if ($token === null) {
        kirim_json(401, false, 'Sesi login tidak ditemukan. Silakan login kembali.');
    }

    $stmt = db()->prepare(
        'SELECT p.*
           FROM token_login t
           JOIN pengguna p ON p.id_pengguna = t.id_pengguna
          WHERE t.token_hash = ? AND t.kedaluwarsa_pada > NOW()
          LIMIT 1'
    );
    $stmt->execute([hash('sha256', $token)]);
    $pengguna = $stmt->fetch();

    if (!$pengguna) {
        kirim_json(401, false, 'Sesi login sudah berakhir. Silakan login kembali.');
    }
    if ($pengguna['status'] !== 'aktif') {
        kirim_json(403, false, 'Akun Anda sedang dinonaktifkan. Silakan hubungi admin.');
    }
    if ($role !== null && $pengguna['role'] !== $role) {
        kirim_json(403, false, 'Anda tidak memiliki akses ke fitur ini.');
    }

    return $pengguna;
}

/**
 * Hapus token yang sedang dipakai (logout dari perangkat ini).
 */
function hapus_token_request()
{
    $token = ambil_token_request();
    if ($token !== null) {
        $stmt = db()->prepare('DELETE FROM token_login WHERE token_hash = ?');
        $stmt->execute([hash('sha256', $token)]);
    }
}

/**
 * Ubah baris tabel pengguna menjadi data yang aman dikirim ke aplikasi
 * (tanpa kolom password).
 */
function data_pengguna_publik(array $p)
{
    return [
        'id_pengguna'      => (int) $p['id_pengguna'],
        'nomor_induk'      => $p['nomor_induk'],
        'nama_lengkap'     => $p['nama_lengkap'],
        'gelar'            => $p['gelar'],
        'email'            => $p['email'],
        'no_hp'            => $p['no_hp'],
        'role'             => $p['role'],
        'jabatan'          => $p['jabatan'],
        'unit'             => $p['unit'],
        'jenis_kelamin'    => $p['jenis_kelamin'],
        'tempat_lahir'     => $p['tempat_lahir'],
        'tanggal_lahir'    => $p['tanggal_lahir'],
        'alamat'           => $p['alamat'],
        'foto'             => $p['foto'],
        'notifikasi_aktif' => (bool) $p['notifikasi_aktif'],
        'status'           => $p['status'],
    ];
}
