import 'package:test/test.dart';

import '../bin/db.dart';

void main() {
  test('eski misafir silinir, bağlı hesap ve yeni misafir kalır', () {
    final db = Db(':memory:');
    final eski = db.misafir('cihaz-eski').id;
    final yeni = db.misafir('cihaz-yeni').id;
    final bagli = db.misafir('cihaz-bagli').id;
    db.testSql("UPDATE kullanicilar SET son_giris = '2020-01-01T00:00:00.000Z' WHERE id IN ($eski, $bagli)");
    db.testSql("UPDATE kullanicilar SET eposta = 'a@b.com' WHERE id = $bagli");
    db.testSql("UPDATE oturumlar SET son_kullanim = '2020-01-01T00:00:00.000Z' WHERE kullanici_id = $yeni");
    final t = db.eskiKayitlariTemizle();
    expect(t.misafir, 1);
    expect(t.oturum, greaterThanOrEqualTo(1));
    expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $eski'), 0);
    expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $yeni'), 1);
    expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $bagli'), 1);
  });

  group('hesap birleştirme', () {
    test('misafir ilerlemesi mevcut Google hesabına eklenir', () {
      final db = Db(':memory:');
      final hesap = db.sosyal('google', 'g-1', nick: 'Ayse').id!;
      final misafir = db.misafir('cihaz-misafir-1').id;
      db.sonuc(misafir, kazandi: true, rakip: 1, online: false);
      db.basarimEkle(misafir, 'ilk_galibiyet');
      final altinMisafir = db.altinOku(misafir);
      final altinHesap = db.altinOku(hesap);
      expect(altinMisafir, greaterThan(0));

      final r = db.sosyal('google', 'g-1', bagla: misafir);
      expect(r.id, hesap);
      expect(r.birlesti, isTrue);
      expect(db.altinOku(hesap), altinHesap + altinMisafir);
      expect(db.testSayi('SELECT oyun FROM kullanicilar WHERE id = $hesap'), 1);
      expect(db.testSayi("SELECT COUNT(*) FROM basarimlar WHERE kullanici_id = $hesap AND basarim = 'ilk_galibiyet'"), 1);
      expect(db.testSayi('SELECT COUNT(*) FROM oyun_gecmisi WHERE kullanici_id = $hesap'), 1);
      expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $misafir'), 0);
    });

    test('e-posta girişinde misafir birleşir, bağlı hesap birleşmez', () async {
      final db = Db(':memory:');
      final hesap = db.misafir('cihaz-a').id;
      expect(await db.epostaBagla(hesap, 'a@b.com', 'sifre123'), isNull);
      final misafir = db.misafir('cihaz-b').id;
      db.sonuc(misafir, kazandi: false, rakip: 1, online: false);
      final r = (await db.epostaGiris('a@b.com', 'sifre123', misafir: misafir))!;
      expect(r.id, hesap);
      expect(r.birlesti, isTrue);
      expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $misafir'), 0);

      final baska = db.sosyal('facebook', 'f-1', nick: 'Can').id!;
      expect(db.birlestir(baska, hesap), isFalse);
      expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $baska'), 1);
    });

    test('yanlış şifrede misafir korunur; kimlik bağlıyken ikinci aynı sağlayıcı reddedilir', () async {
      final db = Db(':memory:');
      final hesap = db.sosyal('google', 'g-1', nick: 'Ayse').id!;
      final misafir = db.misafir('cihaz-c').id;
      expect(await db.epostaGiris('yok@b.com', 'x', misafir: misafir), isNull);
      expect(db.testSayi('SELECT COUNT(*) FROM kullanicilar WHERE id = $misafir'), 1);
      final r = db.sosyal('google', 'g-2', bagla: hesap);
      expect(r.hata, isNotNull);
      expect(r.token, isNull);
    });

    test('misafir aynı sağlayıcıyı ilk kez bağlarsa yeni hesap açılmaz', () {
      final db = Db(':memory:');
      final misafir = db.misafir('cihaz-d').id;
      final r = db.sosyal('google', 'g-9', bagla: misafir);
      expect(r.id, misafir);
      expect(r.birlesti, isFalse);
      expect(db.misafirMi(misafir), isFalse);
    });
  });
}
