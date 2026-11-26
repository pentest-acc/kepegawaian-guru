import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/cuti.dart';
import '../../services/api_service.dart';
import '../../services/cuti_service.dart';
import '../../services/pemilih_foto.dart';
import '../../utils/pesan.dart';
import '../../widgets/gaya_cuti.dart';
import '../../widgets/loading_dots.dart';
import 'form_cuti_screen.dart';

/// Halaman Cuti / Izin guru: sisa kuota cuti tahun ini, daftar pengajuan
/// beserta statusnya, dan tombol untuk mengajukan cuti / izin / sakit.
class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key, this.cutiService, this.pemilihFoto});

  final CutiService? cutiService;
  final PemilihFoto? pemilihFoto;

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen> {
  late final CutiService _service = widget.cutiService ?? CutiService();

  DataCutiSaya? _data;
  bool _sedangMemuat = true;
  String? _pesanGagal;

  /// null = semua status.
  StatusCuti? _filter;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final data = await _service.saya();
      if (!mounted) return;
      setState(() {
        _data = data;
        _sedangMemuat = false;
        _pesanGagal = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sedangMemuat = false;
        _pesanGagal = e.tidakAdaKoneksi
            ? 'Data cuti belum bisa dimuat. Periksa koneksi internet.'
            : e.pesan;
      });
    }
  }

  Future<void> _ajukan() async {
    final data = _data;
    final pesan = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FormCutiScreen(
          cutiService: _service,
          pemilihFoto: widget.pemilihFoto,
          hariIni: data?.hariIni,
          kuota: data?.kuota,
        ),
      ),
    );
    if (pesan == null || !mounted) return;
    tampilkanPesan(context, pesan);
    setState(() => _filter = null);
    _muat();
  }

  Future<void> _bukaDetail(PengajuanCuti cuti) async {
    final dibatalkan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _LembarDetail(cuti: cuti, service: _service),
    );
    if (dibatalkan == true) _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.putih,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Cuti / Izin'),
      ),
      floatingActionButton: _data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _ajukan,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajukan'),
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
    final data = _data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_pesanGagal ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _sedangMemuat = true);
                  _muat();
                },
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final daftar = _filter == null
        ? data.pengajuan
        : data.pengajuan.where((c) => c.status == _filter).toList();

    int jumlah(StatusCuti? s) => s == null
        ? data.pengajuan.length
        : data.pengajuan.where((c) => c.status == s).length;

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _KartuKuota(kuota: data.kuota),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in <StatusCuti?>[null, ...StatusCuti.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${s?.label ?? 'Semua'} (${jumlah(s)})'),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (daftar.isEmpty)
            _KosongCuti(semua: _filter == null)
          else
            for (final c in daftar)
              _KartuPengajuan(cuti: c, onTap: () => _bukaDetail(c)),
        ],
      ),
    );
  }
}

/// Kuota cuti tahun ini.
class _KartuKuota extends StatelessWidget {
  const _KartuKuota({required this.kuota});

  final KuotaCuti kuota;

  @override
  Widget build(BuildContext context) {
    final dipakai = kuota.terpakai + kuota.diajukan;
    final persen = kuota.kuota == 0
        ? 1.0
        : (dipakai / kuota.kuota).clamp(0, 1).toDouble();

    Widget angka(String label, int nilai) => Expanded(
      child: Column(
        children: [
          Text(
            '$nilai',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040029), Color(0xFF0B0068)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kuota Cuti ${kuota.tahun}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${kuota.sisa}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    'hari tersisa dari ${kuota.kuota} hari',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: persen,
              minHeight: 8,
              color: AppColors.mint,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              angka('Terpakai', kuota.terpakai),
              angka('Menunggu', kuota.diajukan),
              angka('Sisa', kuota.sisa),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Izin & sakit tidak memotong kuota cuti. Minggu & hari libur '
            'tidak dihitung.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPengajuan extends StatelessWidget {
  const _KartuPengajuan({required this.cuti, required this.onTap});

  final PengajuanCuti cuti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.garis),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IkonJenisCuti(cuti.jenis),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${cuti.jenis.label} • ${cuti.jumlahHari} hari',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teks,
                            ),
                          ),
                        ),
                        ChipCuti.status(cuti.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rentangTanggalCuti(
                        cuti.tanggalMulai,
                        cuti.tanggalSelesai,
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyTerang,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cuti.alasan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.teksAbu,
                      ),
                    ),
                    if (cuti.catatanAdmin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Catatan admin: ${cuti.catatanAdmin}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cuti.status.warna,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KosongCuti extends StatelessWidget {
  const _KosongCuti({required this.semua});

  final bool semua;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 56,
            color: AppColors.teksAbu.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            semua ? 'Belum ada pengajuan' : 'Tidak ada pengajuan di sini',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tekan tombol Ajukan untuk mengajukan cuti, izin, atau sakit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
          ),
        ],
      ),
    );
  }
}

