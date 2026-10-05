import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'ayarlar.dart';
import 'dil/en_ana.dart';
import 'dil/en_guvenlik.dart';
import 'dil/en_kart.dart';
import 'dil/en_ogretici.dart';
import 'dil/en_oyun.dart';
import 'dil/en_sosyal.dart';
import 'dil/en_veri.dart';
import 'dil/soz.dart';
export 'dil/sunucu_mesaj.dart';

/// Uygulama dili ('tr' | 'en'). Anahtar her zaman Türkçe metindir; İngilizce karşılığı en_*.dart sözlüklerindedir.
class Dil extends ChangeNotifier {
  Dil._();
  static final Dil o = Dil._();

  String kod = 'tr';
  bool get en => kod == 'en';

  /// Kayıtlı dil yoksa cihaz diline bakar (Türkçe değilse İngilizce).
  void baslat() {
    final k = Ayarlar.o.dil;
    if (k == 'tr' || k == 'en') {
      kod = k;
    } else {
      kod = PlatformDispatcher.instance.locale.languageCode == 'tr' ? 'tr' : 'en';
    }
  }

  Future<void> sec(String yeni) async {
    if (yeni == kod) return;
    kod = yeni;
    Ayarlar.o.dil = yeni;
    await Ayarlar.o.kaydet();
    notifyListeners();
  }

  static final Map<String, String> _sozluk = {...enOgretici, ...enKart, ...enAna, ...enOyun, ...enSosyal, ...enVeri, ...enGuvenlik};
  String? _ara(String tr) => _sozluk[tr];
}

/// Çeviri: anahtar Türkçe metin; `{ad}` yer tutucular [a] ile doldurulur. Karşılık yoksa Türkçe döner.
String t(String tr, [Map<String, Object?>? a]) {
  var s = Dil.o.en ? (Dil.o._ara(tr) ?? tr) : tr;
  if (a != null) {
    a.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}

/// Oyun içi konuşma / hızlı sohbet cümlesi: tel üzerinde hep Türkçe taşınır, alıcı kendi dilinde görür ve duyar.
String sozGoster(String trSoz) => Dil.o.en ? (sozEn(trSoz) ?? t(trSoz)) : trSoz;
