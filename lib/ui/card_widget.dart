import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/cards.dart';
import '../dil.dart';

const _krem = Color(0xFFFBF6E9);
const _kahve = Color(0xFF2B2113);
const _altin = Color(0xFFC9A227);
const _soluk = Color(0xFF7A6A4A);
const _gok = [Color(0xFFD9342B), Color(0xFFF08A24), Color(0xFFF2D53C), Color(0xFF1E9E4A), Color(0xFF3FC1C9), Color(0xFF1F3F9E), Color(0xFFB03A9E)];
const _silAd = {
  PColor.brown: 'gaziantep',
  PColor.lightBlue: 'adana',
  PColor.pink: 'konya',
  PColor.orange: 'antalya',
  PColor.red: 'bursa',
  PColor.yellow: 'izmir',
  PColor.green: 'ankara',
  PColor.darkBlue: 'istanbul',
  PColor.railroad: 'ulasim',
  PColor.utility: 'altyapi',
};

double _lum(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
Color _yazi(Color c) => _lum(c) > 0.62 ? _kahve : Colors.white;
Color _tint(Color c) => _lum(c) > 0.55 ? Color.lerp(c, Colors.black, 0.38)! : c;
String _buyuk(String s) => Dil.o.en ? s.toUpperCase() : s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

Text _x(String s, double fs, {Color color = _kahve, FontWeight fw = FontWeight.w700, double ls = 0, double h = 1.2, TextAlign? al, int? max, List<Shadow>? sh}) => Text(
      s,
      textAlign: al,
      maxLines: max,
      overflow: max == null ? null : TextOverflow.ellipsis,
      style: TextStyle(fontSize: fs, color: color, fontWeight: fw, letterSpacing: ls, height: h, shadows: sh, decoration: TextDecoration.none),
    );

/// Tek kart görseli. Tasarım 180×260 ölçüsünde çizilir, [w] genişliğine ölçeklenir (yükseklik 1.45×).
class CardView extends StatelessWidget {
  const CardView(this.card, {super.key, this.w = 72, this.selected = false, this.onTap, this.dim = false});
  final GameCard card;
  final double w;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  static const double _tw = 180, _th = 260;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: w,
      height: w * 1.45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.078),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.078),
        border: Border.all(color: selected ? Colors.amber : Colors.black26, width: selected ? 3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: _tw, height: _th, child: _govde()),
      ),
    );
    return GestureDetector(onTap: onTap, child: Opacity(opacity: dim ? 0.45 : 1, child: body));
  }

  Widget _govde() {
    switch (card.kind) {
      case CardKind.money:
        return _para();
      case CardKind.property:
        return _tapu(card.color!);
      case CardKind.wild:
        return card.isMultiWild ? _cokJoker() : _ikiliJoker();
      case CardKind.action:
        return _aksiyon();
      case CardKind.rent:
        return _kira();
    }
  }

  // ------------------------------------------------------------ ortak parçalar
  Widget _rozet(int v, {bool ters = false}) {
    if (v <= 0) return const SizedBox.shrink();
    final c = paraRengi(v);
    final daire = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: Border.all(color: _krem, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: _x('${v}M', 14, color: v == 1 ? _kahve : Colors.white, fw: FontWeight.w900, ls: -0.5, h: 1, sh: v == 1 ? null : const [Shadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1))]),
    );
    return Positioned(
      left: ters ? null : 7,
      top: ters ? null : 7,
      right: ters ? 7 : null,
      bottom: ters ? 7 : null,
      child: ters ? RotatedBox(quarterTurns: 2, child: daire) : daire,
    );
  }

  Widget _sil(PColor c) => Image.asset(
        'assets/siluet/${_silAd[c]}.png',
        color: _tint(c.renk),
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
      );

  Widget _satir(String l, int v, {bool soluk = false, double fs = 10.5}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _x(l, soluk ? fs - 1 : fs, color: soluk ? _soluk : _kahve, fw: FontWeight.w500, h: 1.15),
          _x('${v}M', soluk ? fs - 1 : fs, fw: FontWeight.w800, h: 1.15),
        ]),
      );

  String _kiraEtiket(PColor c, int j) {
    if (c == PColor.railroad) return t('{n} ulaşım tapusu', {'n': j + 1});
    if (c == PColor.utility) return t('{n} altyapı tapusu', {'n': j + 1});
    if (j == 0) return t('Tek tapu');
    if (j + 1 == c.setBoyu) return t('{n} tapu (tam set)', {'n': j + 1});
    return t('{n} tapu', {'n': j + 1});
  }

  // ------------------------------------------------------------ mülk
  Widget _tapu(PColor c) {
    final kira = c.kira;
    final ad = card.sokak != null ? t(card.sokak!) : c.adT;
    final sehir = _buyuk(t(c.sehir));
    final etiket = c.binaOlur ? t('TAPU SENEDİ · {s}', {'s': sehir}) : t('{s} TAPUSU', {'s': sehir});
    final tam = kira.last;
    return Stack(children: [
      Container(color: _krem),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 64,
          color: c.renk,
          padding: const EdgeInsets.fromLTRB(54, 8, 8, 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _x(etiket, 8.5, color: _yazi(c.renk), ls: 1, max: 1),
            const SizedBox(height: 2),
            _x(ad, ad.length > 11 ? 12.5 : 15, color: _yazi(c.renk), fw: FontWeight.w800, h: 1.1, max: 2),
          ]),
        ),
        Container(height: 54, margin: const EdgeInsets.fromLTRB(10, 5, 10, 0), child: _sil(c)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 156,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _x(t('KİRA BEDELİ'), 8.5, color: _soluk, ls: 1),
                  Container(height: 1, margin: const EdgeInsets.only(top: 2, bottom: 2), color: const Color(0x332B2113)),
                  for (var j = 0; j < kira.length; j++) _satir(_kiraEtiket(c, j), kira[j]),
                  if (c.binaOlur) ...[
                    _satir(t('Tam set + Ev'), tam + 3, soluk: true),
                    _satir(t('+ Ev + Rezidans'), tam + 7, soluk: true),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
      _rozet(card.paraDegeri),
    ]);
  }

  // ------------------------------------------------------------ joker mülk
  Widget _yari(PColor c, {required bool ters}) {
    final kira = c.kira;
    final renkYazi = _yazi(c.renk);
    final govde = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 64,
        color: c.renk,
        padding: EdgeInsets.fromLTRB(ters ? 10 : 54, 8, ters ? 54 : 10, 6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _x(t('JOKER · {s}', {'s': _buyuk(t(c.sehir))}), 8.5, color: renkYazi, ls: 1, max: 1),
          const SizedBox(height: 2),
          _x(c.adT, 15, color: renkYazi, fw: FontWeight.w800, h: 1.1, max: 1),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 156,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var j = 0; j < kira.length; j++) _satir(t('{n} tapu', {'n': j + 1}), kira[j], fs: 10),
              ]),
            ),
          ),
        ),
      ),
    ]);
    return ters ? RotatedBox(quarterTurns: 2, child: govde) : govde;
  }

  Widget _ikiliJoker() {
    final a = card.colors[0], b = card.colors[1];
    final ust = card.wildColor == b ? b : a;
    final alt = ust == a ? b : a;
    final secili = card.wildColor != null;
    return Stack(children: [
      Container(color: _krem),
      Column(children: [
        Expanded(child: _yari(ust, ters: false)),
        Container(
          height: 2,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00C9A227), _altin, _altin, Color(0x00C9A227)], stops: [0, 0.18, 0.82, 1])),
        ),
        Expanded(child: Opacity(opacity: secili ? 0.6 : 1, child: _yari(alt, ters: true))),
      ]),
      Positioned(
        top: 120,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _krem,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _altin, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: _x('✦ JOKER ✦', 8, color: const Color(0xFF8A6A14), fw: FontWeight.w900, ls: 2, h: 1.3),
          ),
        ),
      ),
      _rozet(card.paraDegeri),
      _rozet(card.paraDegeri, ters: true),
    ]);
  }

  Widget _cokJoker() {
    const gok = LinearGradient(colors: _gok, begin: Alignment(-1, -0.3), end: Alignment(1, 0.3));
    return Stack(children: [
      Container(color: _krem),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 64,
          decoration: const BoxDecoration(gradient: gok),
          padding: const EdgeInsets.fromLTRB(54, 8, 8, 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _x(t('JOKER TAPU'), 8.5, color: Colors.white, ls: 1, sh: const [Shadow(color: Color(0xAA000000), blurRadius: 3)]),
            const SizedBox(height: 2),
            _x(t('Her renk'), 15, color: Colors.white, fw: FontWeight.w800, h: 1.1, sh: const [Shadow(color: Color(0xAA000000), blurRadius: 3)]),
          ]),
        ),
        Container(
          height: 54,
          margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(colors: _gok).createShader(r),
            child: Image.asset('assets/siluet/istanbul.png', color: Colors.white, colorBlendMode: BlendMode.srcIn, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: card.wildColor == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _x(t('Her renkli set'), 12, fw: FontWeight.w800),
                    const SizedBox(height: 3),
                    _x(t('Bu kartı dilediğin renkli setin yerine koy. Rengini sonradan değiştirebilirsin. Tek başına para değeri yoktur.'), 10.5, fw: FontWeight.w500, h: 1.35),
                  ])
                : Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: card.wildColor!.renk, borderRadius: BorderRadius.circular(8)),
                      child: _x('▲ ${card.wildColor!.adT}', 14, color: _yazi(card.wildColor!.renk), fw: FontWeight.w800),
                    ),
                  ),
          ),
        ),
      ]),
    ]);
  }

  // ------------------------------------------------------------ para
  static const _paraAd = {1: 'BİR MİLYON', 2: 'İKİ MİLYON', 3: 'ÜÇ MİLYON', 4: 'DÖRT MİLYON', 5: 'BEŞ MİLYON', 10: 'ON MİLYON'};

  Widget _para() {
    final v = card.value;
    final golge = [const Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))];
    return Container(
      decoration: BoxDecoration(color: paraRengi(v), border: Border.all(color: _krem, width: 6)),
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(0),
            decoration: BoxDecoration(border: Border.all(color: const Color(0x88FFFFFF), width: 1.5), borderRadius: BorderRadius.circular(8)),
          ),
        ),
        Positioned(left: 12, top: 9, child: _x('${v}M', 20, color: Colors.white, fw: FontWeight.w900, h: 1, sh: golge)),
        Positioned(right: 12, bottom: 9, child: _x('${v}M', 20, color: Colors.white, fw: FontWeight.w900, h: 1, sh: golge)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _x('${v}M', 46, color: Colors.white, fw: FontWeight.w900, h: 1, sh: golge),
            const SizedBox(height: 6),
            _x(t(_paraAd[v] ?? '${v}M'), 9, color: Colors.white, ls: 2, sh: golge),
          ]),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------ aksiyon
  static const _emoji = {
    ActionType.dealBreaker: '⚖️',
    ActionType.slyDeal: '📜',
    ActionType.forcedDeal: '🔁',
    ActionType.tahsilat: '📑',
    ActionType.birthday: '🎉',
    ActionType.house: '🏠',
    ActionType.hotel: '🏢',
  };

  Widget _ikon(ActionType a, Color c) {
    switch (a) {
      case ActionType.justSayNo:
        return CustomPaint(size: const Size(66, 66), painter: _BlokPainter(c));
      case ActionType.doubleRent:
        return SizedBox(
          width: 76,
          height: 66,
          child: Stack(clipBehavior: Clip.none, children: [
            CustomPaint(size: const Size(76, 64), painter: _ZamPainter(c)),
            Positioned(right: 0, bottom: -4, child: _x('x2', 26, color: c, fw: FontWeight.w900, h: 1)),
          ]),
        );
      case ActionType.passGo:
        return CustomPaint(size: const Size(64, 64), painter: _IkiKartPainter(c));
      default:
        return Text(_emoji[a] ?? '', style: const TextStyle(fontSize: 52, height: 1.2, decoration: TextDecoration.none));
    }
  }

  Widget _aksiyon() {
    final a = card.action!;
    final c = paraRengi(card.paraDegeri);
    final gelistirme = a == ActionType.house || a == ActionType.hotel;
    return Container(
      color: const Color(0xFF1C2430),
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(9)),
          ),
        ),
        Positioned(top: 19, left: 0, right: 0, child: Center(child: _x(t(gelistirme ? 'GELİŞTİRME' : 'AKSİYON'), 9, color: c, ls: 2))),
        Positioned(top: 56, left: 0, right: 0, height: 70, child: Center(child: _ikon(a, c))),
        Positioned(
          top: 138,
          left: 12,
          right: 12,
          child: FittedBox(fit: BoxFit.scaleDown, child: _x(a.adT, 19, color: c, fw: FontWeight.w800, h: 1.2)),
        ),
        Positioned(
          top: 172,
          left: 16,
          right: 16,
          child: _x(a.aciklamaT, 11, color: const Color(0xFFDDDDEE), fw: FontWeight.w500, h: 1.4, al: TextAlign.center, max: 4),
        ),
        _rozet(card.paraDegeri),
      ]),
    );
  }

  // ------------------------------------------------------------ kira
  Widget _kira() {
    final joker = card.isWildRent;
    final a = joker ? null : card.rentColors[0];
    final b = joker ? null : card.rentColors[1];
    final disk = Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _krem, width: 5),
        boxShadow: const [BoxShadow(color: _kahve, spreadRadius: 2.5), BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ClipOval(
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: CustomPaint(painter: _DiskPainter(a?.renk, b?.renk))),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _kahve, border: Border.all(color: _krem, width: 3)),
            child: const Icon(Icons.home_outlined, color: _krem, size: 34),
          ),
        ]),
      ),
    );
    Widget chip(Widget nokta, String ad) => Row(mainAxisSize: MainAxisSize.min, children: [
          nokta,
          const SizedBox(width: 4),
          _x(ad, 10.5, fw: FontWeight.w700),
        ]);
    Widget nokta(Color c) => Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: _kahve, width: 1.5)));
    return Stack(children: [
      Container(color: _krem),
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(border: Border.all(color: const Color(0x332B2113), width: 1.5), borderRadius: BorderRadius.circular(9)),
        ),
      ),
      Positioned(top: 19, left: 0, right: 0, child: Center(child: _x(t(joker ? 'JOKER KİRA' : 'KİRA'), 9, color: _soluk, ls: 2))),
      Positioned(top: 58, left: 0, right: 0, child: Center(child: disk)),
      Positioned(
        top: 176,
        left: 10,
        right: 10,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: joker
              ? [
                  chip(
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const SweepGradient(colors: [..._gok, Color(0xFFD9342B)]), border: Border.all(color: _kahve, width: 1.5)),
                    ),
                    t('Her renk'),
                  ),
                ]
              : [chip(nokta(a!.renk), a.adT), chip(nokta(b!.renk), b.adT)],
        ),
      ),
      Positioned(
        top: 204,
        left: 12,
        right: 12,
        child: Column(children: [
          _x(t('HERKESTEN'), 14, fw: FontWeight.w800, ls: 1, h: 1.2),
          const SizedBox(height: 2),
          _x(joker ? t('istediğin renkten kira al') : t('kira al'), 11, fw: FontWeight.w500, h: 1.35, al: TextAlign.center),
        ]),
      ),
      _rozet(card.paraDegeri),
    ]);
  }
}

