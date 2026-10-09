<?php
/**
 * Fungsi bantu untuk fitur Jadwal Mengajar.
 *
 * Konsep: jadwal disimpan sebagai JADWAL MINGGUAN (hari + jam), sehingga
 * otomatis berulang setiap minggu. Admin cukup mengubah datanya jika ada
 * perubahan. Tanggal di tabel hari_libur dianggap tidak ada kegiatan.
 */

const HARI_SEKOLAH = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const UNIT_SEKOLAH = ['KB', 'TK', 'SD'];

/** Urutan jadwal: Senin -> Sabtu, lalu jam mulai paling pagi. */
const SQL_URUT_JADWAL = "ORDER BY FIELD(j.hari, 'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'), j.jam_mulai";

/**
 * Ubah baris jadwal_mengajar menjadi data JSON untuk aplikasi.
 * Jam dikirim dalam format "HH:MM".
 */
function data_jadwal_publik(array $b)
{
    return [
        'id_jadwal'      => (int) $b['id_jadwal'],
        'id_pengguna'    => (int) $b['id_pengguna'],
        'hari'           => $b['hari'],
        'jam_mulai'      => substr($b['jam_mulai'], 0, 5),
        'jam_selesai'    => substr($b['jam_selesai'], 0, 5),
        'unit'           => $b['unit'],
        'kelas'          => $b['kelas'],
        'mata_pelajaran' => $b['mata_pelajaran'],
    ];
}

/**
 * Cek format tanggal YYYY-MM-DD dan apakah tanggalnya benar-benar ada.
 */
function tanggal_valid($teks)
{
    if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $teks, $m)) {
        return false;
    }
    return checkdate((int) $m[2], (int) $m[3], (int) $m[1]);
}

/**
 * Nama guru beserta gelarnya, mis. "Siti Aminah, S.Pd." atau "Drs. Budi".
 */
function nama_dengan_gelar($nama, $gelar)
{
    $gelar = trim((string) $gelar);
    if ($gelar === '') {
        return $nama;
    }
    if (in_array($gelar, ['Dr.', 'Drs.', 'Dra.', 'Ir.', 'H.', 'Hj.'], true)) {
        return $gelar . ' ' . $nama;
    }
    return $nama . ', ' . $gelar;
}
