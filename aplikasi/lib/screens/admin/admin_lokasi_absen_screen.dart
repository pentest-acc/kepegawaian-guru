import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/perangkat_absen.dart';
import '../../utils/pesan.dart';
import '../../widgets/loading_dots.dart';
import 'form_lokasi_screen.dart';

/// Admin: daftar lokasi absen (mis. 3 gedung Yayasan yang terpencar).
///
/// Guru boleh absen jika berada di dalam radius SALAH SATU lokasi yang aktif,
/// dan di aplikasinya terlihat lokasi mana yang paling dekat.
class AdminLokasiAbsenScreen extends StatefulWidget {
  const AdminLokasiAbsenScreen({super.key, this.absenService, this.perangkat});

  final AbsenService? absenService;
  final LokasiPerangkat? perangkat;

  @override
  State<AdminLokasiAbsenScreen> createState() => _AdminLokasiAbsenScreenState();
}

class _AdminLokasiAbsenScreenState extends State<AdminLokasiAbsenScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();

  List<LokasiAbsen> _daftar = const [];
  bool _sedangMemuat = true;
  String? _pesanGagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final hasil = await _service.daftarLokasi();
      if (!mounted) return;
      setState(() {
        _daftar = hasil;
        _sedangMemuat = false;
        _pesanGagal = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  Future<void> _bukaForm([LokasiAbsen? lokasi]) async {
    final tersimpan = await Navigator.of(context).push<LokasiAbsen>(
      MaterialPageRoute(
        builder: (_) => FormLokasiScreen(
          lokasi: lokasi,
          absenService: _service,
          perangkat: widget.perangkat,
        ),
      ),
    );
    if (tersimpan != null && mounted) {
      tampilkanPesan(
        context,
        lokasi == null
            ? '${tersimpan.nama} ditambahkan sebagai Lokasi ${tersimpan.nomor}.'
            : '${tersimpan.nama} disimpan.',
      );
      _muat();
    }
  }

  Future<void> _hapus(LokasiAbsen lokasi) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${lokasi.nama}?'),
        content: const Text(
          'Guru tidak bisa lagi absen di lokasi ini. Riwayat absen lama tetap '
          'tersimpan. Jika hanya ditutup sementara, cukup nonaktifkan lokasinya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.merah,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 42),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    try {
      await _service.hapusLokasi(lokasi.idLokasi!);
      if (!mounted) return;
      tampilkanPesan(context, '${lokasi.nama} dihapus.');
      _muat();
    } on ApiException catch (e) {
      if (!mounted) return;
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  Future<void> _lihatDiPeta(LokasiAbsen lokasi) async {
    final berhasil = await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${lokasi.lat},${lokasi.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!berhasil && mounted) {
      tampilkanPesan(context, 'Google Maps tidak dapat dibuka.', gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Lokasi Absen'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(),
        backgroundColor: AppColors.biru,
        foregroundColor: AppColors.navy,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Tambah Lokasi'),
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
    if (_pesanGagal != null) {
      return Center(child: Text(_pesanGagal!, textAlign: TextAlign.center));
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.hijau,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Guru bisa absen jika berada di dalam radius SALAH SATU '
                    'lokasi yang aktif. Saat guru mengambil foto absen, '
                    'aplikasinya menampilkan lokasi mana yang paling dekat.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_daftar.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 48,
                    color: AppColors.teksAbu,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Belum ada lokasi absen.\nSelama kosong, jarak guru '
                    'tidak dicek saat absen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.teksAbu),
                  ),
                ],
              ),
            ),
          for (final lokasi in _daftar)
            _KartuLokasi(
              lokasi: lokasi,
              onUbah: () => _bukaForm(lokasi),
              onHapus: () => _hapus(lokasi),
              onPeta: () => _lihatDiPeta(lokasi),
            ),
        ],
      ),
    );
  }
}

class _KartuLokasi extends StatelessWidget {
  const _KartuLokasi({
    required this.lokasi,
    required this.onUbah,
    required this.onHapus,
    required this.onPeta,
  });

  final LokasiAbsen lokasi;
  final VoidCallback onUbah;
  final VoidCallback onHapus;
  final VoidCallback onPeta;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onUbah,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lokasi.aktif ? AppColors.navy : AppColors.garis,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${lokasi.nomor}',
                  style: TextStyle(
                    color: lokasi.aktif ? Colors.white : AppColors.teksAbu,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lokasi.nama,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${lokasi.lat.toStringAsFixed(6)}, '
                      '${lokasi.lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.teksAbu,
                      ),
                    ),
                    Text(
                      'Radius ${lokasi.radius} m'
                      '${lokasi.aktif ? '' : '  •  NONAKTIF'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lokasi.aktif ? AppColors.hijau : AppColors.merah,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Lihat di Google Maps',
                icon: const Icon(Icons.map_outlined, color: Color(0xFF2B7BC4)),
                onPressed: onPeta,
              ),
              IconButton(
                tooltip: 'Hapus lokasi',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.merah,
                ),
                onPressed: onHapus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
