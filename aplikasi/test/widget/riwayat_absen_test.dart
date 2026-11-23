import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/screens/guru/absen_screen.dart';
import 'package:kepegawaian_guru/screens/guru/riwayat_absen_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) =>
    MaterialApp(theme: AppTheme.terang, home: halaman);

/// Server palsu untuk Riwayat Absen (dan halaman Absen).
class ServerRiwayatPalsu {
  ServerRiwayatPalsu({this.mulai = '2026-10-19'});

  final String mulai;
  final List<String> bulanDiminta = [];

  /// Jumlah permintaan riwayat berikutnya yang dibuat gagal.
  int gagal = 0;

  Future<http.Response> tangani(http.Request req) async {
    final path = req.url.path;
    if (path.endsWith('absen/riwayat.php')) {
      final bulan = req.url.queryParameters['bulan']!;
      bulanDiminta.add(bulan);
      if (gagal > 0) {
        gagal--;
        return responJson(500, false, 'Server sedang bermasalah.');
      }
      if (bulan == '2026-11') {
        return responJson(
          200,
          true,
          'ok',
          jsonRiwayatNovember()..['mulai'] = mulai,
        );
      }
      final bagian = bulan.split('-').map(int.parse).toList();
      return responJson(
        200,
        true,
        'ok',
        jsonRiwayatContoh(tahun: bagian[0], bulan: bagian[1], mulai: mulai),
      );
    }
    if (path.endsWith('absen/hari_ini.php')) {
      return responJson(200, true, 'ok', jsonHariIniContoh());
    }
    return responJson(404, false, 'tidak ada');
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void layarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> bukaRiwayat(
    WidgetTester tester,
    ServerRiwayatPalsu server,
  ) async {
    layarHp(tester);
    await tester.pumpWidget(
      bungkus(
        RiwayatAbsenScreen(
          absenService: buatAbsenPalsu(server.tangani),
          sekarang: () => DateTime(2026, 11, 23, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Warna latar sebuah tanggal di kalender.
  Color warnaTanggal(WidgetTester tester, String tanggal) => tester
      .widget<Material>(
        find
            .ancestor(
              of: find.byKey(Key('hari-$tanggal')),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  Future<void> ketukTanggal(WidgetTester tester, String tanggal) async {
    await tester.tap(find.byKey(Key('hari-$tanggal')));
    await tester.pumpAndSettle();
  }

  Future<void> gulirSampai(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  group('Riwayat Absen', () {
    testWidgets('kalender bulan ini berwarna sesuai kehadiran', (tester) async {
      final server = ServerRiwayatPalsu();
      await bukaRiwayat(tester, server);

      expect(server.bulanDiminta, ['2026-11']);
      expect(find.text('Tahun Ajaran 2026/2027'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Semester Ganjil • TA 2026/2027'), findsOneWidget);
      expect(find.text('MIN'), findsOneWidget);
      // Tahun ajaran hanya satu (riwayat mulai Oktober 2026)
      expect(find.text('Ganti'), findsNothing);

      expect(warnaTanggal(tester, '2026-11-03'), GayaHari.hadir.latar);
      expect(warnaTanggal(tester, '2026-11-05'), GayaHari.hadir.latar);
      expect(warnaTanggal(tester, '2026-11-04'), GayaHari.izin.latar);
      expect(warnaTanggal(tester, '2026-11-12'), GayaHari.izin.latar);
      expect(warnaTanggal(tester, '2026-11-09'), GayaHari.sebagian.latar);
      expect(warnaTanggal(tester, '2026-11-02'), GayaHari.tidakHadir.latar);
      expect(warnaTanggal(tester, '2026-11-06'), Colors.white);
      expect(warnaTanggal(tester, '2026-11-24'), Colors.white);

      // Label kecil di dalam tanggal
      expect(find.text('2/2'), findsNWidgets(2)); // 3 & 5 Nov
      expect(find.text('1/2'), findsOneWidget); // 9 Nov
      expect(find.text('0/2'), findsOneWidget); // 2 Nov
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Cuti'), findsOneWidget);
      expect(find.text('Libur'), findsOneWidget); // 10 Nov
      expect(find.text('Hadir'), findsOneWidget); // keterangan warna

      // Detail hari ini terpilih otomatis
      await gulirSampai(tester, find.text('Senin, 23 November 2026'));
      expect(find.text('Hadir • 07.25'), findsOneWidget);
      expect(find.text('Belum absen'), findsOneWidget); // mapel berjalan

      // Rekap bulan
      await gulirSampai(tester, find.text('Rekap November 2026'));
      expect(find.text('Sampai hari ini (Sen, 23 Nov 2026)'), findsOneWidget);
      expect(find.text('6 dari 9'), findsOneWidget);
      expect(find.text('1 kali'), findsOneWidget);
      expect(find.text('8 jam'), findsOneWidget);
    });

    testWidgets('mengetuk tanggal menampilkan detail absennya', (tester) async {
      await bukaRiwayat(tester, ServerRiwayatPalsu());

      await ketukTanggal(tester, '2026-11-04');
      await gulirSampai(tester, find.text('Rabu, 4 November 2026'));
      expect(find.text('Sakit (diisi admin)'), findsNWidgets(2));
      expect(
        find.text('Catatan admin: Sakit, ada surat dokter'),
        findsNWidgets(2),
      );
      expect(find.text('Izin / Sakit / Cuti'), findsWidgets);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await ketukTanggal(tester, '2026-11-02');
      await gulirSampai(tester, find.text('Senin, 2 November 2026'));
      expect(find.text('Tidak absen'), findsWidgets);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await ketukTanggal(tester, '2026-11-05');
      await gulirSampai(tester, find.text('Kamis, 5 November 2026'));
      expect(find.text('Terlambat 22 menit • 09.52'), findsOneWidget);
      expect(find.text('Absen di Gedung SD (30 m)'), findsNWidgets(2));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await ketukTanggal(tester, '2026-11-12');
      await gulirSampai(tester, find.text('Cuti disetujui admin.'));
      expect(find.text('Cuti (disetujui admin)'), findsNWidgets(2));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await ketukTanggal(tester, '2026-11-10');
      await gulirSampai(tester, find.text('Libur: Libur Yayasan'));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await ketukTanggal(tester, '2026-11-24');
      await gulirSampai(tester, find.text('Selasa, 24 November 2026'));
      expect(find.text('Belum dimulai'), findsNWidgets(2));
    });

    testWidgets('berpindah bulan dalam satu tahun ajaran', (tester) async {
      final server = ServerRiwayatPalsu();
      await bukaRiwayat(tester, server);

      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pumpAndSettle();
      expect(server.bulanDiminta.last, '2026-10');
      expect(find.text('Oktober 2026'), findsOneWidget);
      await gulirSampai(
        tester,
        find.text('Ketuk sebuah tanggal untuk melihat detail absennya.'),
      );

      // Pilih Juli (bulan pertama Semester Ganjil): tidak bisa mundur lagi
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulan-2026-07')));
      await tester.pumpAndSettle();
      expect(find.text('Juli 2026'), findsOneWidget);
      final mundur = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
      );
      expect(mundur.onPressed, isNull);

      // Juni 2027 (bulan terakhir Semester Genap): tidak bisa maju lagi
      await tester.tap(find.byKey(const Key('bulan-2027-06')));
      await tester.pumpAndSettle();
      expect(find.text('Juni 2027'), findsOneWidget);
      expect(find.text('Semester Genap • TA 2026/2027'), findsOneWidget);
      final maju = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(maju.onPressed, isNull);
      await gulirSampai(tester, find.text('Bulan ini belum berjalan.'));

      // Kembali ke bulan ini: data sudah tersimpan, tidak dimuat ulang
      final jumlahPermintaan = server.bulanDiminta.length;
      await tester.tap(find.byTooltip('Bulan ini'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(server.bulanDiminta.length, jumlahPermintaan);
      expect(server.bulanDiminta, ['2026-11', '2026-10', '2026-07', '2027-06']);
    });

    testWidgets('tahun ajaran sebelumnya bisa dipilih', (tester) async {
      final server = ServerRiwayatPalsu(mulai: '2025-09-01');
      await bukaRiwayat(tester, server);

      expect(find.text('Ganti'), findsOneWidget);
      await tester.tap(find.text('Ganti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tahun Ajaran 2025/2026').last);
      await tester.pumpAndSettle();
      expect(server.bulanDiminta.last, '2025-07');
      expect(find.text('Juli 2025'), findsOneWidget);
      expect(find.text('Tahun Ajaran 2025/2026'), findsOneWidget);
    });

    testWidgets('gagal memuat bisa dicoba lagi', (tester) async {
      final server = ServerRiwayatPalsu()..gagal = 1;
      await bukaRiwayat(tester, server);

      await gulirSampai(tester, find.text('Server sedang bermasalah.'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Server sedang bermasalah.'), findsNothing);
      expect(warnaTanggal(tester, '2026-11-03'), GayaHari.hadir.latar);
    });

    testWidgets('dibuka dari tombol di halaman Absen', (tester) async {
      layarHp(tester);
      final server = ServerRiwayatPalsu();
      await tester.pumpWidget(
        bungkus(AbsenScreen(absenService: buatAbsenPalsu(server.tangani))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Riwayat Absen'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Absen'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(server.bulanDiminta, ['2026-11']);
    });
  });
}
