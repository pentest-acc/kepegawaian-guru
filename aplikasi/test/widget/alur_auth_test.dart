import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepegawaian_guru/config/app_routes.dart';
import 'package:kepegawaian_guru/config/app_theme.dart';
import 'package:kepegawaian_guru/models/pengguna.dart';
import 'package:kepegawaian_guru/screens/auth/login_screen.dart';
import 'package:kepegawaian_guru/screens/auth/register_screen.dart';
import 'package:kepegawaian_guru/screens/guru/beranda_screen.dart';
import 'package:kepegawaian_guru/screens/splash/splash_screen.dart';
import 'package:kepegawaian_guru/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Membungkus halaman dengan MaterialApp + route aplikasi.
Widget bungkus(Widget halaman) {
  return MaterialApp(
    theme: AppTheme.terang,
    onGenerateRoute: AppRoutes.buatRoute,
    home: halaman,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Ukuran layar seperti HP (360 x 780).
  void layarHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Splash tanpa sesi login -> pindah ke halaman Login', (
    tester,
  ) async {
    layarHp(tester);
    final auth = buatAuthPalsu((req) async => responJson(200, true, 'ok'));

    await tester.pumpWidget(
      bungkus(
        SplashScreen(
          authService: auth,
          durasiMinimal: const Duration(milliseconds: 300),
        ),
      ),
    );
    expect(find.text('Kepegawaian Guru'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Login kosong menampilkan pesan wajib diisi', (tester) async {
    layarHp(tester);
    await tester.pumpWidget(bungkus(const LoginScreen()));

    final tombol = find.widgetWithText(FilledButton, 'Masuk');
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pump();

    expect(find.text('Email / Nomor Induk wajib diisi.'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
  });

  testWidgets('Login salah menampilkan pesan dari server', (tester) async {
    layarHp(tester);
    final auth = buatAuthPalsu(
      (req) async =>
          responJson(401, false, 'Email/Nomor Induk atau kata sandi salah.'),
    );
    await tester.pumpWidget(bungkus(LoginScreen(authService: auth)));

    await tester.enterText(find.byType(TextFormField).at(0), 'guru');
    await tester.enterText(find.byType(TextFormField).at(1), 'salah');
    final tombol = find.widgetWithText(FilledButton, 'Masuk');
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Email/Nomor Induk atau kata sandi salah.'),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Login guru berhasil -> Beranda tampil sesuai data', (
    tester,
  ) async {
    layarHp(tester);
    final auth = buatAuthPalsu(
      (req) async => responJson(200, true, 'Login berhasil', {
        'token': 'a' * 64,
        'pengguna': jsonGuruContoh,
      }),
    );
    await tester.pumpWidget(bungkus(LoginScreen(authService: auth)));

    await tester.enterText(find.byType(TextFormField).at(0), '12345678910');
    await tester.enterText(find.byType(TextFormField).at(1), 'guru123');
    final tombol = find.widgetWithText(FilledButton, 'Masuk');
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.byType(BerandaScreen), findsOneWidget);
    expect(find.text('Guru Contoh, S.Pd.'), findsOneWidget);
    expect(find.text('12345678910'), findsOneWidget);
    expect(find.text('Guru Kelas'), findsOneWidget);
    for (final menu in BerandaScreen.daftarMenu) {
      // "Info Kegiatan" juga bisa muncul di banner, jadi minimal 1
      expect(find.text(menu.judul), findsAtLeastNWidgets(1));
    }
    expect(await SessionService().ambilToken(), 'a' * 64);
  });

  testWidgets('Menu Beranda membuka halaman fitur', (tester) async {
    layarHp(tester);
    await tester.pumpWidget(
      bungkus(BerandaScreen(pengguna: Pengguna.fromJson(jsonGuruContoh))),
    );

    final menuAbsen = find.text('Absen');
    await tester.ensureVisible(menuAbsen);
    await tester.tap(menuAbsen);
    await tester.pumpAndSettle();

    expect(find.text('Fitur Absen'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(BerandaScreen), findsOneWidget);
  });

  testWidgets('Link "Daftar di sini" membuka halaman Register', (tester) async {
    layarHp(tester);
    await tester.pumpWidget(bungkus(const LoginScreen()));

    final linkDaftar = find.text('Daftar di sini');
    await tester.ensureVisible(linkDaftar);
    await tester.tap(linkDaftar);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('Register: validasi isian lalu kembali membawa email', (
    tester,
  ) async {
    layarHp(tester);
    Map<String, dynamic>? dataTerkirim;
    final auth = buatAuthPalsu((req) async {
      dataTerkirim = jsonDecode(req.body) as Map<String, dynamic>;
      return responJson(201, true, 'Registrasi berhasil.', {
        'id_pengguna': 5,
        'email': 'siti@contoh.test',
      });
    });

    String? emailKembali;
    await tester.pumpWidget(
      bungkus(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                emailKembali = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(authService: auth),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Tekan daftar tanpa mengisi apa pun -> muncul pesan kesalahan
    final tombol = find.widgetWithText(FilledButton, 'Daftar Sekarang');
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pump();
    expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);

    // Isi semua data dengan benar
    final isian = find.byType(TextFormField);
    // Gelar ditulis di kolom nama -> ditolak
    await tester.enterText(isian.at(0), 'Siti Aminah, S.Pd.');
    await tester.pump();
    expect(
      find.text('Tulis nama tanpa gelar. Gelar dipilih di kolom Gelar.'),
      findsOneWidget,
    );
    await tester.enterText(isian.at(0), 'Siti Aminah');
    await tester.enterText(isian.at(1), '2026001');
    await tester.enterText(isian.at(2), 'siti@contoh.test');
    await tester.enterText(isian.at(3), '081234567890');
    await tester.enterText(isian.at(4), 'rahasia1');
    await tester.enterText(isian.at(5), 'rahasia1');

    Future<void> pilih(int urutan, String opsi) async {
      final dropdown = find.byType(DropdownButtonFormField<String>).at(urutan);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(opsi).last);
      await tester.pumpAndSettle();
    }

    await pilih(0, 'S.Pd. (Sarjana Pendidikan)');
    await pilih(1, 'TK - Taman Kanak-kanak');
    await pilih(2, 'Perempuan');

    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Registrasi Berhasil'), findsOneWidget);
    await tester.tap(find.text('Ke Halaman Login'));
    await tester.pumpAndSettle();

    expect(emailKembali, 'siti@contoh.test');
    expect(dataTerkirim?['nama_lengkap'], 'Siti Aminah');
    expect(dataTerkirim?['gelar'], 'S.Pd.');
    expect(dataTerkirim?['unit'], 'TK');
    expect(find.byType(RegisterScreen), findsNothing);
  });
}
