#!/usr/bin/env bash
# Yedek + sağlık zamanlayıcılarını kurar (root). Repo'daki sunucu/deploy klasörünü /opt/emlakdeal-deploy'a bağlar.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "root olmalı" >&2; exit 1; }
DIZIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ln -sfn "$DIZIN" /opt/emlakdeal-deploy
install -m 644 "$DIZIN"/sistem/emlak-*.service "$DIZIN"/sistem/emlak-*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now emlak-yedek.timer emlak-saglik.timer
systemctl list-timers 'emlak-*'
