import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/services/auth_service.dart';
import 'package:kepegawaian_guru/services/info_service.dart';
import 'package:kepegawaian_guru/services/jadwal_service.dart';
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
