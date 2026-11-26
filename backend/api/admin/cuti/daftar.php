<?php
/**
 * GET /api/admin/cuti/daftar.php?status=menunggu   (khusus admin)
 * Header: Authorization: Bearer <token>
 *
 * Daftar pengajuan cuti / izin / sakit semua guru.
 *   status : menunggu (bawaan), disetujui, ditolak, atau semua
 *   cari   : nama / NIY guru (opsional)
 * "menunggu" diurutkan dari yang paling lama diajukan (diproses lebih dulu),
 * selainnya dari yang terbaru. Setiap pengajuan menyertakan jumlah mapel
 * yang ditinggalkan guru. Maksimal 200 data.
 */
require_once __DIR__ . '/../../../core/bootstrap.php';
require_once __DIR__ . '/../../../core/cuti.php';

wajib_method('GET');
wajib_login('admin');

$status = strtolower(trim((string) ($_GET['status'] ?? 'menunggu')));
if (!in_array($status, array_merge(STATUS_CUTI, ['semua']), true)) {
    kirim_json(422, false, 'Status tidak valid (menunggu, disetujui, ditolak, atau semua).');
}
$cari = trim((string) ($_GET['cari'] ?? ''));

$where  = [];
$params = [];
if ($status !== 'semua') {
    $where[]  = 'c.status = ?';
    $params[] = $status;
}
if ($cari !== '') {
    $where[]  = '(p.nama_lengkap LIKE ? OR p.nomor_induk LIKE ?)';
    $params[] = '%' . $cari . '%';
    $params[] = '%' . $cari . '%';
}
$urut = $status === 'menunggu'
    ? 'c.dibuat_pada ASC, c.id_cuti ASC'
    : 'COALESCE(c.diproses_pada, c.dibuat_pada) DESC, c.id_cuti DESC';

$stmt = db()->prepare(
    SQL_CUTI . ($where ? ' WHERE ' . implode(' AND ', $where) : '') . ' ORDER BY ' . $urut . ' LIMIT 200'
);
$stmt->execute($params);

$daftar = [];
foreach ($stmt->fetchAll() as $c) {
    $data = data_cuti_publik($c);
    $data['jumlah_mapel'] = jumlah_mapel_ditinggalkan(
        mapel_ditinggalkan((int) $c['id_pengguna'], hari_kerja_cuti($c['tanggal_mulai'], $c['tanggal_selesai']))
    );
    $daftar[] = $data;
}

$jumlahMenunggu = (int) db()->query("SELECT COUNT(*) FROM cuti WHERE status = 'menunggu'")->fetchColumn();

kirim_json(200, true, count($daftar) . ' pengajuan.', [
    'jumlah_menunggu' => $jumlahMenunggu,
    'pengajuan'       => $daftar,
]);
