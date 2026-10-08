import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kepegawaian_guru/services/api_service.dart';
import 'package:kepegawaian_guru/services/auth_service.dart';
import 'package:kepegawaian_guru/services/session_service.dart';

/// Contoh data pengguna seperti yang dikirim backend.
const Map<String, dynamic> jsonGuruContoh = {
  'id_pengguna': 2,
  'nomor_induk': '12345678910',
  'nama_lengkap': 'Guru Contoh, S.Pd.',
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
