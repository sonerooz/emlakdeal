import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'ayarlar.dart';
import 'dil.dart';
import 'sosyal_ayar.dart';

/// Üyelik: cihaz anahtarıyla misafir hesap, oturum token'ı, profil (nick/avatar/XP/level/altın).
/// Google/Facebook/Apple girişleri sunucuda "hesabı bağla" olarak eklenecek.
class Hesap {
  Hesap._();
  static final Hesap o = Hesap._();
  SharedPreferences? _p;
  String? token;
  String cihaz = '';
  Map<String, dynamic>? profil;
  bool get girisli => token != null && profil != null;

  String get nick => profil?['nick'] as String? ?? Ayarlar.o.ad;
  String get avatar => profil?['avatar'] as String? ?? 'misafir';
  /// Girişi olmayan hesap (profil yoksa da misafir sayılır).
  bool get misafir => profil == null || profil!['misafir'] == true;
  int get ses => profil?['ses'] as int? ?? 0;
  int get level => profil?['level'] as int? ?? 1;
  int get altin => profil?['altin'] as int? ?? 0;
  List<String> get esyalar => ((profil?['esyalar'] as List?) ?? const []).cast<String>();
  String get kartArkasi => profil?['kartArkasi'] as String? ?? 'klasik';
  String get masa => profil?['masa'] as String? ?? 'yesil';

  Future<void> yukle() async {
    _p = await SharedPreferences.getInstance();
    cihaz = _p!.getString('cihaz') ?? '';
    if (cihaz.isEmpty) {
      final r = Random.secure();
      cihaz = base64Url.encode(List<int>.generate(24, (_) => r.nextInt(256)));
      await _p!.setString('cihaz', cihaz);
    }
    token = _p!.getString('token');
    final pj = _p!.getString('profil');
    if (pj != null) {
      try {
        profil = jsonDecode(pj) as Map<String, dynamic>;
      } catch (_) {}
    }
  }

  String get _apiKok => Ayarlar.o.sunucu.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');
  String get _apiKokYerel => Ayarlar.sunucuYerel.replaceFirst('ws://', 'http://');

  Future<Map<String, dynamic>> _istek(String yol, {Map<String, dynamic>? govde, bool yetki = true}) async {
    Object? sonHata;
    for (final kok in [_apiKok, if (_apiKok != _apiKokYerel) _apiKokYerel]) {
      try {
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final r = govde == null ? await c.getUrl(Uri.parse('$kok$yol')) : await c.postUrl(Uri.parse('$kok$yol'));
        if (yetki && token != null) r.headers.set('authorization', 'Bearer $token');
        if (govde != null) {
          r.headers.contentType = ContentType.json;
          r.write(jsonEncode(govde));
        }
        final y = await r.close().timeout(const Duration(seconds: 10));
        final m = jsonDecode(await y.transform(utf8.decoder).join());
        if (y.statusCode >= 400) throw HesapHatasi(sunucuMesaj((m is Map ? m['hata'] : null)?.toString() ?? t('Sunucu hatası {n}', {'n': y.statusCode})), y.statusCode);
        if (m is List) return {'_': m};
        return (m as Map).cast<String, dynamic>();
      } on HesapHatasi {
        rethrow;
      } catch (e) {
        sonHata = e;
      }
    }
    throw HesapHatasi(t('Sunucuya ulaşılamadı ({hata})', {'hata': sonHata}), 0);
  }

  Future<void> _profilKaydet(Map<String, dynamic> p) async {
    profil = p;
    await _p?.setString('profil', jsonEncode(p));
  }

