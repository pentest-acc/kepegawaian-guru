import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/absensi.dart';

/// Label, warna, dan ikon untuk sebuah keadaan kehadiran mapel.
class GayaKehadiran {
  const GayaKehadiran(this.label, this.warna, this.ikon);

  final String label;
  final Color warna;
  final IconData ikon;

  static const hijau = Color(0xFF2E9E5B);
  static const kuning = Color(0xFFB7791F);
  static const merah = AppColors.merah;
  static const merahTua = Color(0xFF9B2C2C);
  static const biru = Color(0xFF2B6CB0);
  static const abu = Color(0xFF64748B);

  /// [jamBuka] = jam absen dibuka (untuk guru), mis. "07.00".
  factory GayaKehadiran.dari(
    KeadaanMapel keadaan, {
    AbsensiMapel? absensi,
    String? jamBuka,
  }) {
    final jam = absensi?.jamAbsen == null
        ? ''
        : ' • ${jamTitik(absensi!.jamAbsen!)}';
    final olehAdmin = absensi != null && absensi.jamAbsen == null
        ? ' (diisi admin)'
        : '';
    switch (keadaan) {
      case KeadaanMapel.belumDibuka:
        return GayaKehadiran(
          jamBuka == null ? 'Belum dimulai' : 'Absen dibuka $jamBuka',
          abu,
          Icons.schedule_rounded,
        );
      case KeadaanMapel.belumAbsen:
        return const GayaKehadiran(
          'Belum absen',
          abu,
          Icons.radio_button_unchecked_rounded,
        );
      case KeadaanMapel.terlewat:
        return const GayaKehadiran(
          'Belum absen',
          merah,
          Icons.error_outline_rounded,
        );
      case KeadaanMapel.hadir:
        return GayaKehadiran(
          'Hadir$jam$olehAdmin',
          hijau,
          Icons.check_circle_rounded,
        );
      case KeadaanMapel.terlambat:
        return GayaKehadiran(
          'Terlambat ${absensi!.menitTerlambat} menit$jam',
          kuning,
          Icons.watch_later_rounded,
        );
      case KeadaanMapel.lewatJam:
        return GayaKehadiran(
          'Lewat jam pelajaran • +${absensi!.menitTerlambat} menit$jam',
          merah,
          Icons.running_with_errors_rounded,
        );
      case KeadaanMapel.izin:
        return GayaKehadiran('Izin$olehAdmin', biru, Icons.assignment_rounded);
      case KeadaanMapel.sakit:
        return GayaKehadiran(
          'Sakit$olehAdmin',
          biru,
          Icons.medical_services_rounded,
        );
      case KeadaanMapel.cuti:
        return GayaKehadiran(
          'Cuti$olehAdmin',
          biru,
          Icons.beach_access_rounded,
        );
      case KeadaanMapel.alpa:
        return const GayaKehadiran(
          'Alpa (tidak hadir)',
          merahTua,
          Icons.cancel_rounded,
        );
    }
  }
}

/// Penanda kehadiran berwarna, mis. "Terlambat 12 menit • 07.42".
class ChipKehadiran extends StatelessWidget {
  const ChipKehadiran({super.key, required this.gaya});

  final GayaKehadiran gaya;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gaya.warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gaya.warna.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gaya.ikon, size: 15, color: gaya.warna),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              gaya.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: gaya.warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
