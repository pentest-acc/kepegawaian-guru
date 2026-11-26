import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/cuti.dart';
import '../../services/api_service.dart';
import '../../services/cuti_service.dart';
import '../../services/pemilih_foto.dart';
import '../../utils/pesan.dart';
import '../../widgets/gaya_cuti.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/tombol_utama.dart';

/// Form pengajuan cuti / izin / sakit.
///
/// Setelah jenis & tanggal dipilih, server menghitung jumlah hari kerja,
/// mapel yang ditinggalkan, dan sisa kuota (pratinjau), sehingga guru tahu
/// sebelum mengirim. Jika berhasil, halaman ditutup dengan pesan server.
class FormCutiScreen extends StatefulWidget {
  const FormCutiScreen({
    super.key,
    this.cutiService,
    this.pemilihFoto,
    this.hariIni,
    this.kuota,
  });

  final CutiService? cutiService;
  final PemilihFoto? pemilihFoto;

  /// Tanggal hari ini menurut server (untuk batas pilihan tanggal).
  final DateTime? hariIni;
  final KuotaCuti? kuota;

  @override
  State<FormCutiScreen> createState() => _FormCutiScreenState();
}

class _FormCutiScreenState extends State<FormCutiScreen> {
  late final CutiService _service = widget.cutiService ?? CutiService();
  late final PemilihFoto _pemilih =
      widget.pemilihFoto ?? PemilihFotoPerangkat();
  final _alasanController = TextEditingController();

  static const _maksLampiranByte = 5 * 1024 * 1024;

  JenisCuti? _jenis;
  DateTime? _mulai;
  DateTime? _selesai;
  LampiranCuti? _lampiran;

  PratinjauCuti? _pratinjau;
  String? _pesanPratinjau;
  bool _memuatPratinjau = false;
  int _nomorPratinjau = 0;

  bool _mengirim = false;
  bool _sudahCobaKirim = false;

