import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../models/jadwal_mengajar.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/jadwal_service.dart';
import '../../utils/hari.dart';
import '../../widgets/input_field.dart';
import '../../widgets/kotak_jam.dart';
import '../../widgets/tombol_utama.dart';

/// Admin: form tambah / ubah satu jadwal mengajar.
/// Mengembalikan [JadwalMengajar] yang tersimpan saat berhasil.
class FormJadwalScreen extends StatefulWidget {
  const FormJadwalScreen({
    super.key,
    required this.guru,
    this.jadwal,
    this.hariAwal,
    this.jadwalService,
    this.absenService,
  });

  final GuruRingkas guru;

  /// Diisi jika mengubah jadwal yang sudah ada.
  final JadwalMengajar? jadwal;

  /// Hari yang langsung terpilih saat menambah jadwal baru.
  final String? hariAwal;
  final JadwalService? jadwalService;

  /// Untuk mengambil daftar gedung/lokasi absen.
  final AbsenService? absenService;

  @override
  State<FormJadwalScreen> createState() => _FormJadwalScreenState();
}

class _FormJadwalScreenState extends State<FormJadwalScreen> {
  late final JadwalService _service = widget.jadwalService ?? JadwalService();
  late final AbsenService _absen = widget.absenService ?? AbsenService();

  /// Gedung tempat mengajar (null = belum ditentukan).
  late int? _idLokasi = widget.jadwal?.idLokasi;
  List<LokasiAbsen> _daftarLokasi = const [];
  bool _memuatLokasi = true;
  final _formKey = GlobalKey<FormState>();

  late String _hari = widget.jadwal?.hari ?? widget.hariAwal ?? 'Senin';
  late String _unit = widget.jadwal?.unit ?? widget.guru.unit ?? 'SD';
  late TimeOfDay? _mulai = _keJam(widget.jadwal?.jamMulai);
  late TimeOfDay? _selesai = _keJam(widget.jadwal?.jamSelesai);
  late final _kelasController = TextEditingController(
    text: widget.jadwal?.kelas,
  );
  late final _mapelController = TextEditingController(
    text: widget.jadwal?.mataPelajaran,
  );

  bool _sedangMenyimpan = false;
  String? _pesanGagal;
  bool _sudahCobaSimpan = false;

  bool get _modeUbah => widget.jadwal != null;

  static TimeOfDay? _keJam(String? teks) {
    if (teks == null) return null;
    final bagian = teks.split(':');
    return TimeOfDay(hour: int.parse(bagian[0]), minute: int.parse(bagian[1]));
  }

