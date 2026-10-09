import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/daftar_gelar.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/pesan.dart';
import '../../utils/validator.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/tombol_utama.dart';

/// Halaman pendaftaran akun Guru.
///
/// Jika berhasil, halaman ini ditutup dan mengembalikan email yang
/// didaftarkan ke halaman Login.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _nomorIndukController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();
  final _sandiController = TextEditingController();
  final _konfirmasiController = TextEditingController();
  late final AuthService _auth = widget.authService ?? AuthService();

  String? _gelar;
  String? _unit;
  String? _jenisKelamin;
  bool _sedangMemuat = false;

  static const Map<String, String> _pilihanUnit = {
    'KB': 'KB - Kelompok Bermain',
    'TK': 'TK - Taman Kanak-kanak',
    'SD': 'SD - Sekolah Dasar',
  };

  static const Map<String, String> _pilihanJenisKelamin = {
    'L': 'Laki-laki',
    'P': 'Perempuan',
  };

  @override
  void dispose() {
    _namaController.dispose();
    _nomorIndukController.dispose();
    _emailController.dispose();
    _noHpController.dispose();
    _sandiController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      tampilkanPesan(
        context,
        'Periksa kembali isian yang berwarna merah.',
        gagal: true,
      );
      return;
    }

    setState(() => _sedangMemuat = true);
    try {
      final pesan = await _auth.register(
        namaLengkap: _namaController.text,
        gelar: _gelar!,
        nomorInduk: _nomorIndukController.text,
        email: _emailController.text,
        noHp: _noHpController.text,
        unit: _unit!,
        jenisKelamin: _jenisKelamin!,
        password: _sandiController.text,
        konfirmasiPassword: _konfirmasiController.text,
      );
      if (!mounted) return;
      setState(() => _sedangMemuat = false);
      await _tampilkanBerhasil(pesan);
      if (!mounted) return;
      Navigator.of(context).pop(_emailController.text.trim().toLowerCase());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sedangMemuat = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  Future<void> _tampilkanBerhasil(String pesan) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.hijau,
            size: 40,
          ),
        ),
        title: const Text('Registrasi Berhasil'),
        content: Text(pesan, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(180, 46)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ke Halaman Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      sedangMemuat: _sedangMemuat,
      teks: 'Sedang mendaftarkan...',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Daftar Akun Guru')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kartuInfo(),
                const SizedBox(height: 24),
                InputField(
                  label: 'Nama Lengkap (tanpa gelar)',
                  hint: 'contoh: Siti Aminah',
                  controller: _namaController,
                  ikon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: Validator.namaLengkap,
                ),
                const SizedBox(height: 16),
                _pilihan(
                  label: 'Gelar',
                  hint: 'Pilih gelar',
                  ikon: Icons.workspace_premium_outlined,
                  pilihan: DaftarGelar.pilihan,
                  nilai: _gelar,
                  onChanged: (v) => setState(() => _gelar = v),
                  pesanWajib:
                      'Pilih gelar (pilih "Tanpa gelar" jika tidak ada).',
                ),
                const SizedBox(height: 16),
                InputField(
                  label: 'Nomor Induk Yayasan (NIY)',
                  hint: 'contoh: 12345678910',
                  controller: _nomorIndukController,
                  ikon: Icons.numbers_rounded,
                  validator: Validator.nomorInduk,
                ),
                const SizedBox(height: 16),
                InputField(
                  label: 'Email',
                  hint: 'contoh: guru@email.com',
                  controller: _emailController,
                  ikon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validator.email,
                ),
                const SizedBox(height: 16),
                InputField(
                  label: 'Nomor HP / WhatsApp',
                  hint: 'contoh: 081234567890',
                  controller: _noHpController,
                  ikon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validator.noHp,
                ),
                const SizedBox(height: 16),
                _pilihan(
                  label: 'Unit Tempat Mengajar',
                  hint: 'Pilih unit',
                  ikon: Icons.apartment_rounded,
                  pilihan: _pilihanUnit,
                  nilai: _unit,
                  onChanged: (v) => setState(() => _unit = v),
                  pesanWajib: 'Pilih unit tempat mengajar.',
                ),
                const SizedBox(height: 16),
                _pilihan(
                  label: 'Jenis Kelamin',
                  hint: 'Pilih jenis kelamin',
                  ikon: Icons.wc_rounded,
                  pilihan: _pilihanJenisKelamin,
                  nilai: _jenisKelamin,
                  onChanged: (v) => setState(() => _jenisKelamin = v),
                  pesanWajib: 'Pilih jenis kelamin.',
                ),
                const SizedBox(height: 16),
                InputField(
                  label: 'Kata Sandi',
                  hint: 'Minimal 6 karakter',
                  controller: _sandiController,
                  ikon: Icons.lock_outline_rounded,
                  kataSandi: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validator.kataSandi,
                ),
                const SizedBox(height: 16),
                InputField(
                  label: 'Konfirmasi Kata Sandi',
                  hint: 'Ulangi kata sandi',
                  controller: _konfirmasiController,
                  ikon: Icons.lock_person_outlined,
                  kataSandi: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validator.konfirmasiKataSandi(v, _sandiController.text),
                  onSubmitted: (_) => _daftar(),
                ),
                const SizedBox(height: 28),
                TombolUtama(
                  teks: 'Daftar Sekarang',
                  ikon: Icons.person_add_alt_1_rounded,
                  sedangMemuat: _sedangMemuat,
                  onPressed: _daftar,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun?',
                      style: TextStyle(fontSize: 13, color: AppColors.teksAbu),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Masuk'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.biru.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.biru.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF2B7BC4)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Isi data sesuai identitas Anda di Yayasan. Nomor Induk '
              'Yayasan dan email dapat dipakai untuk login.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.teks,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pilihan({
    required String label,
    required String hint,
    required IconData ikon,
    required Map<String, String> pilihan,
    required String? nilai,
    required ValueChanged<String?> onChanged,
    required String pesanWajib,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelIsian(label),
        DropdownButtonFormField<String>(
          initialValue: nilai,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.teks,
          ),
          hint: Text(
            hint,
            style: const TextStyle(color: AppColors.teksAbu, fontSize: 14),
          ),
          decoration: InputDecoration(prefixIcon: Icon(ikon)),
          items: pilihan.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? pesanWajib : null,
        ),
      ],
    );
  }
}
