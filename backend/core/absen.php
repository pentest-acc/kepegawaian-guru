<?php
/**
 * Fungsi bantu untuk fitur Absen (foto + lokasi GPS).
 *
 * Aturan absen:
 *  - Jam absen SELALU memakai jam server, bukan jam HP.
 *  - Hari Minggu dan tanggal di tabel hari_libur tidak ada absen.
 *  - Absen masuk dibuka mulai config 'absen_masuk_mulai' sampai jam pulang
 *    unit guru. Lewat dari jam masuk + toleransi = terlambat.
 *  - Absen pulang dibuka mulai jam pulang PALING AWAL di tabel
 *    jam_kerja_unit (mis. 13.00 untuk TK). Guru yang absen pulang sebelum
 *    jam pulang unitnya sendiri dicatat "pulang lebih awal".
 *  - Admin bisa menambah BANYAK lokasi absen (mis. 3 gedung Yayasan).
 *    Guru harus berada di dalam radius salah satu lokasi yang aktif; yang
 *    dicatat adalah lokasi terdekat. Jika belum ada lokasi, jarak tidak dicek.
 */

const NAMA_HARI = [1 => 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const STATUS_TANPA_ABSEN = ['izin', 'sakit', 'cuti'];

/** Ubah "HH:MM" atau "HH:MM:SS" menjadi jumlah detik sejak 00:00. */
function detik_dari_jam($jam)
{
    $bagian = explode(':', $jam);
    return (int) $bagian[0] * 3600 + (int) ($bagian[1] ?? 0) * 60 + (int) ($bagian[2] ?? 0);
}

/** "07:00:00" -> "07:00" (null tetap null). */
function jam_pendek($jam)
{
    return $jam === null ? null : substr($jam, 0, 5);
}

/** "13:00:00" -> "13.00" (format jam yang ditampilkan ke guru). */
function jam_titik($jam)
{
    return str_replace(':', '.', substr($jam, 0, 5));
}

/**
 * Keterangan libur untuk sebuah tanggal, atau null jika hari sekolah.
 */
function info_libur($tanggal)
{
    if ((int) date('N', strtotime($tanggal)) === 7) {
        return 'Hari Minggu';
    }
    $stmt = db()->prepare('SELECT keterangan FROM hari_libur WHERE tanggal = ?');
    $stmt->execute([$tanggal]);
    $keterangan = $stmt->fetchColumn();
    return $keterangan === false ? null : $keterangan;
}

/**
 * Jam masuk & pulang untuk unit guru. Jika unit kosong/tidak dikenal,
 * dipakai jam pulang paling akhir (aturan paling ketat).
 */
function jam_kerja_unit($unit)
{
    $stmt = db()->prepare('SELECT unit, jam_masuk, jam_pulang FROM jam_kerja_unit WHERE unit = ?');
    $stmt->execute([(string) $unit]);
    $baris = $stmt->fetch();
    if (!$baris) {
        $baris = db()->query('SELECT unit, jam_masuk, jam_pulang FROM jam_kerja_unit ORDER BY jam_pulang DESC LIMIT 1')->fetch();
    }
    if (!$baris) {
        $baris = ['unit' => $unit, 'jam_masuk' => '07:00:00', 'jam_pulang' => '14:00:00'];
    }
    return $baris;
}

/** Jam paling awal tombol absen pulang muncul (jam pulang paling awal). */
function jam_buka_absen_pulang()
{
    $jam = db()->query('SELECT MIN(jam_pulang) FROM jam_kerja_unit')->fetchColumn();
    return $jam ?: '13:00:00';
}

/** Pengaturan absen: toleransi terlambat. */
function pengaturan_absen()
{
    $baris = db()->query('SELECT toleransi_terlambat FROM pengaturan WHERE id_pengaturan = 1')->fetch();
    return $baris ?: ['toleransi_terlambat' => 15];
}

/**
 * Semua lokasi absen urut dibuat, beserta nomor urutnya (Lokasi 1, 2, 3, ...).
 * Nomor dihitung dari SEMUA lokasi agar tidak berubah saat ada yang dinonaktifkan.
 */
function daftar_lokasi_absen($hanyaAktif = false)
{
    $hasil = [];
    $nomor = 0;
    foreach (db()->query('SELECT * FROM lokasi_absen ORDER BY id_lokasi')->fetchAll() as $b) {
        $nomor++;
        if ($hanyaAktif && !$b['aktif']) {
            continue;
        }
        $b['nomor'] = $nomor;
        $hasil[]    = $b;
    }
    return $hasil;
}

/** Ubah baris lokasi_absen menjadi data JSON untuk aplikasi. */
function data_lokasi_publik(array $b)
{
    return [
        'id_lokasi' => (int) $b['id_lokasi'],
        'nomor'     => (int) $b['nomor'],
        'nama'      => $b['nama'],
        'lat'       => (float) $b['lat'],
        'lng'       => (float) $b['lng'],
        'radius'    => (int) $b['radius'],
        'aktif'     => (bool) $b['aktif'],
    ];
}

/** Baris absensi guru pada tanggal tertentu (false jika belum ada). */
function absensi_guru($idPengguna, $tanggal)
{
    $stmt = db()->prepare(
        'SELECT a.*, lm.nama AS nama_lokasi_masuk, lp.nama AS nama_lokasi_pulang
           FROM absensi a
           LEFT JOIN lokasi_absen lm ON lm.id_lokasi = a.id_lokasi_masuk
           LEFT JOIN lokasi_absen lp ON lp.id_lokasi = a.id_lokasi_pulang
          WHERE a.id_pengguna = ? AND a.tanggal = ?'
    );
    $stmt->execute([(int) $idPengguna, $tanggal]);
    return $stmt->fetch();
}

/** Ubah baris absensi menjadi data JSON untuk aplikasi (tanpa lokasi file foto). */
function data_absensi_publik(array $b)
{
    return [
        'id_absensi'        => (int) $b['id_absensi'],
        'tanggal'           => $b['tanggal'],
        'jam_masuk'         => jam_pendek($b['jam_masuk']),
        'jam_pulang'        => jam_pendek($b['jam_pulang']),
        'status'            => $b['status'],
        'menit_terlambat'   => (int) $b['menit_terlambat'],
        'menit_pulang_awal' => (int) $b['menit_pulang_awal'],
        'lokasi_masuk'      => $b['nama_lokasi_masuk'] ?? null,
        'jarak_masuk'       => $b['jarak_masuk'] === null ? null : (int) $b['jarak_masuk'],
        'lokasi_pulang'     => $b['nama_lokasi_pulang'] ?? null,
        'jarak_pulang'      => $b['jarak_pulang'] === null ? null : (int) $b['jarak_pulang'],
        'ada_foto_masuk'    => $b['foto_masuk'] !== null,
        'ada_foto_pulang'   => $b['foto_pulang'] !== null,
        'keterangan'        => $b['keterangan'],
    ];
}

/**
 * Jarak dua titik GPS dalam meter (rumus Haversine).
 */
function jarak_meter($lat1, $lng1, $lat2, $lng2)
{
    $r    = 6371000; // jari-jari bumi (meter)
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a    = sin($dLat / 2) ** 2
          + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
    return 2 * $r * asin(min(1, sqrt($a)));
}

/** 350 -> "350 m", 1234 -> "1,2 km". */
function format_jarak($meter)
{
    if ($meter < 1000) {
        return $meter . ' m';
    }
    return str_replace('.', ',', (string) round($meter / 1000, 1)) . ' km';
}

/**
 * Baca lat/lng yang dikirim aplikasi. Menolak lokasi palsu (Fake GPS).
 *
 * @return float[] [lat, lng]
 */
function baca_lokasi(array $input)
{
    $lat = is_scalar($input['lat'] ?? null) ? filter_var($input['lat'], FILTER_VALIDATE_FLOAT) : false;
    $lng = is_scalar($input['lng'] ?? null) ? filter_var($input['lng'], FILTER_VALIDATE_FLOAT) : false;

    if ($lat === false || $lng === false || abs($lat) > 90 || abs($lng) > 180) {
        kirim_json(422, false, 'Lokasi GPS belum terbaca. Aktifkan GPS/lokasi lalu coba lagi.');
    }
    if (in_array(strtolower(input_teks($input, 'lokasi_palsu')), ['1', 'true'], true)) {
        kirim_json(422, false, 'Terdeteksi aplikasi lokasi palsu (Fake GPS). Matikan aplikasi tersebut lalu coba lagi.');
    }
    return [$lat, $lng];
}

/**
 * Pastikan guru berada di dalam radius salah satu lokasi absen yang aktif.
 *
 * Mengembalikan ['id_lokasi' => .., 'nama' => .., 'jarak' => ..] untuk lokasi
 * terdekat yang radiusnya mencakup posisi guru, atau null jika admin belum
 * menambahkan lokasi absen sama sekali (jarak tidak dicek).
 */
function periksa_lokasi($lat, $lng)
{
    $daftar = daftar_lokasi_absen(true);
    if (empty($daftar)) {
        return null;
    }

    $terdekat = null; // lokasi terdekat (untuk pesan jika di luar semua radius)
    $sah      = null; // lokasi terdekat yang radiusnya mencakup posisi guru
    foreach ($daftar as $lokasi) {
        $jarak = (int) round(jarak_meter($lat, $lng, (float) $lokasi['lat'], (float) $lokasi['lng']));
        $calon = ['id_lokasi' => (int) $lokasi['id_lokasi'], 'nama' => $lokasi['nama'],
                  'jarak' => $jarak, 'radius' => (int) $lokasi['radius']];
        if ($terdekat === null || $jarak < $terdekat['jarak']) {
            $terdekat = $calon;
        }
        if ($jarak <= $calon['radius'] && ($sah === null || $jarak < $sah['jarak'])) {
            $sah = $calon;
        }
    }

    if ($sah === null) {
        kirim_json(422, false, sprintf(
            'Kamu berada ± %s dari lokasi absen terdekat (%s). Absen hanya bisa dilakukan dalam radius %d m dari lokasi tersebut.',
            format_jarak($terdekat['jarak']),
            $terdekat['nama'],
            $terdekat['radius']
        ), ['lokasi' => $terdekat['nama'], 'jarak' => $terdekat['jarak'], 'radius' => $terdekat['radius']]);
    }
    return $sah;
}

/**
 * Simpan foto absen yang diunggah (field "foto") ke uploads/absen/YYYY-MM/.
 * Mengembalikan lokasi file relatif terhadap folder uploads.
 */
function simpan_foto_absen($idPengguna, $jenis)
{
    $berkas = $_FILES['foto'] ?? null;
    if (!is_array($berkas) || !isset($berkas['error']) || is_array($berkas['error'])
        || $berkas['error'] === UPLOAD_ERR_NO_FILE) {
        kirim_json(422, false, 'Foto absen wajib diunggah.');
    }

    $maksByte = (int) $GLOBALS['config_app']['maks_foto_absen_kb'] * 1024;
    if (in_array($berkas['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)
        || $berkas['size'] > $maksByte) {
        kirim_json(413, false, 'Ukuran foto terlalu besar. Silakan ambil ulang fotonya.');
    }
    if ($berkas['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($berkas['tmp_name'])) {
        kirim_json(422, false, 'Foto gagal diunggah. Silakan coba lagi.');
    }

    // Pastikan isinya benar-benar gambar (bukan sekadar nama file .jpg)
    $ekstensi = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
    $info     = @getimagesize($berkas['tmp_name']);
    if ($info === false || !isset($ekstensi[$info[2]]) || $info[0] < 50 || $info[1] < 50) {
        kirim_json(422, false, 'File harus berupa foto (JPG, PNG, atau WEBP).');
    }

    $relatif = 'absen/' . date('Y-m');
    $folder  = __DIR__ . '/../uploads/' . $relatif;
    if (!is_dir($folder) && !@mkdir($folder, 0775, true) && !is_dir($folder)) {
        throw new RuntimeException('Folder foto absen tidak bisa dibuat: ' . $folder);
    }

    $nama = sprintf('%d-%s-%s.%s', $idPengguna, $jenis, bin2hex(random_bytes(16)), $ekstensi[$info[2]]);
    if (!@move_uploaded_file($berkas['tmp_name'], $folder . '/' . $nama)) {
        throw new RuntimeException('Foto absen gagal disimpan ke ' . $folder . ' (cek izin tulis folder).');
    }
    return $relatif . '/' . $nama;
}

/** Hapus file foto absen (dipakai jika penyimpanan ke database gagal). */
function hapus_foto_absen($relatif)
{
    $lokasi = __DIR__ . '/../uploads/' . $relatif;
    if ($relatif !== null && is_file($lokasi)) {
        @unlink($lokasi);
    }
}

/** Seluruh pengaturan absen untuk halaman Pengaturan Sistem (admin). */
function data_pengaturan_absen_admin()
{
    $alamat     = db()->query('SELECT alamat_yayasan FROM pengaturan WHERE id_pengaturan = 1')->fetchColumn();
    $jamKerja   = db()->query(
        "SELECT unit, jam_masuk, jam_pulang FROM jam_kerja_unit ORDER BY FIELD(unit, 'KB', 'TK', 'SD')"
    )->fetchAll();

    return [
        'alamat_yayasan'      => $alamat === false ? null : $alamat,
        'toleransi_terlambat' => (int) pengaturan_absen()['toleransi_terlambat'],
        'jumlah_lokasi'       => (int) db()->query('SELECT COUNT(*) FROM lokasi_absen WHERE aktif = 1')->fetchColumn(),
        'jam_kerja'           => array_map(function ($b) {
            return [
                'unit'       => $b['unit'],
                'jam_masuk'  => jam_pendek($b['jam_masuk']),
                'jam_pulang' => jam_pendek($b['jam_pulang']),
            ];
        }, $jamKerja),
    ];
}
