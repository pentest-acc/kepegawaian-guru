import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/cuti.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/cuti_service.dart';
import '../../utils/pesan.dart';
import '../../widgets/gaya_cuti.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/loading_overlay.dart';
import '../guru/riwayat_absen_screen.dart';

/// Admin: detail satu pengajuan cuti / izin / sakit beserta lampiran,
/// kuota cuti guru, dan mapel yang ditinggalkan (untuk mencari guru
/// pengganti), lalu menyetujui atau menolaknya.
///
/// Halaman ditutup dengan nilai `true` jika pengajuan diproses.
class DetailCutiAdminScreen extends StatefulWidget {
  const DetailCutiAdminScreen({
    super.key,
    required this.idCuti,
    this.cutiService,
    this.absenService,
  });

  final int idCuti;
  final CutiService? cutiService;
  final AbsenService? absenService;

  @override
  State<DetailCutiAdminScreen> createState() => _DetailCutiAdminScreenState();
}

class _DetailCutiAdminScreenState extends State<DetailCutiAdminScreen> {
  late final CutiService _service = widget.cutiService ?? CutiService();
  final _catatanController = TextEditingController();

  DetailCutiAdmin? _detail;
  String? _pesanGagal;
  Uint8List? _lampiran;
  bool _memuatLampiran = false;
  bool _memproses = false;
  String? _kesalahanCatatan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final detail = await _service.detailAdmin(widget.idCuti);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _pesanGagal = null;
      });
      if (detail.cuti.adaLampiran) _muatLampiran();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _pesanGagal = e.pesan);
    }
  }

  Future<void> _muatLampiran() async {
    setState(() => _memuatLampiran = true);
    try {
      final bytes = await _service.ambilLampiran(widget.idCuti);
      if (!mounted) return;
      setState(() {
        _lampiran = bytes;
        _memuatLampiran = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _memuatLampiran = false);
    }
  }

  Future<void> _proses({required bool setujui}) async {
    final detail = _detail!;
    final catatan = _catatanController.text.trim();
    if (!setujui && catatan.length < 5) {
      setState(
        () => _kesalahanCatatan =
            'Tuliskan alasan penolakan agar guru mengetahuinya.',
      );
      return;
    }
    setState(() => _kesalahanCatatan = null);

    final nama = detail.cuti.guru?.namaTampil ?? 'guru';
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(setujui ? 'Setujui pengajuan?' : 'Tolak pengajuan?'),
        content: Text(
          '${detail.cuti.jenis.label} $nama '
          '${rentangTanggalCuti(detail.cuti.tanggalMulai, detail.cuti.tanggalSelesai)} '
          '(${detail.cuti.jumlahHari} hari) akan '
          '${setujui ? 'disetujui' : 'ditolak'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: setujui ? AppColors.hijau : AppColors.merah,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(setujui ? 'Ya, setujui' : 'Ya, tolak'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _memproses = true);
    try {
      final hasil = await _service.proses(
        widget.idCuti,
        setujui: setujui,
        catatan: catatan,
      );
      if (!mounted) return;
      tampilkanPesan(context, hasil.pesan);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _memproses = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  void _bukaRiwayat() {
    final guru = _detail?.cuti.guru;
    if (guru == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RiwayatAbsenScreen(guru: guru, absenService: widget.absenService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      sedangMemuat: _memproses,
      teks: 'Menyimpan keputusan...',
      child: Scaffold(
        backgroundColor: AppColors.putih,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Detail Pengajuan'),
        ),
        body: _isi(),
      ),
    );
  }

  Widget _isi() {
    final detail = _detail;
    if (detail == null) {
      if (_pesanGagal != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_pesanGagal!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _muat, child: const Text('Coba lagi')),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }

    final c = detail.cuti;
    final guru = c.guru;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IkonJenisCuti(c.jenis, ukuran: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guru?.namaTampil ?? '-',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'NIY ${guru?.nomorInduk ?? '-'}'
                          '${guru?.unit == null ? '' : ' • ${guru!.unit}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.teksAbu,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ChipCuti.status(c.status),
                ],
              ),
              const Divider(height: 24),
              _Baris('Jenis', c.jenis.label),
              _Baris(
                'Tanggal',
                rentangTanggalCuti(c.tanggalMulai, c.tanggalSelesai),
              ),
              _Baris('Jumlah', '${c.jumlahHari} hari kerja'),
              _Baris('Diajukan', waktuSingkat(c.dibuatPada)),
              _Baris('Alasan', c.alasan),
              if (c.diprosesPada != null)
                _Baris(
                  c.status == StatusCuti.disetujui ? 'Disetujui' : 'Ditolak',
                  '${waktuSingkat(c.diprosesPada!)}'
                  '${c.diprosesOleh == null ? '' : ' oleh ${c.diprosesOleh}'}',
                ),
              if (c.catatanAdmin != null)
                _Baris('Catatan admin', c.catatanAdmin!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _bukaRiwayat,
                  icon: const Icon(Icons.manage_history_rounded),
                  label: const Text('Lihat riwayat absen guru ini'),
                ),
              ),
            ],
          ),
        ),
        if (c.adaLampiran) ...[
          const SizedBox(height: 12),
          _Kartu(
            judul: 'Lampiran',
            child: _memuatLampiran
                ? const LinearProgressIndicator()
                : _lampiran == null
                ? const Text('Lampiran gagal dimuat.')
                : GestureDetector(
                    onTap: () =>
                        tampilkanFotoLampiran(context, MemoryImage(_lampiran!)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _lampiran!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Bagian atas surat (kop & judul) yang ditampilkan
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
          ),
        ],
        if (c.jenis == JenisCuti.cuti) ...[
          const SizedBox(height: 12),
          _KartuKuota(detail: detail),
        ],
        if (detail.bertumpuk != null) ...[
          const SizedBox(height: 12),
          _Peringatan(
            'Bertumpuk dengan pengajuan lain yang sudah disetujui: '
            '${detail.bertumpuk}.',
          ),
        ],
        const SizedBox(height: 12),
        _Kartu(
          judul: detail.jumlahMapel == 0
              ? 'Mapel yang ditinggalkan'
              : 'Mapel yang ditinggalkan (${detail.jumlahMapel})',
          child: detail.jumlahMapel == 0
              ? const Text(
                  'Tidak ada jadwal mengajar di tanggal tersebut.',
                  style: TextStyle(fontSize: 13, color: AppColors.teksAbu),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in detail.hari)
                      if (h.mapel.isNotEmpty) _HariMapel(hari: h),
                  ],
                ),
        ),
        if (c.status == StatusCuti.menunggu) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _catatanController,
            maxLength: 255,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Catatan untuk guru',
              hintText: 'Wajib diisi jika menolak',
              errorText: _kesalahanCatatan,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _proses(setujui: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.merah,
                    side: const BorderSide(color: AppColors.merah),
                    minimumSize: const Size(0, 50),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _proses(setujui: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.hijau,
                    minimumSize: const Size(0, 50),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.child, this.judul});

  final String? judul;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (judul != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                judul!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teks,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris(this.label, this.isi);

  final String label;
  final String isi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
            ),
          ),
          Expanded(
            child: Text(
              isi,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.teks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuKuota extends StatelessWidget {
  const _KartuKuota({required this.detail});

  final DetailCutiAdmin detail;

  @override
  Widget build(BuildContext context) {
    final k = detail.kuota;
    final c = detail.cuti;
    final setelah = k.kuota - k.terpakai - c.jumlahHari;
    final cukup = setelah >= 0;
    return _Kartu(
      judul: 'Kuota cuti ${k.tahun}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terpakai ${k.terpakai} dari ${k.kuota} hari'
            '${k.diajukan > 0 ? ' • ${k.diajukan} hari lain masih menunggu' : ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.teks),
          ),
          if (c.status == StatusCuti.menunggu)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                cukup
                    ? 'Jika disetujui: sisa $setelah hari.'
                    : 'Kuota tidak cukup: kurang ${-setelah} hari.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cukup ? AppColors.hijau : AppColors.merah,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HariMapel extends StatelessWidget {
  const _HariMapel({required this.hari});

  final HariCuti hari;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(hari.tanggal),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navyTerang,
            ),
          ),
          for (final m in hari.mapel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      m.jamTampil,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.teksAbu,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${m.mataPelajaran} • ${m.unit} ${m.kelas}'
                      '${m.lokasi == null ? '' : ' • ${m.lokasi}'}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.merah.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.merah),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 12.5, color: AppColors.merah),
            ),
          ),
        ],
      ),
    );
  }
}
