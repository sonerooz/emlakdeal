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

  List<Map<String, dynamic>> liderlik({int limit = 50}) => [
        for (final r in _db.select('SELECT nick, avatar, level, xp, oyun, galibiyet, online_galibiyet FROM kullanicilar WHERE oyun > 0 ORDER BY level DESC, xp DESC, galibiyet DESC LIMIT ?', [limit]))
          {'nick': r['nick'], 'avatar': r['avatar'], 'level': r['level'], 'xp': r['xp'], 'oyun': r['oyun'], 'galibiyet': r['galibiyet'], 'onlineGalibiyet': r['online_galibiyet']}
      ];
}
