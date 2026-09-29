import 'package:flutter/material.dart';
import '../model/cards.dart';
import '../model/game.dart';
import 'card_widget.dart';

/// Kart seçme diyaloğu sonucu: [kartlar] ya da [altBasildi] (ör. Reddet).
class PickSonuc {
  PickSonuc(this.kartlar, {this.altBasildi = false, this.iptal = false});
  final List<GameCard> kartlar;
  final bool altBasildi;
  final bool iptal;
}

/// Kart seçme diyaloğu. [needTotal] verilirse seçilenlerin değeri en az o olmalı;
/// [exact] verilirse tam o kadar kart seçilmeli. [altButon] verilirse en altta ayrı bir
/// seçenek (ör. "Reddet") çıkar. Kapatılamaz (karar şart) — [iptalOlur] hariç.
Future<PickSonuc> pickCardsEx(
  BuildContext context, {
  required String title,
  required List<GameCard> cards,
  int? needTotal,
  int? exact,
  int max = 99,
  String onay = 'Tamam',
  bool iptalOlur = false,
  Map<String, List<GameCard>>? gruplar,
  String? altButon,
  String? altAciklama,
}) async {
  final secili = <GameCard>{};
  final bolumler = gruplar ?? {'': cards};
  final r = await showDialog<PickSonuc>(
    context: context,
    barrierDismissible: iptalOlur,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final toplam = secili.fold(0, (s, c) => s + c.paraDegeri);
      final ok = (needTotal == null || toplam >= needTotal) && (exact == null || secili.length == exact);
      return AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (altAciklama != null)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(altAciklama, style: const TextStyle(fontSize: 13, color: Colors.black54))),
            if (needTotal != null)
              Text('Gereken: ${needTotal}M · Seçilen: ${toplam}M',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ok ? Colors.green : Colors.red)),
            if (exact != null)
              Text('$exact kart seç · Seçilen: ${secili.length}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ok ? Colors.green : Colors.red)),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final b in bolumler.entries) ...[
                    if (b.key.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text('${b.key} (${b.value.length} kart · ${b.value.fold(0, (s, c) => s + c.paraDegeri)}M)',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    if (b.value.isEmpty)
                      const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('— yok —', style: TextStyle(color: Colors.black45))),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in b.value)
                          CardView(c,
                              w: 64,
                              selected: secili.contains(c),
                              onTap: () => setS(() {
                                    if (secili.contains(c)) {
                                      secili.remove(c);
                                    } else if (secili.length < max) {
                                      secili.add(c);
                                    }
                                  })),
                      ],
                    ),
                  ],
                ]),
              ),
            ),
            if (altButon != null) ...[
              const Divider(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade700)),
                  onPressed: () => Navigator.pop(ctx, PickSonuc(const [], altBasildi: true)),
                  icon: const Icon(Icons.block),
                  label: Text(altButon),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ]),
        ),
        actions: [
          if (iptalOlur) TextButton(onPressed: () => Navigator.pop(ctx, PickSonuc(const [], iptal: true)), child: const Text('Vazgeç')),
          FilledButton(onPressed: ok ? () => Navigator.pop(ctx, PickSonuc(secili.toList())) : null, child: Text(onay)),
        ],
      );
    }),
  );
  return r ?? PickSonuc(const [], iptal: true);
}

/// Sadece kartları döndüren kısa yol (iptal/alt buton → boş liste).
Future<List<GameCard>> pickCards(
  BuildContext context, {
  required String title,
  required List<GameCard> cards,
  int? needTotal,
  int? exact,
  int max = 99,
  String onay = 'Tamam',
  bool iptalOlur = false,
  Map<String, List<GameCard>>? gruplar,
}) async =>
    (await pickCardsEx(context,
            title: title, cards: cards, needTotal: needTotal, exact: exact, max: max, onay: onay, iptalOlur: iptalOlur, gruplar: gruplar))
        .kartlar;

Future<PColor?> pickColor(BuildContext context, String title, List<PColor> secenekler,
    {bool iptalOlur = false, String Function(PColor)? altYazi}) {
  return showDialog<PColor>(
    context: context,
    barrierDismissible: iptalOlur,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: SizedBox(
        width: double.maxFinite,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in secenekler)
            ActionChip(
              avatar: CircleAvatar(backgroundColor: c.renk, radius: 9),
              label: Text(altYazi == null ? c.ad : '${c.ad} ${altYazi(c)}'),
              onPressed: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
      actions: [if (iptalOlur) TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Vazgeç'))],
    ),
  );
}

Future<bool> confirmDlg(BuildContext context, String title, String mesaj,
    {String evet = 'Evet', String hayir = 'Hayır'}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(mesaj),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hayir)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(evet)),
      ],
    ),
  );
  return r ?? false;
}

/// İnsan oyuncu: kararlar ekrandaki diyaloglarla alınır.
class HumanDecider implements Decider {
  HumanDecider(this.ctx);
  final BuildContext Function() ctx;

  @override
  Future<bool> justSayNo(Game g, Player me, String aciklama) =>
      confirmDlg(ctx(), '🛑 Reddet?', 'Rakip sana şunu oynadı: $aciklama\n\nElindeki Reddet kartıyla iptal etmek ister misin?',
          evet: 'Reddet!', hayir: 'Kabul et');

  Map<String, List<GameCard>> _gruplar(Player me) => {
        '💵 Para': me.bank,
        '🏠 Tapular': [for (final l in me.props.values) ...l, for (final l in me.binalar.values) ...l],
      };

  @override
  Future<List<GameCard>> ode(Game g, Player me, int tutar, Player alacakli) => pickCards(ctx(),
      title: '💸 ${alacakli.name}\'a ${tutar}M öde',
      cards: me.varliklar,
      needTotal: tutar.clamp(0, me.varlikToplam),
      onay: 'Öde',
      gruplar: _gruplar(me));

  /// Para talebi tek modalda: kartları seç → Öde, ya da en alttaki Reddet.
  @override
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama,
      {required bool reddedebilir}) async {
    final r = await pickCardsEx(ctx(),
        title: '💸 ${alacakli.name}: $aciklama',
        altAciklama: me.varlikToplam <= tutar ? 'Varlığın ${me.varlikToplam}M — tutar bunu aşıyor, hepsini seçmen gerekir.' : null,
        cards: me.varliklar,
        needTotal: tutar.clamp(0, me.varlikToplam),
        onay: 'Öde',
        gruplar: _gruplar(me),
        altButon: reddedebilir ? 'Reddet kartıyla iptal et' : null);
    if (r.altBasildi) return OdemeKarari.reddet();
    return OdemeKarari.ode(r.kartlar);
  }

  @override
  Future<PColor> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler) async {
    if (secenekler.length == 1) return secenekler.first;
    final c = await pickColor(ctx(), '🃏 Joker hangi renk olsun?', secenekler,
        altYazi: (k) => '(${me.propsOf(k).length}/${k.setBoyu})');
    return c ?? secenekler.first;
  }

  @override
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet) =>
      pickCards(ctx(), title: '🗑️ El limiti 7 — $adet kart at', cards: me.hand, exact: adet, max: adet, onay: 'At');
}
