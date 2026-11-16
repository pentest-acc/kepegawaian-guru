import 'dart:typed_data';

import '../models/absensi.dart';
import 'api_service.dart';
import 'perangkat_absen.dart';

/// Hasil absen masuk/pulang: data absensi terbaru + pesan dari server.
class HasilAbsen {
  const HasilAbsen({required this.absensi, required this.pesan});

  final Absensi absensi;
  final String pesan;
}

/// API absen.
/// - Guru: [hariIni], [absenMasuk], [absenPulang], [ambilFoto]
/// - Admin: [daftarLokasi], [simpanLokasi], [hapusLokasi], [pengaturan],
///   [simpanPengaturan]
class AbsenService {
  AbsenService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  // ------------------------------- Guru -------------------------------

  Future<InfoAbsenHariIni> hariIni() async {
    final respon = await _api.get('absen/hari_ini.php');
    return InfoAbsenHariIni.fromJson(respon['data'] as Map<String, dynamic>);
  }

  Future<HasilAbsen> absenMasuk(FotoAbsen foto, PosisiAbsen posisi) =>
      _kirimAbsen('absen/masuk.php', foto, posisi);

  Future<HasilAbsen> absenPulang(FotoAbsen foto, PosisiAbsen posisi) =>
      _kirimAbsen('absen/pulang.php', foto, posisi);

  Future<HasilAbsen> _kirimAbsen(
    String endpoint,
    FotoAbsen foto,
    PosisiAbsen posisi,
  ) async {
    final respon = await _api.kirimBerkas(
      endpoint,
      isian: {
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
      absensi: Absensi.fromJson(data['absensi'] as Map<String, dynamic>),
      pesan: respon['pesan'] as String,
    );
  }

  /// Foto absen ([jenis] = "masuk" atau "pulang").
  Future<Uint8List> ambilFoto(int idAbsensi, String jenis) =>
      _api.ambilBerkas('absen/foto.php?id_absensi=$idAbsensi&jenis=$jenis');

  // ------------------------------- Admin ------------------------------

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
