import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/jadwal_mengajar.dart';
import '../../services/api_service.dart';
import '../../services/jadwal_service.dart';
import '../../utils/hari.dart';
import '../../utils/pesan.dart';
import '../../widgets/loading_dots.dart';
import 'form_jadwal_screen.dart';

/// Admin: jadwal mingguan seorang guru, dikelompokkan per hari.
/// Dari sini admin bisa menambah, mengubah, dan menghapus jadwal.
class AdminJadwalGuruScreen extends StatefulWidget {
  const AdminJadwalGuruScreen({
    super.key,
    required this.guru,
    this.jadwalService,
  });

  final GuruRingkas guru;
  final JadwalService? jadwalService;

  @override
  State<AdminJadwalGuruScreen> createState() => _AdminJadwalGuruScreenState();
}

class _AdminJadwalGuruScreenState extends State<AdminJadwalGuruScreen> {
  late final JadwalService _service = widget.jadwalService ?? JadwalService();

  List<JadwalMengajar> _jadwal = const [];
  bool _sedangMemuat = true;
  String? _pesanGagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final hasil = await _service.daftarJadwalGuru(widget.guru.idPengguna);
      if (!mounted) return;
      setState(() {
        _jadwal = hasil;
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

  Future<void> _bukaForm({JadwalMengajar? jadwal, String? hari}) async {
    final tersimpan = await Navigator.of(context).push<JadwalMengajar>(
      MaterialPageRoute(
        builder: (_) => FormJadwalScreen(
          guru: widget.guru,
          jadwal: jadwal,
          hariAwal: hari,
          jadwalService: _service,
        ),
      ),
    );
    if (tersimpan != null && mounted) {
      tampilkanPesan(
        context,
        jadwal == null ? 'Jadwal berhasil ditambahkan.' : 'Jadwal diubah.',
      );
      _muat();
    }
  }

  Future<void> _hapus(JadwalMengajar jadwal) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text(
          '${jadwal.mataPelajaran} (${jadwal.hari}, ${jadwal.jamTampil}, '
          'kelas ${jadwal.kelas}) akan dihapus dari jadwal mingguan '
          '${widget.guru.namaTampil}.',
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
      await _service.hapus(jadwal.idJadwal!);
      if (!mounted) return;
      tampilkanPesan(context, 'Jadwal dihapus.');
      _muat();
    } on ApiException catch (e) {
      if (!mounted) return;
      tampilkanPesan(context, e.pesan, gagal: true);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jadwal Mingguan'),
            Text(
              widget.guru.namaTampil,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.guru.aktif
          ? FloatingActionButton.extended(
              onPressed: () => _bukaForm(),
              backgroundColor: AppColors.biru,
              foregroundColor: AppColors.navy,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Jadwal'),
            )
          : null,
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
                Icon(Icons.repeat_rounded, color: AppColors.hijau, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jadwal di bawah berlaku SETIAP MINGGU. Cukup ubah di sini '
                    'jika ada perubahan; tanggal yang ditetapkan sebagai hari '
                    'libur otomatis tidak ada kegiatan mengajar.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.guru.aktif)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Akun guru ini nonaktif, jadwal tidak bisa ditambah.',
                style: TextStyle(fontSize: 12, color: AppColors.merah),
              ),
            ),
          for (final hari in Hari.sekolah) _bagianHari(hari),
        ],
      ),
    );
  }

  Widget _bagianHari(String hari) {
    final daftar = _jadwal.where((j) => j.hari == hari).toList()
      ..sort((a, b) => a.menitMulai.compareTo(b.menitMulai));
    // Sabtu hanya ditampilkan jika ada jadwalnya
    if (hari == 'Sabtu' && daftar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hari,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teks,
                        ),
                      ),
                      TextSpan(
                        text: '   ${daftar.length} jam pelajaran',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.teksAbu,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.guru.aktif)
                IconButton(
                  tooltip: 'Tambah jadwal hari $hari',
                  onPressed: () => _bukaForm(hari: hari),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF2B7BC4),
                  ),
                ),
            ],
          ),
          if (daftar.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Belum ada jadwal.',
                style: TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
              ),
            ),
          for (final jadwal in daftar)
            Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(top: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.garis),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _bukaForm(jadwal: jadwal),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              jadwal.jamMulai.replaceAll(':', '.'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              jadwal.jamSelesai.replaceAll(':', '.'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jadwal.mataPelajaran,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${jadwal.unit}  •  Kelas ${jadwal.kelas}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.teksAbu,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus jadwal',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.merah,
                        ),
                        onPressed: () => _hapus(jadwal),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
