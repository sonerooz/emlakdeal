import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../ayarlar.dart';
import '../dil.dart';
import '../model/cards.dart';
import '../model/game.dart';

/// Rehberli ilk maç: anlatıcı (ses + yazı) ve oyunun üstüne binen ipuçları.
/// Oyun gerçek motorla oynanır; deste/eller senaryoya göre kurulur (bkz. game_screen `_ogrKur`),
/// oyuncu her adımda yalnız gösterilen karta dokunabilir.
class OgrAdim {
  const OgrAdim(this.ses, this.metin);
  final String ses; // assets/ses/<ses>.mp3
  final String metin;
}

const ogrAdimlar = <OgrAdim>[
  OgrAdim('ogr_0', "Emlak Deal'e hoş geldin! Amacın çok basit: üç farklı renkte tam tapu seti toplamak. Hadi ilk maçı birlikte oynayalım. Ben sana yol göstereceğim."),
  OgrAdim('ogr_1', "Bu senin masan. Açık Mavi setinin iki tapusu hazır, bir tane eksik. Eksik tapu elinde. Seyhan'a dokun."),
  OgrAdim('ogr_2', 'Harika! Açık Mavi seti tamamlandı. Bir set hazır, iki set daha lazım.'),
  OgrAdim('ogr_3', 'Hamle kartlarını her zaman oynamak zorunda değilsin. İşine yaramıyorsa bankaya koyup para yapabilirsin. Şu Zam Geldi kartına dokun, banka olsun.'),
  OgrAdim('ogr_4', 'Joker tapu, istediğin renge dönüşür. Jokerine dokun; onu Turuncu setine yerleştireceğim. Her turda en fazla üç hamle yaparsın. Üçüncüde sıra rakibe geçer.'),
  OgrAdim('ogr_5', 'Şimdi rakibin sırası. Bekle, ne yapacak görelim.'),
  OgrAdim('ogr_6', 'Sıra sende, iki yeni kart çektin! Takas Pazarlığı ile rakibin tapusunu kendi tapunla değiştirirsin. Rakibin Selçuklu tapusu, Mor setini tamamlayacak. Takas kartına dokun.'),
  OgrAdim('ogr_7', 'Mükemmel! Mor set de tamam. Artık iki setin var.'),
  OgrAdim('ogr_8', 'Son hamle: Haciz! Rakibin tam bir setini komple alırsın. Haciz kartına dokun, Kırmızı seti alalım.'),
  OgrAdim('ogr_9', 'Üç tam set! İlk maçını kazandın, tebrikler! Gerçek rakipler Reddet kartıyla seni durdurabilir, o yüzden Reddet kartlarını sakla. Artık gerçek oyuna hazırsın.'),
  OgrAdim('ogr_10', 'Dikkat! Rakip sana İcra Takibi oynadı, senden beş milyon istiyor. Ama elinde Reddet kartı var! Reddet\'i oyna ve bu saldırıyı geri çevir.'),
  OgrAdim('ogr_11', 'Harika! Reddet kartı saldırıyı iptal etti. Reddet hamle harcamaz, o yüzden her zaman elinde bulunsun.'),
];

const ogrMetinEn = <int, String>{
  0: 'Welcome to Emlak Deal! Your goal is simple: collect three complete property sets in different colors. Let\'s play your first match together, and I\'ll guide you.',
  1: 'This is your table. Two of the three Light Blue deeds are ready, and one is missing. The missing deed is in your hand. Tap Seyhan.',
  2: 'Great! The Light Blue set is complete. One set is done, two to go.',
  3: 'You don\'t have to play every action card. If it\'s not useful, put it in your bank and use it as money. Tap this Rent Hike card to bank it.',
  4: 'A Wild property becomes any color you want. Tap your Wild card, and I\'ll place it on your Orange set. You make up to three moves per turn. After the third, it\'s your rival\'s turn.',
  6: 'Your turn! You drew two new cards. With Swap Meet, you trade one of your deeds for a rival\'s deed. Your rival\'s Selçuklu deed will complete your Purple set. Tap the Swap Meet card.',
  7: 'Excellent! The Purple set is complete too. Now you have two sets.',
  8: 'Last move: Seizure! You take a rival\'s entire complete set. Tap the Seizure card, and let\'s take the Red set.',
  9: 'Three complete sets! You won your first match. Congratulations! Real opponents can stop you with a Reject card, so keep your Reject cards. You\'re ready for real games.',
  10: 'Watch out! Your rival played Pay Up on you, and wants five million. But you have a Reject card! Play Reject and turn the attack back.',
  11: 'Awesome! Your Reject card canceled the attack. Reject costs no move, so always keep one in your hand.',
};

