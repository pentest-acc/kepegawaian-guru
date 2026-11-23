import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kepegawaian_guru/models/absensi.dart';
import 'package:kepegawaian_guru/screens/guru/kamera_absen_screen.dart';
import 'package:kepegawaian_guru/services/absen_service.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/services/auth_service.dart';
import 'package:kepegawaian_guru/services/info_service.dart';
import 'package:kepegawaian_guru/services/jadwal_service.dart';
import 'package:kepegawaian_guru/services/perangkat_absen.dart';
import 'package:kepegawaian_guru/services/session_service.dart';

/// Contoh data pengguna seperti yang dikirim backend.
const Map<String, dynamic> jsonGuruContoh = {
  'id_pengguna': 2,
  'nomor_induk': '12345678910',
  'nama_lengkap': 'Guru Contoh',
  'gelar': 'S.Pd.',
  'email': 'guru@contoh.test',
  'no_hp': '081200000002',
  'role': 'guru',
  'jabatan': 'Guru Kelas',
  'unit': 'SD',
  'jenis_kelamin': 'L',
  'tempat_lahir': null,
  'tanggal_lahir': null,
  'alamat': null,
  'foto': null,
  'notifikasi_aktif': true,
  'status': 'aktif',
};

/// Membuat response JSON dengan format backend.
http.Response responJson(
  int kode,
  bool sukses,
  String pesan, [
  Map<String, dynamic>? data,
]) {
  return http.Response(
    jsonEncode({
      'sukses': sukses,
      'pesan': pesan,
      'data': ?data, // 'data' hanya ditambahkan jika tidak null
    }),
    kode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// AuthService yang memakai server palsu (tanpa Laragon).
AuthService buatAuthPalsu(
  Future<http.Response> Function(http.Request request) server, {
  SessionService? sesi,
}) {
  final sesiDipakai = sesi ?? SessionService();
  final api = ApiService(
    client: MockClient(server),
    sesi: sesiDipakai,
    baseUrl: 'http://server-tes/api',
  );
  return AuthService(api: api, sesi: sesiDipakai);
}

/// Contoh info kegiatan seperti yang dikirim backend.
Map<String, dynamic> jsonInfoContoh({
  int id = 1,
  String judul = 'Rapat Guru Bulanan',
  String dibuat = '2026-10-06 09:00:00',
  bool penting = false,
  bool berlampiran = false,
}) => {
  'id_info': id,
  'judul': judul,
  'isi': 'Isi info $judul',
  'kategori': 'Rapat',
  'tanggal_kegiatan': '2026-10-15',
  'dibuat_pada': dibuat,
  'lampiran': berlampiran
      ? {
          'nama': 'jadwal.pdf',
          'url': 'http://server-tes/uploads/lampiran/jadwal.pdf',
        }
      : null,
  'penting': penting,
};

/// InfoService yang memakai server palsu.
InfoService buatInfoPalsu(
  Future<http.Response> Function(http.Request request) server,
) {
  final api = ApiService(
    client: MockClient(server),
    sesi: SessionService(),
    baseUrl: 'http://server-tes/api',
  );
  return InfoService(api: api);
}

/// Contoh jadwal mengajar seperti yang dikirim backend.
Map<String, dynamic> jsonJadwalContoh({
  int id = 1,
  int idPengguna = 2,
  String hari = 'Senin',
  String mulai = '07:30',
  String selesai = '09:00',
  String kelas = '3B',
  String mapel = 'Bahasa Indonesia',
  String unit = 'SD',
}) => {
  'id_jadwal': id,
  'id_pengguna': idPengguna,
  'hari': hari,
  'jam_mulai': mulai,
  'jam_selesai': selesai,
  'unit': unit,
  'kelas': kelas,
  'mata_pelajaran': mapel,
};

/// JadwalService yang memakai server palsu.
JadwalService buatJadwalPalsu(
  Future<http.Response> Function(http.Request request) server,
) {
  final api = ApiService(
    client: MockClient(server),
    sesi: SessionService(),
    baseUrl: 'http://server-tes/api',
  );
  return JadwalService(api: api);
}

/// Foto PNG 1x1 piksel untuk foto absen palsu.
final Uint8List fotoPngKecil = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Contoh absensi SATU MAPEL seperti yang dikirim backend.
Map<String, dynamic> jsonAbsensiContoh({
  int id = 7,
  int idJadwal = 1,
  String mapel = 'Bahasa Indonesia',
  String mulai = '07:30',
  String selesai = '09:00',
  String? jamAbsen = '07:25',
  String status = 'hadir',
  int menitTerlambat = 0,
  bool lewatJam = false,
  String? lokasi = 'Gedung SD',
  String? keterangan,
  bool diubahAdmin = false,
}) => {
  'id_absensi': id,
  'id_jadwal': idJadwal,
  'tanggal': '2026-11-23',
  'mata_pelajaran': mapel,
  'unit': 'SD',
  'kelas': '3B',
  'jam_mulai': mulai,
  'jam_selesai': selesai,
  'jam_absen': jamAbsen,
  'status': status,
  'menit_terlambat': menitTerlambat,
  'lewat_jam': lewatJam,
  'lokasi': jamAbsen == null ? null : lokasi,
  'jarak': jamAbsen == null ? null : 30,
  'ada_foto': jamAbsen != null,
  'keterangan': keterangan,
  'diubah_admin': diubahAdmin,
};

/// Contoh satu mapel (jadwal) hari itu beserta absensinya.
Map<String, dynamic> jsonMapelContoh({
  int idJadwal = 1,
  String mapel = 'Bahasa Indonesia',
  String kelas = '3B',
  String mulai = '07:30',
  String selesai = '09:00',
  int? idLokasi = 2,
  String? lokasi = 'Gedung SD',
  Map<String, dynamic>? absensi,
}) => {
  'id_jadwal': idJadwal,
  'mata_pelajaran': mapel,
  'unit': 'SD',
  'kelas': kelas,
  'jam_mulai': mulai,
  'jam_selesai': selesai,
  'id_lokasi': idLokasi,
  'lokasi': lokasi,
  'absensi': absensi,
};

/// 3 lokasi absen contoh (3 gedung Yayasan yang terpencar).
const List<Map<String, dynamic>> jsonLokasiContoh = [
  {
    'id_lokasi': 1,
    'nomor': 1,
    'nama': 'Gedung TK',
    'lat': -6.1702,
    'lng': 107.0251,
    'radius': 100,
    'aktif': true,
  },
  {
    'id_lokasi': 2,
    'nomor': 2,
    'nama': 'Gedung SD',
    'lat': -6.175,
    'lng': 107.03,
    'radius': 150,
    'aktif': true,
  },
  {
    'id_lokasi': 3,
    'nomor': 3,
    'nama': 'Gedung KB',
    'lat': -6.18,
    'lng': 107.02,
    'radius': 100,
    'aktif': true,
  },
];

/// Contoh data `absen/hari_ini.php` (Senin, 23 November 2026, guru SD)
/// dengan 2 mapel: 07.30-09.00 (Gedung SD) dan 09.30-10.40 (Gedung TK).
Map<String, dynamic> jsonHariIniContoh({
  String jam = '07:20:00',
  String? libur,
  List<Map<String, dynamic>>? mapel,
  bool adaLokasi = true,
}) => {
  'tanggal': '2026-11-23',
  'hari': 'Senin',
  'waktu_server': '2026-11-23 $jam',
  'libur': libur,
  'toleransi_menit': 15,
  'buka_absen_menit': 30,
  'lokasi_absen': adaLokasi ? jsonLokasiContoh : const [],
  'mapel':
      mapel ??
      [
        jsonMapelContoh(),
        jsonMapelContoh(
          idJadwal: 2,
          kelas: '3A',
          mulai: '09:30',
          selesai: '10:40',
          idLokasi: 1,
          lokasi: 'Gedung TK',
        ),
      ],
};

/// AbsenService yang memakai server palsu.
AbsenService buatAbsenPalsu(
  Future<http.Response> Function(http.Request request) server,
) {
  final api = ApiService(
    client: MockClient(server),
    sesi: SessionService(),
    baseUrl: 'http://server-tes/api',
  );
  return AbsenService(api: api);
}

/// Kamera palsu: langsung "memotret" foto kecil dan membaca lokasi dari
/// [LokasiPerangkat] yang diberikan (sama seperti kamera asli).
class KameraPalsu extends KameraAbsen {
  KameraPalsu({this.batal = false});

  final bool batal;

  /// Judul kamera terakhir yang dibuka, mis. "Foto Absen Pulang".
  String? judulTerakhir;

  @override
  Future<HasilKamera?> buka(
    BuildContext context, {
    required String judul,
    required List<LokasiAbsen> lokasiAbsen,
    required LokasiPerangkat lokasi,
  }) async {
    judulTerakhir = judul;
    if (batal) return null;
    final foto = FotoAbsen(bytes: fotoPngKecil, namaFile: 'absen.jpg');
    try {
      return HasilKamera(foto: foto, posisi: await lokasi.posisiSekarang());
    } on LokasiException catch (e) {
      return HasilKamera(foto: foto, masalahLokasi: e);
    }
  }
}

/// GPS palsu: mengembalikan posisi tertentu atau melempar [LokasiException].
class LokasiPalsu extends LokasiPerangkat {
  const LokasiPalsu({this.posisi, this.gagal});

  final PosisiAbsen? posisi;
  final String? gagal;

  @override
  Future<PosisiAbsen> posisiSekarang() async {
    if (gagal != null) throw LokasiException(gagal!);
    return posisi!;
  }
}

/// Contoh data `absen/riwayat.php` untuk satu bulan. [isi] menimpa data
/// tanggal tertentu, mis. `{3: {'mapel': [...]}}`. Hari Minggu otomatis libur.
Map<String, dynamic> jsonRiwayatContoh({
  int tahun = 2026,
  int bulan = 11,
  String hariIni = '2026-11-23',
  String jam = '10:00:00',
  String mulai = '2026-10-19',
  Map<int, Map<String, dynamic>> isi = const {},
}) {
  const namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  String duaDigit(int n) => n.toString().padLeft(2, '0');
  final jumlah = DateTime(tahun, bulan + 1, 0).day;
  return {
    'bulan': '$tahun-${duaDigit(bulan)}',
    'hari_ini': hariIni,
    'waktu_server': '$hariIni $jam',
    'mulai': mulai,
    'toleransi_menit': 15,
    'hari': [
      for (var d = 1; d <= jumlah; d++)
        {
          'tanggal': '$tahun-${duaDigit(bulan)}-${duaDigit(d)}',
          'hari': namaHari[DateTime(tahun, bulan, d).weekday - 1],
          'libur': DateTime(tahun, bulan, d).weekday == DateTime.sunday
              ? 'Hari Minggu'
              : null,
          'cuti': null,
          'mapel': const <Map<String, dynamic>>[],
          ...?isi[d],
        },
    ],
  };
}

/// 2 mapel contoh: 07.30-09.00 dan 09.30-10.40, dengan absensinya.
List<Map<String, dynamic>> duaMapelContoh({
  Map<String, dynamic>? absen1,
  Map<String, dynamic>? absen2,
}) => [
  jsonMapelContoh(absensi: absen1),
  jsonMapelContoh(
    idJadwal: 2,
    kelas: '3A',
    mulai: '09:30',
    selesai: '10:40',
    absensi: absen2,
  ),
];

/// Riwayat November 2026 (hari ini Senin 23 November, pukul 10.00):
/// - 2 Nov : tidak absen sama sekali (abu-abu)
/// - 3 Nov : 2 mapel hadir (hijau)
/// - 4 Nov : sakit, ditandai admin (merah)
/// - 5 Nov : hadir, 1 mapel terlambat (hijau + titik)
/// - 9 Nov : 1 dari 2 mapel diabsen (kuning)
/// - 10 Nov: libur Yayasan
/// - 12 Nov: cuti disetujui (merah)
/// - 23 Nov: mapel 1 hadir, mapel 2 sedang berlangsung
/// - 24 Nov: hari mendatang
Map<String, dynamic> jsonRiwayatNovember() {
  Map<String, dynamic> sakit(int id, int idJadwal) => jsonAbsensiContoh(
    id: id,
    idJadwal: idJadwal,
    jamAbsen: null,
    status: 'sakit',
    keterangan: 'Sakit, ada surat dokter',
    diubahAdmin: true,
  );
  return jsonRiwayatContoh(
    isi: {
      2: {'mapel': duaMapelContoh()},
      3: {
        'mapel': duaMapelContoh(
          absen1: jsonAbsensiContoh(id: 1),
          absen2: jsonAbsensiContoh(
            id: 2,
            idJadwal: 2,
            mulai: '09:30',
            selesai: '10:40',
            jamAbsen: '09:20',
          ),
        ),
      },
      4: {'mapel': duaMapelContoh(absen1: sakit(3, 1), absen2: sakit(4, 2))},
      5: {
        'mapel': duaMapelContoh(
          absen1: jsonAbsensiContoh(id: 5),
          absen2: jsonAbsensiContoh(
            id: 6,
            idJadwal: 2,
            mulai: '09:30',
            selesai: '10:40',
            jamAbsen: '09:52',
            status: 'terlambat',
            menitTerlambat: 22,
          ),
        ),
      },
      9: {
        'mapel': duaMapelContoh(
          absen2: jsonAbsensiContoh(
            id: 7,
            idJadwal: 2,
            mulai: '09:30',
            selesai: '10:40',
            jamAbsen: '09:25',
          ),
        ),
      },
      10: {'libur': 'Libur Yayasan'},
      12: {'cuti': 'cuti', 'mapel': duaMapelContoh()},
      23: {'mapel': duaMapelContoh(absen1: jsonAbsensiContoh(id: 8))},
      24: {'mapel': duaMapelContoh()},
    },
  );
}