  DateTime get _hariIni {
    final t = widget.hariIni ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  void _pilihJenis(JenisCuti jenis) {
    setState(() => _jenis = jenis);
    _muatPratinjau();
  }

  Future<void> _pilihTanggal({required bool mulai}) async {
    final awal = _jenis == JenisCuti.cuti
        ? _hariIni
        : _hariIni.subtract(const Duration(days: 7));
    final sekarang = mulai ? _mulai : (_selesai ?? _mulai);
    final dipilih = await showDatePicker(
      context: context,
      initialDate: sekarang != null && !sekarang.isBefore(awal)
          ? sekarang
          : (_hariIni.isBefore(awal) ? awal : _hariIni),
      firstDate: mulai ? awal : (_mulai ?? awal),
      lastDate: _hariIni.add(const Duration(days: 365)),
      helpText: mulai ? 'Tanggal mulai' : 'Tanggal selesai',
    );
    if (dipilih == null) return;
    setState(() {
      if (mulai) {
        _mulai = dipilih;
        if (_selesai == null || _selesai!.isBefore(dipilih)) _selesai = dipilih;
      } else {
        _selesai = dipilih;
      }
    });
    _muatPratinjau();
  }

  Future<void> _muatPratinjau() async {
    final jenis = _jenis;
    final mulai = _mulai;
    final selesai = _selesai;
    if (jenis == null || mulai == null || selesai == null) return;
    final nomor = ++_nomorPratinjau;
    setState(() {
      _memuatPratinjau = true;
      _pesanPratinjau = null;
      _pratinjau = null;
    });
    try {
      final hasil = await _service.hitung(jenis, mulai, selesai);
      if (!mounted || nomor != _nomorPratinjau) return;
      setState(() {
        _pratinjau = hasil;
        _memuatPratinjau = false;
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPratinjau) return;
      setState(() {
        _pesanPratinjau = e.pesan;
        _memuatPratinjau = false;
      });
    }
  }

  Future<void> _ambilLampiran({required bool dariKamera}) async {
    try {
      final foto = await _pemilih.ambil(dariKamera: dariKamera);
      if (foto == null || !mounted) return;
      if (foto.bytes.length > _maksLampiranByte) {
        tampilkanPesan(
          context,
          'Ukuran foto maksimal 5 MB. Pilih foto lain.',
          gagal: true,
        );
        return;
      }
      setState(() => _lampiran = foto);
    } catch (_) {
      if (!mounted) return;
      tampilkanPesan(
        context,
        dariKamera
            ? 'Kamera tidak bisa dibuka. Izinkan akses kamera atau pilih dari galeri.'
            : 'Galeri tidak bisa dibuka.',
        gagal: true,
      );
    }
  }

  String? get _kesalahanAlasan {
    final teks = _alasanController.text.trim();
    if (teks.length < 10) return 'Tuliskan alasan minimal 10 karakter.';
    return null;
  }

  bool get _lampiranKurang =>
      (_pratinjau?.wajibLampiran ?? false) && _lampiran == null;

  Future<void> _kirim() async {
    setState(() => _sudahCobaKirim = true);
    final jenis = _jenis;
    final pratinjau = _pratinjau;
    if (jenis == null || _mulai == null || _selesai == null) {
      tampilkanPesan(context, 'Pilih jenis dan tanggalnya dulu.', gagal: true);
      return;
    }
    if (pratinjau == null) {
      tampilkanPesan(
        context,
        _pesanPratinjau ?? 'Tunggu perhitungan hari selesai.',
        gagal: true,
      );
      return;
    }
    if (_kesalahanAlasan != null || _lampiranKurang) return;

    setState(() => _mengirim = true);
    try {
      final hasil = await _service.ajukan(
        jenis: jenis,
        mulai: _mulai!,
        selesai: _selesai!,
        alasan: _alasanController.text.trim(),
        lampiran: _lampiran,
      );
      if (!mounted) return;
      Navigator.of(context).pop(hasil.pesan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mengirim = false);
      tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      sedangMemuat: _mengirim,
      teks: 'Mengirim pengajuan...',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Ajukan Cuti / Izin'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const _Judul('Jenis pengajuan'),
            Row(
              children: [
                for (final j in JenisCuti.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: j == JenisCuti.values.last ? 0 : 8,
                      ),
                      child: _PilihJenis(
                        jenis: j,
                        dipilih: _jenis == j,
                        onTap: () => _pilihJenis(j),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _jenis?.keterangan ?? 'Pilih salah satu jenis di atas.',
              style: TextStyle(
                fontSize: 12,
                color: _sudahCobaKirim && _jenis == null
                    ? AppColors.merah
                    : AppColors.teksAbu,
              ),
            ),
            if (_jenis == JenisCuti.cuti && widget.kuota != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sisa kuota cuti ${widget.kuota!.tahun}: '
                  '${widget.kuota!.sisa} dari ${widget.kuota!.kuota} hari.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyTerang,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const _Judul('Tanggal'),
            Row(
              children: [
                Expanded(
                  child: _KotakTanggal(
                    key: const Key('tanggal-mulai'),
                    label: 'Mulai',
                    tanggal: _mulai,
                    onTap: () => _pilihTanggal(mulai: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KotakTanggal(
                    key: const Key('tanggal-selesai'),
                    label: 'Sampai',
                    tanggal: _selesai,
                    onTap: _mulai == null
                        ? null
                        : () => _pilihTanggal(mulai: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _bagianPratinjau(),
            const SizedBox(height: 20),
            const _Judul('Alasan'),
            TextField(
              controller: _alasanController,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_sudahCobaKirim) setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Contoh: Menghadiri pernikahan saudara di Bandung.',
                errorText: _sudahCobaKirim ? _kesalahanAlasan : null,
              ),
            ),
            const SizedBox(height: 12),
            const _Judul('Lampiran foto'),
            _bagianLampiran(),
            const SizedBox(height: 28),
            TombolUtama(
              teks: 'Kirim Pengajuan',
              ikon: Icons.send_rounded,
              onPressed: _mengirim ? null : _kirim,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagianPratinjau() {
    if (_jenis == null || _mulai == null) {
      return const Text(
        'Minggu dan hari libur tidak dihitung sebagai hari cuti.',
        style: TextStyle(fontSize: 12, color: AppColors.teksAbu),
      );
    }
    if (_memuatPratinjau) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_pesanPratinjau != null) {
      return _KotakInfo(
        warna: AppColors.merah,
        ikon: Icons.error_outline_rounded,
        child: Text(
          _pesanPratinjau!,
          style: const TextStyle(fontSize: 12.5, color: AppColors.merah),
        ),
      );
    }
    final p = _pratinjau;
    if (p == null) return const SizedBox.shrink();

    final sisa = p.sisaSetelahCuti;
    return _KotakInfo(
      warna: AppColors.navyTerang,
      ikon: Icons.event_note_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.jumlahHari} hari kerja',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
            ),
          ),
          Text(
            p.jumlahMapel == 0
                ? 'Tidak ada mapel yang ditinggalkan.'
                : '${p.jumlahMapel} mapel yang ditinggalkan:',
            style: const TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
          ),
          for (final h in p.hari)
            if (h.mapel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMM', 'id_ID').format(h.tanggal),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyTerang,
                      ),
                    ),
                    for (final m in h.mapel)
                      Text(
                        '${m.jamTampil}  ${m.mataPelajaran} '
                        '(${m.unit} ${m.kelas})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.teks,
                        ),
                      ),
                  ],
                ),
              ),
          if (sisa != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sisa kuota cuti jika disetujui: $sisa dari '
                '${p.kuota!.kuota} hari.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.hijau,
                ),
              ),
            ),
          if (p.wajibLampiran)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sakit 2 hari atau lebih wajib melampirkan foto surat dokter.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.merah,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bagianLampiran() {
    final lampiran = _lampiran;
    final wajib = _pratinjau?.wajibLampiran ?? false;
    final keterangan = Text(
      wajib
          ? 'Wajib: foto surat dokter.'
          : 'Opsional, mis. foto surat dokter atau surat undangan '
                '(JPG/PNG, maks. 5 MB).',
      style: TextStyle(
        fontSize: 12,
        color: _sudahCobaKirim && _lampiranKurang
            ? AppColors.merah
            : AppColors.teksAbu,
      ),
    );

    if (lampiran == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _ambilLampiran(dariKamera: true),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Kamera'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _ambilLampiran(dariKamera: false),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          keterangan,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.garis),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                tampilkanFotoLampiran(context, MemoryImage(lampiran.bytes)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                lampiran.bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lampiran.namaFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(lampiran.bytes.length / 1024).ceil()} KB',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.teksAbu,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus lampiran',
            onPressed: () => setState(() => _lampiran = null),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.teks,
        ),
      ),
    );
  }
}

class _PilihJenis extends StatelessWidget {
  const _PilihJenis({
    required this.jenis,
    required this.dipilih,
    required this.onTap,
  });

  final JenisCuti jenis;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dipilih ? jenis.warna.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('jenis-${jenis.kode}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dipilih ? jenis.warna : AppColors.garis,
              width: dipilih ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(jenis.ikon, color: jenis.warna, size: 26),
              const SizedBox(height: 4),
              Text(
                jenis.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dipilih ? jenis.warna : AppColors.teks,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KotakTanggal extends StatelessWidget {
  const _KotakTanggal({
    super.key,
    required this.label,
    required this.tanggal,
    required this.onTap,
  });

  final String label;
  final DateTime? tanggal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.isian,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: onTap == null ? AppColors.teksAbu : AppColors.navyTerang,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.teksAbu,
                      ),
                    ),
                    // Satu baris; diperkecil sedikit jika layar sempit
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tanggal == null
                            ? 'Pilih tanggal'
                            : DateFormat(
                                'EEE, d MMM yyyy',
                                'id_ID',
                              ).format(tanggal!),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tanggal == null
                              ? AppColors.teksAbu
                              : AppColors.teks,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KotakInfo extends StatelessWidget {
  const _KotakInfo({
    required this.warna,
    required this.ikon,
    required this.child,
  });

  final Color warna;
  final IconData ikon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: warna),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