/// Oyuncunun kararları: hepsi gerçek diyaloglara gider, yalnız joker rengi senaryoya göre seçilir.
class OgrDecider implements Decider {
  OgrDecider(this.asil, this.jokerRengiSec, {this.saldiriReddi});
  final Decider asil;
  final PColor? Function(List<PColor> secenekler) jokerRengiSec;

  /// Rakip saldırınca (ve elde Reddet varken) rehberli maçta Reddet'i öğreten akış; true = Reddet oynandı.
  final Future<bool> Function(String aciklama)? saldiriReddi;

  @override
  Future<bool> justSayNo(Game g, Player me, String aciklama) => asil.justSayNo(g, me, aciklama);
  @override
  Future<List<GameCard>> ode(Game g, Player me, int tutar, Player alacakli) => asil.ode(g, me, tutar, alacakli);
  @override
  Future<PColor?> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler) async =>
      jokerRengiSec(secenekler) ?? await asil.jokerRengi(g, me, joker, secenekler);
  @override
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet) => asil.atilacaklar(g, me, adet);
  @override
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama, {required bool reddedebilir}) async {
    if (reddedebilir && saldiriReddi != null && await saldiriReddi!(aciklama)) return OdemeKarari.reddet();
    return asil.odemeKarari(g, me, tutar, alacakli, aciklama, reddedebilir: reddedebilir);
  }
}

/// Adım durumunu tutar; oyun ekranı bunu dinleyip katmanı çizer.
class OgrKontrol extends ChangeNotifier {
  int adim = -1;
  String metin = '';
  int? hedefKartId; // elde dokunulması istenen kart
  bool devamGoster = false;
  bool bitti = false;
  final AudioPlayer _p = AudioPlayer();
  Completer<void>? _devam;
  Completer<void>? _oynandi;

  bool kartIzinli(GameCard c) => hedefKartId == c.id;

  Future<void> _seslendir(OgrAdim a) async {
    final ing = Dil.o.en && ogrMetinEn.containsKey(adim);
    final kisa = Duration(milliseconds: 600 + (ing ? ogrMetinEn[adim]! : a.metin).length * 55);
    if (!Ayarlar.o.sesli) {
      await Future.delayed(kisa);
      return;
    }
    try {
      await _p.stop();
      final bitis = _p.onPlayerComplete.first;
      await _p.play(AssetSource('ses/${a.ses}${ing ? '_en' : ''}.mp3'));
      await bitis.timeout(kisa + const Duration(seconds: 12), onTimeout: () {});
    } catch (_) {
      await Future.delayed(kisa);
    }
  }

  void _goster(int no, {int? kart, bool devam = false}) {
    adim = no;
    metin = Dil.o.en && ogrMetinEn.containsKey(no) ? ogrMetinEn[no]! : t(ogrAdimlar[no].metin);
    hedefKartId = kart;
    devamGoster = devam;
    notifyListeners();
  }

  /// Anlatır; ses bitince döner.
  Future<void> anlat(int no) async {
    _goster(no);
    await _seslendir(ogrAdimlar[no]);
  }

  /// Anlatır ve "Başla/Devam" düğmesine basılana kadar bekler.
  Future<void> devam(int no) async {
    _goster(no, devam: true);
    _devam = Completer<void>();
    unawaited(_seslendir(ogrAdimlar[no]));
    await _devam!.future;
    await _p.stop();
    devamGoster = false;
    notifyListeners();
  }

  void devamEt() {
    if (_devam != null && !_devam!.isCompleted) _devam!.complete();
  }

  /// Anlatır; oyuncu [kart]'ı oynayana kadar bekler (ses arkada sürer).
  Future<void> kartBekle(int no, GameCard kart) async {
    _goster(no, kart: kart.id);
    _oynandi = Completer<void>();
    unawaited(_seslendir(ogrAdimlar[no]));
    await _oynandi!.future;
    hedefKartId = null;
    notifyListeners();
  }

  void kartOynandi(GameCard c) {
    if (hedefKartId == c.id && _oynandi != null && !_oynandi!.isCompleted) _oynandi!.complete();
  }

