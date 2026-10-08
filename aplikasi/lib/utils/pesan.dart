import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Menampilkan pesan singkat (snackbar) di bagian bawah layar.
void tampilkanPesan(BuildContext context, String pesan, {bool gagal = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: gagal ? AppColors.merah : AppColors.navy,
      content: Row(
        children: [
          Icon(
            gagal ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(pesan)),
        ],
      ),
    ),
  );
}
