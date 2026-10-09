import '../models/info_kegiatan.dart';
import 'api_service.dart';

/// Komunikasi dengan API Info Kegiatan (`backend/api/info/`).
class InfoService {
  InfoService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Daftar info kegiatan, yang terbaru dibuat tampil paling atas.
  ///
  /// - [cari]: kata kunci pencarian judul/isi
  /// - [hanyaPenting]: hanya info yang ditandai bintang
  /// - [batas]: jumlah maksimal info (Beranda memakai 5)
  Future<List<InfoKegiatan>> daftar({
    String cari = '',
    bool hanyaPenting = false,
    int? batas,
  }) async {
    final parameter = <String, String>{
      if (cari.trim().isNotEmpty) 'cari': cari.trim(),
      if (hanyaPenting) 'penting': '1',
      if (batas != null) 'batas': '$batas',
    };
    final query = parameter.isEmpty
        ? ''
        : '?${Uri(queryParameters: parameter).query}';

    final respon = await _api.get('info/daftar.php$query');
    final data = respon['data'] as Map<String, dynamic>;
    return (data['info'] as List)
        .map((e) => InfoKegiatan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Data terbaru satu info (dipakai halaman detail).
  Future<InfoKegiatan> detail(int idInfo) async {
    final respon = await _api.get('info/detail.php?id=$idInfo');
    final data = respon['data'] as Map<String, dynamic>;
    return InfoKegiatan.fromJson(data['info'] as Map<String, dynamic>);
  }

  /// Tandai ([penting] = true) atau lepas tanda bintang sebuah info.
  Future<void> tandaiPenting(int idInfo, bool penting) async {
    await _api.post('info/tandai.php', {'id_info': idInfo, 'penting': penting});
  }
}