  Future<void> durdur() async {
    bitti = true;
    await _p.stop();
    for (final c in [_devam, _oynandi]) {
      if (c != null && !c.isCompleted) c.complete();
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }
}

/// Yandan giren emlakçı karakter (ağzından çıkan konuşma balonu) + hedef kartın etrafında ışık halkası ve zıplayan parmak.
class OgrKatman extends StatefulWidget {
  const OgrKatman({super.key, required this.kontrol, required this.hedefRect, required this.atla});
  final OgrKontrol kontrol;
  final Rect? Function(int kartId) hedefRect;
  final VoidCallback atla;
  @override
  State<OgrKatman> createState() => _OgrKatmanState();
}

class _OgrKatmanState extends State<OgrKatman> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  static const double _kh = 250; // karakterin tam boyu
  static const double _gorunenH = 175; // baştan bele kadar görünen yükseklik
  static const double kw = 118; // karakter sütunu genişliği
  // pozlara göre en-boy oranı (genişlik/yükseklik): oran korunur, genişlik sütuna sığar
  static const _oran = {'emlakci': 0.463, 'emlakci_isaret': 0.479, 'emlakci_kutla': 0.629};
  // ağzın karakterin tepesinden uzaklığı (dp); konuşma üçgeni buna hizalanır
  static const _agiz = {'emlakci': 82.0, 'emlakci_isaret': 82.0, 'emlakci_kutla': 62.0};
  double _boy(String poz) => (kw / (_oran[poz] ?? 0.5)).clamp(0, _kh).toDouble();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  String _poz(OgrKontrol k) {
    if (k.adim == 7 || k.adim == 9 || k.adim == 11) return 'emlakci_kutla';
    if (k.hedefKartId != null) return 'emlakci_isaret';
    return 'emlakci';
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kontrol;
    return AnimatedBuilder(
      animation: Listenable.merge([k, _a]),
      builder: (context, _) {
        if (k.adim < 0 || k.bitti) return const SizedBox.shrink();
        final id = k.hedefKartId;
        final r = id == null ? null : widget.hedefRect(id);
        final ust = 4.0; // oyun alanının en tepesi (gövde zaten durum çubuğunun altında)
        final genislik = MediaQuery.of(context).size.width;
        final sallan = 2.5 * _a.value; // konuşurken hafif hareket
        return Stack(children: [
          if (r != null) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _IsikPainter(r.inflate(6), _a.value)))),
          if (r != null)
            Positioned(
              left: r.center.dx - 18,
              top: r.top - 44 - 8 * _a.value,
              child: const IgnorePointer(child: Text('👇', style: TextStyle(fontSize: 34))),
            ),
          // karakter: soldan kayarak girer; oran bozulmaz, belden aşağısı yumuşakça kaybolur
          Positioned(
            left: 2,
            top: ust + 2 - sallan,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -1, end: 0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.translate(offset: Offset(v * kw, 0), child: child),
                child: SizedBox(
                  width: kw,
                  height: _gorunenH,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, 0.72, 1]).createShader(r),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: _kh,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Image.asset('assets/img/${_poz(k)}.png', key: ValueKey(_poz(k)), height: _boy(_poz(k)), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // konuşma balonu: ağzından çıkar
          Positioned(
            left: kw - 2,
            width: genislik - kw - 4,
            top: ust + 2 + (_agiz[_poz(k)] ?? 80) - 29,
            child: _Balon(key: ValueKey(k.adim), metin: k.metin, devam: k.devamGoster, devamBas: k.devamEt, atla: widget.atla),
          ),
        ]);
      },
    );
  }
}

class _IsikPainter extends CustomPainter {
  _IsikPainter(this.hedef, this.nabiz);
  final Rect hedef;
  final double nabiz;

  @override
  void paint(Canvas canvas, Size size) {
    final dis = Path()..addRect(Offset.zero & size);
    final delik = Path()..addRRect(RRect.fromRectAndRadius(hedef, const Radius.circular(10)));
    canvas.drawPath(Path.combine(PathOperation.difference, dis, delik), Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      RRect.fromRectAndRadius(hedef.inflate(2 + 3 * nabiz), const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.amber.withValues(alpha: 0.6 + 0.4 * nabiz),
    );
  }

  @override
  bool shouldRepaint(_IsikPainter o) => o.hedef != hedef || o.nabiz != nabiz;
}

class _Balon extends StatelessWidget {
  const _Balon({super.key, required this.metin, required this.devam, required this.devamBas, required this.atla});
  final String metin;
  final bool devam;
  final VoidCallback devamBas, atla;

  @override
  Widget build(BuildContext context) {
    const dolgu = Color(0xFF0F2A1D);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + 0.15 * v, alignment: Alignment.centerLeft, child: child),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Material(
          color: dolgu,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber, width: 1.5)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: metin.length),
                    duration: Duration(milliseconds: metin.length * 38),
                    builder: (context, n, _) => Text(metin.substring(0, n), style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3, fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(visualDensity: VisualDensity.compact, tooltip: t('Öğreticiyi atla'), onPressed: atla, icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
              ]),
              if (devam)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: FilledButton(onPressed: devamBas, child: Text(t('Devam'))),
                  ),
                ),
            ]),
          ),
        ),
        // konuşma ucu: karakterin ağzına doğru
        Positioned(
          left: -9,
          top: 14,
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: dolgu,
                border: Border(left: BorderSide(color: Colors.amber, width: 1.5), bottom: BorderSide(color: Colors.amber, width: 1.5)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