  /// Uygulama açılışında: oturum yoksa misafir hesabı aç, varsa profili tazele. Sessizce başarısız olabilir.
  Future<void> baglan() async {
    try {
      if (token == null) {
        final r = await _istek('/api/misafir', govde: {'cihaz': cihaz}, yetki: false);
        token = r['token'] as String;
        await _p?.setString('token', token!);
        await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      } else {
        try {
          await _profilKaydet(await _istek('/api/profil'));
        } on HesapHatasi catch (e) {
          if (e.kod == 401) {
            token = null;
            await _p?.remove('token');
            await baglan();
          }
        }
      }
      Ayarlar.o.ad = nick;
      await Ayarlar.o.kaydet();
    } catch (_) {}
  }

  Future<String?> profilGuncelle({String? nick, String? avatar, int? ses}) async {
    try {
      await _profilKaydet(await _istek('/api/profil', govde: {if (nick != null) 'nick': nick, if (avatar != null) 'avatar': avatar, if (ses != null) 'ses': ses}));
      Ayarlar.o.ad = this.nick;
      await Ayarlar.o.kaydet();
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> epostaBagla(String eposta, String sifre) async {
    try {
      await _profilKaydet(await _istek('/api/eposta', govde: {'eposta': eposta, 'sifre': sifre}));
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> epostaGiris(String eposta, String sifre) async {
    try {
      final r = await _istek('/api/giris', govde: {'eposta': eposta, 'sifre': sifre}, yetki: false);
      token = r['token'] as String;
      await _p?.setString('token', token!);
      await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      Ayarlar.o.ad = nick;
      await Ayarlar.o.kaydet();
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  bool get baglandi => profil?['eposta'] != null || profil?['google'] == true || profil?['facebook'] == true || profil?['apple'] == true;

  /// Google/Facebook ile bağlan. Başka hesaba geçilirse degisti true. Hata metni ya da null.
  Future<({String? hata, bool degisti})> sosyalGiris(String saglayici) async {
    try {
      String? tok;
      if (saglayici == 'google') {
        if (googleSunucuIstemci.isEmpty) return (hata: t('Google girişi henüz ayarlanmadı.'), degisti: false);
        final g = GoogleSignIn(serverClientId: googleSunucuIstemci, scopes: ['email']);
        await g.signOut();
        tok = (await (await g.signIn())?.authentication)?.idToken;
        if (tok == null) return (hata: t('Google girişi iptal edildi.'), degisti: false);
      } else if (saglayici == 'apple') {
        final c = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.fullName]);
        tok = c.identityToken;
        if (tok == null) return (hata: t('Apple girişi iptal edildi.'), degisti: false);
      } else {
        if (facebookUygulamaKimligi.isEmpty) return (hata: t('Facebook girişi henüz ayarlanmadı.'), degisti: false);
        final r = await FacebookAuth.instance.login(permissions: ['public_profile']);
        tok = r.accessToken?.tokenString;
        if (tok == null) return (hata: t('Facebook girişi iptal edildi.'), degisti: false);
      }
      final r = await _istek('/api/sosyal', govde: {'saglayici': saglayici, 'token': tok});
      final degisti = r['degisti'] == true;
      if (degisti) {
        token = r['token'] as String;
        await _p?.setString('token', token!);
      }
      await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      Ayarlar.o.ad = nick;
      await Ayarlar.o.kaydet();
      return (hata: null, degisti: degisti);
    } on HesapHatasi catch (e) {
      return (hata: e.mesaj, degisti: false);
    } on SignInWithAppleAuthorizationException catch (e) {
      return (hata: e.code == AuthorizationErrorCode.canceled ? t('Apple girişi iptal edildi.') : t('Giriş yapılamadı: {e}', {'e': e.message}), degisti: false);
    } catch (e) {
      return (hata: t('Giriş yapılamadı: {e}', {'e': e}), degisti: false);
    }
  }

  /// Oturumu kapat; bu cihazda yepyeni bir misafir hesapla devam eder.
  Future<void> cikis() async {
    try {
      await _istek('/api/cikis', govde: {});
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    token = null;
    profil = null;
    await _p?.remove('token');
    await _p?.remove('profil');
    final r = Random.secure();
    cihaz = base64Url.encode(List<int>.generate(24, (_) => r.nextInt(256)));
    await _p?.setString('cihaz', cihaz);
    Ayarlar.o.ad = 'Misafir';
    await baglan();
  }

  /// Botla oynanan oyunun sonucu → XP/altın. Döner: {xp, altin, level, levelAtladi} ya da null.
  Future<Map<String, dynamic>?> sonuc({required bool kazandi, required int rakip, required int zorluk, List<String> basarimlar = const []}) async {
    try {
      final r = await _istek('/api/sonuc', govde: {'kazandi': kazandi, 'rakip': rakip, 'zorluk': zorluk, 'basarimlar': basarimlar});
      await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Online oyun sonunda sunucudan gelen ödül mesajıyla profili güncelle.
  Future<void> odulGeldi(Map<String, dynamic> m) async {
    if (m['profil'] is Map) await _profilKaydet(Map<String, dynamic>.from(m['profil'] as Map));
  }

  bool get bonusHazir => !misafir && profil?['bonusHazir'] == true;
  int get bonusMiktar => profil?['bonusMiktar'] as int? ?? 0;
  int get bonusGun => (profil?['bonusGun'] as int? ?? 1).clamp(1, 7);
  List<int> get bonusOdulleri => ((profil?['bonusOdulleri'] as List?) ?? const [100, 150, 200, 250, 300, 400, 1000]).cast<int>();

  /// Günlük bonusu al; {alindi, bonus} ya da null (sunucu yok).
  Future<Map<String, dynamic>?> bonusAl() async {
    try {
      final r = await _istek('/api/bonus', govde: {});
      await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      return r;
    } catch (_) {
      return null;
    }
  }

  int get gorevHazir => misafir ? 0 : (profil?['gorevHazir'] as int? ?? 0);
  int get botKotaKullanilan => (profil?['botKota']?['kullanilan'] as num?)?.toInt() ?? 0;
  int get botKotaLimit => (profil?['botKota']?['limit'] as num?)?.toInt() ?? 10000;
  bool get botKotaDoldu => profil?['botKota']?['doldu'] == true;

  /// Bugünün görevleri; sunucuya ulaşılamazsa null.
  Future<List<Map<String, dynamic>>?> gorevler() async {
    try {
      final r = await _istek('/api/gorevler');
      if (r['profil'] is Map) await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      return [for (final g in (r['gorevler'] as List)) Map<String, dynamic>.from(g as Map)];
    } catch (_) {
      return null;
    }
  }

  /// Görev ödülünü al; {xp, altin, gorevler} ya da null.
  Future<Map<String, dynamic>?> gorevAl(String id) async {
    try {
      final r = await _istek('/api/gorev_al', govde: {'gorev': id});
      await _profilKaydet(Map<String, dynamic>.from(r['profil'] as Map));
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Yetkili POST (hata/olay raporu gibi); sonuç önemsiz, sessiz.
  Future<void> gonder(String yol, Map<String, dynamic> govde) async {
    try {
      await _istek(yol, govde: govde);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _liste(String yol) async {
    final r = await _istek(yol);
    return [for (final e in (r['_'] as List)) Map<String, dynamic>.from(e as Map)];
  }

  Future<List<Map<String, dynamic>>> magaza() => _liste('/api/magaza');
  Future<List<Map<String, dynamic>>> arkadaslar() => _liste('/api/arkadaslar');
  Future<List<Map<String, dynamic>>> gecmis() => _liste('/api/gecmis');

  Future<String?> satinAl(String esya) async {
    try {
      await _profilKaydet(await _istek('/api/satin_al', govde: {'esya': esya}));
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> secim({String? kartArkasi, String? masa}) async {
    try {
      await _profilKaydet(await _istek('/api/secim', govde: {if (kartArkasi != null) 'kartArkasi': kartArkasi, if (masa != null) 'masa': masa}));
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> arkadasEkle(String nick) async {
    try {
      await _istek('/api/arkadaslar', govde: {'nick': nick});
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<void> arkadasSil(String nick) => gonder('/api/arkadaslar', {'nick': nick, 'sil': true});

  // ----------------------------------------------------------- güvenlik: şikayet / engel / hesap silme
  final Set<String> _engelliNick = {};
  List<Map<String, dynamic>> _engelListe = [];
  List<Map<String, dynamic>> get engelliler => _engelListe;

  static String _nk(String n) => n.trim().toLowerCase();
  bool engelliMi(String nick) => _engelliNick.contains(_nk(nick));

  /// Engellenenleri sunucudan çeker ve yerel önbelleği yeniler; çevrimdışıysa eskisi kalır.
  Future<List<Map<String, dynamic>>> engelleriYukle() async {
    if (misafir) {
      _engelliNick.clear();
      _engelListe = [];
      return _engelListe;
    }
    final r = await _istek('/api/engeller');
    _engelListe = [for (final e in (r['engeller'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
    _engelliNick
      ..clear()
      ..addAll(_engelListe.map((e) => _nk(e['nick'] as String)));
    return _engelListe;
  }

  Future<String?> sikayetGonder(String hedef, String neden, {String? not, String baglam = 'oyun'}) async {
    try {
      await _istek('/api/sikayet', govde: {'hedef': hedef, 'neden': neden, if (not != null && not.trim().isNotEmpty) 'not': not.trim(), 'baglam': baglam});
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> engelle(String nick) async {
    try {
      await _istek('/api/engel', govde: {'nick': nick, 'engel': true});
      _engelliNick.add(_nk(nick));
      _engelListe = [..._engelListe.where((e) => _nk(e['nick'] as String) != _nk(nick)), {'nick': nick, 'avatar': ''}];
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  Future<String?> engeliKaldir(String nick) async {
    try {
      await _istek('/api/engel', govde: {'nick': nick, 'engel': false});
      _engelliNick.remove(_nk(nick));
      _engelListe = [for (final e in _engelListe) if (_nk(e['nick'] as String) != _nk(nick)) e];
      return null;
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
  }

  /// Hesabı kalıcı siler; başarıda yerel durum temizlenir ve yeni misafir hesapla devam edilir. Hata mesajı ya da null.
  Future<String?> hesapSil({String? parola}) async {
    try {
      await _istek('/api/hesap/sil', govde: {'onay': 'SIL', if (parola != null && parola.isNotEmpty) 'parola': parola});
    } on HesapHatasi catch (e) {
      return e.mesaj;
    }
    try {
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    token = null;
    profil = null;
    _engelliNick.clear();
    _engelListe = [];
    await _p?.remove('token');
    await _p?.remove('profil');
    final r = Random.secure();
    cihaz = base64Url.encode(List<int>.generate(24, (_) => r.nextInt(256)));
    await _p?.setString('cihaz', cihaz);
    Ayarlar.o.ad = 'Misafir';
    await baglan();
    return null;
  }

  /// Herkese açık yasal sayfa adresi: `gizlilik` ya da `hesap-sil`; dil = uygulamanın geçerli dili.
  String yasalUrl(String sayfa) => '$_apiKok/$sayfa?dil=${Dil.o.kod}';

  Future<List<Map<String, dynamic>>> liderlik() async {
    for (final kok in [_apiKok, _apiKokYerel]) {
      try {
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final y = await (await c.getUrl(Uri.parse('$kok/api/liderlik'))).close();
        final j = jsonDecode(await y.transform(utf8.decoder).join()) as List;
        return [for (final e in j) Map<String, dynamic>.from(e as Map)];
      } catch (_) {}
    }
    throw HesapHatasi(t('Sunucuya ulaşılamadı'), 0);
  }
}

class HesapHatasi implements Exception {
  HesapHatasi(this.mesaj, this.kod);
  final String mesaj;
  final int kod;
  @override
  String toString() => mesaj;
}
