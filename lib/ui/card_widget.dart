import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../model/cards.dart';

/// Tek kart görseli — fiziksel kart oyunlarına yakın dil:
/// renkli başlık bandı, sol üstte değer rozeti, ortada büyük simge, altta kısa açıklama.
/// [w] genişlik; yükseklik 1.45×.
class CardView extends StatelessWidget {
  const CardView(this.card, {super.key, this.w = 72, this.selected = false, this.onTap, this.dim = false});
  final GameCard card;
  final double w;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  static const _krem = Color(0xFFFBF6E9);

  @override
  Widget build(BuildContext context) {
    final h = w * 1.45;
    final body = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: _krem,
        borderRadius: BorderRadius.circular(w * 0.09),
        border: Border.all(color: selected ? Colors.amber : Colors.black38, width: selected ? 3 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (card.isMoney)
          Positioned.fill(child: CustomPaint(painter: _CercevePainter(card.value, merkez: true)))
        else if (card.isAction || card.isRent) ...[
          Positioned.fill(child: CustomPaint(painter: _CercevePainter(card.paraDegeri, merkez: false, zeminAcik: true))),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(w * 0.14, w * 0.17, w * 0.14, w * 0.17),
              child: card.isAction ? _aksiyon() : _kira(),
            ),
          ),
        ] else ...[
          Positioned.fill(child: CustomPaint(painter: _tapuCercevesi())),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(w * 0.13, w * 0.12, w * 0.13, w * 0.12),
              child: _icerik(),
            ),
          ),
        ],
      ]),
    );
    return GestureDetector(onTap: onTap, child: Opacity(opacity: dim ? 0.45 : 1, child: body));
  }

  double get _fs => w / 7.5;

  _CercevePainter _tapuCercevesi() {
    const siyah = Color(0xFF6B6B6B);
    if (card.isMultiWild) {
      return _CercevePainter(0, merkez: false, zemin: const Color(0xFFFBF6E9), cerceve: siyah, koseUst: const Color(0xFF1F3F9E), koseAlt: const Color(0xFF1F3F9E));
    }
    if (card.isWild) {
      final a = card.colors[0], b = card.colors[1];
      final ust = card.wildColor == b ? b : a, alt = ust == a ? b : a;
      return _CercevePainter(card.paraDegeri, merkez: false, zemin: const Color(0xFFFBF6E9), cerceve: siyah, koseUst: ust.renk, koseAlt: alt.renk);
    }
    final r = card.color!.renk;
    return _CercevePainter(card.paraDegeri, merkez: false, zemin: const Color(0xFFFBF6E9), cerceve: siyah, koseUst: r, koseAlt: r);
  }

  Widget _icerik() {
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

  // ------------------------------------------------------------ para
  Widget _para() => const SizedBox();

  // ------------------------------------------------------------ tapu
  /// Renkli başlık bandı (sokak adı / JOKER TAPU).
  Widget _bant(Color c, String ad, {String? alt, bool ters = false, double yuk = 0.26}) {
    final icerik = Container(
      width: double.infinity,
      height: w * yuk,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(w * 0.03)),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: w * 0.03),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ad.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: _fs * 0.82, fontWeight: FontWeight.w900, color: _koyu(c) ? Colors.white : Colors.black87, height: 1.05, letterSpacing: 0.3)),
          if (alt != null) Text(alt, style: TextStyle(fontSize: _fs * 0.5, color: _koyu(c) ? Colors.white : Colors.black87, height: 1.1)),
        ]),
      ),
    );
    return ters ? Transform.rotate(angle: pi, child: icerik) : icerik;
  }

  /// Küçük tapu destesi simgesi: n kart üst üste, önde sayı.
  Widget _desteSimge(Color c, int n, double b) {
    return SizedBox(
      width: b * 1.5,
      height: b * 1.25,
      child: Stack(children: [
        for (var i = n - 1; i >= 0; i--)
          Positioned(
            left: (n - 1 - i) * b * 0.16,
            top: i * b * 0.08,
            child: Container(
              width: b,
              height: b * 1.15,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(b * 0.14),
                border: Border.all(color: Colors.white, width: b * 0.06),
              ),
              alignment: Alignment.bottomCenter,
              child: i == 0
                  ? Container(
                      width: b * 0.72,
                      height: b * 0.5,
                      margin: EdgeInsets.only(bottom: b * 0.08),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(b * 0.08)),
                      alignment: Alignment.center,
                      child: Text('$n', style: TextStyle(fontSize: b * 0.42, fontWeight: FontWeight.w900, color: Colors.black87, height: 1)),
                    )
                  : null,
            ),
          ),
      ]),
    );
  }

  /// Kira tablosu: sahip olunan tapu sayısı → kira.
  Widget _kiraTablosu(PColor c, {bool kompakt = false}) {
    final b = w * (kompakt ? 0.11 : 0.13);
    final satirlar = <Widget>[];
    for (var i = 0; i < c.kira.length; i++) {
      satirlar.add(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
        _desteSimge(c.renk, i + 1, b),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.02),
            child: CustomPaint(painter: _NoktaCizgi(), child: const SizedBox(height: 1)),
          ),
        ),
        Text('M${c.kira[i]}', style: TextStyle(fontSize: _fs * 0.8, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.black87, height: 1)),
      ]));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!kompakt)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('SAHİP OLUNAN\nTAPU SENEDİ\nSAYISI', style: TextStyle(fontSize: _fs * 0.42, fontWeight: FontWeight.w800, color: Colors.black87, height: 1.05)),
          Text('KİRA', style: TextStyle(fontSize: _fs * 0.42, fontWeight: FontWeight.w800, color: Colors.black87)),
        ]),
      SizedBox(height: w * 0.02),
      ...satirlar.expand((r) => [r, SizedBox(height: w * 0.02)]),
      Text('TAM SET', style: TextStyle(fontSize: _fs * 0.42, fontWeight: FontWeight.w800, color: Colors.black87)),
    ]);
  }

  Widget _tapu(PColor c) {
    return Column(children: [
      _bant(c.renk, card.sokak ?? c.ad, yuk: 0.3),
      Padding(
        padding: EdgeInsets.only(top: w * 0.015),
        child: Text(c.sehir.toUpperCase(), style: TextStyle(fontSize: _fs * 0.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black54)),
      ),
      SizedBox(height: w * 0.015),
      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter, child: SizedBox(width: w * 0.74, child: _kiraTablosu(c)))),
    ]);
  }

  /// İkili joker: seçili renk üstte; tablolar yan yana, alttaki yarı 180° ters (orijinal kart).
  Widget _ikiliJoker() {
    final a = card.colors[0], b = card.colors[1];
    final ust = card.wildColor == b ? b : a;
    final alt = ust == a ? b : a;
    final secili = card.wildColor != null;
    return Column(children: [
      _bant(ust.renk, 'Joker Tapu\nSenedi Kartı', alt: 'Renklerden birini seç', yuk: 0.3),
      SizedBox(height: w * 0.02),
      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.center, child: SizedBox(width: w * 0.7, child: _kiraTablosu(ust, kompakt: true)))),
      SizedBox(height: w * 0.02),
      Opacity(opacity: secili ? 0.55 : 1, child: _bant(alt.renk, 'Joker Tapu\nSenedi Kartı', alt: 'Renklerden birini seç', ters: true, yuk: 0.3)),
    ]);
  }

  Widget _cokJoker() {
    const gok = LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple]);
    return Column(children: [
      Container(
        width: double.infinity,
        height: w * 0.3,
        decoration: BoxDecoration(gradient: gok, borderRadius: BorderRadius.circular(w * 0.03)),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('JOKER TAPU\nSENEDİ KARTI', textAlign: TextAlign.center, style: TextStyle(fontSize: _fs * 0.8, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05, shadows: const [Shadow(blurRadius: 3, color: Colors.black54)])),
        ),
      ),
      Expanded(
        child: Center(
          child: card.wildColor == null
              ? Text('Bu kart herhangi bir renk\ngrubunda tapu olarak\nkullanılabilir.', textAlign: TextAlign.center, style: TextStyle(fontSize: _fs * 0.6, height: 1.15, color: Colors.black87))
              : Container(
                  margin: EdgeInsets.all(w * 0.04),
                  padding: EdgeInsets.all(w * 0.04),
                  decoration: BoxDecoration(color: card.wildColor!.renk, borderRadius: BorderRadius.circular(6)),
                  child: Text('▲ ${card.wildColor!.ad}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: _fs * 0.78, fontWeight: FontWeight.w800, color: _koyu(card.wildColor!.renk) ? Colors.white : Colors.black87)),
                ),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ aksiyon
  static const _aksiyonTema = {
    ActionType.dealBreaker: (Color(0xFFB71C1C), Icons.gavel),
    ActionType.justSayNo: (Color(0xFF1565C0), Icons.block),
    ActionType.slyDeal: (Color(0xFF00796B), Icons.back_hand),
    ActionType.forcedDeal: (Color(0xFFEF6C00), Icons.swap_horiz),
    ActionType.tahsilat: (Color(0xFF6A1B9A), Icons.request_quote),
    ActionType.birthday: (Color(0xFFD81B60), Icons.cake),
    ActionType.passGo: (Color(0xFF2E7D32), Icons.double_arrow),
    ActionType.house: (Color(0xFF6D4C41), Icons.home),
    ActionType.hotel: (Color(0xFF283593), Icons.apartment),
    ActionType.doubleRent: (Color(0xFFF9A825), Icons.close),
  };

  Widget _aksiyon() {
    final a = card.action!;
    final (renk, ikon) = _aksiyonTema[a]!;
    final cerceve = paraRengi(card.paraDegeri);
    final koyu = Color.lerp(cerceve, Colors.black, 0.35)!;
    return Column(children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text('HAMLE KARTI', maxLines: 1, style: TextStyle(fontSize: _fs * 0.74, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: koyu))),
      Expanded(
        child: Center(
          child: Container(
            width: w * 0.36,
            height: w * 0.36,
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: renk, width: 1.5)),
            child: a == ActionType.doubleRent
                ? Center(child: Text('×2', style: TextStyle(fontSize: w * 0.17, fontWeight: FontWeight.w900, color: renk)))
                : Icon(ikon, color: renk, size: w * 0.23),
          ),
        ),
      ),
      Text(a.ad.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(fontSize: _fs * 0.8, fontWeight: FontWeight.w900, color: koyu, height: 1.05, letterSpacing: 0.3)),
      Padding(
        padding: EdgeInsets.only(top: w * 0.015),
        child: Text(a.aciklama,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _fs * 0.56, height: 1.1, color: Colors.black87)),
      ),
    ]);
  }

  // ------------------------------------------------------------ kira
  Widget _kira() {
    final joker = card.isWildRent;
    final a = joker ? null : card.rentColors[0];
    final b = joker ? null : card.rentColors[1];
    final koyu = Color.lerp(paraRengi(card.paraDegeri), Colors.black, 0.35)!;
    final bayrak = SizedBox(
      width: w * 0.42,
      height: w * 0.30,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: joker
            ? const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple])))
            : Column(children: [Expanded(child: Container(color: a!.renk)), Expanded(child: Container(color: b!.renk))]),
      ),
    );
    return Column(children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text('HAMLE KARTI', maxLines: 1, style: TextStyle(fontSize: _fs * 0.74, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: koyu))),
      Expanded(child: Center(child: bayrak)),
      Text('KİRA', style: TextStyle(fontSize: _fs * 0.8, fontWeight: FontWeight.w900, color: koyu, height: 1.05, letterSpacing: 0.3)),
      Padding(
        padding: EdgeInsets.only(top: w * 0.015),
        child: Text(joker ? 'Herhangi bir rengin kirasını herkesten al.' : '${a!.kisaAd} veya ${b!.kisaAd} kirasını herkesten al.',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _fs * 0.56, height: 1.1, color: Colors.black87)),
      ),
    ]);
  }

  bool _koyu(Color c) => c.computeLuminance() < 0.45;
}


