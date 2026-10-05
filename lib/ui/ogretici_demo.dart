import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../dil.dart';
import '../model/cards.dart';
import 'card_widget.dart';
import 'dialogs.dart';

class _Deste {
  final d = GameCard.yeniDeste();
  GameCard tapu(PColor c, [int i = 0]) => d.where((x) => x.kind == CardKind.property && x.color == c).elementAt(i);
  GameCard jokerHer() => d.firstWhere((x) => x.isMultiWild);
  GameCard joker2(PColor a, PColor b) => d.firstWhere((x) => x.isWild && x.colors.length == 2 && x.colors.contains(a) && x.colors.contains(b));
  GameCard aksiyon(ActionType a, [int i = 0]) => d.where((x) => x.isAction && x.action == a).elementAt(i);
  GameCard kira(PColor c) => d.firstWhere((x) => x.isRent && x.rentColors.contains(c));
}

abstract class DemoWidget extends StatefulWidget {
  const DemoWidget({super.key, required this.bitti});
  final VoidCallback bitti;
}

/// Demo durumu: [ipucu] her zaman ÇEVRİLMİŞ metindir.
abstract class _DS<T extends DemoWidget> extends State<T> {
  bool tamam = false;
  String? ipucu;
  bool kotu = false;

  void bitir(String m) {
    setState(() {
      tamam = true;
      ipucu = m;
      kotu = false;
    });
    widget.bitti();
  }

  void uyar(String m, {bool hata = true}) => setState(() {
        ipucu = m;
        kotu = hata;
      });

  Widget cerceve(String baslik, String gorev, List<Widget> icerik) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(baslik, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(gorev, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
          ),
          const SizedBox(height: 10),
          ...icerik,
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tamam ? Colors.green.withValues(alpha: 0.35) : (kotu ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tamam ? Colors.greenAccent : (kotu ? Colors.redAccent : Colors.transparent)),
            ),
            child: Text(
              ipucu == null ? '' : (tamam ? '✅ $ipucu' : ipucu!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
}

Widget _panel(String baslik, List<Widget> cocuk) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        cocuk.isEmpty
            ? SizedBox(height: 40, child: Center(child: Text(t('boş'), style: const TextStyle(color: Colors.white30))))
            : Wrap(spacing: 8, runSpacing: 8, children: cocuk),
      ]),
    );

class _SetGrup extends StatelessWidget {
  const _SetGrup({required this.renk, required this.kartlar, this.onTap, this.kartTap, this.vurgu = false, this.kilit = false, this.binalar = const [], this.bosYer});
  final List<GameCard> binalar;
  final String? bosYer;
  final PColor renk;
  final List<GameCard> kartlar;
  final VoidCallback? onTap;
  final void Function(GameCard)? kartTap;
  final bool vurgu, kilit;

