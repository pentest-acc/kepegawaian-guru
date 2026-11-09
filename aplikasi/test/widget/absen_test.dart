import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/screens/admin/pengaturan_sistem_screen.dart';
import 'package:kepegawaian_guru/screens/auth/login_screen.dart';
import 'package:kepegawaian_guru/screens/guru/absen_screen.dart';
import 'package:kepegawaian_guru/services/perangkat_absen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) =>
    MaterialApp(theme: AppTheme.terang, home: halaman);

/// Posisi ± 24 m dari titik sekolah pada [jsonHariIniContoh].
const posisiDiSekolah = PosisiAbsen(lat: -6.17035, lng: 107.02525);

/// Server palsu untuk API absen.
class ServerAbsenPalsu {
  ServerAbsenPalsu(this.hariIni);

  Map<String, dynamic> hariIni;
  final List<http.Request> permintaan = [];

  Future<http.Response> tangani(http.Request req) async {
    permintaan.add(req);
    final path = req.url.path;
    if (path.endsWith('absen/hari_ini.php')) {
      return responJson(200, true, 'ok', hariIni);
    }
    if (path.endsWith('absen/foto.php')) {
      return http.Response.bytes(fotoPngKecil, 200);
    }
    if (path.endsWith('absen/masuk.php')) {
      return responJson(201, true, 'Absen masuk berhasil pukul 06.33.', {
        'absensi': jsonAbsensiContoh(),
      });
    }
    if (path.endsWith('absen/pulang.php')) {
      return responJson(
        200,
        true,
        'Absen pulang berhasil pukul 13.05. Tercatat pulang lebih awal 55 menit.',
        {'absensi': jsonAbsensiContoh(pulang: '13:05', menitPulangAwal: 55)},
      );
    }
    return responJson(404, false, 'tidak ada');
  }

  bool dikirimKe(String endpoint) =>
      permintaan.any((r) => r.url.path.endsWith(endpoint));
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void layarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> bukaAbsen(
    WidgetTester tester,
    ServerAbsenPalsu server, {
    LokasiPerangkat lokasi = const LokasiPalsu(posisi: posisiDiSekolah),
  }) async {
    layarHp(tester);
    await tester.pumpWidget(
      bungkus(
        AbsenScreen(
          // Key baru agar halaman dibuat ulang saat dipanggil dua kali
          key: UniqueKey(),
          absenService: buatAbsenPalsu(server.tangani),
          kamera: const KameraPalsu(),
          lokasi: lokasi,
          // Jam HP sengaja berbeda: aplikasi harus mengikuti jam server
          sekarang: () => DateTime(2026, 11, 10, 20, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton tombol(WidgetTester tester, String teks) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, teks));

  group('Absen guru', () {
    testWidgets('Belum absen: foto + lokasi lalu absen masuk', (tester) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh());
      await bukaAbsen(tester, server);

      // Desain 1: kartu foto kosong + tombol Upload Gambar
      expect(find.text('Ambil foto selfie untuk absen'), findsOneWidget);
      expect(find.text('Selasa, 10 November 2026'), findsOneWidget);
      await tester.tap(find.text('Upload Gambar'));
      await tester.pumpAndSettle();

      // Desain 2: foto + jam (jam server) + kartu lokasi + Upload Absen
      expect(find.text('06:33'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('Kamu berada di area sekolah'), findsOneWidget);
      expect(find.text('± 24 m dari titik absen'), findsOneWidget);
      expect(tombol(tester, 'Upload Absen').onPressed, isNotNull);

      await tester.ensureVisible(find.text('Upload Absen'));
      await tester.tap(find.text('Upload Absen'));
      await tester.pumpAndSettle();

      // Desain 3: sudah absen masuk, tombol hilang sampai 13.00
      expect(server.dikirimKe('absen/masuk.php'), isTrue);
      expect(find.text('Absen masuk berhasil pukul 06.33.'), findsOneWidget);
      expect(find.text('Jam Masuk'), findsOneWidget);
      expect(find.text('06:33'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_reg_rounded), findsOneWidget);
      expect(find.text('Upload Absen'), findsNothing);
      expect(find.text('Absen Pulang'), findsNothing);
      expect(
        find.text('Tombol absen pulang muncul pukul 13.00.'),
        findsOneWidget,
      );
    });

    testWidgets('Di luar radius: tombol Upload Absen tidak aktif', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh());
      await bukaAbsen(
        tester,
        server,
        lokasi: const LokasiPalsu(
          posisi: PosisiAbsen(lat: -6.1802, lng: 107.0251),
        ),
      );
      await tester.tap(find.text('Upload Gambar'));
      await tester.pumpAndSettle();

      expect(find.text('Di luar area sekolah'), findsOneWidget);
      expect(find.textContaining('± 1,1 km dari sekolah'), findsOneWidget);
      expect(tombol(tester, 'Upload Absen').onPressed, isNull);
    });

    testWidgets('Fake GPS & GPS mati ditolak', (tester) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh());
      await bukaAbsen(
        tester,
        server,
        lokasi: const LokasiPalsu(
          posisi: PosisiAbsen(lat: -6.17035, lng: 107.02525, palsu: true),
        ),
      );
      await tester.tap(find.text('Upload Gambar'));
      await tester.pumpAndSettle();
      expect(find.text('Terdeteksi lokasi palsu'), findsOneWidget);
      expect(tombol(tester, 'Upload Absen').onPressed, isNull);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh()),
        lokasi: const LokasiPalsu(gagal: 'GPS/lokasi di HP sedang mati.'),
      );
      await tester.tap(find.text('Upload Gambar'));
      await tester.pumpAndSettle();
      expect(find.text('Lokasi belum terbaca'), findsOneWidget);
      expect(find.text('GPS/lokasi di HP sedang mati.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(tombol(tester, 'Upload Absen').onPressed, isNull);
    });

