<?php
/**
 * POST /api/absen/masuk.php   (multipart/form-data, khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Isian:
 *   foto          : file foto selfie (JPG/PNG/WEBP)
 *   lat, lng      : lokasi GPS saat absen
 *   lokasi_palsu  : "1" jika HP mendeteksi Fake GPS (opsional)
 *
 * Jam masuk diambil dari jam server. Lewat dari jam masuk unit + toleransi
 * dicatat "terlambat".
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

// ---------- Boleh absen masuk sekarang? ----------
$libur = info_libur($tanggal);
if ($libur !== null) {
    kirim_json(422, false, 'Hari ini libur (' . $libur . '), tidak perlu absen.');
}

$jamKerja = jam_kerja_unit($pengguna['unit']);
$mulai    = $GLOBALS['config_app']['absen_masuk_mulai'];
if ($detikIni < detik_dari_jam($mulai)) {
    kirim_json(422, false, 'Absen masuk dibuka mulai pukul ' . jam_titik($mulai) . '.');
}
if ($detikIni >= detik_dari_jam($jamKerja['jam_pulang'])) {
    kirim_json(422, false, 'Waktu absen masuk sudah lewat (jam pulang ' . jam_titik($jamKerja['jam_pulang'])
        . '). Silakan hubungi admin.');
}

$ada = absensi_guru($idGuru, $tanggal);
if ($ada && in_array($ada['status'], STATUS_TANPA_ABSEN, true)) {
    kirim_json(409, false, 'Hari ini kamu tercatat ' . $ada['status'] . ', jadi tidak perlu absen.');
}
if ($ada && $ada['jam_masuk'] !== null) {
    kirim_json(409, false, 'Kamu sudah absen masuk hari ini pukul ' . jam_titik($ada['jam_masuk']) . '.');
}

// ---------- Lokasi & foto ----------
list($lat, $lng) = baca_lokasi($_POST);
$pengaturan = pengaturan_absen();
$jarak      = periksa_jarak($lat, $lng, $pengaturan);
$foto       = simpan_foto_absen($idGuru, 'masuk');

// ---------- Terlambat? ----------
$selisihDetik   = $detikIni - detik_dari_jam($jamKerja['jam_masuk']);
$terlambat      = $selisihDetik > (int) $pengaturan['toleransi_terlambat'] * 60;
$status         = $terlambat ? 'terlambat' : 'hadir';
$menitTerlambat = $terlambat ? intdiv($selisihDetik, 60) : 0;

try {
    if ($ada) {
        $stmt = db()->prepare(
            'UPDATE absensi SET jam_masuk = ?, foto_masuk = ?, lat_masuk = ?, lng_masuk = ?, jarak_masuk = ?,
                    status = ?, menit_terlambat = ?
              WHERE id_absensi = ? AND jam_masuk IS NULL'
        );
        $stmt->execute([$jamSekarang, $foto, $lat, $lng, $jarak, $status, $menitTerlambat, $ada['id_absensi']]);
        if ($stmt->rowCount() === 0) {
            hapus_foto_absen($foto);
            kirim_json(409, false, 'Kamu sudah absen masuk hari ini.');
        }
    } else {
        $stmt = db()->prepare(
            'INSERT INTO absensi (id_pengguna, tanggal, jam_masuk, foto_masuk, lat_masuk, lng_masuk, jarak_masuk,
                                  status, menit_terlambat)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $stmt->execute([$idGuru, $tanggal, $jamSekarang, $foto, $lat, $lng, $jarak, $status, $menitTerlambat]);
    }
} catch (PDOException $e) {
    hapus_foto_absen($foto);
    if ($e->getCode() === '23000') {
        // Dua kali tekan tombol bersamaan: baris hari ini sudah dibuat
        kirim_json(409, false, 'Kamu sudah absen masuk hari ini.');
    }
    throw $e;
}

$pesan = 'Absen masuk berhasil pukul ' . jam_titik($jamSekarang) . '.';
if ($terlambat) {
    $pesan .= ' Kamu terlambat ' . $menitTerlambat . ' menit.';
}

kirim_json(201, true, $pesan, [
    'absensi' => data_absensi_publik(absensi_guru($idGuru, $tanggal)),
]);
