import 'package:intl/intl.dart';

import '../models/jadwal_mengajar.dart';
import 'api_service.dart';

/// Hasil jadwal untuk satu rentang tanggal (biasanya satu minggu).
class JadwalMingguan {
  const JadwalMingguan({required this.jadwal, required this.libur});

  /// Jadwal mingguan guru (berlaku setiap minggu).
  final List<JadwalMengajar> jadwal;

  /// Hari libur di rentang tanggal yang diminta.
  final List<HariLibur> libur;
}

/// API jadwal mengajar.
/// - Guru: [jadwalSaya]
/// - Admin: [daftarGuru], [daftarJadwalGuru], [simpan], [hapus]
class JadwalService {
  JadwalService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  static final _formatTanggal = DateFormat('yyyy-MM-dd');

  // ------------------------------- Guru -------------------------------

  Future<JadwalMingguan> jadwalSaya({
    required DateTime dari,
    required DateTime sampai,
  }) async {
    final respon = await _api.get(
      'jadwal/saya.php?dari=${_formatTanggal.format(dari)}'
      '&sampai=${_formatTanggal.format(sampai)}',
    );
    final data = respon['data'] as Map<String, dynamic>;
    return JadwalMingguan(
      jadwal: (data['jadwal'] as List)
          .map((e) => JadwalMengajar.fromJson(e as Map<String, dynamic>))
          .toList(),
      libur: (data['libur'] as List)
          .map((e) => HariLibur.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ------------------------------- Admin ------------------------------

  Future<List<GuruRingkas>> daftarGuru({String cari = ''}) async {
    final query = cari.trim().isEmpty
        ? ''
        : '?${Uri(queryParameters: {'cari': cari.trim()}).query}';
    final respon = await _api.get('admin/guru.php$query');
    final data = respon['data'] as Map<String, dynamic>;
    return (data['guru'] as List)
        .map((e) => GuruRingkas.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JadwalMengajar>> daftarJadwalGuru(int idPengguna) async {
    final respon = await _api.get(
      'admin/jadwal/daftar.php?id_pengguna=$idPengguna',
    );
    final data = respon['data'] as Map<String, dynamic>;
    return (data['jadwal'] as List)
        .map((e) => JadwalMengajar.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tambah (jika [jadwal].idJadwal null) atau ubah jadwal.
  /// Melempar [ApiException] kode 409 jika jadwal bentrok.
  Future<JadwalMengajar> simpan(JadwalMengajar jadwal) async {
    final respon = await _api.post('admin/jadwal/simpan.php', jadwal.toJson());
    final data = respon['data'] as Map<String, dynamic>;
    return JadwalMengajar.fromJson(data['jadwal'] as Map<String, dynamic>);
  }

  Future<void> hapus(int idJadwal) async {
    await _api.post('admin/jadwal/hapus.php', {'id_jadwal': idJadwal});
  }
}
