// Emlak Deal sunucusu: odalar, WebSocket, oyun motoru burada çalışır (hakem).
// Çalıştır: dart run bin/sunucu.dart [port]
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:emlakdeal_cekirdek/aktarim.dart';
import 'package:emlakdeal_cekirdek/bot.dart';
import 'package:emlakdeal_cekirdek/cards.dart';
import 'package:emlakdeal_cekirdek/game.dart';
import 'package:emlakdeal_cekirdek/seviye.dart';

import 'db.dart';
import 'filtre.dart';
import 'yasal.dart';

final odalar = <String, Oda>{};
final liderlik = Liderlik('liderlik.json');
late final Db db;

/// Basit liderlik tablosu: ad → {oyun, galibiyet, online}. Dosyaya yazılır.
class Liderlik {
  Liderlik(this.yol) {
    try {
      final f = File(yol);
      if (f.existsSync()) tablo = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map);
    } catch (_) {}
  }
  final String yol;
  Map<String, dynamic> tablo = {};

  void kaydet(String ad, bool kazandi, {bool online = false}) {
    final a = ad.trim();
    if (a.isEmpty || a.length > 24) return;
    final e = Map<String, dynamic>.from((tablo[a] as Map?) ?? {'oyun': 0, 'galibiyet': 0, 'online': 0});
    e['oyun'] = (e['oyun'] as int) + 1;
    if (kazandi) e['galibiyet'] = (e['galibiyet'] as int) + 1;
    if (online) e['online'] = ((e['online'] as int?) ?? 0) + 1;
    e['son'] = DateTime.now().toIso8601String();
    tablo[a] = e;
    try {
      File(yol).writeAsStringSync(jsonEncode(tablo));
    } catch (e) {
      log('liderlik yazılamadı: $e');
    }
  }

  /// Hesap silinince adı tablodan çıkarır.
  void sil(String ad) {
    if (tablo.remove(ad.trim()) == null) return;
    try {
      File(yol).writeAsStringSync(jsonEncode(tablo));
    } catch (e) {
      log('liderlik yazılamadı: $e');
    }
  }

  List<Map<String, dynamic>> sirali() {
    final l = [for (final e in tablo.entries) {'ad': e.key, ...Map<String, dynamic>.from(e.value as Map)}];
    l.sort((a, b) {
      final c = (b['galibiyet'] as int).compareTo(a['galibiyet'] as int);
      return c != 0 ? c : (a['oyun'] as int).compareTo(b['oyun'] as int);
    });
    return l.take(50).toList();
  }
}
final rng = Random();

void log(String s) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)} $s');

final cevrimici = <int, Baglanti>{}; // kullanıcı id → bağlantı (davet/sıra bildirimi)

class Baglanti {
  Baglanti(this.ws);
  final WebSocket ws;
  String ad = 'Oyuncu';
  Oda? oda;
  Koltuk? koltuk;
  int? kullaniciId;
  DateTime sonSohbet = DateTime.fromMillisecondsSinceEpoch(0);
  void gonder(Map<String, dynamic> m) {
    try {
      ws.add(jsonEncode(m));
    } catch (_) {}
  }
}

/// Odadaki bir insan koltuğu (bağlantı koparsa bot devralır).
class Koltuk {
  Koltuk(this.ad, this.bag, {this.kullaniciId, this.avatar = '🙂', this.level = 1, this.ses = 0});
  String ad;
  Baglanti? bag;
  int? kullaniciId;
  String avatar;
  int level;
  int ses;
  Player? player;
  UzakKarar? karar;
  /// Bağlantı koptu ve 30 sn içinde dönmedi: yerine bot oynar (dönerse geri alır).
  bool botlasti = false;
  Timer? kopmaSayaci;
  bool hazir = false;
}

class Oda {
  Oda(this.kod, this.sahip);
  final String kod;
  Koltuk sahip;
  final List<Koltuk> koltuklar = [];
  int botSayisi = 1;
  int turSuresi = 120; // sn; 0 = kapalı
  /// Kişi başı bahis (altın); 0 = bahissiz.
  int bahis = 0;
  /// Bahisli oyun başladıysa: emanet anahtarı ve bahsi yatıran koltuklar.
  String emanetAnahtar = '';
  List<Koltuk> bahisKoltuklari = [];
  bool bahisliOyun = false;
  bool _emanetKapandi = false;
  static const bahisSecenekleri = [50, 100, 250, 500, 1000, 2500, 5000];
  String? sifre; // null = herkese açık
  Game? game;
  final Map<Player, (String, int)> botProfil = {};
  final Map<Player, int> botSes = {};
  bool mesgul = false;
  int _sonSira = -1;
  DateTime? sureBitis;
  Timer? turSayaci;
  final bot = BotDecider();
  bool botOynuyor = false;
  DateTime sozBitis = DateTime.now();

  bool get basladi => game != null;
  static const kopmaSuresi = Duration(seconds: 30);

  Koltuk? koltukOf(Player p) => koltuklar.where((k) => k.player == p).firstOrNull;

  /// Sıradaki oyuncuyu sunucu mu oynatmalı? (gerçek bot ya da botlaşmış koltuk)
  bool aktifBotMu(Game g) => g.aktif.isBot || (koltukOf(g.aktif)?.botlasti ?? false);

  List<Baglanti> get baglar => [for (final k in koltuklar) if (k.bag != null) k.bag!];

  Map<String, dynamic> lobiJson() => {
        't': 'oda',
        'kod': kod,
        'bot': botSayisi,
        'oyuncular': [for (final k in koltuklar) {'ad': k.ad, 'bagli': k.bag != null, 'hazir': k == sahip || k.hazir, 'avatar': k.avatar, 'level': k.level}],
        'sahip': sahip.ad,
        'sure': turSuresi,
        'ozel': sifre != null,
        'bahis': bahis,
      };

  void lobiYayinla() {
    for (final b in baglar) {
      b.gonder(lobiJson()..['sen'] = koltuklar.indexOf(b.koltuk!));
    }
  }

  void durumYayinla() {
    final g = game;
    if (g == null) return;
    _turDegistiMi(g);
    for (final k in koltuklar) {
      final b = k.bag;
      if (b == null || k.player == null) continue;
      b.gonder({'t': 'durum', 'd': durumJson(g, icin: k.player)..['sureBitis'] = sureBitis?.millisecondsSinceEpoch});
    }
  }

  /// Sıra bir insana geçtiyse tur sayacını başlat; süre dolunca tur otomatik biter.
  void _turDegistiMi(Game g) {
    if (g.current == _sonSira) return;
    _sonSira = g.current;
    turSayaci?.cancel();
    sureBitis = null;
    koltukOf(g.aktif)?.bag?.gonder({'t': 'siran'});
    if (turSuresi <= 0 || g.kazanan != null || aktifBotMu(g)) return;
    sureBitis = DateTime.now().add(Duration(seconds: turSuresi));
    final sira = g.current;
    turSayaci = Timer(Duration(seconds: turSuresi), () => _sureDoldu(sira));
  }

  Future<void> _sureDoldu(int sira) async {
    final g = game;
    if (g == null || g.kazanan != null || g.current != sira || aktifBotMu(g)) return;
    if (mesgul) {
      // hamle/karar bekleniyor: biraz sonra tekrar bak
      turSayaci = Timer(const Duration(seconds: 3), () => _sureDoldu(sira));
      return;
    }
    mesgul = true;
    try {
      herkese({'t': 'bilgi', 'm': '${g.aktif.name} süresi doldu, tur geçti.'});
      await g.turBitir(sureDoldu: true);
    } catch (e) {
      log('süre dolunca tur bitirilemedi: $e');
    } finally {
      mesgul = false;
    }
    durumYayinla();
    bitisKontrol();
    if (g.kazanan == null && aktifBotMu(g)) unawaited(botKontrol());
  }

