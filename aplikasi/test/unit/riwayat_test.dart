import 'package:flutter_test/flutter_test.dart';
import 'package:kepegawaian_guru/models/absensi.dart';
import 'package:kepegawaian_guru/utils/tahun_ajaran.dart';

import '../helpers.dart';

void main() {
  group('Tahun ajaran', () {
    test('Juli-Desember = Semester Ganjil, Januari-Juni = Semester Genap', () {
      expect(TahunAjaran.dari(DateTime(2026, 11, 23)).label, '2026/2027');
      expect(TahunAjaran.dari(DateTime(2027, 3, 1)).label, '2026/2027');
      expect(TahunAjaran.dari(DateTime(2026, 6, 30)).label, '2025/2026');
      expect(TahunAjaran.dari(DateTime(2026, 7, 1)).label, '2026/2027');
      expect(TahunAjaran.semester(DateTime(2026, 7)), 'Ganjil');
      expect(TahunAjaran.semester(DateTime(2027, 6)), 'Genap');
    });

    test('12 bulan dari Juli sampai Juni', () {
      final bulan = const TahunAjaran(2026).daftarBulan;
      expect(bulan, hasLength(12));
      expect(bulan.first, DateTime(2026, 7));
      expect(bulan[5], DateTime(2026, 12));
      expect(bulan[6], DateTime(2027, 1));
      expect(bulan.last, DateTime(2027, 6));
    });

    test('Rentang tahun ajaran sejak riwayat dimulai (terbaru dulu)', () {
      final daftar = TahunAjaran.rentang(
        DateTime(2025, 9, 1),
        DateTime(2026, 11, 23),
      );
      expect(daftar.map((t) => t.label), ['2026/2027', '2025/2026']);
      expect(
        TahunAjaran.rentang(DateTime(2026, 11, 1), DateTime(2026, 11, 23)),
        [const TahunAjaran(2026)],
      );
    });
  });

  group('Riwayat absen', () {
    final data = RiwayatBulan.fromJson(jsonRiwayatNovember());
    final hariIni = data.hariIni;
    KeadaanHari keadaan(int tanggal) => keadaanHari(
      data.padaTanggal(DateTime(2026, 11, tanggal))!,
      hariIni: hariIni,
      menitSekarang: data.menitSekarang,
    );

    test('Membaca data server', () {
      expect(data.bulan, DateTime(2026, 11));
      expect(data.hariIni, DateTime(2026, 11, 23));
      expect(data.mulai, DateTime(2026, 10, 19));
      expect(data.menitSekarang, 600);
      expect(data.hari, hasLength(30));
      expect(data.hari.first.hari, 'Minggu');
      expect(data.hari.first.libur, 'Hari Minggu');
      expect(data.padaTanggal(DateTime(2026, 11, 3))!.mapel, hasLength(2));
      expect(data.padaTanggal(DateTime(2026, 12, 1)), isNull);
    });

    test('Warna setiap tanggal', () {
      expect(keadaan(1), KeadaanHari.libur); // Minggu
      expect(keadaan(2), KeadaanHari.tidakHadir);
      expect(keadaan(3), KeadaanHari.hadir);
      expect(keadaan(4), KeadaanHari.izinSakitCuti);
      expect(keadaan(5), KeadaanHari.hadir); // terlambat tetap hadir
      expect(keadaan(6), KeadaanHari.kosong);
      expect(keadaan(9), KeadaanHari.sebagian);
      expect(keadaan(10), KeadaanHari.libur);
      expect(keadaan(12), KeadaanHari.izinSakitCuti); // cuti disetujui
      expect(keadaan(23), KeadaanHari.menunggu); // mapel 2 masih berlangsung
      expect(keadaan(24), KeadaanHari.menunggu);
    });

    test('Mapel tanpa absen di hari cuti dianggap cuti', () {
      final hari = data.padaTanggal(DateTime(2026, 11, 12))!;
      expect(
        keadaanMapelRiwayat(hari, hari.mapel.first, hariIni: hariIni),
        KeadaanMapel.cuti,
      );
    });

    test('Hari ini: mapel yang sudah selesai tanpa absen dihitung', () {
      final hari = data.padaTanggal(DateTime(2026, 11, 23))!;
      // Pukul 11.00 mapel 2 (09.30-10.40) sudah selesai tanpa absen
      expect(
        keadaanHari(hari, hariIni: hariIni, menitSekarang: 660),
        KeadaanHari.sebagian,
      );
      // Pukul 07.00 belum ada mapel yang selesai
      final kosong = HariRiwayat.fromJson({
        'tanggal': '2026-11-23',
        'hari': 'Senin',
        'mapel': duaMapelContoh(),
      });
      expect(
        keadaanHari(kosong, hariIni: hariIni, menitSekarang: 420),
        KeadaanHari.menunggu,
      );
      expect(
        keadaanHari(kosong, hariIni: hariIni, menitSekarang: 660),
        KeadaanHari.tidakHadir,
      );
    });

    test('Alpa dari admin = tidak hadir', () {
      final hari = HariRiwayat.fromJson({
        'tanggal': '2026-11-16',
        'hari': 'Senin',
        'mapel': [
          jsonMapelContoh(
            absensi: jsonAbsensiContoh(jamAbsen: null, status: 'alpa'),
          ),
        ],
      });
      expect(keadaanHari(hari, hariIni: hariIni), KeadaanHari.tidakHadir);
    });

    test('Rekap bulan hanya sampai hari ini', () {
      final rekap = rekapRiwayat(
        data.hari,
        hariIni: hariIni,
        menitSekarang: data.menitSekarang,
      );
      expect(rekap.hariHadir, 2); // 3 & 5 Nov
      expect(rekap.hariSebagian, 1); // 9 Nov
      expect(rekap.hariIzin, 2); // 4 & 12 Nov
      expect(rekap.hariTidakHadir, 1); // 2 Nov
      // Diabsen: 3 Nov (2) + 5 Nov (2) + 9 Nov (1) + 23 Nov (1) = 6
      // Tidak diabsen: 2 Nov (2) + 9 Nov (1) = 3; izin & mapel berjalan
      // tidak dihitung.
      expect(rekap.mapelDiabsen, 6);
      expect(rekap.mapelTidakDiabsen, 3);
      expect(rekap.mapelSelesai, 9);
      expect(rekap.kaliTerlambat, 1);
      // 90+70 + 90+70 + 70 + 90 = 480 menit
      expect(rekap.menitMengajar, 480);
    });

    test('Format durasi jam mengajar', () {
      expect(formatDurasi(0), '0 menit');
      expect(formatDurasi(45), '45 menit');
      expect(formatDurasi(120), '2 jam');
      expect(formatDurasi(750), '12 jam 30 menit');
    });

    test('Posisi tanggal terhadap hari ini', () {
      final hi = DateTime(2026, 11, 23, 10);
      expect(hariRelatif(DateTime(2026, 11, 22), hi), HariRelatif.lalu);
      expect(hariRelatif(DateTime(2026, 11, 23), hi), HariRelatif.ini);
      expect(hariRelatif(DateTime(2026, 11, 24), hi), HariRelatif.depan);
    });
  });
}
