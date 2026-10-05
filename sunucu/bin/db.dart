// Üyelik veritabanı (SQLite): hesaplar, oturumlar, oyun geçmişi, başarımlar.
// Google/Facebook/Apple kimlikleri için sütunlar hazır; şimdilik misafir (cihaz anahtarı) ve e-posta/şifre.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:emlakdeal_cekirdek/seviye.dart';
import 'package:sqlite3/sqlite3.dart';

import 'filtre.dart';

class Db {
  Db(String yol) : _db = sqlite3.open(yol) {
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS kullanicilar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nick TEXT NOT NULL UNIQUE COLLATE NOCASE,
        avatar TEXT NOT NULL DEFAULT '🦊',
        cihaz_anahtari TEXT UNIQUE,
        eposta TEXT UNIQUE COLLATE NOCASE,
        sifre_hash TEXT,
        google_id TEXT UNIQUE,
        facebook_id TEXT UNIQUE,
        apple_id TEXT UNIQUE,
        altin INTEGER NOT NULL DEFAULT 0,
        xp INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        oyun INTEGER NOT NULL DEFAULT 0,
        galibiyet INTEGER NOT NULL DEFAULT 0,
        online_oyun INTEGER NOT NULL DEFAULT 0,
        online_galibiyet INTEGER NOT NULL DEFAULT 0,
        olusturma TEXT NOT NULL,
        son_giris TEXT NOT NULL
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS oturumlar (
        token TEXT PRIMARY KEY,
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        olusturma TEXT NOT NULL,
        son_kullanim TEXT NOT NULL
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS oyun_gecmisi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        tarih TEXT NOT NULL,
        mod TEXT NOT NULL,
        kazandi INTEGER NOT NULL,
        rakip INTEGER NOT NULL,
        zorluk INTEGER NOT NULL DEFAULT 1,
        xp INTEGER NOT NULL,
        altin INTEGER NOT NULL
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS basarimlar (
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        basarim TEXT NOT NULL,
        tarih TEXT NOT NULL,
        PRIMARY KEY (kullanici_id, basarim)
      )''');
    try {
      _db.execute('ALTER TABLE kullanicilar ADD COLUMN son_bonus TEXT');
    } catch (_) {}
    try {
      _db.execute('ALTER TABLE kullanicilar ADD COLUMN ses INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      _db.execute('ALTER TABLE kullanicilar ADD COLUMN bonus_gun INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    for (final sutun in ['kart_arkasi TEXT NOT NULL DEFAULT \'klasik\'', 'masa TEXT NOT NULL DEFAULT \'yesil\'']) {
      try {
        _db.execute('ALTER TABLE kullanicilar ADD COLUMN $sutun');
      } catch (_) {}
    }
    for (final sutun in ['gunluk_tarih TEXT', 'gunluk_bot_altin INTEGER NOT NULL DEFAULT 0']) {
      try {
        _db.execute('ALTER TABLE kullanicilar ADD COLUMN $sutun');
      } catch (_) {}
    }
    _db.execute('''
      CREATE TABLE IF NOT EXISTS gorevler (
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        tarih TEXT NOT NULL,
        gorev TEXT NOT NULL,
        ilerleme INTEGER NOT NULL DEFAULT 0,
        alindi INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (kullanici_id, tarih, gorev)
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS emanetler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_id INTEGER NOT NULL,
        oda TEXT NOT NULL,
        miktar INTEGER NOT NULL,
        durum TEXT NOT NULL,
        tarih TEXT NOT NULL
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS esyalar (
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        esya TEXT NOT NULL,
        tarih TEXT NOT NULL,
        PRIMARY KEY (kullanici_id, esya)
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS arkadaslar (
        kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        arkadas_id INTEGER NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
        tarih TEXT NOT NULL,
        PRIMARY KEY (kullanici_id, arkadas_id)
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS hatalar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tarih TEXT NOT NULL,
        kullanici_id INTEGER,
        surum TEXT,
        cihaz TEXT,
        mesaj TEXT NOT NULL,
        yigin TEXT
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS olaylar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tarih TEXT NOT NULL,
        kullanici_id INTEGER,
        ad TEXT NOT NULL,
        veri TEXT
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sikayetler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kim INTEGER,
        hedef INTEGER,
        neden TEXT NOT NULL,
        notu TEXT,
        baglam TEXT,
        zaman TEXT NOT NULL,
        durum TEXT NOT NULL DEFAULT 'yeni'
      )''');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_sikayet_hedef ON sikayetler(hedef, zaman)');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_sikayet_kim ON sikayetler(kim, hedef, zaman)');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS engeller (
        kim INTEGER NOT NULL,
        hedef INTEGER NOT NULL,
        zaman TEXT NOT NULL,
        PRIMARY KEY (kim, hedef)
      )''');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_engel_hedef ON engeller(hedef)');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS fb_silme (
        kod TEXT PRIMARY KEY,
        zaman TEXT NOT NULL,
        durum TEXT NOT NULL
      )''');
    for (final sutun in ['model TEXT', 'dil TEXT', 'sayac INTEGER NOT NULL DEFAULT 1', 'iz TEXT', 'kaynak TEXT', 'anahtar TEXT', 'son_gorulme TEXT']) {
      try {
        _db.execute('ALTER TABLE hatalar ADD COLUMN $sutun');
      } catch (_) {}
    }
    _db.execute('CREATE INDEX IF NOT EXISTS ix_hata_anahtar ON hatalar(anahtar)');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_gecmis_kullanici ON oyun_gecmisi(kullanici_id)');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_lider ON kullanicilar(level DESC, xp DESC)');
    _misafirleriAdlandir();
  }

  static const _girisli = '(eposta IS NOT NULL OR google_id IS NOT NULL OR facebook_id IS NOT NULL OR apple_id IS NOT NULL)';

  /// Girişi (e-posta/Google/Facebook/Apple) olmayan hesap misafirdir.
  bool misafirMi(int id) => _db.select('SELECT 1 FROM kullanicilar WHERE id = ? AND $_girisli', [id]).isEmpty;

  /// Tohumdan türetilen benzersiz "Misafir-12345" adı.
  String _misafirAdi(String tohum) {
    final h = sha256.convert(utf8.encode('misafir:$tohum')).bytes;
    var n = ((h[0] << 16) | (h[1] << 8) | h[2]) % 90000;
    while (true) {
      final ad = 'Misafir-${10000 + n}';
      if (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ?', [ad]).isEmpty) return ad;
      n = (n + 1) % 90000;
    }
  }

  void _misafirleriAdlandir() {
    for (final r in _db.select("SELECT id, cihaz_anahtari FROM kullanicilar WHERE NOT $_girisli AND (nick NOT LIKE 'Misafir-%' OR avatar != 'misafir' OR ses != 0)")) {
      final id = r['id'] as int;
      final ad = _db.select("SELECT 1 FROM kullanicilar WHERE id = ? AND nick LIKE 'Misafir-%'", [id]).isNotEmpty
          ? null
          : _misafirAdi((r['cihaz_anahtari'] as String?) ?? 'id$id');
      _db.execute("UPDATE kullanicilar SET avatar = 'misafir', ses = 0${ad != null ? ', nick = ?' : ''} WHERE id = ?", [if (ad != null) ad, id]);
    }
  }

  /// Bağlanan misafir emoji avatarına kavuşur; istenen ad geçerliyse Misafir-xxxxx adının yerine geçer.
  void _misafirdenCik(int id, String? istenen) {
    final r = _db.select('SELECT nick, avatar FROM kullanicilar WHERE id = ?', [id]).first;
    if (r['avatar'] == 'misafir') {
      _db.execute('UPDATE kullanicilar SET avatar = ? WHERE id = ?', [avatarlar[_rng.nextInt(avatarlar.length)], id]);
    }
    if ((r['nick'] as String).startsWith('Misafir-') && istenen != null && nickKurali.hasMatch(istenen.trim())) {
      _db.execute('UPDATE kullanicilar SET nick = ? WHERE id = ?', [nickUret(istenen), id]);
    }
  }

  final Database _db;
  final _rng = Random.secure();

  /// Gizlilik politikasındaki ~12 ay saklama süresi: eski hata, olay ve işlenmiş şikayet kayıtlarını siler.
  void eskiKayitlariTemizle() {
    final sinir = _onceki(const Duration(days: 365));
    _db.execute('DELETE FROM hatalar WHERE COALESCE(son_gorulme, tarih) < ?', [sinir]);
    _db.execute('DELETE FROM olaylar WHERE tarih < ?', [sinir]);
    _db.execute("DELETE FROM sikayetler WHERE zaman < ? AND durum != 'yeni'", [sinir]);
  }

  String _onceki(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();
  String _simdi() => DateTime.now().toUtc().toIso8601String();
  String _token() => base64Url.encode(List<int>.generate(32, (_) => _rng.nextInt(256)));
  String sifreHash(String sifre, String tuz) => sha256.convert(utf8.encode('$tuz:$sifre')).toString();

  static final nickKurali = RegExp(r'^[A-Za-zÇĞİÖŞÜçğıöşü0-9_ ]{3,16}$');

  /// Türkiye saatiyle bugünün tarihi (YYYY-MM-DD) ve haftanın günü (Pzt=1..Paz=7).
  static ({String tarih, int gun}) _bugun() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 3));
    return (tarih: t.toIso8601String().substring(0, 10), gun: t.weekday);
  }

  /// 7 günlük seri ödülü: 1-6. gün küçük kutu, 7. gün büyük kutu; kaçırılan gün seriyi başa sarar.
  static const bonusOdulleri = [100, 150, 200, 250, 300, 400, 1000];

  /// Bugünkü ödül durumu: hazır mı, kaçıncı gün (1-7). Alındıysa gün = bugün alınan gün.
  ({bool hazir, int gun}) _bonusPlan(int id) {
    final r = _db.select('SELECT son_bonus, bonus_gun FROM kullanicilar WHERE id = ?', [id]).first;
    final b = _bugun();
    final son = r['son_bonus'] as String?;
    final gun = r['bonus_gun'] as int;
    if (son == b.tarih) return (hazir: false, gun: gun.clamp(1, 7));
    final dun = DateTime.parse(b.tarih).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    return (hazir: true, gun: son == dun ? gun % 7 + 1 : 1);
  }

  Map<String, dynamic> bonusDurumu(int id) {
    if (misafirMi(id)) return {'bonusHazir': false, 'bonusGun': 1, 'bonusMiktar': bonusOdulleri[0], 'bonusOdulleri': bonusOdulleri};
    final p = _bonusPlan(id);
    return {'bonusHazir': p.hazir, 'bonusGun': p.gun, 'bonusMiktar': bonusOdulleri[p.gun - 1], 'bonusOdulleri': bonusOdulleri};
  }

  /// Bonusu verir; zaten alındıysa alindi=false.
  Map<String, dynamic> bonusAl(int id) {
    final p = _bonusPlan(id);
    if (!p.hazir) return {'alindi': false, ...bonusDurumu(id), 'profil': profil(id)};
    final m = bonusOdulleri[p.gun - 1];
    _db.execute('UPDATE kullanicilar SET altin = altin + ?, son_bonus = ?, bonus_gun = ? WHERE id = ?', [m, _bugun().tarih, p.gun, id]);
    return {'alindi': true, 'bonus': m, 'buyuk': p.gun == 7, ...bonusDurumu(id), 'profil': profil(id)};
  }

  Map<String, dynamic> profil(int id) {
    final r = _db.select('SELECT * FROM kullanicilar WHERE id = ?', [id]).first;
    final lv = levelHesapla(r['xp'] as int);
    return {
      ...bonusDurumu(id),
      'gorevHazir': gorevHazirSayisi(id),
      'botKota': botKotaDurumu(id),
      'misafir': misafirMi(id),
      'id': r['id'],
      'nick': r['nick'],
      'avatar': r['avatar'],
      'ses': r['ses'],
      'altin': r['altin'],
      'xp': r['xp'],
      'level': lv.level,
      'levelXp': lv.levelXp,
      'esik': lv.esik,
      'oyun': r['oyun'],
      'galibiyet': r['galibiyet'],
      'onlineOyun': r['online_oyun'],
      'onlineGalibiyet': r['online_galibiyet'],
      'eposta': r['eposta'],
      'google': r['google_id'] != null,
      'facebook': r['facebook_id'] != null,
      'apple': r['apple_id'] != null,
      'basarimlar': [for (final b in _db.select('SELECT basarim FROM basarimlar WHERE kullanici_id = ?', [id])) b['basarim']],
      'esyalar': esyalar(id),
      'kartArkasi': r['kart_arkasi'] ?? 'klasik',
      'masa': r['masa'] ?? 'yesil',
    };
  }

  /// Nick boşsa/çakışıyorsa uygun bir nick üretir.
  String nickUret(String? istenen) {
    var temel = (istenen ?? '').trim();
    if (!nickKurali.hasMatch(temel)) temel = 'Oyuncu';
    if (kufurluMu(temel)) return _oyuncuAdi();
    var aday = temel;
    var n = 1;
    while (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ?', [aday]).isNotEmpty) {
      n++;
      aday = '$temel$n';
    }
    return aday;
  }

  /// Rastgele benzersiz "Oyuncu-12345" adı (uygunsuz isim sıfırlama).
  String _oyuncuAdi() {
    while (true) {
      final ad = 'Oyuncu-${10000 + _rng.nextInt(90000)}';
      if (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ?', [ad]).isEmpty) return ad;
    }
  }

  /// Misafir hesap: cihaz anahtarıyla kayıt (varsa giriş).
  ({int id, String token, bool yeni}) misafir(String cihaz, {String? nick, String? avatar}) {
    final mevcut = _db.select('SELECT id FROM kullanicilar WHERE cihaz_anahtari = ?', [cihaz]);
    if (mevcut.isNotEmpty) {
      final id = mevcut.first['id'] as int;
      _db.execute('UPDATE kullanicilar SET son_giris = ? WHERE id = ?', [_simdi(), id]);
      return (id: id, token: oturumAc(id), yeni: false);
    }
    final ad = _misafirAdi(cihaz);
    _db.execute("INSERT INTO kullanicilar (nick, avatar, cihaz_anahtari, olusturma, son_giris) VALUES (?, 'misafir', ?, ?, ?)", [ad, cihaz, _simdi(), _simdi()]);
    final id = _db.lastInsertRowId;
    return (id: id, token: oturumAc(id), yeni: true);
  }

  /// Sosyal kimlik (google/facebook/apple): varsa giriş, yoksa [cihazId] hesabına bağla ya da yeni hesap.
  ({int id, String token}) sosyal(String saglayici, String kimlik, {int? bagla, String? nick}) {
    final sutun = '${saglayici}_id';
    final mevcut = _db.select('SELECT id FROM kullanicilar WHERE $sutun = ?', [kimlik]);
    if (mevcut.isNotEmpty) {
      final id = mevcut.first['id'] as int;
      return (id: id, token: oturumAc(id));
    }
    if (bagla != null) {
      _db.execute('UPDATE kullanicilar SET $sutun = ? WHERE id = ?', [kimlik, bagla]);
      _misafirdenCik(bagla, nick);
      return (id: bagla, token: oturumAc(bagla));
    }
    final ad = nickUret(nick);
    _db.execute('INSERT INTO kullanicilar (nick, avatar, $sutun, olusturma, son_giris) VALUES (?, ?, ?, ?, ?)', [ad, avatarlar[_rng.nextInt(avatarlar.length)], kimlik, _simdi(), _simdi()]);
    final id = _db.lastInsertRowId;
    return (id: id, token: oturumAc(id));
  }

  /// E-posta/şifre: kayıt (hesaba bağlama) ya da giriş. Hata metni döner, null = başarılı.
  String? epostaBagla(int id, String eposta, String sifre) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(eposta)) return 'Geçersiz e-posta.';
    if (sifre.length < 6) return 'Şifre en az 6 karakter.';
    if (_db.select('SELECT 1 FROM kullanicilar WHERE eposta = ? AND id != ?', [eposta, id]).isNotEmpty) return 'Bu e-posta başka hesapta.';
    final tuz = _token().substring(0, 12);
    _db.execute('UPDATE kullanicilar SET eposta = ?, sifre_hash = ? WHERE id = ?', [eposta, '$tuz\$${sifreHash(sifre, tuz)}', id]);
    _misafirdenCik(id, null);
    return null;
  }

  ({int id, String token})? epostaGiris(String eposta, String sifre) {
    final r = _db.select('SELECT id, sifre_hash FROM kullanicilar WHERE eposta = ?', [eposta]);
    if (r.isEmpty || r.first['sifre_hash'] == null) return null;
    final parcalar = (r.first['sifre_hash'] as String).split(r'$');
    if (parcalar.length != 2 || sifreHash(sifre, parcalar[0]) != parcalar[1]) return null;
    final id = r.first['id'] as int;
    _db.execute('UPDATE kullanicilar SET son_giris = ? WHERE id = ?', [_simdi(), id]);
    return (id: id, token: oturumAc(id));
  }

  String oturumAc(int id) {
    final t = _token();
    _db.execute('INSERT INTO oturumlar (token, kullanici_id, olusturma, son_kullanim) VALUES (?, ?, ?, ?)', [t, id, _simdi(), _simdi()]);
    return t;
  }

  void oturumKapat(String token) => _db.execute('DELETE FROM oturumlar WHERE token = ?', [token]);

  int? oturumKim(String? token) {
    if (token == null || token.isEmpty) return null;
    final r = _db.select('SELECT kullanici_id FROM oturumlar WHERE token = ?', [token]);
    if (r.isEmpty) return null;
    _db.execute('UPDATE oturumlar SET son_kullanim = ? WHERE token = ?', [_simdi(), token]);
    return r.first['kullanici_id'] as int;
  }

  /// Profil güncelle; hata metni ya da null.
  String? profilGuncelle(int id, {String? nick, String? avatar, int? ses}) {
    if (ses != null) {
      if (ses < 0 || ses >= sesAdlari.length) return 'Geçersiz ses.';
      _db.execute('UPDATE kullanicilar SET ses = ? WHERE id = ?', [ses, id]);
    }
    if (nick != null) {
      final n = nick.trim();
      if (!nickKurali.hasMatch(n)) return 'Nickname 3-16 karakter; harf, rakam, alt çizgi.';
      if (kufurluMu(n)) return kotuIsimMesaji;
      if (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ? AND id != ?', [n, id]).isNotEmpty) return 'Bu nickname alınmış.';
      _db.execute('UPDATE kullanicilar SET nick = ? WHERE id = ?', [n, id]);
    }
    if (avatar != null) {
      if (!avatarlar.contains(avatar)) return 'Geçersiz avatar.';
      _db.execute('UPDATE kullanicilar SET avatar = ? WHERE id = ?', [avatar, id]);
    }
    return null;
  }

  /// Botlu / bahissiz oyunlardan günlük kazanılabilecek altın sınırı.
  static const botGunlukLimit = 10000;

  ({int kullanilan, int kalan}) _kotaOku(int id) {
    final r = _db.select('SELECT gunluk_tarih, gunluk_bot_altin FROM kullanicilar WHERE id = ?', [id]).first;
    final k = r['gunluk_tarih'] == _bugun().tarih ? r['gunluk_bot_altin'] as int : 0;
    return (kullanilan: k, kalan: max(0, botGunlukLimit - k));
  }

  Map<String, dynamic> botKotaDurumu(int id) {
    final k = _kotaOku(id);
    return {'kullanilan': k.kullanilan, 'limit': botGunlukLimit, 'doldu': k.kalan <= 0};
  }

  int altinOku(int id) => _db.select('SELECT altin FROM kullanicilar WHERE id = ?', [id]).first['altin'] as int;

  /// XP ekler; (önceki level, sonraki level) döner.
  ({int once, int sonra}) _xpEkle(int id, int xp) {
    final once = levelHesapla(_db.select('SELECT xp FROM kullanicilar WHERE id = ?', [id]).first['xp'] as int).level;
    _db.execute('UPDATE kullanicilar SET xp = xp + ? WHERE id = ?', [xp, id]);
    final sonra = levelHesapla(_db.select('SELECT xp FROM kullanicilar WHERE id = ?', [id]).first['xp'] as int).level;
    _db.execute('UPDATE kullanicilar SET level = ? WHERE id = ?', [sonra, id]);
    return (once: once, sonra: sonra);
  }

  /// Oyun sonucu: XP/altın verir, istatistikleri günceller; ödül ve level bilgisini döner.
  /// [altinVer]=false (bahisli oda): taban altın yok. [kotali]: altın günlük bot kotasına tabi.
  Map<String, dynamic> sonuc(int id, {required bool kazandi, required int rakip, required bool online, int zorluk = 1, bool altinVer = true, bool kotali = true, bool bahisli = false}) {
    final o = odul(kazandi: kazandi, rakip: rakip, online: online, zorluk: zorluk);
    var altin = altinVer ? o.altin : 0;
    var limitDoldu = false;
    if (altinVer && kotali) {
      final k = _kotaOku(id);
      if (altin > k.kalan) {
        altin = k.kalan;
        limitDoldu = true;
      }
      if (altin > 0) {
        _db.execute('UPDATE kullanicilar SET gunluk_tarih = ?, gunluk_bot_altin = ? WHERE id = ?', [_bugun().tarih, k.kullanilan + altin, id]);
      }
    }
    _db.execute('''
      UPDATE kullanicilar SET altin = altin + ?, oyun = oyun + 1, galibiyet = galibiyet + ?,
        online_oyun = online_oyun + ?, online_galibiyet = online_galibiyet + ? WHERE id = ?''',
        [altin, kazandi ? 1 : 0, online ? 1 : 0, (online && kazandi) ? 1 : 0, id]);
    // XP yalnız online (altınlı oda) oyunlardan gelir; botlu oyunlar sadece altın kasmak içindir.
    final xp = online ? o.xp : 0;
    final lv = _xpEkle(id, xp);
    _db.execute('INSERT INTO oyun_gecmisi (kullanici_id, tarih, mod, kazandi, rakip, zorluk, xp, altin) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, _simdi(), online ? 'online' : 'bot', kazandi ? 1 : 0, rakip, zorluk, xp, altin]);
    if (!misafirMi(id)) {
      _gorevIlerlet(id, {
        'oyna': 1,
        if (kazandi) 'kazan': 1,
        if (online) 'online_oyna': 1,
        if (online && kazandi) 'online_kazan': 1,
        if (!online && kazandi) 'bot_kazan': 1,
        if (!online && kazandi && zorluk == 2) 'zor_kazan': 1,
        if (kazandi && rakip >= 3) 'kalabalik_kazan': 1,
      });
    }
    return {
      'xp': xp,
      'altin': altin,
      'limitDoldu': limitDoldu,
      'level': lv.sonra,
      'levelAtladi': lv.sonra > lv.once,
      'profil': profil(id),
    };
  }

  // ---- Günlük görevler ----
  static const gorevHavuzu = <String, ({String ad, int hedef, int xp, int altin})>{
    'oyna': (ad: '3 oyun oyna', hedef: 3, xp: 40, altin: 40),
    'kazan': (ad: '2 oyun kazan', hedef: 2, xp: 70, altin: 70),
    'online_oyna': (ad: '1 online oyun oyna', hedef: 1, xp: 50, altin: 60),
    'online_kazan': (ad: '1 online oyun kazan', hedef: 1, xp: 100, altin: 120),
    'bot_kazan': (ad: 'Botlara karşı 3 oyun kazan', hedef: 3, xp: 90, altin: 90),
    'zor_kazan': (ad: 'Zor botlara karşı 1 oyun kazan', hedef: 1, xp: 90, altin: 100),
    'kalabalik_kazan': (ad: '4 veya 5 kişilik bir oyun kazan', hedef: 1, xp: 80, altin: 80),
  };

  /// Günün 4 görevi: tarihe göre deterministik seçim (herkese aynı).
  List<String> _bugunGorevleri() {
    final t = _bugun().tarih;
    final anahtarlar = gorevHavuzu.keys.toList();
    final r = Random(t.codeUnits.fold<int>(7, (a, c) => a * 31 + c));
    anahtarlar.shuffle(r);
    return anahtarlar.take(4).toList();
  }

  void _gorevIlerlet(int id, Map<String, int> olay) {
    final t = _bugun().tarih;
    for (final g in _bugunGorevleri()) {
      final artis = olay[g];
      if (artis == null) continue;
      final hedef = gorevHavuzu[g]!.hedef;
      _db.execute('INSERT OR IGNORE INTO gorevler (kullanici_id, tarih, gorev) VALUES (?, ?, ?)', [id, t, g]);
      _db.execute('UPDATE gorevler SET ilerleme = MIN(?, ilerleme + ?) WHERE kullanici_id = ? AND tarih = ? AND gorev = ? AND alindi = 0', [hedef, artis, id, t, g]);
    }
  }

  List<Map<String, dynamic>> gorevler(int id) {
    final t = _bugun().tarih;
    final kayit = {
      for (final r in _db.select('SELECT gorev, ilerleme, alindi FROM gorevler WHERE kullanici_id = ? AND tarih = ?', [id, t])) r['gorev'] as String: r,
    };
    return [
      for (final g in _bugunGorevleri())
        () {
          final d = gorevHavuzu[g]!;
          final r = kayit[g];
          final il = r == null ? 0 : r['ilerleme'] as int;
          return <String, dynamic>{'id': g, 'ad': d.ad, 'hedef': d.hedef, 'ilerleme': il, 'xp': d.xp, 'altin': d.altin, 'tamam': il >= d.hedef, 'alindi': r != null && r['alindi'] == 1};
        }(),
    ];
  }

  int gorevHazirSayisi(int id) => misafirMi(id) ? 0 : gorevler(id).where((g) => g['tamam'] == true && g['alindi'] == false).length;

  /// Tamamlanan görevin ödülünü verir (günde bir kez); verilemezse null.
  Map<String, dynamic>? gorevAl(int id, String gorev) {
    if (!_bugunGorevleri().contains(gorev)) return null;
    final g = gorevler(id).firstWhere((x) => x['id'] == gorev);
    if (g['tamam'] != true || g['alindi'] == true) return null;
    final t = _bugun().tarih;
    _db.execute('UPDATE gorevler SET alindi = 1 WHERE kullanici_id = ? AND tarih = ? AND gorev = ?', [id, t, gorev]);
    _db.execute('UPDATE kullanicilar SET altin = altin + ? WHERE id = ?', [g['altin'], id]);
    final lv = _xpEkle(id, g['xp'] as int);
    return {'xp': g['xp'], 'altin': g['altin'], 'level': lv.sonra, 'levelAtladi': lv.sonra > lv.once};
  }

  // ---- Bahis emanetleri ----
  /// Her oyuncudan [miktar] altın keser. Yetersiz bakiyesi olan ilk oyuncunun id'sini döner; hepsi yeterliyse null.
  int? bahisKes(List<int> idler, int miktar, String oda) {
    for (final id in idler) {
      if (altinOku(id) < miktar) return id;
    }
    for (final id in idler) {
      _db.execute('UPDATE kullanicilar SET altin = altin - ? WHERE id = ?', [miktar, id]);
      _db.execute('INSERT INTO emanetler (kullanici_id, oda, miktar, durum, tarih) VALUES (?, ?, ?, ?, ?)', [id, oda, miktar, 'acik', _simdi()]);
    }
    return null;
  }

  /// Havuzun tamamı kazanana; odanın açık emanetleri kapanır.
  void emanetOde(String oda, int kazananId, int havuz) {
    _db.execute("UPDATE emanetler SET durum = 'odendi' WHERE oda = ? AND durum = 'acik'", [oda]);
    _db.execute('UPDATE kullanicilar SET altin = altin + ? WHERE id = ?', [havuz, kazananId]);
  }

  /// Oyuncunun emanetini iade eder.
  void emanetIade(String oda, int id) {
    for (final r in _db.select("SELECT id, miktar FROM emanetler WHERE oda = ? AND kullanici_id = ? AND durum = 'acik'", [oda, id])) {
      _db.execute("UPDATE emanetler SET durum = 'iade' WHERE id = ?", [r['id']]);
      _db.execute('UPDATE kullanicilar SET altin = altin + ? WHERE id = ?', [r['miktar'], id]);
    }
  }

  /// Oyuncunun emanetini kaybeder (oyunu terk etti / kaybetti).
  void emanetKayip(String oda, int id) {
    _db.execute("UPDATE emanetler SET durum = 'kayip' WHERE oda = ? AND kullanici_id = ? AND durum = 'acik'", [oda, id]);
  }

  /// Sunucu yeniden başlayınca yarım kalan bahisli oyunların bahislerini iade eder.
  int acikEmanetleriIadeEt() {
    var n = 0;
    for (final r in _db.select("SELECT id, kullanici_id, miktar FROM emanetler WHERE durum = 'acik'")) {
      _db.execute("UPDATE emanetler SET durum = 'iade_sunucu' WHERE id = ?", [r['id']]);
      _db.execute('UPDATE kullanicilar SET altin = altin + ? WHERE id = ?', [r['miktar'], r['kullanici_id']]);
      n++;
    }
    return n;
  }

  void basarimEkle(int id, String basarim) {
    _db.execute('INSERT OR IGNORE INTO basarimlar (kullanici_id, basarim, tarih) VALUES (?, ?, ?)', [id, basarim, _simdi()]);
  }

  // ------------------------------------------------------------ dükkân
  /// Satın alınabilir eşyalar: id → (ad, fiyat, tür). Tür: kart (kart arkası), masa (çuha), avatar.
  static const magaza = <String, (String, int, String)>{
    'kart_altin': ('Altın Kart Arkası', 300, 'kart'),
    'kart_gece': ('Gece Mavisi Kart Arkası', 300, 'kart'),
    'kart_mermer': ('Mermer Kart Arkası', 500, 'kart'),
    'masa_bordo': ('Bordo Çuha', 400, 'masa'),
    'masa_lacivert': ('Lacivert Çuha', 400, 'masa'),
    'masa_siyah': ('Siyah Çuha (VIP)', 800, 'masa'),
    'avatar_paket': ('Özel Avatarlar (8 adet)', 600, 'avatar'),
  };

  List<String> esyalar(int id) => [for (final r in _db.select('SELECT esya FROM esyalar WHERE kullanici_id = ?', [id])) r['esya'] as String];

  String? satinAl(int id, String esya) {
    final e = magaza[esya];
    if (e == null) return 'Böyle bir eşya yok.';
    if (esyalar(id).contains(esya)) return 'Zaten sende.';
    final altin = _db.select('SELECT altin FROM kullanicilar WHERE id = ?', [id]).first['altin'] as int;
    if (altin < e.$2) return 'Yeterli altın yok (${e.$2} gerekli).';
    _db.execute('UPDATE kullanicilar SET altin = altin - ? WHERE id = ?', [e.$2, id]);
    _db.execute('INSERT INTO esyalar (kullanici_id, esya, tarih) VALUES (?, ?, ?)', [id, esya, _simdi()]);
    return null;
  }

  String? secimKaydet(int id, {String? kartArkasi, String? masa}) {
    final sahip = {'klasik', 'yesil', ...esyalar(id)};
    if (kartArkasi != null) {
      if (!sahip.contains(kartArkasi)) return 'Bu kart arkası sende yok.';
      _db.execute('UPDATE kullanicilar SET kart_arkasi = ? WHERE id = ?', [kartArkasi, id]);
    }
    if (masa != null) {
      if (!sahip.contains(masa)) return 'Bu masa sende yok.';
      _db.execute('UPDATE kullanicilar SET masa = ? WHERE id = ?', [masa, id]);
    }
    return null;
  }

  // ------------------------------------------------------------ arkadaşlar
  String? arkadasEkle(int id, String nick) {
    final r = _db.select('SELECT id FROM kullanicilar WHERE nick = ?', [nick.trim()]);
    if (r.isEmpty) return 'Böyle bir oyuncu yok.';
    final a = r.first['id'] as int;
    if (a == id) return 'Kendini ekleyemezsin.';
    if (engelliMi(a, id)) return 'Bu oyuncuya istek gönderemezsin.';
    if (engelliMi(id, a)) return 'Önce engeli kaldırmalısın.';
    _db.execute('INSERT OR IGNORE INTO arkadaslar (kullanici_id, arkadas_id, tarih) VALUES (?, ?, ?)', [id, a, _simdi()]);
    return null;
  }

  void arkadasSil(int id, String nick) {
    _db.execute('DELETE FROM arkadaslar WHERE kullanici_id = ? AND arkadas_id = (SELECT id FROM kullanicilar WHERE nick = ?)', [id, nick.trim()]);
  }

  List<Map<String, dynamic>> arkadaslar(int id) => [
        for (final r in _db.select('SELECT k.id, k.nick, k.avatar, k.level, k.son_giris FROM arkadaslar a JOIN kullanicilar k ON k.id = a.arkadas_id WHERE a.kullanici_id = ? ORDER BY k.nick', [id]))
          {'id': r['id'], 'nick': r['nick'], 'avatar': r['avatar'], 'level': r['level'], 'sonGiris': r['son_giris']}
      ];

  int? idBul(String nick) {
    final r = _db.select('SELECT id FROM kullanicilar WHERE nick = ?', [nick.trim()]);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  // ------------------------------------------------------------ geçmiş / izleme
  List<Map<String, dynamic>> gecmis(int id, {int limit = 30}) => [
        for (final r in _db.select('SELECT tarih, mod, kazandi, rakip, zorluk, xp, altin FROM oyun_gecmisi WHERE kullanici_id = ? ORDER BY id DESC LIMIT ?', [id, limit]))
          {'tarih': r['tarih'], 'mod': r['mod'], 'kazandi': r['kazandi'] == 1, 'rakip': r['rakip'], 'zorluk': r['zorluk'], 'xp': r['xp'], 'altin': r['altin']}
      ];

  static String _kes(String s, int n) => s.length > n ? s.substring(0, n) : s;
  static String? _kesN(String? s, int n) => s == null || s.trim().isEmpty ? null : _kes(s.trim(), n);

  /// Hata kaydı: (sürüm + mesajın ilk satırı) başına tek kayıt; tekrarlar sayacı artırır.
  void hataKaydet({int? kullaniciId, String? surum, String? cihaz, String? model, String? dil, required String mesaj, String? yigin, int sayac = 1, List? iz, String? kaynak}) {
    final m = _kes(mesaj, 2000);
    final sv = _kesN(surum, 64);
    final anahtar = '${sv ?? ''}|${_kes(m.split('\n').first, 300)}';
    final y = yigin == null ? null : _kes(yigin, 8000);
    final kay = const {'flutter', 'zone', 'native'}.contains(kaynak) ? kaynak : null;
    String? izJson;
    if (iz != null && iz.isNotEmpty) {
      final l = [for (final e in iz.reversed.take(50).toList().reversed) _kes('$e', 300)];
      izJson = jsonEncode(l);
      while (izJson!.length > 8000 && l.isNotEmpty) {
        l.removeAt(0);
        izJson = jsonEncode(l);
      }
    }
    final adet = sayac.clamp(1, 1000);
    final simdi = _simdi();
    final mevcut = _db.select('SELECT id FROM hatalar WHERE anahtar = ? ORDER BY id LIMIT 1', [anahtar]);
    if (mevcut.isNotEmpty) {
      _db.execute(
          'UPDATE hatalar SET sayac = sayac + ?, son_gorulme = ?, kullanici_id = COALESCE(?, kullanici_id), cihaz = COALESCE(?, cihaz), model = COALESCE(?, model), dil = COALESCE(?, dil), '
          'yigin = COALESCE(?, yigin), iz = COALESCE(?, iz), kaynak = COALESCE(?, kaynak) WHERE id = ?',
          [adet, simdi, kullaniciId, _kesN(cihaz, 64), _kesN(model, 64), _kesN(dil, 16), y, izJson, kay, mevcut.first['id']]);
      return;
    }
    _db.execute(
        'INSERT INTO hatalar (tarih, kullanici_id, surum, cihaz, model, dil, mesaj, yigin, sayac, iz, kaynak, anahtar, son_gorulme) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [simdi, kullaniciId, sv, _kesN(cihaz, 64), _kesN(model, 64), _kesN(dil, 16), m, y, adet, izJson, kay, anahtar, simdi]);
  }

  /// Yönetim: son görülen 100 benzersiz hata, sayaca göre sıralı.
  List<Map<String, dynamic>> hatalarListe({int limit = 100}) => [
        for (final r in _db.select(
            'SELECT * FROM (SELECT * FROM hatalar ORDER BY COALESCE(son_gorulme, tarih) DESC LIMIT ?) ORDER BY sayac DESC, COALESCE(son_gorulme, tarih) DESC', [limit]))
          {
            'id': r['id'],
            'surum': r['surum'],
            'cihaz': r['cihaz'],
            'model': r['model'],
            'dil': r['dil'],
            'mesaj': r['mesaj'],
            'yigin': r['yigin'],
            'iz': r['iz'] == null ? null : jsonDecode(r['iz'] as String),
            'kaynak': r['kaynak'],
            'sayac': r['sayac'],
            'ilkGorulme': r['tarih'],
            'sonGorulme': r['son_gorulme'] ?? r['tarih'],
            'kullanici': r['kullanici_id'],
          }
      ];

  void olayKaydet({int? kullaniciId, required String ad, String? veri}) {
    _db.execute('INSERT INTO olaylar (tarih, kullanici_id, ad, veri) VALUES (?, ?, ?, ?)', [_simdi(), kullaniciId, ad, veri]);
  }

  Map<String, dynamic> ozet() => {
        'kullanici': _db.select('SELECT count(*) c FROM kullanicilar').first['c'],
        'oyun': _db.select('SELECT count(*) c FROM oyun_gecmisi').first['c'],
        'hata24s': _db.select('SELECT count(*) c FROM hatalar WHERE COALESCE(son_gorulme, tarih) > ?', [_onceki(const Duration(days: 1))]).first['c'],
        'olay24s': _db.select('SELECT count(*) c FROM olaylar WHERE tarih > ?', [_onceki(const Duration(days: 1))]).first['c'],
        'sonHatalar': [for (final r in _db.select('SELECT tarih, mesaj FROM hatalar ORDER BY id DESC LIMIT 5')) {'tarih': r['tarih'], 'mesaj': r['mesaj']}],
      };

  List<Map<String, dynamic>> liderlik({int limit = 50}) => [
        for (final r in _db.select('SELECT nick, avatar, level, xp, oyun, galibiyet, online_galibiyet FROM kullanicilar WHERE oyun > 0 AND $_girisli ORDER BY level DESC, xp DESC, galibiyet DESC LIMIT ?', [limit]))
          {'nick': r['nick'], 'avatar': r['avatar'], 'level': r['level'], 'xp': r['xp'], 'oyun': r['oyun'], 'galibiyet': r['galibiyet'], 'onlineGalibiyet': r['online_galibiyet']}
      ];

  // ------------------------------------------------------------ şikayet / engel
  static const sikayetNedenleri = {'hakaret', 'uygunsuz_isim', 'hile', 'spam', 'diger'};
  static const sikayetBaglamlari = {'oyun', 'profil', 'arkadas'};
  static const sikayetDurumlari = {'yeni', 'incelendi', 'islem_yapildi', 'reddedildi'};

  /// Şikayet kaydı; hata metni ya da null. Aynı kişi→hedef çifti 24 saatte bir kez sayılır.
  /// 24 saatte 3 farklı kişi şikayet ederse (girişli hesabın) adı "Oyuncu-XXXXX" olarak sıfırlanır.
  String? sikayetEt(int kim, String nick, String neden, String? not, String? baglam) {
    if (!sikayetNedenleri.contains(neden)) return 'Geçersiz şikayet nedeni.';
    if (baglam != null && !sikayetBaglamlari.contains(baglam)) baglam = null;
    final hedef = idBul(nick);
    if (hedef == null) return 'Böyle bir oyuncu yok.';
    if (hedef == kim) return 'Kendini şikayet edemezsin.';
    final esik = _onceki(const Duration(hours: 24));
    if (_db.select('SELECT 1 FROM sikayetler WHERE kim = ? AND hedef = ? AND zaman > ?', [kim, hedef, esik]).isNotEmpty) return null;
    final n = _kesN(not, 200);
    _db.execute('INSERT INTO sikayetler (kim, hedef, neden, notu, baglam, zaman) VALUES (?, ?, ?, ?, ?, ?)', [kim, hedef, neden, n, baglam ?? 'oyun', _simdi()]);
    final sayi = _db.select('SELECT count(DISTINCT kim) c FROM sikayetler WHERE hedef = ? AND zaman > ?', [hedef, esik]).first['c'] as int;
    if (sayi >= 3 && !misafirMi(hedef)) {
      final eski = _db.select('SELECT nick FROM kullanicilar WHERE id = ?', [hedef]).first['nick'] as String;
      if (!eski.startsWith('Oyuncu-')) {
        final yeni = _oyuncuAdi();
        _db.execute('UPDATE kullanicilar SET nick = ? WHERE id = ?', [yeni, hedef]);
        olayKaydet(kullaniciId: hedef, ad: 'sikayet_isim_sifirla', veri: '$eski -> $yeni');
        print('SIKAYET: $eski adi 3 sikayet nedeniyle $yeni yapildi');
      }
    }
    return null;
  }

  List<Map<String, dynamic>> sikayetListe({int limit = 200}) => [
        for (final r in _db.select(
            'SELECT s.id, s.kim, s.hedef, k.nick AS kim_nick, h.nick AS hedef_nick, s.neden, s.notu, s.baglam, s.zaman, s.durum '
            'FROM sikayetler s LEFT JOIN kullanicilar k ON k.id = s.kim LEFT JOIN kullanicilar h ON h.id = s.hedef ORDER BY s.id DESC LIMIT ?',
            [limit]))
          {
            'id': r['id'],
            'kim': r['kim_nick'],
            'hedef': r['hedef_nick'],
            'neden': r['neden'],
            'not': r['notu'],
            'baglam': r['baglam'],
            'zaman': r['zaman'],
            'durum': r['durum'],
          }
      ];

  String? sikayetDurumu(int id, String durum) {
    if (!sikayetDurumlari.contains(durum)) return 'Geçersiz durum.';
    _db.execute('UPDATE sikayetler SET durum = ? WHERE id = ?', [durum, id]);
    return _db.updatedRows == 0 ? 'Şikayet bulunamadı.' : null;
  }

  bool engelliMi(int engelleyen, int hedef) => _db.select('SELECT 1 FROM engeller WHERE kim = ? AND hedef = ?', [engelleyen, hedef]).isNotEmpty;

  /// Engelle / engeli kaldır; hata metni ya da null. Engel arkadaşlığı iki yönde de bitirir.
  String? engelle(int kim, String nick, bool engel) {
    final hedef = idBul(nick);
    if (hedef == null) return 'Böyle bir oyuncu yok.';
    if (hedef == kim) return 'Kendini engelleyemezsin.';
    if (!engel) {
      _db.execute('DELETE FROM engeller WHERE kim = ? AND hedef = ?', [kim, hedef]);
      return null;
    }
    _db.execute('BEGIN');
    try {
      _db.execute('INSERT OR IGNORE INTO engeller (kim, hedef, zaman) VALUES (?, ?, ?)', [kim, hedef, _simdi()]);
      _db.execute('DELETE FROM arkadaslar WHERE (kullanici_id = ? AND arkadas_id = ?) OR (kullanici_id = ? AND arkadas_id = ?)', [kim, hedef, hedef, kim]);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return null;
  }

  List<Map<String, dynamic>> engeller(int kim) => [
        for (final r in _db.select('SELECT k.nick, k.avatar FROM engeller e JOIN kullanicilar k ON k.id = e.hedef WHERE e.kim = ? ORDER BY k.nick', [kim]))
          {'nick': r['nick'], 'avatar': r['avatar']}
      ];

  // ------------------------------------------------------------ hesap silme
  void _hesapSilIc(int id) {
    _db.execute('BEGIN');
    try {
      for (final t in ['oturumlar', 'oyun_gecmisi', 'basarimlar', 'esyalar']) {
        _db.execute('DELETE FROM $t WHERE kullanici_id = ?', [id]);
      }
      _db.execute('DELETE FROM arkadaslar WHERE kullanici_id = ? OR arkadas_id = ?', [id, id]);
      _db.execute('DELETE FROM engeller WHERE kim = ? OR hedef = ?', [id, id]);
      _db.execute('UPDATE sikayetler SET kim = NULL, notu = NULL WHERE kim = ?', [id]);
      _db.execute('UPDATE sikayetler SET hedef = NULL, notu = NULL WHERE hedef = ?', [id]);
      _db.execute('UPDATE hatalar SET kullanici_id = NULL WHERE kullanici_id = ?', [id]);
      _db.execute('UPDATE olaylar SET kullanici_id = NULL WHERE kullanici_id = ?', [id]);
      _db.execute('DELETE FROM kullanicilar WHERE id = ?', [id]);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Hesabı kalıcı siler (tek işlem). Şifreli hesapta [parola] doğrulanır. Dönen nick liderlik temizliği içindir.
  ({String? hata, String? nick}) hesapSil(int id, {String? parola}) {
    final r = _db.select('SELECT nick, sifre_hash FROM kullanicilar WHERE id = ?', [id]);
    if (r.isEmpty) return (hata: 'Hesap bulunamadı.', nick: null);
    final h = r.first['sifre_hash'] as String?;
    if (h != null) {
      final p = h.split(r'$');
      if (parola == null || p.length != 2 || sifreHash(parola, p[0]) != p[1]) return (hata: 'Şifre yanlış.', nick: null);
    }
    final nick = r.first['nick'] as String;
    _hesapSilIc(id);
    return (hata: null, nick: nick);
  }

  /// Facebook veri silme isteği: hesap varsa silinir; her durumda onay kodu döner.
  ({String kod, String? nick}) fbSilme(String fbId) {
    final r = _db.select('SELECT id, nick FROM kullanicilar WHERE facebook_id = ?', [fbId]);
    String? nick;
    if (r.isNotEmpty) {
      nick = r.first['nick'] as String;
      _hesapSilIc(r.first['id'] as int);
    }
    final kod = List.generate(16, (_) => _rng.nextInt(16).toRadixString(16)).join();
    _db.execute('INSERT INTO fb_silme (kod, zaman, durum) VALUES (?, ?, ?)', [kod, _simdi(), 'tamamlandi']);
    return (kod: kod, nick: nick);
  }

  ({String zaman, String durum})? fbSilmeDurumu(String kod) {
    final r = _db.select('SELECT zaman, durum FROM fb_silme WHERE kod = ?', [kod]);
    return r.isEmpty ? null : (zaman: r.first['zaman'] as String, durum: r.first['durum'] as String);
  }
}
