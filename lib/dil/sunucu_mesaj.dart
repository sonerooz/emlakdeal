import '../dil.dart';

/// Sunucudan / oyun motorundan gelen Türkçe metni (hata, bilgi, oyun günlüğü, ödeme açıklaması) kullanıcının diline çevirir.
/// Önce [t] ile tam eşleşme, sonra aşağıdaki kalıplar. Bilinmeyen metin olduğu gibi döner; Türkçe seçiliyse hiç dokunulmaz.
///
/// Şablonlarda `{1}` yakalanan metni olduğu gibi, `{s1}` ise (kart/renk adı gibi) yine [sunucuMesaj]'dan geçirerek koyar.
/// Kalıplarda `@` bir oyuncu adı (boşluksuz sözcük) yakalar.
String sunucuMesaj(String tr) {
  if (!Dil.o.en) return tr;
  final tam = t(tr);
  if (tam != tr) return tam;
  for (final k in _kaliplar) {
    final m = k.$1.firstMatch(tr);
    if (m == null) continue;
    return k.$2.replaceAllMapped(RegExp(r'\{(s?)(\d)\}'), (x) {
      final g = m.group(int.parse(x.group(2)!)) ?? '';
      return x.group(1) == 's' ? sunucuMesaj(g) : g;
    });
  }
  return tr;
}

RegExp _r(String s) => RegExp('^${s.replaceAll('@', r'(\S+)')}\$');

