-- =====================================================================
--  MIGRASI SESI 4c  (Absen per mata pelajaran + gedung di jadwal)
--
--  Pakai file ini HANYA jika database sudah berisi data yang ingin
--  dipertahankan. Jika belum ada data penting, lebih mudah import ulang
--  database/db_kepegawaian_guru.sql.
--
--  Isi migrasi:
--    1. jadwal_mengajar.id_lokasi : gedung tempat mengajar.
--    2. pengaturan.buka_absen_menit : absen mapel dibuka sekian menit
--       sebelum jam mulai (bawaan 30).
--    3. Tabel absensi diganti menjadi absen PER MATA PELAJARAN.
--       Tabel absensi lama (absen harian masuk/pulang) TIDAK dihapus,
--       hanya diganti namanya menjadi "absensi_lama". Tabel itu sudah
--       tidak dipakai aplikasi dan boleh dihapus setelah dicek.
--    4. Tabel jam_kerja_unit dihapus (jam masuk/pulang kini mengikuti
--       jadwal mengajar setiap guru).
--
--  Syarat: migrasi Sesi 4b (2026-11-16_sesi4b.sql) sudah pernah dijalankan.
--  Cara menjalankan: phpMyAdmin -> tab "Import" -> pilih file ini -> "Import".
--  Aman jika tidak sengaja dijalankan lebih dari sekali.
-- =====================================================================

USE db_kepegawaian_guru;

-- 1. Gedung tempat mengajar di jadwal
SET @ada := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'jadwal_mengajar' AND column_name = 'id_lokasi'
);
SET @perintah := IF(@ada = 0,
  'ALTER TABLE jadwal_mengajar
     ADD COLUMN id_lokasi INT UNSIGNED NULL COMMENT ''Gedung/lokasi tempat mengajar'' AFTER mata_pelajaran,
     ADD CONSTRAINT fk_jadwal_lokasi FOREIGN KEY (id_lokasi)
       REFERENCES lokasi_absen (id_lokasi) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT ''kolom jadwal_mengajar.id_lokasi sudah ada'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 2. Absen mapel dibuka sekian menit sebelum jam mulai
SET @ada := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'pengaturan' AND column_name = 'buka_absen_menit'
);
SET @perintah := IF(@ada = 0,
  'ALTER TABLE pengaturan
     MODIFY COLUMN toleransi_terlambat SMALLINT UNSIGNED NOT NULL DEFAULT 15
       COMMENT ''Menit setelah jam mulai mapel'',
     ADD COLUMN buka_absen_menit SMALLINT UNSIGNED NOT NULL DEFAULT 30
       COMMENT ''Absen mapel dibuka sekian menit sebelum jam mulai'' AFTER toleransi_terlambat',
  'SELECT ''kolom pengaturan.buka_absen_menit sudah ada'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 3a. Simpan tabel absensi lama (absen harian) sebagai absensi_lama
SET @absensi_harian := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'absensi' AND column_name = 'jam_masuk'
);
SET @perintah := IF(@absensi_harian > 0,
  'RENAME TABLE absensi TO absensi_lama',
  'SELECT ''tabel absensi sudah per mapel'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

--     Foreign key tabel lama dilepas agar namanya bisa dipakai tabel baru
SET @perintah := (
  SELECT CONCAT('ALTER TABLE absensi_lama ',
                GROUP_CONCAT(CONCAT('DROP FOREIGN KEY ', constraint_name) SEPARATOR ', '))
    FROM information_schema.table_constraints
   WHERE table_schema = DATABASE() AND table_name = 'absensi_lama' AND constraint_type = 'FOREIGN KEY'
);
SET @perintah := IFNULL(@perintah, 'SELECT ''tidak ada foreign key lama'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 3b. Tabel absensi baru: satu baris = satu mapel pada satu tanggal
CREATE TABLE IF NOT EXISTS absensi (
  id_absensi        INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_pengguna       INT UNSIGNED     NOT NULL,
  id_jadwal         INT UNSIGNED     NULL COMMENT 'Jadwal mengajar yang diabsen (NULL jika jadwalnya sudah dihapus)',
  tanggal           DATE             NOT NULL,
  mata_pelajaran    VARCHAR(100)     NOT NULL COMMENT 'Salinan dari jadwal',
  unit              ENUM('KB','TK','SD') NOT NULL,
  kelas             VARCHAR(20)      NOT NULL,
  jam_mulai         TIME             NOT NULL,
  jam_selesai       TIME             NOT NULL,
  jam_absen         TIME             NULL COMMENT 'NULL jika ditandai admin tanpa absen guru',
  foto              VARCHAR(255)     NULL,
  lat               DECIMAL(10,7)    NULL,
  lng               DECIMAL(10,7)    NULL,
  id_lokasi         INT UNSIGNED     NULL COMMENT 'Lokasi absen terdekat saat absen',
  jarak             INT UNSIGNED     NULL COMMENT 'Jarak ke lokasi absen terdekat (meter)',
  status            ENUM('hadir','terlambat','izin','sakit','cuti','alpa') NOT NULL DEFAULT 'hadir',
  menit_terlambat   SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Dihitung dari jam mulai mapel',
  keterangan        VARCHAR(255)     NULL COMMENT 'Catatan, mis. alasan dari admin',
  dikoreksi_oleh    INT UNSIGNED     NULL COMMENT 'Admin yang menandai/mengubah kehadiran',
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_absensi),
  UNIQUE KEY uk_absensi_jadwal_tanggal (id_jadwal, tanggal),
  KEY idx_absensi_guru_tanggal (id_pengguna, tanggal),
  KEY idx_absensi_tanggal (tanggal),
  CONSTRAINT fk_absensi_pengguna FOREIGN KEY (id_pengguna)
    REFERENCES pengguna (id_pengguna) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_absensi_jadwal FOREIGN KEY (id_jadwal)
    REFERENCES jadwal_mengajar (id_jadwal) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_absensi_lokasi FOREIGN KEY (id_lokasi)
    REFERENCES lokasi_absen (id_lokasi) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_absensi_korektor FOREIGN KEY (dikoreksi_oleh)
    REFERENCES pengguna (id_pengguna) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Jam masuk/pulang per unit tidak dipakai lagi
DROP TABLE IF EXISTS jam_kerja_unit;
