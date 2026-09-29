import 'dart:math';
import '../model/cards.dart';
import '../model/game.dart';

/// Basit ama mantıklı bot: set tamamlamaya, kira/çalma ile rakibi zayıflatmaya öncelik verir.
class BotDecider implements Decider {
  @override
  Future<bool> justSayNo(Game g, Player me, String aciklama) async {
    if (aciklama.contains('Haciz') || aciklama.contains('Tapu Devri') || aciklama.contains('Değiş Tokuş')) {
      return true;
    }
    final m = RegExp(r'\((\d+)M\)').firstMatch(aciklama);
    final tutar = m == null ? 0 : int.parse(m.group(1)!);
    return tutar >= 3 || tutar >= me.varlikToplam;
  }

  @override
  Future<List<GameCard>> ode(Game g, Player me, int tutar, Player alacakli) async {
    // Öncelik: banka (küçükten büyüğe), binalar, tamamlanmamış set mülkleri (ucuzdan), tam set mülkleri.
    final banka = List.of(me.bank)..sort((a, b) => a.paraDegeri.compareTo(b.paraDegeri));
    final binalar = [for (final l in me.binalar.values) ...l];
    final eksik = [
      for (final e in me.props.entries)
        if (!me.setTam(e.key)) ...e.value
    ]..sort((a, b) => a.paraDegeri.compareTo(b.paraDegeri));
    final tam = [
      for (final e in me.props.entries)
        if (me.setTam(e.key)) ...e.value
    ]..sort((a, b) => a.paraDegeri.compareTo(b.paraDegeri));
    final aday = [...banka, ...binalar, ...eksik, ...tam];
    final secim = <GameCard>[];
    var toplam = 0;
    // Önce en büyük para kartı tutarı tek başına karşılıyorsa onu ver (az fazla ödeme)
    final tek = banka.where((c) => c.paraDegeri >= tutar).toList();
    if (tek.isNotEmpty) return [tek.first];
    for (final c in aday) {
      if (toplam >= tutar) break;
      secim.add(c);
      toplam += c.paraDegeri;
    }
    // fazla ödemeyi azalt: çıkarınca hâlâ yetiyorsa çıkar
    for (final c in List.of(secim)) {
      if (toplam - c.paraDegeri >= tutar) {
        secim.remove(c);
        toplam -= c.paraDegeri;
      }
    }
    return secim;
  }