class _BlokPainter extends CustomPainter {
  _BlokPainter(this.c);
  final Color c;
  @override
  void paint(Canvas cv, Size s) {
    final k = s.width / 64;
    final p = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 7 * k..strokeCap = StrokeCap.round;
    cv.drawCircle(Offset(32 * k, 32 * k), 24 * k, p);
    cv.drawLine(Offset(15 * k, 49 * k), Offset(49 * k, 15 * k), p);
  }

  @override
  bool shouldRepaint(covariant _BlokPainter o) => o.c != c;
}

class _ZamPainter extends CustomPainter {
  _ZamPainter(this.c);
  final Color c;
  @override
  void paint(Canvas cv, Size s) {
    final p = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    cv.drawPath(Path()..moveTo(4, 52)..lineTo(22, 34)..lineTo(32, 42)..lineTo(52, 18), p);
    cv.drawPath(Path()..moveTo(40, 14)..lineTo(56, 14)..lineTo(56, 30), p);
  }

  @override
  bool shouldRepaint(covariant _ZamPainter o) => o.c != c;
}

class _IkiKartPainter extends CustomPainter {
  _IkiKartPainter(this.c);
  final Color c;
  @override
  void paint(Canvas cv, Size s) {
    final k = s.width / 64;
    cv.scale(k);
    final cizgi = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round;
    void kart(Rect r, double derece, Offset eksen, {bool dolgu = false}) {
      cv.save();
      cv.translate(eksen.dx, eksen.dy);
      cv.rotate(derece * math.pi / 180);
      cv.translate(-eksen.dx, -eksen.dy);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      if (dolgu) cv.drawRRect(rr, Paint()..color = const Color(0xFF1C2430));
      cv.drawRRect(rr, cizgi);
      cv.restore();
    }

    kart(const Rect.fromLTWH(9, 16, 26, 36), -12, const Offset(22, 34));
    kart(const Rect.fromLTWH(26, 12, 26, 36), 10, const Offset(39, 30), dolgu: true);
    final tp = TextPainter(
      text: TextSpan(text: '+2', style: TextStyle(color: c, fontSize: 17, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    cv.save();
    cv.translate(39, 30);
    cv.rotate(10 * math.pi / 180);
    tp.paint(cv, Offset(-tp.width / 2, 8 - tp.height / 2));
    cv.restore();
  }

  @override
  bool shouldRepaint(covariant _IkiKartPainter o) => o.c != c;
}

class _DiskPainter extends CustomPainter {
  _DiskPainter(this.a, this.b);
  final Color? a, b;
  @override
  void paint(Canvas cv, Size s) {
    final r = Offset.zero & s;
    if (a == null || b == null) {
      cv.drawRect(r, Paint()..shader = const SweepGradient(colors: [..._gok, Color(0xFFD9342B)], transform: GradientRotation(-math.pi / 2)).createShader(r));
      return;
    }
    cv.drawRect(r, Paint()..color = a!);
    cv.save();
    cv.translate(s.width / 2, s.height / 2);
    cv.rotate(25 * math.pi / 180);
    cv.drawRect(Rect.fromLTWH(0, -s.height, s.width, s.height * 2), Paint()..color = b!);
    cv.restore();
  }

  @override
  bool shouldRepaint(covariant _DiskPainter o) => o.a != a || o.b != b;
}

/// Arka yüz (rakibin eli / deste).
/// Seçili kart arkası (dükkândan); oyun ekranı Hesap'tan okuyup atar.
String kartArkasiStili = 'klasik';

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.w = 40, this.stil});
  final double w;
  final String? stil;

