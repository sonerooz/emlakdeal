import 'package:flutter/material.dart';
import '../model/cards.dart';

/// Tek kart görseli. [w] genişlik; yükseklik 1.45×.
class CardView extends StatelessWidget {
  const CardView(this.card, {super.key, this.w = 72, this.selected = false, this.onTap, this.dim = false});
  final GameCard card;
  final double w;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final h = w * 1.45;
    final body = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: _arkaPlan,
        borderRadius: BorderRadius.circular(w * 0.09),
        border: Border.all(color: selected ? Colors.amber : Colors.black26, width: selected ? 3 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: _icerik(),
    );
    return GestureDetector(
      onTap: onTap,
      child: Opacity(opacity: dim ? 0.45 : 1, child: body),
    );
  }

  Color get _arkaPlan {
    switch (card.kind) {
      case CardKind.money:
        return const Color(0xFFDFF3E3);
      case CardKind.property:
      case CardKind.wild:
        return const Color(0xFFFFFDF5);
      case CardKind.action:
        return const Color(0xFFFFF1D6);
      case CardKind.rent:
        return const Color(0xFFEFE7FF);
    }
  }

  Widget _icerik() {
    final fs = w / 7.5;
    switch (card.kind) {
      case CardKind.money:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${card.value}M',
                style: TextStyle(fontSize: w / 2.6, fontWeight: FontWeight.w900, color: const Color(0xFF1E7B3A))),
            Text('PARA', style: TextStyle(fontSize: fs * 0.8, color: Colors.black45, letterSpacing: 1)),
          ],
        );
      case CardKind.property:
        final c = card.color!;
        return Column(children: [
          _bant(c.renk, c.ad, fs),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(w * 0.06),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Kira', style: TextStyle(fontSize: fs * 0.75, color: Colors.black45)),
                Text(c.kira.join(' · '),
                    style: TextStyle(fontSize: fs * 0.9, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                Text('${c.setBoyu} set', style: TextStyle(fontSize: fs * 0.7, color: Colors.black45)),
              ]),
            ),
          ),
          _deger(fs),
        ]);
      case CardKind.wild:
        if (card.isMultiWild) {
          return Column(children: [
            Container(
              height: w * 0.38,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple])),
              alignment: Alignment.center,
              child: Text('JOKER', style: TextStyle(fontSize: fs, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            Expanded(child: Center(child: Text('Her renk', style: TextStyle(fontSize: fs * 0.85)))),
            if (card.wildColor != null) _bant(card.wildColor!.renk, card.wildColor!.ad, fs * 0.85),
          ]);
        }
        final a = card.colors[0], b = card.colors[1];
        return Column(children: [
          Expanded(child: _bant(a.renk, a.ad, fs, fill: true)),
          Container(height: 2, color: Colors.black26),
          Expanded(child: _bant(b.renk, b.ad, fs, fill: true)),
          if (card.wildColor != null)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('→ ${card.wildColor!.ad}',
                  style: TextStyle(fontSize: fs * 0.8, color: Colors.white), textAlign: TextAlign.center),
            ),
        ]);
      case CardKind.action:
        return Column(children: [
          Container(
            height: w * 0.36,
            color: const Color(0xFFE8A33C),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(card.action!.ad,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: fs * 0.95, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(w * 0.05),
              child: Center(
                child: Text(card.action!.aciklama,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fs * 0.68, height: 1.1)),
              ),
            ),
          ),
          _deger(fs),
        ]);
      case CardKind.rent:
        if (card.isWildRent) {
          return Column(children: [
            Container(
              height: w * 0.36,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple])),
              alignment: Alignment.center,
              child: Text('KİRA', style: TextStyle(fontSize: fs, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            Expanded(child: Center(child: Text('Her renk', style: TextStyle(fontSize: fs * 0.85)))),
            _deger(fs),
          ]);
        }
        final a = card.rentColors[0], b = card.rentColors[1];
        return Column(children: [
          Row(children: [
            Expanded(child: Container(height: w * 0.36, color: a.renk)),
            Expanded(child: Container(height: w * 0.36, color: b.renk)),
          ]),
          Expanded(
            child: Center(
              child: Text('KİRA\n${a.ad}\n${b.ad}',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 0.8, fontWeight: FontWeight.w700)),
            ),
          ),
          _deger(fs),
        ]);
    }
  }

  Widget _bant(Color c, String ad, double fs, {bool fill = false}) => Container(
        height: fill ? null : w * 0.38,
        color: c,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(ad,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                fontSize: fs * 0.9,
                fontWeight: FontWeight.w800,
                color: _koyu(c) ? Colors.white : Colors.black87,
                height: 1.05)),
      );

  bool _koyu(Color c) => c.computeLuminance() < 0.45;

  Widget _deger(double fs) => Container(
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text('${card.paraDegeri}M',
            textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 0.85, fontWeight: FontWeight.w700)),
      );
}

/// Arka yüz (rakibin eli / deste).
class CardBack extends StatelessWidget {
  const CardBack({super.key, this.w = 40});
  final double w;
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: w * 1.45,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB3202D), Color(0xFF7A1019)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(w * 0.09),
          border: Border.all(color: Colors.black26),
        ),
        alignment: Alignment.center,
        child: Text('MD', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: w / 3)),
      );
}
