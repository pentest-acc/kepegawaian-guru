import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/screens/admin/admin_jadwal_guru_screen.dart';
import 'package:kepegawaian_guru/screens/admin/admin_pilih_guru_screen.dart';
import 'package:kepegawaian_guru/screens/admin/form_jadwal_screen.dart';
import 'package:kepegawaian_guru/screens/guru/jadwal_mengajar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) =>
    MaterialApp(theme: AppTheme.terang, home: halaman);

/// Server palsu untuk semua API jadwal.
class ServerJadwalPalsu {
  ServerJadwalPalsu({this.libur = const []});

  final List<Map<String, dynamic>> jadwal = [
    jsonJadwalContoh(id: 1, hari: 'Senin', mulai: '07:30', selesai: '09:00'),
    jsonJadwalContoh(
      id: 2,
      hari: 'Senin',
      mulai: '09:30',
      selesai: '10:40',
      kelas: '3A',
    ),
    jsonJadwalContoh(
      id: 3,
      hari: 'Senin',
      mulai: '10:40',
      selesai: '11:50',
      kelas: '2A',
    ),
    jsonJadwalContoh(id: 4, hari: 'Selasa', mapel: 'Matematika', kelas: '2A'),
  ];
  final List<Map<String, dynamic>> libur;
  final List<http.Request> permintaan = [];
  String? tolakSimpan; // isi pesan untuk mensimulasikan jadwal bentrok

