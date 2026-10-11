#!/usr/bin/env python3
"""Emlak Deal DB yedeği (LXC): sqlite online backup -> integrity_check -> gzip -> 14 dosya sakla."""
import glob, gzip, os, shutil, sqlite3, sys, tempfile, time

DB = os.environ.get('EMLAK_DB', '/opt/monodeal/src/sunucu/emlakdeal.db')
DIZIN = os.environ.get('EMLAK_YEDEK_DIZIN', '/opt/monodeal/yedek/gunluk')
SAKLA = int(os.environ.get('EMLAK_YEDEK_SAKLA', '14'))

os.makedirs(DIZIN, mode=0o700, exist_ok=True)
damga = time.strftime('%Y%m%d-%H%M%S')
with tempfile.TemporaryDirectory(dir=DIZIN) as tmp:
    ham = os.path.join(tmp, 'k.db')
    kaynak = sqlite3.connect(f'file:{DB}?mode=ro', uri=True, timeout=30)
    hedef = sqlite3.connect(ham)
    kaynak.backup(hedef)
    kaynak.close()
    sonuc = hedef.execute('PRAGMA integrity_check').fetchone()[0]
    kul = hedef.execute('SELECT COUNT(*) FROM kullanicilar').fetchone()[0]
    hedef.close()
    if sonuc != 'ok':
        print(f'YEDEK HATASI: integrity_check={sonuc}', file=sys.stderr)
        sys.exit(1)
    cikti = os.path.join(DIZIN, f'emlakdeal-{damga}.db.gz')
    with open(ham, 'rb') as f, gzip.open(cikti, 'wb', compresslevel=9) as g:
        shutil.copyfileobj(f, g)
    os.chmod(cikti, 0o600)
print(f'yedek: {cikti} ({os.path.getsize(cikti)} bayt, kullanıcı={kul})')
for eski in sorted(glob.glob(os.path.join(DIZIN, 'emlakdeal-*.db.gz')))[:-SAKLA]:
    os.remove(eski)