  void herkese(Map<String, dynamic> m) {
    for (final b in baglar) {
      b.gonder(m);
    }
  }

  /// Gönderen kullanıcıyı engellemiş olanlara iletmez; diğerleri alır.
  void herkeseKimden(Map<String, dynamic> m, int? gonderen) {
    for (final b in baglar) {
      final alici = b.kullaniciId;
      if (gonderen != null && alici != null && alici != gonderen && db.engelliMi(alici, gonderen)) continue;
      b.gonder(m);
    }
  }

  Future<void> basla() async {
    final toplam = koltuklar.length + botSayisi;
    if (toplam < 2 || toplam > 5) throw 'Oyuncu sayısı 2-5 olmalı (şu an $toplam)';
    final hazirDegil = koltuklar.where((k) => k != sahip && k.bag != null && !k.hazir).map((k) => k.ad).toList();
    if (hazirDegil.isNotEmpty) throw 'Hazır değil: ${hazirDegil.join(', ')}';
    if (bahis > 0) {
      if (koltuklar.length < 2) throw 'Online oyun için en az 2 gerçek oyuncu gerekir.';
      final idler = [for (final k in koltuklar) k.kullaniciId ?? -1];
      if (idler.contains(-1)) throw 'Online oyun için herkesin giriş yapmış olması gerekir.';
      emanetAnahtar = '$kod#${DateTime.now().millisecondsSinceEpoch}';
      final eksik = db.bahisKes(idler, bahis, emanetAnahtar);
      if (eksik != null) {
        final k = koltuklar.firstWhere((x) => x.kullaniciId == eksik);
        throw '${k.ad} için yeterli altın yok ($bahis gerekli).';
      }
      bahisliOyun = true;
      _emanetKapandi = false;
      bahisKoltuklari = List.of(koltuklar);
      for (final k in koltuklar) {
        k.bag?.gonder({'t': 'bahisKesildi', 'bahis': bahis, 'profil': db.profil(k.kullaniciId!)});
      }
    }
    try {
      await _baslaOyun();
    } catch (e) {
      if (bahisliOyun) bahisIptal();
      rethrow;
    }
  }

  /// Oyun başlamadan ya da yarıda iptal olduysa tüm bahisleri iade eder.
  void bahisIptal() {
    if (!bahisliOyun || _emanetKapandi) return;
    _emanetKapandi = true;
    for (final k in bahisKoltuklari) {
      final id = k.kullaniciId;
      if (id == null) continue;
      db.emanetIade(emanetAnahtar, id);
      k.bag?.gonder({'t': 'bahisIade', 'profil': db.profil(id)});
    }
    bahisliOyun = false;
    log('oda $kod: bahisler iade edildi');
  }

  Future<void> _baslaOyun() async {
    final players = <Player>[];
    for (final k in koltuklar) {
      k.karar = UzakKarar(this, k);
      k.player = Player(k.ad, isBot: false, decider: k.karar!);
      players.add(k.player!);
    }
    final adlar = List.of(botAdlari)..shuffle(rng);
    final kullanilan = {for (final k in koltuklar) k.ad.toLowerCase()};
    for (var i = 1; i <= botSayisi; i++) {
      var ad = adlar.removeAt(0);
      while (kullanilan.contains(ad.toLowerCase())) {
        ad = adlar.removeAt(0);
      }
      final p = Player(ad, isBot: true, decider: bot);
      botProfil[p] = (avatarlar[rng.nextInt(avatarlar.length)], 1 + rng.nextInt(12));
      players.add(p);
    }
    final botlar = [for (final p in players) if (p.isBot) p];
    final sesler = botSesleri([for (final p in botlar) p.name], [for (final k in koltuklar) k.ses], rng);
    for (var i = 0; i < botlar.length; i++) {
      botSes[botlar[i]] = sesler[i];
    }
    final g = Game(players: players);
    game = g;
    g.addListener(durumYayinla);
    g.animator = (e) async {
      herkese({'t': 'olay', 'o': olayJson(g, e)});
      // istemciler kendi animasyonlarını oynatırken sunucu kısa bekler
      final insan = e.kim != null && !e.kim!.isBot;
      await Future.delayed(Duration(milliseconds: e.tip == EvTip.aksiyon ? (insan ? 900 : 1500) : (insan ? 350 : 550)));
    };
    g.sozcu = (p, soz) async {
      herkeseKimden({'t': 'soz', 'kim': players.indexOf(p), 'soz': soz}, koltukOf(p)?.kullaniciId);
      // konuşma süresi tahmini: hamle hemen devam eder, bir sonraki hamle bunu bekler
      final sure = Duration(milliseconds: 600 + soz.length * 55);
      final simdi = DateTime.now();
      final bas = sozBitis.isAfter(simdi) ? sozBitis : simdi;
      sozBitis = bas.add(sure);
    };
    g.sozBekle = () async {
      final kalan = sozBitis.difference(DateTime.now());
      if (kalan > Duration.zero) await Future.delayed(kalan);
    };
    for (final k in koltuklar) {
      k.bag?.gonder(basladiJson(players.indexOf(k.player!)));
    }
    log('oda $kod başladı: ${players.map((p) => p.name).join(', ')}');
    await g.baslat();
    durumYayinla();
    unawaited(botKontrol());
  }

  /// Oyuncu profilleri (nick/avatar/level) ile başlangıç mesajı.
  Map<String, dynamic> basladiJson(int sen) {
    final g = game!;
    (String, int) profil(Player p) {
      final k = koltukOf(p);
      if (k != null) return (k.avatar, k.level);
      return botProfil[p] ?? ('🤖', 1);
    }
    return {
      't': 'basladi',
      'sen': sen,
      'bahis': bahisliOyun ? bahis : 0,
      'havuz': bahisliOyun ? bahis * bahisKoltuklari.length : 0,
      'adlar': [for (final p in g.players) p.name],
      'botlar': [for (final p in g.players) p.isBot],
      'avatarlar': [for (final p in g.players) profil(p).$1],
      'leveller': [for (final p in g.players) profil(p).$2],
      'sesler': [for (final p in g.players) koltukOf(p)?.ses ?? botSes[p] ?? 0],
    };
  }

  Future<void> botKontrol() async {
    final g = game;
    if (g == null || botOynuyor) return;
    botOynuyor = true;
    mesgul = true;
    try {
      while (g.kazanan == null && aktifBotMu(g)) {
        await bot.turOyna(g, g.aktif);
      }
    } catch (e, st) {
      log('bot hatası: $e\n$st');
    } finally {
      botOynuyor = false;
      mesgul = false;
    }
    durumYayinla();
    bitisKontrol();
  }

