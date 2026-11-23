<?php
/**
 * POST /api/admin/absensi/ubah.php   (khusus admin, body JSON)
 * Header: Authorization: Bearer <token>
 *
 * Admin menandai / mengubah kehadiran guru untuk satu mapel, mis. guru lupa
 * absen, izin, sakit, atau alpa.
 * {
 *   "id_jadwal": 5, "tanggal": "2026-11-24",   (mapel yang belum punya absensi)
 *   "id_absensi": 12,                          (atau absensi yang sudah ada)
 *   "status": "hadir",       (hadir/terlambat/izin/sakit/cuti/alpa, atau "belum")
 *   "keterangan": "Lupa absen, dikonfirmasi kepala sekolah"
 * }
 *
 * "belum" menghapus tanda dari admin (kembali menjadi belum absen). Absen yang
 * berisi foto dari guru tidak bisa dihapus, hanya bisa diubah statusnya.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/jadwal.php';
require_once __DIR__ . '/../../../core/absen.php';

wajib_method('POST');
$admin = wajib_login('admin');

$input      = ambil_input();
$idAbsensi  = (int) ($input['id_absensi'] ?? 0);
$idJadwal   = (int) ($input['id_jadwal'] ?? 0);
$tanggal    = input_teks($input, 'tanggal');
$status     = strtolower(input_teks($input, 'status'));
$keterangan = preg_replace('/\s+/', ' ', input_teks($input, 'keterangan'));

if (!in_array($status, array_merge(STATUS_KEHADIRAN, ['belum']), true)) {
    kirim_json(422, false, 'Pilih status: hadir, terlambat, izin, sakit, cuti, alpa, atau belum.');
}
if (mb_strlen($keterangan) > 255) {
    kirim_json(422, false, 'Keterangan maksimal 255 karakter.');
}

// ---------- Cari absensi / jadwal yang diubah ----------
$jadwal = null;
if ($idAbsensi > 0) {
    $absensi = absensi_by_id($idAbsensi);
    if (!$absensi) {
        kirim_json(404, false, 'Data absensi tidak ditemukan.');
    }
} else {
    if (!tanggal_valid($tanggal)) {
        kirim_json(422, false, 'Tanggal tidak valid (format YYYY-MM-DD).');
    }
    $stmt = db()->prepare(SQL_JADWAL . ' WHERE j.id_jadwal = ?');
    $stmt->execute([$idJadwal]);
    $jadwal = $stmt->fetch();
    if (!$jadwal) {
        kirim_json(404, false, 'Jadwal mengajar tidak ditemukan.');
    }
    $hari = NAMA_HARI[(int) date('N', strtotime($tanggal))];
    if ($jadwal['hari'] !== $hari) {
        kirim_json(422, false, 'Jadwal ini hari ' . $jadwal['hari'] . ', sedangkan tanggal ' . $tanggal
            . ' adalah hari ' . $hari . '.');
    }
    $absensi = absensi_jadwal($idJadwal, $tanggal);
}

// ---------- Hapus tanda admin ----------
if ($status === 'belum') {
    if ($absensi && $absensi['foto'] !== null) {
        kirim_json(422, false, 'Absen dengan foto dari guru tidak bisa dihapus. Ubah statusnya saja.');
    }
    if ($absensi) {
        db()->prepare('DELETE FROM absensi WHERE id_absensi = ?')->execute([$absensi['id_absensi']]);
    }
    kirim_json(200, true, 'Tanda kehadiran dihapus (kembali menjadi belum absen).', ['absensi' => null]);
}

// ---------- Simpan tanda admin ----------
$idAdmin = (int) $admin['id_pengguna'];
if ($absensi) {
    // Menit terlambat hanya berlaku untuk status "terlambat" dari jam absen guru
    $menit = 0;
    if ($status === 'terlambat' && $absensi['jam_absen'] !== null) {
        $menit = max(0, intdiv(detik_dari_jam($absensi['jam_absen']) - detik_dari_jam($absensi['jam_mulai']), 60));
    }
    db()->prepare(
        'UPDATE absensi SET status = ?, menit_terlambat = ?, keterangan = ?, dikoreksi_oleh = ? WHERE id_absensi = ?'
    )->execute([$status, $menit, $keterangan !== '' ? $keterangan : null, $idAdmin, $absensi['id_absensi']]);
    $idAbsensi = (int) $absensi['id_absensi'];
} else {
    db()->prepare(
        'INSERT INTO absensi (id_pengguna, id_jadwal, tanggal, mata_pelajaran, unit, kelas, jam_mulai, jam_selesai,
                              status, keterangan, dikoreksi_oleh)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    )->execute([
        $jadwal['id_pengguna'], $jadwal['id_jadwal'], $tanggal, $jadwal['mata_pelajaran'], $jadwal['unit'],
        $jadwal['kelas'], $jadwal['jam_mulai'], $jadwal['jam_selesai'], $status,
        $keterangan !== '' ? $keterangan : null, $idAdmin,
    ]);
    $idAbsensi = (int) db()->lastInsertId();
}

kirim_json(200, true, 'Kehadiran disimpan.', ['absensi' => data_absensi_publik(absensi_by_id($idAbsensi))]);
