#!/usr/bin/env bash
# YENİ bir Ubuntu 22.04/24.04 VPS'te root olarak BİR KEZ çalıştır.
# Önce kendi bilgisayarından SSH anahtarının sunucuya girdiğini DOĞRULA (ayrı bir terminalde),
# yoksa parola girişini kapatınca dışarıda kalırsın.
#   KULLANICI=emlak SSH_PORT=22 bash guvenlik_kur.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "root olmalı" >&2; exit 1; }
KULLANICI="${KULLANICI:-emlak}"
SSH_PORT="${SSH_PORT:-22}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y ufw fail2ban unattended-upgrades sqlite3 curl ca-certificates gnupg

# 1) Yönetici kullanıcı (root SSH kapatılacak). Anahtar root'tan kopyalanır.
if ! id "$KULLANICI" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$KULLANICI"
  usermod -aG sudo "$KULLANICI"
  echo "$KULLANICI ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$KULLANICI"
  chmod 440 "/etc/sudoers.d/90-$KULLANICI"
fi
install -d -m 700 -o "$KULLANICI" -g "$KULLANICI" "/home/$KULLANICI/.ssh"
if [ -s /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys "/home/$KULLANICI/.ssh/authorized_keys"
  chown "$KULLANICI:$KULLANICI" "/home/$KULLANICI/.ssh/authorized_keys"
  chmod 600 "/home/$KULLANICI/.ssh/authorized_keys"
fi
[ -s "/home/$KULLANICI/.ssh/authorized_keys" ] || { echo "HATA: $KULLANICI için SSH anahtarı yok; devam edilmiyor." >&2; exit 1; }

# 2) SSH sertleştirme (drop-in dosyası; ana yapılandırma bozulmaz)
cat > /etc/ssh/sshd_config.d/99-emlak.conf <<CFG
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
CFG
sshd -t && systemctl reload ssh || systemctl reload sshd

# 3) Güvenlik duvarı: yalnız SSH + 80/443
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp comment 'ssh'
ufw allow 80/tcp comment 'http (acme)'
ufw allow 443/tcp comment 'https'
ufw allow 443/udp comment 'http3'
ufw --force enable

# 4) fail2ban (sshd jail varsayılan açık; ayar: 5 hata -> 1 saat ban)
cat > /etc/fail2ban/jail.d/emlak.local <<CFG
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
findtime = 10m
bantime = 1h
CFG
systemctl enable --now fail2ban && systemctl restart fail2ban

# 5) Otomatik güvenlik güncellemeleri (gerekirse gece yeniden başlatma 04:30)
cat > /etc/apt/apt.conf.d/20auto-upgrades <<CFG
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CFG
cat > /etc/apt/apt.conf.d/52emlak-unattended <<CFG
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:30";
CFG
echo "NOT: otomatik yeniden başlatma açık. Oyun sırasında düşmesin diye 04:30 seçildi."

# 6) Docker (resmi depo)
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$KULLANICI"
systemctl enable --now docker

# 7) Swap (2 GB'lık makinede derleme sırasında bellek yetmezse)
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo
echo "TAMAM. YENİ bir terminalden test et:  ssh -p $SSH_PORT $KULLANICI@SUNUCU_IP"
echo "Çalışıyorsa bu root oturumunu kapat."
