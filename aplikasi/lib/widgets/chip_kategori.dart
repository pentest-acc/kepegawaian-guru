import 'package:flutter/material.dart';

/// Label kecil berwarna untuk kategori info kegiatan.
class ChipKategori extends StatelessWidget {
  const ChipKategori(this.kategori, {super.key});

  final String kategori;

  static const Map<String, (Color, IconData)> _gaya = {
    'Pengumuman': (Color(0xFF2B7BC4), Icons.campaign_rounded),
    'Rapat': (Color(0xFF6C5CE7), Icons.groups_rounded),
    'Acara': (Color(0xFF2E9E80), Icons.celebration_rounded),
    'Libur': (Color(0xFFE5484D), Icons.beach_access_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) =
        _gaya[kategori] ??
        (const Color(0xFF6B7280), Icons.info_outline_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 15, color: warna),
          const SizedBox(width: 5),
          Text(
            kategori,
            style: TextStyle(
              color: warna,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
