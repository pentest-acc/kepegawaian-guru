<?php
/**
 * Fungsi bantu untuk fitur Info Kegiatan.
 */

/**
 * Query dasar info kegiatan yang sudah terbit, sekaligus menandai apakah
 * info tersebut ditandai "penting" (bintang) oleh pengguna yang login.
 * Parameter pertama query ini selalu id_pengguna.
 */
const SQL_INFO_DASAR = '
    SELECT i.id_info, i.judul, i.isi, i.kategori, i.tanggal_kegiatan,
           i.lampiran, i.dibuat_pada,
           (p.id_info IS NOT NULL) AS penting
      FROM info_kegiatan i
      LEFT JOIN info_penting p
             ON p.id_info = i.id_info AND p.id_pengguna = ?
     WHERE i.status = \'terbit\'';

/**
 * Ubah baris info_kegiatan menjadi data JSON untuk aplikasi.
 */
function data_info_publik(array $baris)
{
    $lampiran = null;
    if (!empty($baris['lampiran'])) {
        $lampiran = [
            'nama' => $baris['lampiran'],
            'url'  => url_backend() . '/uploads/lampiran/' . rawurlencode($baris['lampiran']),
        ];
    }

    return [
        'id_info'          => (int) $baris['id_info'],
        'judul'            => $baris['judul'],
        'isi'              => $baris['isi'],
        'kategori'         => $baris['kategori'],
        'tanggal_kegiatan' => $baris['tanggal_kegiatan'],
        'dibuat_pada'      => $baris['dibuat_pada'],
        'lampiran'         => $lampiran,
        'penting'          => (bool) $baris['penting'],
    ];
}
