import 'package:emlakdeal_cekirdek/bot.dart';
import 'package:emlakdeal_cekirdek/cards.dart';
import 'package:emlakdeal_cekirdek/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ağdan gelen kararları taklit eder: kurallara aykırı cevaplar verir.
class _Hileci extends BotDecider {
  List<GameCard> Function(Game g)? odemeKartlari;
  bool reddet = false;
  List<GameCard> Function(Game g)? atilacak;

  @override
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama, {required bool reddedebilir}) async =>
      reddet ? OdemeKarari.reddet() : OdemeKarari.ode(odemeKartlari?.call(g) ?? const []);

  @override
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet) async => atilacak?.call(g) ?? const [];
}

void main() {
  late List<GameCard> deste;
  late Player a, b;
  late _Hileci hileA, hileB;
  late Game g;

  GameCard al(bool Function(GameCard) f) {
    final c = deste.firstWhere(f);
    deste.remove(c);
    return c;
  }

  setUp(() {
    deste = GameCard.yeniDeste();
    hileA = _Hileci();
    hileB = _Hileci();
    a = Player('A', isBot: false, decider: hileA);
    b = Player('B', isBot: false, decider: hileB);
    g = Game(players: [a, b]);
    g.deck.clear();
    g.current = 0;
    g.playsLeft = 3;
    g.turBasladi = true;
  });

  test('ödeme yalnız borçlunun varlıklarından ve borcu karşılayacak kadar', () async {
    final tahsil = al((c) => c.action == ActionType.tahsilat);
    a.hand.add(tahsil);
    final aPara = al((c) => c.isMoney && c.value == 5);
    a.bank.add(aPara);
    final b1 = al((c) => c.isMoney && c.value == 1), b2 = al((c) => c.isMoney && c.value == 2), b3 = al((c) => c.isMoney && c.value == 3);
    b.bank.addAll([b1, b2, b3]);
    hileB.odemeKartlari = (_) => [aPara, aPara]; // rakibin (alacaklının) kartıyla "ödeme"
    expect(await g.tahsilat(a, tahsil, b), isTrue);
    expect(a.bankaToplam, 5 + 6 - b.bankaToplam);
    expect(a.bankaToplam - 5, greaterThanOrEqualTo(5), reason: 'borç tam ödenmeli');
  });

  test('Reddet kartı olmadan reddetmek ödemeyi engellemez', () async {
    final tahsil = al((c) => c.action == ActionType.tahsilat);
    a.hand.add(tahsil);
    b.bank.add(al((c) => c.isMoney && c.value == 5));
    hileB.reddet = true;
    expect(await g.tahsilat(a, tahsil, b), isTrue);
    expect(a.bankaToplam, 5);
    expect(b.bankaToplam, 0);
  });

  test('elde olmayan aksiyon kartı (atık destesinden) oynanamaz', () async {
    final pg = al((c) => c.action == ActionType.passGo);
    g.discard.add(pg);
    g.deck.addAll([al((c) => c.isMoney), al((c) => c.isMoney)]);
    expect(await g.passGo(a, pg), isFalse);
    expect(a.hand, isEmpty);
    final hb = al((c) => c.action == ActionType.dealBreaker);
    b.hand.add(hb);
    expect(await g.dealBreaker(a, hb, b, PColor.darkBlue), isFalse);
  });

  test('rakibin masasındaki jokerin rengi değiştirilemez (kopyalanamaz)', () async {
    final j = al((c) => c.isWild && !c.isMultiWild);
    b.mulkEkle(j, j.colors.first);
    expect(await g.jokerRengiDegistir(a, j), isFalse);
    expect(a.props.values.expand((l) => l), isNot(contains(j)));
  });

  test('tur sonu atma: yalnız kendi elinden, tam adet', () async {
    for (var i = 0; i < 9; i++) {
      a.hand.add(al((c) => c.isMoney));
    }
    final bKart = al((c) => c.isMoney);
    b.bank.add(bKart);
    g.deck.addAll([for (var i = 0; i < 6; i++) al((c) => c.isMoney)]);
    hileA.atilacak = (_) => [bKart, bKart];
    await g.turBitir();
    expect(a.hand.length, 7);
    expect(b.bank, contains(bKart));
    expect(g.discard, isNot(contains(bKart)));
  });
}
