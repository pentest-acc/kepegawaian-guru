import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/info_kegiatan.dart';
import 'pesan.dart';

/// Membuka file lampiran di browser / aplikasi PDF bawaan HP,
/// sehingga guru bisa melihat atau mengunduhnya.
Future<void> bukaLampiran(BuildContext context, LampiranInfo lampiran) async {
  var berhasil = false;
  try {
    berhasil = await launchUrl(
      Uri.parse(lampiran.url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    berhasil = false;
  }

  if (!berhasil && context.mounted) {
    tampilkanPesan(
      context,
      'Lampiran tidak dapat dibuka. Periksa koneksi ke server.',
      gagal: true,
    );
  }
}
