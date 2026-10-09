import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/pesan.dart';
import '../../utils/validator.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/logo_yayasan.dart';
import '../../widgets/tombol_utama.dart';

/// Halaman login untuk Guru dan Admin.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.identitasAwal, this.authService});

  /// Diisi otomatis setelah registrasi berhasil.
  final String? identitasAwal;
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _identitasController = TextEditingController(
    text: widget.identitasAwal,
  );
  final _sandiController = TextEditingController();
  late final AuthService _auth = widget.authService ?? AuthService();

  bool _sedangMemuat = false;

  @override
  void dispose() {
    _identitasController.dispose();
    _sandiController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMemuat = true);
    try {
      final pengguna = await _auth.login(
        _identitasController.text,
        _sandiController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.halamanUtama(pengguna),
        (route) => false,
        arguments: pengguna,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sedangMemuat = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  Future<void> _bukaRegister() async {
    final emailBaru = await Navigator.of(
      context,
    ).pushNamed<String>(AppRoutes.register);

    if (emailBaru != null && mounted) {
      _identitasController.text = emailBaru;
      _sandiController.clear();
      tampilkanPesan(context, 'Akun berhasil dibuat. Silakan masuk.');
    }
  }

  void _lupaSandi() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.lock_reset_rounded,
          color: AppColors.biru,
          size: 40,
        ),
        title: const Text('Lupa Kata Sandi?'),
        content: const Text(
          'Silakan hubungi Admin Yayasan untuk mengatur ulang kata sandi '
          'akun Anda.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: LoadingOverlay(
        sedangMemuat: _sedangMemuat,
        teks: 'Sedang masuk...',
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              children: [
                const _HeaderLogin(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: _formLogin(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formLogin() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masuk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.teks,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Silakan masuk menggunakan akun yang terdaftar.',
              style: TextStyle(fontSize: 13, color: AppColors.teksAbu),
            ),
            const SizedBox(height: 24),
            InputField(
              label: 'Email / Nomor Induk Yayasan',
              hint: 'contoh: guru@email.com',
              controller: _identitasController,
              ikon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              validator: (v) => Validator.wajib(v, 'Email / Nomor Induk'),
            ),
            const SizedBox(height: 16),
            InputField(
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              controller: _sandiController,
              ikon: Icons.lock_outline_rounded,
              kataSandi: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: (v) => Validator.wajib(v, 'Kata sandi'),
              onSubmitted: (_) => _login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _lupaSandi,
                child: const Text('Lupa kata sandi?'),
              ),
            ),
            const SizedBox(height: 8),
            TombolUtama(
              teks: 'Masuk',
              ikon: Icons.login_rounded,
              sedangMemuat: _sedangMemuat,
              onPressed: _login,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Belum punya akun?',
                  style: TextStyle(fontSize: 13, color: AppColors.teksAbu),
                ),
                TextButton(
                  onPressed: _bukaRegister,
                  child: const Text('Daftar di sini'),
                ),
              ],
            ),
            if (kDebugMode) const _InfoAkunDemo(),
          ],
        ),
      ),
    );
  }
}

/// Header halaman login: foto bersama Yayasan dengan filter navy,
/// logo, dan ucapan selamat datang.
class _HeaderLogin extends StatelessWidget {
  const _HeaderLogin();

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/header_sekolah.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.2),
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: AppColors.navy),
            ),
          ),
          // Filter navy: foto tetap terlihat, tulisan putih tetap terbaca
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6140B2D), Color(0xB32A1B5C)],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, atas + 36, 24, 36),
            child: Column(
              children: [
                const LogoYayasan(ukuran: 84),
                const SizedBox(height: 16),
                const Text(
                  'Selamat Datang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistem Informasi Kepegawaian Guru\nYayasan Tiara Harapan Jaya',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info akun demo, hanya muncul saat mode debug (tidak ada di APK rilis).
class _InfoAkunDemo extends StatelessWidget {
  const _InfoAkunDemo();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Akun demo (mode debug):\n'
        'Guru  : 12345678910 / guru123\n'
        'Admin : ADM001 / admin123',
        style: TextStyle(fontSize: 12, color: AppColors.teks, height: 1.5),
      ),
    );
  }
}
