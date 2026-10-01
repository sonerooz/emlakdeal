import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monodeal/model/cards.dart';
import 'package:monodeal/ui/card_widget.dart';

void main() {
  testWidgets('kart gorunumleri', (tester) async {
    final f = File('C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    if (f.existsSync()) {
      final l = FontLoader('Roboto')..addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
      await l.load();
    }
    final d = GameCard.yeniDeste();
    GameCard bul(bool Function(GameCard) t) => d.firstWhere(t);
    final kartlar = [
      bul((c) => c.isMoney && c.value == 5),
      bul((c) => c.kind == CardKind.property && c.sokak == 'Sirkeci'),
      bul((c) => c.action == ActionType.house),
      bul((c) => c.action == ActionType.dealBreaker),
      bul((c) => c.isRent && !c.isWildRent),
      bul((c) => c.isWild && !c.isMultiWild),
    ];
    await tester.binding.setSurfaceSize(const Size(1000, 520));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF1B5E3A),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final c in kartlar) Padding(padding: const EdgeInsets.all(6), child: CardView(c, w: 150))]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final c in kartlar) Padding(padding: const EdgeInsets.all(6), child: CardView(c, w: 74))]),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('kartlar.png'));
  });
}
