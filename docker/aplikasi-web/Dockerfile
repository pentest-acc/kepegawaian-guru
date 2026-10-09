# Aplikasi Flutter versi web (opsional).
# Tahap 1 membangun aplikasi dengan Flutter versi tertentu,
# tahap 2 menyajikannya dengan nginx.

FROM debian:bookworm-slim AS bangun
ARG FLUTTER_VERSION=3.47.6
ARG API_URL=http://localhost:8080/kepegawaian-guru/backend/api

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt \
 && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web

WORKDIR /app
COPY aplikasi/pubspec.yaml aplikasi/pubspec.lock ./
RUN flutter pub get
COPY aplikasi/ ./
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL}

FROM nginx:1.27-alpine
COPY --from=bangun /app/build/web /usr/share/nginx/html
