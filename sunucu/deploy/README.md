# Emlak Deal – sunucu taşıma ve işletme rehberi

Hedef: sunucuyu evdeki LXC'den (Proxmox 101, Tailscale Funnel) küçük bir VPS'e taşımak.
Adım adım görsel akış için sunum: **Emlak Deal taşıma rehberi** (Artifact).

> Durum: bu klasördeki dosyalar yerelde sözdizimi açısından doğrulandı (`bash -n`, `dart analyze`; yük testi yerel sunucuya karşı çalıştırıldı).
> **Docker imajı bu makinede derlenmedi** (Docker Desktop daemon'ı kapalıydı). İlk `docker compose up --build` VPS'te gerçek sınav olacak; hata verirse çıktıyı Claude'a ver.

## Dosyalar

| Dosya | Ne işe yarar |
|---|---|
| `Dockerfile` | Çok aşamalı: `dart build cli` ile native derleme (sqlite3 kütüphanesi dahil), `debian:bookworm-slim`, root olmayan kullanıcı |
| `docker-compose.yml` | `sunucu` + `caddy` (otomatik TLS, WebSocket), `veri` hacmi `/data` |
| `Caddyfile` | `ALAN_ADI` için HTTPS → `sunucu:8765` |
| `.env.example` | Tüm ortam değişkenleri (gizli değerler boş) |
| `emlakdeal.service` | Docker'sız alternatif (systemd) |
| `backup.sh` / `restore.sh` | Doğrulamalı yedek (sqlite `.backup` + `integrity_check`), 14 günlük + 8 haftalık döndürme, isteğe bağlı rclone / scp |
| `healthcheck.sh` | `/saglik` + disk dolu kontrolü + Healthchecks.io ping |
| `sistem/` | systemd timer'ları (yedek 03:30, sağlık her dakika), cron örneği, logrotate |
| `guvenlik_kur.sh` | Yeni VPS: kullanıcı, SSH sertleştirme, ufw, fail2ban, otomatik güvenlik güncellemesi, Docker, swap |
| `kur_zamanlayici.sh` | Yedek/sağlık timer'larını kurar |
| `gecis_tasi.sh` | LXC → VPS veri taşıma (prova modu + kesinti modu) |
| `yuk_testi.dart` | Yük testi (elle çalıştırılır) |

## 1. VPS ve alan adı

- Öneri: Hetzner CX22 (2 vCPU / 4 GB, Avrupa) ya da DigitalOcean 2 vCPU / 2 GB. Ubuntu 24.04.
- Alan adı al (ya da mevcut bir alan adının alt alanı: `oyun.ornek.com`). A kaydını VPS IP'sine yönelt, TTL 300.
- Facebook/Google panellerinde de bu alan adı kullanılacak.

## 2. İlk kurulum (root, bir kez)

```bash
ssh root@VPS_IP
apt-get update && apt-get install -y git
git clone <depo-adresi> /root/emlakdeal      # ya da klasörü scp -r ile kopyala
cd /root/emlakdeal/sunucu/deploy
bash guvenlik_kur.sh                         # SSH anahtarı root'ta zaten olmalı
```

Yeni bir terminalden `ssh emlak@VPS_IP` ile girebildiğini doğrula, sonra root oturumunu kapat.
Not: Ubuntu 24.04'te SSH portunu değiştirirsen `ssh.socket` devreye girer; varsayılan 22'yi bırakmak en güvenlisi.

## 3. Kodu al, .env doldur

```bash
cd ~ && git clone <depo-adresi> emlakdeal && cd emlakdeal/sunucu/deploy
cp .env.example .env && chmod 600 .env && nano .env
openssl rand -hex 32          # YONETIM_ANAHTAR için
```

`.env` içine yaz: `ALAN_ADI`, `ACME_EPOSTA`, Google/Facebook kimlikleri. **.env dosyasını git'e koyma.**

## 4. Başlat

```bash
docker compose up -d --build
docker compose ps
curl -fsS https://ALAN_ADI/saglik            # ok odalar=0
docker compose logs -f sunucu
```

İlk istekte Caddy sertifikayı kendisi alır (80 ve 443 açık, DNS yayılmış olmalı).

## 5. Veri taşıma (LXC → VPS)

Kesinti ~1–2 dakikadır. Oyuncunun az olduğu saati seç.

1. **Prova:** `ESKI=root@192.168.1.21 YENI=emlak@VPS_IP ./gecis_tasi.sh` (eski sunucuya dokunmaz).
2. Eski sunucuda `curl localhost:8765/saglik` → `odalar=0` olmalı (restart oyunları düşürür).
3. **Kesinti:** `./gecis_tasi.sh --kes` – eski servisi durdurur, yedekler, doğrular, VPS'e yükler, başlatır, kullanıcı sayılarını yazar.
4. Kullanıcı sayısı eşleşiyorsa DNS / istemci adresini yeni sunucuya çevir.

Elle yapmak istersen: eski makinede `systemctl stop monodeal`, `sqlite3 emlakdeal.db ".backup '/tmp/g.db'"`, `scp`, VPS'te `docker compose stop sunucu` ve DB'yi `emlakdeal_veri` hacmine kopyala (`restore.sh` aynı işi yapar).

## 6. İstemci adresi (kod değişikliği – Claude yapar)

`lib/ayarlar.dart` içinde şu satır yeni alan adına çevrilecek:

```dart
String get sunucu => 'wss://emlakdeal.tailb92005.ts.net';   // -> 'wss://ALAN_ADI'
```

Adres uygulamanın içine gömülü olduğu için **yeni APK/AAB gerekir**. Uygulama henüz mağazada olmadığı için en temiz yol: önce sunucuyu taşı, sonra yeni adresle derle. Eski sürümü telefonlarda kullanan varsa geçiş süresince eski adres (Tailscale Funnel) açık kalmalı; ama iki sunucu aynı anda yazarsa veri bölünür, bu yüzden `--kes` ile eski sunucu durdurulur.

## 7. Yedek ve izleme

```bash
sudo apt-get install -y sqlite3
sudo ./kur_zamanlayici.sh                    # yedek 03:30 + sağlık her dakika
sudo ./backup.sh                             # ilk yedeği elle al, çıktıyı oku
sudo ./restore.sh /var/backups/emlakdeal/gunluk/emlakdeal-XXXX.db.gz   # SADECE test ortamında dene
```

- Healthchecks.io'da iki "check" aç (yedek: 1 gün + 6 saat tolerans; sağlık: 1 dakika + 5 dakika tolerans). Ping adreslerini `.env` içine `HC_YEDEK_URL` ve `HC_SAGLIK_URL` olarak yaz.
- UptimeRobot'ta `https://ALAN_ADI/saglik` için HTTP monitörü (5 dk). Dışarıdan bakıştır; VPS tamamen çökerse tek o haber verir.
- **Yedeği VPS dışına da çıkar:** `RCLONE_HEDEF` (Backblaze B2 / S3) ve/veya `SCP_HEDEF` (ev PC'si). Aynı diskteki yedek, disk gidince biter.
- Geri yükleme provasını yılda en az bir kez yap.

## 8. Docker'sız (systemd) alternatif

```bash
cd ~/emlakdeal/sunucu && dart pub get && dart build cli -t bin/sunucu.dart -o /tmp/derle
sudo useradd --system --home /var/lib/emlakdeal -m emlak
sudo mkdir -p /opt/emlakdeal /etc/emlakdeal && sudo cp -r /tmp/derle/bundle/* /opt/emlakdeal/
sudo cp deploy/.env.example /etc/emlakdeal/emlakdeal.env   # düzenle
sudo cp deploy/emlakdeal.service /etc/systemd/system/ && sudo systemctl enable --now emlakdeal
```

Bu modda TLS'i yine Caddy (ya da nginx) yapmalı; `backup.sh` için `DB_YOL=/var/lib/emlakdeal/emlakdeal.db` ver.

## 9. Güvenlik özeti

- Sunucu portu (8765) dışarı **açık değil**; yalnız Caddy 80/443 dinler (`expose`, `ports` değil – Docker'ın ufw'yi atlaması böylece sorun olmaz).
- SSH: yalnız anahtar, root kapalı, fail2ban (5 hata → 1 saat ban).
- Otomatik güvenlik güncellemesi; çekirdek güncellemesi gerekirse 04:30'da yeniden başlar (oyuncuları kısa süre düşürebilir, istemci yeniden bağlanır).
- Caddy arkasında sunucu istemci IP'sini proxy IP'si (172.x) olarak görür. Sunucudaki giriş sınırı **e-postaya** bağlı (`_girisHatalari`), IP'ye değil; sorun çıkmaz. İleride IP tabanlı sınır eklenirse `X-Forwarded-For` okunmalı.
- `.env` ve yedekler `chmod 600/700`.

## 10. Kapasite (ÖLÇÜLMEDİ – tahmin)

- Sunucu **tek Dart isolate**: tüm odalar, botlar, zamanlayıcılar ve SQLite çağrıları tek iş parçacığında. Ek çekirdek hız kazandırmaz; 2 vCPU yeterli (ikincisi Caddy/OS için).
- Oda başına bir `Timer` (60 sn tur) ve bot gecikmeleri (350–1500 ms) var; iş çoğunlukla bekleme. Tahmin: 2 vCPU / 2–4 GB ile birkaç yüz eşzamanlı bağlantı ve onlarca aktif oda rahat olmalı. Bu bir **tahmindir**.
- Gerçek sınırı `yuk_testi.dart` bulur:
  ```bash
  cd sunucu
  dart deploy/yuk_testi.dart --url wss://ALAN_ADI --baglanti 200 --sure 60          # yalnız bağlantı + ping
  dart deploy/yuk_testi.dart --url wss://ALAN_ADI --odalar tokenlar.txt --sure 300  # oda+bot yükü (test hesaplarının token'ları)
  ```
  Ölçüt: p95 ping < 200 ms, hata 0. Aynı anda VPS'te `docker stats` izle. Yerelde 30 bağlantıyla doğrulandı (p95 2 ms); gerçek ağ ve oda yükü ölçülmedi.
- Çok büyürse önce VPS'i büyüt (dikey). Yatay ölçek, sunucunun odaları bellekte tuttuğu için kod değişikliği ister.

## 11. Geri dönüş planı

- Taşımada eski LXC servisi **silinmez**, yalnız durdurulur: `ssh root@192.168.1.21 'systemctl start monodeal'` ve DNS/istemciyi eski adrese çevir.
- Yeni sunucuda yazılan veri kaybolmasın diye geri dönüşte VPS'ten son yedeği LXC'ye aynı yöntemle (`.backup` → scp) taşı.
- `restore.sh` her geri yüklemede mevcut DB'yi `.once-<tarih>` diye saklar.

## 12. Sorun giderme

| Belirti | Bak |
|---|---|
| Sertifika alınmıyor | DNS A kaydı doğru mu, 80/443 açık mı: `docker compose logs caddy` |
| `libsqlite3` bulunamadı | `docker compose exec sunucu ls /app/lib` |
| DB sıfırlanmış görünüyor | WORKDIR `/data` olmalı; `docker volume inspect emlakdeal_veri` |
| WebSocket kopuyor | Caddy log'u; istemci `wss://` kullanıyor mu |
| Disk doluyor | `docker system prune -f`, `du -sh /var/lib/docker /var/backups/emlakdeal` |
