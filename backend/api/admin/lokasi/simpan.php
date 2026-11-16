<?php
/**
 * POST /api/admin/lokasi/simpan.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * Tambah lokasi absen baru, atau ubah jika mengirim "id_lokasi".
 * {
 *   "id_lokasi": 2,             (opsional, untuk mengubah)
 *   "nama": "Gedung SD",
 *   "lat": -6.1702113, "lng": 107.0251456,
 *   "radius": 100,              (meter, 20-5000)
 *   "aktif": true
 * }
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/absen.php';

wajib_method('POST');
wajib_login('admin');

const MAKS_LOKASI = 20;

$input    = ambil_input();
$idLokasi = (int) ($input['id_lokasi'] ?? 0);
$nama     = preg_replace('/\s+/', ' ', input_teks($input, 'nama'));
$lat      = filter_var(input_teks($input, 'lat'), FILTER_VALIDATE_FLOAT);
$lng      = filter_var(input_teks($input, 'lng'), FILTER_VALIDATE_FLOAT);
$radius   = filter_var($input['radius'] ?? null, FILTER_VALIDATE_INT);
$aktif    = !isset($input['aktif']) || filter_var($input['aktif'], FILTER_VALIDATE_BOOLEAN);

// ---------- Validasi ----------
$kesalahan = [];
if (mb_strlen($nama) < 2 || mb_strlen($nama) > 100) {
    $kesalahan['nama'] = 'Nama lokasi 2-100 karakter, contoh: Gedung SD.';
}
if ($lat === false || abs($lat) > 90 || $lng === false || abs($lng) > 180) {
    $kesalahan['koordinat'] = 'Koordinat tidak valid. Latitude -90 s.d. 90, longitude -180 s.d. 180.';
}
if ($radius === false || $radius < 20 || $radius > 5000) {
    $kesalahan['radius'] = 'Radius 20 sampai 5000 meter.';
}
if (!empty($kesalahan)) {
    kirim_json(422, false, reset($kesalahan), ['kesalahan' => $kesalahan]);
}

$cekNama = db()->prepare('SELECT id_lokasi FROM lokasi_absen WHERE nama = ? AND id_lokasi <> ?');
$cekNama->execute([$nama, $idLokasi]);
if ($cekNama->fetch()) {
    kirim_json(409, false, 'Nama lokasi "' . $nama . '" sudah dipakai. Gunakan nama lain.');
}

// ---------- Simpan ----------
if ($idLokasi > 0) {
    $ada = db()->prepare('SELECT id_lokasi FROM lokasi_absen WHERE id_lokasi = ?');
    $ada->execute([$idLokasi]);
    if (!$ada->fetch()) {
        kirim_json(404, false, 'Lokasi absen tidak ditemukan.');
    }
    db()->prepare('UPDATE lokasi_absen SET nama = ?, lat = ?, lng = ?, radius = ?, aktif = ? WHERE id_lokasi = ?')
        ->execute([$nama, $lat, $lng, $radius, $aktif ? 1 : 0, $idLokasi]);
    $kode  = 200;
    $pesan = 'Lokasi absen diubah.';
} else {
    $jumlah = (int) db()->query('SELECT COUNT(*) FROM lokasi_absen')->fetchColumn();
    if ($jumlah >= MAKS_LOKASI) {
        kirim_json(422, false, 'Maksimal ' . MAKS_LOKASI . ' lokasi absen.');
    }
    db()->prepare('INSERT INTO lokasi_absen (nama, lat, lng, radius, aktif) VALUES (?, ?, ?, ?, ?)')
        ->execute([$nama, $lat, $lng, $radius, $aktif ? 1 : 0]);
    $idLokasi = (int) db()->lastInsertId();
    $kode     = 201;
    $pesan    = 'Lokasi absen ditambahkan.';
}

foreach (daftar_lokasi_absen() as $lokasi) {
    if ((int) $lokasi['id_lokasi'] === $idLokasi) {
        kirim_json($kode, true, $pesan, ['lokasi' => data_lokasi_publik($lokasi)]);
    }
}
