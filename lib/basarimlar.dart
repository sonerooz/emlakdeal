import 'package:shared_preferences/shared_preferences.dart';
import 'dil.dart';

/// Yerel başarımlar (rozetler). Sayaçlar SharedPreferences'ta; Google Play Games
/// bağlanınca aynı anahtarlarla oraya da bildirilecek.
class Basarim {
  const Basarim(this.id, this._ad, this._aciklama, this.ikon);
  final String id, ikon;
  final String _ad, _aciklama;
  String get ad => t(_ad);
  String get aciklama => t(_aciklama);
}

const basarimlar = [
  Basarim('ilk_galibiyet', 'İlk Zafer', 'İlk oyununu kazan.', '🏆'),
  Basarim('uc_galibiyet', 'Alışkanlık', '3 oyun kazan.', '🥉'),
  Basarim('on_galibiyet', 'Usta', '10 oyun kazan.', '🥇'),
  Basarim('on_oyun', 'Masa Başı', '10 oyun oyna.', '🎲'),
  Basarim('dort_bot', 'Kalabalık Masa', '4 bota karşı kazan.', '🤖'),
  Basarim('zor_bot', 'Zor Lokma', 'Zor botlara karşı kazan.', '🔥'),
  Basarim('zengin', 'Patron', 'Bankanda 20M ile oyunu bitir.', '💰'),
  Basarim('haciz', 'Hacizci', 'Haciz kartıyla tam set al.', '⚖️'),
  Basarim('reddet', 'Hayır Dedim', 'Bir saldırıyı Reddet ile iptal et.', '🛑'),
  Basarim('online', 'Sosyal Kelebek', 'Online bir oyun kazan.', '🌐'),
  Basarim('seri', 'Seri', 'Üst üste 3 oyun kazan.', '⚡'),
  Basarim('hizli', 'Şimşek', 'Oyunu 10 turdan kısa sürede kazan.', '⏱️'),
];

class BasarimDurumu {
  BasarimDurumu._();
  static final BasarimDurumu o = BasarimDurumu._();
  SharedPreferences? _p;
  final Set<String> acik = {};
  int seri = 0;

  Future<void> yukle() async {
    _p = await SharedPreferences.getInstance();
    acik.addAll(_p!.getStringList('basarim') ?? const []);
    seri = _p!.getInt('seri') ?? 0;
  }

  /// Açılan yeni başarımları döner (toast için).
  List<Basarim> ac(Iterable<String> idler) {
    final yeni = <Basarim>[];
    for (final id in idler) {
      if (acik.add(id)) yeni.add(basarimlar.firstWhere((b) => b.id == id));
    }
    if (yeni.isNotEmpty) _p?.setStringList('basarim', acik.toList());
    return yeni;
  }

  void seriGuncelle(bool kazandi) {
    seri = kazandi ? seri + 1 : 0;
    _p?.setInt('seri', seri);
  }

  void sifirla() {
    acik.clear();
    seri = 0;
    _p?.remove('basarim');
    _p?.remove('seri');
  }
}
