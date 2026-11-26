<?php
/**
 * POST /api/cuti/ajukan.php   (multipart/form-data, khusus guru)
 * Header: Authorization: Bearer <token>
 *
 * Isian:
 *   jenis            : cuti / izin / sakit
 *   tanggal_mulai    : YYYY-MM-DD
 *   tanggal_selesai  : YYYY-MM-DD
 *   alasan           : 10-1000 karakter
 *   lampiran         : foto (JPG/PNG/WEBP, maks 5 MB), mis. surat dokter.
 *                      Wajib untuk sakit 2 hari kerja atau lebih.
 *
 * Aturan lengkap ada di core/cuti.php. Pengajuan baru berstatus "menunggu"
 * sampai disetujui / ditolak admin.
 */
require_once __DIR__ . '/../../core/bootstrap.php';
require_once __DIR__ . '/../../core/cuti.php';

wajib_method('POST');
$pengguna = wajib_login('guru');
$idGuru   = (int) $pengguna['id_pengguna'];

[$jenis, $mulai, $selesai, $hari] = periksa_pengajuan_cuti($idGuru, $_POST);

$alasan = trim(preg_replace('/[ \t]+/', ' ', (string) ($_POST['alasan'] ?? '')));
if (mb_strlen($alasan) < 10) {
    kirim_json(422, false, 'Tuliskan alasan minimal 10 karakter.', ['kesalahan' => ['alasan' => 'Alasan minimal 10 karakter.']]);
}
if (mb_strlen($alasan) > 1000) {
    kirim_json(422, false, 'Alasan maksimal 1000 karakter.', ['kesalahan' => ['alasan' => 'Alasan maksimal 1000 karakter.']]);
}

$adaFile = isset($_FILES['lampiran']['error']) && $_FILES['lampiran']['error'] !== UPLOAD_ERR_NO_FILE;
if ($jenis === 'sakit' && count($hari) >= CUTI_SAKIT_WAJIB_SURAT && !$adaFile) {
    kirim_json(422, false, 'Sakit ' . CUTI_SAKIT_WAJIB_SURAT . ' hari atau lebih wajib melampirkan foto surat dokter.');
}

$lampiran = simpan_lampiran_cuti($idGuru);
try {
    db()->prepare(
        'INSERT INTO cuti (id_pengguna, jenis, tanggal_mulai, tanggal_selesai, jumlah_hari, alasan, lampiran, dibuat_pada)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    )->execute([$idGuru, $jenis, $mulai, $selesai, count($hari), $alasan, $lampiran, date('Y-m-d H:i:s')]);
} catch (Throwable $e) {
    hapus_lampiran_cuti($lampiran);
    throw $e;
}

kirim_json(201, true, sprintf(
    'Pengajuan %s %s (%d hari) terkirim. Tunggu persetujuan admin.',
    strtolower(label_jenis_cuti($jenis)),
    rentang_tanggal($mulai, $selesai),
    count($hari)
), [
    'cuti'  => data_cuti_publik(cuti_by_id(db()->lastInsertId())),
    'kuota' => kuota_cuti($idGuru, date('Y')),
]);
