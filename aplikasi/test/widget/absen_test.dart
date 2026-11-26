import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/models/jadwal_mengajar.dart';
import 'package:kepegawaian_guru/screens/admin/admin_lokasi_absen_screen.dart';
import 'package:kepegawaian_guru/screens/admin/form_jadwal_screen.dart';
import 'package:kepegawaian_guru/screens/admin/form_lokasi_screen.dart';
import 'package:kepegawaian_guru/screens/admin/monitoring_absensi_screen.dart';
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

/// Server palsu untuk API absen guru.
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
    if (path.endsWith('absen/kirim.php')) {
      final idJadwal = RegExp(
        r'name="id_jadwal"\r\n\r\n(\d+)',
      ).firstMatch(latin1.decode(req.bodyBytes))!.group(1)!;
      return responJson(
        201,
        true,
        'Absen Bahasa Indonesia berhasil pukul 07.25 di Gedung SD.',
        {'absensi': jsonAbsensiContoh(idJadwal: int.parse(idJadwal))},
      );
    }
    return responJson(404, false, 'tidak ada');
  }

  List<http.Request> dikirimKe(String endpoint) =>
      permintaan.where((r) => r.url.path.endsWith(endpoint)).toList();
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
          sekarang: () => DateTime(2026, 11, 23, 20, 0),
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

  group('Absen guru per mapel', () {
    testWidgets('Daftar mapel hari ini, lalu absen mapel pertama', (
      tester,
    ) async {
      final server = ServerAbsenPalsu(jsonHariIniContoh(jam: '07:20:00'));
      final kamera = await bukaAbsen(tester, server);

      // Ringkasan: 0 dari 2 mapel, masuk 07.30, boleh pulang 10.40
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text('07.30'), findsWidgets);
      expect(find.text('10.40'), findsWidgets);
      expect(find.text('Mapel hari ini'), findsOneWidget);
      expect(find.text('Gedung SD'), findsOneWidget);
      expect(find.text('Gedung TK'), findsOneWidget);
      expect(find.text('Belum absen'), findsOneWidget);
      // Mapel kedua (09.30) baru dibuka 30 menit sebelumnya
      expect(find.text('Absen dibuka 09.00'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Absen'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Absen'));
      await tester.pumpAndSettle();
      expect(kamera.judulTerakhir, 'Absen Bahasa Indonesia');

      // Desain 2: foto + jam absen + perkiraan status + lokasi
      expect(find.text('Absen Bahasa Indonesia'), findsOneWidget);
      expect(find.text('07:20'), findsOneWidget);
      expect(find.text('Tepat waktu'), findsOneWidget);
      expect(find.text('Kamu berada di Gedung SD'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNotNull);

      await tester.tap(find.text('Kirim Absen'));
      await tester.pumpAndSettle();

      final kirim = server.dikirimKe('absen/kirim.php');
      expect(kirim, hasLength(1));
      expect(
        latin1.decode(kirim.single.bodyBytes),
        contains('name="id_jadwal"\r\n\r\n1'),
      );
      // Kembali ke daftar: mapel pertama sudah hadir
      expect(
        find.text('Absen Bahasa Indonesia berhasil pukul 07.25 di Gedung SD.'),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Hadir • 07.25'), findsOneWidget);
      expect(find.text('Absen di Gedung SD (30 m)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Absen'), findsNothing);
    });

    testWidgets('Terlambat & lewat jam pelajaran tetap bisa absen', (
      tester,
    ) async {
      // 10.00: mapel 1 (07.30-09.00) sudah selesai, mapel 2 (09.30) berlangsung
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(jam: '10:00:00')),
      );
      expect(find.widgetWithText(FilledButton, 'Absen'), findsNWidgets(2));
      expect(find.textContaining('sedang berlangsung'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Absen').first);
      await tester.pumpAndSettle();
      expect(find.text('Lewat jam pelajaran • +150 menit'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Batal'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Absen').last);
      await tester.pumpAndSettle();
      expect(find.text('Terlambat 30 menit'), findsOneWidget);
      // Mapel 2 dijadwalkan di Gedung TK, guru berada di Gedung SD
      await tester.scrollUntilVisible(
        find.textContaining('Mapel ini dijadwalkan di Gedung TK'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Mapel ini dijadwalkan di Gedung TK'),
        findsOneWidget,
      );
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNotNull);
    });

    testWidgets('Di luar semua lokasi: Kirim Absen tidak aktif', (
      tester,
    ) async {
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh()),
        // ± 400 m dari Gedung KB, lebih jauh dari lokasi lain
        lokasi: const LokasiPalsu(
          posisi: PosisiAbsen(lat: -6.1836, lng: 107.02),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Absen'));
      await tester.pumpAndSettle();

      expect(find.text('Di luar area lokasi absen'), findsOneWidget);
      expect(
        find.textContaining('Terdekat: Lokasi 3 • Gedung KB, ± 400 m'),
        findsOneWidget,
      );
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
      await tester.tap(find.widgetWithText(FilledButton, 'Absen'));
      await tester.pumpAndSettle();
      expect(find.text('Terdeteksi lokasi palsu'), findsOneWidget);
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNull);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh()),
        lokasi: const LokasiPalsu(gagal: 'GPS/lokasi di HP sedang mati.'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Absen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Lokasi tidak terbaca saat foto diambil'),
        findsOneWidget,
      );
      expect((await tombol(tester, 'Kirim Absen')).onPressed, isNull);
    });

    testWidgets('Ditandai admin, semua selesai, libur, tanpa jadwal', (
      tester,
    ) async {
      await bukaAbsen(
        tester,
        ServerAbsenPalsu(
          jsonHariIniContoh(
            jam: '11:00:00',
            mapel: [
              jsonMapelContoh(absensi: jsonAbsensiContoh()),
              jsonMapelContoh(
                idJadwal: 2,
                mulai: '09:30',
                selesai: '10:40',
                absensi: jsonAbsensiContoh(
                  idJadwal: 2,
                  jamAbsen: null,
                  status: 'sakit',
                  keterangan: 'Surat dokter',
                  diubahAdmin: true,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Sakit (diisi admin)'), findsOneWidget);
      expect(find.text('Catatan admin: Surat dokter'), findsOneWidget);
      expect(
        find.text(
          'Semua mapel hari ini sudah selesai. Kamu sudah boleh pulang.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Absen'), findsNothing);

      await bukaAbsen(
        tester,
        ServerAbsenPalsu(jsonHariIniContoh(libur: 'Hari Raya Natal')),
      );
      expect(find.text('Hari ini libur'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Absen'), findsNothing);

      await bukaAbsen(tester, ServerAbsenPalsu(jsonHariIniContoh(mapel: [])));
      expect(find.text('Tidak ada jadwal mengajar hari ini'), findsOneWidget);
    });
  });

  group('Admin', () {
    testWidgets('Monitoring Absensi: warna penanda & ubah kehadiran', (
      tester,
    ) async {
      layarHp(tester);
      final permintaan = <http.Request>[];
      final service = buatAbsenPalsu((req) async {
        permintaan.add(req);
        if (req.url.path.endsWith('harian.php')) {
          return responJson(200, true, 'ok', {
            'tanggal': '2026-11-23',
            'hari': 'Senin',
            'waktu_server': '2026-11-23 12:30:00',
            'libur': null,
            'toleransi_menit': 15,
            'guru': [
              {
                'id_pengguna': 4,
                'nomor_induk': '12345678912',
                'nama_tampil': 'Ahmad Fauzi, S.Pd.I.',
                'unit': 'SD',
                'mapel': [
                  jsonMapelContoh(
                    idJadwal: 16,
                    mapel: 'Pendidikan Agama Islam',
                    kelas: '2A',
                  ),
                ],
              },
              {
                'id_pengguna': 2,
                'nomor_induk': '12345678910',
                'nama_tampil': 'Guru Contoh, S.Pd.',
                'unit': 'SD',
                'mapel': [
                  jsonMapelContoh(absensi: jsonAbsensiContoh()),
                  jsonMapelContoh(
                    idJadwal: 3,
                    mulai: '10:40',
                    selesai: '11:50',
                    absensi: jsonAbsensiContoh(
                      id: 9,
                      idJadwal: 3,
                      mulai: '10:40',
                      selesai: '11:50',
                      jamAbsen: '12:30',
                      status: 'terlambat',
                      menitTerlambat: 110,
                      lewatJam: true,
                    ),
                  ),
                ],
              },
            ],
          });
        }
        return responJson(200, true, 'ok', {
          'absensi': jsonAbsensiContoh(jamAbsen: null, diubahAdmin: true),
        });
      });

      await tester.pumpWidget(
        bungkus(
          MonitoringAbsensiScreen(
            absenService: service,
            tanggal: DateTime(2026, 11, 23),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(permintaan.first.url.queryParameters['tanggal'], '2026-11-23');
      expect(find.text('Senin, 23 November 2026'), findsOneWidget);
      expect(find.text('Hadir: 1'), findsOneWidget);
      expect(find.text('Terlambat: 1'), findsOneWidget);
      expect(find.text('Belum absen: 1'), findsOneWidget);
      expect(find.text('Hadir • 07.25'), findsOneWidget);
      expect(
        find.text('Lewat jam pelajaran • +110 menit • 12.30'),
        findsOneWidget,
      );
      expect(find.text('Belum absen'), findsOneWidget);

      // Ahmad lupa absen: admin menandai hadir
      await tester.tap(find.textContaining('Pendidikan Agama Islam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hadir'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Lupa absen');
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      final ubah = permintaan.firstWhere(
        (r) => r.url.path.endsWith('ubah.php'),
      );
      expect(jsonDecode(ubah.body), {
        'id_jadwal': 16,
        'tanggal': '2026-11-23',
        'status': 'hadir',
        'keterangan': 'Lupa absen',
      });
      expect(
        find.text('Kehadiran Ahmad Fauzi, S.Pd.I. disimpan.'),
        findsOneWidget,
      );
      // Data dimuat ulang setelah disimpan
      expect(
        permintaan.where((r) => r.url.path.endsWith('harian.php')),
        hasLength(2),
      );
    });

    testWidgets('Form jadwal: pilih gedung tempat mengajar', (tester) async {
      layarHp(tester);
      final jadwalDikirim = <Map<String, dynamic>>[];
      final jadwalService = buatJadwalPalsu((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        jadwalDikirim.add(body);
        return responJson(200, true, 'ok', {
          'jadwal': {...body, 'id_jadwal': 1, 'lokasi': 'Gedung SD'},
        });
      });
      final absenService = buatAbsenPalsu(
        (req) async =>
            responJson(200, true, 'ok', {'lokasi': jsonLokasiContoh}),
      );

      await tester.pumpWidget(
        bungkus(
          FormJadwalScreen(
            guru: const GuruRingkas(
              idPengguna: 2,
              nomorInduk: '12345678910',
              namaTampil: 'Guru Contoh, S.Pd.',
              jabatan: 'Guru Kelas',
              status: 'aktif',
              jumlahJadwal: 0,
              unit: 'SD',
            ),
            jadwal: const JadwalMengajar(
              idJadwal: 1,
              idPengguna: 2,
              hari: 'Senin',
              jamMulai: '07:30',
              jamSelesai: '09:00',
              unit: 'SD',
              kelas: '3B',
              mataPelajaran: 'Bahasa Indonesia',
            ),
            jadwalService: jadwalService,
            absenService: absenService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ditentukan'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('pilih-gedung')));
      await tester.tap(find.byKey(const Key('pilih-gedung')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lokasi 2 • Gedung SD').last);
      await tester.pumpAndSettle();

      final simpan = find.widgetWithText(FilledButton, 'Simpan Perubahan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(jadwalDikirim.single['id_lokasi'], 2);
    });

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

    testWidgets('Pengaturan Sistem: toleransi & jam buka absen', (
      tester,
    ) async {
      layarHp(tester);
      final permintaan = <http.Request>[];
      Map<String, dynamic> data = {
        'toleransi_terlambat': 15,
        'buka_absen_menit': 30,
        'kuota_cuti_tahunan': 12,
        'jumlah_lokasi': 3,
        'alamat_yayasan': 'PUP Sektor V Blok O2',
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
      expect(find.textContaining('jadwal mengajarnya'), findsOneWidget);
      expect(find.textContaining('Unit TK'), findsNothing);

      // Toleransi tidak valid ditolak sebelum dikirim
      await tester.enterText(find.widgetWithText(TextFormField, '15'), '500');
      final simpan = find.widgetWithText(FilledButton, 'Simpan Pengaturan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Isi angka 0 sampai 180.'), findsOneWidget);
      expect(permintaan.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, '500'), '10');
      await tester.enterText(find.widgetWithText(TextFormField, '30'), '45');
      await tester.enterText(find.widgetWithText(TextFormField, '12'), '99');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();
      expect(find.text('Isi angka 0 sampai 60.'), findsOneWidget);
      expect(permintaan.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, '99'), '14');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.pumpAndSettle();

      expect(jsonDecode(permintaan.last.body), {
        'toleransi_terlambat': 10,
        'buka_absen_menit': 45,
        'kuota_cuti_tahunan': 14,
      });
      expect(find.text('Pengaturan absen & cuti disimpan.'), findsOneWidget);
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
