import 'package:image_picker/image_picker.dart';

import 'cuti_service.dart';

/// Mengambil foto lampiran (mis. surat dokter) dari kamera atau galeri.
/// Dibuat sebagai kelas terpisah agar bisa diganti saat pengujian.
abstract class PemilihFoto {
  const PemilihFoto();

  /// null jika pengguna membatalkan.
  Future<LampiranCuti?> ambil({required bool dariKamera});
}

class PemilihFotoPerangkat extends PemilihFoto {
  PemilihFotoPerangkat({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LampiranCuti?> ambil({required bool dariKamera}) async {
    final file = await _picker.pickImage(
      source: dariKamera ? ImageSource.camera : ImageSource.gallery,
      // Diperkecil agar cepat diunggah tetapi tulisan surat masih terbaca
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Di browser, foto yang diperkecil diberi awalan "scaled_"
    final nama = file.name.contains('.')
        ? file.name.replaceFirst(RegExp(r'^scaled_'), '')
        : 'lampiran.jpg';
    return LampiranCuti(bytes: bytes, namaFile: nama);
  }
}