  bool _bittiBildirildi = false;
  void bitisKontrol() {
    final g = game;
    if (g?.kazanan != null && !_bittiBildirildi) {
      _bittiBildirildi = true;
      turSayaci?.cancel();
      herkese({'t': 'bitti', 'kazanan': g!.players.indexOf(g.kazanan!)});
      log('oda $kod bitti: ${g.kazanan!.name}');
      final bahisli = bahisliOyun && !_emanetKapandi;
      final havuz = bahisli ? bahis * bahisKoltuklari.length : 0;
      final kazK = koltukOf(g.kazanan!);
      // botlaşmış (oyundan düşmüş) koltuk kazansa da gerçek kazanan sayılmaz
      final insanKazandi = kazK != null && !kazK.botlasti && kazK.kullaniciId != null;
      if (bahisli) {
        _emanetKapandi = true;
        try {
          if (insanKazandi) {
            db.emanetOde(emanetAnahtar, kazK.kullaniciId!, havuz);
          } else {
            for (final k in bahisKoltuklari) {
              final id = k.kullaniciId;
              if (id == null) continue;
              if (k.botlasti) {
                db.emanetKayip(emanetAnahtar, id);
              } else {
                db.emanetIade(emanetAnahtar, id);
              }
            }
          }
        } catch (e) {
          log('bahis dağıtılamadı: $e');
        }
      }
      for (final k in koltuklar) {
        if (k.player == null) continue;
        final kazandi = k.player == g.kazanan && !k.botlasti;
        liderlik.kaydet(k.ad, kazandi, online: true);
        final kid = k.kullaniciId;
        if (kid != null) {
          try {
            final r = db.sonuc(kid, kazandi: kazandi, rakip: g.players.length - 1, online: true, altinVer: !bahisli, bahisli: bahisli);
            final yattiriyor = bahisli && bahisKoltuklari.contains(k);
            var net = 0;
            var sonuc = kazandi ? 'kazandin' : 'kaybettin';
            if (yattiriyor) {
              if (insanKazandi) {
                net = kazandi ? havuz - bahis : -bahis;
              } else if (k.botlasti) {
                net = -bahis;
                sonuc = 'terk';
              } else {
                sonuc = 'iade';
              }
            }
            k.bag?.gonder({
              't': 'odul',
              'xp': r['xp'],
              'altin': r['altin'],
              'level': r['level'],
              'levelAtladi': r['levelAtladi'],
              'limitDoldu': r['limitDoldu'],
              'bahis': bahisli ? bahis : 0,
              'havuz': havuz,
              'net': net,
              'sonuc': sonuc,
              'profil': db.profil(kid),
            });
          } catch (e) {
            log('ödül yazılamadı: $e');
          }
        }
      }
      bahisliOyun = false;
    }
  }

  /// İnsan hamlesi (istemciden gelen).
  Future<void> hamle(Koltuk k, Map<String, dynamic> m) async {
    final g = game;
    final p = k.player;
    if (g == null || p == null) return;
    if (g.aktif != p) {
      k.bag?.gonder({'t': 'hata', 'm': 'Sıra sende değil.'});
      return;
    }
    GameCard? kart(String alan) => m[alan] == null ? null : kartBul(g, m[alan] as int);
    Player? oyuncu(String alan) => m[alan] == null ? null : g.players[m[alan] as int];
    PColor? renk(String alan) => m[alan] == null ? null : PColor.values[m[alan] as int];
    final tip = m['tip'] as String;
    if (mesgul) {
      k.bag?.gonder({'t': 'hata', 'm': 'Önceki hamle sürüyor, bekle.'});
      return;
    }
    mesgul = true;
    try {
      switch (tip) {
        case 'mulk':
          await g.mulkOyna(p, kart('kart')!);
        case 'joker':
          await g.jokerRengiDegistir(p, kart('kart')!);
        case 'banka':
          await g.bankayaKoy(p, kart('kart')!);
        case 'passGo':
          await g.passGo(p, kart('kart')!);
        case 'tahsilat':
          await g.tahsilat(p, kart('kart')!, oyuncu('hedef')!);
        case 'dogumGunu':
          await g.dogumGunu(p, kart('kart')!);
        case 'kira':
          await g.kiraOyna(p, kart('kart')!, renk('renk')!, cift: kart('cift'));
        case 'slyDeal':
          await g.slyDeal(p, kart('kart')!, kart('hedefKart')!);
        case 'forcedDeal':
          await g.forcedDeal(p, kart('kart')!, kart('benim')!, kart('onun')!);
        case 'dealBreaker':
          await g.dealBreaker(p, kart('kart')!, oyuncu('hedef')!, renk('set')!);
        case 'bina':
          await g.binaKoy(p, kart('kart')!, renk('set')!);
        case 'turBitir':
          await g.turBitir();
        default:
          k.bag?.gonder({'t': 'hata', 'm': 'Bilinmeyen hamle: $tip'});
      }
    } catch (e, st) {
      log('hamle hatası ($tip): $e\n$st');
      k.bag?.gonder({'t': 'hata', 'm': 'Hamle yapılamadı: $e'});
    } finally {
      mesgul = false;
    }
    durumYayinla();
    bitisKontrol();
    if (g.kazanan == null && aktifBotMu(g)) unawaited(botKontrol());
  }
}

/// İnsan oyuncunun kararları ağ üzerinden sorulur; cevap gelmezse bot karar verir.
class UzakKarar extends Decider {
  UzakKarar(this.oda, this.koltuk);
  final Oda oda;
  final Koltuk koltuk;
  final _bekleyen = <int, Completer<dynamic>>{};
  int _sayac = 0;

  Future<dynamic> _sor(String tur, Map<String, dynamic> veri) async {
    final b = koltuk.bag;
    if (b == null) return null;
    final id = ++_sayac;
    final c = Completer<dynamic>();
    _bekleyen[id] = c;
    b.gonder({'t': 'sor', 'id': id, 'tur': tur, ...veri});
    try {
      return await c.future.timeout(Duration(seconds: oda.turSuresi > 0 ? oda.turSuresi.clamp(20, 120) : 120));
    } catch (_) {
      return null;
    } finally {
      _bekleyen.remove(id);
    }
  }

  void cevap(int id, dynamic deger) => _bekleyen[id]?.complete(deger);

  List<GameCard> _kartlar(Game g, dynamic l) => [for (final id in (l as List)) kartBul(g, id as int)].whereType<GameCard>().toList();

  @override
  Future<bool> justSayNo(Game g, Player me, String aciklama) async {
    final r = await _sor('justSayNo', {'aciklama': aciklama});
    return r is bool ? r : await oda.bot.justSayNo(g, me, aciklama);
  }

  @override
  Future<List<GameCard>> ode(Game g, Player me, int tutar, Player alacakli) async {
    final r = await _sor('ode', {'tutar': tutar, 'alacakli': g.players.indexOf(alacakli)});
    if (r is List) return _kartlar(g, r);
    return oda.bot.ode(g, me, tutar, alacakli);
  }

  @override
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama, {required bool reddedebilir}) async {
    final r = await _sor('odemeKarari', {'tutar': tutar, 'alacakli': g.players.indexOf(alacakli), 'aciklama': aciklama, 'reddedebilir': reddedebilir});
    if (r is Map) {
      if (r['reddet'] == true) return OdemeKarari.reddet();
      return OdemeKarari.ode(_kartlar(g, r['kartlar']));
    }
    return oda.bot.odemeKarari(g, me, tutar, alacakli, aciklama, reddedebilir: reddedebilir);
  }

  @override
  Future<PColor?> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler) async {
    if (secenekler.length == 1) return secenekler.first;
    final r = await _sor('jokerRengi', {'kart': joker.id, 'secenekler': [for (final c in secenekler) c.index]});
    if (r == -1) return null;
    if (r is int && r >= 0 && r < PColor.values.length && secenekler.contains(PColor.values[r])) return PColor.values[r];
    return oda.bot.jokerRengi(g, me, joker, secenekler);
  }

  @override
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet) async {
    final r = await _sor('atilacaklar', {'adet': adet});
    if (r is List && r.length == adet) return _kartlar(g, r);
    return oda.bot.atilacaklar(g, me, adet);
  }
}

String yeniKod() {
  const h = 'ABCDEFGHJKLMNPRSTUVYZ';
  while (true) {
    final k = List.generate(4, (_) => h[rng.nextInt(h.length)]).join();
    if (!odalar.containsKey(k)) return k;
  }
}

/// Online oda işlemleri girişli (misafir olmayan) hesap ister.
bool _onlineIzni(Baglanti b, Map<String, dynamic> m) {
  final id = db.oturumKim(m['token'] as String?);
  if (id != null && !db.misafirMi(id)) return true;
  b.gonder({'t': 'hata', 'm': 'Online oyun için giriş yapmalısın.', 'giris': true});
  return false;
}

