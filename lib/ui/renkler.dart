import 'package:flutter/material.dart';
import 'package:emlakdeal_cekirdek/cards.dart';
import '../dil.dart';

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

/// Ekranda gösterilen motor metinleri (renk, kart, aksiyon adı) kullanıcının dilinde.
extension PColorCeviri on PColor {
  String get adT => t(ad);
  String get kisaAdT => t(kisaAd);
  String get sehirT => t(sehir);
}

extension ActionCeviri on ActionType {
  String get adT => t(ad);
  String get aciklamaT => t(aciklama);
}

extension KartCeviri on GameCard {
  String get adT {
    switch (kind) {
      case CardKind.money:
        return ad;
      case CardKind.property:
        return sokak != null ? t(sokak!) : color!.adT;
      case CardKind.wild:
        return colors.isEmpty ? t('Joker Tapu') : '${colors[0].adT} / ${colors[1].adT}';
      case CardKind.action:
        return action!.adT;
      case CardKind.rent:
        return rentColors.isEmpty ? t('Joker Kira') : t('Kira {a}/{b}', {'a': rentColors[0].adT, 'b': rentColors[1].adT});
    }
  }

  String get kisaAdT {
    switch (kind) {
      case CardKind.money:
        return ad;
      case CardKind.property:
        return sokak != null ? t(sokak!) : color!.adT;
      case CardKind.wild:
        return t('Joker');
      case CardKind.action:
        return action!.adT;
      case CardKind.rent:
        return rentColors.isEmpty ? t('Joker Kira') : t('Kira');
    }
  }
}

String _kartAdi(String s) {
  if (s.contains(' / ')) return s.split(' / ').map(_kartAdi).join(' / ');
  final m = RegExp(r'^Kira (.+)/(.+)$').firstMatch(s);
  if (m != null) return t('Kira {a}/{b}', {'a': t(m[1]!), 'b': t(m[2]!)});
  return t(s);
}

