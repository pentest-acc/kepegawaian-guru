<?php
/**
 * POST /api/admin/cuti/proses.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 * {
 *   "id_cuti": 5,
 *   "keputusan": "disetujui",          (disetujui / ditolak)
 *   "catatan": "Semoga lekas sembuh"   (wajib jika ditolak, maks 255 karakter)
 * }
 *
 * Hanya pengajuan yang masih "menunggu" yang bisa diproses. Cuti hanya bisa
 * disetujui jika kuota tahunan guru masih cukup.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/cuti.php';

wajib_method('POST');
$admin = wajib_login('admin');
$input = ambil_input();

$keputusan = strtolower(input_teks($input, 'keputusan'));
$catatan   = preg_replace('/\s+/', ' ', input_teks($input, 'catatan'));
if (!in_array($keputusan, ['disetujui', 'ditolak'], true)) {
    kirim_json(422, false, 'Pilih keputusan: disetujui atau ditolak.');
}
if ($keputusan === 'ditolak' && mb_strlen($catatan) < 5) {
    kirim_json(422, false, 'Tuliskan alasan penolakan (minimal 5 karakter) agar guru mengetahuinya.',
        ['kesalahan' => ['catatan' => 'Alasan penolakan wajib diisi.']]);
}
if (mb_strlen($catatan) > 255) {
    kirim_json(422, false, 'Catatan maksimal 255 karakter.', ['kesalahan' => ['catatan' => 'Maksimal 255 karakter.']]);
}

$cuti = cuti_by_id((int) ($input['id_cuti'] ?? 0));
if (!$cuti) {
    kirim_json(404, false, 'Pengajuan tidak ditemukan.');
}
if ($cuti['status'] !== 'menunggu') {
    kirim_json(409, false, 'Pengajuan ini sudah ' . $cuti['status'] . ' sebelumnya.');
}

$idGuru = (int) $cuti['id_pengguna'];
$nama   = nama_dengan_gelar($cuti['nama_lengkap'], $cuti['gelar']);
if ($keputusan === 'disetujui') {
    $tumpuk = cuti_bertumpuk($idGuru, $cuti['tanggal_mulai'], $cuti['tanggal_selesai'], $cuti['id_cuti'], true);
    if ($tumpuk) {
        kirim_json(409, false, sprintf(
            'Tanggalnya bertumpuk dengan %s %s milik %s yang sudah disetujui.',
            strtolower(label_jenis_cuti($tumpuk['jenis'])),
            rentang_tanggal($tumpuk['tanggal_mulai'], $tumpuk['tanggal_selesai']),
            $nama
        ));
    }
    if ($cuti['jenis'] === 'cuti') {
        $kuota = kuota_cuti($idGuru, substr($cuti['tanggal_mulai'], 0, 4), $cuti['id_cuti']);
        if ($kuota['terpakai'] + (int) $cuti['jumlah_hari'] > $kuota['kuota']) {
            kirim_json(422, false, sprintf(
                'Kuota cuti %s tahun %d tidak cukup: sudah terpakai %d dari %d hari, pengajuan ini %d hari.',
                $nama,
                $kuota['tahun'],
                $kuota['terpakai'],
                $kuota['kuota'],
                (int) $cuti['jumlah_hari']
            ), ['kuota' => $kuota]);
        }
    }
}

db()->prepare(
    "UPDATE cuti SET status = ?, catatan_admin = ?, diproses_oleh = ?, diproses_pada = ?
      WHERE id_cuti = ? AND status = 'menunggu'"
)->execute([$keputusan, $catatan === '' ? null : $catatan, $admin['id_pengguna'], date('Y-m-d H:i:s'), $cuti['id_cuti']]);

kirim_json(200, true, sprintf(
    'Pengajuan %s %s %s.',
    strtolower(label_jenis_cuti($cuti['jenis'])),
    $nama,
    $keputusan
), [
    'cuti'  => data_cuti_publik(cuti_by_id($cuti['id_cuti'])),
    'kuota' => kuota_cuti($idGuru, substr($cuti['tanggal_mulai'], 0, 4)),
]);
