import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/info_kegiatan.dart';
import '../../services/api_service.dart';
import '../../services/info_service.dart';
import '../../utils/buka_lampiran.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/pesan.dart';
import '../../widgets/loading_dots.dart';
import 'info_detail_screen.dart';

/// Halaman daftar Informasi Kegiatan Yayasan (sesuai desain).
///
/// - Kolom pencarian untuk mencari judul/isi info
/// - Tombol bintang "Penting" di kanan atas untuk menampilkan info yang
///   ditandai saja
/// - Bintang di setiap kartu untuk menandai info penting
/// - Tombol unduh jika info memiliki lampiran
class InfoKegiatanScreen extends StatefulWidget {
  const InfoKegiatanScreen({super.key, this.infoService});

  final InfoService? infoService;

  @override
  State<InfoKegiatanScreen> createState() => _InfoKegiatanScreenState();
}

class _InfoKegiatanScreenState extends State<InfoKegiatanScreen> {
  late final InfoService _service = widget.infoService ?? InfoService();
  final _cariController = TextEditingController();
  Timer? _jedaCari;

  bool _hanyaPenting = false;
  bool _sedangMemuat = true;
  String? _pesanGagal;
  List<InfoKegiatan> _daftar = const [];

  /// Penanda permintaan terakhir, supaya hasil pencarian lama yang datang
  /// terlambat tidak menimpa hasil yang baru.
  int _nomorPermintaan = 0;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _jedaCari?.cancel();
    _cariController.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final nomor = ++_nomorPermintaan;
    if (!_sedangMemuat) {
      setState(() {
        _sedangMemuat = true;
        _pesanGagal = null;
      });
    }

    try {
      final hasil = await _service.daftar(
        cari: _cariController.text,
        hanyaPenting: _hanyaPenting,
      );
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _daftar = hasil;
        _pesanGagal = null;
        _sedangMemuat = false;
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  /// Pencarian dijalankan 0,4 detik setelah berhenti mengetik.
  void _saatCariBerubah(String _) {
    setState(() {}); // memperbarui tombol hapus (x)
    _jedaCari?.cancel();
    _jedaCari = Timer(const Duration(milliseconds: 400), _muat);
  }

  void _hapusPencarian() {
    _cariController.clear();
    _saatCariBerubah('');
  }

  void _gantiFilterPenting() {
    setState(() => _hanyaPenting = !_hanyaPenting);
    _muat();
  }

  void _perbaruiItem(InfoKegiatan info) {
    setState(() {
      _daftar = [
        for (final i in _daftar)
          if (i.idInfo != info.idInfo)
            i
          else if (!_hanyaPenting || info.penting)
            info,
      ];
    });
  }

  Future<void> _tandai(InfoKegiatan info) async {
    final baru = info.copyWith(penting: !info.penting);
    _perbaruiItem(baru); // langsung berubah di layar supaya terasa cepat

    try {
      await _service.tandaiPenting(info.idInfo, baru.penting);
      if (!mounted) return;
      tampilkanPesan(
        context,
        baru.penting
            ? 'Ditandai sebagai info penting.'
            : 'Tanda penting dihapus.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Gagal: kembalikan seperti semula
      if (_hanyaPenting && !baru.penting) {
        _muat();
      } else {
        _perbaruiItem(info);
      }
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  void _bukaDetail(InfoKegiatan info) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InfoDetailScreen(
          info: info,
          infoService: _service,
          onPentingBerubah: _perbaruiItem,
        ),
      ),
    );
  }

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
        title: const Text('Informasi Kegiatan'),
        actions: [
          _TombolFilterPenting(
            aktif: _hanyaPenting,
            onTap: _gantiFilterPenting,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _KolomCari(
              controller: _cariController,
              onChanged: _saatCariBerubah,
              onHapus: _hapusPencarian,
            ),
          ),
          Expanded(child: _isiDaftar()),
        ],
      ),
    );
  }

  Widget _isiDaftar() {
    if (_sedangMemuat && _daftar.isEmpty) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }

    if (_pesanGagal != null && _daftar.isEmpty) {
      return _KeadaanKosong(
        ikon: Icons.cloud_off_rounded,
        judul: 'Gagal memuat info',
        keterangan: _pesanGagal!,
        tombol: 'Coba lagi',
        onTombol: _muat,
      );
    }

    final List<Widget> isi;
    if (_daftar.isEmpty) {
      isi = [
        const SizedBox(height: 60),
        _KeadaanKosong(
          ikon: _hanyaPenting
              ? Icons.star_outline_rounded
              : Icons.event_note_rounded,
          judul: _cariController.text.trim().isNotEmpty
              ? 'Info tidak ditemukan'
              : _hanyaPenting
              ? 'Belum ada info penting'
              : 'Belum ada info kegiatan',
          keterangan: _cariController.text.trim().isNotEmpty
              ? 'Coba gunakan kata kunci lain.'
              : _hanyaPenting
              ? 'Tekan ikon bintang pada info untuk menandainya sebagai penting.'
              : 'Info kegiatan dari Yayasan akan tampil di sini.',
        ),
      ];
    } else {
      isi = [
        for (final info in _daftar)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _KartuInfo(
              info: info,
              onTap: () => _bukaDetail(info),
              onTandai: () => _tandai(info),
              onUnduh: info.lampiran == null
                  ? null
                  : () => bukaLampiran(context, info.lampiran!),
            ),
          ),
      ];
    }

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: isi,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TombolFilterPenting extends StatelessWidget {
  const _TombolFilterPenting({required this.aktif, required this.onTap});

  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: aktif ? 'Tampilkan semua info' : 'Tampilkan info penting saja',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  aktif ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: aktif ? const Color(0xFFFFC83D) : Colors.white,
                  size: 26,
                ),
                Text(
                  'Penting',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KolomCari extends StatelessWidget {
  const _KolomCari({
    required this.controller,
    required this.onChanged,
    required this.onHapus,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final bulat = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.teks),
      decoration: InputDecoration(
        hintText: 'Cari Informasi Kegiatan...',
        hintStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.teks,
        ),
        filled: true,
        fillColor: const Color(0xFFDCDEE2),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teks),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close_rounded, color: AppColors.teks),
                onPressed: onHapus,
              ),
        border: bulat,
        enabledBorder: bulat,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.biru, width: 1.5),
        ),
      ),
    );
  }
}

class _KartuInfo extends StatelessWidget {
  const _KartuInfo({
    required this.info,
    required this.onTap,
    required this.onTandai,
    required this.onUnduh,
  });

  final InfoKegiatan info;
  final VoidCallback onTap;
  final VoidCallback onTandai;
  final VoidCallback? onUnduh;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF63B3ED), Color(0xFF4096DB)],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: info.penting
                      ? 'Hapus tanda penting'
                      : 'Tandai sebagai penting',
                  onPressed: onTandai,
                  icon: Icon(
                    info.penting
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: info.penting
                        ? const Color(0xFFFFC83D)
                        : AppColors.navy,
                    size: 30,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FormatTanggal.hariAngka(info.dibuatPada),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.judul,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onUnduh != null)
                  IconButton(
                    tooltip: 'Unduh lampiran',
                    onPressed: onUnduh,
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.navy,
                      size: 28,
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeadaanKosong extends StatelessWidget {
  const _KeadaanKosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.tombol,
    this.onTombol,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final String? tombol;
  final VoidCallback? onTombol;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 64, color: AppColors.biru),
            const SizedBox(height: 12),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.teks,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.teksAbu),
            ),
            if (tombol != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
                onPressed: onTombol,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tombol!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
