import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  /// Kirim isian + satu file (multipart/form-data), mis. foto absen.
  Future<Map<String, dynamic>> kirimBerkas(
    String endpoint, {
    required Map<String, String> isian,
    required String namaField,
    required List<int> isiBerkas,
    required String namaBerkas,
  }) async {
    final permintaan = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/$endpoint'),
    );
    permintaan.headers.addAll(await _headerDasar());
    permintaan.fields.addAll(isian);
    permintaan.files.add(
      http.MultipartFile.fromBytes(namaField, isiBerkas, filename: namaBerkas),
    );

    // Unggah foto butuh waktu lebih lama di jaringan yang lambat
    final respon = await _tunggu(
      _client.send(permintaan).then(http.Response.fromStream),
      batasWaktu: ApiConfig.batasWaktu * 3,
    );
    return _olahRespon(respon);
  }

  /// Ambil isi file (mis. foto absen) dari endpoint yang butuh login.
  Future<Uint8List> ambilBerkas(String endpoint) async {
    final respon = await _tunggu(
      _client.get(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: await _headerDasar(),
      ),
    );
    if (respon.statusCode >= 400) {
      _olahRespon(respon); // melempar ApiException berisi pesan server
    }
    return respon.bodyBytes;
  }

  Future<Map<String, dynamic>> _kirim(
    String method,
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final headers = {
      ...await _headerDasar(),
      if (method == 'POST') 'Content-Type': 'application/json',
    };

    final respon = await _tunggu(
      method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {})),
    );
    return _olahRespon(respon);
  }

  Future<Map<String, String>> _headerDasar() async {
    final token = await _sesi.ambilToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Tunggu jawaban server dan ubah masalah koneksi menjadi [ApiException].
  Future<http.Response> _tunggu(
    Future<http.Response> permintaan, {
    Duration? batasWaktu,
  }) async {
    try {
      return await permintaan.timeout(batasWaktu ?? ApiConfig.batasWaktu);
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
