<?php
/**
 * POST /api/absen/kirim.php   (multipart/form-data, khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Absen untuk SATU mata pelajaran (jadwal) hari ini.
 * Isian:
 *   id_jadwal     : jadwal mengajar yang diabsen
 *   foto          : foto selfie dari kamera (JPG/PNG/WEBP)
 *   lat, lng      : lokasi GPS saat foto diambil
 *   lokasi_palsu  : "1" jika HP mendeteksi Fake GPS (opsional)
 *
 * - Dibuka mulai 'buka_absen_menit' sebelum jam mulai mapel, dan tetap bisa
 *   dilakukan sampai akhir hari walaupun mapelnya sudah selesai.
 * - Lewat dari jam mulai + toleransi dicatat 'terlambat' (menit dihitung
 *   dari jam mulai). Admin melihat tandanya di Monitoring Absensi.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/jadwal.php';
require_once __DIR__ . '/../../core/absen.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('POST');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];
$idJadwal = (int) ($_POST['id_jadwal'] ?? 0);

$sekarang    = time();
$tanggal     = date('Y-m-d', $sekarang);
$hari        = NAMA_HARI[(int) date('N', $sekarang)];
$jamSekarang = date('H:i:s', $sekarang);
$detikIni    = detik_dari_jam($jamSekarang);

// ---------- Mapel yang diabsen ----------
$stmt = db()->prepare(SQL_JADWAL . ' WHERE j.id_jadwal = ? AND j.id_pengguna = ?');
$stmt->execute([$idJadwal, $idGuru]);
$jadwal = $stmt->fetch();
if (!$jadwal) {
    kirim_json(404, false, 'Jadwal mengajar tidak ditemukan.');
}
if ($jadwal['hari'] !== $hari) {
    kirim_json(422, false, 'Jadwal ' . $jadwal['mata_pelajaran'] . ' adalah hari ' . $jadwal['hari']
        . ', bukan hari ini.');
}

$libur = info_libur($tanggal);
if ($libur !== null) {
    kirim_json(422, false, 'Hari ini libur (' . $libur . '), tidak perlu absen.');
}
$cuti = cuti_disetujui_pada($idGuru, $tanggal);
if ($cuti !== null) {
    kirim_json(409, false, 'Hari ini kamu ' . strtolower(label_jenis_cuti($cuti))
        . ' (sudah disetujui admin), tidak perlu absen.');
}

$pengaturan = pengaturan_absen();
$detikBuka  = detik_dari_jam($jadwal['jam_mulai']) - (int) $pengaturan['buka_absen_menit'] * 60;
if ($detikIni < $detikBuka) {
    kirim_json(422, false, sprintf(
        'Absen %s dibuka mulai pukul %s.',
        $jadwal['mata_pelajaran'],
        jam_titik(sprintf('%02d:%02d', intdiv(max(0, $detikBuka), 3600), intdiv(max(0, $detikBuka) % 3600, 60)))
    ));
}

$ada = absensi_jadwal($idJadwal, $tanggal);
if ($ada) {
    if ($ada['jam_absen'] === null) {
        kirim_json(409, false, 'Kehadiran mapel ini sudah ditandai admin (' . $ada['status'] . ').');
    }
    kirim_json(409, false, 'Kamu sudah absen ' . $ada['mata_pelajaran'] . ' pukul ' . jam_titik($ada['jam_absen']) . '.');
}

// ---------- Lokasi & foto ----------
list($lat, $lng) = baca_lokasi($_POST);
$lokasi = periksa_lokasi($lat, $lng);
$foto   = simpan_foto_absen($idGuru, $idJadwal);

list($status, $menitTerlambat) = hitung_status_absen(
    $detikIni,
    $jadwal['jam_mulai'],
    $pengaturan['toleransi_terlambat']
);

try {
    db()->prepare(
        'INSERT INTO absensi (id_pengguna, id_jadwal, tanggal, mata_pelajaran, unit, kelas, jam_mulai, jam_selesai,
                              jam_absen, foto, lat, lng, id_lokasi, jarak, status, menit_terlambat)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    )->execute([
        $idGuru, $idJadwal, $tanggal, $jadwal['mata_pelajaran'], $jadwal['unit'], $jadwal['kelas'],
        $jadwal['jam_mulai'], $jadwal['jam_selesai'], $jamSekarang, $foto, $lat, $lng,
        $lokasi === null ? null : $lokasi['id_lokasi'],
        $lokasi === null ? null : $lokasi['jarak'],
        $status, $menitTerlambat,
    ]);
} catch (PDOException $e) {
    hapus_foto_absen($foto);
    if ($e->getCode() === '23000') {
        // Dua kali tekan tombol bersamaan
        kirim_json(409, false, 'Kamu sudah absen untuk mapel ini.');
    }
    throw $e;
}

$pesan = 'Absen ' . $jadwal['mata_pelajaran'] . ' berhasil pukul ' . jam_titik($jamSekarang)
    . ($lokasi === null ? '' : ' di ' . $lokasi['nama']) . '.';
if ($status === 'terlambat') {
    $pesan .= ' Kamu terlambat ' . $menitTerlambat . ' menit';
    $pesan .= $jamSekarang > $jadwal['jam_selesai'] ? ' (lewat jam pelajaran).' : '.';
}

kirim_json(201, true, $pesan, [
    'absensi' => data_absensi_publik(absensi_jadwal($idJadwal, $tanggal)),
]);
