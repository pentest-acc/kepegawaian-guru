<?php
/**
 * Konfigurasi umum backend API.
 */
return [
    // Zona waktu Yayasan (WIB)
    'timezone' => 'Asia/Jakarta',

    // Berapa hari token login berlaku sebelum guru harus login ulang
    'token_berlaku_hari' => 30,

    // true  = pesan error asli ditampilkan (mudah dicari saat belajar/development)
    // false = pesan error disembunyikan (WAJIB false saat sudah di hosting)
    'tampilkan_error' => true,
];