void mesaj(Baglanti b, Map<String, dynamic> m) {
  final t = m['t'] as String?;
  switch (t) {
    case 'kur':
      if (!_onlineIzni(b, m)) return;
      final pr = _profilden(m);
      b.ad = pr.ad;
      if (pr.id != null) {
        b.kullaniciId = pr.id;
        cevrimici[pr.id!] = b;
      }
      final oda = Oda(yeniKod(), Koltuk(b.ad, b, kullaniciId: pr.id, avatar: pr.avatar, level: pr.level, ses: pr.ses));
      oda.koltuklar.add(oda.sahip);
      oda.botSayisi = ((m['bot'] as int?) ?? 1).clamp(0, 3);
      final bh = (m['bahis'] as int?) ?? 0;
      if (!Oda.bahisSecenekleri.contains(bh)) {
        b.gonder({'t': 'hata', 'm': 'Oda tutarı seçmelisin.'});
        return;
      }
      if (pr.id != null && db.altinOku(pr.id!) < bh) {
        b.gonder({'t': 'hata', 'm': 'Bu oda için yeterli altının yok ($bh gerekli).'});
        return;
      }
      oda.bahis = bh;
      final sf = (m['sifre'] as String? ?? '').trim();
      if (sf.isNotEmpty) oda.sifre = sf.length > 20 ? sf.substring(0, 20) : sf;
      odalar[oda.kod] = oda;
      b.oda = oda;
      b.koltuk = oda.sahip;
      log('oda ${oda.kod} kuruldu (${b.ad}, bot ${oda.botSayisi})');
      oda.lobiYayinla();
    case 'katil':
      if (!_onlineIzni(b, m)) return;
      final kod = (m['oda'] as String? ?? '').toUpperCase().trim();
      final oda = odalar[kod];
      if (oda == null) {
        b.gonder({'t': 'hata', 'm': 'Oda bulunamadı: $kod'});
        return;
      }
      if (oda.sifre != null && (m['sifre'] as String? ?? '').trim() != oda.sifre) {
        b.gonder({'t': 'hata', 'm': (m['sifre'] as String? ?? '').isEmpty ? 'Bu oda özel, şifre gerekli.' : 'Şifre yanlış.', 'sifre': true});
        return;
      }
      final pr = _profilden(m);
      b.ad = pr.ad;
      if (pr.id != null) {
        b.kullaniciId = pr.id;
        cevrimici[pr.id!] = b;
      }
      // aynı adla kopan koltuğa geri dön
      final eski = oda.koltuklar.where((k) => k.bag == null && k.ad == b.ad).firstOrNull;
      if (eski != null) {
        eski.bag = b;
        eski.kopmaSayaci?.cancel();
        eski.kopmaSayaci = null;
        final botIdi = eski.botlasti;
        eski.botlasti = false;
        b.oda = oda;
        b.koltuk = eski;
        log('oda $kod: ${b.ad} geri döndü');
        if (oda.basladi) oda.herkese({'t': 'bilgi', 'm': botIdi ? '${b.ad} geri döndü, yeniden kendisi oynuyor.' : '${b.ad} geri döndü.'});
        if (oda.basladi) {
          final g = oda.game!;
          b.gonder(oda.basladiJson(g.players.indexOf(eski.player!)));
          oda.durumYayinla();
        } else {
          oda.lobiYayinla();
        }
        return;
      }
      if (oda.basladi) {
        b.gonder({'t': 'hata', 'm': 'Oyun başlamış.'});
        return;
      }
      if (oda.koltuklar.length + oda.botSayisi >= 5) {
        b.gonder({'t': 'hata', 'm': 'Oda dolu (en çok 5 oyuncu).'});
        return;
      }
      if (oda.bahis > 0 && (pr.id == null || db.altinOku(pr.id!) < oda.bahis)) {
        b.gonder({'t': 'hata', 'm': 'Bu oda ${oda.bahis} altınlık, yeterli altının yok.'});
        return;
      }
      if (oda.koltuklar.any((k) => k.ad == b.ad)) b.ad = '${b.ad} ${oda.koltuklar.length + 1}';
      final k = Koltuk(b.ad, b, kullaniciId: pr.id, avatar: pr.avatar, level: pr.level, ses: pr.ses);
      oda.koltuklar.add(k);
      b.oda = oda;
      b.koltuk = k;
      log('oda $kod: ${b.ad} katıldı');
      oda.lobiYayinla();
    case 'bot':
      final oda = b.oda;
      if (oda == null || oda.sahip != b.koltuk || oda.basladi) return;
      oda.botSayisi = ((m['bot'] as int?) ?? 1).clamp(0, 3);
      oda.lobiYayinla();
    case 'sure':
      final oda = b.oda;
      if (oda == null || oda.sahip != b.koltuk || oda.basladi) return;
      oda.turSuresi = ((m['sure'] as int?) ?? 120).clamp(0, 180);
      oda.lobiYayinla();
    case 'bahis':
      final oda = b.oda;
      if (oda == null || oda.sahip != b.koltuk || oda.basladi) return;
      final bh = (m['bahis'] as int?) ?? 0;
      if (!Oda.bahisSecenekleri.contains(bh)) return;
      final sid = b.kullaniciId;
      if (bh > 0 && sid != null && db.altinOku(sid) < bh) {
        b.gonder({'t': 'hata', 'm': 'Bu oda tutarı için yeterli altının yok ($bh gerekli).'});
        return;
      }
      oda.bahis = bh;
      for (final k in oda.koltuklar) {
        if (k != oda.sahip) k.hazir = false;
      }
      oda.herkese({'t': 'bilgi', 'm': 'Oda tutarı $bh altın oldu, herkes yeniden hazır olmalı.'});
      oda.lobiYayinla();
    case 'hazir':
      final oda = b.oda;
      final k = b.koltuk;
      if (oda == null || k == null || oda.basladi) return;
      k.hazir = (m['hazir'] as bool?) ?? true;
      if (k.hazir && oda.bahis > 0 && k.kullaniciId != null && db.altinOku(k.kullaniciId!) < oda.bahis) {
        k.hazir = false;
        b.gonder({'t': 'hata', 'm': 'Bu oda ${oda.bahis} altınlık, yeterli altının yok.'});
      }
      oda.lobiYayinla();
    case 'basla':
      final oda = b.oda;
      if (oda == null || oda.sahip != b.koltuk || oda.basladi) return;
      oda.basla().catchError((e) {
        b.gonder({'t': 'hata', 'm': '$e'});
        oda.game = null;
      });
    case 'hamle':
      final oda = b.oda;
      final k = b.koltuk;
      if (oda == null || k == null) return;
      unawaited(oda.hamle(k, m));
    case 'karar':
      b.koltuk?.karar?.cevap(m['id'] as int, m['deger']);
    case 'sohbet':
      final oda = b.oda;
      final k = b.koltuk;
      var soz = (m['soz'] as String? ?? '').trim();
      if (oda == null || k == null || soz.isEmpty || soz.length > 80) return;
      if (DateTime.now().difference(b.sonSohbet) < const Duration(milliseconds: 700)) return; // hız sınırı
      b.sonSohbet = DateTime.now();
      soz = sansurle(soz);
      final g = oda.game;
      final kim = g == null || k.player == null ? -1 : g.players.indexOf(k.player!);
      oda.herkeseKimden({'t': 'sohbet', 'kim': kim, 'ad': k.ad, 'soz': soz}, k.kullaniciId);
    case 'kimlik':
      // menüde açık tutulan bağlantı: davet ve bildirim için çevrim içi kaydı
      final id = db.oturumKim(m['token'] as String?);
      if (id != null && !db.misafirMi(id)) {
        b.kullaniciId = id;
        cevrimici[id] = b;
        b.gonder({'t': 'kimlik', 'ok': true});
      } else {
        b.gonder({'t': 'kimlik', 'ok': false});
      }
    case 'davet':
      final oda = b.oda;
      final hedef = db.idBul(m['nick'] as String? ?? '');
      if (oda == null || hedef == null) {
        b.gonder({'t': 'bilgi', 'm': 'Davet gönderilemedi.'});
        return;
      }
      final ben = b.kullaniciId;
      if (ben != null && db.engelliMi(hedef, ben)) {
        b.gonder({'t': 'bilgi', 'm': 'Bu oyuncuya istek gönderemezsin.'});
        return;
      }
      if (ben != null && db.engelliMi(ben, hedef)) {
        b.gonder({'t': 'bilgi', 'm': 'Önce engeli kaldırmalısın.'});
        return;
      }
      final hb = cevrimici[hedef];
      if (hb == null || hb.ws.readyState != WebSocket.open) {
        b.gonder({'t': 'bilgi', 'm': '${m['nick']} şu an çevrim içi değil.'});
        return;
      }
      hb.gonder({'t': 'davet', 'kim': b.ad, 'oda': oda.kod});
      b.gonder({'t': 'bilgi', 'm': '${m['nick']} davet edildi.'});
    case 'liste':
      b.gonder({
        't': 'odalar',
        'liste': [
          for (final o in odalar.values)
            if (!o.basladi) {'kod': o.kod, 'sahip': o.sahip.ad, 'oyuncu': o.koltuklar.length, 'bot': o.botSayisi, 'sure': o.turSuresi, 'ozel': o.sifre != null, 'bahis': o.bahis}
        ],
      });
    case 'ping':
      b.gonder({'t': 'pong'});
    default:
      b.gonder({'t': 'hata', 'm': 'Bilinmeyen mesaj: $t'});
  }
}

