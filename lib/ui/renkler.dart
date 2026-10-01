import 'package:flutter/material.dart';
import 'package:emlakdeal_cekirdek/cards.dart';

/// Mülk setlerinin ekran renkleri (motor Flutter'dan bağımsız olduğu için burada).
extension PColorRenk on PColor {
  Color get renk => const {
        PColor.brown: Color(0xFF7B4A2E),
        PColor.lightBlue: Color(0xFF7FC8F8),
        PColor.pink: Color(0xFFB03A9E),
        PColor.orange: Color(0xFFF08A24),
        PColor.red: Color(0xFFD9342B),
        PColor.yellow: Color(0xFFF2D53C),
        PColor.green: Color(0xFF1E9E4A),
        PColor.darkBlue: Color(0xFF1F3F9E),
        PColor.railroad: Color(0xFF2B2B2B),
        PColor.utility: Color(0xFF3FC1C9),
      }[this]!;
}

/// Para kartı rengi (Türkçe baskı): 1M gri, 2M turuncu, 3M yeşil, 4M mavi, 5M mor, 10M kırmızı.
/// Hamle/kira kartlarının değer rozeti de aynı renkle gider.
Color paraRengi(int deger) => const {
      1: Color(0xFFB8B8B8),
      2: Color(0xFFF08A24),
      3: Color(0xFF2E9E4F),
      4: Color(0xFF2F6FD1),
      5: Color(0xFF7B3FB5),
      10: Color(0xFFD9342B),
    }[deger] ?? const Color(0xFFDDDDDD);
