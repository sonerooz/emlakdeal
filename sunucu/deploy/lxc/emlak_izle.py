#!/usr/bin/env python3
"""Emlak Deal izleme (LXC, 5 dk'da bir): /saglik, yedek yaşı, disk. Sorun/düzelme Home Assistant webhook'u ile telefona bildirilir."""
import glob, json, os, shutil, time, urllib.request

SAGLIK = os.environ.get('EMLAK_SAGLIK', 'http://127.0.0.1:8765/saglik')
YEDEK = os.environ.get('EMLAK_YEDEK_DIZIN', '/opt/monodeal/yedek/gunluk')
YEDEK_ESIK_SAAT = 36
DISK_ESIK = 85
WEBHOOK = os.environ.get('EMLAK_HA_WEBHOOK', '')
DURUM = '/var/lib/emlak_izle.json'
HATIRLAT_SN = 6 * 3600
ART_ARDA = 2

def sorunlar():
    s = []
    try:
        with urllib.request.urlopen(SAGLIK, timeout=5) as r:
            if not r.read().decode().startswith('ok'):
                s.append('/saglik beklenmeyen yanıt verdi')
    except Exception as e:
        s.append(f'/saglik yanıt vermiyor ({type(e).__name__})')
    dosyalar = glob.glob(os.path.join(YEDEK, 'emlakdeal-*.db.gz'))
    if not dosyalar:
        s.append('hiç yedek yok')
    else:
        yas = (time.time() - max(os.path.getmtime(f) for f in dosyalar)) / 3600
        if yas > YEDEK_ESIK_SAAT:
            s.append(f'son yedek {yas:.0f} saat önce')
    u = shutil.disk_usage('/')
    yuzde = u.used * 100 // u.total
    if yuzde >= DISK_ESIK:
        s.append(f'disk %{yuzde} dolu')
    return s

def bildir(mesaj):
    print(mesaj)
    if not WEBHOOK:
        return
    istek = urllib.request.Request(WEBHOOK, data=json.dumps({'mesaj': mesaj}).encode(), headers={'Content-Type': 'application/json'})
    try:
        urllib.request.urlopen(istek, timeout=10).read()
    except Exception as e:
        print('bildirim gönderilemedi:', e)

try:
    d = json.load(open(DURUM))
except Exception:
    d = {'art_arda': 0, 'bildirildi': 0, 'bozuk': False}

s = sorunlar()
if s:
    d['art_arda'] += 1
    simdi = time.time()
    if d['art_arda'] >= ART_ARDA and (not d['bozuk'] or simdi - d['bildirildi'] > HATIRLAT_SN):
        bildir('Emlak Deal sunucusu: ' + '; '.join(s))
        d['bozuk'], d['bildirildi'] = True, simdi
else:
    if d['bozuk']:
        bildir('Emlak Deal sunucusu: sorun giderildi, her şey yolunda.')
    d = {'art_arda': 0, 'bildirildi': 0, 'bozuk': False}
json.dump(d, open(DURUM, 'w'))