// (kalıp, İngilizce sözlük anahtarı = Türkçe şablon, yakalamaların türü: n=oyuncu adı, k=kart/renk adı, s=sebep, x=olduğu gibi)
final List<(RegExp, String, String)> _kaliplar = [
  (RegExp(r'^(\S+) turuna başladı — kart çekiyor\.$'), '{a} turuna başladı — kart çekiyor.', 'n'),
  (RegExp(r'^(\S+) (\d+) kart attı\.$'), '{a} {b} kart attı.', 'nx'),
  (RegExp(r'^🏆 (\S+) 3 tam setle kazandı!$'), '🏆 {a} 3 tam setle kazandı!', 'n'),
  (RegExp(r'^(\S+) (.+) tapusunu (.+) setine koydu\.$'), '{a} {b} tapusunu {c} setine koydu.', 'nkk'),
  (RegExp(r'^(\S+) jokeri (.+) setine taşıdı\.$'), '{a} jokeri {b} setine taşıdı.', 'nk'),
  (RegExp(r'^(\S+) (.+) kartını (\d+)M para olarak bankaya koydu\.$'), '{a} {b} kartını {c}M para olarak bankaya koydu.', 'nkx'),
  (RegExp(r'^(\S+) (.+) kartını bankaya koydu\.$'), '{a} {b} kartını bankaya koydu.', 'nk'),
  (RegExp(r'^(\S+) ödeyecek hiçbir şeyi yok\.$'), '{a} ödeyecek hiçbir şeyi yok.', 'n'),
  (RegExp(r'^(\S+) → (\S+): (.+) için (\d+)M ödedi\.$'), '{a} → {b}: {c} için {d}M ödedi.', 'nnsx'),
  (RegExp(r'^(\S+) Reddet oynadı — aksiyon iptal!$'), '{a} Reddet oynadı — aksiyon iptal!', 'n'),
  (RegExp(r'^(\S+) Reddet oynadı — reddi reddetti!$'), '{a} Reddet oynadı — reddi reddetti!', 'n'),
  (RegExp(r'^(\S+) Reddet oynadı — (.+) iptal!$'), '{a} Reddet oynadı — {b} iptal!', 'ns'),
  (RegExp(r'^(\S+) Reddet ile karşılık verdi — talep yeniden geçerli!$'), '{a} Reddet ile karşılık verdi — talep yeniden geçerli!', 'n'),
  (RegExp(r'^(\S+) 2 Kart Çek oynadı: 2 kart çekti\.$'), '{a} 2 Kart Çek oynadı: 2 kart çekti.', 'n'),
  (RegExp(r'^(\S+) İcra Takibi: (\S+) 5M ödemeli\.$'), '{a} İcra Takibi: {b} 5M ödemeli.', 'nn'),
  (RegExp(r'^(\S+) Ev Partisi: herkes 2M veriyor\.$'), '{a} Ev Partisi: herkes 2M veriyor.', 'n'),
  (RegExp(r'^(\S+) (.+) kirası: (\d+)M \(çift\) — herkes öder\.$'), '{a} {b} kirası: {c}M (çift) — herkes öder.', 'nkx'),
  (RegExp(r'^(\S+) (.+) kirası: (\d+)M — herkes öder\.$'), '{a} {b} kirası: {c}M — herkes öder.', 'nkx'),
  (RegExp(r'^(\S+) Tapu Devri: (.+) çalmak istiyor\.$'), '{a} Tapu Devri: {b} çalmak istiyor.', 'nk'),
  (RegExp(r'^(\S+) (.+) tapusunu aldı\.$'), '{a} {b} tapusunu aldı.', 'nk'),
  (RegExp(r'^(\S+) Takas Pazarlığı: (.+) ↔ (.+)\.$'), '{a} Takas Pazarlığı: {b} ↔ {c}.', 'nkk'),
  (RegExp(r'^(\S+) Haciz: (.+) setini istiyor!$'), '{a} Haciz: {b} setini istiyor!', 'nk'),
  (RegExp(r'^(\S+) (.+) setini aldı!$'), '{a} {b} setini aldı!', 'nk'),
  (RegExp(r'^(\S+) (.+) setine (.+) koydu\.$'), '{a} {b} setine {c} koydu.', 'nkk'),
  (RegExp(r'^İcra Takibi \((\d+)M\)$'), 'İcra Takibi ({a}M)', 'x'),
  (RegExp(r'^Ev Partisi \((\d+)M\)$'), 'Ev Partisi ({a}M)', 'x'),
  (RegExp(r'^(.+) kirası \((\d+)M\)$'), '{a} kirası ({b}M)', 'kx'),
  (RegExp(r'^Tapu Devri \((.+)\)$'), 'Tapu Devri ({a})', 'k'),
  (RegExp(r'^Takas Pazarlığı \((.+)\)$'), 'Takas Pazarlığı ({a})', 'k'),
  (RegExp(r'^Haciz \((.+) seti\)$'), 'Haciz ({a} seti)', 'k'),
  (RegExp(r'^Reddet \((\S+) (.+) ödemeyi reddetti\)$'), 'Reddet ({a} {b} ödemeyi reddetti)', 'ns'),
];

/// Motorun/sunucunun ürettiği Türkçe oyun metnini (günlük satırı, banner etiketi, açıklama) kullanıcının diline çevirir.
String oyunMetin(String tr) {
  if (!Dil.o.en) return tr;
  for (final (re, anahtar, tur) in _kaliplar) {
    final m = re.firstMatch(tr);
    if (m == null) continue;
    final a = <String, Object?>{};
    for (var i = 0; i < tur.length; i++) {
      final v = m[i + 1]!;
      a[String.fromCharCode(97 + i)] = switch (tur[i]) {
        'k' => _kartAdi(v),
        's' => _kartAdi(v).toLowerCase(),
        _ => v,
      };
    }
    return t(anahtar, a);
  }
  return sunucuMesaj(_kartAdi(tr));
}
