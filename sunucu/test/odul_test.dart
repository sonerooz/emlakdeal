import 'package:emlakdeal_cekirdek/seviye.dart';
import 'package:test/test.dart';

import '../bin/db.dart';

void main() {
  test('seviye atlayınca altın verilir', () {
    final db = Db(':memory:');
    final id = db.sosyal('google', 'g-lv', nick: 'Lv').id!;
    final once = db.altinOku(id);
    // 1→2 eşiği 110 XP; online galibiyet 150 XP verir
    final r = db.sonuc(id, kazandi: true, rakip: 1, online: true, altinVer: false);
    expect(r['levelAtladi'], isTrue);
    expect(r['levelAltin'], levelAltinOdulu(2));
    expect(db.altinOku(id), once + levelAltinOdulu(2));
  });

  test('x2 XP güçlendiricisi online XP\'yi ikiye katlar ve süresi üst üste eklenir', () {
    final db = Db(':memory:');
    final id = db.sosyal('google', 'g-x2', nick: 'Xp').id!;
    db.testSql('UPDATE kullanicilar SET altin = 2000 WHERE id = $id');
    final normal = db.sonuc(id, kazandi: false, rakip: 1, online: true, altinVer: false)['xp'] as int;
    expect(db.satinAl(id, 'xp2_saat'), isNull);
    final b1 = db.xp2Bitis(id)!;
    expect(db.satinAl(id, 'xp2_saat'), isNull);
    expect(db.xp2Bitis(id)!.difference(b1).inMinutes, 60);
    final r = db.sonuc(id, kazandi: false, rakip: 1, online: true, altinVer: false);
    expect(r['xp'], normal * 2);
    expect(r['xp2'], isTrue);
    expect(db.sonuc(id, kazandi: false, rakip: 1, online: false)['xp'], 0);
  });

  test('tüm görevler alınınca bitirme ödülü bir kez verilir', () {
    final db = Db(':memory:');
    final id = db.sosyal('google', 'g-gr', nick: 'Gr').id!;
    // ilerlemeyi gerçek oyun sonuçlarıyla doldurmak yerine doğrudan yaz
    final tarih = db.bugunTarihTest();
    for (final g in db.gorevler(id)) {
      db.testSql("INSERT OR REPLACE INTO gorevler (kullanici_id, tarih, gorev, ilerleme, alindi) VALUES ($id, '$tarih', '${g['id']}', ${g['hedef']}, 0)");
    }
    final l = db.gorevler(id);
    Map<String, dynamic>? son;
    for (final g in l) {
      son = db.gorevAl(id, g['id'] as String);
      expect(son, isNotNull);
    }
    expect(son!['tum'], isNotNull);
    expect(db.tumGorevDurumu(id)['alindi'], isTrue);
    expect(db.testSayi("SELECT COUNT(*) FROM gorevler WHERE kullanici_id = $id AND gorev = 'tum'"), 1);
    expect(db.gorevAl(id, l.last['id'] as String), isNull);
  });
}
