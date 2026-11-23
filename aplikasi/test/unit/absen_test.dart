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

  group('Model absen per mapel', () {
    test('InfoAbsenHariIni membaca data server', () {
      final info = InfoAbsenHariIni.fromJson(
        jsonHariIniContoh(
          mapel: [
            jsonMapelContoh(absensi: jsonAbsensiContoh()),
            jsonMapelContoh(
              idJadwal: 2,
              mulai: '10:40',
              selesai: '11:50',
              lokasi: null,
              idLokasi: null,
            ),
          ],
        ),
      );
      expect(info.hari, 'Senin');
      expect(info.waktuServer, DateTime(2026, 11, 23, 7, 20));
      expect(info.toleransiMenit, 15);
      expect(info.bukaAbsenMenit, 30);
      expect(info.lokasiAbsen, hasLength(3));
      expect(info.mapel, hasLength(2));
      expect(info.mapel.first.lokasi, 'Gedung SD');
      expect(info.mapel.first.absensi!.jamAbsen, '07:25');
      expect(info.mapel.first.jamTampil, '07.30 - 09.00');
      expect(info.mapel.last.absensi, isNull);
      // Jam masuk = mapel pertama, boleh pulang = mapel terakhir selesai
      expect(info.jamMasuk, '07:30');
      expect(info.jamBolehPulang, '11:50');

      final baru = info.denganAbsensi(
        1,
        AbsensiMapel.fromJson(jsonAbsensiContoh(id: 8, idJadwal: 2)),
      );
      expect(baru.mapel.last.absensi!.idAbsensi, 8);
      expect(baru.mapel.first.absensi!.idAbsensi, 7);
    });

    test('Keadaan mapel: belum dibuka, belum absen, terlewat', () {
      final mapel = MapelAbsen.fromJson(jsonMapelContoh()); // 07.30-09.00
      KeadaanMapel pada(int jam, int menit) => keadaanMapel(
        mapel,
        hari: HariRelatif.ini,
        menitSekarang: jam * 60 + menit,
        bukaAbsenMenit: 30,
      );
      expect(pada(6, 50), KeadaanMapel.belumDibuka);
      expect(pada(7, 0), KeadaanMapel.belumAbsen); // dibuka 30 menit sebelum
      expect(pada(8, 59), KeadaanMapel.belumAbsen);
      expect(pada(9, 0), KeadaanMapel.terlewat);
      expect(
        keadaanMapel(mapel, hari: HariRelatif.lalu),
        KeadaanMapel.terlewat,
      );
      expect(
        keadaanMapel(mapel, hari: HariRelatif.depan),
        KeadaanMapel.belumAbsen,
      );
    });

    test('Keadaan mapel dari status absensi', () {
      KeadaanMapel dari(Map<String, dynamic> absensi) => keadaanMapel(
        MapelAbsen.fromJson(jsonMapelContoh(absensi: absensi)),
        hari: HariRelatif.ini,
        menitSekarang: 600,
      );
      expect(dari(jsonAbsensiContoh()), KeadaanMapel.hadir);
      expect(
        dari(jsonAbsensiContoh(status: 'terlambat', menitTerlambat: 20)),
        KeadaanMapel.terlambat,
      );
      expect(
        dari(
          jsonAbsensiContoh(
            status: 'terlambat',
            menitTerlambat: 110,
            lewatJam: true,
          ),
        ),
        KeadaanMapel.lewatJam,
      );
      expect(
        dari(jsonAbsensiContoh(status: 'sakit', jamAbsen: null)),
        KeadaanMapel.sakit,
      );
      expect(
        dari(jsonAbsensiContoh(status: 'alpa', jamAbsen: null)),
        KeadaanMapel.alpa,
      );
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
      final p = PengaturanAbsen.fromJson({
        'toleransi_terlambat': 10,
        'buka_absen_menit': 45,
        'jumlah_lokasi': 3,
        'alamat_yayasan': 'Bekasi',
      });
      expect(p.jumlahLokasi, 3);
      expect(p.toJson(), {'toleransi_terlambat': 10, 'buka_absen_menit': 45});
    });

    test('RekapHarian (monitoring admin) membaca data server', () {
      final rekap = RekapHarian.fromJson({
        'tanggal': '2026-11-23',
        'hari': 'Senin',
        'waktu_server': '2026-11-23 12:30:00',
        'libur': null,
        'toleransi_menit': 15,
        'guru': [
          {
            'id_pengguna': 2,
            'nomor_induk': '12345678910',
            'nama_tampil': 'Guru Contoh, S.Pd.',
            'unit': 'SD',
            'mapel': [
              jsonMapelContoh(absensi: jsonAbsensiContoh()),
              jsonMapelContoh(idJadwal: 2, mulai: '09:30', selesai: '10:40'),
            ],
          },
        ],
      });
      expect(rekap.guru.single.namaTampil, 'Guru Contoh, S.Pd.');
      expect(rekap.guru.single.mapel, hasLength(2));
      expect(rekap.guru.single.mapel.last.absensi, isNull);
    });
  });

  group('AbsenService', () {
    test('Kirim absen sebuah mapel: id jadwal + foto + lokasi', () async {
      late http.Request dikirim;
      final service = buatAbsenPalsu((req) async {
        dikirim = req;
        return responJson(201, true, 'Absen Bahasa Indonesia berhasil.', {
          'absensi': jsonAbsensiContoh(),
        });
      });

      final hasil = await service.kirimAbsen(
        2,
        FotoAbsen(bytes: fotoPngKecil, namaFile: 'absen.jpg'),
        const PosisiAbsen(lat: -6.17527, lng: 107.03, akurasi: 12.4),
      );

      expect(dikirim.url.path, '/api/absen/kirim.php');
      expect(
        dikirim.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      final isi = latin1.decode(dikirim.bodyBytes);
      expect(isi, contains('name="id_jadwal"\r\n\r\n2'));
      expect(isi, contains('name="lat"\r\n\r\n-6.1752700'));
      expect(isi, contains('name="lng"\r\n\r\n107.0300000'));
      expect(isi, contains('name="foto"; filename="absen.jpg"'));
      expect(isi, isNot(contains('lokasi_palsu')));
      expect(hasil.pesan, 'Absen Bahasa Indonesia berhasil.');
      expect(hasil.absensi.jamAbsen, '07:25');
    });

    test('Fake GPS ikut dilaporkan ke server', () async {
      late http.Request dikirim;
      final service = buatAbsenPalsu((req) async {
        dikirim = req;
        return responJson(422, false, 'Terdeteksi aplikasi lokasi palsu.');
      });

      await expectLater(
        service.kirimAbsen(
          1,
          FotoAbsen(bytes: fotoPngKecil, namaFile: 'absen.jpg'),
          const PosisiAbsen(lat: 1, lng: 2, palsu: true),
        ),
        throwsA(isA<ApiException>().having((e) => e.kodeStatus, 'kode', 422)),
      );
      expect(latin1.decode(dikirim.bodyBytes), contains('name="lokasi_palsu"'));
    });

    test('Foto absen diambil sebagai bytes, 404 jadi ApiException', () async {
      final service = buatAbsenPalsu((req) async {
        if (req.url.queryParameters['id_absensi'] == '7') {
          return http.Response.bytes(
            fotoPngKecil,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return responJson(404, false, 'Foto absen tidak ditemukan.');
      });

      expect(await service.ambilFoto(7), fotoPngKecil);
      await expectLater(
        service.ambilFoto(8),
        throwsA(
          isA<ApiException>().having(
            (e) => e.pesan,
            'pesan',
            'Foto absen tidak ditemukan.',
          ),
        ),
      );
    });

    test('Admin: rekap harian & ubah kehadiran', () async {
      final permintaan = <http.Request>[];
      final service = buatAbsenPalsu((req) async {
        permintaan.add(req);
        if (req.url.path.endsWith('harian.php')) {
          return responJson(200, true, 'ok', {
            'tanggal': '2026-11-23',
            'hari': 'Senin',
            'waktu_server': '2026-11-23 12:30:00',
            'libur': null,
            'guru': [],
          });
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return responJson(200, true, 'ok', {
          'absensi': body['status'] == 'belum'
              ? null
              : jsonAbsensiContoh(
                  jamAbsen: null,
                  status: body['status'] as String,
                  diubahAdmin: true,
                ),
        });
      });

      await service.rekapHarian(DateTime(2026, 11, 23));
      expect(permintaan.last.url.queryParameters['tanggal'], '2026-11-23');

      final hasil = await service.ubahKehadiran(
        status: 'hadir',
        idJadwal: 5,
        tanggal: DateTime(2026, 11, 23),
        keterangan: 'Lupa absen',
      );
      expect(jsonDecode(permintaan.last.body), {
        'id_jadwal': 5,
        'tanggal': '2026-11-23',
        'status': 'hadir',
        'keterangan': 'Lupa absen',
      });
      expect(hasil!.diubahAdmin, isTrue);

      expect(
        await service.ubahKehadiran(status: 'belum', idAbsensi: 7),
        isNull,
      );
      expect(jsonDecode(permintaan.last.body), {
        'id_absensi': 7,
        'status': 'belum',
        'keterangan': '',
      });
    });
  });
}
