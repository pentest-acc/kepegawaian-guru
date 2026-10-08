import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

/// Kesalahan yang terjadi saat berkomunikasi dengan backend API.
class ApiException implements Exception {
  ApiException(this.pesan, {this.kodeStatus, this.kesalahan = const {}});

  /// Pesan yang siap ditampilkan ke pengguna.
  final String pesan;

  /// Kode HTTP dari server. `null` berarti server tidak bisa dihubungi.
  final int? kodeStatus;

  /// Pesan kesalahan per kolom isian (dari validasi server).
  final Map<String, String> kesalahan;

  bool get tidakAdaKoneksi => kodeStatus == null;
  bool get sesiBerakhir => kodeStatus == 401;
  bool get aksesDitolak => kodeStatus == 403;

  @override
  String toString() => pesan;
}

/// Pembungkus paket `http` untuk memanggil backend API.
///
/// Semua response dari backend berbentuk:
/// `{ "sukses": true/false, "pesan": "...", "data": {...} }`
class ApiService {
  ApiService({http.Client? client, SessionService? sesi, String? baseUrl})
    : _client = client ?? http.Client(),
      _sesi = sesi ?? SessionService(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final SessionService _sesi;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(String endpoint) => _kirim('GET', endpoint);

  Future<Map<String, dynamic>> post(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) => _kirim('POST', endpoint, body);

  Future<Map<String, dynamic>> _kirim(
    String method,
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final token = await _sesi.ambilToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (method == 'POST') 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final http.Response respon;
    try {
      final permintaan = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      respon = await permintaan.timeout(ApiConfig.batasWaktu);
    } on TimeoutException {
      throw ApiException(
        'Server terlalu lama merespons. Periksa koneksi lalu coba lagi.',
      );
    } on http.ClientException {
      throw ApiException(
        'Tidak dapat terhubung ke server. Pastikan Laragon (Apache & MySQL) '
        'sudah menyala dan alamat API sudah benar.',
      );
    }

    return _olahRespon(respon);
  }

  Map<String, dynamic> _olahRespon(http.Response respon) {
    Map<String, dynamic>? json;
    try {
      final hasil = jsonDecode(utf8.decode(respon.bodyBytes));
      if (hasil is Map<String, dynamic>) json = hasil;
    } on FormatException {
      json = null;
    }

    if (json == null) {
      throw ApiException(
        'Jawaban server tidak dikenali (kode ${respon.statusCode}). '
        'Periksa kembali alamat API.',
        kodeStatus: respon.statusCode,
      );
    }

    if (json['sukses'] != true || respon.statusCode >= 400) {
      throw ApiException(
        json['pesan']?.toString() ?? 'Terjadi kesalahan. Silakan coba lagi.',
        kodeStatus: respon.statusCode,
        kesalahan: _ambilKesalahan(json['data']),
      );
    }

    return json;
  }

  Map<String, String> _ambilKesalahan(Object? data) {
    if (data is Map && data['kesalahan'] is Map) {
      return (data['kesalahan'] as Map).map(
        (kunci, nilai) => MapEntry(kunci.toString(), nilai.toString()),
      );
    }
    return const {};
  }
}
