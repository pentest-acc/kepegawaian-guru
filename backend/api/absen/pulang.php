<?php
/**
 * POST /api/absen/pulang.php   (multipart/form-data, khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Isian sama dengan absen/masuk.php (foto, lat, lng, lokasi_palsu).
 *
 * Absen pulang dibuka mulai jam pulang PALING AWAL di tabel jam_kerja_unit
 * (mis. 13.00, jam pulang guru TK). Guru unit lain yang absen pulang sebelum
 * jam pulang unitnya tetap bisa, tetapi dicatat "pulang lebih awal"
 * (menit_pulang_awal) agar terlihat di rekap admin.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/absen.php';

wajib_method('POST');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

$sekarang    = time();
$tanggal     = date('Y-m-d', $sekarang);
$jamSekarang = date('H:i:s', $sekarang);
$detikIni    = detik_dari_jam($jamSekarang);

// ---------- Boleh absen pulang sekarang? ----------
$absensi = absensi_guru($idGuru, $tanggal);
if (!$absensi || $absensi['jam_masuk'] === null) {
    kirim_json(422, false, 'Kamu belum absen masuk hari ini.');
}
if ($absensi['jam_pulang'] !== null) {
    kirim_json(409, false, 'Kamu sudah absen pulang hari ini pukul ' . jam_titik($absensi['jam_pulang']) . '.');
}

$buka = jam_buka_absen_pulang();
if ($detikIni < detik_dari_jam($buka)) {
    kirim_json(422, false, 'Absen pulang dibuka mulai pukul ' . jam_titik($buka) . '.');
}

// ---------- Lokasi & foto ----------
list($lat, $lng) = baca_lokasi($_POST);
$jarak = periksa_jarak($lat, $lng, pengaturan_absen());
$foto  = simpan_foto_absen($idGuru, 'pulang');

// ---------- Pulang lebih awal? ----------
$jamKerja    = jam_kerja_unit($pengguna['unit']);
$sisaDetik   = detik_dari_jam($jamKerja['jam_pulang']) - $detikIni;
$menitAwal   = $sisaDetik > 0 ? (int) ceil($sisaDetik / 60) : 0;

$stmt = db()->prepare(
    'UPDATE absensi SET jam_pulang = ?, foto_pulang = ?, lat_pulang = ?, lng_pulang = ?, jarak_pulang = ?,
            menit_pulang_awal = ?
      WHERE id_absensi = ? AND jam_pulang IS NULL'
);
$stmt->execute([$jamSekarang, $foto, $lat, $lng, $jarak, $menitAwal, $absensi['id_absensi']]);
if ($stmt->rowCount() === 0) {
    hapus_foto_absen($foto);
    kirim_json(409, false, 'Kamu sudah absen pulang hari ini.');
}

$pesan = 'Absen pulang berhasil pukul ' . jam_titik($jamSekarang) . '.';
if ($menitAwal > 0) {
    $pesan .= ' Tercatat pulang lebih awal ' . $menitAwal . ' menit (jam pulang unit '
        . $jamKerja['unit'] . ' pukul ' . jam_titik($jamKerja['jam_pulang']) . ').';
}

kirim_json(200, true, $pesan, [
    'absensi' => data_absensi_publik(absensi_guru($idGuru, $tanggal)),
]);
