#!/usr/bin/env bash
# Yedekten geri yükleme.   Kullanım:  ./restore.sh /var/backups/emlakdeal/gunluk/emlakdeal-XXXX.db.gz
# Önce yedeği DOĞRULAR; sonra sunucuyu durdurur, mevcut DB'yi .once-<damga> olarak kenara alır, yedeği koyar, başlatır.
# Docker modu varsayılan; systemd için DB_YOL=/var/lib/emlakdeal/emlakdeal.db SERVIS=emlakdeal ayarla.
set -euo pipefail
[ $# -eq 1 ] || { echo "Kullanım: $0 yedek.db.gz" >&2; exit 64; }
yedek="$1"
[ -f "$yedek" ] || { echo "Dosya yok: $yedek" >&2; exit 66; }
DIZIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="${COMPOSE:-docker compose -f $DIZIN/docker-compose.yml}"
DB_YOL="${DB_YOL:-}"
SERVIS="${SERVIS:-}"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gzip -dc "$yedek" > "$tmp/emlakdeal.db"
[ "$(sqlite3 "$tmp/emlakdeal.db" 'PRAGMA integrity_check;')" = "ok" ] || { echo "Yedek bozuk, iptal." >&2; exit 1; }
echo "Yedek sağlam. Kullanıcı sayısı: $(sqlite3 "$tmp/emlakdeal.db" 'SELECT count(*) FROM kullanicilar;')"
read -r -p "Canlı veritabanının ÜZERİNE yazılacak. Devam? (evet yazın) " c
[ "$c" = "evet" ] || { echo "İptal."; exit 1; }
damga="$(date +%Y%m%d-%H%M%S)"

if [ -n "$DB_YOL" ]; then
  systemctl stop "${SERVIS:-emlakdeal}"
  [ -f "$DB_YOL" ] && mv "$DB_YOL" "$DB_YOL.once-$damga"
  rm -f "$DB_YOL-wal" "$DB_YOL-shm"
  install -o emlak -g emlak -m 600 "$tmp/emlakdeal.db" "$DB_YOL"
  systemctl start "${SERVIS:-emlakdeal}"
else
  $COMPOSE stop sunucu
  # Geçici konteynerle aynı hacme yaz (sunucu durduğu için exec kullanılamaz)
  vol="emlakdeal_veri"
  docker run --rm -v "$vol":/data -v "$tmp":/yedek:ro debian:bookworm-slim sh -c \
    "[ -f /data/emlakdeal.db ] && mv /data/emlakdeal.db /data/emlakdeal.db.once-$damga; rm -f /data/emlakdeal.db-wal /data/emlakdeal.db-shm; cp /yedek/emlakdeal.db /data/emlakdeal.db && chown 10001:10001 /data/emlakdeal.db && chmod 600 /data/emlakdeal.db"
  $COMPOSE start sunucu
fi
sleep 3
echo "Sağlık: $(curl -fsS http://127.0.0.1:8765/saglik 2>/dev/null || echo 'yanıt yok (docker modunda: docker compose exec sunucu curl localhost:8765/saglik)')"
echo "Eski DB .once-$damga olarak saklandı; her şey yolundaysa sonra silebilirsin."
