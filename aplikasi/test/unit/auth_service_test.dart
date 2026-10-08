import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kepegawaian_guru/models/pengguna.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  late SessionService sesi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sesi = SessionService();
  });

  group('login', () {
    test('berhasil: token & pengguna tersimpan', () async {
      late http.Request diterima;
      final auth = buatAuthPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'Login berhasil', {
          'token': 'a' * 64,
          'pengguna': jsonGuruContoh,
        });
      }, sesi: sesi);

      final pengguna = await auth.login(' 12345678910 ', 'guru123');

      expect(pengguna.namaLengkap, 'Guru Contoh, S.Pd.');
      expect(await sesi.ambilToken(), 'a' * 64);
      expect((await sesi.ambilPengguna())?.idPengguna, 2);

      expect(diterima.method, 'POST');
      expect(diterima.url.toString(), 'http://server-tes/api/auth/login.php');
      final body = jsonDecode(diterima.body) as Map<String, dynamic>;
      expect(body['identitas'], '12345678910');
      expect(body['password'], 'guru123');
    });

    test('gagal: pesan dari server diteruskan', () async {
      final auth = buatAuthPalsu(
        (req) async => responJson(401, false, 'Kata sandi salah.'),
        sesi: sesi,
      );

      await expectLater(
        auth.login('guru', 'salah'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.pesan, 'pesan', 'Kata sandi salah.')
              .having((e) => e.kodeStatus, 'kodeStatus', 401),
        ),
      );
      expect(await sesi.ambilToken(), isNull);
    });

    test('server mati: pesan koneksi yang jelas', () async {
      final auth = buatAuthPalsu(
        (req) async => throw http.ClientException('Connection refused'),
        sesi: sesi,
      );

      await expectLater(
        auth.login('guru', 'guru123'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.tidakAdaKoneksi,
            'tidakAdaKoneksi',
            isTrue,
          ),
        ),
      );
    });

    test('jawaban bukan JSON (mis. error PHP) ditangani', () async {
      final auth = buatAuthPalsu(
        (req) async => http.Response('<b>Fatal error</b>', 500),
        sesi: sesi,
      );

      await expectLater(
        auth.login('guru', 'guru123'),
        throwsA(
          isA<ApiException>().having((e) => e.kodeStatus, 'kodeStatus', 500),
        ),
      );
    });
  });

  test('register mengirim data & membaca kesalahan per kolom', () async {
    final auth = buatAuthPalsu(
      (req) async => responJson(422, false, 'Format email tidak valid.', {
        'kesalahan': {'email': 'Format email tidak valid.'},
      }),
      sesi: sesi,
    );

    await expectLater(
      auth.register(
        namaLengkap: 'Siti',
        nomorInduk: '2026001',
        email: 'salah',
        noHp: '081234567890',
        unit: 'TK',
        jenisKelamin: 'P',
        password: 'rahasia',
        konfirmasiPassword: 'rahasia',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kesalahan['email'],
          'kesalahan email',
          'Format email tidak valid.',
        ),
      ),
    );
  });

  group('cekSesi', () {
    Future<void> simpanSesiContoh() async {
      final auth = buatAuthPalsu(
        (req) async => responJson(200, true, 'ok', {
          'token': 'b' * 64,
          'pengguna': jsonGuruContoh,
        }),
        sesi: sesi,
      );
      await auth.login('guru', 'guru123');
    }

    test('tanpa token -> null tanpa memanggil server', () async {
      var dipanggil = false;
      final auth = buatAuthPalsu((req) async {
        dipanggil = true;
        return responJson(200, true, 'ok');
      }, sesi: sesi);

      expect(await auth.cekSesi(), isNull);
      expect(dipanggil, isFalse);
    });

    test('token valid -> data terbaru & header Authorization', () async {
      await simpanSesiContoh();
      late http.Request diterima;
      final auth = buatAuthPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'ok', {
          'pengguna': {...jsonGuruContoh, 'jabatan': 'Wali Kelas'},
        });
      }, sesi: sesi);

      final pengguna = await auth.cekSesi();

      expect(pengguna?.jabatan, 'Wali Kelas');
      expect(diterima.headers['Authorization'], 'Bearer ${'b' * 64}');
      expect((await sesi.ambilPengguna())?.jabatan, 'Wali Kelas');
    });

    test('token kedaluwarsa (401) -> sesi dihapus', () async {
      await simpanSesiContoh();
      final auth = buatAuthPalsu(
        (req) async => responJson(401, false, 'Sesi berakhir'),
        sesi: sesi,
      );

      expect(await auth.cekSesi(), isNull);
      expect(await sesi.ambilToken(), isNull);
    });

    test('server tidak bisa dihubungi -> pakai data tersimpan', () async {
      await simpanSesiContoh();
      final auth = buatAuthPalsu(
        (req) async => throw http.ClientException('offline'),
        sesi: sesi,
      );

      final pengguna = await auth.cekSesi();

      expect(pengguna?.nomorInduk, '12345678910');
      expect(await sesi.ambilToken(), isNotNull);
    });
  });

  test('logout tetap menghapus sesi walau server error', () async {
    await sesi.simpan('c' * 64, Pengguna.fromJson(jsonGuruContoh));
    final auth = buatAuthPalsu(
      (req) async => throw http.ClientException('offline'),
      sesi: sesi,
    );

    await auth.logout();

    expect(await sesi.ambilToken(), isNull);
    expect(await sesi.ambilPengguna(), isNull);
  });
}
