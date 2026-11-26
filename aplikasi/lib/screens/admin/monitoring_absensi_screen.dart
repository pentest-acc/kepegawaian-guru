import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../models/jadwal_mengajar.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/pesan.dart';
import '../../widgets/chip_kehadiran.dart';
import '../../widgets/loading_dots.dart';
import '../guru/riwayat_absen_screen.dart';

/// Admin: Monitoring Absensi per tanggal.
///
/// Setiap guru yang punya jadwal di tanggal itu tampil beserta setiap mapelnya.
/// Warna penanda: hijau = hadir tepat waktu, kuning = terlambat, merah = lewat
/// jam pelajaran / belum absen padahal mapel sudah selesai, biru = izin/sakit/
/// cuti, merah tua = alpa. Ketuk sebuah mapel untuk melihat foto absen atau
/// mengubah tanda kehadirannya (mis. guru lupa absen).
class MonitoringAbsensiScreen extends StatefulWidget {
  const MonitoringAbsensiScreen({super.key, this.absenService, this.tanggal});

  final AbsenService? absenService;

  /// Tanggal awal yang ditampilkan (bawaan: hari ini menurut server).
  final DateTime? tanggal;

  @override
  State<MonitoringAbsensiScreen> createState() =>
      _MonitoringAbsensiScreenState();
}

class _MonitoringAbsensiScreenState extends State<MonitoringAbsensiScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();

  late DateTime _tanggal = _hanyaTanggal(widget.tanggal ?? DateTime.now());
  RekapHarian? _rekap;
  bool _sedangMemuat = true;
  String? _pesanGagal;
  int _nomorPermintaan = 0;

  static DateTime _hanyaTanggal(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final nomor = ++_nomorPermintaan;
    setState(() {
      _sedangMemuat = true;
      _pesanGagal = null;
    });
    try {
      final rekap = await _service.rekapHarian(_tanggal);
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _rekap = rekap;
        _sedangMemuat = false;
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  void _gantiTanggal(DateTime baru) {
    setState(() => _tanggal = _hanyaTanggal(baru));
    _muat();
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal',
    );
    if (hasil != null) _gantiTanggal(hasil);
  }

  /// Posisi tanggal yang dilihat terhadap hari ini (menurut jam server).
  HariRelatif _hariRelatif(RekapHarian rekap) {
    final hariIni = _hanyaTanggal(rekap.waktuServer);
    final dilihat = _hanyaTanggal(rekap.tanggal);
    if (dilihat.isBefore(hariIni)) return HariRelatif.lalu;
    if (dilihat.isAfter(hariIni)) return HariRelatif.depan;
    return HariRelatif.ini;
  }

  KeadaanMapel _keadaan(
    RekapHarian rekap,
    KehadiranGuru guru,
    MapelAbsen mapel,
  ) => keadaanMapelDenganCuti(
    mapel,
    guru.cuti,
    hari: _hariRelatif(rekap),
    menitSekarang: rekap.waktuServer.hour * 60 + rekap.waktuServer.minute,
  );

  void _bukaRiwayat(KehadiranGuru guru) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiwayatAbsenScreen(
          absenService: _service,
          guru: GuruRingkas(
            idPengguna: guru.idPengguna,
            nomorInduk: guru.nomorInduk,
            namaTampil: guru.namaTampil,
            unit: guru.unit,
            jabatan: 'Guru',
            status: 'aktif',
            jumlahJadwal: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _bukaDetail(KehadiranGuru guru, MapelAbsen mapel) async {
    final berubah = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _LembarKehadiran(
        service: _service,
        guru: guru,
        mapel: mapel,
        tanggal: _rekap!.tanggal,
        gaya: GayaKehadiran.dari(
          _keadaan(_rekap!, guru, mapel),
          absensi: mapel.absensi,
        ),
      ),
    );
    if (berubah == true && mounted) {
      tampilkanPesan(context, 'Kehadiran ${guru.namaTampil} disimpan.');
      _muat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Monitoring Absensi'),
      ),
      body: Column(
        children: [
          _BarisTanggal(
            tanggal: _tanggal,
            onSebelum: () =>
                _gantiTanggal(_tanggal.subtract(const Duration(days: 1))),
            onSesudah: () =>
                _gantiTanggal(_tanggal.add(const Duration(days: 1))),
            onPilih: _pilihTanggal,
          ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_sedangMemuat && _rekap == null) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }
    if (_pesanGagal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_pesanGagal!, textAlign: TextAlign.center),
        ),
      );
    }
    final rekap = _rekap!;

    // Hitung ringkasan
    final hitung = <String, int>{};
    for (final g in rekap.guru) {
      for (final m in g.mapel) {
        final k = _keadaan(rekap, g, m);
        final kelompok = switch (k) {
          KeadaanMapel.hadir => 'hadir',
          KeadaanMapel.terlambat || KeadaanMapel.lewatJam => 'terlambat',
          KeadaanMapel.izin ||
          KeadaanMapel.sakit ||
          KeadaanMapel.cuti => 'izin',
          KeadaanMapel.alpa => 'alpa',
          _ => 'belum',
        };
        hitung[kelompok] = (hitung[kelompok] ?? 0) + 1;
      }
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (rekap.libur != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Libur: ${rekap.libur}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.merah,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Ringkas('Hadir', hitung['hadir'] ?? 0, GayaKehadiran.hijau),
              _Ringkas(
                'Terlambat',
                hitung['terlambat'] ?? 0,
                GayaKehadiran.kuning,
              ),
              _Ringkas('Belum absen', hitung['belum'] ?? 0, GayaKehadiran.abu),
              _Ringkas(
                'Izin/Sakit/Cuti',
                hitung['izin'] ?? 0,
                GayaKehadiran.biru,
              ),
              _Ringkas('Alpa', hitung['alpa'] ?? 0, GayaKehadiran.merahTua),
            ],
          ),
          const SizedBox(height: 14),
          if (rekap.guru.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Tidak ada jadwal mengajar di tanggal ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.teksAbu),
              ),
            ),
          for (final guru in rekap.guru)
            _KartuGuru(
              guru: guru,
              gayaMapel: [
                for (final m in guru.mapel)
                  GayaKehadiran.dari(
                    _keadaan(rekap, guru, m),
                    absensi: m.absensi,
                  ),
              ],
              onTapMapel: (mapel) => _bukaDetail(guru, mapel),
              onRiwayat: () => _bukaRiwayat(guru),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Komponen
// ---------------------------------------------------------------------------

class _BarisTanggal extends StatelessWidget {
  const _BarisTanggal({
    required this.tanggal,
    required this.onSebelum,
    required this.onSesudah,
    required this.onPilih,
  });

  final DateTime tanggal;
  final VoidCallback onSebelum;
  final VoidCallback onSesudah;
  final VoidCallback onPilih;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Hari sebelumnya',
            onPressed: onSebelum,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPilih,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        FormatTanggal.panjang(tanggal),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teks,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hari berikutnya',
            onPressed: onSesudah,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Ringkas extends StatelessWidget {
  const _Ringkas(this.label, this.jumlah, this.warna);

  final String label;
  final int jumlah;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $jumlah',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: warna,
        ),
      ),
    );
  }
}