/// Para kartı: açık zemin, renkli süslü çift çerçeve, köşelerde baklava (alttakiler ters),
/// ortada degrade büyük baklava içinde değer. (Orijinal kart düzeni, karakter yok.)
class _CercevePainter extends CustomPainter {
  _CercevePainter(this.deger, {this.merkez = true, this.zeminAcik = false, this.zemin, this.cerceve, this.koseUst, this.koseAlt});
  final int deger;
  final bool merkez;
  final bool zeminAcik;
  final Color? zemin, cerceve, koseUst, koseAlt;

  @override
  void paint(Canvas c, Size sz) {
    final w = sz.width, h = sz.height;
    final renk = paraRengi(deger);
    final koyu = Color.lerp(renk, Colors.black, 0.35)!;
    final acik = Color.lerp(renk, Colors.white, 0.25)!;
    final zeminR = zemin ?? Color.lerp(renk, Colors.white, zeminAcik ? 0.93 : 0.80)!;
    final cer = cerceve ?? renk;
    final rr = RRect.fromRectAndRadius(Offset.zero & sz, Radius.circular(w * 0.09));
    c.drawRRect(rr, Paint()..color = zeminR);
    // dış ve iç çerçeve
    final d1 = w * 0.07, d2 = w * 0.115;
    final r1 = Rect.fromLTWH(d1, d1, w - 2 * d1, h - 2 * d1);
    final r2 = Rect.fromLTWH(d2, d2, w - 2 * d2, h - 2 * d2);
    c.drawRect(r1, Paint()..color = cer..style = PaintingStyle.stroke..strokeWidth = w * 0.022);
    c.drawRect(r2, Paint()..color = cer..style = PaintingStyle.stroke..strokeWidth = w * 0.010);
    // iki çerçeve arasında zincir deseni (küçük halkalar)
    final halka = Paint()..color = cer..style = PaintingStyle.stroke..strokeWidth = w * 0.008;
    final orta = (d1 + d2) / 2, adim = w * 0.045, rad = w * 0.013;
    for (var x = d2 + adim; x < w - d2; x += adim) {
      c.drawCircle(Offset(x, orta), rad, halka);
      c.drawCircle(Offset(x, h - orta), rad, halka);
    }
    for (var y = d2 + adim; y < h - d2; y += adim) {
      c.drawCircle(Offset(orta, y), rad, halka);
      c.drawCircle(Offset(w - orta, y), rad, halka);
    }
    // köşe baklavaları (çerçeve kesişimine oturur)
    final ks = w * 0.15;
    final etiket = deger == 0 ? 'M' : 'M$deger';
    for (final (cx, cy, ters) in [(d1, d1, false), (w - d1, d1, false), (d1, h - d1, true), (w - d1, h - d1, true)]) {
      final kr = ters ? (koseAlt ?? koseUst ?? koyu) : (koseUst ?? koyu);
      _baklava(c, Offset(cx, cy), ks, kr, kr, etiket, w * 0.075, ters);
    }
    // merkez baklava (para)
    if (merkez) _baklava(c, Offset(w / 2, h / 2), w * 0.44, acik, koyu, 'M$deger', w * 0.19, false, degrade: true);
  }

