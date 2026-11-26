import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../models/cuti.dart';
import '../../models/pengguna.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/cuti_service.dart';
import '../../widgets/loading_overlay.dart';
import 'admin_lokasi_absen_screen.dart';
import 'admin_pilih_guru_screen.dart';
import 'monitoring_absensi_screen.dart';
import 'pengaturan_sistem_screen.dart';
import 'persetujuan_cuti_screen.dart';

/// Halaman awal Admin (sementara).
///
/// Fitur admin (Dashboard, Data Guru, Kelola Info Kegiatan, dll.) akan
/// dibuat setelah semua fitur Guru selesai.
class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({
    super.key,
    required this.pengguna,
    this.authService,
    this.cutiService,
  });

  final Pengguna pengguna;
  final AuthService? authService;
  final CutiService? cutiService;

  static const List<(IconData, String)> _rencanaFitur = [
    (Icons.dashboard_rounded, 'Dashboard kehadiran hari ini'),
    (Icons.groups_rounded, 'Data Guru'),
    (Icons.campaign_rounded, 'Kelola Info Kegiatan'),
    (Icons.calendar_month_rounded, 'Kelola Jadwal Mengajar'),
    (Icons.fact_check_rounded, 'Monitoring Absensi'),
    (Icons.manage_history_rounded, 'Riwayat Absen Guru'),
    (Icons.add_location_alt_rounded, 'Lokasi Absen'),
    (Icons.approval_rounded, 'Persetujuan Cuti'),
    (Icons.print_rounded, 'Laporan (PDF/Excel)'),
    (Icons.tune_rounded, 'Pengaturan Sistem'),
  ];

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  late final CutiService _cuti = widget.cutiService ?? CutiService();
  bool _sedangKeluar = false;

  /// Jumlah pengajuan cuti/izin yang menunggu persetujuan.
  int _cutiMenunggu = 0;

  @override
  void initState() {
    super.initState();
    _muatCutiMenunggu();
  }

  Future<void> _muatCutiMenunggu() async {
    try {
      final data = await _cuti.daftarAdmin(status: StatusCuti.menunggu);
      if (!mounted) return;
      setState(() => _cutiMenunggu = data.jumlahMenunggu);
    } on ApiException {
      // Lencana jumlah hanya pelengkap; abaikan jika gagal dimuat.
    }
  }

  Future<void> _bukaFitur(String nama) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _halamanFitur(nama)!));
    if (nama == 'Persetujuan Cuti') _muatCutiMenunggu();
  }

  /// Halaman untuk fitur admin yang sudah tersedia (null = belum dibuat).
  Widget? _halamanFitur(String nama) {
    switch (nama) {
      case 'Kelola Jadwal Mengajar':
        return const AdminPilihGuruScreen();
      case 'Monitoring Absensi':
        return const MonitoringAbsensiScreen();
      case 'Riwayat Absen Guru':
        return const AdminPilihGuruScreen(tujuan: TujuanPilihGuru.riwayatAbsen);
      case 'Persetujuan Cuti':
        return PersetujuanCutiScreen(cutiService: _cuti);
      case 'Lokasi Absen':
        return const AdminLokasiAbsenScreen();
      case 'Pengaturan Sistem':
        return const PengaturanSistemScreen();
      default:
        return null;
    }
  }

  Future<void> _keluar() async {
    setState(() => _sedangKeluar = true);
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      sedangMemuat: _sedangKeluar,
      teks: 'Sedang keluar...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          actions: [
            IconButton(
              tooltip: 'Keluar',
              onPressed: _keluar,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyTerang],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${widget.pengguna.namaTampil}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.pengguna.jabatan,
                    style: const TextStyle(color: AppColors.mint, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fitur Admin:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final (ikon, nama) in DashboardAdminScreen._rencanaFitur)
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.garis),
                ),
                child: ListTile(
                  leading: Icon(ikon, color: AppColors.navyTerang),
                  title: Text(nama, style: const TextStyle(fontSize: 14)),
                  onTap: _halamanFitur(nama) == null
                      ? null
                      : () => _bukaFitur(nama),
                  trailing: nama == 'Persetujuan Cuti' && _cutiMenunggu > 0
                      ? Badge(
                          key: const Key('lencana-cuti'),
                          backgroundColor: AppColors.merah,
                          label: Text('$_cutiMenunggu menunggu'),
                        )
                      : _halamanFitur(nama) == null
                      ? const Text(
                          'Segera',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.teksAbu,
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