class _KartuGuru extends StatelessWidget {
  const _KartuGuru({
    required this.guru,
    required this.gayaMapel,
    required this.onTapMapel,
    required this.onRiwayat,
  });

  final KehadiranGuru guru;
  final List<GayaKehadiran> gayaMapel;
  final ValueChanged<MapelAbsen> onTapMapel;
  final VoidCallback onRiwayat;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 0, 0),
            child: Row(
              children: [
                Expanded(child: _namaGuru()),
                IconButton(
                  tooltip: 'Riwayat absen ${guru.namaTampil}',
                  onPressed: onRiwayat,
                  icon: const Icon(
                    Icons.manage_history_rounded,
                    color: AppColors.navyTerang,
                  ),
                ),
              ],
            ),
          ),
          if (guru.cuti != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                '${guru.cuti![0].toUpperCase()}${guru.cuti!.substring(1)} '
                '(pengajuan disetujui)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GayaKehadiran.biru,
                ),
              ),
            ),
          for (var i = 0; i < guru.mapel.length; i++)
            InkWell(
              onTap: () => onTapMapel(guru.mapel[i]),
              child: _barisMapel(i),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _namaGuru() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: guru.namaTampil,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.teks,
              ),
            ),
            TextSpan(
              text:
                  '   NIY ${guru.nomorInduk}'
                  '${guru.unit == null ? '' : ' • ${guru.unit}'}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.teksAbu),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barisMapel(int i) {
    final mapel = guru.mapel[i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: gayaMapel[i].warna,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mapel.jamTampil}  ${mapel.mataPelajaran}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teks,
                  ),
                ),
                Text(
                  'Kelas ${mapel.kelas}'
                  '${mapel.lokasi == null ? '' : ' • ${mapel.lokasi}'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.teksAbu,
                  ),
                ),
                const SizedBox(height: 4),
                ChipKehadiran(gaya: gayaMapel[i]),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.teksAbu),
        ],
      ),
    );
  }
}

