import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_routes.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/models/info_kegiatan.dart';
import 'package:kepegawaian_guru/models/pengguna.dart';
import 'package:kepegawaian_guru/screens/guru/beranda_screen.dart';
import 'package:kepegawaian_guru/screens/guru/info_detail_screen.dart';
import 'package:kepegawaian_guru/screens/guru/info_kegiatan_screen.dart';
import 'package:kepegawaian_guru/widgets/banner_info_berjalan.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) => MaterialApp(
  theme: AppTheme.terang,
  onGenerateRoute: AppRoutes.buatRoute,
  home: halaman,
);

/// Server palsu sederhana yang menyimpan tanda "penting" seperti database.
class ServerInfoPalsu {
  ServerInfoPalsu(this.info);

  final List<Map<String, dynamic>> info;
  final Set<int> penting = {};
  final List<http.Request> permintaan = [];

  Future<http.Response> tangani(http.Request req) async {
    permintaan.add(req);
    final path = req.url.path;

    if (path.endsWith('daftar.php')) {
      final cari = (req.url.queryParameters['cari'] ?? '').toLowerCase();
      final hanyaPenting = req.url.queryParameters['penting'] == '1';
      final hasil = [
        for (final i in info)
          if ((cari.isEmpty || '${i['judul']}'.toLowerCase().contains(cari)) &&
              (!hanyaPenting || penting.contains(i['id_info'])))
            {...i, 'penting': penting.contains(i['id_info'])},
      ];
      return responJson(200, true, 'ok', {
        'info': hasil,
        'jumlah': hasil.length,
      });
    }
    if (path.endsWith('detail.php')) {
      final id = int.parse(req.url.queryParameters['id']!);
      final i = info.firstWhere((e) => e['id_info'] == id);
      return responJson(200, true, 'ok', {
        'info': {...i, 'penting': penting.contains(id)},
      });
    }
    if (path.endsWith('tandai.php')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final id = body['id_info'] as int;
      body['penting'] == true ? penting.add(id) : penting.remove(id);
      return responJson(200, true, 'ok', body);
    }
    return responJson(404, false, 'Tidak ditemukan');
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

  List<Map<String, dynamic>> contohInfo() => [
    jsonInfoContoh(
      id: 2,
      judul: 'Upacara Hari Sumpah Pemuda',
      dibuat: '2026-10-09 07:45:00',
    ),
    jsonInfoContoh(
      id: 1,
      judul: 'Pengambilan Raport Semester Ganjil',
      dibuat: '2026-10-04 07:30:00',
      berlampiran: true,
    ),
  ];

  testWidgets('Daftar info tampil dengan tanggal dibuat & tombol unduh', (
    tester,
  ) async {
    layarHp(tester);
    final server = ServerInfoPalsu(contohInfo());
    await tester.pumpWidget(
      bungkus(InfoKegiatanScreen(infoService: buatInfoPalsu(server.tangani))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upacara Hari Sumpah Pemuda'), findsOneWidget);
    expect(find.text('Pengambilan Raport Semester Ganjil'), findsOneWidget);
    expect(find.text('Jumat, 09-10-2026'), findsOneWidget);
    expect(find.text('Minggu, 04-10-2026'), findsOneWidget);
    // Hanya info yang punya lampiran yang memiliki tombol unduh
    expect(find.byTooltip('Unduh lampiran'), findsOneWidget);
  });

  testWidgets('Bintang menandai info & filter Penting menyaringnya', (
    tester,
  ) async {
    layarHp(tester);
    final server = ServerInfoPalsu(contohInfo());
    await tester.pumpWidget(
      bungkus(InfoKegiatanScreen(infoService: buatInfoPalsu(server.tangani))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tandai sebagai penting').last);
    await tester.pumpAndSettle();
    expect(server.penting, {1});
    expect(find.byTooltip('Hapus tanda penting'), findsOneWidget);

    await tester.tap(find.byTooltip('Tampilkan info penting saja'));
    await tester.pumpAndSettle();
    expect(server.permintaan.last.url.queryParameters['penting'], '1');
    expect(find.text('Pengambilan Raport Semester Ganjil'), findsOneWidget);
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsNothing);

    // Lepas bintang saat filter aktif -> info hilang dari daftar
    await tester.tap(find.byTooltip('Hapus tanda penting'));
    await tester.pumpAndSettle();
    expect(server.penting, isEmpty);
    expect(find.text('Belum ada info penting'), findsOneWidget);
  });

  testWidgets('Pencarian dikirim ke server setelah berhenti mengetik', (
    tester,
  ) async {
    layarHp(tester);
    final server = ServerInfoPalsu(contohInfo());
    await tester.pumpWidget(
      bungkus(InfoKegiatanScreen(infoService: buatInfoPalsu(server.tangani))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'raport');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(server.permintaan.last.url.queryParameters['cari'], 'raport');
    expect(find.text('Pengambilan Raport Semester Ganjil'), findsOneWidget);
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsNothing);

    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Info tidak ditemukan'), findsOneWidget);
  });

  testWidgets('Detail menampilkan isi, tanggal, dan lampiran', (tester) async {
    layarHp(tester);
    final server = ServerInfoPalsu(contohInfo());
    await tester.pumpWidget(
      bungkus(InfoKegiatanScreen(infoService: buatInfoPalsu(server.tangani))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengambilan Raport Semester Ganjil'));
    await tester.pumpAndSettle();

    expect(find.byType(InfoDetailScreen), findsOneWidget);
    expect(
      find.text('Isi info Pengambilan Raport Semester Ganjil'),
      findsOneWidget,
    );
    expect(find.text('Kamis, 15 Oktober 2026'), findsOneWidget);
    expect(
      find.text('Minggu, 4 Oktober 2026, pukul 07.30 WIB'),
      findsOneWidget,
    );
    expect(find.text('jadwal.pdf'), findsOneWidget);

    // Bintang di detail ikut mengubah daftar
    await tester.tap(find.byTooltip('Tandai sebagai penting'));
    await tester.pumpAndSettle();
    expect(server.penting, {1});
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hapus tanda penting'), findsOneWidget);
  });

  testWidgets('Banner berganti otomatis ke info berikutnya', (tester) async {
    final daftar = contohInfo().map(InfoKegiatan.fromJson).toList();
    InfoKegiatan? diketuk;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerInfoBerjalan(
            daftar: daftar,
            jeda: const Duration(seconds: 2),
            onTapInfo: (info) => diketuk = info,
          ),
        ),
      ),
    );
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsOneWidget);
    expect(find.textContaining('Jum, 9 Okt 2026'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // timer berbunyi
    await tester.pumpAndSettle(); // animasi bergeser ke atas selesai
    expect(find.text('Pengambilan Raport Semester Ganjil'), findsOneWidget);
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsNothing);

    await tester.tap(find.text('Pengambilan Raport Semester Ganjil'));
    expect(diketuk?.idInfo, 1);

    // Setelah info terakhir, kembali ke info pertama
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsOneWidget);
  });

  testWidgets('Beranda: nama + gelar, tanpa label unit, banner berisi info', (
    tester,
  ) async {
    layarHp(tester);
    final server = ServerInfoPalsu(contohInfo());
    await tester.pumpWidget(
      bungkus(
        BerandaScreen(
          pengguna: Pengguna.fromJson(jsonGuruContoh),
          infoService: buatInfoPalsu(server.tangani),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guru Contoh, S.Pd.'), findsOneWidget);
    expect(find.text('SD'), findsNothing); // label unit sudah dihapus
    expect(server.permintaan.first.url.queryParameters['batas'], '5');
    expect(find.text('Upacara Hari Sumpah Pemuda'), findsOneWidget);

    // Menu Info Kegiatan membuka halaman daftar info
    final menu = find.text('Info Kegiatan').last;
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byType(InfoKegiatanScreen), findsOneWidget);
  });
}
