#!/usr/bin/env bash
# Emlak Deal DB yedeği: sqlite .backup -> integrity_check -> gzip -> döndürme -> isteğe bağlı uzak kopya.
# Çalışma modları:
#   Docker (varsayılan): DB konteyner içinde, yedek sqlite3 ile konteynerde alınır.
#   Dosya:               DB_YOL=/var/lib/emlakdeal/emlakdeal.db ayarlıysa host'taki sqlite3 kullanılır.
# Ayarlar ortamdan ya da /etc/emlakdeal/yedek.env dosyasından okunur.
set -euo pipefail

[ -f /etc/emlakdeal/yedek.env ] && . /etc/emlakdeal/yedek.env
DIZIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIZIN/.env" ] && { set -a; . "$DIZIN/.env"; set +a; }

YEDEK_DIZIN="${YEDEK_DIZIN:-/var/backups/emlakdeal}"
GUNLUK_SAKLA="${GUNLUK_SAKLA:-14}"
HAFTALIK_SAKLA="${HAFTALIK_SAKLA:-8}"
COMPOSE="${COMPOSE:-docker compose -f $DIZIN/docker-compose.yml}"
DB_YOL="${DB_YOL:-}"
HC="${HC_YEDEK_URL:-}"

mkdir -p "$YEDEK_DIZIN/gunluk" "$YEDEK_DIZIN/haftalik"
chmod 700 "$YEDEK_DIZIN"
damga="$(date +%Y%m%d-%H%M%S)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ham="$tmp/emlakdeal.db"

bildir() { [ -n "$HC" ] && curl -fsS -m 10 --retry 3 "$HC$1" -o /dev/null || true; }
bildir /start

hata() { echo "YEDEK HATASI: $*" >&2; bildir /fail; exit 1; }

# 1) Tutarlı anlık kopya (WAL açıkken bile güvenli)
if [ -n "$DB_YOL" ]; then
  sqlite3 "$DB_YOL" ".backup '$ham'" || hata "sqlite3 .backup (dosya modu)"
else
  $COMPOSE exec -T sunucu sh -c "rm -f /data/.yedek.db; sqlite3 /data/emlakdeal.db \".backup '/data/.yedek.db'\"" || hata "sqlite3 .backup (konteyner)"
  $COMPOSE cp sunucu:/data/.yedek.db "$ham" || hata "docker compose cp"
  $COMPOSE exec -T sunucu rm -f /data/.yedek.db || true
fi

# 2) Doğrula: bozuk yedek saklanmaz
sonuc="$(sqlite3 "$ham" 'PRAGMA integrity_check;')"
[ "$sonuc" = "ok" ] || hata "integrity_check: $sonuc"
kul="$(sqlite3 "$ham" 'SELECT count(*) FROM kullanicilar;')"
[ "${kul:-0}" -ge 0 ] || hata "kullanicilar tablosu okunamadı"

# 3) Sıkıştır
hedef="$YEDEK_DIZIN/gunluk/emlakdeal-$damga.db.gz"
gzip -9 -c "$ham" > "$hedef"
chmod 600 "$hedef"
echo "yedek: $hedef ($(du -h "$hedef" | cut -f1), kullanıcı=$kul)"

# 4) Pazar günü haftalık kopya
if [ "$(date +%u)" = "7" ]; then
  cp "$hedef" "$YEDEK_DIZIN/haftalik/"
fi

# 5) Döndürme
find "$YEDEK_DIZIN/gunluk"   -name 'emlakdeal-*.db.gz' -mtime +"$GUNLUK_SAKLA" -delete
find "$YEDEK_DIZIN/haftalik" -name 'emlakdeal-*.db.gz' -mtime +$((HAFTALIK_SAKLA * 7)) -delete

# 6) Uzak kopyalar (isteğe bağlı; hata yedeği geçersiz kılmaz ama uyarı verir)
uzak_hata=0
if [ -n "${RCLONE_HEDEF:-}" ]; then
  rclone copy "$hedef" "$RCLONE_HEDEF/" --quiet || { echo "rclone başarısız" >&2; uzak_hata=1; }
fi
if [ -n "${SCP_HEDEF:-}" ]; then
  scp -q -o BatchMode=yes -o ConnectTimeout=15 "$hedef" "$SCP_HEDEF/" || { echo "scp başarısız" >&2; uzak_hata=1; }
fi

if [ "$uzak_hata" = 1 ]; then bildir /fail; exit 2; fi
bildir ""