  Future<http.Response> tangani(http.Request req) async {
    permintaan.add(req);
    final path = req.url.path;
    if (path.endsWith('jadwal/saya.php')) {
      final dari = req.url.queryParameters['dari']!;
      final sampai = req.url.queryParameters['sampai']!;
      return responJson(200, true, 'ok', {
        'jadwal': jadwal,
        'libur': [
          for (final l in libur)
            if ('${l['tanggal']}'.compareTo(dari) >= 0 &&
                '${l['tanggal']}'.compareTo(sampai) <= 0)
              l,
        ],
      });
    }
    if (path.endsWith('admin/guru.php')) {
      return responJson(200, true, 'ok', {
        'guru': [
          {
            'id_pengguna': 2,
            'nomor_induk': '12345678910',
            'nama_tampil': 'Guru Contoh, S.Pd.',
            'unit': 'SD',
            'jabatan': 'Guru Kelas',
            'status': 'aktif',
            'jumlah_jadwal': jadwal.length,
          },
        ],
      });
    }
    if (path.endsWith('admin/jadwal/daftar.php')) {
      return responJson(200, true, 'ok', {'jadwal': jadwal});
    }
    if (path.endsWith('admin/jadwal/simpan.php')) {
      if (tolakSimpan != null) return responJson(409, false, tolakSimpan!);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final i = jadwal.indexWhere((j) => j['id_jadwal'] == body['id_jadwal']);
      final simpan = {...body, 'id_jadwal': body['id_jadwal'] ?? 99};
      i >= 0 ? jadwal[i] = simpan : jadwal.add(simpan);
      return responJson(200, true, 'ok', {'jadwal': simpan});
    }
    if (path.endsWith('admin/jadwal/hapus.php')) {
      final id = (jsonDecode(req.body) as Map)['id_jadwal'];
      jadwal.removeWhere((j) => j['id_jadwal'] == id);
      return responJson(200, true, 'ok', {'id_jadwal': id});
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

  group('Jadwal Mengajar (guru)', () {
    testWidgets('Hari ini terpilih, status berlangsung & selesai', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerJadwalPalsu();
      await tester.pumpWidget(
        bungkus(
          JadwalMengajarScreen(
            jadwalService: buatJadwalPalsu(server.tangani),
            // Senin, 12 Oktober 2026 pukul 09.45
            sekarang: () => DateTime(2026, 10, 12, 9, 45),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(server.permintaan.first.url.queryParameters, {
        'dari': '2026-10-12',
        'sampai': '2026-10-17',
      });
      expect(find.text('Senin, 12 Oktober 2026'), findsOneWidget);
      expect(find.text('Minggu ini'), findsOneWidget);
      expect(find.text('BAHASA INDONESIA'), findsNWidgets(3));
      expect(find.text('07.30 - 09.00  |  Kelas 3B'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Sedang berlangsung'), findsOneWidget);
      expect(
        find.text('3 jam pelajaran  •  total 3 jam 50 menit'),
        findsOneWidget,
      );
      // Tidak ada jadwal Sabtu -> tab Sabtu tidak muncul
      expect(find.text('Sabtu'), findsNothing);

      await tester.tap(find.text('Selasa'));
      await tester.pumpAndSettle();
      expect(find.text('MATEMATIKA'), findsOneWidget);
      expect(find.text('Sedang berlangsung'), findsNothing);

      await tester.tap(find.text('Rabu'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada jadwal mengajar'), findsOneWidget);
    });

    testWidgets('Jadwal berulang di minggu berikutnya & hari libur', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerJadwalPalsu(
        libur: [
          {'tanggal': '2026-10-19', 'keterangan': 'Libur Contoh'},
        ],
      );
      await tester.pumpWidget(
        bungkus(
          JadwalMengajarScreen(
            jadwalService: buatJadwalPalsu(server.tangani),
            sekarang: () => DateTime(2026, 10, 12, 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Minggu berikutnya'));
      await tester.pumpAndSettle();
      expect(server.permintaan.last.url.queryParameters['dari'], '2026-10-19');
      expect(find.text('Minggu depan'), findsOneWidget);
      // Senin 19 Oktober libur
      expect(find.text('Libur: Libur Contoh'), findsOneWidget);

      // Selasa minggu depan: jadwal tetap sama seperti setiap Selasa
      await tester.tap(find.text('Selasa'));
      await tester.pumpAndSettle();
      expect(find.text('Selasa, 20 Oktober 2026'), findsOneWidget);
      expect(find.text('MATEMATIKA'), findsOneWidget);

      await tester.tap(find.text('Kembali ke hari ini'));
      await tester.pumpAndSettle();
      expect(find.text('Senin, 12 Oktober 2026'), findsOneWidget);
    });

    testWidgets('Hari Minggu langsung menampilkan Senin minggu depan', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerJadwalPalsu();
      await tester.pumpWidget(
        bungkus(
          JadwalMengajarScreen(
            jadwalService: buatJadwalPalsu(server.tangani),
            sekarang: () => DateTime(2026, 10, 18, 10), // Minggu
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(server.permintaan.first.url.queryParameters['dari'], '2026-10-19');
      expect(find.text('Senin, 19 Oktober 2026'), findsOneWidget);
    });

    testWidgets('Tab Sabtu muncul jika ada jadwal Sabtu', (tester) async {
      layarHp(tester);
      final server = ServerJadwalPalsu();
      server.jadwal.add(
        jsonJadwalContoh(id: 9, hari: 'Sabtu', mapel: 'Pramuka', kelas: '4A'),
      );
      await tester.pumpWidget(
        bungkus(
          JadwalMengajarScreen(
            jadwalService: buatJadwalPalsu(server.tangani),
            sekarang: () => DateTime(2026, 10, 12, 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sabtu'));
      await tester.pumpAndSettle();
      expect(find.text('PRAMUKA'), findsOneWidget);
    });
  });

  group('Kelola Jadwal (admin)', () {
    testWidgets('Pilih guru -> lihat jadwal per hari -> ubah -> bentrok', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerJadwalPalsu();
      await tester.pumpWidget(
        bungkus(
          AdminPilihGuruScreen(jadwalService: buatJadwalPalsu(server.tangani)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guru Contoh, S.Pd.'), findsOneWidget);
      await tester.tap(find.text('Guru Contoh, S.Pd.'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminJadwalGuruScreen), findsOneWidget);
      expect(
        find.textContaining('3 jam pelajaran', findRichText: true),
        findsOneWidget,
      ); // Senin
      expect(find.text('Matematika'), findsOneWidget);

      // Ubah jadwal Matematika, server menolak karena bentrok
      server.tolakSimpan =
          'Kelas SD 2A pada jam itu sudah diajar oleh Ahmad Fauzi, S.Pd.I.';
      await tester.tap(find.text('Matematika'));
      await tester.pumpAndSettle();
      expect(find.byType(FormJadwalScreen), findsOneWidget);
      expect(find.text('Ubah Jadwal'), findsOneWidget);
      expect(find.text('07.30'), findsOneWidget); // jam terisi otomatis

      final simpan = find.text('Simpan Perubahan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pesan-gagal-jadwal')), findsOneWidget);
      expect(
        find.textContaining('sudah diajar oleh Ahmad Fauzi'),
        findsOneWidget,
      );
      expect(find.byType(FormJadwalScreen), findsOneWidget);

      // Setelah diperbaiki, simpan berhasil dan kembali ke daftar
      server.tolakSimpan = null;
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Matematika Lanjut',
      );
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.byType(FormJadwalScreen), findsNothing);
      final body =
          jsonDecode(
                server.permintaan
                    .lastWhere((r) => r.url.path.endsWith('simpan.php'))
                    .body,
              )
              as Map<String, dynamic>;
      expect(body['id_jadwal'], 4);
      expect(body['mata_pelajaran'], 'Matematika Lanjut');
      expect(find.text('Matematika Lanjut'), findsOneWidget);
    });

    testWidgets('Form baru menolak isian kosong; hapus jadwal', (tester) async {
      layarHp(tester);
      final server = ServerJadwalPalsu();
      final service = buatJadwalPalsu(server.tangani);
      await tester.pumpWidget(
        bungkus(AdminPilihGuruScreen(jadwalService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guru Contoh, S.Pd.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah Jadwal'));
      await tester.pumpAndSettle();
      final simpan = find.text('Simpan Jadwal');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Pilih jam mulai & selesai.'), findsOneWidget);
      expect(find.text('Kelas wajib diisi.'), findsOneWidget);
      expect(
        server.permintaan.where((r) => r.url.path.endsWith('simpan.php')),
        isEmpty,
      );

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      // Hapus jadwal Matematika
      final hapus = find.byTooltip('Hapus jadwal').last;
      await tester.ensureVisible(hapus);
      await tester.tap(hapus);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(server.jadwal.any((j) => j['id_jadwal'] == 4), isFalse);
      expect(find.text('Matematika'), findsNothing);
    });
  });
}
