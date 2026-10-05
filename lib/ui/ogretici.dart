import 'package:flutter/material.dart';

import '../ayarlar.dart';
import '../dil.dart';
import 'ogretici_demo.dart';

class _Adim {
  const _Adim.metin(this.ikon, this.baslik, this.metin) : demo = null;
  const _Adim.demo(this.demo)
      : ikon = null,
        baslik = '',
        metin = '';
  final IconData? ikon;
  final String baslik, metin;
  final Widget Function(VoidCallback bitti)? demo;
  bool get demoMu => demo != null;
}

/// İlk açılışta (ve menüden) görsel öğretici; kurallar ve etkileşimli demolar burada.
class OgreticiEkrani extends StatefulWidget {
  const OgreticiEkrani({super.key});
  @override
  State<OgreticiEkrani> createState() => _OgreticiEkraniState();
}

class _OgreticiEkraniState extends State<OgreticiEkrani> {
  final _pc = PageController();
  int _i = 0;
  final _tamam = <int>{};

  static final _adimlar = <_Adim>[
    const _Adim.metin(
      Icons.flag,
      'Amaç',
      'Farklı renkte 3 TAM tapu seti toplayan kazanır. Set boyları kartın üstünde yazar (2, 3 ya da 4 tapu).',
    ),
    const _Adim.metin(
      Icons.style,
      'Tur',
      'Her tur 2 kart çek (elin boşsa 5). En fazla 3 hamle yaparsın; 3. hamlede tur kendiliğinden biter. Tapu ya da para kartına bir kez dokun: tapu sete, para bankaya gider. Kira ve ev kartlarına dokununca oyun en uygun yeri kendisi seçer; oynayacak yer yoksa kart para olarak bankaya girer. Tur sonunda elinde en fazla 7 kart kalabilir.',
    ),
    _Adim.demo((b) => DemoSet(bitti: b)),
    const _Adim.metin(
      Icons.attach_money,
      'Para ve ödeme',
      'Hamle ve kira kartları bankaya konursa para olur; geri alınamaz. Borç banka ve tapulardan ödenir, elden ödenmez. Yetmezse her şeyini verirsin. Soluk görünen kartın işlevi şu an oynanamaz, yine de bankaya konabilir.',
    ),
    const _Adim.metin(
      Icons.receipt_long,
      'Kira',
      'Kira kartı: o renkte tapun varsa HERKESTEN kira alırsın (Joker kira her renk için geçerlidir). Zam Geldi ile iki katı (2 hamle harcar).',
    ),
    _Adim.demo((b) => DemoKira(bitti: b)),
    const _Adim.metin(
      Icons.gavel,
      'Saldırı kartları',
      'Tapu Devri: tam olmayan setten bir tapu al. Takas Pazarlığı: tapu takas et (tam setler hariç). Haciz: rakibin TAM setini ev/rezidansıyla birlikte al. İcra Takibi: seçtiğin birinden 5M. Her biri 1 hamle harcar. Şimdi hepsini tek tek deneyelim.',
    ),
    _Adim.demo((b) => DemoTapuDevri(bitti: b)),
    _Adim.demo((b) => DemoTakas(bitti: b)),
    _Adim.demo((b) => DemoHaciz(bitti: b)),
    const _Adim.metin(
      Icons.shield,
      'Reddet ve yardımcı kartlar',
      'Reddet: sana oynanan bir hamleyi iptal eder (hamle harcamaz); karşı taraf da Reddet ile karşılık verebilir. Ev Partisi: herkesten 2M alırsın. 2 Kart Çek: desteden 2 kart çekersin. Ev Partisi ve 2 Kart Çek birer hamle harcar.',
    ),
    _Adim.demo((b) => DemoReddet(bitti: b)),
    const _Adim.metin(
      Icons.home_work,
      'Ev ve rezidans',
      'Ev (+3M) ve Rezidans (+4M) sadece TAM setlere konur. Her sete bir Ev konur; Rezidans için önce Ev gerekir. Ulaşım ve Altyapı setlerine konmaz. Set bozulursa ev ve rezidans para olarak bankana döner.',
    ),
    _Adim.demo((b) => DemoEv(bitti: b)),
    const _Adim.metin(
      Icons.style_outlined,
      'Joker',
      'Joker Tapu istediğin renkte sayılır; iki renkli jokerler yalnızca üstlerindeki iki renkten biri olur. Kendi turunda masadaki jokere dokunup rengini değiştirebilirsin; seti tamamlamanın en kolay yolu budur. Çok renkli Joker Tapu para değeri taşımaz, ödemede verilemez. Şimdi jokerle set tamamlamayı dene.',
    ),
    _Adim.demo((b) => DemoJoker(bitti: b, cokRenkli: true)),
    _Adim.demo((b) => DemoJoker(bitti: b, cokRenkli: false)),
    const _Adim.metin(
      Icons.monetization_on,
      'Online oda ve altın',
      'Online oyunlar altınlı odalarda oynanır: odayı kuran tutarı seçer (50, 100, 250…), herkes o kadar altınla girer ve gerçek oyuncuların toplamı kazanana gider. Bot kazanırsa herkesin altını iade edilir; oyundan düşersen altının kaybolur. XP sadece online oyunlardan kazanılır. Botlu oyunlar altın biriktirmek içindir.',
    ),
    const _Adim.metin(
      Icons.task_alt,
      'Günlük görevler',
      'Her gün yeni görevler gelir; tamamlayınca ekstra XP ve altın alırsın. Botlu oyunlardan günde en çok 10.000 altın kazanılır; sınır dolunca o gün altın gelmez.',
    ),
    const _Adim.metin(
      Icons.threed_rotation,
      'Masa',
      'Masayı parmağınla döndür, iki parmakla yakınlaştır. Sağ alttaki rozetlerle oyuncuya odaklan, tepeden bak, sıfırla.',
    ),
  ];