/// WS mesajındaki token'dan profil; token yoksa mesajdaki ad ile misafir.
({int? id, String ad, String avatar, int level, int ses}) _profilden(Map<String, dynamic> m) {
  final id = db.oturumKim(m['token'] as String?);
  if (id != null) {
    final p = db.profil(id);
    return (id: id, ad: p['nick'] as String, avatar: p['avatar'] as String, level: p['level'] as int, ses: (p['ses'] as int?) ?? 0);
  }
  final ad = (m['ad'] as String?)?.trim().isNotEmpty == true ? (m['ad'] as String).trim() : 'Oyuncu';
  return (id: null, ad: ad.toLowerCase() == 'sen' ? 'Oyuncu' : ad, avatar: '🙂', level: 1, ses: 0);
}

void kopti(Baglanti b) {
  final kid = b.kullaniciId;
  if (kid != null && cevrimici[kid] == b) cevrimici.remove(kid);
  final oda = b.oda;
  final k = b.koltuk;
  if (oda == null || k == null) return;
  k.bag = null;
  log('oda ${oda.kod}: ${k.ad} koptu');
  if (!oda.basladi) {
    oda.koltuklar.remove(k);
    if (oda.koltuklar.isEmpty) {
      odalar.remove(oda.kod);
      log('oda ${oda.kod} kapandı');
      return;
    }
    if (oda.sahip == k) oda.sahip = oda.koltuklar.first;
    oda.lobiYayinla();
  } else {
    // oyun sürüyor: 30 sn geri dönüş süresi; dönmezse yerine bot oynar (dönerse devralır)
    if (oda.baglar.isEmpty) {
      oda.bahisIptal();
      odalar.remove(oda.kod);
      log('oda ${oda.kod} boşaldı, kapandı');
      return;
    }
    oda.herkese({'t': 'bilgi', 'm': '${k.ad} bağlantısı koptu, 30 sn bekleniyor…'});
    k.kopmaSayaci?.cancel();
    k.kopmaSayaci = Timer(Oda.kopmaSuresi, () {
      if (k.bag != null || !odalar.containsKey(oda.kod)) return;
      k.botlasti = true;
      log('oda ${oda.kod}: ${k.ad} dönmedi, bot devraldı');
      oda.herkese({'t': 'bilgi', 'm': '${k.ad} geri dönmedi, yerine bot oynuyor.'});
      final g = oda.game;
      if (g != null && g.kazanan == null && oda.aktifBotMu(g)) unawaited(oda.botKontrol());
    });
  }
}

/// Sertifika varsa (Let's Encrypt) TLS portunu da açar: wss://emlakdeal.duckdns.org:8766
const sertifikaDizini = '/etc/letsencrypt/live/emlakdeal.duckdns.org';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8765;
  final tlsPort = args.length > 1 ? int.parse(args[1]) : 8766;
  db = Db('emlakdeal.db');
  db.eskiKayitlariTemizle();
  final iade = db.acikEmanetleriIadeEt();
  if (iade > 0) log('yarım kalan $iade bahis iade edildi');
  Timer.periodic(const Duration(hours: 24), (_) => db.eskiKayitlariTemizle());
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  log('Emlak Deal sunucusu dinliyor: ws://0.0.0.0:$port');
  final zincir = File('$sertifikaDizini/fullchain.pem'), anahtar = File('$sertifikaDizini/privkey.pem');
  if (zincir.existsSync() && anahtar.existsSync()) {
    try {
      final ctx = SecurityContext()
        ..useCertificateChain(zincir.path)
        ..usePrivateKey(anahtar.path);
      final tls = await HttpServer.bindSecure(InternetAddress.anyIPv4, tlsPort, ctx);
      log('TLS dinliyor: wss://0.0.0.0:$tlsPort');
      unawaited(_dinle(tls));
    } catch (e) {
      log('TLS açılamadı: $e');
    }
  } else {
    log('sertifika yok ($sertifikaDizini), yalnız düz ws');
  }
  await _dinle(server);
}

final _girisHatalari = <String, List<DateTime>>{};
/// Virgülle ayrılmış liste: Web istemcisi + iOS istemcisi (iOS'ta id_token'ın aud alanı iOS istemci kimliğidir).
final _googleIstemciler = (Platform.environment['EMLAKDEAL_GOOGLE_CLIENT_ID'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
final _facebookUygulama = Platform.environment['EMLAKDEAL_FACEBOOK_APP_ID'] ?? '';

Future<Map<String, dynamic>?> _jsonGet(String url) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final y = await (await c.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 10));
    final j = jsonDecode(await y.transform(utf8.decoder).join());
    return y.statusCode == 200 && j is Map ? j.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  } finally {
    c.close(force: true);
  }
}

final _appleIstemci = Platform.environment['EMLAKDEAL_APPLE_CLIENT_ID'] ?? 'com.soner.emlakdeal';
final _jwksOnbellek = <String, ({List<dynamic> anahtarlar, DateTime zaman})>{};

BigInt _bigOku(List<int> b) => b.fold(BigInt.zero, (a, x) => (a << 8) | BigInt.from(x));

