import 'package:flutter/foundation.dart';

/// Pengaturan alamat backend API (folder `backend/api` di XAMPP).
///
/// Cara aplikasi menentukan alamat server:
/// - Dijalankan di Chrome (web)  -> memakai alamat yang sama dengan halaman
///   web, biasanya `localhost`.
/// - Dijalankan di HP Android     -> memakai [ipLaptop]. HP dan laptop harus
///   tersambung ke Wi-Fi yang SAMA.
/// - Emulator Android            -> ganti [ipLaptop] menjadi `10.0.2.2`.
class ApiConfig {
  ApiConfig._();

  /// GANTI dengan alamat IPv4 laptop kamu.
  /// Cara melihatnya: buka CMD lalu ketik `ipconfig`, cari "IPv4 Address"
  /// pada bagian Wi-Fi (contoh: 192.168.1.7).
  static const String ipLaptop = '192.168.1.10';

  /// Nama folder proyek di dalam `C:\xampp\htdocs`.
  static const String folderProyek = 'kepegawaian-guru';

  /// Alamat API bisa juga ditentukan langsung saat menjalankan aplikasi:
  /// `flutter run --dart-define=API_URL=http://192.168.1.7/kepegawaian-guru/backend/api`
  static const String _apiUrlDariPerintah = String.fromEnvironment('API_URL');

  /// Batas waktu menunggu jawaban server.
  static const Duration batasWaktu = Duration(seconds: 15);

  static String get baseUrl {
    if (_apiUrlDariPerintah.isNotEmpty) return _apiUrlDariPerintah;

    final host = kIsWeb ? Uri.base.host : ipLaptop;
    return 'http://$host/$folderProyek/backend/api';
  }
}
