import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../models/cuti.dart';

/// Warna & ikon setiap jenis pengajuan.
extension GayaJenisCuti on JenisCuti {
  Color get warna {
    switch (this) {
      case JenisCuti.cuti:
        return const Color(0xFFE39A0E);
      case JenisCuti.izin:
        return const Color(0xFF2F86DE);
      case JenisCuti.sakit:
        return AppColors.merah;
    }
  }

  IconData get ikon {
    switch (this) {
      case JenisCuti.cuti:
        return Icons.beach_access_rounded;
      case JenisCuti.izin:
        return Icons.assignment_rounded;
      case JenisCuti.sakit:
        return Icons.medical_services_rounded;
    }
  }
}

/// Warna & ikon setiap status pengajuan.
extension GayaStatusCuti on StatusCuti {
  Color get warna {
    switch (this) {
      case StatusCuti.menunggu:
        return const Color(0xFFB7791F);
      case StatusCuti.disetujui:
        return AppColors.hijau;
      case StatusCuti.ditolak:
        return AppColors.merah;
    }
  }

  IconData get ikon {
    switch (this) {
      case StatusCuti.menunggu:
        return Icons.hourglass_top_rounded;
      case StatusCuti.disetujui:
        return Icons.check_circle_rounded;
      case StatusCuti.ditolak:
        return Icons.cancel_rounded;
    }
  }
}

/// "Sel, 1 Des 2026" atau "Sel, 1 Des - Kam, 3 Des 2026".
String rentangTanggalCuti(DateTime mulai, DateTime selesai) {
  final hariBulan = DateFormat('EEE, d MMM', 'id_ID');
  final lengkap = DateFormat('EEE, d MMM yyyy', 'id_ID');
  if (mulai.year == selesai.year &&
      mulai.month == selesai.month &&
      mulai.day == selesai.day) {
    return lengkap.format(mulai);
  }
  final awal = mulai.year == selesai.year
      ? hariBulan.format(mulai)
      : lengkap.format(mulai);
  return '$awal - ${lengkap.format(selesai)}';
}

/// "26 Nov 2026, 09.15"
String waktuSingkat(DateTime t) =>
    DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(t);

/// Penanda kecil berwarna, mis. status "Menunggu" atau jenis "Sakit".
class ChipCuti extends StatelessWidget {
  const ChipCuti({
    super.key,
    required this.label,
    required this.warna,
    this.ikon,
  });

  ChipCuti.status(StatusCuti status, {super.key})
    : label = status.label,
      warna = status.warna,
      ikon = status.ikon;

  ChipCuti.jenis(JenisCuti jenis, {super.key})
    : label = jenis.label,
      warna = jenis.warna,
      ikon = jenis.ikon;

  final String label;
  final Color warna;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 13, color: warna),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak ikon jenis pengajuan (di kiri kartu).
class IkonJenisCuti extends StatelessWidget {
  const IkonJenisCuti(this.jenis, {super.key, this.ukuran = 44});

  final JenisCuti jenis;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        color: jenis.warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(jenis.ikon, color: jenis.warna, size: ukuran * 0.52),
    );
  }
}

/// Menampilkan foto lampiran layar penuh (bisa diperbesar).
Future<void> tampilkanFotoLampiran(BuildContext context, ImageProvider foto) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: Image(image: foto, fit: BoxFit.contain),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              tooltip: 'Tutup',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}