/// RS256 JWT: imza sağlayıcının yayımladığı anahtarlarla (JWKS), iss/aud/exp kontrol edilir. Geçerliyse yük döner.
Future<Map<String, dynamic>?> _jwtDogrula(String jwt, {required String jwksUrl, required Set<String> issler, required String aud}) async {
  try {
    final p = jwt.split('.');
    if (p.length != 3) return null;
    Map<String, dynamic> coz(String s) => (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(s)))) as Map).cast<String, dynamic>();
    final baslik = coz(p[0]), yuk = coz(p[1]);
    if (baslik['alg'] != 'RS256') return null;
    if (!issler.contains(yuk['iss']) || yuk['aud'] != aud) return null;
    if (((yuk['exp'] as num) * 1000).toInt() < DateTime.now().millisecondsSinceEpoch) return null;
    var onbellek = _jwksOnbellek[jwksUrl];
    if (onbellek == null || DateTime.now().difference(onbellek.zaman) > const Duration(hours: 1) || !onbellek.anahtarlar.any((k) => k['kid'] == baslik['kid'])) {
      final j = await _jsonGet(jwksUrl);
      if (j == null) return null;
      onbellek = (anahtarlar: j['keys'] as List, zaman: DateTime.now());
      _jwksOnbellek[jwksUrl] = onbellek;
    }
    final k = onbellek.anahtarlar.cast<Map>().firstWhere((k) => k['kid'] == baslik['kid'], orElse: () => const {});
    if (k.isEmpty) return null;
    final n = _bigOku(base64Url.decode(base64Url.normalize(k['n'] as String)));
    final e = _bigOku(base64Url.decode(base64Url.normalize(k['e'] as String)));
    final imza = base64Url.decode(base64Url.normalize(p[2]));
    final uzunluk = (n.bitLength + 7) ~/ 8;
    if (imza.length != uzunluk) return null;
    var m = _bigOku(imza).modPow(e, n);
    final em = List<int>.filled(uzunluk, 0);
    for (var i = uzunluk - 1; i >= 0; i--) {
      em[i] = (m & BigInt.from(0xff)).toInt();
      m >>= 8;
    }
    const onek = [0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20];
    final ozet = sha256.convert(utf8.encode('${p[0]}.${p[1]}')).bytes;
    final beklenen = <int>[0, 1, ...List.filled(uzunluk - 3 - onek.length - ozet.length, 0xff), 0, ...onek, ...ozet];
    if (beklenen.length != em.length) return null;
    var fark = 0;
    for (var i = 0; i < em.length; i++) {
      fark |= em[i] ^ beklenen[i];
    }
    return fark == 0 ? yuk : null;
  } catch (_) {
    return null;
  }
}

/// Sağlayıcının verdiği token'ı sağlayıcıya sorarak doğrular; kimlik (sub / user id) döner.
Future<({String? kimlik, String? ad, String? hata})> _sosyalDogrula(String saglayici, String token) async {
  if (token.isEmpty) return (kimlik: null, ad: null, hata: 'Token yok.');
  if (saglayici == 'google') {
    if (_googleIstemciler.isEmpty) return (kimlik: null, ad: null, hata: 'yapılandırılmadı: Google girişi sunucuda henüz ayarlanmadı.');
    final j = await _jsonGet('https://oauth2.googleapis.com/tokeninfo?id_token=${Uri.encodeQueryComponent(token)}');
    if (j == null || !_googleIstemciler.contains(j['aud']) || j['sub'] == null) return (kimlik: null, ad: null, hata: 'Google girişi doğrulanamadı.');
    return (kimlik: '${j['sub']}', ad: (j['given_name'] ?? j['name']) as String?, hata: null);
  }
  if (saglayici == 'facebook') {
    if (_facebookUygulama.isEmpty) return (kimlik: null, ad: null, hata: 'yapılandırılmadı: Facebook girişi sunucuda henüz ayarlanmadı.');
    // iOS'ta Limited Login: token Graph erişim token'ı değil, Facebook'un imzaladığı OIDC JWT'sidir.
    if (token.split('.').length == 3) {
      final y = await _jwtDogrula(token,
          jwksUrl: 'https://limited.facebook.com/.well-known/oauth/openid/jwks/',
          issler: {'https://www.facebook.com', 'https://facebook.com', 'https://limited.facebook.com'},
          aud: _facebookUygulama);
      if (y == null || y['sub'] == null) return (kimlik: null, ad: null, hata: 'Facebook girişi doğrulanamadı.');
      return (kimlik: '${y['sub']}', ad: (y['given_name'] ?? y['name']) as String?, hata: null);
    }
    final t = Uri.encodeQueryComponent(token);
    final app = await _jsonGet('https://graph.facebook.com/app?access_token=$t');
    if (app == null || '${app['id']}' != _facebookUygulama) return (kimlik: null, ad: null, hata: 'Facebook girişi doğrulanamadı.');
    final me = await _jsonGet('https://graph.facebook.com/me?fields=id,first_name&access_token=$t');
    if (me == null || me['id'] == null) return (kimlik: null, ad: null, hata: 'Facebook girişi doğrulanamadı.');
    return (kimlik: '${me['id']}', ad: me['first_name'] as String?, hata: null);
  }
  if (saglayici == 'apple') {
    final y = await _jwtDogrula(token, jwksUrl: 'https://appleid.apple.com/auth/keys', issler: {'https://appleid.apple.com'}, aud: _appleIstemci);
    if (y == null || y['sub'] == null) return (kimlik: null, ad: null, hata: 'Apple girişi doğrulanamadı.');
    return (kimlik: '${y['sub']}', ad: null, hata: null);
  }
  return (kimlik: null, ad: null, hata: 'Bilinmeyen sağlayıcı.');
}

final _yonetimAnahtar = Platform.environment['YONETIM_ANAHTAR'] ?? '';
final _fbUygulamaSirri = Platform.environment['FB_APP_SECRET'] ?? '';
const _govdeSiniri = 64 * 1024;

class _GovdeCokBuyuk implements Exception {}

/// Gövdeyi en çok [_govdeSiniri] bayt okur; aşarsa _GovdeCokBuyuk.
Future<String> _govdeOku(HttpRequest req) async {
  if (req.contentLength > _govdeSiniri) throw _GovdeCokBuyuk();
  final b = BytesBuilder(copy: false);
  await for (final parca in req) {
    b.add(parca);
    if (b.length > _govdeSiniri) throw _GovdeCokBuyuk();
  }
  return utf8.decode(b.takeBytes(), allowMalformed: true);
}

/// İstemci IP'si: yerel/özel ağdan gelen istekte (ters vekil) X-Forwarded-For'un ilk adresi.
String _ip(HttpRequest req) {
  final a = req.connectionInfo?.remoteAddress;
  if (a == null) return '?';
  if (a.isLoopback || a.isLinkLocal || a.address.startsWith('10.') || a.address.startsWith('192.168.') || a.address.startsWith('172.') || a.address.startsWith('100.')) {
    final x = req.headers.value('x-forwarded-for');
    if (x != null && x.trim().isNotEmpty) return x.split(',').first.trim();
  }
  return a.address;
}

final _oranKayit = <String, List<DateTime>>{};

/// Dakikada [sinir] istek; aşılırsa false.
bool _oranIzin(String ad, String ip, {int sinir = 30}) {
  final simdi = DateTime.now();
  if (_oranKayit.length > 2000) {
    _oranKayit.removeWhere((_, l) => l.isEmpty || simdi.difference(l.last).inSeconds > 60);
  }
  final l = (_oranKayit['$ad|$ip'] ??= []);
  l.removeWhere((t) => simdi.difference(t).inSeconds >= 60);
  if (l.length >= sinir) return false;
  l.add(simdi);
  return true;
}

String? _str(Object? v, [int n = 500]) => v is String ? (v.length > n ? v.substring(0, n) : v) : null;

bool _anahtarDogru(String? verilen) {
  if (_yonetimAnahtar.isEmpty || verilen == null) return false;
  final a = utf8.encode(verilen), b = utf8.encode(_yonetimAnahtar);
  var fark = a.length ^ b.length;
  for (var i = 0; i < b.length; i++) {
    fark |= (i < a.length ? a[i] : 0) ^ b[i];
  }
  return fark == 0;
}

List<int>? _b64urlCoz(String s) {
  try {
    return base64Url.decode(base64Url.normalize(s));
  } catch (_) {
    return null;
  }
}

