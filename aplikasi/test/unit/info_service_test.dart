import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kepegawaian_guru/models/info_kegiatan.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('InfoKegiatan.fromJson', () {
    test('membaca tanggal, lampiran, dan tanda penting', () {
      final info = InfoKegiatan.fromJson(
        jsonInfoContoh(penting: true, berlampiran: true),
      );

      expect(info.idInfo, 1);
      expect(info.dibuatPada, DateTime(2026, 10, 6, 9));
      expect(info.tanggalKegiatan, DateTime(2026, 10, 15));
      expect(info.penting, isTrue);
      expect(info.lampiran?.nama, 'jadwal.pdf');
      expect(info.lampiran?.url, endsWith('/uploads/lampiran/jadwal.pdf'));
    });

    test('tanpa lampiran & penting berupa angka', () {
      final info = InfoKegiatan.fromJson({
        ...jsonInfoContoh(),
        'id_info': '7',
        'penting': 0,
      });

      expect(info.idInfo, 7);
      expect(info.lampiran, isNull);
      expect(info.penting, isFalse);
      expect(info.copyWith(penting: true).penting, isTrue);
    });
  });

  group('InfoService', () {
    test('daftar mengirim parameter cari, penting, batas', () async {
      late http.Request diterima;
      final service = buatInfoPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'ok', {
          'info': [jsonInfoContoh(id: 2), jsonInfoContoh(id: 1)],
          'jumlah': 2,
        });
      });

      final hasil = await service.daftar(
        cari: ' raport UAS ',
        hanyaPenting: true,
        batas: 5,
      );

      expect(hasil.map((i) => i.idInfo), [2, 1]);
      expect(diterima.url.path, '/api/info/daftar.php');
      expect(diterima.url.queryParameters, {
        'cari': 'raport UAS',
        'penting': '1',
        'batas': '5',
      });
    });

    test('daftar tanpa parameter tidak menambah query', () async {
      late http.Request diterima;
      final service = buatInfoPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'ok', {'info': [], 'jumlah': 0});
      });

      expect(await service.daftar(), isEmpty);
      expect(diterima.url.toString(), 'http://server-tes/api/info/daftar.php');
    });

    test('tandaiPenting mengirim id dan status', () async {
      late http.Request diterima;
      final service = buatInfoPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'Ditandai', {
          'id_info': 3,
          'penting': true,
        });
      });

      await service.tandaiPenting(3, true);

      expect(diterima.method, 'POST');
      expect(diterima.url.path, '/api/info/tandai.php');
      expect(jsonDecode(diterima.body), {'id_info': 3, 'penting': true});
    });

    test('detail info yang sudah dihapus -> ApiException 404', () async {
      final service = buatInfoPalsu(
        (req) async => responJson(404, false, 'Info tidak ditemukan.'),
      );

      await expectLater(
        service.detail(99),
        throwsA(
          isA<ApiException>().having((e) => e.kodeStatus, 'kodeStatus', 404),
        ),
      );
    });
  });
}
