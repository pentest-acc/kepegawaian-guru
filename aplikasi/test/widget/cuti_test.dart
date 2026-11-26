import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/models/pengguna.dart';
import 'package:kepegawaian_guru/screens/admin/admin_pilih_guru_screen.dart';
import 'package:kepegawaian_guru/screens/admin/dashboard_admin_screen.dart';
import 'package:kepegawaian_guru/screens/admin/monitoring_absensi_screen.dart';
import 'package:kepegawaian_guru/screens/admin/persetujuan_cuti_screen.dart';
import 'package:kepegawaian_guru/screens/guru/absen_screen.dart';
import 'package:kepegawaian_guru/screens/guru/cuti_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Widget bungkus(Widget halaman) =>
    MaterialApp(theme: AppTheme.terang, home: halaman);

/// Server palsu untuk semua API cuti (guru & admin) dan API terkait.
class ServerCutiPalsu {
  final List<http.Request> permintaan = [];

  /// Pengajuan milik guru (cuti/saya.php).
  List<Map<String, dynamic>> milikGuru = [
    jsonCutiContoh(),
    jsonCutiContoh(
      id: 2,
      jenis: 'sakit',
      mulai: '2026-11-24',
      selesai: '2026-11-25',
      alasan: 'Demam tinggi, harus istirahat',
      status: 'disetujui',
      adaLampiran: true,
      catatan: 'Semoga lekas sembuh',
    ),
    jsonCutiContoh(
      id: 3,
      jenis: 'izin',
      mulai: '2026-11-20',
      selesai: '2026-11-20',
      jumlahHari: 1,
      alasan: 'Mengurus administrasi kependudukan',
      status: 'ditolak',
      catatan: 'Ada rapat guru',
    ),
  ];

  /// Pesan galat untuk cuti/hitung.php (null = berhasil).
  String? galatHitung;

  List<http.Request> ke(String endpoint) =>
      permintaan.where((r) => r.url.path.endsWith(endpoint)).toList();

