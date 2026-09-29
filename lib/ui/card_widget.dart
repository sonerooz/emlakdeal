import 'package:flutter/material.dart';
import '../model/cards.dart';

/// Tek kart görseli — orijinal Monopoly Deal kartlarına yakın dil:
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
        Positioned.fill(child: _icerik()),
        if (!card.isMoney) Positioned(left: w * 0.05, top: w * 0.05, child: _rozet()),
      ]),
    );
    return GestureDetector(onTap: onTap, child: Opacity(opacity: dim ? 0.45 : 1, child: body));
  }

  double get _fs => w / 7.5;

  /// Sol üst değer rozeti (orijinaldeki para dairesi).
  Widget _rozet() => Container(
        width: w * 0.30,
        height: w * 0.30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text('${card.paraDegeri}M',
            style: TextStyle(fontSize: _fs * 0.72, fontWeight: FontWeight.w900, color: Colors.black87)),
      );

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
  static const _paraRenk = {
    1: Color(0xFFF6D35B),
    2: Color(0xFFF4B183),
    3: Color(0xFF9CD6C3),
    4: Color(0xFF7FB2E5),
    5: Color(0xFFB79BDA),
    10: Color(0xFFE0B53B),
  };

  Widget _para() {
    final c = _paraRenk[card.value] ?? const Color(0xFFDDDDDD);
    return Container(
      color: c,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: w * 0.62,
          height: w * 0.62,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black87, width: 1.5)),
          alignment: Alignment.center,
          child: Text('${card.value}M',
              style: TextStyle(fontSize: w / 3.2, fontWeight: FontWeight.w900, color: Colors.black87, height: 1)),
        ),
        SizedBox(height: w * 0.08),
        Text('PARA', style: TextStyle(fontSize: _fs * 0.8, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.5)),
      ]),
    );
  }

  // ------------------------------------------------------------ tapu
  Widget _bant(Color c, String ad, {double? hh, double olcek = 1}) => Container(
        height: hh,
        color: c,
        alignment: Alignment.center,
        padding: EdgeInsets.fromLTRB(w * 0.34, 2, 3, 2),
        child: Text(ad,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                fontSize: _fs * 0.85 * olcek,
                fontWeight: FontWeight.w800,
                color: _koyu(c) ? Colors.white : Colors.black87,
                height: 1.05)),
      );

  /// Kart türü şeridi ("TAPU" / "HAMLE KARTI").
  Widget _etiket(String s) => Container(
        width: double.infinity,
        color: Colors.black12,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(s, textAlign: TextAlign.center, style: TextStyle(fontSize: _fs * 0.62, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black87)),
      );

  Widget _tapuEtiketi() => _etiket('TAPU');

  Widget _tapu(PColor c) {
    return Column(children: [
      _bant(c.renk, c.ad, hh: w * 0.40),
      _tapuEtiketi(),
      Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.06),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < c.kira.length; i++)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${i + 1} tapu', style: TextStyle(fontSize: _fs * 0.68, color: Colors.black54)),
                Text('${c.kira[i]}M', style: TextStyle(fontSize: _fs * 0.72, fontWeight: FontWeight.w800)),
              ]),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text('${c.setBoyu}\'lü set', style: TextStyle(fontSize: _fs * 0.62, color: Colors.black45)),
      ),
    ]);
  }

  /// İkili joker: hangi renk seçildiyse o yarı ÜSTTE (masaya o taraf yukarı konmuş gibi).
  Widget _ikiliJoker() {
    final a = card.colors[0], b = card.colors[1];
    final ust = card.wildColor == b ? b : a;
    final alt = ust == a ? b : a;
    final secili = card.wildColor != null;
    Widget yari(PColor k, bool aktif) => Expanded(
          child: Container(
            color: aktif ? k.renk : k.renk.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Text(k.ad,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: _fs * 0.85,
                    fontWeight: FontWeight.w800,
                    color: _koyu(k.renk) ? Colors.white : Colors.black87)),
          ),
        );
    return Column(children: [
      yari(ust, true),
      Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (secili) Icon(Icons.arrow_drop_up, color: ust.renk, size: _fs * 1.3),
          Text('JOKER TAPU', style: TextStyle(fontSize: _fs * 0.62, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
        ]),
      ),
      yari(alt, !secili),
    ]);
  }

  Widget _cokJoker() {
    const gok = LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple]);
    return Column(children: [
      Container(
        height: w * 0.40,
        decoration: const BoxDecoration(gradient: gok),
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: w * 0.3),
        child: Text('JOKER', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w900, color: Colors.white, shadows: const [Shadow(blurRadius: 3, color: Colors.black54)])),
      ),
      _tapuEtiketi(),
      Expanded(
        child: Center(
          child: card.wildColor == null
              ? Text('Her renk\nolabilir', textAlign: TextAlign.center, style: TextStyle(fontSize: _fs * 0.78))
              : Container(
                  margin: EdgeInsets.all(w * 0.06),
                  padding: const EdgeInsets.all(4),
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
    ActionType.debtCollector: (Color(0xFF6A1B9A), Icons.request_quote),
    ActionType.birthday: (Color(0xFFD81B60), Icons.cake),
    ActionType.passGo: (Color(0xFF2E7D32), Icons.double_arrow),
    ActionType.house: (Color(0xFF6D4C41), Icons.home),
    ActionType.hotel: (Color(0xFF283593), Icons.apartment),
    ActionType.doubleRent: (Color(0xFFF9A825), Icons.close),
  };

  Widget _aksiyon() {
    final a = card.action!;
    final (renk, ikon) = _aksiyonTema[a]!;
    return Column(children: [
      Container(
        height: w * 0.40,
        color: renk,
        alignment: Alignment.center,
        padding: EdgeInsets.fromLTRB(w * 0.34, 2, 3, 2),
        child: Text(a.ad,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: _fs * 0.85, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05)),
      ),
      _etiket('HAMLE KARTI'),
      Expanded(
        child: Center(
          child: Container(
            width: w * 0.46,
            height: w * 0.46,
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: renk, width: 1.5)),
            child: a == ActionType.doubleRent
                ? Center(child: Text('×2', style: TextStyle(fontSize: w * 0.2, fontWeight: FontWeight.w900, color: renk)))
                : Icon(ikon, color: renk, size: w * 0.3),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(w * 0.05, 0, w * 0.05, w * 0.05),
        child: Text(a.aciklama,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _fs * 0.62, height: 1.1, color: Colors.black87)),
      ),
    ]);
  }

  // ------------------------------------------------------------ kira
  Widget _kira() {
    final joker = card.isWildRent;
    final a = joker ? null : card.rentColors[0];
    final b = joker ? null : card.rentColors[1];
    return Stack(children: [
      Positioned.fill(
        child: joker
            ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple], begin: Alignment.topCenter, end: Alignment.bottomCenter)))
            : Column(children: [
                Expanded(child: Container(color: a!.renk)),
                Expanded(child: Container(color: b!.renk)),
              ]),
      ),
      Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black87)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('KİRA', style: TextStyle(fontSize: _fs * 1.1, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black87)),
            Text(joker ? 'her renk' : '${a!.ad}\n${b!.ad}',
                textAlign: TextAlign.center, style: TextStyle(fontSize: _fs * 0.62, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.05)),
          ]),
        ),
      ),
      Positioned(left: 0, right: 0, bottom: 0, child: _etiket('HAMLE KARTI')),
    ]);
  }

  bool _koyu(Color c) => c.computeLuminance() < 0.45;
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
        child: Container(
          width: w * 0.7,
          height: w * 0.7 * 1.45,
          decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(w * 0.06)),
          alignment: Alignment.center,
          child: Text('MD', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: w / 3.5)),
        ),
      );
}
