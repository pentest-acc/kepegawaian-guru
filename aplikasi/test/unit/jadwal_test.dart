import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kepegawaian_guru/models/jadwal_mengajar.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/utils/hari.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('JadwalMengajar', () {
    test('fromJson, jam tampil, dan durasi', () {
      final j = JadwalMengajar.fromJson(
        jsonJadwalContoh(mulai: '07:30:00', selesai: '09:00:00'),
      );
      expect(j.jamMulai, '07:30');
      expect(j.jamTampil, '07.30 - 09.00');
      expect(j.menitMulai, 450);
      expect(j.durasiMenit, 90);
    });

    test('toJson tanpa id untuk jadwal baru', () {
      const baru = JadwalMengajar(
        idPengguna: 2,
        hari: 'Rabu',
        jamMulai: '10:00',
        jamSelesai: '11:00',
        unit: 'SD',
        kelas: '4A',
        mataPelajaran: 'IPAS',
      );
      expect(baru.toJson().containsKey('id_jadwal'), isFalse);
      expect(baru.toJson()['hari'], 'Rabu');
    });
  });

  group('Hari', () {
    test('nama hari', () {
      expect(Hari.nama(DateTime(2026, 10, 12)), 'Senin');
      expect(Hari.nama(DateTime(2026, 10, 17)), 'Sabtu');
      expect(Hari.nama(DateTime(2026, 10, 18)), 'Minggu');
    });

    test('Senin dari minggu yang sama (Minggu = akhir minggu)', () {
      expect(
        Hari.seninDari(DateTime(2026, 10, 15, 13)),
        DateTime(2026, 10, 12),
      );
      expect(Hari.seninDari(DateTime(2026, 10, 18)), DateTime(2026, 10, 12));
      expect(Hari.seninDari(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
      // Melewati pergantian bulan
      expect(Hari.seninDari(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    });

    test('tanggal untuk hari tertentu', () {
      final senin = DateTime(2026, 12, 21);
      expect(Hari.tanggalPada(senin, 'Jumat'), DateTime(2026, 12, 25));
    });
  });

  group('JadwalService', () {
    test('jadwalSaya mengirim rentang tanggal & membaca libur', () async {
      late http.Request diterima;
      final service = buatJadwalPalsu((req) async {
        diterima = req;
        return responJson(200, true, 'ok', {
          'jadwal': [jsonJadwalContoh()],
          'libur': [
            {'tanggal': '2026-12-25', 'keterangan': 'Hari Raya Natal'},
          ],
        });
      });

      final hasil = await service.jadwalSaya(
        dari: DateTime(2026, 12, 21),
        sampai: DateTime(2026, 12, 26),
      );

      expect(diterima.url.path, '/api/jadwal/saya.php');
      expect(diterima.url.queryParameters, {
        'dari': '2026-12-21',
        'sampai': '2026-12-26',
      });
      expect(hasil.jadwal.single.kelas, '3B');
      expect(hasil.libur.single.tanggal, DateTime(2026, 12, 25));
    });

    test('simpan mengirim data jadwal; bentrok -> ApiException 409', () async {
      late Map<String, dynamic> body;
      final service = buatJadwalPalsu((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return responJson(409, false, 'Bentrok dengan jadwal guru ini.');
      });

      await expectLater(
        service.simpan(
          const JadwalMengajar(
            idJadwal: 7,
            idPengguna: 2,
            hari: 'Senin',
            jamMulai: '08:00',
            jamSelesai: '08:30',
            unit: 'SD',
            kelas: '4A',
            mataPelajaran: 'PAI',
          ),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.kodeStatus, 'kodeStatus', 409),
        ),
      );
      expect(body['id_jadwal'], 7);
      expect(body['jam_mulai'], '08:00');
    });

    test('daftarGuru membaca nama tampil & jumlah jadwal', () async {
      final service = buatJadwalPalsu(
        (req) async => responJson(200, true, 'ok', {
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
        }),
      );
      final guru = (await service.daftarGuru()).single;
      expect(guru.namaTampil, 'Ahmad Fauzi, S.Pd.I.');
      expect(guru.jumlahJadwal, 4);
      expect(guru.aktif, isTrue);
    });
  });
}
