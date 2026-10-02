// Üyelik veritabanı (SQLite): hesaplar, oturumlar, oyun geçmişi, başarımlar.
// Google/Facebook/Apple kimlikleri için sütunlar hazır; şimdilik misafir (cihaz anahtarı) ve e-posta/şifre.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:emlakdeal_cekirdek/seviye.dart';
import 'package:sqlite3/sqlite3.dart';

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
    for (final sutun in ['kart_arkasi TEXT NOT NULL DEFAULT \'klasik\'', 'masa TEXT NOT NULL DEFAULT \'yesil\'']) {
      try {
        _db.execute('ALTER TABLE kullanicilar ADD COLUMN $sutun');
      } catch (_) {}
    }
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
    _db.execute('CREATE INDEX IF NOT EXISTS ix_gecmis_kullanici ON oyun_gecmisi(kullanici_id)');
    _db.execute('CREATE INDEX IF NOT EXISTS ix_lider ON kullanicilar(level DESC, xp DESC)');
  }

  final Database _db;
  final _rng = Random.secure();

  String _simdi() => DateTime.now().toUtc().toIso8601String();
  String _token() => base64Url.encode(List<int>.generate(32, (_) => _rng.nextInt(256)));
  String sifreHash(String sifre, String tuz) => sha256.convert(utf8.encode('$tuz:$sifre')).toString();

  static final nickKurali = RegExp(r'^[A-Za-zÇĞİÖŞÜçğıöşü0-9_ ]{3,16}$');

  /// Türkiye saatiyle bugünün tarihi (YYYY-MM-DD) ve haftanın günü (Pzt=1..Paz=7).
  static ({String tarih, int gun}) _bugun() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 3));
    return (tarih: t.toIso8601String().substring(0, 10), gun: t.weekday);
  }

  /// Günlük bonus: Pazartesi 100, Salı 200 … Pazar 700; her gün bir kez.
  static int bonusMiktari(int gun) => gun * 100;

  Map<String, dynamic> bonusDurumu(int id) {
    final r = _db.select('SELECT son_bonus FROM kullanicilar WHERE id = ?', [id]).first;
    final b = _bugun();
    return {'bonusHazir': r['son_bonus'] != b.tarih, 'bonusMiktar': bonusMiktari(b.gun), 'bonusGun': b.gun};
  }

  /// Bonusu verir; zaten alındıysa alindi=false.
  Map<String, dynamic> bonusAl(int id) {
    final b = _bugun();
    final r = _db.select('SELECT son_bonus FROM kullanicilar WHERE id = ?', [id]).first;
    if (r['son_bonus'] == b.tarih) return {'alindi': false, ...bonusDurumu(id), 'profil': profil(id)};
    final m = bonusMiktari(b.gun);
    _db.execute('UPDATE kullanicilar SET altin = altin + ?, son_bonus = ? WHERE id = ?', [m, b.tarih, id]);
    return {'alindi': true, 'bonus': m, ...bonusDurumu(id), 'profil': profil(id)};
  }

  Map<String, dynamic> profil(int id) {
    final r = _db.select('SELECT * FROM kullanicilar WHERE id = ?', [id]).first;
    final lv = levelHesapla(r['xp'] as int);
    final b = _bugun();
    return {
      'bonusHazir': r['son_bonus'] != b.tarih,
      'bonusMiktar': bonusMiktari(b.gun),
      'bonusGun': b.gun,
      'id': r['id'],
      'nick': r['nick'],
      'avatar': r['avatar'],
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
    var aday = temel;
    var n = 1;
    while (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ?', [aday]).isNotEmpty) {
      n++;
      aday = '$temel$n';
    }
    return aday;
  }

  /// Misafir hesap: cihaz anahtarıyla kayıt (varsa giriş).
  ({int id, String token, bool yeni}) misafir(String cihaz, {String? nick, String? avatar}) {
    final mevcut = _db.select('SELECT id FROM kullanicilar WHERE cihaz_anahtari = ?', [cihaz]);
    if (mevcut.isNotEmpty) {
      final id = mevcut.first['id'] as int;
      _db.execute('UPDATE kullanicilar SET son_giris = ? WHERE id = ?', [_simdi(), id]);
      return (id: id, token: oturumAc(id), yeni: false);
    }
    final ad = nickUret(nick);
    final av = avatarlar.contains(avatar) ? avatar! : avatarlar[_rng.nextInt(avatarlar.length)];
    _db.execute('INSERT INTO kullanicilar (nick, avatar, cihaz_anahtari, olusturma, son_giris) VALUES (?, ?, ?, ?, ?)', [ad, av, cihaz, _simdi(), _simdi()]);
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
  String? profilGuncelle(int id, {String? nick, String? avatar}) {
    if (nick != null) {
      final n = nick.trim();
      if (!nickKurali.hasMatch(n)) return 'Takma ad 3-16 karakter; harf, rakam, alt çizgi.';
      if (_db.select('SELECT 1 FROM kullanicilar WHERE nick = ? AND id != ?', [n, id]).isNotEmpty) return 'Bu takma ad alınmış.';
      _db.execute('UPDATE kullanicilar SET nick = ? WHERE id = ?', [n, id]);
    }
    if (avatar != null) {
      if (!avatarlar.contains(avatar)) return 'Geçersiz avatar.';
      _db.execute('UPDATE kullanicilar SET avatar = ? WHERE id = ?', [avatar, id]);
    }
    return null;
  }

  /// Oyun sonucu: XP/altın verir, istatistikleri günceller; ödül ve level bilgisini döner.
  Map<String, dynamic> sonuc(int id, {required bool kazandi, required int rakip, required bool online, int zorluk = 1}) {
    final o = odul(kazandi: kazandi, rakip: rakip, online: online, zorluk: zorluk);
    final once = levelHesapla(_db.select('SELECT xp FROM kullanicilar WHERE id = ?', [id]).first['xp'] as int).level;
    _db.execute('''
      UPDATE kullanicilar SET xp = xp + ?, altin = altin + ?, oyun = oyun + 1, galibiyet = galibiyet + ?,
        online_oyun = online_oyun + ?, online_galibiyet = online_galibiyet + ? WHERE id = ?''',
        [o.xp, o.altin, kazandi ? 1 : 0, online ? 1 : 0, (online && kazandi) ? 1 : 0, id]);
    final sonraXp = _db.select('SELECT xp FROM kullanicilar WHERE id = ?', [id]).first['xp'] as int;
    final sonra = levelHesapla(sonraXp);
    _db.execute('UPDATE kullanicilar SET level = ? WHERE id = ?', [sonra.level, id]);
    _db.execute('INSERT INTO oyun_gecmisi (kullanici_id, tarih, mod, kazandi, rakip, zorluk, xp, altin) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, _simdi(), online ? 'online' : 'bot', kazandi ? 1 : 0, rakip, zorluk, o.xp, o.altin]);
    return {'xp': o.xp, 'altin': o.altin, 'level': sonra.level, 'levelAtladi': sonra.level > once, 'profil': profil(id)};
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

  void hataKaydet({int? kullaniciId, String? surum, String? cihaz, required String mesaj, String? yigin}) {
    _db.execute('INSERT INTO hatalar (tarih, kullanici_id, surum, cihaz, mesaj, yigin) VALUES (?, ?, ?, ?, ?, ?)',
        [_simdi(), kullaniciId, surum, cihaz, mesaj.length > 2000 ? mesaj.substring(0, 2000) : mesaj, yigin == null ? null : (yigin.length > 8000 ? yigin.substring(0, 8000) : yigin)]);
  }

  void olayKaydet({int? kullaniciId, required String ad, String? veri}) {
    _db.execute('INSERT INTO olaylar (tarih, kullanici_id, ad, veri) VALUES (?, ?, ?, ?)', [_simdi(), kullaniciId, ad, veri]);
  }

  Map<String, dynamic> ozet() => {
        'kullanici': _db.select('SELECT count(*) c FROM kullanicilar').first['c'],
        'oyun': _db.select('SELECT count(*) c FROM oyun_gecmisi').first['c'],
        'hata24s': _db.select("SELECT count(*) c FROM hatalar WHERE tarih > datetime('now', '-1 day')").first['c'],
        'olay24s': _db.select("SELECT count(*) c FROM olaylar WHERE tarih > datetime('now', '-1 day')").first['c'],
        'sonHatalar': [for (final r in _db.select('SELECT tarih, mesaj FROM hatalar ORDER BY id DESC LIMIT 5')) {'tarih': r['tarih'], 'mesaj': r['mesaj']}],
      };

  List<Map<String, dynamic>> liderlik({int limit = 50}) => [
        for (final r in _db.select('SELECT nick, avatar, level, xp, oyun, galibiyet, online_galibiyet FROM kullanicilar WHERE oyun > 0 ORDER BY level DESC, xp DESC, galibiyet DESC LIMIT ?', [limit]))
          {'nick': r['nick'], 'avatar': r['avatar'], 'level': r['level'], 'xp': r['xp'], 'oyun': r['oyun'], 'galibiyet': r['galibiyet'], 'onlineGalibiyet': r['online_galibiyet']}
      ];
}
