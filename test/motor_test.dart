import 'dart:convert';
import 'dart:math';

import 'package:emlakdeal_cekirdek/aktarim.dart';
import 'package:emlakdeal_cekirdek/bot.dart';
import 'package:emlakdeal_cekirdek/cards.dart';
import 'package:emlakdeal_cekirdek/game.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

int _tumKartlar(Game g) {
  var n = g.deck.length + g.discard.length;
  for (final p in g.players) {
    n += p.hand.length + p.bank.length;
    for (final l in p.props.values) {
      n += l.length;
    }
    for (final l in p.binalar.values) {
      n += l.length;
    }
  }
  return n;
}

Game _botOyunu(int n, int tohum) {
  final rng = Random(tohum);
  final g = Game(players: [for (var i = 0; i < n; i++) Player('B$i', isBot: true, decider: BotDecider(zorluk: 2, rng: rng))], rng: rng);
  g.deck.shuffle(rng);
  return g;
}

void main() {
  group('deste', () {
    final deste = GameCard.yeniDeste();

    test('123 kart, kimlikler benzersiz', () {
      expect(deste.length, 123);
      expect(deste.map((c) => c.id).toSet().length, deste.length);
    });

    test('her renkte setBoyu kadar tapu var; joker ve kira kartları geçerli renklerde', () {
      for (final r in PColor.values) {
        final tapu = deste.where((c) => c.kind == CardKind.property && c.color == r).length;
        expect(tapu, r.setBoyu, reason: '${r.name} tapu sayısı');
        expect(r.kira.length, r.setBoyu, reason: '${r.name} kira basamakları');
      }
      for (final c in deste.where((c) => c.kind == CardKind.wild)) {
        expect(c.colors.length, anyOf(0, 2), reason: 'joker: çok renkli (boş) ya da iki renkli');
      }
    });

    test('yeni renk (Pembe/Kocaeli) enum sonunda; eski sıra bozulmadı', () {
      expect(PColor.values.last, PColor.rose);
      expect(PColor.rose.index, 10);
      expect(PColor.brown.index, 0);
      expect(PColor.utility.index, 9);
      expect(PColor.rose.sehir, 'Kocaeli');
      expect(PColor.rose.sokaklar.length, 3);
    });

    test('kartlar JSON gidiş-dönüşte aynı kalır', () {
      for (final c in deste) {
        final y = GameCard.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(c.toJson())) as Map));
        expect(y.id, c.id);
        expect(y.kind, c.kind);
        expect(y.value, c.value);
        expect(y.color, c.color);
        expect(y.colors, c.colors);
        expect(y.action, c.action);
        expect(y.rentColors, c.rentColors);
      }
    });
  });

  group('bot oyunları', () {
    for (final n in [2, 3, 4, 5]) {
      test('$n kişilik bot oyunları biter, kart sayısı korunur', () {
        for (var tohum = 0; tohum < 6; tohum++) {
          final g = _botOyunu(n, tohum);
          final toplam = _tumKartlar(g);
          fakeAsync((async) {
            g.baslat();
            async.flushMicrotasks();
            var tur = 0, guard = 0;
            while (g.kazanan == null && tur < 400 && guard++ < 400000) {
              final p = g.aktif;
              (p.decider as BotDecider).turOyna(g, p);
              async.elapse(const Duration(seconds: 20));
              tur++;
            }
            expect(g.kazanan, isNotNull, reason: 'n=$n tohum=$tohum bitmedi');
          });
          expect(_tumKartlar(g), toplam, reason: 'n=$n tohum=$tohum kart kaybı/kopyası');
          final k = g.kazanan!;
          final tam = k.props.entries.where((e) => e.value.length >= e.key.setBoyu).length;
          expect(tam, greaterThanOrEqualTo(3), reason: 'kazanan 3 tam set sahibi olmalı');
        }
      });
    }
  });

  group('aktarım', () {
    test('kayıt JSON gidiş-dönüşte oyun durumunu korur (yeni renk dahil)', () {
      final g = _botOyunu(3, 7);
      fakeAsync((async) {
        g.baslat();
        async.flushMicrotasks();
        for (var i = 0; i < 12 && g.kazanan == null; i++) {
          (g.aktif.decider as BotDecider).turOyna(g, g.aktif);
          async.elapse(const Duration(seconds: 20));
        }
      });
      final rose = g.deck.firstWhere((c) => c.color == PColor.rose && c.kind == CardKind.property);
      g.deck.remove(rose);
      g.players[1].props.putIfAbsent(PColor.rose, () => []).add(rose);
      final roseSayisi = g.players[1].props[PColor.rose]!.length;

      final metin = jsonEncode(kayitJson(g));
      final h = _botOyunu(3, 99);
      kayitYukle(h, Map<String, dynamic>.from(jsonDecode(metin) as Map));
      expect(_tumKartlar(h), _tumKartlar(g));
      expect(h.deck.map((c) => c.id).toList(), g.deck.map((c) => c.id).toList());
      expect(h.players[1].props[PColor.rose]!.length, roseSayisi);
      expect(h.players[1].props[PColor.rose]!.map((c) => c.id), contains(rose.id));
      expect(h.current, g.current);
    });

    test('durumJson yalnız istenen oyuncunun elini açar', () {
      final g = _botOyunu(3, 3);
      fakeAsync((async) {
        g.baslat();
        async.flushMicrotasks();
      });
      final j = durumJson(g, icin: g.players[0]);
      final oy = j['oyuncular'] as List;
      expect((oy[0] as Map).containsKey('el'), isTrue);
      expect((oy[1] as Map).containsKey('el'), isFalse);
      expect((oy[1] as Map)['elSayisi'], g.players[1].hand.length);
    });
  });
}
