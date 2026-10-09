<?php
/**
 * POST /api/admin/jadwal/simpan.php      (KHUSUS ADMIN)
 *
 * Menambah jadwal baru, atau mengubah jadwal lama jika "id_jadwal" diisi.
 * Body JSON:
 *   {
 *     "id_jadwal": 5,               (kosongkan untuk jadwal baru)
 *     "id_pengguna": 2, "hari": "Senin",
 *     "jam_mulai": "07:30", "jam_selesai": "09:00",
 *     "unit": "SD", "kelas": "3B", "mata_pelajaran": "Bahasa Indonesia"
 *   }
 *
 * Jadwal ditolak (409) jika BENTROK:
 *   - guru yang sama sudah mengajar di jam yang beririsan pada hari itu, atau
 *   - kelas yang sama sudah diajar guru lain di jam yang beririsan.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/jadwal.php';

wajib_method('POST');
wajib_login('admin');

$input      = ambil_input();
$idJadwal   = (int) ($input['id_jadwal'] ?? 0);
$idGuru     = (int) ($input['id_pengguna'] ?? 0);
$hari       = input_teks($input, 'hari');
$jamMulai   = input_teks($input, 'jam_mulai');
$jamSelesai = input_teks($input, 'jam_selesai');
$unit       = strtoupper(input_teks($input, 'unit'));
$kelas      = strtoupper(preg_replace('/\s+/', ' ', input_teks($input, 'kelas')));
$mapel      = preg_replace('/\s+/', ' ', input_teks($input, 'mata_pelajaran'));

// ---------- Validasi isian ----------
$kesalahan = [];
$polaJam   = '/^([01]\d|2[0-3]):[0-5]\d$/';

if (!in_array($hari, HARI_SEKOLAH, true)) {
    $kesalahan['hari'] = 'Pilih hari Senin sampai Sabtu.';
}
if (!preg_match($polaJam, $jamMulai)) {
    $kesalahan['jam_mulai'] = 'Jam mulai tidak valid (format JJ:MM).';
}
if (!preg_match($polaJam, $jamSelesai)) {
    $kesalahan['jam_selesai'] = 'Jam selesai tidak valid (format JJ:MM).';
} elseif (preg_match($polaJam, $jamMulai) && $jamSelesai <= $jamMulai) {
    $kesalahan['jam_selesai'] = 'Jam selesai harus setelah jam mulai.';
}
if (!in_array($unit, UNIT_SEKOLAH, true)) {
    $kesalahan['unit'] = 'Pilih unit KB, TK, atau SD.';
}
if (!preg_match('/^[0-9A-Za-z .\-]{1,20}$/', $kelas)) {
    $kesalahan['kelas'] = 'Kelas 1-20 karakter, contoh: 3B atau TK A.';
}
if (mb_strlen($mapel) < 2 || mb_strlen($mapel) > 100) {
    $kesalahan['mata_pelajaran'] = 'Mata pelajaran 2-100 karakter.';
}
if (!empty($kesalahan)) {
    kirim_json(422, false, reset($kesalahan), ['kesalahan' => $kesalahan]);
}

$cekGuru = db()->prepare("SELECT id_pengguna, status FROM pengguna WHERE id_pengguna = ? AND role = 'guru'");
$cekGuru->execute([$idGuru]);
$guru = $cekGuru->fetch();
if (!$guru) {
    kirim_json(404, false, 'Guru tidak ditemukan.');
}
if ($guru['status'] !== 'aktif') {
    kirim_json(422, false, 'Akun guru ini nonaktif, jadwal tidak bisa ditambahkan.');
}

if ($idJadwal > 0) {
    $cekJadwal = db()->prepare('SELECT id_jadwal FROM jadwal_mengajar WHERE id_jadwal = ?');
    $cekJadwal->execute([$idJadwal]);
    if (!$cekJadwal->fetch()) {
        kirim_json(404, false, 'Jadwal yang akan diubah tidak ditemukan.');
    }
}

// ---------- Cek bentrok ----------
// Dua rentang jam beririsan jika: mulai_A < selesai_B DAN mulai_B < selesai_A
$mulai   = $jamMulai . ':00';
$selesai = $jamSelesai . ':00';

$bentrokGuru = db()->prepare(
    'SELECT * FROM jadwal_mengajar
      WHERE id_pengguna = ? AND hari = ? AND jam_mulai < ? AND jam_selesai > ? AND id_jadwal <> ?
      LIMIT 1'
);
$bentrokGuru->execute([$idGuru, $hari, $selesai, $mulai, $idJadwal]);
if ($b = $bentrokGuru->fetch()) {
    kirim_json(409, false, sprintf(
        'Bentrok dengan jadwal guru ini: %s, %s-%s di kelas %s.',
        $b['mata_pelajaran'], substr($b['jam_mulai'], 0, 5), substr($b['jam_selesai'], 0, 5), $b['kelas']
    ));
}

$bentrokKelas = db()->prepare(
    'SELECT j.*, p.nama_lengkap, p.gelar
       FROM jadwal_mengajar j JOIN pengguna p ON p.id_pengguna = j.id_pengguna
      WHERE j.unit = ? AND j.kelas = ? AND j.hari = ? AND j.jam_mulai < ? AND j.jam_selesai > ?
        AND j.id_jadwal <> ? AND j.id_pengguna <> ?
      LIMIT 1'
);
$bentrokKelas->execute([$unit, $kelas, $hari, $selesai, $mulai, $idJadwal, $idGuru]);
if ($b = $bentrokKelas->fetch()) {
    kirim_json(409, false, sprintf(
        'Kelas %s %s pada jam itu sudah diajar oleh %s (%s, %s-%s).',
        $b['unit'], $b['kelas'], nama_dengan_gelar($b['nama_lengkap'], $b['gelar']), $b['mata_pelajaran'],
        substr($b['jam_mulai'], 0, 5), substr($b['jam_selesai'], 0, 5)
    ));
}

// ---------- Simpan ----------
$nilai = [$idGuru, $hari, $mulai, $selesai, $unit, $kelas, $mapel];
if ($idJadwal > 0) {
    $stmt = db()->prepare(
        'UPDATE jadwal_mengajar
            SET id_pengguna = ?, hari = ?, jam_mulai = ?, jam_selesai = ?, unit = ?, kelas = ?, mata_pelajaran = ?
          WHERE id_jadwal = ?'
    );
    $stmt->execute(array_merge($nilai, [$idJadwal]));
    $pesan = 'Jadwal berhasil diubah.';
} else {
    $stmt = db()->prepare(
        'INSERT INTO jadwal_mengajar (id_pengguna, hari, jam_mulai, jam_selesai, unit, kelas, mata_pelajaran)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute($nilai);
    $idJadwal = (int) db()->lastInsertId();
    $pesan = 'Jadwal berhasil ditambahkan.';
}

$ambil = db()->prepare('SELECT * FROM jadwal_mengajar WHERE id_jadwal = ?');
$ambil->execute([$idJadwal]);

kirim_json($pesan === 'Jadwal berhasil ditambahkan.' ? 201 : 200, true, $pesan, [
    'jadwal' => data_jadwal_publik($ambil->fetch()),
]);
