-- =====================================================================
--  MIGRASI SESI 2  (Sesi 1 -> Sesi 2)
--
--  Pakai file ini HANYA jika database Sesi 1 sudah berisi data yang ingin
--  dipertahankan (mis. akun guru yang sudah didaftarkan).
--  Jika belum ada data penting, lebih mudah import ulang file
--  database/db_kepegawaian_guru.sql (semua tabel dibuat ulang).
--
--  Cara menjalankan: phpMyAdmin -> tab "Import" -> pilih file ini -> "Import".
--  Cukup dijalankan SATU KALI.
--
--  Isi perubahan:
--    1. Kolom baru pengguna.gelar (nama dan gelar dipisah)
--    2. Tabel baru percobaan_login (kunci sementara jika salah sandi 5x)
--    3. Info kegiatan contoh diganti 5 info baru (+ lampiran PDF)
--    4. Alamat yayasan diperbarui
-- =====================================================================

USE db_kepegawaian_guru;
SET NAMES utf8mb4;
SET time_zone = '+07:00';

-- 1. Kolom gelar ---------------------------------------------------------
ALTER TABLE pengguna
  MODIFY nama_lengkap VARCHAR(100) NOT NULL COMMENT 'Nama tanpa gelar',
  ADD COLUMN gelar VARCHAR(30) NULL COMMENT 'Gelar akademik, mis. S.Pd. atau Drs.' AFTER nama_lengkap;

-- Pisahkan nama yang sudah berisi gelar, mis. "Siti Aminah, S.Pd."
-- (gelar diisi lebih dulu karena masih membaca nama_lengkap yang lama)
UPDATE pengguna
   SET gelar        = NULLIF(TRIM(SUBSTRING(nama_lengkap, LOCATE(',', nama_lengkap) + 1)), ''),
       nama_lengkap = TRIM(SUBSTRING_INDEX(nama_lengkap, ',', 1))
 WHERE nama_lengkap LIKE '%,%';

-- 2. Tabel percobaan_login -----------------------------------------------
CREATE TABLE IF NOT EXISTS percobaan_login (
  id_percobaan      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  identitas         VARCHAR(100)     NOT NULL COMMENT 'akun:<id_pengguna>, atau email/NIY yang dicoba jika akun tidak ada',
  alamat_ip         VARCHAR(45)      NULL,
  waktu             DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_percobaan),
  KEY idx_percobaan_identitas_waktu (identitas, waktu)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Info kegiatan contoh ------------------------------------------------
DELETE FROM info_kegiatan
 WHERE dibuat_oleh = 1
   AND judul IN ('Pengumuman Pengambilan Raport UAS Semester Ganjil', 'Rapat Guru Bulanan');

INSERT INTO info_kegiatan (judul, isi, kategori, tanggal_kegiatan, lampiran, status, dibuat_oleh, dibuat_pada)
VALUES
  ('Pengumuman Pengambilan Raport UAS Semester Ganjil',
   'Pengambilan raport hasil UAS semester ganjil dilaksanakan oleh orang tua/wali murid di kelas masing-masing pukul 08.00-11.00 WIB. Wali kelas dimohon menyiapkan raport dan daftar hadir orang tua paling lambat dua hari sebelumnya. Jadwal per kelas dapat diunduh pada lampiran.',
   'Pengumuman', '2026-12-19', 'jadwal-pengambilan-raport-semester-ganjil.pdf', 'terbit', 1, '2026-10-04 07:30:00'),
  ('Rapat Guru Bulanan',
   'Rapat koordinasi seluruh guru KB, TK, dan SD di ruang guru pukul 13.00 WIB. Agenda: evaluasi pembelajaran bulan September dan persiapan kegiatan akhir Oktober. Mohon hadir tepat waktu.',
   'Rapat', '2026-10-15', NULL, 'terbit', 1, '2026-10-06 09:00:00'),
  ('Pelatihan Penggunaan Aplikasi Kepegawaian Guru',
   'Seluruh guru diharapkan mengikuti pelatihan penggunaan aplikasi kepegawaian (absen online, pengajuan cuti, dan info kegiatan) di ruang komputer pukul 13.30 WIB. Silakan membawa HP masing-masing.',
   'Acara', '2026-10-20', NULL, 'terbit', 1, '2026-10-07 10:15:00'),
  ('Batas Pengumpulan Perangkat Ajar Semester Ganjil',
   'Guru dimohon mengumpulkan perangkat ajar (modul ajar dan asesmen) semester ganjil kepada Kepala Sekolah unit masing-masing paling lambat Sabtu, 17 Oktober 2026.',
   'Pengumuman', '2026-10-17', NULL, 'terbit', 1, '2026-10-08 08:00:00'),
  ('Upacara Peringatan Hari Sumpah Pemuda',
   'Upacara peringatan Hari Sumpah Pemuda dilaksanakan di halaman sekolah pukul 07.00 WIB. Guru dan siswa SD memakai seragam putih-merah, siswa KB/TK memakai seragam olahraga.',
   'Acara', '2026-10-28', NULL, 'terbit', 1, '2026-10-09 07:45:00');

-- 4. Alamat yayasan --------------------------------------------------------
UPDATE pengaturan
   SET alamat_yayasan = 'PUP Sektor V Blok O2 No. 1-5, Kel. Bahagia, Kec. Babelan, Kab. Bekasi'
 WHERE id_pengaturan = 1;
