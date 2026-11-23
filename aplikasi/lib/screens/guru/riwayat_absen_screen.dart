import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/tahun_ajaran.dart';
import '../../widgets/chip_kehadiran.dart';

/// Warna & label sebuah tanggal di kalender Riwayat Absen.
class GayaHari {
  const GayaHari(this.label, this.latar, this.teks);

  final String label;
  final Color latar;
  final Color teks;

  static const hadir = GayaHari('Hadir', AppColors.mint, Color(0xFF1C6B3F));
  static const sebagian = GayaHari(
    'Sebagian mapel',
    Color(0xFFFDE68A),
    Color(0xFF8A4B08),
  );
  static const izin = GayaHari(
    'Izin / Sakit / Cuti',
    Color(0xFFFCA5A5),
    Color(0xFF9B1C1C),
  );
  static const tidakHadir = GayaHari(
    'Tidak absen',
    Color(0xFFCBD5E1),
    Color(0xFF334155),
  );
  static const polos = GayaHari('', Colors.white, AppColors.teks);

  static GayaHari dari(KeadaanHari keadaan) {
    switch (keadaan) {
      case KeadaanHari.hadir:
        return hadir;
      case KeadaanHari.sebagian:
        return sebagian;
      case KeadaanHari.izinSakitCuti:
        return izin;
      case KeadaanHari.tidakHadir:
        return tidakHadir;
      case KeadaanHari.kosong:
      case KeadaanHari.libur:
      case KeadaanHari.menunggu:
        return polos;
    }
  }
}

/// Halaman Riwayat Absen guru: kalender setiap bulan dalam satu tahun
/// ajaran (Semester Ganjil Juli-Desember, Semester Genap Januari-Juni).
/// Tanggal yang sudah diabsen berwarna hijau, izin/sakit/cuti merah.
class RiwayatAbsenScreen extends StatefulWidget {
  const RiwayatAbsenScreen({super.key, this.absenService, this.sekarang});

  final AbsenService? absenService;

  /// Sumber waktu "sekarang" sebelum data server didapat (untuk pengujian).
  final DateTime Function()? sekarang;

  @override
  State<RiwayatAbsenScreen> createState() => _RiwayatAbsenScreenState();
}

