import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kepegawaian_guru/models/absensi.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/services/perangkat_absen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Model absen', () {
    test('InfoAbsenHariIni membaca data server', () {
      final info = InfoAbsenHariIni.fromJson(
        jsonHariIniContoh(absensi: jsonAbsensiContoh(pulang: '13:05')),
      );
      expect(info.hari, 'Selasa');
      expect(info.waktuServer, DateTime(2026, 11, 10, 6, 33));
      expect(info.jamKerja.unit, 'SD');
      expect(info.jamKerja.jamPulang, '14:00');
      expect(info.toleransiMenit, 15);
      expect(info.absenPulangMulai, '13:00');
      expect(info.lokasiAbsen.map((l) => l.namaLengkap), [
        'Lokasi 1 • Gedung TK',
        'Lokasi 2 • Gedung SD',
        'Lokasi 3 • Gedung KB',
      ]);
      expect(info.lokasiAbsen[1].radius, 150);
      expect(info.absensi!.lokasiMasuk, 'Gedung SD');
      expect(info.absensi!.sudahMasuk, isTrue);
      expect(info.absensi!.sudahPulang, isTrue);
      expect(info.absensi!.adaFotoPulang, isTrue);
    });

    test('Tanpa lokasi absen & belum absen', () {
      final info = InfoAbsenHariIni.fromJson(
        jsonHariIniContoh(adaLokasi: false, libur: 'Hari Minggu'),
      );
      expect(info.lokasiAbsen, isEmpty);
      expect(info.absensi, isNull);
      expect(info.libur, 'Hari Minggu');
    });

    test('Status izin/sakit/cuti tidak perlu absen', () {
      expect(
        Absensi.fromJson(
          jsonAbsensiContoh(masuk: null, status: 'sakit'),
        ).tanpaAbsen,
        isTrue,
      );
      expect(Absensi.fromJson(jsonAbsensiContoh()).tanpaAbsen, isFalse);
    });

    test('Jarak GPS (Haversine) & format jarak', () {
      // 0,01 derajat lintang ~ 1,1 km (sama dengan hitungan server)
      expect(jarakMeter(-6.1702, 107.0251, -6.1802, 107.0251).round(), 1112);
      const tk = LokasiAbsen(
        nama: 'Gedung TK',
        lat: -6.1702,
        lng: 107.0251,
        radius: 100,
      );
      expect(tk.jarakDari(-6.17035, 107.02525), inInclusiveRange(20, 30));
      expect(formatJarak(350), '350 m');
      expect(formatJarak(1112), '1,1 km');
    });

    test('Lokasi terdekat dari banyak lokasi absen', () {
      final daftar = [
        for (final l in jsonLokasiContoh) LokasiAbsen.fromJson(l),
      ];

      // ± 30 m dari Gedung SD
      final urut = urutkanLokasi(daftar, -6.17527, 107.03);
      expect(urut.map((j) => j.lokasi.nama), [
        'Gedung SD',
        'Gedung TK',
        'Gedung KB',
      ]);
      final terpilih = lokasiAbsenTerpilih(urut)!;
      expect(terpilih.lokasi.nomor, 2);
      expect(terpilih.diDalam, isTrue);

      // Di luar semua radius: tetap ditunjukkan lokasi terdekat
      final jauh = lokasiAbsenTerpilih(urutkanLokasi(daftar, -6.1836, 107.02))!;
      expect(jauh.lokasi.nama, 'Gedung KB');
      expect(jauh.jarak, 400);
      expect(jauh.diDalam, isFalse);

      // Radius tumpang tindih: dipilih yang terdekat di antara yang mencakup
      final besar = [
        const LokasiAbsen(nama: 'A', lat: 0, lng: 0, radius: 5000),
        const LokasiAbsen(nama: 'B', lat: 0, lng: 0.01, radius: 50),
      ];
      expect(
        lokasiAbsenTerpilih(urutkanLokasi(besar, 0, 0.0098))!.lokasi.nama,
        'B',
      );
      expect(lokasiAbsenTerpilih(const []), isNull);
    });

    test('LokasiAbsen ke JSON untuk disimpan admin', () {
      const baru = LokasiAbsen(
        nama: 'Gedung SD',
        lat: -6.175,
        lng: 107.03,
        radius: 150,
      );
      expect(baru.toJson(), {
        'nama': 'Gedung SD',
        'lat': -6.175,
        'lng': 107.03,
        'radius': 150,
        'aktif': true,
      });
      final lama = LokasiAbsen.fromJson(jsonLokasiContoh.first);
      expect(lama.toJson()['id_lokasi'], 1);
    });

    test('PengaturanAbsen bolak-balik JSON', () {
      final asli = {
        'jumlah_lokasi': 3,
        'toleransi_terlambat': 10,
        'alamat_yayasan': 'Bekasi',
        'jam_kerja': [
          {'unit': 'TK', 'jam_masuk': '07:00', 'jam_pulang': '13:00'},
        ],
      };
      final p = PengaturanAbsen.fromJson(asli);
      expect(p.jumlahLokasi, 3);
      final json = p.toJson();
      expect(json['toleransi_terlambat'], 10);
      expect(json.containsKey('jumlah_lokasi'), isFalse);
      expect(json['jam_kerja'], [
        {'unit': 'TK', 'jam_masuk': '07:00', 'jam_pulang': '13:00'},
      ]);
      expect(json.containsKey('alamat_yayasan'), isFalse);
    });
  });

  group('AbsenService', () {
    test('Absen masuk mengirim foto + lokasi (multipart)', () async {
      late http.Request dikirim;
      final service = buatAbsenPalsu((req) async {
        dikirim = req;
        return responJson(201, true, 'Absen masuk berhasil pukul 06.33.', {
          'absensi': jsonAbsensiContoh(),
        });
      });

      final hasil = await service.absenMasuk(
        FotoAbsen(bytes: fotoPngKecil, namaFile: 'selfie.png'),
        const PosisiAbsen(lat: -6.17035, lng: 107.02525, akurasi: 12.4),
      );

      expect(dikirim.url.path, '/api/absen/masuk.php');
      expect(
        dikirim.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      final isi = latin1.decode(dikirim.bodyBytes);
      expect(isi, contains('name="lat"\r\n\r\n-6.1703500'));
      expect(isi, contains('name="lng"\r\n\r\n107.0252500'));
      expect(isi, contains('name="akurasi"\r\n\r\n12'));
      expect(isi, contains('name="foto"; filename="selfie.png"'));
      expect(isi, isNot(contains('lokasi_palsu')));
      expect(hasil.pesan, 'Absen masuk berhasil pukul 06.33.');
      expect(hasil.absensi.jamMasuk, '06:33');
    });

    test('Fake GPS ikut dilaporkan ke server', () async {
      late http.Request dikirim;
      final service = buatAbsenPalsu((req) async {
        dikirim = req;
        return responJson(422, false, 'Terdeteksi aplikasi lokasi palsu.');
      });

      await expectLater(
        service.absenPulang(
          FotoAbsen(bytes: fotoPngKecil, namaFile: 'selfie.png'),
          const PosisiAbsen(lat: 1, lng: 2, palsu: true),
        ),
        throwsA(isA<ApiException>().having((e) => e.kodeStatus, 'kode', 422)),
      );
      expect(dikirim.url.path, '/api/absen/pulang.php');
      expect(latin1.decode(dikirim.bodyBytes), contains('name="lokasi_palsu"'));
    });

    test('Foto absen diambil sebagai bytes, 404 jadi ApiException', () async {
      final service = buatAbsenPalsu((req) async {
        if (req.url.queryParameters['jenis'] == 'masuk') {
          return http.Response.bytes(
            fotoPngKecil,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return responJson(404, false, 'Foto absen tidak ditemukan.');
      });

      expect(await service.ambilFoto(7, 'masuk'), fotoPngKecil);
      await expectLater(
        service.ambilFoto(7, 'pulang'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.pesan,
            'pesan',
            'Foto absen tidak ditemukan.',
          ),
        ),
      );
    });
  });
}
