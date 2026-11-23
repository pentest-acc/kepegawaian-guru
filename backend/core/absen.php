<?php
/**
 * Fungsi bantu untuk fitur Absen (foto + lokasi GPS), PER MATA PELAJARAN.
 *
 * Aturan absen:
 *  - Setiap jadwal mengajar hari itu = satu kali absen. Guru dengan 2 mapel
 *    absen 2 kali. Jam masuk mengikuti mapel pertama dan guru boleh pulang
 *    setelah mapel terakhir selesai (tidak ada lagi jam kerja per unit).
 *  - Jam absen SELALU memakai jam server, bukan jam HP.
 *  - Absen sebuah mapel dibuka mulai 'buka_absen_menit' sebelum jam mulai
 *    dan tetap bisa dilakukan sampai akhir hari (walau mapel sudah selesai).
 *  - Lewat dari jam mulai + toleransi = 'terlambat'; menit terlambat dihitung
 *    dari jam mulai. Absen setelah jam selesai ditandai "lewat jam pelajaran".
 *  - Hari Minggu dan tanggal di tabel hari_libur tidak ada absen.
 *  - Admin bisa menandai/mengubah kehadiran (lupa absen, izin, sakit, alpa).
 *  - Admin bisa menambah BANYAK lokasi absen (mis. 3 gedung Yayasan).
 *    Guru harus berada di dalam radius salah satu lokasi yang aktif; yang
 *    dicatat adalah lokasi terdekat. Jika belum ada lokasi, jarak tidak dicek.
 */

