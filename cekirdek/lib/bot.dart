import 'dart:math';
import 'cards.dart';
import 'game.dart';

/// Basit ama mantıklı bot: set tamamlamaya, kira/çalma ile rakipleri zayıflatmaya öncelik verir.
/// Birden fazla rakipte hedefi (en zengin / en tehlikeli) kendisi seçer.
class BotDecider extends Decider {
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
    final tek = banka.where((c) => c.paraDegeri >= tutar).toList();
    if (tek.isNotEmpty) return [tek.first];
    final secim = <GameCard>[];
    var toplam = 0;
    for (final c in aday) {
      if (toplam >= tutar) break;
      secim.add(c);
      toplam += c.paraDegeri;
    }
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
    var guard = 0;
    while (g.playsLeft > 0 && g.kazanan == null && guard++ < 10) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (await _birHamle(g, me)) continue;
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

  /// En zengin rakip (para talebi hedefi).
  Player _enZengin(Game g, Player me) =>
      g.rakipler(me).reduce((a, b) => a.varlikToplam >= b.varlikToplam ? a : b);

  Future<bool> _birHamle(Game g, Player me) async {
    final rakipler = g.rakipler(me);
    // 1) Haciz: en değerli tam sete sahip rakip
    final db = _kart(me, ActionType.dealBreaker);
    if (db != null) {
      Player? hedef;
      PColor? set;
      var best = -1;
      for (final r in rakipler) {
        for (final s in r.tamSetler) {
          if (s.kira.last > best) {
            best = s.kira.last;
            hedef = r;
            set = s;
          }
        }
      }
      if (hedef != null) return g.dealBreaker(me, db, hedef, set!);
    }
    // 2) Tapu oyna (seti en çok ilerleten)
    final mulkler = me.hand.where((c) => c.isProperty).toList();
    if (mulkler.isNotEmpty) {
      mulkler.sort((a, b) => _mulkSkor(me, b).compareTo(_mulkSkor(me, a)));
      return g.mulkOyna(me, mulkler.first);
    }
    // 3) Kira (herkesten alınır)
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
    final rakipVarlik = rakipler.fold(0, (s, r) => s + r.varlikToplam);
    if (enIyiKira != null && enIyi > 0 && rakipVarlik > 0) {
      final cift = _kart(me, ActionType.doubleRent);
      final ciftKullan = cift != null && g.playsLeft >= 2 && enIyi >= 2;
      return g.kiraOyna(me, enIyiKira, enIyiRenk!, cift: ciftKullan ? cift : null);
    }
    // 4) Tapu Devri: tüm rakiplerin alınabilir tapuları arasından en işe yarayan
    final sd = _kart(me, ActionType.slyDeal);
    final calinabilir = [for (final r in rakipler) ...g.calinabilir(r)];
    if (sd != null && calinabilir.isNotEmpty) {
      calinabilir.sort((a, b) => _calmaSkor(me, b).compareTo(_calmaSkor(me, a)));
      return g.slyDeal(me, sd, calinabilir.first);
    }
    // 5) Değiş Tokuş (sadece set tamamlıyorsa)
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
    // 6-7) Borç tahsildarı (en zengine) / doğum günü
    final dc = _kart(me, ActionType.tahsilat);
    if (dc != null) {
      final hedef = _enZengin(g, me);
      if (hedef.varlikToplam >= 2) return g.tahsilat(me, dc, hedef);
    }
    final bd = _kart(me, ActionType.birthday);
    if (bd != null && rakipVarlik >= 1) return g.dogumGunu(me, bd);
    // 8) Ev/otel
    for (final t in [ActionType.house, ActionType.hotel]) {
      final b = _kart(me, t);
      if (b == null) continue;
      for (final set in me.tamSetler.where((s) => s.binaOlur)) {
        if (await g.binaKoy(me, b, set)) return true;
      }
    }
    // 9) 2 Kart Çek
    final pg = _kart(me, ActionType.passGo);
    if (pg != null) return g.passGo(me, pg);
    // 10) Para bankaya (büyükten)
    final para = me.hand.where((c) => c.isMoney).toList()..sort((a, b) => b.value.compareTo(a.value));
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
