import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'ayarlar.dart';

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
  String get avatar => profil?['avatar'] as String? ?? '🙂';
  int get level => profil?['level'] as int? ?? 1;
  int get altin => profil?['altin'] as int? ?? 0;

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
        if (y.statusCode >= 400) throw HesapHatasi((m is Map ? m['hata'] : null)?.toString() ?? 'Sunucu hatası ${y.statusCode}', y.statusCode);
        return (m as Map).cast<String, dynamic>();
      } on HesapHatasi {
        rethrow;
      } catch (e) {
        sonHata = e;
      }
    }
    throw HesapHatasi('Sunucuya ulaşılamadı ($sonHata)', 0);
  }

  Future<void> _profilKaydet(Map<String, dynamic> p) async {
    profil = p;
    await _p?.setString('profil', jsonEncode(p));
  }

  /// Uygulama açılışında: oturum yoksa misafir hesabı aç, varsa profili tazele. Sessizce başarısız olabilir.
  Future<void> baglan() async {
    try {
      if (token == null) {
        final r = await _istek('/api/misafir', govde: {'cihaz': cihaz, 'nick': Ayarlar.o.ad}, yetki: false);
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

  Future<String?> profilGuncelle({String? nick, String? avatar}) async {
    try {
      await _profilKaydet(await _istek('/api/profil', govde: {if (nick != null) 'nick': nick, if (avatar != null) 'avatar': avatar}));
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

  bool get bonusHazir => profil?['bonusHazir'] == true;
  int get bonusMiktar => profil?['bonusMiktar'] as int? ?? 0;

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

  Future<List<Map<String, dynamic>>> liderlik() async {
    for (final kok in [_apiKok, _apiKokYerel]) {
      try {
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final y = await (await c.getUrl(Uri.parse('$kok/api/liderlik'))).close();
        final j = jsonDecode(await y.transform(utf8.decoder).join()) as List;
        return [for (final e in j) Map<String, dynamic>.from(e as Map)];
      } catch (_) {}
    }
    throw HesapHatasi('Sunucuya ulaşılamadı', 0);
  }
}

class HesapHatasi implements Exception {
  HesapHatasi(this.mesaj, this.kod);
  final String mesaj;
  final int kod;
  @override
  String toString() => mesaj;
}