  late final List<int> _demoSayfalari = [for (var i = 0; i < _adimlar.length; i++) if (_adimlar[i].demoMu) i];

  bool get _atlayabilir => Ayarlar.o.ogreticiDemoBitti;

  bool get _sayfaTamam => !_adimlar[_i].demoMu || _tamam.contains(_i) || _atlayabilir;

  void _demoBitti(int i) {
    if (_tamam.contains(i)) return;
    setState(() => _tamam.add(i));
    if (_demoSayfalari.every(_tamam.contains) && !Ayarlar.o.ogreticiDemoBitti) {
      Ayarlar.o.ogreticiDemoBitti = true;
      Ayarlar.o.kaydet();
    }
  }

  void _git(int d) => _pc.animateToPage(_i + d, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final son = _i == _adimlar.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (_i + 1) / _adimlar.length, minHeight: 6, backgroundColor: Colors.white12, color: Colors.amber),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${_i + 1} / ${_adimlar.length}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _adimlar.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final a = _adimlar[i];
                  if (a.demoMu) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: a.demo!(() => _demoBitti(i)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              child: Icon(a.ikon, size: 64, color: Colors.black),
                            ),
                            const SizedBox(height: 28),
                            Text(t(a.baslik), style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            Text(t(a.metin), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.45)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_i > 0)
                    TextButton(onPressed: () => _git(-1), child: Text(t('Geri'), style: const TextStyle(color: Colors.white70)))
                  else if (_atlayabilir)
                    TextButton(onPressed: _bitir, child: Text(t('Atla'), style: const TextStyle(color: Colors.white70))),
                  if (_i > 0 && _atlayabilir)
                    TextButton(onPressed: _bitir, child: Text(t('Atla'), style: const TextStyle(color: Colors.white38))),
                  const Spacer(),
                  if (_adimlar[_i].demoMu && !_tamam.contains(_i) && _atlayabilir && !son)
                    TextButton(onPressed: () => _git(1), child: Text(t('Bu demoyu atla'), style: const TextStyle(color: Colors.white70))),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    ),
                    onPressed: !_sayfaTamam ? null : (son ? _bitir : () => _git(1)),
                    child: Text(
                      !_sayfaTamam ? t('Görevi tamamla') : (son ? t('Başla') : t('İleri')),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bitir() {
    Ayarlar.o.ogreticiGoruldu = true;
    Ayarlar.o.kaydet();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }
}