/// Lembar detail satu mapel: foto absen, lokasi, dan ubah tanda kehadiran.
class _LembarKehadiran extends StatefulWidget {
  const _LembarKehadiran({
    required this.service,
    required this.guru,
    required this.mapel,
    required this.tanggal,
    required this.gaya,
  });

  final AbsenService service;
  final KehadiranGuru guru;
  final MapelAbsen mapel;
  final DateTime tanggal;
  final GayaKehadiran gaya;

  @override
  State<_LembarKehadiran> createState() => _LembarKehadiranState();
}

class _LembarKehadiranState extends State<_LembarKehadiran> {
  static const _pilihan = [
    ('hadir', 'Hadir'),
    ('terlambat', 'Terlambat'),
    ('izin', 'Izin'),
    ('sakit', 'Sakit'),
    ('cuti', 'Cuti'),
    ('alpa', 'Alpa'),
  ];

  late String? _status = widget.mapel.absensi?.status;
  late final _keteranganController = TextEditingController(
    text: widget.mapel.absensi?.keterangan,
  );
  Uint8List? _foto;
  bool _sedangMenyimpan = false;
  String? _pesanGagal;

  AbsensiMapel? get _absensi => widget.mapel.absensi;

  @override
  void initState() {
    super.initState();
    if (_absensi?.adaFoto == true) _muatFoto();
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _muatFoto() async {
    try {
      final foto = await widget.service.ambilFoto(_absensi!.idAbsensi);
      if (mounted) setState(() => _foto = foto);
    } on ApiException {
      // foto tidak wajib tampil
    }
  }

  Future<void> _simpan(String status) async {
    setState(() {
      _sedangMenyimpan = true;
      _pesanGagal = null;
    });
    try {
      await widget.service.ubahKehadiran(
        status: status,
        idAbsensi: _absensi?.idAbsensi,
        idJadwal: _absensi == null ? widget.mapel.idJadwal : null,
        tanggal: _absensi == null ? widget.tanggal : null,
        keterangan: _keteranganController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMenyimpan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final absensi = _absensi;
    final mapel = widget.mapel;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mapel.mataPelajaran,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.guru.namaTampil}\n${mapel.jamTampil} • '
              'Kelas ${mapel.kelas}'
              '${mapel.lokasi == null ? '' : ' • ${mapel.lokasi}'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.teksAbu),
            ),
            const SizedBox(height: 10),
            ChipKehadiran(gaya: widget.gaya),
            if (absensi != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (absensi.adaFoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 90,
                        height: 110,
                        child: _foto == null
                            ? const ColoredBox(
                                color: AppColors.isian,
                                child: Icon(Icons.image_rounded),
                              )
                            : Image.memory(_foto!, fit: BoxFit.cover),
                      ),
                    ),
                  if (absensi.adaFoto) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [
                        absensi.jamAbsen == null
                            ? 'Ditandai admin (tanpa absen guru)'
                            : 'Absen pukul ${jamTitik(absensi.jamAbsen!)}',
                        if (absensi.lokasi != null)
                          'Lokasi: ${absensi.lokasi}'
                              '${absensi.jarak == null ? '' : ' (${formatJarak(absensi.jarak!)})'}',
                        if (absensi.diubahAdmin) 'Pernah diubah admin',
                        if (absensi.keterangan != null)
                          'Catatan: ${absensi.keterangan}',
                      ].join('\n'),
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Ubah tanda kehadiran',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (nilai, label) in _pilihan)
                  ChoiceChip(
                    label: Text(label),
                    selected: _status == nilai,
                    onSelected: _sedangMenyimpan
                        ? null
                        : (_) => setState(() => _status = nilai),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keteranganController,
              maxLength: 255,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional), mis. lupa absen',
                counterText: '',
              ),
            ),
            if (_pesanGagal != null) ...[
              const SizedBox(height: 8),
              Text(
                _pesanGagal!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.merah),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (absensi != null && !absensi.adaFoto)
                  TextButton(
                    onPressed: _sedangMenyimpan ? null : () => _simpan('belum'),
                    child: const Text('Hapus tanda'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _status == null || _sedangMenyimpan
                      ? null
                      : () => _simpan(_status!),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(130, 44),
                  ),
                  child: Text(_sedangMenyimpan ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
