import 'package:flutter/foundation.dart';

import '../models/pengguna.dart';
import 'api_service.dart';
import 'session_service.dart';

/// Semua proses autentikasi: login, register, cek sesi, dan logout.
class AuthService {
  AuthService({ApiService? api, SessionService? sesi})
    : this._(sesi ?? SessionService(), api);

  AuthService._(SessionService sesi, ApiService? api)
    : _sesi = sesi,
      _api = api ?? ApiService(sesi: sesi);

  final SessionService _sesi;
  final ApiService _api;

  /// Login memakai email ATAU nomor induk yayasan.
  /// Jika berhasil, token & data pengguna langsung disimpan di perangkat.
  Future<Pengguna> login(String identitas, String password) async {
    final respon = await _api.post('auth/login.php', {
      'identitas': identitas.trim(),
      'password': password,
      'perangkat': _namaPerangkat(),
    });

    final data = respon['data'] as Map<String, dynamic>;
    final pengguna = Pengguna.fromJson(
      data['pengguna'] as Map<String, dynamic>,
    );
    await _sesi.simpan(data['token'] as String, pengguna);
    return pengguna;
  }

  /// Daftar akun guru baru. Mengembalikan pesan sukses dari server.
  Future<String> register({
    required String namaLengkap,
    required String gelar,
    required String nomorInduk,
    required String email,
    required String noHp,
    required String unit,
    required String jenisKelamin,
    required String password,
    required String konfirmasiPassword,
  }) async {
    final respon = await _api.post('auth/register.php', {
      'nama_lengkap': namaLengkap.trim(),
      'gelar': gelar,
      'nomor_induk': nomorInduk.trim(),
      'email': email.trim(),
      'no_hp': noHp.trim(),
      'unit': unit,
      'jenis_kelamin': jenisKelamin,
      'password': password,
      'konfirmasi_password': konfirmasiPassword,
    });
    return respon['pesan'].toString();
  }

  /// Dipanggil saat aplikasi dibuka (splash screen).
  ///
  /// - Belum pernah login / sesi berakhir -> `null` (ke halaman login)
  /// - Sesi valid -> data pengguna terbaru dari server
  /// - Server tidak bisa dihubungi -> data pengguna yang tersimpan di HP
  Future<Pengguna?> cekSesi() async {
    final token = await _sesi.ambilToken();
    if (token == null) return null;

    try {
      final respon = await _api.get('auth/profil.php');
      final data = respon['data'] as Map<String, dynamic>;
      final pengguna = Pengguna.fromJson(
        data['pengguna'] as Map<String, dynamic>,
      );
      await _sesi.perbaruiPengguna(pengguna);
      return pengguna;
    } on ApiException catch (e) {
      if (e.tidakAdaKoneksi) return _sesi.ambilPengguna();
      if (e.sesiBerakhir || e.aksesDitolak) await _sesi.hapus();
      return null;
    }
  }

  /// Keluar dari aplikasi. Data sesi di HP tetap dihapus walaupun
  /// server sedang tidak bisa dihubungi.
  Future<void> logout() async {
    try {
      await _api.post('auth/logout.php');
    } on ApiException {
      // Abaikan: yang penting sesi di perangkat ini terhapus.
    } finally {
      await _sesi.hapus();
    }
  }

  String _namaPerangkat() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      default:
        return defaultTargetPlatform.name;
    }
  }
}