final List<(RegExp, String)> _kaliplar = [
  (_r(r'Oda tutarı (\d+) altın oldu, herkes yeniden hazır olmalı\.'), 'The room amount is now {1} gold; everyone must get ready again.'),
  (_r(r'Bu oda (\d+) altınlık, yeterli altının yok\.'), 'This room is {1} gold and you do not have enough gold.'),
  (_r(r'Bu oda tutarı için yeterli altının yok \((\d+) gerekli\)\.'), 'You do not have enough gold for this room ({1} needed).'),
  (_r(r'Bu oda için yeterli altının yok \((\d+) gerekli\)\.'), 'You do not have enough gold for this room ({1} needed).'),
  (_r(r'(.+) için yeterli altın yok \((\d+) gerekli\)\.'), 'Not enough gold for {1} ({2} needed).'),
  // --- oda / lobi / bağlantı
  (_r(r'Oda bulunamadı: (.+)'), 'Room not found: {1}'),
  (_r(r'Oyuncu sayısı 2-5 olmalı \(şu an (\d+)\)'), 'There must be 2-5 players (currently {1})'),
  (_r(r'Hazır değil: (.+)'), 'Not ready: {1}'),
  (_r(r'@ süresi doldu, tur geçti\.'), "{1}'s time ran out; the turn was skipped."),
  (_r(r'@ geri döndü, yeniden kendisi oynuyor\.'), '{1} is back and is playing again.'),
  (_r(r'@ geri döndü\.'), '{1} is back.'),
  (_r(r'@ bağlantısı koptu, 30 sn bekleniyor…'), '{1} disconnected; waiting 30 s…'),
  (_r(r'@ geri dönmedi, yerine bot oynuyor\.'), "{1} didn't come back; a bot is playing instead."),
  (_r(r'Bilinmeyen hamle: (.+)'), 'Unknown move: {1}'),
  (_r(r'Bilinmeyen mesaj: (.+)'), 'Unknown message: {1}'),
  (_r(r'Hamle yapılamadı: (.+)'), 'Move failed: {1}'),
  // --- davet / arkadaş
  (_r(r'(.+) seni "(.*)" odasına çağırıyor\.?'), '{1} is inviting you to the "{2}" room.'),
  (_r(r'(.+) seni (.+) odasına çağırıyor\.?'), '{1} is inviting you to the {2} room.'),
  (_r(r'(.+) şu an çevrim içi değil\.'), '{1} is not online right now.'),
  (_r(r'(.+) davet edildi\.'), '{1} was invited.'),
  // --- dükkân / yapılandırma
  (_r(r'Yeterli altın yok \((\d+) gerekli\)\.'), 'Not enough gold ({1} needed).'),
  (_r(r'yapılandırılmadı: (.+)'), 'Not configured: {s1}'),
  // --- oyun günlüğü (cekirdek/game.dart _log)
  (_r(r'@ turuna başladı — kart çekiyor\.'), '{1} started their turn — drawing cards.'),
  (_r(r'@ (\d+) kart attı\.'), '{1} discarded {2} cards.'),
  (_r(r'🏆 @ 3 tam setle kazandı!'), '🏆 {1} won with 3 complete sets!'),
  (_r(r'@ (.+?) tapusunu (.+?) setine koydu\.'), '{1} put the {s2} title into the {s3} set.'),
  (_r(r'@ jokeri (.+?) setine taşıdı\.'), '{1} moved the wild to the {s2} set.'),
  (_r(r'@ (.+?) kartını (\d+)M para olarak bankaya koydu\.'), '{1} banked {s2} as {3}M cash.'),
  (_r(r'@ (.+?) kartını bankaya koydu\.'), '{1} banked {s2}.'),
  (_r(r'@ ödeyecek hiçbir şeyi yok\.'), '{1} has nothing to pay with.'),
  (_r(r'@ → @: (.+?) için (\d+)M ödedi\.'), '{1} → {2}: paid {4}M for {s3}.'),
  (_r(r'@ Reddet oynadı — aksiyon iptal!'), '{1} played Reject — action cancelled!'),
  (_r(r'@ Reddet oynadı — reddi reddetti!'), '{1} played Reject — rejected the rejection!'),
  (_r(r'@ Reddet oynadı — (.+?) iptal!'), '{1} played Reject — {s2} cancelled!'),
  (_r(r'@ Reddet ile karşılık verdi — talep yeniden geçerli!'), '{1} answered with Reject — the demand is back on!'),
  (_r(r'@ 2 Kart Çek oynadı: 2 kart çekti\.'), '{1} played Draw 2: drew 2 cards.'),
  (_r(r'@ İcra Takibi: @ 5M ödemeli\.'), '{1} played Pay Up: {2} must pay 5M.'),
  (_r(r'@ Ev Partisi: herkes 2M veriyor\.'), "{1} played Housewarming: everyone gives 2M."),
  (_r(r'@ (.+?) kirası: (\d+)M \(çift\) — herkes öder\.'), '{1} charged {s2} rent: {3}M (doubled) — everyone pays.'),
  (_r(r'@ (.+?) kirası: (\d+)M — herkes öder\.'), '{1} charged {s2} rent: {3}M — everyone pays.'),
  (_r(r'@ Tapu Devri: (.+?) çalmak istiyor\.'), '{1} played Deed Transfer: wants to steal {s2}.'),
  (_r(r'@ (.+?) tapusunu aldı\.'), '{1} took the {s2} title.'),
  (_r(r'@ Takas Pazarlığı: (.+?) ↔ (.+?)\.'), '{1} played Swap Meet: {s2} ↔ {s3}.'),
  (_r(r'@ Haciz: (.+?) setini istiyor!'), '{1} played Seizure: wants the {s2} set!'),
  (_r(r'@ (.+?) setini aldı!'), '{1} took the {s2} set!'),
  (_r(r'@ (.+?) setine (.+?) koydu\.'), '{1} added {s3} to the {s2} set.'),
  // --- ödeme / aksiyon açıklamaları (etiket, Reddet sorusu)
  (_r(r'İcra Takibi \((\d+)M\)'), 'Pay Up ({1}M)'),
  (_r(r'Ev Partisi \((\d+)M\)'), "Housewarming ({1}M)"),
  (_r(r'(.+?) kirası \((\d+)M\)'), '{s1} rent ({2}M)'),
  (_r(r'Tapu Devri \((.+)\)'), 'Deed Transfer ({s1})'),
  (_r(r'Takas Pazarlığı \((.+)\)'), 'Swap Meet ({s1})'),
  (_r(r'Haciz \((.+) seti\)'), 'Seizure ({s1} set)'),
  (_r(r'Reddet \(@ (.+?) ödemeyi reddetti\)'), 'Reject ({1} refused the {s2} payment)'),
  // --- kart adları
  (_r(r'Kira (.+?)/(.+)'), 'Rent {s1}/{s2}'),
  (_r(r'(.+?) / (.+)'), '{s1} / {s2}'),
];
