import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../utils/pesan.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/tombol_utama.dart';
import 'admin_lokasi_absen_screen.dart';

/// Admin: Pengaturan Sistem bagian absensi.
///
/// Jam absen setiap guru mengikuti JADWAL MENGAJARNYA (per mapel), jadwal
/// diatur di menu Kelola Jadwal Mengajar. Di sini admin mengatur:
/// - toleransi terlambat (menit setelah jam mulai mapel),
/// - absen dibuka sekian menit sebelum jam mulai mapel,
/// - pintasan ke menu Lokasi Absen.
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
  final _bukaController = TextEditingController();
  String? _alamat;
  int _jumlahLokasi = 0;

  bool _sedangMemuat = true;
  bool _sedangMenyimpan = false;
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
    _bukaController.dispose();
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
    _bukaController.text = '${data.bukaAbsenMenit}';
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

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sedangMenyimpan = true;
      _pesanGagalSimpan = null;
    });
    try {
      final tersimpan = await _service.simpanPengaturan(
        PengaturanAbsen(
          toleransiTerlambat: int.parse(_toleransiController.text.trim()),
          bukaAbsenMenit: int.parse(_bukaController.text.trim()),
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
              teks: 'Aturan Absen',
            ),
            const _KotakInfo(
              teks:
                  'Jam absen setiap guru mengikuti jadwal mengajarnya: '
                  'guru absen di setiap mata pelajaran. Jam masuk = mapel '
                  'pertama, boleh pulang setelah mapel terakhir selesai. '
                  'Jadwal diatur di menu Kelola Jadwal Mengajar.',
            ),
            const SizedBox(height: 14),
            InputField(
              label: 'Absen dibuka sebelum mapel (menit)',
              hint: '30',
              controller: _bukaController,
              ikon: Icons.lock_open_rounded,
              keyboardType: TextInputType.number,
              validator: _validasiBulat(0, 180),
            ),
            const SizedBox(height: 16),
            InputField(
              label: 'Toleransi terlambat (menit)',
              hint: '15',
              controller: _toleransiController,
              ikon: Icons.timer_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: _validasiBulat(0, 180),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lewat dari toleransi tetap bisa absen, tetapi tercatat '
              'terlambat dan diberi tanda di Monitoring Absensi.',
              style: TextStyle(fontSize: 12, color: AppColors.teksAbu),
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
