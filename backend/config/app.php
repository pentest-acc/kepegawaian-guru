<?php
/**
 * Konfigurasi umum backend API.
 */
return [
    // Zona waktu Yayasan (WIB)
    'timezone' => 'Asia/Jakarta',

    // Berapa hari token login berlaku sebelum guru harus login ulang
    'token_berlaku_hari' => 30,

    // Pengamanan login: jika kata sandi salah sebanyak 'maks_gagal_login' kali,
    // akun (email/NIY) tersebut dikunci sementara selama 'lama_kunci_menit'.
    'maks_gagal_login' => 5,
    'lama_kunci_menit' => 15,

    // Absen: ukuran maksimal foto absen (foto dari kamera biasanya < 300 KB).
    // Toleransi terlambat, jam buka absen, dan lokasi absen diatur admin di
    // aplikasi (menu Pengaturan Sistem & Lokasi Absen). Jam absen setiap
    // guru mengikuti jadwal mengajarnya.
    'maks_foto_absen_kb' => 5120,

    // true  = pesan error asli ditampilkan (mudah dicari saat belajar/development)
    // false = pesan error disembunyikan (WAJIB false saat sudah di hosting)
    'tampilkan_error' => true,
];