/// Detail satu pengajuan + tombol batal (jika masih menunggu).
class _LembarDetail extends StatefulWidget {
  const _LembarDetail({required this.cuti, required this.service});

  final PengajuanCuti cuti;
  final CutiService service;

  @override
  State<_LembarDetail> createState() => _LembarDetailState();
}

class _LembarDetailState extends State<_LembarDetail> {
  Uint8List? _lampiran;
  bool _memuatLampiran = false;
  bool _membatalkan = false;

  @override
  void initState() {
    super.initState();
    if (widget.cuti.adaLampiran) _muatLampiran();
  }

  Future<void> _muatLampiran() async {
    setState(() => _memuatLampiran = true);
    try {
      final bytes = await widget.service.ambilLampiran(widget.cuti.idCuti);
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

  Future<void> _batal() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: Text(
          'Pengajuan ${widget.cuti.jenis.label.toLowerCase()} '
          '${rentangTanggalCuti(widget.cuti.tanggalMulai, widget.cuti.tanggalSelesai)} '
          'akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.merah),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    setState(() => _membatalkan = true);
    try {
      final pesan = await widget.service.batal(widget.cuti.idCuti);
      if (!mounted) return;
      tampilkanPesan(context, pesan);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _membatalkan = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cuti;
    Widget baris(String label, String isi) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.teksAbu),
          ),
          const SizedBox(height: 2),
          Text(
            isi,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.teks,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IkonJenisCuti(c.jenis),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${c.jenis.label} • ${c.jumlahHari} hari kerja',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ChipCuti.status(c.status),
              ],
            ),
            const SizedBox(height: 16),
            baris(
              'Tanggal',
              rentangTanggalCuti(c.tanggalMulai, c.tanggalSelesai),
            ),
            baris('Diajukan', waktuSingkat(c.dibuatPada)),
            baris('Alasan', c.alasan),
            if (c.diprosesPada != null)
              baris(
                c.status == StatusCuti.disetujui ? 'Disetujui' : 'Ditolak',
                '${waktuSingkat(c.diprosesPada!)}'
                '${c.diprosesOleh == null ? '' : ' oleh ${c.diprosesOleh}'}',
              ),
            if (c.catatanAdmin != null) baris('Catatan admin', c.catatanAdmin!),
            if (c.adaLampiran) ...[
              const Text(
                'Lampiran',
                style: TextStyle(fontSize: 12, color: AppColors.teksAbu),
              ),
              const SizedBox(height: 6),
              if (_memuatLampiran)
                const LinearProgressIndicator()
              else if (_lampiran == null)
                const Text('Lampiran gagal dimuat.')
              else
                GestureDetector(
                  onTap: () =>
                      tampilkanFotoLampiran(context, MemoryImage(_lampiran!)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _lampiran!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Bagian atas surat (kop & judul) yang ditampilkan
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (c.status == StatusCuti.menunggu)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Pengajuan sedang menunggu persetujuan admin.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
                ),
              ),
            if (c.bisaDibatalkan)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _membatalkan ? null : _batal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.merah,
                    side: const BorderSide(color: AppColors.merah),
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _membatalkan ? 'Membatalkan...' : 'Batalkan pengajuan',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
