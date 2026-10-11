# Emlak Deal — ev sunucusu (Proxmox) kurulumu

İnternete açık oyun sunucusu, Samantha / Home Assistant'tan **ayrı** bir container'da çalışır.

| Ne | Nerede |
|---|---|
| Oyun sunucusu | **LXC 102 `emlakdeal`** (192.168.1.22), Debian 13, unprivileged, SSH yok |
| Servis | `emlakdeal.service` — `emlak` kullanıcısı (root değil), `/opt/emlakdeal/src/sunucu` |
| Veritabanı | `/opt/emlakdeal/src/sunucu/emlakdeal.db` (0600, emlak) |
| Dış adres | Tailscale Funnel `https://emlakdeal.tailb92005.ts.net` → `127.0.0.1:8765` (tailscaled userspace, LXC 102) |
| Ağ yalıtımı | Proxmox ana makinesinde `emlak-yalitim.service` → `/etc/emlak-yalitim.nft` (bridge tablosu, yalnız `veth102i0`) |
| Yedek | Ana makine `emlak-yedek.timer` 04:10 → `/usr/local/bin/emlak-yedek.sh`: 102'de yedek, kopyası LXC 101 `/opt/monodeal/yedek/gunluk` |
| İzleme | LXC 101 `emlak-izle.timer` → `http://192.168.1.22:8765/saglik` + yedek tazeliği → HA bildirimi |

Ağ yalıtımı: LXC 102 ev ağına (HA, Proxmox, modem, LXC 101 servisleri), özel ağlara ve IPv6'ya çıkamaz;
yalnız internete çıkar. Ev ağından 102'ye yalnız LXC 101 → 8765 (sağlık kontrolü) girebilir.
Bu kurallar ana makinede olduğu için container içindeki root bile değiştiremez.

## Dağıtım

```
python sunucu/deploy/lxc/dagit.py          # kodu yükler, pub get, servisi yeniden başlatır, /saglik bekler
python sunucu/deploy/lxc/dagit.py --kurulum # yalnız kodu koyar
```
Öncesinde yedek: `ssh root@192.168.1.50 /usr/local/bin/emlak-yedek.sh` (ya da Proxmox kabuğundan).
Proxmox root şifresi `C:\HomeAssistant\proxmox.txt` (repoda değil).

Gizli ortam değişkenleri (Google/Facebook istemci kimlikleri, destek e-postası) yalnız LXC 102'deki
`/etc/systemd/system/emlakdeal.service` içinde; buradaki kopya onlarsız.

## Geri dönüş (11 Ekim 2026 öncesi düzen)
LXC 101'de eski kurulum durdurulmuş halde duruyor (`monodeal.service`, `tailscaled` devre dışı).
Geri dönmek için: 102'de `tailscaled` ve `emlakdeal` durdur → güncel DB'yi ve `/var/lib/tailscale/tailscaled.state`'i 101'e geri taşı → 101'de ikisini başlat.
