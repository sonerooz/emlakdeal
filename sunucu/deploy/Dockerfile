# Emlak Deal sunucusu - çok aşamalı imaj.
# Build bağlamı: emlakdeal/ kökü (cekirdek + sunucu birlikte gerekir)
#   docker build -f sunucu/deploy/Dockerfile -t emlakdeal-sunucu .

FROM dart:stable AS derle
WORKDIR /src
COPY cekirdek/ cekirdek/
COPY sunucu/pubspec.yaml sunucu/pubspec.lock* sunucu/
RUN cd sunucu && dart pub get
COPY sunucu/bin/ sunucu/bin/
# sqlite3 yerel kütüphanesi build hook'u ile bundle/lib içine girer
RUN cd sunucu && dart pub get && dart build cli -t bin/sunucu.dart -o /out

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl sqlite3 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --home-dir /data --shell /usr/sbin/nologin emlak \
 && mkdir -p /data && chown emlak:emlak /data
COPY --from=derle /out/bundle/ /app/
WORKDIR /data
USER emlak
EXPOSE 8765
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8765/saglik || exit 1
# DB dosyası göreli (emlakdeal.db) => WORKDIR /data içinde oluşur
ENTRYPOINT ["/app/bin/sunucu", "8765"]
