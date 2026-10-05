import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı ayarlar ve istatistikler (SharedPreferences). Uygulama açılışında [yukle] çağrılır.
class Ayarlar {
  Ayarlar._();
  static final Ayarlar o = Ayarlar._();
  SharedPreferences? _p;

  String ad = 'Misafir';
  bool sesli = true;
  bool muzik = false;
  String get sunucu => 'wss://emlakdeal.tailb92005.ts.net';
  static const sunucuYerel = 'ws://192.168.1.21:8765';
  int botZorluk = 1; // 0 kolay, 1 normal, 2 zor
  int sayacHaciz = 0, sayacReddet = 0;
  int oynanan = 0;
  int kazanilan = 0;
  bool ogreticiGoruldu = false;
  bool ogreticiDemoBitti = false;
  String dil = ''; // '' = cihaz diline göre

  Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    ad = p.getString('ad') ?? ad;
    sesli = p.getBool('sesli') ?? sesli;
    muzik = p.getBool('muzik') ?? muzik;
    botZorluk = p.getInt('botZorluk') ?? botZorluk;
    sayacHaciz = p.getInt('sayacHaciz') ?? 0;
    sayacReddet = p.getInt('sayacReddet') ?? 0;
    oynanan = p.getInt('oynanan') ?? 0;
    kazanilan = p.getInt('kazanilan') ?? 0;
    ogreticiGoruldu = p.getBool('ogretici') ?? false;
    ogreticiDemoBitti = p.getBool('ogretici_demo') ?? false;
    dil = p.getString('dil') ?? '';
  }

  Future<void> kaydet() async {
    final p = _p;
    if (p == null) return;
    await p.setString('ad', ad);
    await p.setBool('sesli', sesli);
    await p.setBool('muzik', muzik);
    await p.setInt('botZorluk', botZorluk);
    await p.setInt('sayacHaciz', sayacHaciz);
    await p.setInt('sayacReddet', sayacReddet);
    await p.setInt('oynanan', oynanan);
    await p.setInt('kazanilan', kazanilan);
    await p.setBool('ogretici', ogreticiGoruldu);
    await p.setBool('ogretici_demo', ogreticiDemoBitti);
    if (dil.isNotEmpty) await p.setString('dil', dil);
  }

  /// Tek kişilik oyun kaydı (uygulama kapanınca devam edebilmek için).
  Map<String, dynamic>? get kayit {
    final s = _p?.getString('kayit');
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> kayitYaz(Map<String, dynamic>? j) async {
    final p = _p;
    if (p == null) return;
    if (j == null) {
      await p.remove('kayit');
    } else {
      await p.setString('kayit', jsonEncode(j));
    }
  }
}
