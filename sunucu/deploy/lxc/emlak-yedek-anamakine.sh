#!/bin/bash
# Emlak Deal DB yedeği: LXC 102'de alınır, kopyası LXC 101'e (oyun container'ı dışına) konur.
set -euo pipefail
pct exec 102 -- env EMLAK_DB=/opt/emlakdeal/src/sunucu/emlakdeal.db EMLAK_YEDEK_DIZIN=/opt/emlakdeal/yedek/gunluk python3 /opt/emlakdeal/emlak_yedek.py
son=$(pct exec 102 -- sh -c 'ls -t /opt/emlakdeal/yedek/gunluk/emlakdeal-*.db.gz | head -1')
ad=$(basename "$son")
umask 077
pct pull 102 "$son" "/root/$ad"
pct push 101 "/root/$ad" "/opt/monodeal/yedek/gunluk/$ad" --perms 0600
rm -f "/root/$ad"
pct exec 101 -- sh -c 'ls -t /opt/monodeal/yedek/gunluk/emlakdeal-*.db.gz | tail -n +15 | xargs -r rm -f'
echo "yedek tamam: $ad"
