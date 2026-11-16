import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/screens/admin/admin_lokasi_absen_screen.dart';
import 'package:kepegawaian_guru/screens/admin/form_lokasi_screen.dart';
import 'package:kepegawaian_guru/screens/admin/pengaturan_sistem_screen.dart';
import 'package:kepegawaian_guru/screens/auth/login_screen.dart';
import 'package:kepegawaian_guru/screens/guru/absen_screen.dart';
import 'package:kepegawaian_guru/services/perangkat_absen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) =>
    MaterialApp(theme: AppTheme.terang, home: halaman);

/// Posisi ± 30 m dari Lokasi 2 (Gedung SD) pada [jsonLokasiContoh].
const posisiDiGedungSd = PosisiAbsen(lat: -6.17527, lng: 107.03);

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
      return responJson(
        201,
        true,
        'Absen masuk berhasil pukul 06.33 di Gedung SD.',
        {'absensi': jsonAbsensiContoh()},
      );
    }
    if (path.endsWith('absen/pulang.php')) {
      return responJson(
        200,
        true,
        'Absen pulang berhasil pukul 13.05 di Gedung SD. Tercatat pulang '
        'lebih awal 55 menit.',
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

  Future<KameraPalsu> bukaAbsen(
    WidgetTester tester,
    ServerAbsenPalsu server, {
    LokasiPerangkat lokasi = const LokasiPalsu(posisi: posisiDiGedungSd),
  }) async {
    layarHp(tester);
    final kamera = KameraPalsu();
    await tester.pumpWidget(
      bungkus(
        AbsenScreen(
          // Key baru agar halaman dibuat ulang saat dipanggil dua kali
          key: UniqueKey(),
          absenService: buatAbsenPalsu(server.tangani),
          kamera: kamera,
          lokasi: lokasi,
          // Jam HP sengaja berbeda: aplikasi harus mengikuti jam server
          sekarang: () => DateTime(2026, 11, 10, 20, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return kamera;
  }

  /// Gulir sampai tombol terlihat (daftar dibangun bertahap), lalu ambil.
  Future<FilledButton> tombol(WidgetTester tester, String teks) async {
    final cari = find.widgetWithText(FilledButton, teks);
    await tester.scrollUntilVisible(
      cari,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    return tester.widget<FilledButton>(cari);
  }

  group('Absen guru', () {
    testWidgets('Kamera + lokasi saat foto, lalu absen masuk di Gedung SD', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh());
      final kamera = await bukaAbsen(tester, server);

      // Desain 1: kartu kosong + tombol Buka Kamera (bukan unggah gambar)
      expect(find.text('Foto selfie langsung dari kamera'), findsOneWidget);
      expect(find.text('Upload Gambar'), findsNothing);
      await tester.tap(find.text('Buka Kamera'));
      await tester.pumpAndSettle();
      expect(kamera.judulTerakhir, 'Foto Absen Masuk');

      // Desain 2: foto + jam server + lokasi terdekat + jarak ke semua lokasi
      expect(find.text('06:33'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('Kamu berada di Gedung SD'), findsOneWidget);
      expect(find.text('Lokasi 2 • ± 30 m dari titik absen'), findsOneWidget);
      expect(find.text('Lokasi 1 • Gedung TK'), findsOneWidget);
      expect(find.text('Lokasi 2 • Gedung SD'), findsOneWidget);
      expect(find.text('Lokasi 3 • Gedung KB'), findsOneWidget);
      expect(find.text('30 m'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNotNull);

      await tester.ensureVisible(find.text('Kirim Absen'));
      await tester.tap(find.text('Kirim Absen'));
      await tester.pumpAndSettle();

      // Desain 3: sudah absen masuk, nama lokasi tampil, tombol hilang
      final dikirim = server.permintaan.last;
      expect(dikirim.url.path, endsWith('absen/masuk.php'));
      expect(latin1.decode(dikirim.bodyBytes), contains('-6.1752700'));
      expect(
        find.text('Absen masuk berhasil pukul 06.33 di Gedung SD.'),
        findsOneWidget,
      );
      expect(find.text('Jam Masuk'), findsOneWidget);
      expect(find.text('Gedung SD'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_reg_rounded), findsOneWidget);
      expect(find.text('Kirim Absen'), findsNothing);
      expect(find.text('Absen Pulang'), findsNothing);
      expect(
        find.text('Tombol absen pulang muncul pukul 13.00.'),
        findsOneWidget,
      );
    });

    testWidgets('Di luar semua lokasi: Kirim Absen tidak aktif', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh());
      await bukaAbsen(
        tester,
        server,
        // ± 400 m dari Gedung KB, lebih jauh dari lokasi lain
        lokasi: const LokasiPalsu(
          posisi: PosisiAbsen(lat: -6.1836, lng: 107.02),
        ),
      );
      await tester.tap(find.text('Buka Kamera'));
      await tester.pumpAndSettle();

      expect(find.text('Di luar area lokasi absen'), findsOneWidget);
      expect(
        find.textContaining('Terdekat: Lokasi 3 • Gedung KB, ± 400 m'),
        findsOneWidget,
      );
      expect(find.text('Foto ulang'), findsWidgets);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNull);
    });

    testWidgets('Fake GPS & lokasi tidak terbaca ditolak', (tester) async {
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh()),
        lokasi: const LokasiPalsu(
          posisi: PosisiAbsen(lat: -6.17527, lng: 107.03, palsu: true),
        ),
      );
      await tester.tap(find.text('Buka Kamera'));
      await tester.pumpAndSettle();
      expect(find.text('Terdeteksi lokasi palsu'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNull);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh()),
        lokasi: const LokasiPalsu(gagal: 'GPS/lokasi di HP sedang mati.'),
      );
      await tester.tap(find.text('Buka Kamera'));
      await tester.pumpAndSettle();
      expect(
        find.text('Lokasi tidak terbaca saat foto diambil'),
        findsOneWidget,
      );
      expect(find.text('GPS/lokasi di HP sedang mati.'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNull);
    });

    testWidgets('Belum ada lokasi absen: jarak tidak dicek', (tester) async {
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(adaLokasi: false)),
      );
      await tester.tap(find.text('Buka Kamera'));
      await tester.pumpAndSettle();
      expect(find.text('Lokasi terbaca'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNotNull);
    });

    testWidgets('Pukul 13.05 guru SD: tombol pulang + konfirmasi pulang awal', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(
        jsonHariIniContoh(jam: '13:05:00', absensi: jsonAbsensiContoh()),
      );
      final kamera = await bukaAbsen(tester, server);

      expect(server.dikirimKe('absen/foto.php'), isTrue);
      await tester.tap(find.text('Absen Pulang'));
      await tester.pumpAndSettle();
      expect(kamera.judulTerakhir, 'Foto Absen Pulang');
      expect(find.text('13:05'), findsOneWidget); // jam keluar (jam server)
      expect(
        find.textContaining('tercatat pulang lebih awal 55 menit'),
        findsOneWidget,
      );

      await tombol(tester, 'Kirim Absen');
      await tester.tap(find.text('Kirim Absen'));
      await tester.pumpAndSettle();
      expect(find.text('Pulang lebih awal?'), findsOneWidget);

      // Batal: tidak ada yang dikirim
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(server.dikirimKe('absen/pulang.php'), isFalse);

      await tester.tap(find.text('Kirim Absen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap Absen'));
      await tester.pumpAndSettle();

      expect(server.dikirimKe('absen/pulang.php'), isTrue);
      expect(
        find.text('Absen hari ini sudah lengkap. Terima kasih!'),
        findsOneWidget,
      );
      expect(find.text('Pulang lebih awal 55 menit'), findsOneWidget);
      expect(find.text('Gedung SD'), findsNWidgets(2)); // lokasi masuk & pulang
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
      expect(find.text('Buka Kamera'), findsNothing);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(jam: '15:00:00')),
      );
      expect(
        find.textContaining('Waktu absen masuk sudah lewat'),
        findsOneWidget,
      );
      expect(find.text('Buka Kamera'), findsNothing);
    });
  });

  group('Admin', () {
    testWidgets('Lokasi Absen: daftar, tambah lokasi ke-4, hapus', (
      tester,
    ) async {
      layarHp(tester);
      final permintaan = <http.Request>[];
      final lokasi = [...jsonLokasiContoh];
      final service = buatAbsenPalsu((req) async {
        permintaan.add(req);
        final path = req.url.path;
        if (path.endsWith('admin/lokasi/daftar.php')) {
          return responJson(200, true, 'ok', {'lokasi': lokasi});
        }
        if (path.endsWith('admin/lokasi/simpan.php')) {
          final baru = {
            ...jsonDecode(req.body) as Map<String, dynamic>,
            'id_lokasi': 4,
            'nomor': 4,
          };
          lokasi.add(baru);
          return responJson(201, true, 'ok', {'lokasi': baru});
        }
        if (path.endsWith('admin/lokasi/hapus.php')) {
          final id = (jsonDecode(req.body) as Map)['id_lokasi'];
          lokasi.removeWhere((l) => l['id_lokasi'] == id);
          return responJson(200, true, 'ok', {'id_lokasi': id});
        }
        return responJson(404, false, 'tidak ada');
      });

      await tester.pumpWidget(
        bungkus(
          AdminLokasiAbsenScreen(
            absenService: service,
            perangkat: const LokasiPalsu(
              posisi: PosisiAbsen(lat: -6.1655, lng: 107.041),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gedung TK'), findsOneWidget);
      expect(find.text('Gedung SD'), findsOneWidget);
      expect(find.text('Gedung KB'), findsOneWidget);
      expect(find.text('Radius 150 m'), findsOneWidget);

      // Tambah lokasi ke-4
      await tester.tap(find.text('Tambah Lokasi'));
      await tester.pumpAndSettle();
      expect(find.byType(FormLokasiScreen), findsOneWidget);

      // Isian kosong ditolak
      final simpan = find.widgetWithText(FilledButton, 'Simpan Lokasi');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Nama lokasi wajib diisi.'), findsOneWidget);
      expect(
        find.text('Isi koordinat, contoh: -6.1702113, 107.0251456'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'contoh: Gedung SD'),
        'Gedung SMP',
      );
      await tester.tap(find.text('Gunakan lokasi saya sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('-6.1655000, 107.0410000'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // snackbar hilang
      await tester.pumpAndSettle();

      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();

      final dikirim =
          jsonDecode(permintaan.lastWhere((r) => r.method == 'POST').body)
              as Map<String, dynamic>;
      expect(dikirim, {
        'nama': 'Gedung SMP',
        'lat': -6.1655,
        'lng': 107.041,
        'radius': 100,
        'aktif': true,
      });
      expect(
        find.text('Gedung SMP ditambahkan sebagai Lokasi 4.'),
        findsOneWidget,
      );
      expect(find.text('Gedung SMP'), findsOneWidget);

      // Hapus Gedung KB
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus lokasi').at(2));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Gedung KB?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(jsonDecode(permintaan.lastWhere((r) => r.method == 'POST').body), {
        'id_lokasi': 3,
      });
      expect(find.text('Gedung KB'), findsNothing);
    });

    test('Koordinat dari Google Maps bisa ditempel', () {
      expect(FormLokasiScreen.bacaKoordinat('-6.1702113, 107.0251456'), (
        -6.1702113,
        107.0251456,
      ));
      expect(FormLokasiScreen.bacaKoordinat('(-6.17, 107.02)'), (
        -6.17,
        107.02,
      ));
      expect(FormLokasiScreen.bacaKoordinat('-6.17'), isNull);
      expect(FormLokasiScreen.bacaKoordinat('abc, 107'), isNull);
      expect(FormLokasiScreen.bacaKoordinat('-96.1, 107'), isNull);
    });

    testWidgets('Pengaturan Sistem: jam kerja & toleransi', (tester) async {
      layarHp(tester);
      final permintaan = <http.Request>[];
      Map<String, dynamic> data = {
        'toleransi_terlambat': 15,
        'jumlah_lokasi': 3,
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
        bungkus(PengaturanSistemScreen(absenService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('PUP Sektor V Blok O2'), findsOneWidget);
      expect(find.text('3 lokasi absen aktif'), findsOneWidget);
      expect(find.text('Unit TK'), findsOneWidget);
      expect(find.textContaining('mulai pukul 13.00'), findsOneWidget);

      // Toleransi tidak valid ditolak sebelum dikirim
      await tester.enterText(find.widgetWithText(TextFormField, '15'), '500');
      final simpan = find.widgetWithText(FilledButton, 'Simpan Pengaturan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Isi angka 0 sampai 180.'), findsOneWidget);
      expect(permintaan.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, '500'), '10');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();

      final dikirim = jsonDecode(permintaan.last.body) as Map<String, dynamic>;
      expect(permintaan.last.url.path, endsWith('simpan_absen.php'));
      expect(dikirim['toleransi_terlambat'], 10);
      expect(dikirim.containsKey('lokasi_lat'), isFalse);
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
