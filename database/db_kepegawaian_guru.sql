-- =====================================================================
--  DATABASE  : db_kepegawaian_guru
--  PROJECT   : Sistem Informasi Kepegawaian Guru
--              Yayasan Tiara Harapan Jaya (KB / TK / SD)
--  DBMS      : MySQL 5.7+ / MariaDB 10.3+ (Laragon atau XAMPP)
--
--  Cara import (Laragon / XAMPP) lewat phpMyAdmin:
--    1. Laragon: klik "Start All", lalu klik tombol "Database"
--       (XAMPP: Start Apache & MySQL, buka http://localhost/phpmyadmin).
--    2. Login: username root, password dikosongkan.
--    3. Klik tab "Import" -> "Choose File" -> pilih file ini -> klik "Import".
--    Atau lewat Terminal Laragon:
--       mysql -u root -e "source database/db_kepegawaian_guru.sql"
--  Database db_kepegawaian_guru otomatis dibuat oleh file ini,
--  jadi tidak perlu membuat/memilih database terlebih dahulu.
--
--  PERHATIAN: file ini menghapus (DROP) tabel lama lalu membuat ulang.
--             Jangan import ulang jika sudah berisi data asli!
-- =====================================================================

CREATE DATABASE IF NOT EXISTS db_kepegawaian_guru
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_kepegawaian_guru;

SET NAMES utf8mb4;
SET time_zone = '+07:00';
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS info_penting;
DROP TABLE IF EXISTS info_kegiatan;
DROP TABLE IF EXISTS jadwal_mengajar;
DROP TABLE IF EXISTS absensi;
DROP TABLE IF EXISTS cuti;
DROP TABLE IF EXISTS hari_libur;
DROP TABLE IF EXISTS pengaturan;
DROP TABLE IF EXISTS token_login;
DROP TABLE IF EXISTS percobaan_login;
DROP TABLE IF EXISTS pengguna;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. pengguna : akun login sekaligus biodata Guru dan Admin
-- ---------------------------------------------------------------------
CREATE TABLE pengguna (
  id_pengguna       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  nomor_induk       VARCHAR(30)      NOT NULL COMMENT 'Nomor Induk Yayasan (NIY)',
  nama_lengkap      VARCHAR(100)     NOT NULL COMMENT 'Nama tanpa gelar',
  gelar             VARCHAR(30)      NULL COMMENT 'Gelar akademik, mis. S.Pd. atau Drs.',
  email             VARCHAR(100)     NOT NULL,
  no_hp             VARCHAR(20)      NULL,
  password          VARCHAR(255)     NOT NULL COMMENT 'Hash bcrypt, bukan kata sandi asli',
  role              ENUM('guru','admin') NOT NULL DEFAULT 'guru',
  jabatan           VARCHAR(50)      NOT NULL DEFAULT 'Guru',
  unit              ENUM('KB','TK','SD') NULL COMMENT 'Unit tempat mengajar',
  jenis_kelamin     ENUM('L','P')    NULL,
  tempat_lahir      VARCHAR(50)      NULL,
  tanggal_lahir     DATE             NULL,
  alamat            TEXT             NULL,
  foto              VARCHAR(255)     NULL COMMENT 'Path file foto profil',
  notifikasi_aktif  BOOLEAN          NOT NULL DEFAULT 1,
  status            ENUM('aktif','nonaktif') NOT NULL DEFAULT 'aktif',
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pengguna),
  UNIQUE KEY uk_pengguna_nomor_induk (nomor_induk),
  UNIQUE KEY uk_pengguna_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. token_login : token sesi login aplikasi (satu pengguna bisa login
--    di beberapa perangkat sekaligus)
-- ---------------------------------------------------------------------
CREATE TABLE token_login (
  id_token          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_pengguna       INT UNSIGNED     NOT NULL,
  token_hash        CHAR(64)         NOT NULL COMMENT 'SHA-256 dari token yang dipegang aplikasi',
  perangkat         VARCHAR(100)     NULL,
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  kedaluwarsa_pada  DATETIME         NOT NULL,
  PRIMARY KEY (id_token),
  UNIQUE KEY uk_token_hash (token_hash),
  KEY idx_token_pengguna (id_pengguna),
  CONSTRAINT fk_token_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. info_kegiatan : informasi & pengumuman kegiatan Yayasan
-- ---------------------------------------------------------------------
CREATE TABLE info_kegiatan (
  id_info           INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  judul             VARCHAR(150)     NOT NULL,
  isi               TEXT             NOT NULL,
  kategori          ENUM('Pengumuman','Rapat','Acara','Libur','Lainnya') NOT NULL DEFAULT 'Pengumuman',
  tanggal_kegiatan  DATE             NOT NULL,
  lampiran          VARCHAR(255)     NULL COMMENT 'Path file lampiran yang bisa diunduh guru',
  status            ENUM('draf','terbit') NOT NULL DEFAULT 'terbit',
  dibuat_oleh       INT UNSIGNED     NULL,
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_info),
  KEY idx_info_tanggal (tanggal_kegiatan),
  CONSTRAINT fk_info_pembuat FOREIGN KEY (dibuat_oleh)
    REFERENCES pengguna (id_pengguna) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. info_penting : info kegiatan yang ditandai bintang (penting) oleh guru
-- ---------------------------------------------------------------------
CREATE TABLE info_penting (
  id_pengguna       INT UNSIGNED     NOT NULL,
  id_info           INT UNSIGNED     NOT NULL,
  ditandai_pada     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pengguna, id_info),
  KEY idx_penting_info (id_info),
  CONSTRAINT fk_penting_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_penting_info FOREIGN KEY (id_info)
    REFERENCES info_kegiatan (id_info) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 5. jadwal_mengajar : jadwal mengajar MINGGUAN setiap guru
--    Satu baris = satu jam pelajaran pada hari tertentu, dan otomatis
--    berlaku SETIAP MINGGU (tidak perlu diisi ulang tiap minggu).
--    Admin cukup mengubah baris ini jika ada perubahan jadwal/mapel.
--    Tanggal yang ada di tabel hari_libur otomatis dianggap libur.
-- ---------------------------------------------------------------------
CREATE TABLE jadwal_mengajar (
  id_jadwal         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_pengguna       INT UNSIGNED     NOT NULL COMMENT 'Guru yang mengajar',
  hari              ENUM('Senin','Selasa','Rabu','Kamis','Jumat','Sabtu') NOT NULL,
  jam_mulai         TIME             NOT NULL,
  jam_selesai       TIME             NOT NULL,
  unit              ENUM('KB','TK','SD') NOT NULL,
  kelas             VARCHAR(20)      NOT NULL,
  mata_pelajaran    VARCHAR(100)     NOT NULL COMMENT 'Mata pelajaran / kegiatan belajar',
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_jadwal),
  KEY idx_jadwal_guru_hari (id_pengguna, hari),
  KEY idx_jadwal_kelas_hari (unit, kelas, hari),
  CONSTRAINT fk_jadwal_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 6. absensi : absen masuk & pulang guru (foto + lokasi GPS)
--    satu guru hanya punya satu baris absensi per tanggal
-- ---------------------------------------------------------------------
CREATE TABLE absensi (
  id_absensi        INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_pengguna       INT UNSIGNED     NOT NULL,
  tanggal           DATE             NOT NULL,
  jam_masuk         TIME             NULL,
  jam_pulang        TIME             NULL,
  foto_masuk        VARCHAR(255)     NULL,
  foto_pulang       VARCHAR(255)     NULL,
  lat_masuk         DECIMAL(10,7)    NULL,
  lng_masuk         DECIMAL(10,7)    NULL,
  lat_pulang        DECIMAL(10,7)    NULL,
  lng_pulang        DECIMAL(10,7)    NULL,
  status            ENUM('hadir','terlambat','izin','sakit','cuti','alpa') NOT NULL DEFAULT 'hadir',
  menit_terlambat   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  keterangan        VARCHAR(255)     NULL COMMENT 'Catatan, mis. koreksi admin',
  dikoreksi_oleh    INT UNSIGNED     NULL COMMENT 'Admin yang mengoreksi absen',
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_absensi),
  UNIQUE KEY uk_absensi_guru_tanggal (id_pengguna, tanggal),
  KEY idx_absensi_tanggal (tanggal),
  CONSTRAINT fk_absensi_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_absensi_korektor FOREIGN KEY (dikoreksi_oleh)
    REFERENCES pengguna (id_pengguna) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 7. cuti : pengajuan cuti / izin / sakit guru dan persetujuannya
-- ---------------------------------------------------------------------
CREATE TABLE cuti (
  id_cuti           INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_pengguna       INT UNSIGNED     NOT NULL,
  jenis             ENUM('cuti','izin','sakit') NOT NULL,
  tanggal_mulai     DATE             NOT NULL,
  tanggal_selesai   DATE             NOT NULL,
  jumlah_hari       SMALLINT UNSIGNED NOT NULL,
  alasan            TEXT             NOT NULL,
  lampiran          VARCHAR(255)     NULL COMMENT 'Mis. surat dokter',
  status            ENUM('menunggu','disetujui','ditolak') NOT NULL DEFAULT 'menunggu',
  catatan_admin     VARCHAR(255)     NULL,
  diproses_oleh     INT UNSIGNED     NULL,
  diproses_pada     DATETIME         NULL,
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cuti),
  KEY idx_cuti_pengguna (id_pengguna),
  KEY idx_cuti_status (status),
  CONSTRAINT fk_cuti_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cuti_pemroses FOREIGN KEY (diproses_oleh)
    REFERENCES pengguna (id_pengguna) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 8. hari_libur : tanggal libur (tidak dihitung sebagai hari kerja)
-- ---------------------------------------------------------------------
CREATE TABLE hari_libur (
  id_libur          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  tanggal           DATE             NOT NULL,
  keterangan        VARCHAR(100)     NOT NULL,
  PRIMARY KEY (id_libur),
  UNIQUE KEY uk_libur_tanggal (tanggal)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 9. pengaturan : pengaturan sistem (hanya 1 baris, id_pengaturan = 1)
-- ---------------------------------------------------------------------
CREATE TABLE pengaturan (
  id_pengaturan        TINYINT UNSIGNED NOT NULL,
  nama_yayasan         VARCHAR(100)   NOT NULL,
  alamat_yayasan       VARCHAR(255)   NULL,
  jam_masuk            TIME           NOT NULL DEFAULT '07:00:00',
  jam_pulang           TIME           NOT NULL DEFAULT '14:00:00',
  toleransi_terlambat  SMALLINT UNSIGNED NOT NULL DEFAULT 15 COMMENT 'Menit',
  lokasi_lat           DECIMAL(10,7)  NULL COMMENT 'Titik lokasi absen (diisi admin)',
  lokasi_lng           DECIMAL(10,7)  NULL,
  radius_absen         SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Meter',
  kuota_cuti_tahunan   TINYINT UNSIGNED NOT NULL DEFAULT 12 COMMENT 'Hari per tahun',
  diubah_pada          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pengaturan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- 10. percobaan_login : catatan login GAGAL, untuk mengunci sementara
--     akun yang kata sandinya dicoba-coba (mencegah tebak kata sandi)
-- ---------------------------------------------------------------------
CREATE TABLE percobaan_login (
  id_percobaan      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  identitas         VARCHAR(100)     NOT NULL COMMENT 'akun:<id_pengguna>, atau email/NIY yang dicoba jika akun tidak ada',
  alamat_ip         VARCHAR(45)      NULL,
  waktu             DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_percobaan),
  KEY idx_percobaan_identitas_waktu (identitas, waktu)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
--  DATA AWAL (SEED)
-- =====================================================================

-- Pengaturan default (lokasi absen dikosongkan, nanti diisi admin)
INSERT INTO pengaturan (id_pengaturan, nama_yayasan, alamat_yayasan, jam_masuk, jam_pulang,
                        toleransi_terlambat, lokasi_lat, lokasi_lng, radius_absen, kuota_cuti_tahunan)
VALUES (1, 'Yayasan Tiara Harapan Jaya', 'PUP Sektor V Blok O2 No. 1-5, Kel. Bahagia, Kec. Babelan, Kab. Bekasi',
        '07:00:00', '14:00:00', 15, NULL, NULL, 100, 12);

-- Akun demo (GANTI kata sandi setelah aplikasi dipakai sungguhan!)
--   Admin : ADM001 / admin@contoh.test       kata sandi: admin123
--   Guru  : 12345678910 / guru@contoh.test   kata sandi: guru123
--   Guru  : 12345678911 / siti@contoh.test   kata sandi: guru123
--   Guru  : 12345678912 / ahmad@contoh.test  kata sandi: guru123
INSERT INTO pengguna (id_pengguna, nomor_induk, nama_lengkap, gelar, email, no_hp, password, role,
                      jabatan, unit, jenis_kelamin)
VALUES
  (1, 'ADM001', 'Admin Yayasan', NULL, 'admin@contoh.test', '081200000001',
   '$2y$10$arktODfbEKH1IV.1Hk0uEu8S6WipCNi3FdEEgBWZ9UdJYX/Ke2vvy', 'admin', 'Staf Tata Usaha', NULL, NULL),
  (2, '12345678910', 'Guru Contoh', 'S.Pd.', 'guru@contoh.test', '081200000002',
   '$2y$10$ug6XsBJ3VgZBnWJXK8gSvu66QtozXt3LjOPFD2FPY.Fc9eJqAnZzu', 'guru', 'Guru Kelas', 'SD', 'L'),
  (3, '12345678911', 'Siti Rahmawati', 'S.Pd.', 'siti@contoh.test', '081200000003',
   '$2y$10$ug6XsBJ3VgZBnWJXK8gSvu66QtozXt3LjOPFD2FPY.Fc9eJqAnZzu', 'guru', 'Wali Kelas', 'TK', 'P'),
  (4, '12345678912', 'Ahmad Fauzi', 'S.Pd.I.', 'ahmad@contoh.test', '081200000004',
   '$2y$10$ug6XsBJ3VgZBnWJXK8gSvu66QtozXt3LjOPFD2FPY.Fc9eJqAnZzu', 'guru', 'Guru Mapel', 'SD', 'L');

-- Jadwal mengajar contoh (berulang setiap minggu)
INSERT INTO jadwal_mengajar (id_pengguna, hari, jam_mulai, jam_selesai, unit, kelas, mata_pelajaran)
VALUES
  -- Guru Contoh, S.Pd. (SD)
  (2, 'Senin',  '07:30:00', '09:00:00', 'SD', '3B', 'Bahasa Indonesia'),
  (2, 'Senin',  '09:30:00', '10:40:00', 'SD', '3A', 'Bahasa Indonesia'),
  (2, 'Senin',  '10:40:00', '11:50:00', 'SD', '2A', 'Bahasa Indonesia'),
  (2, 'Selasa', '07:30:00', '09:00:00', 'SD', '2A', 'Matematika'),
  (2, 'Selasa', '09:30:00', '10:40:00', 'SD', '3A', 'Matematika'),
  (2, 'Rabu',   '07:30:00', '09:00:00', 'SD', '3A', 'Pendidikan Pancasila'),
  (2, 'Rabu',   '09:30:00', '10:40:00', 'SD', '2B', 'Bahasa Indonesia'),
  (2, 'Kamis',  '07:30:00', '08:40:00', 'SD', '3B', 'Bahasa Indonesia'),
  (2, 'Kamis',  '09:30:00', '10:40:00', 'SD', '3B', 'Matematika'),
  (2, 'Jumat',  '07:30:00', '08:40:00', 'SD', '2A', 'Seni Budaya'),
  -- Siti Rahmawati, S.Pd. (TK)
  (3, 'Senin',  '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'),
  (3, 'Selasa', '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'),
  (3, 'Rabu',   '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'),
  (3, 'Kamis',  '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'),
  (3, 'Jumat',  '07:30:00', '09:30:00', 'TK', 'TK A', 'Senam & Motorik Kasar'),
  -- Ahmad Fauzi, S.Pd.I. (SD)
  (4, 'Senin',  '07:30:00', '09:00:00', 'SD', '2A', 'Pendidikan Agama Islam'),
  (4, 'Senin',  '09:30:00', '10:40:00', 'SD', '3B', 'Pendidikan Agama Islam'),
  (4, 'Rabu',   '07:30:00', '09:00:00', 'SD', '3B', 'Pendidikan Agama Islam'),
  (4, 'Jumat',  '07:30:00', '08:40:00', 'SD', '3A', 'Pendidikan Agama Islam');

-- Info kegiatan contoh (lampiran ada di backend/uploads/lampiran/)
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

-- Hari libur contoh (sesuai Project Charter)
INSERT INTO hari_libur (tanggal, keterangan)
VALUES
  ('2026-12-25', 'Hari Raya Natal'),
  ('2027-01-01', 'Tahun Baru Masehi');