  @override
  Widget build(BuildContext context) {
    final n = kartlar.length;
    final tam = n >= renk.setBoyu;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: vurgu ? Colors.amber : (tam ? Colors.greenAccent : Colors.white24), width: vurgu ? 2.5 : 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(backgroundColor: renk.renk, radius: 6),
            const SizedBox(width: 5),
            Text('${renk.adT} $n/${renk.setBoyu}${tam ? ' ✓' : ''}${kilit ? ' 🔒' : ''}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ]),
          if (binalar.isNotEmpty || bosYer != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 52 * 1.45,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final b in binalar) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: CardView(b, w: 52)),
                if (bosYer != null)
                  Container(
                    width: 52,
                    height: 52 * 1.45,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber, width: 1.5)),
                    child: Text(bosYer!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: 52 + (math.max(n, 1) - 1) * 22.0,
            height: 52 * 1.45,
            child: Stack(children: [
              if (n == 0) Container(width: 52, height: 52 * 1.45, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24))),
              for (var i = 0; i < n; i++)
                Positioned(left: i * 22.0, child: CardView(kartlar[i], w: 52, onTap: kartTap == null ? null : () => kartTap!(kartlar[i]))),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget _el(List<GameCard> kartlar, void Function(GameCard) tap, {Set<int> secili = const {}}) => _panel(
      t('Elin'),
      [for (final c in kartlar) CardView(c, w: 58, selected: secili.contains(c.id), onTap: () => tap(c))],
    );

// --------------------------------------------------------------------------- 1. tapu setleri
class DemoSet extends DemoWidget {
  const DemoSet({super.key, required super.bitti});
  @override
  State<DemoSet> createState() => _DemoSetState();
}

class _DemoSetState extends _DS<DemoSet> {
  final dk = _Deste();
  late final List<GameCard> el;
  final masa = <PColor, List<GameCard>>{PColor.brown: [], PColor.lightBlue: []};

  @override
  void initState() {
    super.initState();
    el = [dk.tapu(PColor.brown, 0), dk.tapu(PColor.lightBlue, 0), dk.tapu(PColor.brown, 1), dk.tapu(PColor.lightBlue, 1), dk.tapu(PColor.lightBlue, 2)];
  }

  void oyna(GameCard c) {
    if (tamam) return;
    final r = c.color!;
    setState(() {
      el.remove(c);
      masa[r]!.add(c);
    });
    if (el.isEmpty) {
      bitir(t('Harika! İki set de tamam. Oyunu, FARKLI renkte 3 tam set toplayan kazanır.'));
    } else if (masa[r]!.length >= r.setBoyu) {
      uyar(t('{renk} seti tamamlandı! Set boyu (2, 3 ya da 4) kartın üstünde yazar.', {'renk': r.adT}), hata: false);
    }
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Tapu setleri'),
        t('Tapu kartlarına dokunarak masana koy. Aynı renkteki tapular bir sette toplanır; sette kaç tapu gerektiği başlıkta yazar (ör. 0/2). Tüm kartları koy.'),
        [
          _panel(t('Masan'), [for (final e in masa.entries) _SetGrup(renk: e.key, kartlar: e.value)]),
          const SizedBox(height: 8),
          _el(el, oyna),
        ],
      );
}

// --------------------------------------------------------------------------- 2/3. joker
class DemoJoker extends DemoWidget {
  const DemoJoker({super.key, required super.bitti, required this.cokRenkli});
  final bool cokRenkli;
  @override
  State<DemoJoker> createState() => _DemoJokerState();
}

class _DemoJokerState extends _DS<DemoJoker> {
  final dk = _Deste();
  late final GameCard joker;
  late final PColor hedef, baslangic;
  final masa = <PColor, List<GameCard>>{};

  @override
  void initState() {
    super.initState();
    if (widget.cokRenkli) {
      hedef = PColor.green;
      baslangic = PColor.darkBlue;
      joker = dk.jokerHer();
      masa[PColor.green] = [dk.tapu(PColor.green, 0), dk.tapu(PColor.green, 1)];
      masa[PColor.darkBlue] = [];
    } else {
      hedef = PColor.orange;
      baslangic = PColor.pink;
      joker = dk.joker2(PColor.pink, PColor.orange);
      masa[PColor.orange] = [dk.tapu(PColor.orange, 0), dk.tapu(PColor.orange, 1)];
      masa[PColor.pink] = [];
    }
    joker.wildColor = baslangic;
    masa[baslangic]!.add(joker);
  }

  Future<void> degistir() async {
    if (tamam) return;
    final secenek = widget.cokRenkli ? PColor.values.toList() : List.of(joker.colors);
    final yeni = await pickColor(context, t('🃏 Joker hangi renk olsun?'), secenek,
        iptalOlur: true, altYazi: (k) => '(${(masa[k] ?? const <GameCard>[]).where((x) => x != joker).length}/${k.setBoyu})');
    if (yeni == null || !mounted) return;
    setState(() {
      for (final l in masa.values) {
        l.remove(joker);
      }
      joker.wildColor = yeni;
      masa.putIfAbsent(yeni, () => []).add(joker);
    });
    if (yeni == hedef) {
      bitir(t('Joker {renk} oldu ve set tamamlandı! Oyunda da kendi turunda masadaki jokere dokunup rengini değiştirebilirsin.', {'renk': hedef.adT}));
    } else {
      uyar(t('{a} bu seti tamamlamıyor. {b} setin 2/{n}: jokeri {b} yap.', {'a': yeni.adT, 'b': hedef.adT, 'n': hedef.setBoyu}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sirali = masa.entries.where((e) => e.value.isNotEmpty || e.key == hedef).toList();
    final p = {'h': hedef.adT, 'b': baslangic.adT, 'n': hedef.setBoyu};
    return cerceve(
      widget.cokRenkli ? t('Joker tapu (her renk)') : t('İki renkli joker'),
      widget.cokRenkli
          ? t('Joker Tapu istediğin renkte sayılır. {h} setin 2/{n} ama joker şu an {b} sette duruyor. Jokere dokun, rengini {h} yap ve seti tamamla.', p)
          : t('İki renkli joker yalnızca üstünde yazan iki renkten biri olur. {h} setin 2/{n}, joker şu an {b}. Jokere dokun, rengini {h} yap.', p),
      [
        _panel(t('Masan'), [
          for (final e in sirali)
            _SetGrup(
              renk: e.key,
              kartlar: e.value,
              vurgu: !tamam && e.value.contains(joker),
              kartTap: (c) {
                if (c == joker) degistir();
              },
            ),
        ]),
        const SizedBox(height: 6),
        Text(t('👆 Jokere dokun'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// --------------------------------------------------------------------------- 4. kira
class DemoKira extends DemoWidget {
  const DemoKira({super.key, required super.bitti});
  @override
  State<DemoKira> createState() => _DemoKiraState();
}

class _DemoKiraState extends _DS<DemoKira> {
  final dk = _Deste();
  late final GameCard kart;
  late final List<GameCard> yesil;
  bool oynandi = false;

  @override
  void initState() {
    super.initState();
    kart = dk.kira(PColor.green);
    yesil = [dk.tapu(PColor.green, 0), dk.tapu(PColor.green, 1)];
  }

  int get kiraTutari => PColor.green.kira[math.min(yesil.length, PColor.green.setBoyu) - 1];

  void oyna(GameCard c) {
    if (tamam) return;
    setState(() => oynandi = true);
    bitir(t('Kira kartı oynandı: {n} Yeşil tapun var, kira {k}M. HERKES sana {k}M öder. Tapu sayın ve ev/rezidans kirayı artırır; Zam Geldi kartı kirayı 2 katına çıkarır (2 hamle harcar).', {'n': yesil.length, 'k': kiraTutari}));
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Kira kartı'),
        t('Kira kartını oynamak için o renklerden birinde tapun olmalı. Elindeki kira kartına dokun: oyun en yüksek kirayı veren rengi kendisi seçer.'),
        [
          _panel(t('🤖 Rakipler'), [
            for (var i = 1; i <= 2; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                child: Text(oynandi ? '🤖 Bot $i → ${kiraTutari}M 💸' : '🤖 Bot $i', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 8),
          _panel(t('Masan'), [_SetGrup(renk: PColor.green, kartlar: yesil)]),
          const SizedBox(height: 8),
          if (!oynandi) _el([kart], oyna),
        ],
      );
}

// --------------------------------------------------------------------------- 5. tapu devri
class DemoTapuDevri extends DemoWidget {
  const DemoTapuDevri({super.key, required super.bitti});
  @override
  State<DemoTapuDevri> createState() => _DemoTapuDevriState();
}

class _DemoTapuDevriState extends _DS<DemoTapuDevri> {
  final dk = _Deste();
  late final GameCard kart;
  late final List<GameCard> turuncu, kahve;
  final benim = <GameCard>[];
  bool secili = false;
  bool kullandi = false;

  @override
  void initState() {
    super.initState();
    kart = dk.aksiyon(ActionType.slyDeal);
    turuncu = [dk.tapu(PColor.orange, 0), dk.tapu(PColor.orange, 1)];
    kahve = [dk.tapu(PColor.brown, 0), dk.tapu(PColor.brown, 1)];
  }

  void rakibe(GameCard c, PColor renk) {
    if (tamam) return;
    if (!secili) return uyar(t('Önce elindeki Tapu Devri kartına dokun.'));
    if (renk == PColor.brown) return uyar(t('Kahverengi set TAM, tam setteki tapu çalınamaz. Tamamlanmamış sete dokun. (Tam seti almak için Haciz gerekir.)'));
    setState(() {
      turuncu.remove(c);
      benim.add(c);
      kullandi = true;
    });
    bitir(t('Tapuyu çaldın! Tapu Devri yalnızca rakibin TAMAMLANMAMIŞ setindeki tapuyu alır.'));
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Tapu Devri'),
        t('Önce Tapu Devri kartına dokun, sonra rakibin bir tapusuna dokun. Kural: sadece tamamlanmamış setten tapu alınır.'),
        [
          _panel(t('🤖 Rakip'), [
            _SetGrup(renk: PColor.orange, kartlar: turuncu, vurgu: secili && !tamam, kartTap: (c) => rakibe(c, PColor.orange)),
            _SetGrup(renk: PColor.brown, kartlar: kahve, kilit: true, kartTap: (c) => rakibe(c, PColor.brown)),
          ]),
          const SizedBox(height: 8),
          _panel(t('Masan'), [if (benim.isNotEmpty) _SetGrup(renk: PColor.orange, kartlar: benim)]),
          const SizedBox(height: 8),
          if (!kullandi)
            _el([kart], (c) {
              setState(() => secili = true);
              uyar(t('Şimdi rakibin bir tapusuna dokun.'), hata: false);
            }, secili: secili ? {kart.id} : const {}),
        ],
      );
}

// --------------------------------------------------------------------------- 6. takas
class DemoTakas extends DemoWidget {
  const DemoTakas({super.key, required super.bitti});
  @override
  State<DemoTakas> createState() => _DemoTakasState();
}

class _DemoTakasState extends _DS<DemoTakas> {
  final dk = _Deste();
  late final GameCard kart;
  late final List<GameCard> kirmizi, sari, mavi;
  GameCard? rakipSecim;
  bool secili = false;
  bool kullandi = false;

  @override
  void initState() {
    super.initState();
    kart = dk.aksiyon(ActionType.forcedDeal);
    kirmizi = [dk.tapu(PColor.red, 0), dk.tapu(PColor.red, 1)];
    sari = [dk.tapu(PColor.yellow, 0)];
    mavi = [dk.tapu(PColor.lightBlue, 0), dk.tapu(PColor.lightBlue, 1), dk.tapu(PColor.lightBlue, 2)];
  }

  void rakipTikla(GameCard c) {
    if (tamam) return;
    if (!secili) return uyar(t('Önce elindeki Takas Pazarlığı kartına dokun.'));
    setState(() => rakipSecim = c);
    uyar(t('Şimdi kendi tamamlanmamış setinden vereceğin tapuya dokun (Sarı).'), hata: false);
  }

  void benimTikla(GameCard c, bool tamSet) {
    if (tamam) return;
    if (!secili) return uyar(t('Önce elindeki Takas Pazarlığı kartına dokun.'));
    final r = rakipSecim;
    if (r == null) return uyar(t('Önce rakipten almak istediğin tapuya dokun (Kırmızı).'));
    if (tamSet) return uyar(t('Tam setindeki tapuyu veremezsin. Tamamlanmamış setinden bir tapu seç (Sarı).'));
    setState(() {
      kirmizi.remove(r);
      sari.remove(c);
      sari.add(r);
      kirmizi.add(c);
      kullandi = true;
    });
    bitir(t('Takas tamam! İki taraftan da tamamlanmamış setlerden birer tapu değişir; tam setler takas edilemez.'));
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Takas Pazarlığı'),
        t('Kartına dokun, sonra rakibin tamamlanmamış setinden (Kırmızı) bir tapu seç, sonra kendi tamamlanmamış setinden (Sarı) bir tapu seç. Tam setler (Açık Mavi 🔒) takas edilemez.'),
        [
          _panel(t('🤖 Rakip'), [_SetGrup(renk: PColor.red, kartlar: kirmizi, vurgu: secili && rakipSecim == null && !tamam, kartTap: rakipTikla)]),
          const SizedBox(height: 8),
          _panel(t('Masan'), [
            _SetGrup(renk: PColor.yellow, kartlar: sari, vurgu: rakipSecim != null && !tamam, kartTap: (c) => benimTikla(c, false)),
            _SetGrup(renk: PColor.lightBlue, kartlar: mavi, kilit: true, kartTap: (c) => benimTikla(c, true)),
          ]),
          const SizedBox(height: 8),
          if (!kullandi)
            _el([kart], (c) {
              setState(() => secili = true);
              uyar(t('Şimdi rakibin almak istediğin tapusuna dokun (Kırmızı).'), hata: false);
            }, secili: secili ? {kart.id} : const {}),
        ],
      );
}

// --------------------------------------------------------------------------- 7. haciz
class DemoHaciz extends DemoWidget {
  const DemoHaciz({super.key, required super.bitti});
  @override
  State<DemoHaciz> createState() => _DemoHacizState();
}

class _DemoHacizState extends _DS<DemoHaciz> {
  final dk = _Deste();
  late final GameCard kart;
  late final List<GameCard> mavi, mor;
  final benim = <GameCard>[];
  bool secili = false;
  bool kullandi = false;

  @override
  void initState() {
    super.initState();
    kart = dk.aksiyon(ActionType.dealBreaker);
    mavi = [dk.tapu(PColor.lightBlue, 0), dk.tapu(PColor.lightBlue, 1), dk.tapu(PColor.lightBlue, 2)];
    mor = [dk.tapu(PColor.pink, 0)];
  }

  void sete(PColor renk) {
    if (tamam) return;
    if (!secili) return uyar(t('Önce elindeki Haciz kartına dokun.'));
    if (renk == PColor.pink) return uyar(t('Haciz yalnızca TAM seti alır. Mor set 1/3, tam olan Açık Mavi sete dokun.'));
    setState(() {
      benim.addAll(mavi);
      mavi.clear();
      kullandi = true;
    });
    bitir(t('Tüm seti aldın! Haciz, rakibin tamamlanmış setini (üstündeki ev/rezidansla birlikte) komple alır. Güçlü bir karttır, rakip Reddet ile karşılık verebilir.'));
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Haciz'),
        t('Haciz kartına dokun, sonra rakibin TAM setine dokun. Tek tapu değil, seti komple alırsın.'),
        [
          _panel(t('🤖 Rakip'), [
            if (mavi.isNotEmpty) _SetGrup(renk: PColor.lightBlue, kartlar: mavi, vurgu: secili && !tamam, onTap: () => sete(PColor.lightBlue), kartTap: (_) => sete(PColor.lightBlue)),
            _SetGrup(renk: PColor.pink, kartlar: mor, onTap: () => sete(PColor.pink), kartTap: (_) => sete(PColor.pink)),
          ]),
          const SizedBox(height: 8),
          _panel(t('Masan'), [if (benim.isNotEmpty) _SetGrup(renk: PColor.lightBlue, kartlar: benim)]),
          const SizedBox(height: 8),
          if (!kullandi)
            _el([kart], (c) {
              setState(() => secili = true);
              uyar(t('Şimdi rakibin tam setine dokun.'), hata: false);
            }, secili: secili ? {kart.id} : const {}),
        ],
      );
}

// --------------------------------------------------------------------------- 8. reddet
class DemoReddet extends DemoWidget {
  const DemoReddet({super.key, required super.bitti});
  @override
  State<DemoReddet> createState() => _DemoReddetState();
}

class _DemoReddetState extends _DS<DemoReddet> {
  final dk = _Deste();
  late List<GameCard> el;
  late final List<GameCard> yesil;
  int asama = 0; // 0: ilk saldırı, 1: rakip karşı Reddet oynadı
  bool setVar = true;

  @override
  void initState() {
    super.initState();
    el = [dk.aksiyon(ActionType.justSayNo, 0), dk.aksiyon(ActionType.justSayNo, 1)];
    yesil = [dk.tapu(PColor.green, 0), dk.tapu(PColor.green, 1), dk.tapu(PColor.green, 2)];
  }

  void reddet(GameCard c) {
    if (tamam || el.isEmpty) return;
    setState(() => el.remove(c));
    if (asama == 0) {
      setState(() => asama = 1);
      uyar(t('✋ Reddet oynadın: Haciz iptal! Ama rakip de elindeki Reddet ile karşılık verdi: Haciz yeniden geçerli. Sen de bir kez daha Reddet oynayabilirsin.'), hata: false);
    } else {
      bitir(t('Sen de Reddet oynadın ve zinciri kazandın. Haciz kesin iptal! Reddet hamle harcamaz; elinde varsa her saldırıda kullanabilirsin.'));
    }
  }

  void kabul() {
    if (tamam) return;
    setState(() => setVar = false);
    uyar(t('Setini kaybettin! Elinde Reddet varken kabul etme. Tekrar deneniyor…'));
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || tamam) return;
      setState(() {
        setVar = true;
        asama = 0;
        el = [dk.aksiyon(ActionType.justSayNo, 0), dk.aksiyon(ActionType.justSayNo, 1)];
        ipucu = null;
        kotu = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Reddet'),
        t('Rakip sana saldırınca Reddet kartıyla hamleyi iptal edebilirsin. Rakip sana Haciz oynadı ve Yeşil setini istiyor! Reddet kartına dokun.'),
        [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
            child: Text(
              asama == 0 ? t('🤖 Rakip Haciz oynadı: Yeşil setini istiyor!') : t('🤖 Rakip Reddet ile karşılık verdi: Haciz yeniden geçerli!'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          _panel(t('Masan'), [if (setVar) _SetGrup(renk: PColor.green, kartlar: yesil, vurgu: !tamam)]),
          const SizedBox(height: 8),
          if (!tamam && setVar) _el(el, reddet),
          if (!tamam && setVar)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(onPressed: kabul, style: OutlinedButton.styleFrom(foregroundColor: Colors.white70), child: Text(t('Kabul et (setimi ver)'))),
            ),
        ],
      );
}

// --------------------------------------------------------------------------- 9. ev / rezidans
class DemoEv extends DemoWidget {
  const DemoEv({super.key, required super.bitti});
  @override
  State<DemoEv> createState() => _DemoEvState();
}

class _DemoEvState extends _DS<DemoEv> {
  final dk = _Deste();
  late final GameCard ev, otel;
  late final List<GameCard> kirmizi;
  final el = <GameCard>[];
  bool evKondu = false, otelKondu = false;

  @override
  void initState() {
    super.initState();
    ev = dk.aksiyon(ActionType.house);
    otel = dk.aksiyon(ActionType.hotel);
    el.addAll([otel, ev]);
    kirmizi = [dk.tapu(PColor.red, 0), dk.tapu(PColor.red, 1), dk.tapu(PColor.red, 2)];
  }

  int get kira => PColor.red.kira[2] + (evKondu ? 3 : 0) + (otelKondu ? 4 : 0);

  void koy(GameCard c) {
    if (tamam) return;
    if (c == otel && !evKondu) return uyar(t('Rezidans için önce sete bir Ev koymalısın.'));
    setState(() {
      el.remove(c);
      if (c == ev) evKondu = true;
      if (c == otel) otelKondu = true;
    });
    if (otelKondu) {
      bitir(t('Kırmızı set artık {k}M kira getiriyor! Ev ve Rezidans yalnızca TAM setlere konur (Ulaşım ve Altyapı hariç).', {'k': kira}));
    } else {
      uyar(t('Ev kondu, kira {k}M oldu (+3M). Şimdi Rezidansı koy.', {'k': kira}), hata: false);
    }
  }

  @override
  Widget build(BuildContext context) => cerceve(
        t('Ev ve Rezidans'),
        t('Ev ve Rezidans kartları setin ÜSTÜNE konur. Elindeki Ev kartına dokun: set tamam olduğu için kart setin üstüne oturur ve kira artar. Sonra Rezidansı koy; Rezidans için Ev şart. Önce Rezidans kartına dokunmayı dene, sonra doğru sırayla koy.'),
        [
          _panel(t('Masan'), [
            _SetGrup(
              renk: PColor.red,
              kartlar: kirmizi,
              binalar: [if (otelKondu) otel, if (evKondu) ev],
              bosYer: otelKondu ? null : (evKondu ? t('Rezidans buraya') : t('Ev buraya')),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: Text('${evKondu ? '🏠 ' : ''}${otelKondu ? '🏨 ' : ''}${t('Kira')}: ${kira}M', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 8),
          if (el.isNotEmpty) _el(el, koy),
        ],
      );
}