  // zemin, madalyon, madalyon yazısı
  static const _stiller = {
    'klasik': (Color(0xFF0F5A3A), Color(0xFFE8C35A), Color(0xFF3A2A05)),
    'kart_altin': (Color(0xFF9A6E14), Color(0xFF3A2A05), Color(0xFFE8C35A)),
    'kart_gece': (Color(0xFF16275A), Color(0xFFE8C35A), Color(0xFF3A2A05)),
    'kart_mermer': (Color(0xFF9A9088), Color(0xFFFBF6E9), Color(0xFF3A3A44)),
  };

  static Color zeminRengi(String? stil) => (_stiller[stil] ?? _stiller['klasik']!).$1;

  @override
  Widget build(BuildContext context) {
    final (zemin, madalyon, yazi) = _stiller[stil ?? kartArkasiStili] ?? _stiller['klasik']!;
    return Container(
      width: w,
      height: w * 1.45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.078),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
      ),
      foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(w * 0.078), border: Border.all(color: Colors.black26)),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 180,
          height: 260,
          child: Container(
            decoration: BoxDecoration(color: zemin, border: Border.all(color: _krem, width: 6)),
            child: CustomPaint(
              painter: _DamaPainter(),
              child: Center(
                child: Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: madalyon,
                    border: Border.all(color: _krem, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0xFF8A6A14), spreadRadius: 3), BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: _x('EMLAK\nDEAL', 20, color: yazi, fw: FontWeight.w900, ls: 1, h: 1.05, al: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DamaPainter extends CustomPainter {
  @override
  void paint(Canvas cv, Size s) {
    final p = Paint()..color = const Color(0x14FFFFFF);
    const k = 14.0;
    for (var i = 0; i * k < s.height; i++) {
      for (var j = 0; j * k < s.width; j++) {
        if ((i + j).isEven) cv.drawRect(Rect.fromLTWH(j * k, i * k, k, k), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Seçili kart arkası stilinin zemin rengi (deste kalınlık şeritleri için).
Color kartArkasiZemin() => CardBack.zeminRengi(kartArkasiStili);
