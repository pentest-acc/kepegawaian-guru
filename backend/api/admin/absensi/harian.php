<?php
/**
 * GET /api/admin/absensi/harian.php?tanggal=2026-11-24   (khusus admin)
 * Header: Authorization: Bearer <token>
 *
 * Monitoring absensi satu hari: setiap guru yang punya jadwal di hari itu,
 * beserta setiap mapelnya dan absensinya (null = belum absen).
 * 'cuti' = jenis cuti/izin/sakit guru yang disetujui untuk tanggal itu, atau null.
 * Bawaan tanggal = hari ini.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/jadwal.php';
require_once __DIR__ . '/../../../core/absen.php';
require_once __DIR__ . '/../../../core/cuti.php';

wajib_method('GET');
wajib_login('admin');

$sekarang = time();
$tanggal  = (string) ($_GET['tanggal'] ?? date('Y-m-d', $sekarang));
if (!tanggal_valid($tanggal)) {
    kirim_json(422, false, 'Tanggal tidak valid (format YYYY-MM-DD).');
}
$hari = NAMA_HARI[(int) date('N', strtotime($tanggal))];

// Jadwal semua guru aktif pada hari itu
$jadwal = db()->prepare(
    SQL_JADWAL . " JOIN pengguna p ON p.id_pengguna = j.id_pengguna
     WHERE j.hari = ? AND p.role = 'guru' AND p.status = 'aktif'
     ORDER BY j.jam_mulai"
);
$jadwal->execute([$hari]);

$absensi = db()->prepare(SQL_ABSENSI . ' WHERE a.tanggal = ?');
$absensi->execute([$tanggal]);

// Kelompokkan per guru
$jadwalGuru  = [];
$absensiGuru = [];
foreach ($jadwal->fetchAll() as $j) {
    $jadwalGuru[(int) $j['id_pengguna']][] = $j;
}
foreach ($absensi->fetchAll() as $a) {
    $absensiGuru[(int) $a['id_pengguna']][] = $a;
}

$idGuru = array_unique(array_merge(array_keys($jadwalGuru), array_keys($absensiGuru)));
$cuti   = cuti_disetujui_tanggal($tanggal);
$guru   = [];
if (!empty($idGuru)) {
    $tanda = implode(',', array_fill(0, count($idGuru), '?'));
    $stmt  = db()->prepare(
        "SELECT id_pengguna, nomor_induk, nama_lengkap, gelar, unit FROM pengguna
          WHERE id_pengguna IN ($tanda) ORDER BY nama_lengkap"
    );
    $stmt->execute(array_values($idGuru));
    foreach ($stmt->fetchAll() as $p) {
        $id     = (int) $p['id_pengguna'];
        $guru[] = [
            'id_pengguna' => $id,
            'nomor_induk' => $p['nomor_induk'],
            'nama_tampil' => nama_dengan_gelar($p['nama_lengkap'], $p['gelar']),
            'unit'        => $p['unit'],
            'cuti'        => $cuti[$id] ?? null,
            'mapel'       => gabung_jadwal_absensi($jadwalGuru[$id] ?? [], $absensiGuru[$id] ?? []),
        ];
    }
}

kirim_json(200, true, count($guru) . ' guru mengajar.', [
    'tanggal'         => $tanggal,
    'hari'            => $hari,
    'waktu_server'    => date('Y-m-d H:i:s', $sekarang),
    'libur'           => info_libur($tanggal),
    'toleransi_menit' => (int) pengaturan_absen()['toleransi_terlambat'],
    'guru'            => $guru,
]);
