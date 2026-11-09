import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/perangkat_absen.dart';
import '../../utils/pesan.dart';
import '../../widgets/input_field.dart';
import '../../widgets/kotak_jam.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/tombol_utama.dart';

/// Admin: Pengaturan Sistem bagian absensi.
///
/// - Titik lokasi sekolah + radius absen (guru harus berada di dalamnya).
/// - Toleransi terlambat.
/// - Jam masuk & jam pulang setiap unit (KB/TK/SD).
class PengaturanSistemScreen extends StatefulWidget {
  const PengaturanSistemScreen({super.key, this.absenService, this.lokasi});

  final AbsenService? absenService;
  final LokasiPerangkat? lokasi;

  @override
  State<PengaturanSistemScreen> createState() => _PengaturanSistemScreenState();
}

class _PengaturanSistemScreenState extends State<PengaturanSistemScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();
  late final LokasiPerangkat _lokasi = widget.lokasi ?? const LokasiPerangkat();

  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _toleransiController = TextEditingController();

  /// Jam kerja per unit, urut KB, TK, SD.
  List<JamKerja> _jamKerja = const [];
  String? _alamat;

  bool _sedangMemuat = true;
  bool _mencariLokasi = false;
  bool _sedangMenyimpan = false;
  bool _sudahCobaSimpan = false;
  String? _pesanGagalMuat;
  String? _pesanGagalSimpan;

  static const _angkaDesimal = TextInputType.numberWithOptions(
    signed: true,
    decimal: true,
  );

  @override
  void initState() {
    super.initState();
    // Tombol "Lihat di Google Maps" & "Kosongkan" aktif saat lokasi terisi
    _latController.addListener(_perbaruiTampilan);
    _lngController.addListener(_perbaruiTampilan);
    _muat();
  }

  void _perbaruiTampilan() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _toleransiController.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final data = await _service.pengaturan();
      if (!mounted) return;
      setState(() {
        _isiForm(data);
        _sedangMemuat = false;
        _pesanGagalMuat = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagalMuat = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  void _isiForm(PengaturanAbsen data) {
    _latController.text = data.lokasiLat?.toStringAsFixed(7) ?? '';
    _lngController.text = data.lokasiLng?.toStringAsFixed(7) ?? '';
    _radiusController.text = '${data.radiusAbsen}';
    _toleransiController.text = '${data.toleransiTerlambat}';
    _jamKerja = data.jamKerja;
    _alamat = data.alamatYayasan;
  }

  Future<void> _pakaiLokasiSekarang() async {
    setState(() => _mencariLokasi = true);
    try {
      final posisi = await _lokasi.posisiSekarang();
      if (!mounted) return;
      setState(() {
        _latController.text = posisi.lat.toStringAsFixed(7);
        _lngController.text = posisi.lng.toStringAsFixed(7);
        _mencariLokasi = false;
      });
      tampilkanPesan(
        context,
        'Lokasi terbaca (akurasi ± ${posisi.akurasi.round()} m). '
        'Tekan Simpan Pengaturan untuk menyimpan.',
      );
    } on LokasiException catch (e) {
      if (!mounted) return;
      setState(() => _mencariLokasi = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  void _kosongkanLokasi() {
    setState(() {
      _latController.clear();
      _lngController.clear();
    });
  }

  Future<void> _lihatDiPeta() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return;
    final berhasil = await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
    if (!berhasil && mounted) {
      tampilkanPesan(context, 'Google Maps tidak dapat dibuka.', gagal: true);
    }
  }

  Future<void> _pilihJam(int indeks, {required bool masuk}) async {
    final jam = _jamKerja[indeks];
    final teks = masuk ? jam.jamMasuk : jam.jamPulang;
    final bagian = teks.split(':');
    final hasil = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(bagian[0]),
        minute: int.parse(bagian[1]),
      ),
      helpText: '${masuk ? 'Jam masuk' : 'Jam pulang'} ${jam.unit}',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hasil == null) return;
    final baru =
        '${hasil.hour.toString().padLeft(2, '0')}:'
        '${hasil.minute.toString().padLeft(2, '0')}';
    setState(() {
      _jamKerja = [
        for (var i = 0; i < _jamKerja.length; i++)
          i == indeks
              ? (masuk
                    ? _jamKerja[i].salin(jamMasuk: baru)
                    : _jamKerja[i].salin(jamPulang: baru))
              : _jamKerja[i],
      ];
    });
  }

  String? _kesalahanJam(JamKerja jam) =>
      jam.jamPulang.compareTo(jam.jamMasuk) <= 0
      ? 'Jam pulang ${jam.unit} harus setelah jam masuk.'
      : null;

  /// Jam pulang paling awal = jam tombol absen pulang muncul.
  String get _jamBukaPulang {
    if (_jamKerja.isEmpty) return '-';
    final paling = _jamKerja
        .map((j) => j.jamPulang)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    return paling.replaceAll(':', '.');
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() => _sudahCobaSimpan = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _jamKerja.any((j) => _kesalahanJam(j) != null)) return;

    setState(() {
      _sedangMenyimpan = true;
      _pesanGagalSimpan = null;
    });
    try {
      final tersimpan = await _service.simpanPengaturan(
        PengaturanAbsen(
          lokasiLat: double.tryParse(_latController.text.trim()),
          lokasiLng: double.tryParse(_lngController.text.trim()),
          radiusAbsen: int.parse(_radiusController.text.trim()),
          toleransiTerlambat: int.parse(_toleransiController.text.trim()),
          jamKerja: _jamKerja,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isiForm(tersimpan);
        _sedangMenyimpan = false;
      });
      tampilkanPesan(context, 'Pengaturan absen disimpan.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagalSimpan = e.pesan;
        _sedangMenyimpan = false;
      });
    }
  }

  // ------------------------------- Validasi -------------------------------

  String? _validasiKoordinat(String? nilai, {required bool lintang}) {
    final teks = nilai?.trim() ?? '';
    final pasangan = (lintang ? _lngController : _latController).text.trim();
    if (teks.isEmpty) {
      return pasangan.isEmpty ? null : 'Wajib diisi.';
    }
    final angka = double.tryParse(teks);
    final batas = lintang ? 90 : 180;
    if (angka == null || angka.abs() > batas) {
      return 'Angka -$batas s.d. $batas.';
    }
    return null;
  }

  static String? Function(String?) _validasiBulat(int min, int maks) =>
      (nilai) {
        final angka = int.tryParse(nilai?.trim() ?? '');
        if (angka == null || angka < min || angka > maks) {
          return 'Isi angka $min sampai $maks.';
        }
        return null;
      };

  // ------------------------------- Tampilan -------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Pengaturan Sistem'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_sedangMemuat) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }
    if (_pesanGagalMuat != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_pesanGagalMuat!, textAlign: TextAlign.center),
        ),
      );
    }

    final lokasiTerisi =
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _JudulBagian(
              ikon: Icons.location_on_rounded,
              teks: 'Lokasi Absen',
            ),
            if (_alamat != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _alamat!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.teksAbu,
                  ),
                ),
              ),
            const _KotakInfo(
              teks:
                  'Guru hanya bisa absen jika berada di dalam radius dari titik '
                  'ini. Cara termudah: berdiri di sekolah, lalu tekan "Gunakan '
                  'lokasi saya sekarang". Kosongkan jika belum ingin mengecek '
                  'lokasi.',
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InputField(
                    label: 'Latitude',
                    hint: 'Belum diatur',
                    controller: _latController,
                    keyboardType: _angkaDesimal,
                    validator: (v) => _validasiKoordinat(v, lintang: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputField(
                    label: 'Longitude',
                    hint: 'Belum diatur',
                    controller: _lngController,
                    keyboardType: _angkaDesimal,
                    validator: (v) => _validasiKoordinat(v, lintang: false),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: lokasiTerisi ? _lihatDiPeta : null,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lihat di Google Maps'),
                ),
                TextButton.icon(
                  onPressed: lokasiTerisi ? _kosongkanLokasi : null,
                  icon: const Icon(Icons.location_off_outlined, size: 18),
                  label: const Text('Kosongkan'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InputField(
              label: 'Radius absen (meter)',
              hint: '100',
              controller: _radiusController,
              ikon: Icons.radar_rounded,
              keyboardType: TextInputType.number,
              validator: _validasiBulat(20, 5000),
            ),
            const SizedBox(height: 26),
            const _JudulBagian(
              ikon: Icons.schedule_rounded,
              teks: 'Jam Kerja Guru',
            ),
            InputField(
              label: 'Toleransi terlambat (menit)',
              hint: '15',
              controller: _toleransiController,
              ikon: Icons.timer_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: _validasiBulat(0, 180),
            ),
            for (var i = 0; i < _jamKerja.length; i++) ...[
              const SizedBox(height: 16),
              Text(
                'Unit ${_jamKerja[i].unit}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teks,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: KotakJam(
                      label: 'Jam masuk',
                      jam: _keJam(_jamKerja[i].jamMasuk),
                      onTap: () => _pilihJam(i, masuk: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KotakJam(
                      label: 'Jam pulang',
                      jam: _keJam(_jamKerja[i].jamPulang),
                      onTap: () => _pilihJam(i, masuk: false),
                    ),
                  ),
                ],
              ),
              if (_sudahCobaSimpan && _kesalahanJam(_jamKerja[i]) != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    _kesalahanJam(_jamKerja[i])!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.merah,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _KotakInfo(
              teks:
                  'Tombol absen pulang muncul untuk semua guru mulai pukul '
                  '$_jamBukaPulang (jam pulang paling awal). Guru yang absen '
                  'pulang sebelum jam pulang unitnya tetap bisa, tetapi '
                  'tercatat "pulang lebih awal" di rekap admin.',
            ),
            if (_pesanGagalSimpan != null) ...[
              const SizedBox(height: 16),
              Text(
                _pesanGagalSimpan!,
                key: const Key('pesan-gagal-pengaturan'),
                style: const TextStyle(fontSize: 13, color: AppColors.merah),
              ),
            ],
            const SizedBox(height: 24),
            TombolUtama(
              teks: 'Simpan Pengaturan',
              ikon: Icons.save_rounded,
              sedangMemuat: _sedangMenyimpan,
              onPressed: _simpan,
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay _keJam(String teks) {
    final bagian = teks.split(':');
    return TimeOfDay(hour: int.parse(bagian[0]), minute: int.parse(bagian[1]));
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ikon, color: AppColors.navy, size: 22),
          const SizedBox(width: 8),
          Text(
            teks,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
            ),
          ),
        ],
      ),
    );
  }
}

class _KotakInfo extends StatelessWidget {
  const _KotakInfo({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.hijau,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
