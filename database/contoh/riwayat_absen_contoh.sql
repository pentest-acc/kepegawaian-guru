-- =====================================================================
-- DATA CONTOH RIWAYAT ABSEN (untuk demo / presentasi)
--
-- Mengisi absensi 36 hari terakhir (sampai kemarin) untuk akun guru demo
-- yang email-nya berakhiran @contoh.test, agar kalender Riwayat Absen
-- langsung terlihat berwarna:
--   - kebanyakan mapel hadir tepat waktu, sebagian terlambat, beberapa
--     lewat jam pelajaran, dan beberapa mapel tidak diabsen;
--   - beberapa hari sakit / izin (ditandai admin);
--   - beberapa hari tidak absen sama sekali.
-- Jadwal mengajar akun demo dianggap sudah ada sejak 36 hari lalu.
--
-- JANGAN dijalankan di database yang dipakai sungguhan. Akun selain
-- @contoh.test tidak disentuh. Aman dijalankan ulang (data yang sudah ada
-- tidak ditimpa). Cara: phpMyAdmin -> pilih db_kepegawaian_guru -> Import.
-- =====================================================================

SET NAMES utf8mb4;

SET @id_admin := (SELECT id_pengguna FROM pengguna WHERE role = 'admin' ORDER BY id_pengguna LIMIT 1);

-- Jadwal akun demo dianggap sudah ada sejak 36 hari lalu
UPDATE jadwal_mengajar j
  JOIN pengguna p ON p.id_pengguna = j.id_pengguna
   SET j.dibuat_pada = CURDATE() - INTERVAL 36 DAY
 WHERE p.role = 'guru'
   AND p.email LIKE '%@contoh.test'
   AND j.dibuat_pada > CURDATE() - INTERVAL 36 DAY;

-- Absensi contoh
--   keadaan_hari : 0 = biasa, 1 = sakit, 2 = izin, 3 = tidak absen seharian
--   pola         : 0-1 = mapel tidak diabsen, 2-4 = terlambat,
--                  5 = lewat jam pelajaran, selainnya = hadir tepat waktu
--   geser        : menit absen dihitung dari jam mulai (negatif = lebih awal)
INSERT IGNORE INTO absensi
  (id_pengguna, id_jadwal, tanggal, mata_pelajaran, unit, kelas, jam_mulai, jam_selesai,
   jam_absen, id_lokasi, jarak, status, menit_terlambat, keterangan, dikoreksi_oleh)
SELECT x.id_pengguna, x.id_jadwal, x.tanggal, x.mata_pelajaran, x.unit, x.kelas,
       x.jam_mulai, x.jam_selesai,
       IF(x.keadaan_hari > 0, NULL, SEC_TO_TIME(TIME_TO_SEC(x.jam_mulai) + x.geser * 60)),
       IF(x.keadaan_hari > 0, NULL, x.id_lokasi),
       IF(x.keadaan_hari > 0 OR x.id_lokasi IS NULL, NULL, 12 + x.pola * 4),
       CASE x.keadaan_hari
         WHEN 1 THEN 'sakit'
         WHEN 2 THEN 'izin'
         ELSE IF(x.geser > 15, 'terlambat', 'hadir')
       END,
       IF(x.keadaan_hari = 0 AND x.geser > 15, x.geser, 0),
       CASE x.keadaan_hari
         WHEN 1 THEN 'Sakit, ada surat dokter (data contoh)'
         WHEN 2 THEN 'Izin keperluan keluarga (data contoh)'
         ELSE NULL
       END,
       IF(x.keadaan_hari > 0, @id_admin, NULL)
  FROM (
    SELECT j.id_pengguna, j.id_jadwal, j.mata_pelajaran, j.unit, j.kelas,
           j.jam_mulai, j.jam_selesai, j.id_lokasi, t.tanggal,
           MOD(TO_DAYS(t.tanggal) * 7 + j.id_jadwal * 3, 20) AS pola,
           CASE
             WHEN MOD(TO_DAYS(t.tanggal), 11) = 0 THEN 1
             WHEN MOD(TO_DAYS(t.tanggal) + j.id_pengguna, 17) = 0 THEN 2
             WHEN MOD(TO_DAYS(t.tanggal) + j.id_pengguna * 5, 19) = 0 THEN 3
             ELSE 0
           END AS keadaan_hari,
           CASE MOD(TO_DAYS(t.tanggal) * 7 + j.id_jadwal * 3, 20)
             WHEN 2 THEN 18
             WHEN 3 THEN 26
             WHEN 4 THEN 35
             WHEN 5 THEN TIME_TO_SEC(TIMEDIFF(j.jam_selesai, j.jam_mulai)) DIV 60 + 12
             ELSE -5 - CAST(MOD(TO_DAYS(t.tanggal) + j.id_jadwal, 15) AS SIGNED)
           END AS geser
      FROM (
        SELECT CURDATE() - INTERVAL (a.n + b.n * 6 + 1) DAY AS tanggal
          FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
                UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) a
         CROSS JOIN
               (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
                UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) b
      ) t
      JOIN jadwal_mengajar j
        ON j.hari = ELT(WEEKDAY(t.tanggal) + 1, 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu')
      JOIN pengguna p
        ON p.id_pengguna = j.id_pengguna AND p.role = 'guru' AND p.email LIKE '%@contoh.test'
      LEFT JOIN hari_libur l ON l.tanggal = t.tanggal
     WHERE l.id_libur IS NULL
  ) x
 WHERE x.keadaan_hari IN (1, 2)
    OR (x.keadaan_hari = 0 AND x.pola > 1);