/// Facebook signed_request doğrulaması; geçerliyse user_id döner.
String? _fbKullanici(String signedRequest) {
  final p = signedRequest.split('.');
  if (p.length != 2) return null;
  final imza = _b64urlCoz(p[0]), yuk = _b64urlCoz(p[1]);
  if (imza == null || yuk == null) return null;
  final beklenen = Hmac(sha256, utf8.encode(_fbUygulamaSirri)).convert(utf8.encode(p[1])).bytes;
  if (imza.length != beklenen.length) return null;
  var fark = 0;
  for (var i = 0; i < imza.length; i++) {
    fark |= imza[i] ^ beklenen[i];
  }
  if (fark != 0) return null;
  try {
    final j = jsonDecode(utf8.decode(yuk));
    if (j is! Map || (j['algorithm'] as String?)?.toUpperCase() != 'HMAC-SHA256') return null;
    final id = j['user_id'];
    return id == null ? null : '$id';
  } catch (_) {
    return null;
  }
}

/// Facebook veri silme geri çağrısı: POST /api/fb-silme (signed_request, form ya da JSON).
Future<void> _fbSilme(HttpRequest req, Map<String, dynamic> govde, void Function(int, Object) yaz) async {
  if (_fbUygulamaSirri.isEmpty) return yaz(501, {'hata': 'yapılandırılmadı: Facebook veri silme sunucuda henüz ayarlanmadı.'});
  final sr = _str(govde['signed_request'], 4000) ?? '';
  final fbId = _fbKullanici(sr);
  if (fbId == null) return yaz(400, {'hata': 'Geçersiz istek.'});
  final r = db.fbSilme(fbId);
  if (r.nick != null) liderlik.sil(r.nick!);
  log('FB silme isteği tamamlandı (${r.kod})');
  final host = req.headers.value('x-forwarded-host') ?? req.headers.value('host') ?? 'localhost';
  final proto = req.headers.value('x-forwarded-proto') ?? (req.connectionInfo?.localPort == 8766 ? 'https' : 'http');
  return yaz(200, {'url': '$proto://$host/hesap-sil-durum?kod=${r.kod}', 'confirmation_code': r.kod});
}

/// JSON API: misafir/giriş/profil/sonuç/liderlik. Yetki: Authorization: Bearer <token>.
Future<void> _api(HttpRequest req) async {
  Map<String, dynamic> govde = {};
  void yaz(int kod, Object veri) {
    req.response
      ..statusCode = kod
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(veri))
      ..close();
  }
  if (req.method == 'POST') {
    try {
      final t = await _govdeOku(req);
      if (t.trim().isNotEmpty) {
        final ct = req.headers.contentType?.mimeType ?? '';
        if (ct == 'application/x-www-form-urlencoded') {
          govde = Map<String, dynamic>.from(Uri.splitQueryString(t));
        } else {
          final j = jsonDecode(t);
          if (j is Map) govde = j.cast<String, dynamic>();
        }
      }
    } on _GovdeCokBuyuk {
      return yaz(413, {'hata': 'İstek çok büyük.'});
    } catch (_) {}
  }
  final yetki = req.headers.value('authorization');
  final token = yetki != null && yetki.startsWith('Bearer ') ? yetki.substring(7) : null;
  final kim = db.oturumKim(token);
  try {
    switch (req.uri.path) {
      case '/api/misafir':
        final cihaz = (govde['cihaz'] as String? ?? '').trim();
        if (cihaz.length < 8) return yaz(400, {'hata': 'cihaz anahtarı yok'});
        final r = db.misafir(cihaz, nick: govde['nick'] as String?, avatar: govde['avatar'] as String?);
        return yaz(200, {'token': r.token, 'yeni': r.yeni, 'profil': db.profil(r.id)});
      case '/api/giris':
        final ep = (govde['eposta'] as String? ?? '').trim().toLowerCase();
        final simdi = DateTime.now();
        final denemeler = (_girisHatalari[ep] ?? []).where((t) => simdi.difference(t).inMinutes < 10).toList();
        if (denemeler.length >= 8) return yaz(429, {'hata': 'Çok fazla yanlış deneme. 10 dakika sonra tekrar dene.'});
        final r = db.epostaGiris(ep, govde['sifre'] as String? ?? '');
        if (r == null) {
          _girisHatalari[ep] = [...denemeler, simdi];
          return yaz(401, {'hata': 'E-posta ya da şifre yanlış.'});
        }
        _girisHatalari.remove(ep);
        return yaz(200, {'token': r.token, 'profil': db.profil(r.id)});
      case '/api/sosyal':
        final sag = govde['saglayici'] as String? ?? '';
        final k = await _sosyalDogrula(sag, govde['token'] as String? ?? '');
        if (k.hata != null) return yaz(k.hata!.startsWith('yapılandırılmadı') ? 501 : 401, {'hata': k.hata});
        final onceki = kim;
        final r = db.sosyal(sag, k.kimlik!, bagla: onceki, nick: k.ad);
        return yaz(200, {'token': r.token, 'degisti': onceki != null && r.id != onceki, 'profil': db.profil(r.id)});
      case '/api/cikis':
        if (token != null) db.oturumKapat(token);
        return yaz(200, {'tamam': true});
      case '/api/profil':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method == 'POST') {
          if (db.misafirMi(kim)) return yaz(403, {'hata': 'Misafir hesapta profil değiştirilemez. Giriş yap.', 'misafir': true});
          final h = db.profilGuncelle(kim, nick: govde['nick'] as String?, avatar: govde['avatar'] as String?, ses: govde['ses'] as int?);
          if (h != null) return yaz(400, {'hata': h});
        }
        return yaz(200, db.profil(kim));
      case '/api/eposta':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        final h = db.epostaBagla(kim, (govde['eposta'] as String? ?? '').trim(), govde['sifre'] as String? ?? '');
        if (h != null) return yaz(400, {'hata': h});
        return yaz(200, db.profil(kim));
      case '/api/sonuc':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        final r = db.sonuc(kim, kazandi: govde['kazandi'] == true, rakip: (govde['rakip'] as int? ?? 1).clamp(1, 4), online: false, zorluk: (govde['zorluk'] as int? ?? 1).clamp(0, 2));
        for (final b in (govde['basarimlar'] as List? ?? const [])) {
          db.basarimEkle(kim, '$b');
        }
        return yaz(200, r);
      case '/api/gorevler':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (db.misafirMi(kim)) return yaz(403, {'hata': 'Günlük görevler için giriş yapmalısın.', 'misafir': true});
        return yaz(200, {'gorevler': db.gorevler(kim), 'profil': db.profil(kim)});
      case '/api/gorev_al':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        if (db.misafirMi(kim)) return yaz(403, {'hata': 'Günlük görevler için giriş yapmalısın.', 'misafir': true});
        final gr = db.gorevAl(kim, govde['gorev'] as String? ?? '');
        if (gr == null) return yaz(400, {'hata': 'Görev ödülü alınamaz.'});
        return yaz(200, {...gr, 'gorevler': db.gorevler(kim), 'profil': db.profil(kim)});
      case '/api/bonus':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (db.misafirMi(kim)) return yaz(403, {'hata': 'Günlük ödül için giriş yapmalısın.', 'misafir': true});
        return yaz(200, db.bonusAl(kim));
      case '/api/liderlik':
        return yaz(200, db.liderlik());
      case '/api/magaza':
        return yaz(200, [for (final e in Db.magaza.entries) {'id': e.key, 'ad': e.value.$1, 'fiyat': e.value.$2, 'tur': e.value.$3}]);
      case '/api/satin_al':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (db.misafirMi(kim)) return yaz(403, {'hata': 'Satın almak için giriş yapmalısın.', 'misafir': true});
        final h = db.satinAl(kim, govde['esya'] as String? ?? '');
        if (h != null) return yaz(400, {'hata': h});
        return yaz(200, db.profil(kim));
      case '/api/secim':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        final h = db.secimKaydet(kim, kartArkasi: govde['kartArkasi'] as String?, masa: govde['masa'] as String?);
        if (h != null) return yaz(400, {'hata': h});
        return yaz(200, db.profil(kim));
      case '/api/arkadaslar':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method == 'POST') {
          if (db.misafirMi(kim)) return yaz(403, {'hata': 'Arkadaşlar için giriş yapmalısın.', 'misafir': true});
          if (govde['sil'] == true) {
            db.arkadasSil(kim, govde['nick'] as String? ?? '');
          } else {
            final h = db.arkadasEkle(kim, govde['nick'] as String? ?? '');
            if (h != null) return yaz(400, {'hata': h});
          }
        }
        final l = db.arkadaslar(kim);
        for (final a in l) {
          final c = cevrimici[a['id'] as int];
          a['cevrimici'] = c != null && c.ws.readyState == WebSocket.open;
          a['odada'] = c?.oda?.kod;
        }
        return yaz(200, l);
      case '/api/gecmis':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        return yaz(200, db.gecmis(kim));
      case '/api/hata':
        if (!_oranIzin('hata', _ip(req))) return yaz(429, {'hata': 'Çok fazla istek.'});
        final mesaj = _str(govde['mesaj'], 2000) ?? '?';
        db.hataKaydet(
          kullaniciId: kim,
          surum: _str(govde['surum'], 64),
          cihaz: _str(govde['cihaz'], 64),
          model: _str(govde['model'], 64),
          dil: _str(govde['dil'], 16),
          mesaj: mesaj,
          yigin: _str(govde['yigin'], 8000),
          sayac: govde['sayac'] is int ? govde['sayac'] as int : 1,
          iz: govde['iz'] is List ? govde['iz'] as List : null,
          kaynak: _str(govde['kaynak'], 16),
        );
        log('İSTEMCİ HATASI (${kim ?? '-'}): ${mesaj.split('\n').first}');
        return yaz(200, {'ok': true});
      case '/api/sikayet':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        if (!_oranIzin('sikayet', '$kim', sinir: 20)) return yaz(429, {'hata': 'Çok fazla istek.'});
        final sh = db.sikayetEt(kim, _str(govde['hedef'], 40) ?? '', _str(govde['neden'], 30) ?? '', _str(govde['not'], 200), _str(govde['baglam'], 20));
        if (sh != null) return yaz(400, {'hata': sh});
        return yaz(200, {'ok': true});
      case '/api/engel':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        final eh = db.engelle(kim, _str(govde['nick'], 40) ?? '', govde['engel'] != false);
        if (eh != null) return yaz(400, {'hata': eh});
        return yaz(200, {'ok': true});
      case '/api/engeller':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        return yaz(200, {'engeller': db.engeller(kim)});
      case '/api/hesap/sil':
        if (kim == null) return yaz(401, {'hata': 'oturum yok'});
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        if (govde['onay'] != 'SIL') return yaz(400, {'hata': 'Onay gerekli.'});
        final silDeneme = (_girisHatalari['sil:$kim'] ?? []).where((t) => DateTime.now().difference(t).inMinutes < 10).toList();
        if (silDeneme.length >= 5) return yaz(429, {'hata': 'Çok fazla yanlış deneme. 10 dakika sonra tekrar dene.'});
        final sr = db.hesapSil(kim, parola: _str(govde['parola'], 200));
        if (sr.hata != null) {
          _girisHatalari['sil:$kim'] = [...silDeneme, DateTime.now()];
          return yaz(403, {'hata': sr.hata});
        }
        _girisHatalari.remove('sil:$kim');
        if (sr.nick != null) liderlik.sil(sr.nick!);
        final bag = cevrimici.remove(kim);
        log('HESAP SİLİNDİ (id $kim)');
        yaz(200, {'ok': true});
        if (bag != null) {
          try {
            bag.kullaniciId = null;
            await bag.ws.close();
          } catch (_) {}
        }
        return;
      case '/api/fb-silme':
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        if (!_oranIzin('fbsilme', _ip(req), sinir: 10)) return yaz(429, {'hata': 'Çok fazla istek.'});
        return await _fbSilme(req, govde, yaz);
      case '/api/yonetim/sikayetler':
      case '/api/yonetim/sikayet':
      case '/api/yonetim/hatalar':
        if (_yonetimAnahtar.isEmpty) return yaz(503, {'hata': 'Yönetim devre dışı.'});
        if (!_oranIzin('yonetim', _ip(req))) return yaz(429, {'hata': 'Çok fazla istek.'});
        if (!_anahtarDogru(req.uri.queryParameters['anahtar'] ?? _str(govde['anahtar'], 200))) return yaz(403, {'hata': 'Anahtar yanlış.'});
        if (req.uri.path == '/api/yonetim/hatalar') return yaz(200, db.hatalarListe());
        if (req.uri.path == '/api/yonetim/sikayetler') return yaz(200, db.sikayetListe());
        if (req.method != 'POST') return yaz(405, {'hata': 'POST gerekli'});
        final dh = db.sikayetDurumu(govde['id'] is int ? govde['id'] as int : -1, _str(govde['durum'], 30) ?? '');
        if (dh != null) return yaz(400, {'hata': dh});
        return yaz(200, {'ok': true});
      case '/api/olay':
        db.olayKaydet(kullaniciId: kim, ad: govde['ad'] as String? ?? '?', veri: govde['veri'] == null ? null : jsonEncode(govde['veri']));
        return yaz(200, {'ok': true});
      case '/api/ozet':
        return yaz(200, db.ozet());
      default:
        return yaz(404, {'hata': 'yok'});
    }
  } catch (e, st) {
    log('api hatası ${req.uri.path}: $e\n$st');
    yaz(500, {'hata': '$e'});
  }
}

