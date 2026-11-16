import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../utils/pesan.dart';
import '../../widgets/input_field.dart';
import '../../widgets/kotak_jam.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/tombol_utama.dart';
import 'admin_lokasi_absen_screen.dart';

/// Admin: Pengaturan Sistem bagian absensi.
///
/// - Toleransi terlambat.
/// - Jam masuk & jam pulang setiap unit (KB/TK/SD).
/// - Pintasan ke menu Lokasi Absen (titik-titik lokasi diatur di sana).
class PengaturanSistemScreen extends StatefulWidget {
  const PengaturanSistemScreen({super.key, this.absenService});

  final AbsenService? absenService;

  @override
  State<PengaturanSistemScreen> createState() => _PengaturanSistemScreenState();
}

class _PengaturanSistemScreenState extends State<PengaturanSistemScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();

  final _formKey = GlobalKey<FormState>();
  final _toleransiController = TextEditingController();

  /// Jam kerja per unit, urut KB, TK, SD.
  List<JamKerja> _jamKerja = const [];
  String? _alamat;
  int _jumlahLokasi = 0;

  bool _sedangMemuat = true;
  bool _sedangMenyimpan = false;
  bool _sudahCobaSimpan = false;
  String? _pesanGagalMuat;
  String? _pesanGagalSimpan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
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
    _toleransiController.text = '${data.toleransiTerlambat}';
    _jamKerja = data.jamKerja;
    _alamat = data.alamatYayasan;
    _jumlahLokasi = data.jumlahLokasi;
  }

  Future<void> _bukaLokasiAbsen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminLokasiAbsenScreen(absenService: _service),
      ),
    );
    // Perbarui jumlah lokasi aktif
    try {
      final data = await _service.pengaturan();
      if (mounted) setState(() => _jumlahLokasi = data.jumlahLokasi);
    } on ApiException {
      // biarkan angka lama
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
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: AppColors.isian,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: _bukaLokasiAbsen,
                leading: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.navy,
                ),
                title: Text(
                  _jumlahLokasi == 0
                      ? 'Belum ada lokasi absen'
                      : '$_jumlahLokasi lokasi absen aktif',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Atur titik lokasi setiap gedung di menu Lokasi Absen',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
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