const NAMA_HARI = [1 => 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const STATUS_KEHADIRAN = ['hadir', 'terlambat', 'izin', 'sakit', 'cuti', 'alpa'];

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

/** Pengaturan absen: toleransi terlambat & jam buka absen (menit). */
function pengaturan_absen()
{
    $baris = db()->query(
        'SELECT toleransi_terlambat, buka_absen_menit FROM pengaturan WHERE id_pengaturan = 1'
    )->fetch();
    return $baris ?: ['toleransi_terlambat' => 15, 'buka_absen_menit' => 30];
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

/** Query dasar absensi beserta nama lokasi absennya. */
const SQL_ABSENSI = 'SELECT a.*, l.nama AS nama_lokasi
                       FROM absensi a
                       LEFT JOIN lokasi_absen l ON l.id_lokasi = a.id_lokasi';

/** Satu baris absensi berdasarkan id (false jika tidak ada). */
function absensi_by_id($idAbsensi)
{
    $stmt = db()->prepare(SQL_ABSENSI . ' WHERE a.id_absensi = ?');
    $stmt->execute([(int) $idAbsensi]);
    return $stmt->fetch();
}

/** Absensi sebuah jadwal pada tanggal tertentu (false jika belum ada). */
function absensi_jadwal($idJadwal, $tanggal)
{
    $stmt = db()->prepare(SQL_ABSENSI . ' WHERE a.id_jadwal = ? AND a.tanggal = ?');
    $stmt->execute([(int) $idJadwal, $tanggal]);
    return $stmt->fetch();
}

/** Ubah baris absensi menjadi data JSON untuk aplikasi (tanpa lokasi file foto). */
function data_absensi_publik(array $b)
{
    return [
        'id_absensi'      => (int) $b['id_absensi'],
        'id_jadwal'       => $b['id_jadwal'] === null ? null : (int) $b['id_jadwal'],
        'tanggal'         => $b['tanggal'],
        'mata_pelajaran'  => $b['mata_pelajaran'],
        'unit'            => $b['unit'],
        'kelas'           => $b['kelas'],
        'jam_mulai'       => jam_pendek($b['jam_mulai']),
        'jam_selesai'     => jam_pendek($b['jam_selesai']),
        'jam_absen'       => jam_pendek($b['jam_absen']),
        'status'          => $b['status'],
        'menit_terlambat' => (int) $b['menit_terlambat'],
        // absen dilakukan setelah jam pelajaran selesai
        'lewat_jam'       => $b['jam_absen'] !== null && $b['jam_absen'] > $b['jam_selesai'],
        'lokasi'          => $b['nama_lokasi'] ?? null,
        'jarak'           => $b['jarak'] === null ? null : (int) $b['jarak'],
        'ada_foto'        => $b['foto'] !== null,
        'keterangan'      => $b['keterangan'],
        'diubah_admin'    => $b['dikoreksi_oleh'] !== null,
    ];
}

/**
 * Satu mapel (jadwal) pada tanggal tertentu beserta absensinya, untuk
 * halaman Absen guru & Monitoring Absensi admin.
 *
 * @param array      $jadwal  baris jadwal_mengajar + nama_lokasi
 * @param array|null $absensi baris absensi (null jika belum absen)
 */
function data_mapel_publik(array $jadwal, $absensi)
{
    return [
        'id_jadwal'      => (int) $jadwal['id_jadwal'],
        'mata_pelajaran' => $jadwal['mata_pelajaran'],
        'unit'           => $jadwal['unit'],
        'kelas'          => $jadwal['kelas'],
        'jam_mulai'      => jam_pendek($jadwal['jam_mulai']),
        'jam_selesai'    => jam_pendek($jadwal['jam_selesai']),
        'id_lokasi'      => $jadwal['id_lokasi'] === null ? null : (int) $jadwal['id_lokasi'],
        'lokasi'         => $jadwal['nama_lokasi'] ?? null,
        'absensi'        => $absensi ? data_absensi_publik($absensi) : null,
    ];
}

/**
 * Absensi yang jadwalnya sudah tidak ada / sudah dipindah hari, ditampilkan
 * memakai salinan data mapel di baris absensi itu sendiri.
 */
function data_mapel_dari_absensi(array $absensi)
{
    return [
        'id_jadwal'      => $absensi['id_jadwal'] === null ? null : (int) $absensi['id_jadwal'],
        'mata_pelajaran' => $absensi['mata_pelajaran'],
        'unit'           => $absensi['unit'],
        'kelas'          => $absensi['kelas'],
        'jam_mulai'      => jam_pendek($absensi['jam_mulai']),
        'jam_selesai'    => jam_pendek($absensi['jam_selesai']),
        'id_lokasi'      => null,
        'lokasi'         => null,
        'absensi'        => data_absensi_publik($absensi),
    ];
}

/**
 * Gabungkan jadwal hari itu dengan absensinya.
 *
 * @param array $jadwal  baris jadwal (+ nama_lokasi), urut jam mulai
 * @param array $absensi baris absensi pada tanggal itu
 * @return array daftar data_mapel_publik, urut jam mulai
 */
function gabung_jadwal_absensi(array $jadwal, array $absensi)
{
    // Kunci 'j<id_jadwal>'; absensi yang jadwalnya sudah dihapus memakai 'a<id_absensi>'
    $perJadwal = [];
    foreach ($absensi as $a) {
        $kunci = $a['id_jadwal'] === null ? 'a' . $a['id_absensi'] : 'j' . $a['id_jadwal'];
        $perJadwal[$kunci] = $a;
    }

    $hasil = [];
    foreach ($jadwal as $j) {
        $kunci   = 'j' . $j['id_jadwal'];
        $hasil[] = data_mapel_publik($j, $perJadwal[$kunci] ?? null);
        unset($perJadwal[$kunci]);
    }
    // Sisa absensi yang jadwalnya sudah dihapus/dipindah
    foreach ($perJadwal as $a) {
        $hasil[] = data_mapel_dari_absensi($a);
    }

    usort($hasil, function ($x, $y) {
        return strcmp($x['jam_mulai'], $y['jam_mulai']);
    });
    return $hasil;
}

/**
 * Status absen guru berdasarkan jam absen dan jam mulai mapel.
 *
 * @return array [status, menit_terlambat]
 */
function hitung_status_absen($detikAbsen, $jamMulai, $toleransiMenit)
{
    $selisih = $detikAbsen - detik_dari_jam($jamMulai);
    if ($selisih > (int) $toleransiMenit * 60) {
        return ['terlambat', intdiv($selisih, 60)];
    }
    return ['hadir', 0];
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
function simpan_foto_absen($idPengguna, $idJadwal)
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

    $nama = sprintf('%d-j%d-%s.%s', $idPengguna, $idJadwal, bin2hex(random_bytes(16)), $ekstensi[$info[2]]);
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
    $pengaturan = pengaturan_absen();
    $alamat     = db()->query('SELECT alamat_yayasan FROM pengaturan WHERE id_pengaturan = 1')->fetchColumn();

    return [
        'alamat_yayasan'      => $alamat === false ? null : $alamat,
        'toleransi_terlambat' => (int) $pengaturan['toleransi_terlambat'],
        'buka_absen_menit'    => (int) $pengaturan['buka_absen_menit'],
        'jumlah_lokasi'       => (int) db()->query('SELECT COUNT(*) FROM lokasi_absen WHERE aktif = 1')->fetchColumn(),
    ];
}