class _RiwayatAbsenScreenState extends State<RiwayatAbsenScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();

  /// Data yang sudah dimuat, per bulan ("2026-11").
  final Map<String, RiwayatBulan> _cache = {};

  /// Tanggal 1 bulan yang sedang ditampilkan.
  late DateTime _bulan;
  DateTime? _dipilih;

  /// Dari server: tanggal hari ini & tanggal awal riwayat guru.
  DateTime? _hariIniServer;
  DateTime? _mulai;

  bool _memuat = false;
  String? _pesanGagal;
  int _nomorPermintaan = 0;

  static String _kunci(DateTime b) => '${b.year}-${b.month}';

  RiwayatBulan? get _data => _cache[_kunci(_bulan)];

  DateTime get _hariIni {
    final t = _hariIniServer ?? (widget.sekarang ?? DateTime.now)();
    return DateTime(t.year, t.month, t.day);
  }

  /// Tahun ajaran yang bisa dipilih: sejak riwayat guru dimulai.
  List<TahunAjaran> get _daftarTahunAjaran =>
      TahunAjaran.rentang(_mulai ?? _hariIni, _hariIni);

  DateTime get _bulanAwal => _daftarTahunAjaran.last.bulanPertama;
  DateTime get _bulanAkhir => TahunAjaran.dari(_hariIni).bulanTerakhir;

  bool get _bisaMundur => _bulan.isAfter(_bulanAwal);
  bool get _bisaMaju => _bulan.isBefore(_bulanAkhir);

  static bool _bulanSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  @override
  void initState() {
    super.initState();
    final hariIni = _hariIni;
    _bulan = DateTime(hariIni.year, hariIni.month);
    _dipilih = hariIni;
    _muat();
  }

  Future<void> _muat({bool paksa = false}) async {
    final bulan = _bulan;
    if (!paksa && _cache.containsKey(_kunci(bulan))) {
      // Data bulan ini sudah ada; abaikan permintaan bulan lain yang
      // mungkin masih berjalan.
      _nomorPermintaan++;
      setState(() {
        _pesanGagal = null;
        _memuat = false;
      });
      return;
    }
    final nomor = ++_nomorPermintaan;
    setState(() {
      _memuat = true;
      _pesanGagal = null;
    });
    try {
      final data = await _service.riwayat(bulan);
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _cache[_kunci(bulan)] = data;
        _hariIniServer = data.hariIni;
        _mulai = data.mulai;
        _memuat = false;
        if (_dipilih != null && _bulanSama(_bulan, data.hariIni)) {
          _dipilih = data.hariIni;
        }
      });
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _memuat = false;
        _pesanGagal = e.tidakAdaKoneksi
            ? 'Riwayat absen belum bisa dimuat. Periksa koneksi internet.'
            : e.pesan;
      });
    }
  }

  void _pindahBulan(DateTime bulan) {
    final tujuan = DateTime(bulan.year, bulan.month);
    if (tujuan.isBefore(_bulanAwal) || tujuan.isAfter(_bulanAkhir)) return;
    if (_bulanSama(tujuan, _bulan) && _data != null) return;
    setState(() {
      _bulan = tujuan;
      _dipilih = _bulanSama(tujuan, _hariIni) ? _hariIni : null;
    });
    _muat();
  }

  void _pilihTahunAjaran(TahunAjaran ta) {
    final sekarang = TahunAjaran.dari(_hariIni);
    _pindahBulan(ta == sekarang ? _hariIni : ta.bulanPertama);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.putih,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Riwayat Absen'),
        actions: [
          IconButton(
            tooltip: 'Bulan ini',
            icon: const Icon(Icons.today_rounded),
            onPressed: () => _pindahBulan(_hariIni),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _muat(paksa: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _PilihBulan(
              tahunAjaran: TahunAjaran.dari(_bulan),
              daftarTahunAjaran: _daftarTahunAjaran,
              bulan: _bulan,
              hariIni: _hariIni,
              onPilihBulan: _pindahBulan,
              onPilihTahunAjaran: _pilihTahunAjaran,
            ),
            const SizedBox(height: 12),
            _Kalender(
              bulan: _bulan,
              data: data,
              hariIni: _hariIni,
              dipilih: _dipilih,
              memuat: _memuat,
              onPilih: (t) => setState(() => _dipilih = t),
              onMundur: _bisaMundur
                  ? () => _pindahBulan(DateTime(_bulan.year, _bulan.month - 1))
                  : null,
              onMaju: _bisaMaju
                  ? () => _pindahBulan(DateTime(_bulan.year, _bulan.month + 1))
                  : null,
            ),
            const SizedBox(height: 10),
            const _Keterangan(),
            const SizedBox(height: 16),
            if (_pesanGagal != null)
              _KotakGagal(pesan: _pesanGagal!, onCobaLagi: _muat)
            else if (data != null) ...[
              _DetailTanggal(
                tanggal: _dipilih,
                hari: _dipilih == null ? null : data.padaTanggal(_dipilih!),
                hariIni: _hariIni,
                menitSekarang: data.menitSekarang,
              ),
              const SizedBox(height: 16),
              _RekapBulan(data: data, hariIni: _hariIni),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Pilihan tahun ajaran & bulan (Semester Ganjil / Genap)
// ------------------------------------------------------------------------

class _PilihBulan extends StatelessWidget {
  const _PilihBulan({
    required this.tahunAjaran,
    required this.daftarTahunAjaran,
    required this.bulan,
    required this.hariIni,
    required this.onPilihBulan,
    required this.onPilihTahunAjaran,
  });

  final TahunAjaran tahunAjaran;
  final List<TahunAjaran> daftarTahunAjaran;
  final DateTime bulan;
  final DateTime hariIni;
  final ValueChanged<DateTime> onPilihBulan;
  final ValueChanged<TahunAjaran> onPilihTahunAjaran;

  @override
  Widget build(BuildContext context) {
    final daftarBulan = tahunAjaran.daftarBulan;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_rounded,
                size: 20,
                color: AppColors.navyTerang,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tahun Ajaran ${tahunAjaran.label}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teks,
                  ),
                ),
              ),
              if (daftarTahunAjaran.length > 1)
                PopupMenuButton<TahunAjaran>(
                  tooltip: 'Pilih tahun ajaran',
                  onSelected: onPilihTahunAjaran,
                  itemBuilder: (_) => [
                    for (final ta in daftarTahunAjaran)
                      PopupMenuItem(
                        value: ta,
                        child: Text('Tahun Ajaran ${ta.label}'),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ganti',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navyTerang,
                          ),
                        ),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.navyTerang,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _barisSemester('Ganjil', daftarBulan.sublist(0, 6)),
          const SizedBox(height: 6),
          _barisSemester('Genap', daftarBulan.sublist(6)),
        ],
      ),
    );
  }

  Widget _barisSemester(String semester, List<DateTime> daftar) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            semester,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.teksAbu,
            ),
          ),
        ),
        for (final b in daftar)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _ChipBulan(
                bulan: b,
                dipilih: b.year == bulan.year && b.month == bulan.month,
                bulanIni: b.year == hariIni.year && b.month == hariIni.month,
                onTap: () => onPilihBulan(b),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipBulan extends StatelessWidget {
  const _ChipBulan({
    required this.bulan,
    required this.dipilih,
    required this.bulanIni,
    required this.onTap,
  });

  final DateTime bulan;
  final bool dipilih;
  final bool bulanIni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nama = DateFormat('MMM', 'id_ID').format(bulan);
    return Material(
      color: dipilih ? AppColors.navy : AppColors.isian,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('bulan-${DateFormat('yyyy-MM').format(bulan)}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: bulanIni && !dipilih
                ? Border.all(color: AppColors.biru, width: 1.5)
                : null,
          ),
          child: Text(
            nama,
            style: TextStyle(
              fontSize: 12,
              fontWeight: dipilih || bulanIni
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: dipilih ? Colors.white : AppColors.teks,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Kalender satu bulan
// ------------------------------------------------------------------------

class _Kalender extends StatelessWidget {
  const _Kalender({
    required this.bulan,
    required this.data,
    required this.hariIni,
    required this.dipilih,
    required this.memuat,
    required this.onPilih,
    this.onMundur,
    this.onMaju,
  });

  final DateTime bulan;
  final RiwayatBulan? data;
  final DateTime hariIni;
  final DateTime? dipilih;
  final bool memuat;
  final ValueChanged<DateTime> onPilih;
  final VoidCallback? onMundur;
  final VoidCallback? onMaju;

  static const _namaHari = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];

  @override
  Widget build(BuildContext context) {
    final pertama = DateTime(bulan.year, bulan.month);
    final jumlahHari = DateTime(bulan.year, bulan.month + 1, 0).day;
    final geser = pertama.weekday % 7; // Minggu = kolom pertama
    final jumlahMinggu = ((geser + jumlahHari) / 7).ceil();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: onMundur,
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(bulan),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Semester ${TahunAjaran.semester(bulan)} • '
                        'TA ${TahunAjaran.dari(bulan).label}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  onPressed: onMaju,
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: memuat
                ? const LinearProgressIndicator(
                    color: AppColors.biru,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _namaHari[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? AppColors.merah : AppColors.teksAbu,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            // Geser ke kiri/kanan untuk berpindah bulan
            onHorizontalDragEnd: (detail) {
              final v = detail.primaryVelocity ?? 0;
              if (v < -250) onMaju?.call();
              if (v > 250) onMundur?.call();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Column(
                children: [
                  for (var m = 0; m < jumlahMinggu; m++)
                    Row(
                      children: [
                        for (var k = 0; k < 7; k++)
                          Expanded(
                            child: _sel(
                              DateTime(
                                bulan.year,
                                bulan.month,
                                1 - geser + m * 7 + k,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sel(DateTime tanggal) {
    final diBulanIni = tanggal.month == bulan.month;
    final hari = diBulanIni ? data?.padaTanggal(tanggal) : null;
    final keadaan = hari == null
        ? KeadaanHari.kosong
        : keadaanHari(
            hari,
            hariIni: hariIni,
            menitSekarang: data?.menitSekarang ?? 0,
          );
    return _SelHari(
      tanggal: tanggal,
      diBulanIni: diBulanIni,
      hari: hari,
      keadaan: keadaan,
      hariIni: diBulanIni && _sama(tanggal, hariIni),
      dipilih: diBulanIni && dipilih != null && _sama(tanggal, dipilih!),
      menitSekarang: data?.menitSekarang ?? 0,
      hariIniTanggal: hariIni,
      onTap: diBulanIni ? () => onPilih(tanggal) : null,
    );
  }

  static bool _sama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SelHari extends StatelessWidget {
  const _SelHari({
    required this.tanggal,
    required this.diBulanIni,
    required this.hari,
    required this.keadaan,
    required this.hariIni,
    required this.dipilih,
    required this.menitSekarang,
    required this.hariIniTanggal,
    this.onTap,
  });

  final DateTime tanggal;
  final bool diBulanIni;
  final HariRiwayat? hari;
  final KeadaanHari keadaan;
  final bool hariIni;
  final bool dipilih;
  final int menitSekarang;
  final DateTime hariIniTanggal;
  final VoidCallback? onTap;

  /// Label kecil di bawah angka tanggal.
  String? get _label {
    final h = hari;
    if (h == null) return null;
    final libur = h.libur;
    if (h.mapel.isEmpty) {
      // Nama liburnya tampil di detail saat tanggal diketuk
      return libur != null && libur != 'Hari Minggu' ? 'Libur' : null;
    }
    switch (keadaan) {
      case KeadaanHari.izinSakitCuti:
        return _jenisIzin(h);
      case KeadaanHari.hadir:
      case KeadaanHari.sebagian:
      case KeadaanHari.tidakHadir:
        final diabsen = h.mapel.where(_diabsen).length;
        return '$diabsen/${h.mapel.length}';
      case KeadaanHari.menunggu:
      case KeadaanHari.kosong:
      case KeadaanHari.libur:
        return null;
    }
  }

  bool _diabsen(MapelAbsen m) {
    final k = keadaanMapelRiwayat(
      hari!,
      m,
      hariIni: hariIniTanggal,
      menitSekarang: menitSekarang,
    );
    return k == KeadaanMapel.hadir ||
        k == KeadaanMapel.terlambat ||
        k == KeadaanMapel.lewatJam;
  }

  bool get _adaTerlambat =>
      hari?.mapel.any((m) => m.absensi?.status == 'terlambat') ?? false;

  static String _jenisIzin(HariRiwayat h) {
    var jenis = h.cuti;
    for (final m in h.mapel) {
      final s = m.absensi?.status;
      if (s == 'izin' || s == 'sakit' || s == 'cuti') {
        jenis = s;
        break;
      }
    }
    if (jenis == null) return 'Izin';
    return jenis[0].toUpperCase() + jenis.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final gaya = GayaHari.dari(keadaan);
    final libur = tanggal.weekday == DateTime.sunday || hari?.libur != null;
    final warnaAngka = !diBulanIni
        ? const Color(0xFFC9CED6)
        : libur && gaya == GayaHari.polos
        ? AppColors.merah
        : gaya.teks;
    final label = _label;
    final berwarna = diBulanIni && gaya != GayaHari.polos;

    final Border? garis = dipilih
        ? Border.all(color: AppColors.navy, width: 2)
        : hariIni
        ? Border.all(color: AppColors.biru, width: 2)
        : diBulanIni && !berwarna
        ? Border.all(color: AppColors.garis)
        : null;

    return Semantics(
      button: onTap != null,
      label: diBulanIni
          ? '${DateFormat('d MMMM', 'id_ID').format(tanggal)}'
                '${gaya.label.isEmpty ? '' : ': ${gaya.label}'}'
          : null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: berwarna ? gaya.latar : Colors.white,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            key: diBulanIni
                ? Key('hari-${DateFormat('yyyy-MM-dd').format(tanggal)}')
                : null,
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: garis,
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: hariIni
                            ? const BoxDecoration(
                                color: AppColors.biru,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${tanggal.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: hariIni ? Colors.white : warnaAngka,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (label != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: gaya == GayaHari.polos
                                  ? AppColors.merah
                                  : gaya.teks,
                            ),
                          ),
                        )
                      else if (keadaan == KeadaanHari.menunggu)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.navyTerang,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (diBulanIni && _adaTerlambat)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keterangan warna kalender.
class _Keterangan extends StatelessWidget {
  const _Keterangan();

  @override
  Widget build(BuildContext context) {
    Widget kotak(Color warna, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              kotak(GayaHari.hadir.latar, GayaHari.hadir.label),
              kotak(GayaHari.sebagian.latar, GayaHari.sebagian.label),
              kotak(GayaHari.izin.latar, GayaHari.izin.label),
              kotak(GayaHari.tidakHadir.latar, GayaHari.tidakHadir.label),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Ada yang terlambat',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '2/3 = mapel yang diabsen dari seluruh mapel hari itu. '
            'Tanggal merah = hari Minggu / libur.',
            style: TextStyle(fontSize: 11, color: AppColors.teksAbu),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Detail tanggal yang dipilih
// ------------------------------------------------------------------------

class _DetailTanggal extends StatelessWidget {
  const _DetailTanggal({
    required this.tanggal,
    required this.hari,
    required this.hariIni,
    required this.menitSekarang,
  });

  final DateTime? tanggal;
  final HariRiwayat? hari;
  final DateTime hariIni;
  final int menitSekarang;

  @override
  Widget build(BuildContext context) {
    final t = tanggal;
    final h = hari;
    if (t == null || h == null) {
      return const _KotakInfo(
        ikon: Icons.touch_app_rounded,
        teks: 'Ketuk sebuah tanggal untuk melihat detail absennya.',
      );
    }
    final keadaan = keadaanHari(
      h,
      hariIni: hariIni,
      menitSekarang: menitSekarang,
    );
    final gaya = GayaHari.dari(keadaan);
    final relatif = hariRelatif(h.tanggal, hariIni);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  FormatTanggal.panjang(t),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teks,
                  ),
                ),
              ),
              if (gaya != GayaHari.polos)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gaya.latar,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    gaya.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: gaya.teks,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (h.mapel.isEmpty)
            Text(
              h.libur != null
                  ? 'Libur: ${h.libur}'
                  : 'Tidak ada jadwal mengajar di tanggal ini.',
              style: TextStyle(
                fontSize: 13,
                color: h.libur != null ? AppColors.merah : AppColors.teksAbu,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            if (h.libur != null)
              _Catatan('Libur: ${h.libur}', warna: AppColors.merah),
            if (h.cuti != null)
              _Catatan(
                '${_kapital(h.cuti!)} disetujui admin.',
                warna: GayaHari.izin.teks,
              ),
            for (final m in h.mapel)
              _BarisMapel(
                mapel: m,
                gaya: _gayaMapel(
                  keadaanMapelRiwayat(
                    h,
                    m,
                    hariIni: hariIni,
                    menitSekarang: menitSekarang,
                  ),
                  m.absensi,
                  relatif,
                  h.cuti,
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _kapital(String s) => s[0].toUpperCase() + s.substring(1);

  /// Label & warna setiap mapel, disamakan dengan warna kalender.
  static GayaKehadiran _gayaMapel(
    KeadaanMapel k,
    AbsensiMapel? absensi,
    HariRelatif relatif,
    String? cuti,
  ) {
    switch (k) {
      case KeadaanMapel.izin:
      case KeadaanMapel.sakit:
      case KeadaanMapel.cuti:
        final g = GayaKehadiran.dari(k, absensi: absensi);
        return GayaKehadiran(
          absensi == null ? '${g.label} (disetujui admin)' : g.label,
          GayaHari.izin.teks,
          g.ikon,
        );
      case KeadaanMapel.terlewat:
        if (relatif == HariRelatif.lalu) {
          return GayaKehadiran(
            'Tidak absen',
            GayaHari.tidakHadir.teks,
            Icons.remove_circle_outline_rounded,
          );
        }
        return GayaKehadiran.dari(k);
      case KeadaanMapel.alpa:
        return GayaKehadiran(
          'Alpa (tidak hadir)',
          GayaHari.tidakHadir.teks,
          Icons.cancel_rounded,
        );
      case KeadaanMapel.belumAbsen:
        return relatif == HariRelatif.depan
            ? GayaKehadiran.dari(KeadaanMapel.belumDibuka)
            : GayaKehadiran.dari(k);
      case KeadaanMapel.belumDibuka:
      case KeadaanMapel.hadir:
      case KeadaanMapel.terlambat:
      case KeadaanMapel.lewatJam:
        return GayaKehadiran.dari(k, absensi: absensi);
    }
  }
}

class _BarisMapel extends StatelessWidget {
  const _BarisMapel({required this.mapel, required this.gaya});

  final MapelAbsen mapel;
  final GayaKehadiran gaya;

  @override
  Widget build(BuildContext context) {
    final absensi = mapel.absensi;
    const kecil = TextStyle(fontSize: 11.5, color: AppColors.teksAbu);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  jamTitik(mapel.jamMulai),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  jamTitik(mapel.jamSelesai),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapel.mataPelajaran,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teks,
                  ),
                ),
                Text(
                  '${mapel.unit} • Kelas ${mapel.kelas}'
                  '${mapel.lokasi == null ? '' : ' • ${mapel.lokasi}'}',
                  style: kecil,
                ),
                const SizedBox(height: 6),
                ChipKehadiran(gaya: gaya),
                if (absensi?.lokasi != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Absen di ${absensi!.lokasi}'
                      '${absensi.jarak == null ? '' : ' (${formatJarak(absensi.jarak!)})'}',
                      style: kecil,
                    ),
                  ),
                if (absensi?.keterangan != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Catatan admin: ${absensi!.keterangan}',
                      style: kecil,
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

class _Catatan extends StatelessWidget {
  const _Catatan(this.teks, {required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: warna,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Rekap bulan
// ------------------------------------------------------------------------

class _RekapBulan extends StatelessWidget {
  const _RekapBulan({required this.data, required this.hariIni});

  final RiwayatBulan data;
  final DateTime hariIni;

  @override
  Widget build(BuildContext context) {
    final rekap = rekapRiwayat(
      data.hari,
      hariIni: hariIni,
      menitSekarang: data.menitSekarang,
    );
    final bulanIni =
        data.bulan.year == hariIni.year && data.bulan.month == hariIni.month;
    final bulanDepan = data.bulan.isAfter(hariIni);

    Widget angka(String nilai, String label, Color warna) => Expanded(
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
          const SizedBox(height: 4),
          Text(
            nilai,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );

    Widget baris(IconData ikon, String label, String nilai) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(ikon, size: 17, color: AppColors.biru),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
              ),
            ),
          ),
          Text(
            nilai,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040029), Color(0xFF0B0068)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rekap ${DateFormat('MMMM yyyy', 'id_ID').format(data.bulan)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            bulanDepan
                ? 'Bulan ini belum berjalan.'
                : bulanIni
                ? 'Sampai hari ini (${FormatTanggal.singkat(hariIni)})'
                : 'Satu bulan penuh',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              angka('${rekap.hariHadir}', 'Hari hadir', GayaHari.hadir.latar),
              angka(
                '${rekap.hariSebagian}',
                'Hari hadir sebagian',
                GayaHari.sebagian.latar,
              ),
              angka(
                '${rekap.hariIzin}',
                'Hari izin/sakit/cuti',
                GayaHari.izin.latar,
              ),
              angka(
                '${rekap.hariTidakHadir}',
                'Hari tidak absen',
                GayaHari.tidakHadir.latar,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 4),
          baris(
            Icons.menu_book_rounded,
            'Mapel diabsen',
            '${rekap.mapelDiabsen} dari ${rekap.mapelSelesai}',
          ),
          baris(
            Icons.watch_later_rounded,
            'Terlambat',
            '${rekap.kaliTerlambat} kali',
          ),
          baris(
            Icons.timer_rounded,
            'Jam mengajar',
            formatDurasi(rekap.menitMengajar),
          ),
          const SizedBox(height: 8),
          Text(
            'Mapel izin/sakit/cuti dan mapel yang belum selesai tidak '
            'dihitung. Jam mengajar = total jam mapel yang diabsen.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------

class _KotakInfo extends StatelessWidget {
  const _KotakInfo({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Row(
        children: [
          Icon(ikon, color: AppColors.teksAbu),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 13, color: AppColors.teksAbu),
            ),
          ),
        ],
      ),
    );
  }
}

class _KotakGagal extends StatelessWidget {
  const _KotakGagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.garis),
      ),
      child: Column(
        children: [
          Text(pesan, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onCobaLagi,
            style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
