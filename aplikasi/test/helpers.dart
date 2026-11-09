import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

/// Contoh absensi seperti yang dikirim backend.
Map<String, dynamic> jsonAbsensiContoh({
  String? masuk = '06:33',
  String? pulang,
  String status = 'hadir',
  int menitTerlambat = 0,
  int menitPulangAwal = 0,
}) => {
  'id_absensi': 7,
  'tanggal': '2026-11-10',
  'jam_masuk': masuk,
  'jam_pulang': pulang,
  'status': status,
  'menit_terlambat': menitTerlambat,
  'menit_pulang_awal': menitPulangAwal,
  'jarak_masuk': masuk == null ? null : 24,
  'jarak_pulang': pulang == null ? null : 24,
  'ada_foto_masuk': masuk != null,
  'ada_foto_pulang': pulang != null,
  'keterangan': null,
};

/// Contoh data `absen/hari_ini.php` (Selasa, 10 November 2026, guru SD).
Map<String, dynamic> jsonHariIniContoh({
  String jam = '06:33:00',
  String? libur,
  Map<String, dynamic>? absensi,
  bool adaLokasi = true,
}) => {
  'tanggal': '2026-11-10',
  'hari': 'Selasa',
  'waktu_server': '2026-11-10 $jam',
  'libur': libur,
  'jam_kerja': {
    'unit': 'SD',
    'jam_masuk': '07:00',
    'jam_pulang': '14:00',
    'toleransi_menit': 15,
  },
  'absen_masuk_mulai': '05:00',
  'absen_pulang_mulai': '13:00',
  'lokasi_sekolah': adaLokasi
      ? {'lat': -6.1702, 'lng': 107.0251, 'radius': 100}
      : null,
  'absensi': absensi,
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

/// Kamera palsu: langsung mengembalikan foto kecil (atau null = dibatalkan).
class KameraPalsu extends KameraAbsen {
  const KameraPalsu({this.batal = false});

  final bool batal;

  @override
  Future<FotoAbsen?> ambilSelfie() async =>
      batal ? null : FotoAbsen(bytes: fotoPngKecil, namaFile: 'selfie.png');
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
