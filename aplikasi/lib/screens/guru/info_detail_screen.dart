import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/info_kegiatan.dart';
import '../../services/api_service.dart';
import '../../services/info_service.dart';
import '../../utils/buka_lampiran.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/pesan.dart';
import '../../widgets/chip_kategori.dart';

/// Halaman detail satu info kegiatan.
///
/// Data awal langsung ditampilkan dari [info], lalu diperbarui dari server
/// di latar belakang (misalnya jika admin baru saja mengubah isinya).
class InfoDetailScreen extends StatefulWidget {
  const InfoDetailScreen({
    super.key,
    required this.info,
    this.infoService,
    this.onPentingBerubah,
  });

  final InfoKegiatan info;
  final InfoService? infoService;

  /// Dipanggil saat bintang diubah, supaya halaman sebelumnya ikut berubah.
  final ValueChanged<InfoKegiatan>? onPentingBerubah;

  @override
  State<InfoDetailScreen> createState() => _InfoDetailScreenState();
}

class _InfoDetailScreenState extends State<InfoDetailScreen> {
  late final InfoService _service = widget.infoService ?? InfoService();
  late InfoKegiatan _info = widget.info;
  bool _sudahDihapus = false;

  @override
  void initState() {
    super.initState();
    _segarkan();
  }

  Future<void> _segarkan() async {
    try {
      final terbaru = await _service.detail(_info.idInfo);
      if (!mounted) return;
      setState(() => _info = terbaru);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.kodeStatus == 404) setState(() => _sudahDihapus = true);
      // Kesalahan lain (mis. offline) diabaikan: data awal tetap tampil.
    }
  }

  Future<void> _tandai() async {
    final lama = _info;
    final baru = _info.copyWith(penting: !_info.penting);
    setState(() => _info = baru);
    widget.onPentingBerubah?.call(baru);

    try {
      await _service.tandaiPenting(baru.idInfo, baru.penting);
      if (!mounted) return;
      tampilkanPesan(
        context,
        baru.penting
            ? 'Ditandai sebagai info penting.'
            : 'Tanda penting dihapus.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _info = lama);
      widget.onPentingBerubah?.call(lama);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
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
        title: const Text('Detail Info Kegiatan'),
        actions: [
          if (!_sudahDihapus)
            IconButton(
              tooltip: _info.penting
                  ? 'Hapus tanda penting'
                  : 'Tandai sebagai penting',
              onPressed: _tandai,
              icon: Icon(
                _info.penting ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _info.penting ? const Color(0xFFFFC83D) : Colors.white,
                size: 28,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (_sudahDihapus)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.merah.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Info ini sudah dihapus atau tidak lagi diterbitkan oleh admin.',
                style: TextStyle(fontSize: 13, color: AppColors.merah),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: ChipKategori(_info.kategori),
          ),
          const SizedBox(height: 12),
          Text(
            _info.judul,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _BarisKeterangan(
            ikon: Icons.event_rounded,
            label: 'Tanggal kegiatan',
            nilai: FormatTanggal.panjang(_info.tanggalKegiatan),
          ),
          const SizedBox(height: 10),
          _BarisKeterangan(
            ikon: Icons.schedule_rounded,
            label: 'Diumumkan',
            nilai:
                '${FormatTanggal.panjang(_info.dibuatPada)}, '
                'pukul ${FormatTanggal.jam(_info.dibuatPada)} WIB',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: AppColors.garis, height: 1),
          ),
          SelectableText(
            _info.isi,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.teks,
              height: 1.65,
            ),
          ),
          if (_info.lampiran != null) ...[
            const SizedBox(height: 24),
            _KartuLampiran(
              lampiran: _info.lampiran!,
              onBuka: () => bukaLampiran(context, _info.lampiran!),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarisKeterangan extends StatelessWidget {
  const _BarisKeterangan({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  final IconData ikon;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.biru.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikon, size: 18, color: const Color(0xFF2B7BC4)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.teksAbu),
              ),
              Text(
                nilai,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teks,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KartuLampiran extends StatelessWidget {
  const _KartuLampiran({required this.lampiran, required this.onBuka});

  final LampiranInfo lampiran;
  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context) {
    final adalahPdf = lampiran.nama.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.isian,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Row(
        children: [
          Icon(
            adalahPdf
                ? Icons.picture_as_pdf_rounded
                : Icons.insert_drive_file_rounded,
            color: adalahPdf ? AppColors.merah : AppColors.teksAbu,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lampiran',
                  style: TextStyle(fontSize: 11, color: AppColors.teksAbu),
                ),
                Text(
                  lampiran.nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teks,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: onBuka,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('Unduh'),
          ),
        ],
      ),
    );
  }
}
