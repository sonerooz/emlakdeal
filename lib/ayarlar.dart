import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı ayarlar ve istatistikler (SharedPreferences). Uygulama açılışında [yukle] çağrılır.
class Ayarlar {
  Ayarlar._();
  static final Ayarlar o = Ayarlar._();
  SharedPreferences? _p;

  String ad = 'Sen';
  bool sesli = true;
  bool muzik = false;
  String sunucu = 'ws://192.168.1.21:8765';
  int botZorluk = 1; // 0 kolay, 1 normal, 2 zor
  int oynanan = 0;
  int kazanilan = 0;
  bool ogreticiGoruldu = false;

  Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    ad = p.getString('ad') ?? ad;
    sesli = p.getBool('sesli') ?? sesli;
    muzik = p.getBool('muzik') ?? muzik;
    sunucu = p.getString('sunucu') ?? sunucu;
    botZorluk = p.getInt('botZorluk') ?? botZorluk;
    oynanan = p.getInt('oynanan') ?? 0;
    kazanilan = p.getInt('kazanilan') ?? 0;
    ogreticiGoruldu = p.getBool('ogretici') ?? false;
  }

  Future<void> kaydet() async {
    final p = _p;
    if (p == null) return;
    await p.setString('ad', ad);
    await p.setBool('sesli', sesli);
    await p.setBool('muzik', muzik);
    await p.setString('sunucu', sunucu);
    await p.setInt('botZorluk', botZorluk);
    await p.setInt('oynanan', oynanan);
    await p.setInt('kazanilan', kazanilan);
    await p.setBool('ogretici', ogreticiGoruldu);
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