Future<void> _dinle(HttpServer server) async {
  await for (final req in server) {
    if (req.uri.path == '/saglik') {
      req.response
        ..write('ok odalar=${odalar.length}')
        ..close();
      continue;
    }
    if (req.uri.path == '/liderlik') {
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(liderlik.sirali()))
        ..close();
      continue;
    }
    if (req.method == 'GET' || req.method == 'HEAD') {
      final yasalSayfa = switch (req.uri.path) {
        '/gizlilik' => gizlilikSayfasi(en: ingilizceMi(req)),
        '/hesap-sil' => hesapSilSayfasi(en: ingilizceMi(req)),
        '/kosullar' => kosullarSayfasi(en: ingilizceMi(req)),
        '/hesap-sil-durum' => () {
            final kod = (req.uri.queryParameters['kod'] ?? '').trim();
            final kayit = kod.length > 64 ? null : db.fbSilmeDurumu(kod);
            return silmeDurumSayfasi(en: ingilizceMi(req), kod: kod.length > 64 ? '' : kod, kayit: kayit);
          }(),
        _ => null,
      };
      if (yasalSayfa != null) {
        req.response
          ..headers.contentType = ContentType.html
          ..headers.set('cache-control', 'public, max-age=300')
          ..write(req.method == 'HEAD' ? '' : yasalSayfa);
        await req.response.close();
        continue;
      }
    }
    if (req.uri.path.startsWith('/api/')) {
      await _api(req);
      continue;
    }
    if (req.uri.path == '/sonuc' && req.method == 'POST') {
      try {
        final j = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        liderlik.kaydet(j['ad'] as String, j['kazandi'] == true);
        req.response.write('ok');
      } catch (e) {
        req.response
          ..statusCode = 400
          ..write('$e');
      }
      await req.response.close();
      continue;
    }
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = 400
        ..write('WebSocket bekleniyor')
        ..close();
      continue;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    final b = Baglanti(ws);
    ws.listen((veri) {
      try {
        mesaj(b, jsonDecode(veri as String) as Map<String, dynamic>);
      } catch (e, st) {
        log('mesaj hatası: $e\n$st');
        b.gonder({'t': 'hata', 'm': '$e'});
      }
    }, onDone: () => kopti(b), onError: (_) => kopti(b));
  }
}
