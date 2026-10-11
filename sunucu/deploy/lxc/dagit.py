"""Emlak Deal sunucusunu LXC 102'ye (yalıtılmış oyun container'ı) dağıtır.
Kullanım: python dagit102.py [--kurulum]   (--kurulum: servisi yeniden başlatmaz, yalnız kodu koyar)
Akış: yerel tar -> Proxmox sftp -> pct push 102 -> önceki src yedeği -> aç -> pub get (emlak) -> restart -> /saglik."""
import io, os, sys, tarfile, paramiko

sys.stdout.reconfigure(encoding='utf-8')
REPO = r'C:\Users\soner\emlakdeal'
DOSYALAR = ['cekirdek/lib', 'cekirdek/pubspec.yaml', 'sunucu/bin', 'sunucu/pubspec.yaml', 'sunucu/pubspec.lock']
kurulum = '--kurulum' in sys.argv

buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode='w:gz') as t:
    for d in DOSYALAR:
        t.add(os.path.join(REPO, d), arcname=d)
print('tar', len(buf.getvalue()), 'bayt')

sifre = open(r'C:\HomeAssistant\proxmox.txt', encoding='utf-8').read().strip().splitlines()[-1].strip()
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('192.168.1.50', username='root', password=sifre, timeout=15)
s = c.open_sftp()
s.putfo(io.BytesIO(buf.getvalue()), '/tmp/emlak_src.tgz')
s.close()


def calis(k, zaman=600):
    _, o, e = c.exec_command(k, timeout=zaman)
    cikti = o.read().decode('utf-8', 'replace') + e.read().decode('utf-8', 'replace')
    kod = o.channel.recv_exit_status()
    if cikti.strip():
        print(cikti.strip())
    if kod:
        sys.exit(f'HATA ({kod})')


calis('pct push 102 /tmp/emlak_src.tgz /opt/emlakdeal/src_yeni.tgz && rm /tmp/emlak_src.tgz')
ic = r'''set -e
cd /opt/emlakdeal
mkdir -p src yedek
[ -d src/sunucu ] && tar czf yedek/src_onceki.tgz --exclude='*.db*' --exclude='.dart_tool' src || true
tar xzf src_yeni.tgz -C src && rm src_yeni.tgz
chmod -R u=rwX,go=rX src && chown -R emlak:emlak /opt/emlakdeal && chmod 700 /opt/emlakdeal
cd src/sunucu
runuser -u emlak -- env HOME=/opt/emlakdeal PUB_CACHE=/opt/emlakdeal/.pub-cache /opt/dart-sdk/bin/dart pub get >/dev/null
'''
if not kurulum:
    ic += r'''systemctl restart emlakdeal
for i in $(seq 1 40); do sleep 2; curl -fs localhost:8765/saglik && exit 0; done
journalctl -u emlakdeal -n 30 --no-pager; exit 1
'''
calis("pct exec 102 -- bash -c " + "'" + ic.replace("'", "'\\''") + "'")
print('\nDAGITIM-TAMAM')
