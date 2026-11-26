import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/models/absensi.dart';
import 'package:kepegawaian_guru/models/cuti.dart';
import 'package:kepegawaian_guru/widgets/chip_kehadiran.dart';
import 'package:kepegawaian_guru/widgets/gaya_cuti.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Model cuti', () {
    test('PengajuanCuti membaca data server', () {
      final c = PengajuanCuti.fromJson(
        jsonCutiContoh(
          jenis: 'sakit',
          status: 'disetujui',
          adaLampiran: true,
          catatan: 'Semoga lekas sembuh',
          denganGuru: true,
          jumlahMapel: 3,
        ),
      );
      expect(c.jenis, JenisCuti.sakit);
      expect(c.status, StatusCuti.disetujui);
      expect(c.tanggalMulai, DateTime(2026, 12, 7));
      expect(c.jumlahHari, 2);
      expect(c.adaLampiran, isTrue);
      expect(c.catatanAdmin, 'Semoga lekas sembuh');
      expect(c.diprosesOleh, 'Admin Yayasan');
      expect(c.diprosesPada, DateTime(2026, 11, 25, 10, 15));
      expect(c.guru!.namaTampil, 'Guru Contoh, S.Pd.');
      expect(c.jumlahMapel, 3);
      expect(c.satuHari, isFalse);
      expect(c.bisaDibatalkan, isFalse);
      expect(PengajuanCuti.fromJson(jsonCutiContoh()).bisaDibatalkan, isTrue);
    });

    test('Kuota, pratinjau, dan detail admin', () {
      final kuota = KuotaCuti.fromJson(jsonKuotaContoh());
      expect(kuota.sisa, 7);

      final p = PratinjauCuti.fromJson({
        'jenis': 'cuti',
        'jumlah_hari': 2,
        'jumlah_mapel': 3,
        'hari': jsonHariCutiContoh(),
        'kuota': jsonKuotaContoh(),
        'wajib_lampiran': false,
      });
      expect(p.hari, hasLength(2));
      expect(p.hari.first.mapel, hasLength(2));
      expect(p.hari.last.mapel.single.mataPelajaran, 'Matematika');
      expect(p.sisaSetelahCuti, 5);

      final izin = PratinjauCuti.fromJson({
        'jenis': 'izin',
        'jumlah_hari': 1,
        'hari': const [],
        'kuota': null,
      });
      expect(izin.sisaSetelahCuti, isNull);

      final d = DetailCutiAdmin.fromJson({
        'cuti': jsonCutiContoh(denganGuru: true),
        'hari': jsonHariCutiContoh(),
        'jumlah_mapel': 3,
        'kuota': jsonKuotaContoh(diajukan: 0),
        'bertumpuk': {
          'jenis': 'izin',
          'tanggal_mulai': '2026-12-07',
          'tanggal_selesai': '2026-12-07',
        },
      });
      expect(d.jumlahMapel, 3);
      expect(d.bertumpuk, 'Izin 2026-12-07 s.d. 2026-12-07');
    });

    test('Teks rentang tanggal', () {
      expect(
        rentangTanggalCuti(DateTime(2026, 12, 1), DateTime(2026, 12, 1)),
        'Sel, 1 Des 2026',
      );
      expect(
        rentangTanggalCuti(DateTime(2026, 12, 1), DateTime(2026, 12, 3)),
        'Sel, 1 Des - Kam, 3 Des 2026',
      );
      expect(
        rentangTanggalCuti(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        'Rab, 30 Des 2026 - Sab, 2 Jan 2027',
      );
    });
  });

  group('Absen saat cuti disetujui', () {
    test('Mapel tanpa absen pada hari cuti = cuti/izin/sakit', () {
      final mapel = MapelAbsen.fromJson(jsonMapelContoh());
      expect(
        keadaanMapelDenganCuti(mapel, 'sakit', hari: HariRelatif.ini),
        KeadaanMapel.sakit,
      );
      expect(
        keadaanMapelDenganCuti(mapel, 'izin', hari: HariRelatif.lalu),
        KeadaanMapel.izin,
      );
      expect(
        keadaanMapelDenganCuti(mapel, null, hari: HariRelatif.lalu),
        KeadaanMapel.terlewat,
      );
      // Absen yang sudah ada tetap dipakai
      final sudahAbsen = MapelAbsen.fromJson(
        jsonMapelContoh(absensi: jsonAbsensiContoh()),
      );
      expect(
        keadaanMapelDenganCuti(sudahAbsen, 'cuti', hari: HariRelatif.ini),
        KeadaanMapel.hadir,
      );
    });

    test('Label: dari pengajuan disetujui vs diisi admin', () {
      expect(GayaKehadiran.dari(KeadaanMapel.cuti).label, 'Cuti (disetujui)');
      final olehAdmin = AbsensiMapel.fromJson(
        jsonAbsensiContoh(jamAbsen: null, status: 'sakit'),
      );
      expect(
        GayaKehadiran.dari(KeadaanMapel.sakit, absensi: olehAdmin).label,
        'Sakit (diisi admin)',
      );
    });

    test('InfoAbsenHariIni membaca cuti hari ini', () {
      final info = InfoAbsenHariIni.fromJson({
        ...jsonHariIniContoh(),
        'cuti': 'sakit',
      });
      expect(info.cuti, 'sakit');
      expect(
        info.denganAbsensi(0, AbsensiMapel.fromJson(jsonAbsensiContoh())).cuti,
        'sakit',
      );
    });
  });
}
