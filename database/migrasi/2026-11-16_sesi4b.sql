-- =====================================================================
--  MIGRASI SESI 4b  (Absen: banyak lokasi absen)
--
--  Pakai file ini HANYA jika database sudah berisi data yang ingin
--  dipertahankan. Jika belum ada data penting, lebih mudah import ulang
--  database/db_kepegawaian_guru.sql.
--
--  Isi migrasi:
--    1. Tabel baru lokasi_absen: admin bisa menambah banyak titik lokasi
--       (mis. 3 gedung Yayasan), masing-masing dengan radiusnya sendiri.
--    2. Kolom baru di absensi: id_lokasi_masuk & id_lokasi_pulang
--       (lokasi terdekat saat guru absen).
--    3. Titik lokasi lama di tabel pengaturan (jika pernah diisi) dipindahkan
--       menjadi lokasi bernama "Lokasi Utama", lalu kolom lamanya dihapus.
--
--  Syarat: migrasi Sesi 4 (2026-11-09_sesi4.sql) sudah pernah dijalankan.
--  Cara menjalankan: phpMyAdmin -> tab "Import" -> pilih file ini -> "Import".
--  Aman jika tidak sengaja dijalankan lebih dari sekali.
-- =====================================================================

USE db_kepegawaian_guru;

-- 1. Tabel lokasi absen
CREATE TABLE IF NOT EXISTS lokasi_absen (
  id_lokasi         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  nama              VARCHAR(100)     NOT NULL COMMENT 'Contoh: Gedung SD',
  lat               DECIMAL(10,7)    NOT NULL,
  lng               DECIMAL(10,7)    NOT NULL,
  radius            SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Meter',
  aktif             BOOLEAN          NOT NULL DEFAULT TRUE,
  dibuat_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_lokasi),
  UNIQUE KEY uk_lokasi_nama (nama)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Kolom lokasi di absensi
SET @ada_kolom := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'absensi' AND column_name = 'id_lokasi_masuk'
);
SET @perintah := IF(@ada_kolom = 0,
  'ALTER TABLE absensi
     ADD COLUMN id_lokasi_masuk INT UNSIGNED NULL
       COMMENT ''Lokasi absen terdekat saat absen masuk'' AFTER menit_pulang_awal,
     ADD COLUMN id_lokasi_pulang INT UNSIGNED NULL
       COMMENT ''Lokasi absen terdekat saat absen pulang'' AFTER jarak_masuk,
     MODIFY COLUMN jarak_masuk INT UNSIGNED NULL
       COMMENT ''Jarak ke lokasi absen terdekat saat absen masuk (meter)'',
     MODIFY COLUMN jarak_pulang INT UNSIGNED NULL
       COMMENT ''Jarak ke lokasi absen terdekat saat absen pulang (meter)'',
     ADD CONSTRAINT fk_absensi_lokasi_masuk FOREIGN KEY (id_lokasi_masuk)
       REFERENCES lokasi_absen (id_lokasi) ON DELETE SET NULL ON UPDATE CASCADE,
     ADD CONSTRAINT fk_absensi_lokasi_pulang FOREIGN KEY (id_lokasi_pulang)
       REFERENCES lokasi_absen (id_lokasi) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT ''kolom lokasi absensi sudah ada'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 3. Pindahkan titik lokasi lama dari tabel pengaturan (hanya sekali)
SET @ada_lokasi_lama := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'pengaturan' AND column_name = 'lokasi_lat'
);
SET @perintah := IF(@ada_lokasi_lama > 0,
  'INSERT IGNORE INTO lokasi_absen (nama, lat, lng, radius)
     SELECT ''Lokasi Utama'', lokasi_lat, lokasi_lng, radius_absen FROM pengaturan
      WHERE id_pengaturan = 1 AND lokasi_lat IS NOT NULL AND lokasi_lng IS NOT NULL',
  'SELECT ''lokasi lama sudah dipindahkan'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- Absensi lama yang tercatat jaraknya dihubungkan ke "Lokasi Utama"
SET @perintah := IF(@ada_lokasi_lama > 0,
  'UPDATE absensi a JOIN lokasi_absen l ON l.nama = ''Lokasi Utama''
      SET a.id_lokasi_masuk  = IF(a.jarak_masuk  IS NULL, a.id_lokasi_masuk,  l.id_lokasi),
          a.id_lokasi_pulang = IF(a.jarak_pulang IS NULL, a.id_lokasi_pulang, l.id_lokasi)',
  'SELECT ''tidak ada absensi lama untuk dihubungkan'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

SET @perintah := IF(@ada_lokasi_lama > 0,
  'ALTER TABLE pengaturan DROP COLUMN lokasi_lat, DROP COLUMN lokasi_lng, DROP COLUMN radius_absen',
  'SELECT ''kolom lokasi lama sudah dihapus'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;