  void _baklava(Canvas c, Offset m, double s, Color a, Color b, String yazi, double fs, bool ters, {bool degrade = false}) {
    final yol = Path()
      ..moveTo(m.dx, m.dy - s / 2)
      ..lineTo(m.dx + s / 2, m.dy)
      ..lineTo(m.dx, m.dy + s / 2)
      ..lineTo(m.dx - s / 2, m.dy)
      ..close();
    c.drawPath(yol, Paint()..color = degrade ? a : b);
    c.drawPath(yol, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = s * 0.05);
    if (degrade) {
      // iç baklava koyu: açık dış kenar + koyu iç = orijinaldeki degrade hissi
      final ic = Path()
        ..moveTo(m.dx, m.dy - s * 0.42)
        ..lineTo(m.dx + s * 0.42, m.dy)
        ..lineTo(m.dx, m.dy + s * 0.42)
        ..lineTo(m.dx - s * 0.42, m.dy)
        ..close();
      c.drawPath(ic, Paint()..color = b);
      c.drawPath(ic, Paint()..color = Colors.white.withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = s * 0.02);
    }
    final tp = TextPainter(
      text: TextSpan(text: yazi, style: TextStyle(fontFamily: 'Roboto', fontSize: fs, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(m.dx, m.dy);
    if (ters) c.rotate(pi);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _CercevePainter old) => old.deger != deger || old.merkez != merkez || old.zeminAcik != zeminAcik || old.koseUst != koseUst || old.koseAlt != koseAlt || old.cerceve != cerceve;
}

class _NoktaCizgi extends CustomPainter {
  @override
  void paint(Canvas c, Size sz) {
    final p = Paint()..color = Colors.black45..strokeWidth = 1;
    for (var x = 0.0; x < sz.width; x += 4) {
      c.drawLine(Offset(x, sz.height / 2), Offset(x + 2, sz.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Arka yüz (rakibin eli / deste).
/// Seçili kart arkası (dükkândan); oyun ekranı Hesap'tan okuyup atar.
String kartArkasiStili = 'klasik';

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.w = 40, this.stil});
  final double w;
  final String? stil;
  static const _stiller = {
    'klasik': [Color(0xFFB3202D), Color(0xFF7A1019)],
    'kart_altin': [Color(0xFFE0B13A), Color(0xFF8A6210)],
    'kart_gece': [Color(0xFF26407A), Color(0xFF0F1A3A)],
    'kart_mermer': [Color(0xFFEDE6DA), Color(0xFF9A9088)],
  };
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: w * 1.45,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _stiller[stil ?? kartArkasiStili] ?? _stiller['klasik']!, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(w * 0.09),
          border: Border.all(color: Colors.black26),
        ),
        alignment: Alignment.center,
        child: Container(
          width: w * 0.7,
          height: w * 0.7 * 1.45,
          decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(w * 0.06)),
          alignment: Alignment.center,
          child: Text('ED', style: TextStyle(color: (stil ?? kartArkasiStili) == 'kart_mermer' ? Colors.black45 : Colors.white70, fontWeight: FontWeight.w900, fontSize: w / 3.5)),
        ),
      );
}
