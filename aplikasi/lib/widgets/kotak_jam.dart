import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import 'input_field.dart';

/// Kotak pilih jam (mis. "07.30"), membuka pemilih jam saat ditekan.
class KotakJam extends StatelessWidget {
  const KotakJam({
    super.key,
    required this.label,
    required this.jam,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? jam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final teks = jam == null
        ? '--.--'
        : '${jam!.hour.toString().padLeft(2, '0')}.'
              '${jam!.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelIsian(label),
        Material(
          color: AppColors.isian,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.teksAbu),
                  const SizedBox(width: 10),
                  Text(
                    teks,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: jam == null ? AppColors.teksAbu : AppColors.teks,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
