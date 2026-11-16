import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/perangkat_absen.dart';
import '../../utils/pesan.dart';
import '../../widgets/input_field.dart';
import '../../widgets/tombol_utama.dart';

/// Admin: form tambah / ubah satu lokasi absen.
/// Mengembalikan [LokasiAbsen] yang tersimpan saat berhasil.
class FormLokasiScreen extends StatefulWidget {
  const FormLokasiScreen({
    super.key,
    this.lokasi,
    this.absenService,
    this.perangkat,
  });

  /// Diisi jika mengubah lokasi yang sudah ada.
  final LokasiAbsen? lokasi;
  final AbsenService? absenService;
  final LokasiPerangkat? perangkat;

  @override
  State<FormLokasiScreen> createState() => _FormLokasiScreenState();

  /// "-6.1702113, 107.0251456" -> (lat, lng). Format ini sama dengan yang
  /// disalin dari Google Maps (tekan lama pada peta, lalu ketuk koordinatnya).
  static (double, double)? bacaKoordinat(String teks) {
    final bagian = teks
        .replaceAll(RegExp(r'[()°]'), ' ')
        .split(RegExp(r'[,;\s]+'))
        .where((b) => b.isNotEmpty)
        .toList();
    if (bagian.length != 2) return null;
    final lat = double.tryParse(bagian[0]);
    final lng = double.tryParse(bagian[1]);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return (lat, lng);
  }
}

class _FormLokasiScreenState extends State<FormLokasiScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();
  late final LokasiPerangkat _perangkat =
      widget.perangkat ?? const LokasiPerangkat();

  final _formKey = GlobalKey<FormState>();
  late final _namaController = TextEditingController(text: widget.lokasi?.nama);
  late final _koordinatController = TextEditingController(
    text: widget.lokasi == null
        ? null
        : '${widget.lokasi!.lat.toStringAsFixed(7)}, '
              '${widget.lokasi!.lng.toStringAsFixed(7)}',
  );
  late final _radiusController = TextEditingController(
    text: '${widget.lokasi?.radius ?? 100}',
  );
  late bool _aktif = widget.lokasi?.aktif ?? true;

  bool _mencariLokasi = false;
  bool _sedangMenyimpan = false;
  String? _pesanGagal;

  bool get _modeUbah => widget.lokasi != null;

  @override
  void initState() {
    super.initState();
    // Tombol "Lihat di Google Maps" aktif saat koordinat terisi
    _koordinatController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _koordinatController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pakaiLokasiSekarang() async {
    setState(() => _mencariLokasi = true);
    try {
      final posisi = await _perangkat.posisiSekarang();
      if (!mounted) return;
      setState(() {
        _koordinatController.text =
            '${posisi.lat.toStringAsFixed(7)}, ${posisi.lng.toStringAsFixed(7)}';
        _mencariLokasi = false;
      });
      tampilkanPesan(
        context,
        'Lokasi terbaca (akurasi ± ${posisi.akurasi.round()} m).',
      );
    } on LokasiException catch (e) {
      if (!mounted) return;
      setState(() => _mencariLokasi = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  Future<void> _lihatDiPeta() async {
    final titik = FormLokasiScreen.bacaKoordinat(_koordinatController.text);
    if (titik == null) return;
    final berhasil = await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${titik.$1},${titik.$2}',
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!berhasil && mounted) {
      tampilkanPesan(context, 'Google Maps tidak dapat dibuka.', gagal: true);
    }
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final titik = FormLokasiScreen.bacaKoordinat(_koordinatController.text)!;

    setState(() {
      _sedangMenyimpan = true;
      _pesanGagal = null;
    });
    try {
      final tersimpan = await _service.simpanLokasi(
        LokasiAbsen(
          idLokasi: widget.lokasi?.idLokasi,
          nama: _namaController.text.trim(),
          lat: titik.$1,
          lng: titik.$2,
          radius: int.parse(_radiusController.text.trim()),
          aktif: _aktif,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(tersimpan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMenyimpan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final koordinatValid =
        FormLokasiScreen.bacaKoordinat(_koordinatController.text) != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _modeUbah ? 'Ubah ${widget.lokasi!.namaLengkap}' : 'Tambah Lokasi',
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_pesanGagal != null) ...[
                Container(
                  key: const Key('pesan-gagal-lokasi'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.merah.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _pesanGagal!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.merah,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              InputField(
                label: 'Nama lokasi',
                hint: 'contoh: Gedung SD',
                controller: _namaController,
                ikon: Icons.apartment_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  final teks = v?.trim() ?? '';
                  if (teks.length < 2) return 'Nama lokasi wajib diisi.';
                  if (teks.length > 100) return 'Maksimal 100 karakter.';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const LabelIsian('Titik lokasi'),
              OutlinedButton.icon(
                onPressed: _mencariLokasi ? null : _pakaiLokasiSekarang,
                icon: _mencariLokasi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                  _mencariLokasi
                      ? 'Mendeteksi lokasi...'
                      : 'Gunakan lokasi saya sekarang',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InputField(
                label: 'Koordinat (latitude, longitude)',
                hint: 'contoh: -6.1702113, 107.0251456',
                controller: _koordinatController,
                ikon: Icons.place_outlined,
                keyboardType: TextInputType.text,
                validator: (v) =>
                    FormLokasiScreen.bacaKoordinat(v ?? '') == null
                    ? 'Isi koordinat, contoh: -6.1702113, 107.0251456'
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                  'Tips: di Google Maps, tekan lama titik gedung sampai '
                  'muncul pin merah, ketuk koordinatnya untuk menyalin, lalu '
                  'tempel di sini.',
                  style: TextStyle(fontSize: 12, color: AppColors.teksAbu),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: koordinatValid ? _lihatDiPeta : null,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lihat di Google Maps'),
                ),
              ),
              const SizedBox(height: 6),
              InputField(
                label: 'Radius absen (meter)',
                hint: '100',
                controller: _radiusController,
                ikon: Icons.radar_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final angka = int.tryParse(v?.trim() ?? '');
                  if (angka == null || angka < 20 || angka > 5000) {
                    return 'Isi angka 20 sampai 5000.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _aktif,
                onChanged: (nilai) => setState(() => _aktif = nilai),
                title: const Text(
                  'Lokasi aktif',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Matikan jika lokasi ini sementara tidak dipakai untuk absen.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              TombolUtama(
                teks: _modeUbah ? 'Simpan Perubahan' : 'Simpan Lokasi',
                ikon: Icons.save_rounded,
                sedangMemuat: _sedangMenyimpan,
                onPressed: _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
