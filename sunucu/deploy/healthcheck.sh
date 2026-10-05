#!/usr/bin/env bash
# Dakikada bir çalıştır (cron veya systemd timer). Sağlık + disk kontrolü.
# Başarıda Healthchecks.io'ya ping atar; ping ULAŞMAZSA Healthchecks sana e-posta/telegram yollar.
# Ayrıca UptimeRobot'ta https://ALAN/saglik için ayrı bir HTTP monitörü kur (dışarıdan bakış).
set -uo pipefail
DIZIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIZIN/.env" ] && { set -a; . "$DIZIN/.env"; set +a; }
[ -f /etc/emlakdeal/yedek.env ] && . /etc/emlakdeal/yedek.env

URL="${SAGLIK_URL:-http://127.0.0.1:8765/saglik}"
HC="${HC_SAGLIK_URL:-}"
DISK_ESIK="${DISK_ESIK:-85}"      # yüzde
YOL="${DISK_YOL:-/}"
COMPOSE="${COMPOSE:-docker compose -f $DIZIN/docker-compose.yml}"

ping() { [ -n "$HC" ] && curl -fsS -m 10 --retry 2 "$HC$1" -o /dev/null || true; }

# Docker modunda 8765 dışarı açık değil: konteyner içinden sor
if curl -fsS -m 5 "$URL" >/tmp/emlak_saglik 2>/dev/null; then
  cevap="$(cat /tmp/emlak_saglik)"
elif cevap="$($COMPOSE exec -T sunucu curl -fsS -m 5 http://127.0.0.1:8765/saglik 2>/dev/null)"; then
  :
else
  echo "SAĞLIK BAŞARISIZ: sunucu yanıt vermiyor" >&2
  ping /fail
  exit 1
fi

kullanim="$(df -P "$YOL" | awk 'NR==2 {gsub("%",""); print $5}')"
if [ "${kullanim:-0}" -ge "$DISK_ESIK" ]; then
  echo "DİSK DOLU: $YOL %$kullanim (eşik %$DISK_ESIK)" >&2
  ping /fail
  exit 2
fi

echo "ok: $cevap, disk %$kullanim"
ping ""