  static String _keTeks(TimeOfDay jam) =>
      '${jam.hour.toString().padLeft(2, '0')}:'
      '${jam.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _muatLokasi();
  }

  Future<void> _muatLokasi() async {
    try {
      final daftar = await _absen.daftarLokasi();
      if (!mounted) return;
      setState(() {
        _daftarLokasi = daftar;
        _memuatLokasi = false;
        // Lokasi lama yang sudah dihapus dianggap belum ditentukan
        if (!daftar.any((l) => l.idLokasi == _idLokasi)) _idLokasi = null;
      });
    } on ApiException {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  @override
  void dispose() {
    _kelasController.dispose();
    _mapelController.dispose();
    super.dispose();
  }

  Future<void> _pilihJam({required bool mulai}) async {
    final awal = mulai
        ? (_mulai ?? const TimeOfDay(hour: 7, minute: 30))
        : (_selesai ??
              (_mulai == null
                  ? const TimeOfDay(hour: 8, minute: 40)
                  : TimeOfDay(
                      hour: (_mulai!.hour + 1) % 24,
                      minute: _mulai!.minute,
                    )));
    final hasil = await showTimePicker(
      context: context,
      initialTime: awal,
      helpText: mulai ? 'Jam mulai' : 'Jam selesai',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hasil == null) return;
    setState(() => mulai ? _mulai = hasil : _selesai = hasil);
  }

  String? get _kesalahanJam {
    if (_mulai == null || _selesai == null) return 'Pilih jam mulai & selesai.';
    final m = _mulai!.hour * 60 + _mulai!.minute;
    final s = _selesai!.hour * 60 + _selesai!.minute;
    if (s <= m) return 'Jam selesai harus setelah jam mulai.';
    return null;
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() => _sudahCobaSimpan = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _kesalahanJam != null) return;

    setState(() {
      _sedangMenyimpan = true;
      _pesanGagal = null;
    });
    try {
      final tersimpan = await _service.simpan(
        JadwalMengajar(
          idJadwal: widget.jadwal?.idJadwal,
          idPengguna: widget.guru.idPengguna,
          hari: _hari,
          jamMulai: _keTeks(_mulai!),
          jamSelesai: _keTeks(_selesai!),
          unit: _unit,
          kelas: _kelasController.text.trim(),
          mataPelajaran: _mapelController.text.trim(),
          idLokasi: _idLokasi,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(tersimpan);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Pesan bentrok jadwal ditampilkan jelas di atas form
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMenyimpan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kesalahanJam = _sudahCobaSimpan ? _kesalahanJam : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_modeUbah ? 'Ubah Jadwal' : 'Tambah Jadwal'),
      ),
      // SingleChildScrollView (bukan ListView) supaya semua kolom selalu
      // terpasang dan ikut divalidasi walaupun sedang tidak terlihat di layar.
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.guru.namaTampil,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'NIY ${widget.guru.nomorInduk}',
                style: const TextStyle(fontSize: 12, color: AppColors.teksAbu),
              ),
              if (_pesanGagal != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('pesan-gagal-jadwal'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.merah.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.merah.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        color: AppColors.merah,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pesanGagal!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.merah,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const LabelIsian('Hari'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hari in Hari.sekolah)
                    ChoiceChip(
                      label: Text(hari),
                      selected: _hari == hari,
                      onSelected: (_) => setState(() => _hari = hari),
                      selectedColor: AppColors.biru,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: KotakJam(
                      label: 'Jam mulai',
                      jam: _mulai,
                      onTap: () => _pilihJam(mulai: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KotakJam(
                      label: 'Jam selesai',
                      jam: _selesai,
                      onTap: () => _pilihJam(mulai: false),
                    ),
                  ),
                ],
              ),
              if (kesalahanJam != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    kesalahanJam,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.merah,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const LabelIsian('Unit'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'KB', label: Text('KB')),
                  ButtonSegment(value: 'TK', label: Text('TK')),
                  ButtonSegment(value: 'SD', label: Text('SD')),
                ],
                selected: {_unit},
                showSelectedIcon: false,
                onSelectionChanged: (pilihan) =>
                    setState(() => _unit = pilihan.first),
              ),
              const SizedBox(height: 18),
              const LabelIsian('Gedung / lokasi mengajar'),
              DropdownButtonFormField<int?>(
                key: const Key('pilih-gedung'),
                initialValue: _idLokasi,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.apartment_rounded),
                  helperMaxLines: 2,
                  helperText: _memuatLokasi
                      ? 'Memuat daftar gedung...'
                      : _daftarLokasi.isEmpty
                      ? 'Belum ada lokasi. Tambahkan di menu Lokasi Absen.'
                      : 'Agar guru tahu harus mengajar di gedung mana.',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Belum ditentukan'),
                  ),
                  for (final lokasi in _daftarLokasi)
                    DropdownMenuItem<int?>(
                      value: lokasi.idLokasi,
                      child: Text(
                        '${lokasi.namaLengkap}'
                        '${lokasi.aktif ? '' : ' (nonaktif)'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (nilai) => setState(() => _idLokasi = nilai),
              ),
              const SizedBox(height: 18),
              InputField(
                label: 'Kelas',
                hint: 'contoh: 3B atau TK A',
                controller: _kelasController,
                ikon: Icons.meeting_room_outlined,
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  final teks = v?.trim() ?? '';
                  if (teks.isEmpty) return 'Kelas wajib diisi.';
                  if (!RegExp(r'^[0-9A-Za-z .\-]{1,20}$').hasMatch(teks)) {
                    return 'Kelas 1-20 karakter (huruf/angka).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InputField(
                label: 'Mata Pelajaran / Kegiatan',
                hint: 'contoh: Bahasa Indonesia',
                controller: _mapelController,
                ikon: Icons.menu_book_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final teks = v?.trim() ?? '';
                  if (teks.length < 2) return 'Mata pelajaran wajib diisi.';
                  if (teks.length > 100) return 'Maksimal 100 karakter.';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              TombolUtama(
                teks: _modeUbah ? 'Simpan Perubahan' : 'Simpan Jadwal',
                ikon: Icons.save_rounded,
                sedangMemuat: _sedangMenyimpan,
                onPressed: _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
