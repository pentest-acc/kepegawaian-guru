-- =====================================================================
--  MIGRASI SESI 4  (Sesi 3 -> Sesi 4: Absen)
--
--  Pakai file ini HANYA jika database Sesi 3 sudah berisi data yang ingin
--  dipertahankan. Jika belum ada data penting, lebih mudah import ulang
--  database/db_kepegawaian_guru.sql.
--
--  Isi migrasi:
--    1. Tabel baru jam_kerja_unit: jam masuk & pulang per unit
--       (KB & TK pulang 13.00, SD pulang 14.00). Jam masuk dan jam pulang
--       SD diambil dari pengaturan lama.
--    2. Kolom pengaturan.jam_masuk & jam_pulang dihapus (pindah ke
--       jam_kerja_unit).
--    3. Kolom baru di absensi: menit_pulang_awal, jarak_masuk, jarak_pulang.
--
--  Syarat: migrasi Sesi 2 & Sesi 3 sudah pernah dijalankan.
--  Cara menjalankan: phpMyAdmin -> tab "Import" -> pilih file ini -> "Import".
--  Aman jika tidak sengaja dijalankan lebih dari sekali.
-- =====================================================================

USE db_kepegawaian_guru;

-- 1. Jam kerja per unit
CREATE TABLE IF NOT EXISTS jam_kerja_unit (
  unit                 ENUM('KB','TK','SD') NOT NULL,
  jam_masuk            TIME           NOT NULL DEFAULT '07:00:00',
  jam_pulang           TIME           NOT NULL DEFAULT '14:00:00',
  PRIMARY KEY (unit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--    Isi dari pengaturan lama jika kolomnya masih ada, jika tidak pakai bawaan
SET @ada_jam_lama := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'pengaturan' AND column_name = 'jam_masuk'
);
SET @perintah := IF(@ada_jam_lama > 0,
  'INSERT IGNORE INTO jam_kerja_unit (unit, jam_masuk, jam_pulang)
     SELECT ''KB'', jam_masuk, ''13:00:00'' FROM pengaturan WHERE id_pengaturan = 1
     UNION ALL SELECT ''TK'', jam_masuk, ''13:00:00'' FROM pengaturan WHERE id_pengaturan = 1
     UNION ALL SELECT ''SD'', jam_masuk, jam_pulang FROM pengaturan WHERE id_pengaturan = 1',
  'SELECT ''jam kerja lama sudah dipindahkan'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

INSERT IGNORE INTO jam_kerja_unit (unit, jam_masuk, jam_pulang)
VALUES
  ('KB', '07:00:00', '13:00:00'),
  ('TK', '07:00:00', '13:00:00'),
  ('SD', '07:00:00', '14:00:00');

-- 2. Hapus kolom jam lama di pengaturan
SET @perintah := IF(@ada_jam_lama > 0,
  'ALTER TABLE pengaturan DROP COLUMN jam_masuk, DROP COLUMN jam_pulang',
  'SELECT ''kolom jam lama sudah dihapus'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 3. Kolom baru di absensi
SET @ada_kolom := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'absensi' AND column_name = 'menit_pulang_awal'
);
SET @perintah := IF(@ada_kolom = 0,
  'ALTER TABLE absensi
     ADD COLUMN menit_pulang_awal SMALLINT UNSIGNED NOT NULL DEFAULT 0
       COMMENT ''Absen pulang sebelum jam pulang unitnya'' AFTER menit_terlambat,
     ADD COLUMN jarak_masuk INT UNSIGNED NULL
       COMMENT ''Jarak dari titik lokasi sekolah saat absen masuk (meter)'' AFTER menit_pulang_awal,
     ADD COLUMN jarak_pulang INT UNSIGNED NULL
       COMMENT ''Jarak dari titik lokasi sekolah saat absen pulang (meter)'' AFTER jarak_masuk',
  'SELECT ''kolom absensi sudah ada'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;
