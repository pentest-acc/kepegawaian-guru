import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Kolom isian dengan label di atasnya. Untuk kata sandi, set
/// [kataSandi] = true agar muncul tombol lihat/sembunyikan.
class InputField extends StatefulWidget {
  const InputField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.ikon,
    this.kataSandi = false,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? ikon;
  final bool kataSandi;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late bool _tersembunyi = widget.kataSandi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelIsian(widget.label),
        TextFormField(
          controller: widget.controller,
          obscureText: _tersembunyi,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 14, color: AppColors.teks),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.ikon == null ? null : Icon(widget.ikon),
            suffixIcon: widget.kataSandi
                ? IconButton(
                    tooltip: _tersembunyi
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    icon: Icon(
                      _tersembunyi
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _tersembunyi = !_tersembunyi),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Label kecil di atas kolom isian.
class LabelIsian extends StatelessWidget {
  const LabelIsian(this.teks, {super.key});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.teks,
        ),
      ),
    );
  }
}
