import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/jadwal_mengajar.dart';
import '../../services/api_service.dart';
import '../../services/jadwal_service.dart';
import '../../widgets/loading_dots.dart';
import 'admin_jadwal_guru_screen.dart';

/// Admin: memilih guru yang jadwal mengajarnya akan diatur.
class AdminPilihGuruScreen extends StatefulWidget {
  const AdminPilihGuruScreen({super.key, this.jadwalService});

  final JadwalService? jadwalService;

  @override
  State<AdminPilihGuruScreen> createState() => _AdminPilihGuruScreenState();
}

class _AdminPilihGuruScreenState extends State<AdminPilihGuruScreen> {
  late final JadwalService _service = widget.jadwalService ?? JadwalService();
  final _cariController = TextEditingController();
  Timer? _jedaCari;

  List<GuruRingkas> _daftar = const [];
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
    if (!_sedangMemuat) {
      setState(() {
        _sedangMemuat = true;
        _pesanGagal = null;
      });
    }
    try {
      final hasil = await _service.daftarGuru(cari: _cariController.text);
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _daftar = hasil;
        _sedangMemuat = false;
        _pesanGagal = null;
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  void _saatCariBerubah(String _) {
    _jedaCari?.cancel();
    _jedaCari = Timer(const Duration(milliseconds: 400), _muat);
  }

  Future<void> _bukaGuru(GuruRingkas guru) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminJadwalGuruScreen(guru: guru, jadwalService: _service),
      ),
    );
    _muat(); // jumlah jadwal mungkin berubah
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
        title: const Text('Kelola Jadwal Mengajar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _cariController,
              onChanged: _saatCariBerubah,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau NIY guru...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Pilih guru untuk mengatur jadwal mingguannya. Jadwal otomatis '
              'berulang setiap minggu.',
              style: TextStyle(fontSize: 12, color: AppColors.teksAbu),
            ),
          ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_sedangMemuat && _daftar.isEmpty) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }
    if (_pesanGagal != null && _daftar.isEmpty) {
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
    if (_daftar.isEmpty) {
      return const Center(child: Text('Guru tidak ditemukan.'));
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _daftar.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final guru = _daftar[i];
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.garis),
            ),
            child: ListTile(
              onTap: () => _bukaGuru(guru),
              leading: CircleAvatar(
                backgroundColor: AppColors.biru.withValues(alpha: 0.2),
                child: Text(
                  guru.unit ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              title: Text(
                guru.namaTampil,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'NIY ${guru.nomorInduk}  •  ${guru.jumlahJadwal} jam pelajaran'
                '${guru.aktif ? '' : '  •  NONAKTIF'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}
