import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../models/cuti.dart';
import 'api_service.dart';

/// Foto lampiran pengajuan (mis. foto surat dokter).
class LampiranCuti {
  const LampiranCuti({required this.bytes, required this.namaFile});

  final Uint8List bytes;
  final String namaFile;
}

/// Hasil mengirim / memproses pengajuan: data terbaru + pesan server.
class HasilCuti {
  const HasilCuti({required this.pesan, this.cuti});

  final PengajuanCuti? cuti;
  final String pesan;
}

/// API cuti / izin / sakit.
/// - Guru: [saya], [hitung], [ajukan], [batal], [ambilLampiran]
/// - Admin: [daftarAdmin], [detailAdmin], [proses], [ambilLampiran]
class CutiService {
  CutiService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  static final _formatTanggal = DateFormat('yyyy-MM-dd');

  static String _tgl(DateTime t) => _formatTanggal.format(t);

  // ------------------------------- Guru -------------------------------

  Future<DataCutiSaya> saya() async {
    final respon = await _api.get('cuti/saya.php');
    return DataCutiSaya.fromJson(respon['data'] as Map<String, dynamic>);
  }

  /// Pratinjau: jumlah hari kerja, mapel yang ditinggalkan, sisa kuota.
  /// Melempar [ApiException] jika tanggal/aturan tidak sesuai.
  Future<PratinjauCuti> hitung(
    JenisCuti jenis,
    DateTime mulai,
    DateTime selesai,
  ) async {
    final respon = await _api.get(
      'cuti/hitung.php?jenis=${jenis.kode}'
      '&tanggal_mulai=${_tgl(mulai)}&tanggal_selesai=${_tgl(selesai)}',
    );
    return PratinjauCuti.fromJson(respon['data'] as Map<String, dynamic>);
  }

  Future<HasilCuti> ajukan({
    required JenisCuti jenis,
    required DateTime mulai,
    required DateTime selesai,
    required String alasan,
    LampiranCuti? lampiran,
  }) async {
    final respon = await _api.kirimBerkas(
      'cuti/ajukan.php',
      isian: {
        'jenis': jenis.kode,
        'tanggal_mulai': _tgl(mulai),
        'tanggal_selesai': _tgl(selesai),
        'alasan': alasan,
      },
      namaField: 'lampiran',
      isiBerkas: lampiran?.bytes,
      namaBerkas: lampiran?.namaFile ?? '',
    );
    final data = respon['data'] as Map<String, dynamic>;
    return HasilCuti(
      cuti: PengajuanCuti.fromJson(data['cuti'] as Map<String, dynamic>),
      pesan: respon['pesan'] as String,
    );
  }

  /// Membatalkan pengajuan yang masih menunggu. Mengembalikan pesan server.
  Future<String> batal(int idCuti) async {
    final respon = await _api.post('cuti/batal.php', {'id_cuti': idCuti});
    return respon['pesan'] as String;
  }

  /// Foto lampiran (guru pemilik atau admin).
  Future<Uint8List> ambilLampiran(int idCuti) =>
      _api.ambilBerkas('cuti/lampiran.php?id_cuti=$idCuti');

  // ------------------------------- Admin ------------------------------

  /// [status]: menunggu, disetujui, ditolak, atau null (semua).
  Future<DaftarCutiAdmin> daftarAdmin({
    StatusCuti? status,
    String cari = '',
  }) async {
    final respon = await _api.get(
      'admin/cuti/daftar.php?status=${status?.kode ?? 'semua'}'
      '${cari.trim().isEmpty ? '' : '&cari=${Uri.encodeQueryComponent(cari.trim())}'}',
    );
    return DaftarCutiAdmin.fromJson(respon['data'] as Map<String, dynamic>);
  }

  Future<DetailCutiAdmin> detailAdmin(int idCuti) async {
    final respon = await _api.get('admin/cuti/detail.php?id_cuti=$idCuti');
    return DetailCutiAdmin.fromJson(respon['data'] as Map<String, dynamic>);
  }

  /// Menyetujui ([setujui] true) atau menolak pengajuan.
  Future<HasilCuti> proses(
    int idCuti, {
    required bool setujui,
    String catatan = '',
  }) async {
    final respon = await _api.post('admin/cuti/proses.php', {
      'id_cuti': idCuti,
      'keputusan': setujui ? 'disetujui' : 'ditolak',
      'catatan': catatan.trim(),
    });
    final data = respon['data'] as Map<String, dynamic>;
    return HasilCuti(
      cuti: PengajuanCuti.fromJson(data['cuti'] as Map<String, dynamic>),
      pesan: respon['pesan'] as String,
    );
  }
}
