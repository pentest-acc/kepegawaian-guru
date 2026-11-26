<?php
/**
 * Aturan cuti / izin / sakit guru.
 *
 * - Jenis: cuti (memotong kuota cuti tahunan), izin & sakit (tidak memotong kuota).
 * - Jumlah hari = hari kerja dalam rentang tanggal: hari Minggu dan tanggal di
 *   tabel hari_libur tidak dihitung.
 * - Cuti diajukan untuk hari ini atau tanggal mendatang. Izin & sakit boleh
 *   diajukan menyusul, paling lambat 7 hari setelah tanggalnya.
 * - Satu pengajuan paling lama 30 hari kalender dan tidak boleh bertumpuk dengan
 *   pengajuan lain yang masih menunggu / sudah disetujui.
 * - Sakit 2 hari kerja atau lebih wajib melampirkan foto surat dokter.
 * - Kuota cuti dihitung per tahun kalender (pengaturan.kuota_cuti_tahunan).
 *   Pengajuan cuti yang masih menunggu ikut dihitung agar tidak melebihi kuota.
 * - Cuti/izin/sakit yang DISETUJUI admin membuat guru tidak perlu absen pada
 *   hari itu (absen/kirim.php menolak), dan tampil di Monitoring & Riwayat Absen.
 */

require_once __DIR__ . '/jadwal.php';

const JENIS_CUTI              = ['cuti', 'izin', 'sakit'];
const STATUS_CUTI             = ['menunggu', 'disetujui', 'ditolak'];
const CUTI_MAKS_HARI_KALENDER = 30;
const CUTI_BOLEH_MENYUSUL     = 7;    // hari, untuk izin & sakit
const CUTI_SAKIT_WAJIB_SURAT  = 2;    // sakit >= 2 hari kerja wajib lampiran
const CUTI_MAKS_LAMPIRAN_KB   = 5120;

const SQL_CUTI = 'SELECT c.*, p.nomor_induk, p.nama_lengkap, p.gelar, p.unit,
                         a.nama_lengkap AS nama_pemroses, a.gelar AS gelar_pemroses
                    FROM cuti c
                    JOIN pengguna p ON p.id_pengguna = c.id_pengguna
               LEFT JOIN pengguna a ON a.id_pengguna = c.diproses_oleh';

function label_jenis_cuti($jenis)
{
    return ['cuti' => 'Cuti', 'izin' => 'Izin', 'sakit' => 'Sakit'][$jenis] ?? $jenis;
}

