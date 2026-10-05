import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emlakdeal/izleme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Izleme iz;
  late List<Map<String, dynamic>> gonderilen;
  late bool ag;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    iz = Izleme.testIcin();
    gonderilen = [];
    ag = true;
    iz.gonderici = (r) async {
      if (!ag) return false;
      gonderilen.add(r);
      return true;
    };
  });

  Future<int> kuyrukBoyu() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(Izleme.kuyrukAnahtari);
    return s == null ? 0 : RegExp('"mesaj"').allMatches(s).length;
  }

  test('ilk hata hemen gider, kaynak ve iz alanları dolu', () async {
    iz.iz('ekran: lobi');
    await iz.hata('boom', 'yigin', kaynak: 'zone');
    expect(gonderilen.length, 1);
    expect(gonderilen.first['kaynak'], 'zone');
    expect(gonderilen.first['sayac'], 1);
    expect((gonderilen.first['iz'] as List).any((s) => '$s'.contains('ekran: lobi')), isTrue);
  });

  test('aynı hata tekrar edince sayaç artar, 30 sn toplu gönderimde tek raporla gider', () async {
    await iz.hata('boom', 'y');
    await iz.hata('boom', 'y');
    await iz.hata('boom', 'y');
    expect(gonderilen.length, 1);
    await iz.topluGonder();
    expect(gonderilen.length, 2);
    expect(gonderilen.last['sayac'], 2);
    await iz.topluGonder();
    expect(gonderilen.length, 2);
  });

  test('gönderilemeyen rapor kuyruğa girir, ağ gelince boşalır', () async {
    ag = false;
    await iz.hata('offline', 'y');
    expect(gonderilen, isEmpty);
    expect(await kuyrukBoyu(), 1);
    await iz.kuyrukBosalt();
    expect(await kuyrukBoyu(), 1);
    ag = true;
    await iz.kuyrukBosalt();
    expect(gonderilen.length, 1);
    expect(gonderilen.first['mesaj'], 'offline');
    expect(await kuyrukBoyu(), 0);
  });

  test('kuyruk en fazla 20 rapor tutar (en eskiler düşer)', () async {
    ag = false;
    for (var i = 0; i < 25; i++) {
      await iz.hata('hata $i', 'y');
    }
    expect(await kuyrukBoyu(), Izleme.kuyrukMax);
    ag = true;
    await iz.kuyrukBosalt();
    expect(gonderilen.length, Izleme.kuyrukMax);
    expect(gonderilen.first['mesaj'], 'hata 5');
  });

  test('kırıntı izi en fazla 30 satır tutar', () {
    for (var i = 0; i < 50; i++) {
      iz.iz('satir $i');
    }
    expect(iz.izler.length, Izleme.izMax);
    expect(iz.izler.last.endsWith('satir 49'), isTrue);
  });

  test('token, Bearer ve e-posta maskelenir', () async {
    expect(Izleme.maskele('Authorization: Bearer abc.def-123'), isNot(contains('abc.def')));
    expect(Izleme.maskele('mail a.b@x.com'), isNot(contains('a.b@x.com')));
    expect(Izleme.maskele('token=SECRETDEGER1'), isNot(contains('SECRETDEGER1')));
    expect(Izleme.maskele('k ${'a1' * 20}'), contains('***'));
    await iz.hata('Bearer topsecret99 hata', 'y');
    expect(gonderilen.first['mesaj'], isNot(contains('topsecret99')));
  });
}
