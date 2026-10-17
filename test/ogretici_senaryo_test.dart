import 'package:emlakdeal_cekirdek/bot.dart';
import 'package:emlakdeal_cekirdek/cards.dart';
import 'package:emlakdeal_cekirdek/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// İnsan yerine: joker her zaman Turuncu (rehberli ilk maçtaki OgrDecider gibi).
class _Ogr extends BotDecider {
  @override
  Future<PColor> jokerRengi(Game g, Player me, GameCard joker, List<PColor> s) async => PColor.orange;

  int reddetSorusu = 0;
  @override
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama, {required bool reddedebilir}) async {
    if (reddedebilir) {
      reddetSorusu++;
      return OdemeKarari.reddet();
    }
    return super.odemeKarari(g, me, tutar, alacakli, aciklama, reddedebilir: reddedebilir);
  }
}

/// Rehberli ilk maç senaryosu (game_screen._ogrKur ile aynı kurulum): 2 turda kesin kazanılır.
void main() {
  test('rehberli ilk maç: tapu, para, joker, rakip turu, takas, haciz -> 3 set', () async {
    final ogr = _Ogr();
    final ben = Player('Ben', isBot: false, decider: ogr);
    final bot = Player('Ali', isBot: true, decider: BotDecider());
    final g = Game(players: [ben, bot]);
    final d = g.deck;
    GameCard al(bool Function(GameCard) f) {
      final c = d.firstWhere(f);
      d.remove(c);
      return c;
    }

    GameCard tapu(PColor r, String ad) => al((c) => c.kind == CardKind.property && c.color == r && c.sokak == ad);
    GameCard para(int v) => al((c) => c.isMoney && c.value == v);
    GameCard eylem(ActionType a) => al((c) => c.action == a);
    for (final (r, ad) in [(PColor.lightBlue, 'Çukurova'), (PColor.lightBlue, 'Yüreğir'), (PColor.pink, 'Meram'), (PColor.pink, 'Karatay'), (PColor.orange, 'Muratpaşa'), (PColor.utility, 'Doğalgaz İdaresi')]) {
      ben.mulkEkle(tapu(r, ad), r);
    }
    for (final s in ['Nilüfer', 'Osmangazi', 'Gemlik']) {
      bot.mulkEkle(tapu(PColor.red, s), PColor.red);
    }
    bot.mulkEkle(tapu(PColor.pink, 'Selçuklu'), PColor.pink);
    bot.mulkEkle(tapu(PColor.green, 'Çankaya'), PColor.green);
    final seyhan = tapu(PColor.lightBlue, 'Seyhan');
    final zam = eylem(ActionType.doubleRent);
    final joker = al((c) => c.isWild && c.colors.length == 2 && c.colors.contains(PColor.pink) && c.colors.contains(PColor.orange));
    final reddet = eylem(ActionType.justSayNo);
    ben.hand.addAll([seyhan, zam, joker, reddet]);
    final icra = eylem(ActionType.tahsilat);
    bot.hand.addAll([icra, para(5)]);
    d.addAll([eylem(ActionType.dealBreaker), eylem(ActionType.forcedDeal), para(2), para(1), para(2), para(1)]);
    g.current = 0;

    await g.turBaslat();
    expect(ben.hand.length, 6);
    expect(await g.mulkOyna(ben, seyhan), isTrue);
    expect(ben.setTam(PColor.lightBlue), isTrue);
    expect(await g.bankayaKoy(ben, zam), isTrue, reason: 'hamle kartı nakit olur');
    expect(ben.bank.length, 1);
    expect(await g.mulkOyna(ben, joker), isTrue);
    expect(ben.propsOf(PColor.orange).length, 2);
    expect(ben.tamSetSayisi, 1);
    expect(g.playsLeft, 0);

    await g.turBitir();
    expect(g.aktif, bot);
    final bankaOnce = ben.bankaToplam;
    expect(await g.tahsilat(bot, icra, ben), isTrue);
    expect(ogr.reddetSorusu, 1, reason: 'Reddet seçeneği sunulmalı');
    expect(ben.bankaToplam, bankaOnce, reason: 'Reddet edilince ödeme yok');
    expect(ben.hand.contains(reddet), isFalse, reason: 'Reddet kartı harcandı');
    await g.turBitir();
    expect(g.aktif, ben);
    expect(g.playsLeft, 3);
    final takas = ben.hand.firstWhere((c) => c.action == ActionType.forcedDeal);
    final haciz = ben.hand.firstWhere((c) => c.action == ActionType.dealBreaker);
    expect(bot.setTam(PColor.red), isTrue, reason: 'rakip tam setini bozmamalı');
    final benimki = ben.propsOf(PColor.utility).first;
    final onunki = bot.propsOf(PColor.pink).first;
    expect(await g.forcedDeal(ben, takas, benimki, onunki), isTrue);
    expect(ben.setTam(PColor.pink), isTrue);
    expect(ben.tamSetSayisi, 2);
    expect(g.kazanan, isNull);
    expect(await g.dealBreaker(ben, haciz, bot, PColor.red), isTrue);
    expect(g.kazanan, ben);
  });
}