    testWidgets('Pukul 13.05 guru SD: tombol pulang + konfirmasi pulang awal', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(
        jsonHariIniContoh(jam: '13:05:00', absensi: jsonAbsensiContoh()),
      );
      await bukaAbsen(tester, server);

      expect(server.dikirimKe('absen/foto.php'), isTrue);
      await tester.tap(find.text('Absen Pulang'));
      await tester.pumpAndSettle();
      expect(find.text('13:05'), findsOneWidget); // jam keluar (jam server)
      expect(
        find.textContaining('tercatat pulang lebih awal 55 menit'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Upload Absen'));
      await tester.tap(find.text('Upload Absen'));
      await tester.pumpAndSettle();
      expect(find.text('Pulang lebih awal?'), findsOneWidget);

      // Batal: tidak ada yang dikirim
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(server.dikirimKe('absen/pulang.php'), isFalse);

      await tester.tap(find.text('Upload Absen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap Absen'));
      await tester.pumpAndSettle();

      expect(server.dikirimKe('absen/pulang.php'), isTrue);
      expect(
        find.text('Absen hari ini sudah lengkap. Terima kasih!'),
        findsOneWidget,
      );
      expect(find.text('Pulang lebih awal 55 menit'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Pulang'), findsOneWidget);
    });

    testWidgets('Hari libur & waktu absen masuk sudah lewat', (tester) async {
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(libur: 'Hari Raya Natal')),
      );
      expect(find.text('Hari ini libur'), findsOneWidget);
      expect(find.textContaining('Hari Raya Natal'), findsOneWidget);
      expect(find.text('Upload Gambar'), findsNothing);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(jam: '15:00:00')),
      );
      expect(
        find.textContaining('Waktu absen masuk sudah lewat'),
        findsOneWidget,
      );
      expect(find.text('Upload Gambar'), findsNothing);
    });
  });

  group('Pengaturan Sistem (admin)', () {
    testWidgets('Pakai lokasi sekarang lalu simpan', (tester) async {
      layarHp(tester);
      final permintaan = <http.Request>[];
      Map<String, dynamic> data = {
        'lokasi_lat': null,
        'lokasi_lng': null,
        'radius_absen': 100,
        'toleransi_terlambat': 15,
        'alamat_yayasan': 'PUP Sektor V Blok O2',
        'jam_kerja': [
          {'unit': 'KB', 'jam_masuk': '07:00', 'jam_pulang': '13:00'},
          {'unit': 'TK', 'jam_masuk': '07:00', 'jam_pulang': '13:00'},
          {'unit': 'SD', 'jam_masuk': '07:00', 'jam_pulang': '14:00'},
        ],
      };
      final service = buatAbsenPalsu((req) async {
        permintaan.add(req);
        if (req.method == 'POST') {
          data = {...data, ...jsonDecode(req.body) as Map<String, dynamic>};
        }
        return responJson(200, true, 'ok', data);
      });

      await tester.pumpWidget(
        bungkus(
          PengaturanSistemScreen(
            absenService: service,
            lokasi: const LokasiPalsu(
              posisi: PosisiAbsen(lat: -6.1702113, lng: 107.0251456),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PUP Sektor V Blok O2'), findsOneWidget);
      expect(find.text('Unit TK'), findsOneWidget);
      expect(find.textContaining('mulai pukul 13.00'), findsOneWidget);

      await tester.tap(find.text('Gunakan lokasi saya sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('-6.1702113'), findsOneWidget);
      expect(find.text('107.0251456'), findsOneWidget);
      // Tunggu snackbar hilang agar tidak menutupi tombol Simpan
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Radius tidak valid ditolak sebelum dikirim
      await tester.enterText(find.widgetWithText(TextFormField, '100'), '5');
      final simpan = find.widgetWithText(FilledButton, 'Simpan Pengaturan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Isi angka 20 sampai 5000.'), findsOneWidget);
      expect(permintaan.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, '5'), '150');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();

      final dikirim = jsonDecode(permintaan.last.body) as Map<String, dynamic>;
      expect(permintaan.last.url.path, endsWith('simpan_absen.php'));
      expect(dikirim['lokasi_lat'], -6.1702113);
      expect(dikirim['lokasi_lng'], 107.0251456);
      expect(dikirim['radius_absen'], 150);
      expect((dikirim['jam_kerja'] as List).length, 3);
      expect(find.text('Pengaturan absen disimpan.'), findsOneWidget);
    });
  });

  testWidgets('Halaman login tanpa kotak akun demo', (tester) async {
    layarHp(tester);
    await tester.pumpWidget(bungkus(const LoginScreen()));
    await tester.pump();
    expect(find.textContaining('Akun demo'), findsNothing);
    expect(find.textContaining('admin123'), findsNothing);
  });
}