/** "2026-12-01" -> "1 Des 2026" */
function tanggal_singkat($tanggal)
{
    $bulan = [1 => 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    $t = strtotime($tanggal);
    return (int) date('j', $t) . ' ' . $bulan[(int) date('n', $t)] . ' ' . date('Y', $t);
}

/** "1 Des 2026" atau "1 Des 2026 - 3 Des 2026" */
function rentang_tanggal($mulai, $selesai)
{
    return $mulai === $selesai
        ? tanggal_singkat($mulai)
        : tanggal_singkat($mulai) . ' - ' . tanggal_singkat($selesai);
}

/**
 * Tanggal-tanggal hari kerja (bukan Minggu, bukan hari libur) dalam rentang.
 * @return string[] format Y-m-d
 */
function hari_kerja_cuti($mulai, $selesai)
{
    $stmt = db()->prepare('SELECT tanggal FROM hari_libur WHERE tanggal BETWEEN ? AND ?');
    $stmt->execute([$mulai, $selesai]);
    $libur = array_flip($stmt->fetchAll(PDO::FETCH_COLUMN));

    $hasil = [];
    $tgl   = new DateTime($mulai);
    while ($tgl->format('Y-m-d') <= $selesai) {
        $teks = $tgl->format('Y-m-d');
        if ($tgl->format('N') !== '7' && !isset($libur[$teks])) {
            $hasil[] = $teks;
        }
        $tgl->modify('+1 day');
    }
    return $hasil;
}

/**
 * Kuota cuti seorang guru pada satu tahun kalender.
 * [kecualiId] = pengajuan yang tidak ikut dihitung (mis. yang sedang diproses).
 */
function kuota_cuti($idGuru, $tahun, $kecualiId = 0)
{
    $kuota = (int) db()->query('SELECT kuota_cuti_tahunan FROM pengaturan WHERE id_pengaturan = 1')->fetchColumn();
    $stmt  = db()->prepare(
        "SELECT status, COALESCE(SUM(jumlah_hari), 0)
           FROM cuti
          WHERE id_pengguna = ? AND jenis = 'cuti' AND YEAR(tanggal_mulai) = ?
            AND status IN ('menunggu', 'disetujui') AND id_cuti <> ?
          GROUP BY status"
    );
    $stmt->execute([$idGuru, (int) $tahun, (int) $kecualiId]);
    $per      = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
    $terpakai = (int) ($per['disetujui'] ?? 0);
    $diajukan = (int) ($per['menunggu'] ?? 0);

    return [
        'tahun'    => (int) $tahun,
        'kuota'    => $kuota,
        'terpakai' => $terpakai,   // cuti yang sudah disetujui
        'diajukan' => $diajukan,   // cuti yang masih menunggu persetujuan
        'sisa'     => max(0, $kuota - $terpakai - $diajukan),
    ];
}

/** Pengajuan lain (menunggu / disetujui) yang tanggalnya bertumpuk, atau null. */
function cuti_bertumpuk($idGuru, $mulai, $selesai, $kecualiId = 0, $hanyaDisetujui = false)
{
    $status = $hanyaDisetujui ? "('disetujui')" : "('menunggu', 'disetujui')";
    $stmt   = db()->prepare(
        "SELECT * FROM cuti
          WHERE id_pengguna = ? AND status IN $status
            AND tanggal_mulai <= ? AND tanggal_selesai >= ? AND id_cuti <> ?
          ORDER BY tanggal_mulai LIMIT 1"
    );
    $stmt->execute([$idGuru, $selesai, $mulai, (int) $kecualiId]);
    return $stmt->fetch() ?: null;
}

/** Jenis cuti/izin/sakit yang DISETUJUI untuk guru pada tanggal itu, atau null. */
function cuti_disetujui_pada($idGuru, $tanggal)
{
    $stmt = db()->prepare(
        "SELECT jenis FROM cuti
          WHERE id_pengguna = ? AND status = 'disetujui'
            AND tanggal_mulai <= ? AND tanggal_selesai >= ?
          ORDER BY tanggal_mulai LIMIT 1"
    );
    $stmt->execute([$idGuru, $tanggal, $tanggal]);
    $jenis = $stmt->fetchColumn();
    return $jenis === false ? null : $jenis;
}

/** Cuti yang disetujui untuk semua guru pada satu tanggal: [id_pengguna => jenis]. */
function cuti_disetujui_tanggal($tanggal)
{
    $stmt = db()->prepare(
        "SELECT id_pengguna, jenis FROM cuti
          WHERE status = 'disetujui' AND tanggal_mulai <= ? AND tanggal_selesai >= ?
          ORDER BY tanggal_mulai DESC"
    );
    $stmt->execute([$tanggal, $tanggal]);
    return $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
}

/**
 * Mapel yang ditinggalkan guru selama cuti (berdasarkan jadwal mingguan),
 * untuk setiap hari kerja: [{tanggal, hari, mapel: [...]}].
 */
function mapel_ditinggalkan($idGuru, array $daftarTanggal)
{
    $stmt = db()->prepare(SQL_JADWAL . ' WHERE j.id_pengguna = ? ORDER BY j.jam_mulai');
    $stmt->execute([$idGuru]);
    $perHari = [];
    foreach ($stmt->fetchAll() as $j) {
        $perHari[$j['hari']][] = data_jadwal_publik($j);
    }

    $namaHari = [1 => 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    $hasil    = [];
    foreach ($daftarTanggal as $tanggal) {
        $hari    = $namaHari[(int) date('N', strtotime($tanggal))];
        $hasil[] = ['tanggal' => $tanggal, 'hari' => $hari, 'mapel' => $perHari[$hari] ?? []];
    }
    return $hasil;
}

function jumlah_mapel_ditinggalkan(array $hari)
{
    $jumlah = 0;
    foreach ($hari as $h) {
        $jumlah += count($h['mapel']);
    }
    return $jumlah;
}

/** Data pengajuan yang aman dikirim ke aplikasi. */
function data_cuti_publik(array $b)
{
    $data = [
        'id_cuti'         => (int) $b['id_cuti'],
        'id_pengguna'     => (int) $b['id_pengguna'],
        'jenis'           => $b['jenis'],
        'tanggal_mulai'   => $b['tanggal_mulai'],
        'tanggal_selesai' => $b['tanggal_selesai'],
        'jumlah_hari'     => (int) $b['jumlah_hari'],
        'alasan'          => $b['alasan'],
        'ada_lampiran'    => $b['lampiran'] !== null,
        'status'          => $b['status'],
        'catatan_admin'   => $b['catatan_admin'],
        'diproses_oleh'   => isset($b['nama_pemroses'])
            ? nama_dengan_gelar($b['nama_pemroses'], $b['gelar_pemroses'])
            : null,
        'diproses_pada'   => $b['diproses_pada'],
        'dibuat_pada'     => $b['dibuat_pada'],
    ];
    if (isset($b['nama_lengkap'])) {
        $data['guru'] = [
            'id_pengguna' => (int) $b['id_pengguna'],
            'nomor_induk' => $b['nomor_induk'],
            'nama_tampil' => nama_dengan_gelar($b['nama_lengkap'], $b['gelar']),
            'unit'        => $b['unit'],
        ];
    }
    return $data;
}

function cuti_by_id($idCuti)
{
    $stmt = db()->prepare(SQL_CUTI . ' WHERE c.id_cuti = ?');
    $stmt->execute([(int) $idCuti]);
    return $stmt->fetch() ?: null;
}

/**
 * Memeriksa isian pengajuan (dipakai cuti/hitung.php & cuti/ajukan.php).
 * Menghentikan request dengan 422/409 jika tidak valid.
 * @return array [jenis, mulai, selesai, hari (tanggal-tanggal hari kerja)]
 */
function periksa_pengajuan_cuti($idGuru, array $input)
{
    $jenis   = strtolower(trim((string) ($input['jenis'] ?? '')));
    $mulai   = trim((string) ($input['tanggal_mulai'] ?? ''));
    $selesai = trim((string) ($input['tanggal_selesai'] ?? ''));

    if (!in_array($jenis, JENIS_CUTI, true)) {
        kirim_json(422, false, 'Pilih jenis pengajuan: cuti, izin, atau sakit.', ['kesalahan' => ['jenis' => 'Pilih jenis pengajuan.']]);
    }
    if (!tanggal_valid($mulai) || !tanggal_valid($selesai)) {
        kirim_json(422, false, 'Tanggal mulai dan selesai wajib diisi (format YYYY-MM-DD).');
    }
    if ($selesai < $mulai) {
        kirim_json(422, false, 'Tanggal selesai tidak boleh sebelum tanggal mulai.');
    }
    $lamaHari = (int) (new DateTime($mulai))->diff(new DateTime($selesai))->days + 1;
    if ($lamaHari > CUTI_MAKS_HARI_KALENDER) {
        kirim_json(422, false, 'Satu pengajuan paling lama ' . CUTI_MAKS_HARI_KALENDER
            . ' hari. Ajukan terpisah untuk waktu yang lebih panjang.');
    }

    $hariIni = date('Y-m-d');
    if ($jenis === 'cuti' && $mulai < $hariIni) {
        kirim_json(422, false, 'Cuti tidak bisa diajukan untuk tanggal yang sudah lewat. '
            . 'Gunakan izin atau sakit jika keperluannya mendadak.');
    }
    $batasMenyusul = date('Y-m-d', strtotime($hariIni . ' -' . CUTI_BOLEH_MENYUSUL . ' days'));
    if ($jenis !== 'cuti' && $mulai < $batasMenyusul) {
        kirim_json(422, false, label_jenis_cuti($jenis) . ' paling lambat diajukan '
            . CUTI_BOLEH_MENYUSUL . ' hari setelah tanggalnya.');
    }
    if ($jenis === 'cuti' && substr($mulai, 0, 4) !== substr($selesai, 0, 4)) {
        kirim_json(422, false, 'Kuota cuti dihitung per tahun, jadi cuti yang melewati pergantian '
            . 'tahun diajukan terpisah (sampai 31 Desember, lalu mulai 1 Januari).');
    }

    $hari = hari_kerja_cuti($mulai, $selesai);
    if (empty($hari)) {
        kirim_json(422, false, 'Tanggal yang dipilih hanya berisi hari Minggu / hari libur.');
    }

    $lain = cuti_bertumpuk($idGuru, $mulai, $selesai);
    if ($lain) {
        kirim_json(409, false, sprintf(
            'Tanggalnya bertumpuk dengan pengajuan %s %s yang %s.',
            label_jenis_cuti($lain['jenis']),
            rentang_tanggal($lain['tanggal_mulai'], $lain['tanggal_selesai']),
            $lain['status'] === 'disetujui' ? 'sudah disetujui' : 'masih menunggu persetujuan'
        ));
    }

    if ($jenis === 'cuti') {
        $kuota = kuota_cuti($idGuru, substr($mulai, 0, 4));
        if (count($hari) > $kuota['sisa']) {
            kirim_json(422, false, sprintf(
                'Sisa kuota cuti tahun %d tinggal %d hari, sedangkan pengajuan ini %d hari kerja.',
                $kuota['tahun'],
                $kuota['sisa'],
                count($hari)
            ), ['kuota' => $kuota]);
        }
    }

    return [$jenis, $mulai, $selesai, $hari];
}

/**
 * Menyimpan foto lampiran (mis. surat dokter) dari field 'lampiran'.
 * @return string|null path relatif di folder uploads, null jika tidak ada file.
 */
function simpan_lampiran_cuti($idPengguna)
{
    $berkas = $_FILES['lampiran'] ?? null;
    if (!is_array($berkas) || !isset($berkas['error']) || is_array($berkas['error'])
        || $berkas['error'] === UPLOAD_ERR_NO_FILE) {
        return null;
    }

    if (in_array($berkas['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)
        || $berkas['size'] > CUTI_MAKS_LAMPIRAN_KB * 1024) {
        kirim_json(413, false, 'Ukuran foto lampiran maksimal ' . (CUTI_MAKS_LAMPIRAN_KB / 1024) . ' MB.');
    }
    if ($berkas['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($berkas['tmp_name'])) {
        kirim_json(422, false, 'Lampiran gagal diunggah. Silakan coba lagi.');
    }

    $ekstensi = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
    $info     = @getimagesize($berkas['tmp_name']);
    if ($info === false || !isset($ekstensi[$info[2]])) {
        kirim_json(422, false, 'Lampiran harus berupa foto (JPG, PNG, atau WEBP), mis. foto surat dokter.');
    }

    $relatif = 'cuti/' . date('Y-m');
    $folder  = __DIR__ . '/../uploads/' . $relatif;
    if (!is_dir($folder) && !@mkdir($folder, 0775, true) && !is_dir($folder)) {
        throw new RuntimeException('Folder lampiran cuti tidak bisa dibuat: ' . $folder);
    }

    $nama = sprintf('%d-%s.%s', $idPengguna, bin2hex(random_bytes(16)), $ekstensi[$info[2]]);
    if (!@move_uploaded_file($berkas['tmp_name'], $folder . '/' . $nama)) {
        throw new RuntimeException('Lampiran cuti gagal disimpan ke ' . $folder . ' (cek izin tulis folder).');
    }
    return $relatif . '/' . $nama;
}

function hapus_lampiran_cuti($relatif)
{
    if ($relatif === null) {
        return;
    }
    $lokasi = __DIR__ . '/../uploads/' . $relatif;
    if (is_file($lokasi)) {
        @unlink($lokasi);
    }
}