  Future<http.Response> tangani(http.Request req) async {
    permintaan.add(req);
    final path = req.url.path;
    final q = req.url.queryParameters;

    if (path.endsWith('cuti/saya.php')) {
      return responJson(200, true, 'ok', {
        'hari_ini': '2026-11-26',
        'kuota': jsonKuotaContoh(),
        'pengajuan': milikGuru,
      });
    }
    if (path.endsWith('cuti/hitung.php')) {
      if (galatHitung != null) return responJson(422, false, galatHitung!);
      final duaHari = q['tanggal_mulai'] != q['tanggal_selesai'];
      return responJson(200, true, 'ok', {
        'jenis': q['jenis'],
        'tanggal_mulai': q['tanggal_mulai'],
        'tanggal_selesai': q['tanggal_selesai'],
        'jumlah_hari': duaHari ? 2 : 1,
        'jumlah_mapel': duaHari ? 3 : 2,
        'hari': duaHari
            ? jsonHariCutiContoh()
            : jsonHariCutiContoh().take(1).toList(),
        'kuota': q['jenis'] == 'cuti' ? jsonKuotaContoh() : null,
        'wajib_lampiran': q['jenis'] == 'sakit' && duaHari,
      });
    }
    if (path.endsWith('cuti/ajukan.php')) {
      return responJson(
        201,
        true,
        'Pengajuan sakit 24 Nov 2026 - 25 Nov 2026 (2 hari) terkirim. '
        'Tunggu persetujuan admin.',
        {
          'cuti': jsonCutiContoh(id: 9, jenis: 'sakit'),
          'kuota': jsonKuotaContoh(),
        },
      );
    }
    if (path.endsWith('cuti/batal.php')) {
      final id = (jsonDecode(req.body) as Map)['id_cuti'];
      milikGuru = milikGuru.where((c) => c['id_cuti'] != id).toList();
      return responJson(200, true, 'Pengajuan cuti dibatalkan.', {
        'kuota': jsonKuotaContoh(diajukan: 0),
      });
    }
    if (path.endsWith('cuti/lampiran.php')) {
      return http.Response.bytes(
        fotoPngKecil,
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    if (path.endsWith('admin/cuti/daftar.php')) {
      final menunggu = [
        jsonCutiContoh(denganGuru: true, jumlahMapel: 3),
        jsonCutiContoh(
          id: 2,
          jenis: 'sakit',
          mulai: '2026-11-24',
          selesai: '2026-11-25',
          alasan: 'Demam tinggi, harus istirahat',
          adaLampiran: true,
          denganGuru: true,
          jumlahMapel: 2,
        ),
      ];
      return responJson(200, true, 'ok', {
        'jumlah_menunggu': 2,
        'pengajuan': q['status'] == 'menunggu' ? menunggu : const [],
      });
    }
    if (path.endsWith('admin/cuti/detail.php')) {
      final id = int.parse(q['id_cuti']!);
      return responJson(200, true, 'ok', {
        'cuti': id == 1
            ? jsonCutiContoh(denganGuru: true)
            : jsonCutiContoh(
                id: 2,
                jenis: 'sakit',
                mulai: '2026-11-24',
                selesai: '2026-11-25',
                alasan: 'Demam tinggi, harus istirahat',
                adaLampiran: true,
                denganGuru: true,
              ),
        'hari': jsonHariCutiContoh(),
        'jumlah_mapel': 3,
        'kuota': jsonKuotaContoh(diajukan: 0),
        'bertumpuk': null,
      });
    }
    if (path.endsWith('admin/cuti/proses.php')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final setuju = body['keputusan'] == 'disetujui';
      return responJson(
        200,
        true,
        'Pengajuan cuti Guru Contoh, S.Pd. ${body['keputusan']}.',
        {
          'cuti': jsonCutiContoh(
            denganGuru: true,
            status: setuju ? 'disetujui' : 'ditolak',
          ),
          'kuota': jsonKuotaContoh(),
        },
      );
    }
    if (path.endsWith('absen/hari_ini.php')) {
      return responJson(200, true, 'ok', {
        ...jsonHariIniContoh(),
        'cuti': 'sakit',
      });
    }
    if (path.endsWith('absen/riwayat.php')) {
      return responJson(200, true, 'ok', jsonRiwayatNovember());
    }
    if (path.endsWith('admin/absensi/harian.php')) {
      return responJson(200, true, 'ok', {
        'tanggal': '2026-11-23',
        'hari': 'Senin',
        'waktu_server': '2026-11-23 10:00:00',
        'libur': null,
        'toleransi_menit': 15,
        'guru': [
          {
            'id_pengguna': 2,
            'nomor_induk': '12345678910',
            'nama_tampil': 'Guru Contoh, S.Pd.',
            'unit': 'SD',
            'cuti': 'cuti',
            'mapel': duaMapelContoh(),
          },
        ],
      });
    }
    if (path.endsWith('admin/guru.php')) {
      return responJson(200, true, 'ok', {
        'guru': [
          {
            'id_pengguna': 4,
            'nomor_induk': '12345678912',
            'nama_tampil': 'Ahmad Fauzi, S.Pd.I.',
            'unit': 'SD',
            'jabatan': 'Guru Mapel',
            'status': 'aktif',
            'jumlah_jadwal': 4,
          },
        ],
      });
    }
    return responJson(404, false, 'tidak ada: $path');
  }
}

/// Isi satu field multipart, mis. name="jenis" -> "sakit".
String? isianMultipart(http.Request req, String nama) => RegExp(
  'name="$nama"\\r\\n\\r\\n([^\\r]*)',
).firstMatch(latin1.decode(req.bodyBytes))?.group(1);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void layarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<PemilihFotoPalsu> bukaCuti(
    WidgetTester tester,
    ServerCutiPalsu server,
  ) async {
    layarHp(tester);
    final pemilih = PemilihFotoPalsu();
    await tester.pumpWidget(
      bungkus(
        CutiScreen(
          cutiService: buatCutiPalsu(server.tangani),
          pemilihFoto: pemilih,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pemilih;
  }

  Future<void> gulirSampai(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  Future<void> pilihTanggal(WidgetTester tester, Key kotak, String hari) async {
    await tester.tap(find.byKey(kotak));
    await tester.pumpAndSettle();
    await tester.tap(find.text(hari));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('Cuti / Izin (guru)', () {
    testWidgets('kuota, daftar pengajuan, dan filter status', (tester) async {
      await bukaCuti(tester, ServerCutiPalsu());

      expect(find.text('Kuota Cuti 2026'), findsOneWidget);
      expect(find.text('hari tersisa dari 12 hari'), findsOneWidget);
      expect(find.text('Semua (3)'), findsOneWidget);
      expect(find.text('Menunggu (1)'), findsOneWidget);
      expect(find.text('Cuti • 2 hari'), findsOneWidget);
      expect(find.text('Sen, 7 Des - Sel, 8 Des 2026'), findsOneWidget);
      expect(find.text('Sakit • 2 hari'), findsOneWidget);

      await tester.ensureVisible(find.text('Ditolak (1)'));
      await tester.tap(find.text('Ditolak (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Cuti • 2 hari'), findsNothing);
      expect(find.text('Izin • 1 hari'), findsOneWidget);
      expect(find.text('Catatan admin: Ada rapat guru'), findsOneWidget);
    });

    testWidgets('detail pengajuan, lampiran, dan membatalkan', (tester) async {
      final server = ServerCutiPalsu();
      await bukaCuti(tester, server);

      // Pengajuan yang sudah disetujui: lampiran tampil, tidak bisa dibatalkan
      await tester.tap(find.text('Sakit • 2 hari'));
      await tester.pumpAndSettle();
      expect(find.text('Semoga lekas sembuh'), findsOneWidget);
      expect(find.textContaining('oleh Admin Yayasan'), findsOneWidget);
      expect(server.ke('cuti/lampiran.php'), hasLength(1));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Batalkan pengajuan'), findsNothing);
      Navigator.of(tester.element(find.text('Semoga lekas sembuh'))).pop();
      await tester.pumpAndSettle();

      // Pengajuan yang masih menunggu bisa dibatalkan
      await tester.tap(find.text('Cuti • 2 hari'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pengajuan sedang menunggu persetujuan admin.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, batalkan'));
      await tester.pumpAndSettle();

      expect(jsonDecode(server.ke('cuti/batal.php').single.body), {
        'id_cuti': 1,
      });
      expect(find.text('Pengajuan cuti dibatalkan.'), findsOneWidget);
      expect(server.ke('cuti/saya.php'), hasLength(2));
      expect(find.text('Cuti • 2 hari'), findsNothing);
    });

    testWidgets('form: pratinjau hari & mapel, validasi, kirim + lampiran', (
      tester,
    ) async {
      final server = ServerCutiPalsu();
      final pemilih = await bukaCuti(tester, server);

      await tester.tap(find.text('Ajukan'));
      await tester.pumpAndSettle();
      expect(find.text('Ajukan Cuti / Izin'), findsOneWidget);

      // Belum memilih apa pun
      final kirim = find.widgetWithText(FilledButton, 'Kirim Pengajuan');
      await tester.ensureVisible(kirim);
      await tester.tap(kirim);
      await tester.pumpAndSettle();
      expect(find.text('Pilih jenis dan tanggalnya dulu.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('jenis-sakit')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('jenis-sakit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('wajib foto surat dokter'), findsOneWidget);

      await pilihTanggal(tester, const Key('tanggal-mulai'), '24');
      expect(find.text('1 hari kerja'), findsOneWidget);
      await pilihTanggal(tester, const Key('tanggal-selesai'), '25');
      expect(server.ke('cuti/hitung.php').last.url.queryParameters, {
        'jenis': 'sakit',
        'tanggal_mulai': '2026-11-24',
        'tanggal_selesai': '2026-11-25',
      });
      expect(find.text('2 hari kerja'), findsOneWidget);
      expect(find.text('3 mapel yang ditinggalkan:'), findsOneWidget);
      expect(find.text('Senin, 7 Des'), findsOneWidget);
      expect(
        find.text(
          'Sakit 2 hari atau lebih wajib melampirkan foto surat dokter.',
        ),
        findsOneWidget,
      );

      // Alasan terlalu pendek & lampiran belum ada: tidak dikirim
      await gulirSampai(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Demam');
      await tester.ensureVisible(kirim);
      await tester.tap(kirim);
      await tester.pumpAndSettle();
      expect(find.text('Tuliskan alasan minimal 10 karakter.'), findsOneWidget);
      expect(find.text('Wajib: foto surat dokter.'), findsOneWidget);
      expect(server.ke('cuti/ajukan.php'), isEmpty);

      await gulirSampai(tester, find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Demam tinggi, harus istirahat',
      );
      await tester.ensureVisible(find.text('Galeri'));
      await tester.tap(find.text('Galeri'));
      await tester.pumpAndSettle();
      expect(pemilih.dariKamera, [false]);
      expect(find.text('surat_dokter.png'), findsOneWidget);

      await tester.ensureVisible(kirim);
      await tester.tap(kirim);
      await tester.pumpAndSettle();

      final req = server.ke('cuti/ajukan.php').single;
      expect(isianMultipart(req, 'jenis'), 'sakit');
      expect(isianMultipart(req, 'tanggal_mulai'), '2026-11-24');
      expect(isianMultipart(req, 'tanggal_selesai'), '2026-11-25');
      expect(isianMultipart(req, 'alasan'), 'Demam tinggi, harus istirahat');
      expect(
        latin1.decode(req.bodyBytes),
        contains('name="lampiran"; filename="surat_dokter.png"'),
      );

      // Kembali ke daftar dengan pesan server, lalu daftar dimuat ulang
      expect(find.text('Ajukan Cuti / Izin'), findsNothing);
      expect(find.textContaining('(2 hari) terkirim'), findsOneWidget);
      expect(server.ke('cuti/saya.php'), hasLength(2));
    });

    testWidgets('form: aturan dari server ditampilkan', (tester) async {
      final server = ServerCutiPalsu()
        ..galatHitung =
            'Sisa kuota cuti tahun 2026 tinggal 7 hari, sedangkan pengajuan '
            'ini 9 hari kerja.';
      await bukaCuti(tester, server);
      await tester.tap(find.text('Ajukan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('jenis-cuti')));
      await tester.pumpAndSettle();
      expect(
        find.text('Sisa kuota cuti 2026: 7 dari 12 hari.'),
        findsOneWidget,
      );
      await pilihTanggal(tester, const Key('tanggal-mulai'), '30');
      expect(find.text(server.galatHitung!), findsOneWidget);

      await gulirSampai(tester, find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Cuti panjang bersama keluarga',
      );
      final kirim = find.widgetWithText(FilledButton, 'Kirim Pengajuan');
      await tester.ensureVisible(kirim);
      await tester.tap(kirim);
      await tester.pumpAndSettle();
      expect(server.ke('cuti/ajukan.php'), isEmpty);
    });

    testWidgets('halaman Absen: hari ini cuti, tidak perlu absen', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerCutiPalsu();
      await tester.pumpWidget(
        bungkus(AbsenScreen(absenService: buatAbsenPalsu(server.tangani))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Hari ini kamu sakit (sudah disetujui admin), jadi tidak perlu absen.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sakit (disetujui)'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Absen'), findsNothing);
    });
  });

  group('Persetujuan Cuti (admin)', () {
    Future<void> bukaPersetujuan(
      WidgetTester tester,
      ServerCutiPalsu server,
    ) async {
      layarHp(tester);
      await tester.pumpWidget(
        bungkus(
          PersetujuanCutiScreen(
            cutiService: buatCutiPalsu(server.tangani),
            absenService: buatAbsenPalsu(server.tangani),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('daftar menunggu, detail, lalu setujui', (tester) async {
      final server = ServerCutiPalsu();
      await bukaPersetujuan(tester, server);

      expect(
        server.ke('admin/cuti/daftar.php').single.url.queryParameters['status'],
        'menunggu',
      );
      expect(find.text('Menunggu (2)'), findsOneWidget);
      expect(find.text('Guru Contoh, S.Pd.'), findsNWidgets(2));
      expect(find.text('3 mapel ditinggalkan'), findsOneWidget);
      expect(find.text('Lampiran'), findsOneWidget);

      await tester.tap(find.text('3 mapel ditinggalkan'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Pengajuan'), findsOneWidget);
      expect(find.text('Terpakai 3 dari 12 hari'), findsOneWidget);
      expect(find.text('Jika disetujui: sisa 7 hari.'), findsOneWidget);
      await gulirSampai(tester, find.text('Mapel yang ditinggalkan (3)'));
      expect(find.text('Senin, 7 Desember 2026'), findsOneWidget);

      // Menolak tanpa catatan tidak dikirim
      final tolak = find.widgetWithText(OutlinedButton, 'Tolak');
      await gulirSampai(tester, tolak);
      await tester.tap(tolak);
      await tester.pumpAndSettle();
      expect(
        find.text('Tuliskan alasan penolakan agar guru mengetahuinya.'),
        findsOneWidget,
      );
      expect(server.ke('admin/cuti/proses.php'), isEmpty);

      final setujui = find.widgetWithText(FilledButton, 'Setujui');
      await gulirSampai(tester, setujui);
      await tester.tap(setujui);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, setujui'));
      await tester.pumpAndSettle();

      expect(jsonDecode(server.ke('admin/cuti/proses.php').single.body), {
        'id_cuti': 1,
        'keputusan': 'disetujui',
        'catatan': '',
      });
      expect(find.text('Detail Pengajuan'), findsNothing);
      expect(
        find.text('Pengajuan cuti Guru Contoh, S.Pd. disetujui.'),
        findsOneWidget,
      );
      expect(server.ke('admin/cuti/daftar.php'), hasLength(2));
    });

    testWidgets('tolak dengan catatan, lampiran, dan filter status', (
      tester,
    ) async {
      final server = ServerCutiPalsu();
      await bukaPersetujuan(tester, server);

      await tester.tap(find.text('2 mapel ditinggalkan'));
      await tester.pumpAndSettle();
      expect(server.ke('cuti/lampiran.php'), hasLength(1));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Kuota cuti 2026'), findsNothing); // bukan jenis cuti

      final catatan = find.widgetWithText(TextField, 'Catatan untuk guru');
      await gulirSampai(tester, catatan);
      await tester.enterText(catatan, 'Surat dokter tidak terbaca');
      final tolak = find.widgetWithText(OutlinedButton, 'Tolak');
      await gulirSampai(tester, tolak);
      await tester.tap(tolak);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, tolak'));
      await tester.pumpAndSettle();

      expect(jsonDecode(server.ke('admin/cuti/proses.php').single.body), {
        'id_cuti': 2,
        'keputusan': 'ditolak',
        'catatan': 'Surat dokter tidak terbaca',
      });

      await tester.tap(find.text('Disetujui'));
      await tester.pumpAndSettle();
      expect(
        server.ke('admin/cuti/daftar.php').last.url.queryParameters['status'],
        'disetujui',
      );
      expect(find.text('Belum ada pengajuan.'), findsOneWidget);
    });

    testWidgets('dashboard menampilkan jumlah pengajuan yang menunggu', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerCutiPalsu();
      await tester.pumpWidget(
        bungkus(
          DashboardAdminScreen(
            pengguna: Pengguna.fromJson({
              ...jsonGuruContoh,
              'id_pengguna': 1,
              'nama_lengkap': 'Admin Yayasan',
              'gelar': null,
              'role': 'admin',
              'jabatan': 'Staf Tata Usaha',
            }),
            cutiService: buatCutiPalsu(server.tangani),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 menunggu'), findsOneWidget);
      expect(find.text('Riwayat Absen Guru'), findsOneWidget);

      await tester.tap(find.text('Persetujuan Cuti'));
      await tester.pumpAndSettle();
      expect(find.text('Persetujuan Cuti / Izin'), findsOneWidget);
    });
  });

  group('Riwayat absen guru (admin)', () {
    testWidgets('Monitoring: guru cuti & tombol riwayat absen', (tester) async {
      layarHp(tester);
      final server = ServerCutiPalsu();
      await tester.pumpWidget(
        bungkus(
          MonitoringAbsensiScreen(absenService: buatAbsenPalsu(server.tangani)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cuti (pengajuan disetujui)'), findsOneWidget);
      expect(find.text('Cuti (disetujui)'), findsNWidgets(2));
      expect(find.text('Izin/Sakit/Cuti: 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Riwayat absen Guru Contoh, S.Pd.'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Absen'), findsOneWidget);
      expect(find.text('Guru Contoh, S.Pd.'), findsOneWidget);
      expect(server.ke('absen/riwayat.php').single.url.queryParameters, {
        'bulan': '2026-11',
        'id_pengguna': '2',
      });
    });

    testWidgets('menu Riwayat Absen Guru: pilih guru lalu lihat kalendernya', (
      tester,
    ) async {
      layarHp(tester);
      final server = ServerCutiPalsu();
      await tester.pumpWidget(
        bungkus(
          AdminPilihGuruScreen(
            tujuan: TujuanPilihGuru.riwayatAbsen,
            jadwalService: buatJadwalPalsu(server.tangani),
            absenService: buatAbsenPalsu(server.tangani),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Absen Guru'), findsOneWidget);

      await tester.tap(find.text('Ahmad Fauzi, S.Pd.I.'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Absen'), findsOneWidget);
      expect(find.text('Ahmad Fauzi, S.Pd.I.'), findsOneWidget);
      expect(
        server
            .ke('absen/riwayat.php')
            .single
            .url
            .queryParameters['id_pengguna'],
        '4',
      );
    });
  });
}
