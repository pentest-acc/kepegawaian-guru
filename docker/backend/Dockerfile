# Backend API: PHP 8.3 + Apache (versi sama di setiap laptop)
FROM php:8.3-apache

# - pdo_mysql : koneksi PHP ke MySQL
# - rewrite   : dipakai backend/.htaccess (meneruskan header Authorization)
# - AllowOverride All : agar file .htaccess di folder backend dibaca Apache
RUN docker-php-ext-install pdo_mysql \
 && a2enmod rewrite \
 && sed -ri 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf \
 && printf 'date.timezone = Asia/Jakarta\nupload_max_filesize = 10M\npost_max_size = 12M\n' \
      > /usr/local/etc/php/conf.d/kepegawaian.ini

# Halaman awal sederhana jika membuka http://localhost:8080/
RUN printf '<!doctype html><meta charset="utf-8"><title>Kepegawaian Guru</title><p>Backend berjalan. API: <a href="/kepegawaian-guru/backend/api/">/kepegawaian-guru/backend/api/</a></p>' \
      > /var/www/html/index.html
