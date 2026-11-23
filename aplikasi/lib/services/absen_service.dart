import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../models/absensi.dart';
import 'api_service.dart';
import 'perangkat_absen.dart';

/// Hasil absen sebuah mapel: data absensi terbaru + pesan dari server.
class HasilAbsen {
  const HasilAbsen({required this.absensi, required this.pesan});

  final AbsensiMapel absensi;
  final String pesan;
}

/// API absen (per mata pelajaran).
/// - Guru: [hariIni], [kirimAbsen], [ambilFoto]
/// - Admin: [rekapHarian], [ubahKehadiran], [daftarLokasi], [simpanLokasi],
///   [hapusLokasi], [pengaturan], [simpanPengaturan]
class AbsenService {
  AbsenService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  static final _formatTanggal = DateFormat('yyyy-MM-dd');

  // ------------------------------- Guru -------------------------------

  Future<InfoAbsenHariIni> hariIni() async {
    final respon = await _api.get('absen/hari_ini.php');
    return InfoAbsenHariIni.fromJson(respon['data'] as Map<String, dynamic>);
  }

  /// Absen untuk satu mapel (jadwal) hari ini.
  Future<HasilAbsen> kirimAbsen(
    int idJadwal,
    FotoAbsen foto,
    PosisiAbsen posisi,
  ) async {
    final respon = await _api.kirimBerkas(
      'absen/kirim.php',
      isian: {
        'id_jadwal': '$idJadwal',
        'lat': posisi.lat.toStringAsFixed(7),
        'lng': posisi.lng.toStringAsFixed(7),
        'akurasi': posisi.akurasi.round().toString(),
        if (posisi.palsu) 'lokasi_palsu': '1',
      },
      namaField: 'foto',
      isiBerkas: foto.bytes,
      namaBerkas: foto.namaFile,
    );
    final data = respon['data'] as Map<String, dynamic>;
    return HasilAbsen(
      absensi: AbsensiMapel.fromJson(data['absensi'] as Map<String, dynamic>),
      pesan: respon['pesan'] as String,
    );
  }

  /// Foto absen sebuah mapel (guru pemilik atau admin).
  Future<Uint8List> ambilFoto(int idAbsensi) =>
      _api.ambilBerkas('absen/foto.php?id_absensi=$idAbsensi');

  // ------------------------------- Admin ------------------------------

  /// Monitoring absensi semua guru pada [tanggal].
  Future<RekapHarian> rekapHarian(DateTime tanggal) async {
    final respon = await _api.get(
      'admin/absensi/harian.php?tanggal=${_formatTanggal.format(tanggal)}',
    );
    return RekapHarian.fromJson(respon['data'] as Map<String, dynamic>);
  }

  /// Admin menandai / mengubah kehadiran satu mapel.
  /// [status] = hadir, terlambat, izin, sakit, cuti, alpa, atau "belum"
  /// (menghapus tanda admin). Mengembalikan null jika tanda dihapus.
  Future<AbsensiMapel?> ubahKehadiran({
    required String status,
    int? idAbsensi,
    int? idJadwal,
    DateTime? tanggal,
    String keterangan = '',
  }) async {
    final respon = await _api.post('admin/absensi/ubah.php', {
      'id_absensi': ?idAbsensi,
      'id_jadwal': ?idJadwal,
      if (tanggal != null) 'tanggal': _formatTanggal.format(tanggal),
      'status': status,
      'keterangan': keterangan,
    });
    final data = respon['data'] as Map<String, dynamic>?;
    final absensi = data?['absensi'];
    return absensi == null
        ? null
        : AbsensiMapel.fromJson(absensi as Map<String, dynamic>);
  }

  Future<List<LokasiAbsen>> daftarLokasi() async {
    final respon = await _api.get('admin/lokasi/daftar.php');
    final data = respon['data'] as Map<String, dynamic>;
    return (data['lokasi'] as List)
        .map((e) => LokasiAbsen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tambah (jika [lokasi].idLokasi null) atau ubah lokasi absen.
  Future<LokasiAbsen> simpanLokasi(LokasiAbsen lokasi) async {
    final respon = await _api.post('admin/lokasi/simpan.php', lokasi.toJson());
    final data = respon['data'] as Map<String, dynamic>;
    return LokasiAbsen.fromJson(data['lokasi'] as Map<String, dynamic>);
  }

  Future<void> hapusLokasi(int idLokasi) async {
    await _api.post('admin/lokasi/hapus.php', {'id_lokasi': idLokasi});
  }

  Future<PengaturanAbsen> pengaturan() async {
    final respon = await _api.get('admin/pengaturan/absen.php');
    return PengaturanAbsen.fromJson(respon['data'] as Map<String, dynamic>);
  }

  Future<PengaturanAbsen> simpanPengaturan(PengaturanAbsen pengaturan) async {
    final respon = await _api.post(
      'admin/pengaturan/simpan_absen.php',
      pengaturan.toJson(),
    );
    return PengaturanAbsen.fromJson(respon['data'] as Map<String, dynamic>);
  }
}
