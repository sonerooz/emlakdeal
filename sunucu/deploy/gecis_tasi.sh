#!/usr/bin/env bash
# LXC 101 (ev) -> VPS veri taşıma. Hem LXC'ye hem VPS'e ssh ile erişebilen bir makinede (ev PC / WSL / git-bash) çalıştır.
#   ESKI=root@192.168.1.21 YENI=emlak@VPS_IP ./gecis_tasi.sh [--kes]
# --kes verilmezse yalnız PROVA yapar (eski sunucuyu durdurmaz, VPS'e deneme kopyası koyar).
# --kes verilirse: odalar=0 kontrolü -> eski servisi durdur -> son .backup -> VPS'e yükle -> VPS'te başlat.
# DNS geçişi ve istemci adresi bu betiğin işi değil (README "Veri taşıma" ve sunum 6-8. adımlar).
set -euo pipefail
ESKI="${ESKI:?ESKI=kullanici@host ver}"
YENI="${YENI:?YENI=kullanici@host ver}"
ESKI_SERVIS="${ESKI_SERVIS:-monodeal}"
KES=0; [ "${1:-}" = "--kes" ] && KES=1
damga="$(date +%Y%m%d-%H%M%S)"
yerel="$(mktemp -d)"; trap 'rm -rf "$yerel"' EXIT

echo "== 1) Eski sunucu sağlığı"
saglik="$(ssh "$ESKI" 'curl -fsS localhost:8765/saglik')"
echo "   $saglik"
if [ "$KES" = 1 ]; then
  case "$saglik" in
    *"odalar=0"*) ;;
    *) echo "   Aktif oda var; restart oyunları düşürür. Odalar bitene kadar bekle." >&2; exit 1;;
  esac
fi

echo "== 2) Eski DB konumu"
wd="$(ssh "$ESKI" "systemctl show $ESKI_SERVIS -p WorkingDirectory --value")"
db="${ESKI_DB:-$wd/emlakdeal.db}"
echo "   $db"
ssh "$ESKI" "test -f '$db'" || { echo "   DB bulunamadı. ESKI_DB=... ile ver." >&2; exit 1; }

if [ "$KES" = 1 ]; then
  echo "== 3) Eski servis durduruluyor (kesinti başladı)"
  ssh "$ESKI" "systemctl stop $ESKI_SERVIS"
fi

echo "== 4) Tutarlı yedek + doğrulama"
ssh "$ESKI" "rm -f /tmp/gecis.db && sqlite3 '$db' \".backup '/tmp/gecis.db'\" && sqlite3 /tmp/gecis.db 'PRAGMA integrity_check;' && sqlite3 /tmp/gecis.db 'SELECT count(*) FROM kullanicilar;'"
scp -q "$ESKI:/tmp/gecis.db" "$yerel/emlakdeal.db"
ssh "$ESKI" 'rm -f /tmp/gecis.db'
[ "$(sqlite3 "$yerel/emlakdeal.db" 'PRAGMA integrity_check;')" = "ok" ] || { echo "indirilen kopya bozuk" >&2; exit 1; }
kul="$(sqlite3 "$yerel/emlakdeal.db" 'SELECT count(*) FROM kullanicilar;')"
echo "   kullanıcı sayısı: $kul"

echo "== 5) VPS'e kopyalama"
scp -q "$yerel/emlakdeal.db" "$YENI:/tmp/emlakdeal-gecis.db"

if [ "$KES" = 0 ]; then
  echo "PROVA bitti: VPS'te /tmp/emlakdeal-gecis.db hazır. Canlıya almak için --kes ile tekrar çalıştır."
  exit 0
fi

echo "== 6) VPS'te yükleme"
ssh "$YENI" bash -s <<REMOTE
set -euo pipefail
cd ~/emlakdeal/sunucu/deploy
docker compose stop sunucu
docker run --rm -v emlakdeal_veri:/data -v /tmp:/gelen:ro debian:bookworm-slim sh -c \
 "[ -f /data/emlakdeal.db ] && mv /data/emlakdeal.db /data/emlakdeal.db.once-$damga; rm -f /data/emlakdeal.db-wal /data/emlakdeal.db-shm; cp /gelen/emlakdeal-gecis.db /data/emlakdeal.db && chown 10001:10001 /data/emlakdeal.db && chmod 600 /data/emlakdeal.db"
docker compose start sunucu
sleep 5
docker compose exec -T sunucu curl -fsS http://127.0.0.1:8765/saglik; echo
docker compose exec -T sunucu sqlite3 /data/emlakdeal.db 'SELECT count(*) FROM kullanicilar;'
rm -f /tmp/emlakdeal-gecis.db
REMOTE
echo
echo "BİTTİ. Kullanıcı sayısı ($kul) yukarıdakiyle aynı mı? Aynıysa DNS'i / istemciyi yeni adrese yönlendir."
echo "Eski servis DURDURULDU. Geri dönüş: ssh $ESKI 'systemctl start $ESKI_SERVIS' ve DNS'i geri al."
