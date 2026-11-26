import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/cuti.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/cuti_service.dart';
import '../../widgets/gaya_cuti.dart';
import '../../widgets/loading_dots.dart';
import 'detail_cuti_admin_screen.dart';

/// Admin: daftar pengajuan cuti / izin / sakit semua guru untuk disetujui
/// atau ditolak. Tab "Menunggu" diurutkan dari pengajuan paling lama.
class PersetujuanCutiScreen extends StatefulWidget {
  const PersetujuanCutiScreen({super.key, this.cutiService, this.absenService});

  final CutiService? cutiService;
  final AbsenService? absenService;

  @override
  State<PersetujuanCutiScreen> createState() => _PersetujuanCutiScreenState();
}

class _PersetujuanCutiScreenState extends State<PersetujuanCutiScreen> {
  late final CutiService _service = widget.cutiService ?? CutiService();
  final _cariController = TextEditingController();
  Timer? _jedaCari;

  /// null = semua status.
  StatusCuti? _status = StatusCuti.menunggu;
  DaftarCutiAdmin? _data;
  bool _sedangMemuat = true;
  String? _pesanGagal;
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
    setState(() {
      _sedangMemuat = true;
      _pesanGagal = null;
    });
    try {
      final data = await _service.daftarAdmin(
        status: _status,
        cari: _cariController.text,
      );
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _data = data;
        _sedangMemuat = false;
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _sedangMemuat = false;
        _pesanGagal = e.pesan;
      });
    }
  }

  void _pilihStatus(StatusCuti? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _muat();
  }

  Future<void> _buka(PengajuanCuti cuti) async {
    final berubah = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DetailCutiAdminScreen(
          idCuti: cuti.idCuti,
          cutiService: _service,
          absenService: widget.absenService,
        ),
      ),
    );
    if (berubah == true) _muat();
  }

  @override
  Widget build(BuildContext context) {
    final menunggu = _data?.jumlahMenunggu;
    return Scaffold(
      backgroundColor: AppColors.putih,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Persetujuan Cuti / Izin'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _cariController,
              onChanged: (_) {
                _jedaCari?.cancel();
                _jedaCari = Timer(const Duration(milliseconds: 400), _muat);
              },
              decoration: const InputDecoration(
                hintText: 'Cari nama atau NIY guru...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final s in <StatusCuti?>[...StatusCuti.values, null])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        s == StatusCuti.menunggu && menunggu != null
                            ? 'Menunggu ($menunggu)'
                            : s?.label ?? 'Semua',
                      ),
                      selected: _status == s,
                      onSelected: (_) => _pilihStatus(s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (_sedangMemuat && _data != null)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    final data = _data;
    if (data == null) {
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
    if (data.pengajuan.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: AppColors.teksAbu.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              _status == StatusCuti.menunggu
                  ? 'Tidak ada pengajuan yang menunggu.'
                  : 'Belum ada pengajuan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.teksAbu),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: data.pengajuan.length,
        itemBuilder: (context, i) => _KartuPengajuanAdmin(
          cuti: data.pengajuan[i],
          onTap: () => _buka(data.pengajuan[i]),
        ),
      ),
    );
  }
}

class _KartuPengajuanAdmin extends StatelessWidget {
  const _KartuPengajuanAdmin({required this.cuti, required this.onTap});

  final PengajuanCuti cuti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final guru = cuti.guru;
    const kecil = TextStyle(fontSize: 12, color: AppColors.teksAbu);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cuti.status == StatusCuti.menunggu
              ? cuti.status.warna.withValues(alpha: 0.5)
              : AppColors.garis,
        ),
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
                            guru?.namaTampil ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teks,
                            ),
                          ),
                        ),
                        ChipCuti.status(cuti.status),
                      ],
                    ),
                    Text(
                      'NIY ${guru?.nomorInduk ?? '-'}'
                      '${guru?.unit == null ? '' : ' • ${guru!.unit}'}',
                      style: kecil,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${cuti.jenis.label} • ${cuti.jumlahHari} hari • '
                      '${rentangTanggalCuti(cuti.tanggalMulai, cuti.tanggalSelesai)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cuti.jenis.warna,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cuti.alasan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.teks,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        if (cuti.jumlahMapel != null)
                          _Info(
                            Icons.menu_book_rounded,
                            '${cuti.jumlahMapel} mapel ditinggalkan',
                          ),
                        if (cuti.adaLampiran)
                          const _Info(Icons.attach_file_rounded, 'Lampiran'),
                        _Info(
                          Icons.schedule_rounded,
                          'Diajukan ${waktuSingkat(cuti.dibuatPada)}',
                        ),
                      ],
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

class _Info extends StatelessWidget {
  const _Info(this.ikon, this.teks);

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 14, color: AppColors.teksAbu),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            teks,
            style: const TextStyle(fontSize: 11.5, color: AppColors.teksAbu),
          ),
        ),
      ],
    );
  }
}
