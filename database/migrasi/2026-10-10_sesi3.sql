-- =====================================================================
--  MIGRASI SESI 3  (Sesi 2 -> Sesi 3: Jadwal Mengajar)
--
--  Pakai file ini HANYA jika database Sesi 2 sudah berisi data yang ingin
--  dipertahankan. Jika belum ada data penting, lebih mudah import ulang
--  database/db_kepegawaian_guru.sql.
--
--  Isi migrasi:
--    1. Index baru untuk pengecekan jadwal bentrok di satu kelas.
--    2. 2 akun guru demo tambahan (siti@contoh.test & ahmad@contoh.test,
--       kata sandi guru123) jika belum ada.
--    3. Jadwal mengajar contoh untuk 3 akun guru demo, HANYA untuk guru
--       demo yang belum punya jadwal sama sekali.
--
--  Syarat: migrasi Sesi 2 (2026-10-09_sesi2.sql) sudah pernah dijalankan.
--  Cara menjalankan: phpMyAdmin -> tab "Import" -> pilih file ini -> "Import".
--  Aman jika tidak sengaja dijalankan lebih dari sekali.
-- =====================================================================

USE db_kepegawaian_guru;

-- 1. Index untuk mempercepat pengecekan jadwal bentrok di satu kelas
--    (dibuat hanya jika belum ada)
SET @ada_index := (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'jadwal_mengajar'
    AND index_name = 'idx_jadwal_kelas_hari'
);
SET @perintah := IF(@ada_index = 0,
  'ALTER TABLE jadwal_mengajar ADD KEY idx_jadwal_kelas_hari (unit, kelas, hari)',
  'SELECT ''index sudah ada'' AS keterangan');
PREPARE langkah FROM @perintah;
EXECUTE langkah;
DEALLOCATE PREPARE langkah;

-- 2. Akun guru demo tambahan (dilewati jika email/NIY sudah terpakai)
INSERT IGNORE INTO pengguna (nomor_induk, nama_lengkap, gelar, email, no_hp, password, role,
                             jabatan, unit, jenis_kelamin)
VALUES
  ('12345678911', 'Siti Rahmawati', 'S.Pd.', 'siti@contoh.test', '081200000003',
   '$2y$10$ug6XsBJ3VgZBnWJXK8gSvu66QtozXt3LjOPFD2FPY.Fc9eJqAnZzu', 'guru', 'Wali Kelas', 'TK', 'P'),
  ('12345678912', 'Ahmad Fauzi', 'S.Pd.I.', 'ahmad@contoh.test', '081200000004',
   '$2y$10$ug6XsBJ3VgZBnWJXK8gSvu66QtozXt3LjOPFD2FPY.Fc9eJqAnZzu', 'guru', 'Guru Mapel', 'SD', 'L');

-- 3. Jadwal mengajar contoh (berulang setiap minggu)
INSERT INTO jadwal_mengajar (id_pengguna, hari, jam_mulai, jam_selesai, unit, kelas, mata_pelajaran)
SELECT p.id_pengguna, c.hari, c.jam_mulai, c.jam_selesai, c.unit, c.kelas, c.mata_pelajaran
FROM pengguna p
JOIN (
  -- Guru Contoh, S.Pd. (SD)
  SELECT 'guru@contoh.test' AS email, 'Senin' AS hari, '07:30:00' AS jam_mulai, '09:00:00' AS jam_selesai,
         'SD' AS unit, '3B' AS kelas, 'Bahasa Indonesia' AS mata_pelajaran
  UNION ALL SELECT 'guru@contoh.test',  'Senin',  '09:30:00', '10:40:00', 'SD', '3A', 'Bahasa Indonesia'
  UNION ALL SELECT 'guru@contoh.test',  'Senin',  '10:40:00', '11:50:00', 'SD', '2A', 'Bahasa Indonesia'
  UNION ALL SELECT 'guru@contoh.test',  'Selasa', '07:30:00', '09:00:00', 'SD', '2A', 'Matematika'
  UNION ALL SELECT 'guru@contoh.test',  'Selasa', '09:30:00', '10:40:00', 'SD', '3A', 'Matematika'
  UNION ALL SELECT 'guru@contoh.test',  'Rabu',   '07:30:00', '09:00:00', 'SD', '3A', 'Pendidikan Pancasila'
  UNION ALL SELECT 'guru@contoh.test',  'Rabu',   '09:30:00', '10:40:00', 'SD', '2B', 'Bahasa Indonesia'
  UNION ALL SELECT 'guru@contoh.test',  'Kamis',  '07:30:00', '08:40:00', 'SD', '3B', 'Bahasa Indonesia'
  UNION ALL SELECT 'guru@contoh.test',  'Kamis',  '09:30:00', '10:40:00', 'SD', '3B', 'Matematika'
  UNION ALL SELECT 'guru@contoh.test',  'Jumat',  '07:30:00', '08:40:00', 'SD', '2A', 'Seni Budaya'
  -- Siti Rahmawati, S.Pd. (TK)
  UNION ALL SELECT 'siti@contoh.test',  'Senin',  '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'
  UNION ALL SELECT 'siti@contoh.test',  'Selasa', '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'
  UNION ALL SELECT 'siti@contoh.test',  'Rabu',   '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'
  UNION ALL SELECT 'siti@contoh.test',  'Kamis',  '07:30:00', '10:00:00', 'TK', 'TK A', 'Pembelajaran Tematik'
  UNION ALL SELECT 'siti@contoh.test',  'Jumat',  '07:30:00', '09:30:00', 'TK', 'TK A', 'Senam & Motorik Kasar'
  -- Ahmad Fauzi, S.Pd.I. (SD)
  UNION ALL SELECT 'ahmad@contoh.test', 'Senin',  '07:30:00', '09:00:00', 'SD', '2A', 'Pendidikan Agama Islam'
  UNION ALL SELECT 'ahmad@contoh.test', 'Senin',  '09:30:00', '10:40:00', 'SD', '3B', 'Pendidikan Agama Islam'
  UNION ALL SELECT 'ahmad@contoh.test', 'Rabu',   '07:30:00', '09:00:00', 'SD', '3B', 'Pendidikan Agama Islam'
  UNION ALL SELECT 'ahmad@contoh.test', 'Jumat',  '07:30:00', '08:40:00', 'SD', '3A', 'Pendidikan Agama Islam'
) AS c ON c.email = p.email
WHERE p.role = 'guru'
  AND NOT EXISTS (SELECT 1 FROM jadwal_mengajar j WHERE j.id_pengguna = p.id_pengguna);
