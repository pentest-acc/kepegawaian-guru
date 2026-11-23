<?php
/**
 * GET /api/absen/riwayat.php?bulan=2026-11   (khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Riwayat absen guru selama satu bulan, untuk kalender Riwayat Absen.
 * Setiap tanggal berisi:
 *   libur : keterangan libur ("Hari Minggu" / dari tabel hari_libur) atau null
 *   cuti  : jenis cuti/izin/sakit yang sudah DISETUJUI admin, atau null
 *   mapel : mapel hari itu beserta absensinya (absensi null = tidak absen)
 *
 * - Mapel diambil dari jadwal mengajar mingguan yang SUDAH ADA pada tanggal
 *   tersebut (jadwal yang baru dibuat tidak dihitung ke tanggal sebelumnya),
 *   ditambah absensi yang jadwalnya sudah dihapus/diubah.
 * - Hari libur tidak berisi jadwal (kecuali ada absensi yang ditandai admin).
 * - 'mulai' = tanggal awal riwayat guru (akun dibuat atau absen pertama),
 *   dipakai aplikasi untuk membatasi pilihan tahun ajaran.
 * Bawaan bulan = bulan ini.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/jadwal.php';
require_once __DIR__ . '/../../core/absen.php';

wajib_method('GET');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

$sekarang = time();
$bulan    = (string) ($_GET['bulan'] ?? date('Y-m', $sekarang));
if (!preg_match('/^(\d{4})-(\d{2})$/', $bulan, $m)
    || (int) $m[1] < 2000 || (int) $m[1] > 2100
    || (int) $m[2] < 1 || (int) $m[2] > 12) {
    kirim_json(422, false, 'Bulan tidak valid (format YYYY-MM).');
}
$awal  = $bulan . '-01';
$akhir = date('Y-m-t', strtotime($awal));

// ---------- Jadwal mingguan guru, dikelompokkan per hari ----------
$stmt = db()->prepare(SQL_JADWAL . ' WHERE j.id_pengguna = ? ORDER BY j.jam_mulai');
$stmt->execute([$idGuru]);
$jadwalPerHari = [];
foreach ($stmt->fetchAll() as $j) {
    $jadwalPerHari[$j['hari']][] = $j;
}

// ---------- Absensi sebulan, dikelompokkan per tanggal ----------
$stmt = db()->prepare(SQL_ABSENSI . ' WHERE a.id_pengguna = ? AND a.tanggal BETWEEN ? AND ?');
$stmt->execute([$idGuru, $awal, $akhir]);
$absensiPerTanggal = [];
foreach ($stmt->fetchAll() as $a) {
    $absensiPerTanggal[$a['tanggal']][] = $a;
}

// ---------- Hari libur & cuti yang disetujui ----------
$stmt = db()->prepare('SELECT tanggal, keterangan FROM hari_libur WHERE tanggal BETWEEN ? AND ?');
$stmt->execute([$awal, $akhir]);
$hariLibur = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);

$stmt = db()->prepare(
    "SELECT jenis, tanggal_mulai, tanggal_selesai
       FROM cuti
      WHERE id_pengguna = ? AND status = 'disetujui'
        AND tanggal_mulai <= ? AND tanggal_selesai >= ?
      ORDER BY tanggal_mulai"
);
$stmt->execute([$idGuru, $akhir, $awal]);
$daftarCuti = $stmt->fetchAll();

// ---------- Tanggal awal riwayat ----------
$mulai = substr((string) $pengguna['dibuat_pada'], 0, 10);
$stmt  = db()->prepare('SELECT MIN(tanggal) FROM absensi WHERE id_pengguna = ?');
$stmt->execute([$idGuru]);
$absenPertama = $stmt->fetchColumn();
if ($absenPertama && $absenPertama < $mulai) {
    $mulai = $absenPertama;
}

// ---------- Susun setiap tanggal dalam bulan ----------
$daftarHari = [];
$tgl = new DateTime($awal);
while ($tgl->format('Y-m-d') <= $akhir) {
    $tanggal  = $tgl->format('Y-m-d');
    $namaHari = NAMA_HARI[(int) $tgl->format('N')];
    $libur    = $namaHari === 'Minggu' ? 'Hari Minggu' : ($hariLibur[$tanggal] ?? null);

    $cuti = null;
    foreach ($daftarCuti as $c) {
        if ($c['tanggal_mulai'] <= $tanggal && $c['tanggal_selesai'] >= $tanggal) {
            $cuti = $c['jenis'];
            break;
        }
    }

    $jadwalHari = [];
    if ($libur === null) {
        foreach ($jadwalPerHari[$namaHari] ?? [] as $j) {
            if (substr((string) $j['dibuat_pada'], 0, 10) <= $tanggal) {
                $jadwalHari[] = $j;
            }
        }
    }

    $daftarHari[] = [
        'tanggal' => $tanggal,
        'hari'    => $namaHari,
        'libur'   => $libur,
        'cuti'    => $cuti,
        'mapel'   => gabung_jadwal_absensi($jadwalHari, $absensiPerTanggal[$tanggal] ?? []),
    ];
    $tgl->modify('+1 day');
}

kirim_json(200, true, 'Riwayat absen ' . $bulan . '.', [
    'bulan'           => $bulan,
    'hari_ini'        => date('Y-m-d', $sekarang),
    'waktu_server'    => date('Y-m-d H:i:s', $sekarang),
    'mulai'           => $mulai,
    'toleransi_menit' => (int) pengaturan_absen()['toleransi_terlambat'],
    'hari'            => $daftarHari,
]);