  @override
  Future<PColor> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler) async {
    // En çok yaklaştığı (tamamlanmamış) seti tercih et; yoksa en yüksek kira.
    PColor? best;
    var bestSkor = -1.0;
    for (final c in secenekler) {
      final n = me.propsOf(c).length;
      final skor = me.setTam(c) ? -1.0 : (n / c.setBoyu) * 10 + c.kira.last / 10;
      if (skor > bestSkor) {
        bestSkor = skor;
        best = c;
      }
    }
    return best ?? secenekler.first;
  }

  @override
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet) async {
    final s = List.of(me.hand)..sort((a, b) => _tutmaDegeri(a).compareTo(_tutmaDegeri(b)));
    return s.take(adet).toList();
  }

  double _tutmaDegeri(GameCard c) {
    if (c.action == ActionType.justSayNo) return 100;
    if (c.action == ActionType.dealBreaker) return 90;
    if (c.isProperty) return 50.0 + c.paraDegeri;
    if (c.isRent) return 30.0 + c.value;
    if (c.isAction) return 20.0 + c.value;
    return c.paraDegeri.toDouble();
  }

  // ----------------------------------------------------------- tur
  Future<void> turOyna(Game g, Player me) async {
    final r = g.rakip(me);
    var guard = 0;
    while (g.playsLeft > 0 && g.kazanan == null && guard++ < 10) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (await _birHamle(g, me, r)) continue;
      break;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await g.turBitir();
  }

  GameCard? _kart(Player me, ActionType t) {
    for (final c in me.hand) {
      if (c.action == t) return c;
    }
    return null;
  }

  Future<bool> _birHamle(Game g, Player me, Player r) async {
    // 1) Deal Breaker
    final db = _kart(me, ActionType.dealBreaker);
    if (db != null && r.tamSetler.isNotEmpty) {
      final set = r.tamSetler.reduce((a, b) => a.kira.last >= b.kira.last ? a : b);
      return g.dealBreaker(me, db, set);
    }
    // 2) Mülk oyna (seti en çok ilerleten)
    final mulkler = me.hand.where((c) => c.isProperty).toList();
    if (mulkler.isNotEmpty) {
      mulkler.sort((a, b) => _mulkSkor(me, b).compareTo(_mulkSkor(me, a)));
      return g.mulkOyna(me, mulkler.first);
    }
    // 3) Kira
    GameCard? enIyiKira;
    PColor? enIyiRenk;
    var enIyi = 0;
    for (final c in me.hand.where((c) => c.isRent)) {
      final renkler = c.isWildRent ? PColor.values : c.rentColors;
      for (final renk in renkler) {
        final k = me.kira(renk);
        if (k > enIyi) {
          enIyi = k;
          enIyiKira = c;
          enIyiRenk = renk;
        }
      }
    }
    if (enIyiKira != null && enIyi > 0 && r.varlikToplam > 0) {
      final cift = _kart(me, ActionType.doubleRent);
      final ciftKullan = cift != null && g.playsLeft >= 2 && enIyi >= 2;
      return g.kiraOyna(me, enIyiKira, enIyiRenk!, cift: ciftKullan ? cift : null);
    }
    // 4) Sly Deal
    final sd = _kart(me, ActionType.slyDeal);
    final calinabilir = g.calinabilir(r);
    if (sd != null && calinabilir.isNotEmpty) {
      calinabilir.sort((a, b) => _calmaSkor(me, b).compareTo(_calmaSkor(me, a)));
      return g.slyDeal(me, sd, calinabilir.first);
    }
    // 5) Forced Deal (sadece set tamamlıyorsa)
    final fd = _kart(me, ActionType.forcedDeal);
    if (fd != null && calinabilir.isNotEmpty) {
      final benimkiler = g.calinabilir(me);
      for (final o in calinabilir) {
        final renk = o.etkinRenk!;
        if (me.propsOf(renk).length == renk.setBoyu - 1) {
          final verilebilir = benimkiler.where((b) => b.etkinRenk != renk).toList();
          if (verilebilir.isNotEmpty) {
            verilebilir.sort((a, b) => a.paraDegeri.compareTo(b.paraDegeri));
            return g.forcedDeal(me, fd, verilebilir.first, o);
          }
        }
      }
    }
    // 6-7) Borç tahsildarı / doğum günü
    final dc = _kart(me, ActionType.debtCollector);
    if (dc != null && r.varlikToplam >= 2) return g.borcTahsildari(me, dc);
    final bd = _kart(me, ActionType.birthday);
    if (bd != null && r.varlikToplam >= 1) return g.dogumGunu(me, bd);
    // 8) Ev/otel
    for (final t in [ActionType.house, ActionType.hotel]) {
      final b = _kart(me, t);
      if (b == null) continue;
      for (final set in me.tamSetler.where((s) => s.binaOlur)) {
        if (await g.binaKoy(me, b, set)) return true;
      }
    }
    // 9) Pass Go
    final pg = _kart(me, ActionType.passGo);
    if (pg != null) return g.passGo(me, pg);
    // 10) Para bankaya (büyükten)
    final para = me.hand.where((c) => c.isMoney).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (para.isNotEmpty) return g.bankayaKoy(me, para.first);
    // 11) El kalabalıksa işe yaramayan aksiyonu bankaya
    if (me.hand.length > 5) {
      final aksiyon = me.hand.where((c) => (c.isAction || c.isRent) && c.action != ActionType.justSayNo).toList()
        ..sort((a, b) => _tutmaDegeri(a).compareTo(_tutmaDegeri(b)));
      if (aksiyon.isNotEmpty) return g.bankayaKoy(me, aksiyon.first);
    }
    return false;
  }

  double _mulkSkor(Player me, GameCard c) {
    if (c.kind == CardKind.property) {
      final n = me.propsOf(c.color!).length;
      return (n + 1) / c.color!.setBoyu * 10 + c.paraDegeri;
    }
    final sec = c.isMultiWild ? PColor.values : c.colors;
    return sec.map((k) => (me.propsOf(k).length + 1) / k.setBoyu * 10).reduce(max) - 1;
  }

  double _calmaSkor(Player me, GameCard c) {
    final renk = c.etkinRenk!;
    final n = me.propsOf(renk).length;
    return (n + 1) / renk.setBoyu * 10 + c.paraDegeri;
  }
}
