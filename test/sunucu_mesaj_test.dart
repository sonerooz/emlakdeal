import 'package:emlakdeal/dil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Dil.o.kod = 'en');
  tearDown(() => Dil.o.kod = 'tr');

  void e(String tr, String en) => test(tr, () => expect(sunucuMesaj(tr), en));

  test('Türkçede metin değişmez', () {
    Dil.o.kod = 'tr';
    expect(sunucuMesaj('Oda bulunamadı: ABC'), 'Oda bulunamadı: ABC');
  });
  test('bilinmeyen metin olduğu gibi döner', () => expect(sunucuMesaj('Bambaşka bir şey'), 'Bambaşka bir şey'));

  e('Sıra sende değil.', "It's not your turn.");
  e('Altın Kart Arkası', 'Gold Card Back');
  e('Oda bulunamadı: ABC12', 'Room not found: ABC12');
  e('Oyuncu sayısı 2-5 olmalı (şu an 1)', 'There must be 2-5 players (currently 1)');
  e('Hazır değil: Kerem, Elif', 'Not ready: Kerem, Elif');
  e('Kerem süresi doldu, tur geçti.', "Kerem's time ran out; the turn was skipped.");
  e('Kerem geri döndü, yeniden kendisi oynuyor.', 'Kerem is back and is playing again.');
  e('Kerem geri döndü.', 'Kerem is back.');
  e('Kerem bağlantısı koptu, 30 sn bekleniyor…', 'Kerem disconnected; waiting 30 s…');
  e('Kerem geri dönmedi, yerine bot oynuyor.', "Kerem didn't come back; a bot is playing instead.");
  e('Bilinmeyen hamle: x', 'Unknown move: x');
  e('Bilinmeyen mesaj: y', 'Unknown message: y');
  e('Hamle yapılamadı: boom', 'Move failed: boom');
  e('Ali seni "ODA1" odasına çağırıyor.', 'Ali is inviting you to the "ODA1" room.');
  e('Ali seni ODA1 odasına çağırıyor', 'Ali is inviting you to the ODA1 room.');
  e('Ali şu an çevrim içi değil.', 'Ali is not online right now.');
  e('Ali davet edildi.', 'Ali was invited.');
  e('Yeterli altın yok (300 gerekli).', 'Not enough gold (300 needed).');
  e('yapılandırılmadı: Google girişi sunucuda henüz ayarlanmadı.', 'Not configured: Google sign-in is not set up on the server yet.');
  e('Kerem turuna başladı — kart çekiyor.', 'Kerem started their turn — drawing cards.');
  e('Kerem 2 kart attı.', 'Kerem discarded 2 cards.');
  e('🏆 Kerem 3 tam setle kazandı!', '🏆 Kerem won with 3 complete sets!');
  e('Kerem Konak tapusunu Sarı setine koydu.', 'Kerem put the Konak title into the Yellow set.');
  e('Kerem jokeri Kırmızı setine taşıdı.', 'Kerem moved the wild to the Red set.');
  e('Kerem Haciz kartını bankaya koydu.', 'Kerem banked Deal Breaker.');
  e('Kerem Haciz kartını 5M para olarak bankaya koydu.', 'Kerem banked Deal Breaker as 5M cash.');
  e('Kerem ödeyecek hiçbir şeyi yok.', 'Kerem has nothing to pay with.');
  e('Kerem → Elif: Tahsilat için 5M ödedi.', 'Kerem → Elif: paid 5M for Debt Collector.');
  e('Kerem Reddet oynadı — aksiyon iptal!', 'Kerem played Just Say No — action cancelled!');
  e('Kerem Reddet oynadı — reddi reddetti!', 'Kerem played Just Say No — rejected the rejection!');
  e('Kerem Reddet oynadı — Tahsilat iptal!', 'Kerem played Just Say No — Debt Collector cancelled!');
  e('Kerem Reddet ile karşılık verdi — talep yeniden geçerli!', 'Kerem answered with Just Say No — the demand is back on!');
  e('Kerem 2 Kart Çek oynadı: 2 kart çekti.', 'Kerem played Draw 2: drew 2 cards.');
  e('Kerem Tahsilat: Elif 5M ödemeli.', 'Kerem played Debt Collector: Elif must pay 5M.');
  e('Kerem Doğum Günüm: herkes 2M veriyor.', "Kerem played It's My Birthday: everyone gives 2M.");
  e('Kerem Mor kirası: 4M (çift) — herkes öder.', 'Kerem charged Purple rent: 4M (doubled) — everyone pays.');
  e('Kerem Mor kirası: 4M — herkes öder.', 'Kerem charged Purple rent: 4M — everyone pays.');
  e('Kerem Tapu Devri: Kaş çalmak istiyor.', 'Kerem played Sly Deal: wants to steal Kaş.');
  e('Kerem Kaş tapusunu aldı.', 'Kerem took the Kaş title.');
  e('Kerem Değiş Tokuş: Kaş ↔ Konak.', 'Kerem played Forced Deal: Kaş ↔ Konak.');
  e('Kerem Haciz: Sarı setini istiyor!', 'Kerem played Deal Breaker: wants the Yellow set!');
  e('Kerem Sarı setini aldı!', 'Kerem took the Yellow set!');
  e('Kerem Sarı setine Ev koydu.', 'Kerem added House to the Yellow set.');
  e('Tahsilat (5M)', 'Debt Collector (5M)');
  e('Doğum Günüm (2M)', "It's My Birthday (2M)");
  e('Mor kirası (4M)', 'Purple rent (4M)');
  e('Tapu Devri (Kaş)', 'Sly Deal (Kaş)');
  e('Değiş Tokuş (Konak)', 'Forced Deal (Konak)');
  e('Haciz (Sarı seti)', 'Deal Breaker (Yellow set)');
  e('Reddet (Elif Tahsilat ödemeyi reddetti)', 'Just Say No (Elif refused the Debt Collector payment)');
  e('Kira Kırmızı/Sarı', 'Rent Red/Yellow');
  e('Kırmızı / Sarı', 'Red / Yellow');
}
