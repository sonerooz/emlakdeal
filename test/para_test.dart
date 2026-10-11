import 'package:flutter_test/flutter_test.dart';
import 'package:emlakdeal/dil.dart';
import 'package:emlakdeal/ui/renkler.dart';

void main() {
  tearDown(() => Dil.o.kod = 'tr');

  test('ekranda M yerine ₺ yazılır', () {
    expect(paraYaz('Bankanda 20M ile oyunu bitir.'), 'Bankanda 20₺ ile oyunu bitir.');
    expect(paraYaz('Ev (+3M) ve Rezidans (+4M)'), 'Ev (+3₺) ve Rezidans (+4₺)');
    expect(paraYaz('M'), 'M');
    expect(paraYaz('10MB'), '10MB');
    expect(t('kira {n}M', {'n': 8}), 'kira 8₺');
    expect(sozGoster('Buyur, 8M.'), 'Buyur, 8₺.');
    expect(oyunMetin('Ali → Veli: Kira için 5M ödedi.'), 'Ali → Veli: Kira için 5₺ ödedi.');
  });

  test('İngilizcede kalıp çevirisi bozulmaz', () {
    Dil.o.kod = 'en';
    expect(sunucuMesaj('Ali İcra Takibi: Veli 5M ödemeli.'), 'Ali played Pay Up: Veli must pay 5₺.');
    expect(sozGoster('Buyur, 8M.'), 'Here you go, 8₺.');
    expect(t('kira {n}M', {'n': 8}), 'rent 8₺');
  });
}
