// Monopoly Deal LAN sunucusu: odalar, WebSocket, oyun motoru burada çalışır (hakem).
// Çalıştır: dart run bin/sunucu.dart [port]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:monodeal_cekirdek/aktarim.dart';
import 'package:monodeal_cekirdek/bot.dart';
import 'package:monodeal_cekirdek/cards.dart';
import 'package:monodeal_cekirdek/game.dart';

final odalar = <String, Oda>{};
final rng = Random();

void log(String s) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)} $s');

class Baglanti {
  Baglanti(this.ws);
  final WebSocket ws;
  String ad = 'Oyuncu';
  Oda? oda;
  Koltuk? koltuk;
  void gonder(Map<String, dynamic> m) {
    try {
      ws.add(jsonEncode(m));
    } catch (_) {}
  }
}

/// Odadaki bir insan koltuğu (bağlantı koparsa bot devralır).
class Koltuk {
  Koltuk(this.ad, this.bag);
  String ad;
  Baglanti? bag;
  Player? player;
  UzakKarar? karar;
  /// Bağlantı koptu ve 30 sn içinde dönmedi: yerine bot oynar (dönerse geri alır).
  bool botlasti = false;
  Timer? kopmaSayaci;
}

class Oda {
  Oda(this.kod, this.sahip);
  final String kod;
  Koltuk sahip;
  final List<Koltuk> koltuklar = [];
  int botSayisi = 1;
  Game? game;
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
        'oyuncular': [for (final k in koltuklar) {'ad': k.ad, 'bagli': k.bag != null}],
        'sahip': sahip.ad,
      };

  void lobiYayinla() {
    for (final b in baglar) {
      b.gonder(lobiJson()..['sen'] = koltuklar.indexOf(b.koltuk!));
    }
  }

  void durumYayinla() {
    final g = game;
    if (g == null) return;
    for (final k in koltuklar) {
      final b = k.bag;
      if (b == null || k.player == null) continue;
      b.gonder({'t': 'durum', 'd': durumJson(g, icin: k.player)});
    }
  }

  void herkese(Map<String, dynamic> m) {
    for (final b in baglar) {
      b.gonder(m);
    }
  }

  Future<void> basla() async {
    final toplam = koltuklar.length + botSayisi;
    if (toplam < 2 || toplam > 5) throw 'Oyuncu sayısı 2-5 olmalı (şu an $toplam)';
    final players = <Player>[];
    for (final k in koltuklar) {
      k.karar = UzakKarar(this, k);
      k.player = Player(k.ad, isBot: false, decider: k.karar!);
      players.add(k.player!);
    }
    for (var i = 1; i <= botSayisi; i++) {
      players.add(Player(botSayisi == 1 ? 'Bot' : 'Bot $i', isBot: true, decider: bot));
    }
    final g = Game(players: players);
    game = g;
    g.addListener(durumYayinla);
    g.animator = (e) async {
      herkese({'t': 'olay', 'o': olayJson(g, e)});
      // istemciler kendi animasyonlarını oynatırken sunucu kısa bekler
      await Future.delayed(Duration(milliseconds: e.tip == EvTip.aksiyon ? 1500 : 550));
    };
    g.sozcu = (p, soz) async {
      herkese({'t': 'soz', 'kim': players.indexOf(p), 'soz': soz});
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
      k.bag?.gonder({'t': 'basladi', 'sen': players.indexOf(k.player!), 'adlar': [for (final p in players) p.name], 'botlar': [for (final p in players) p.isBot]});
    }
    log('oda $kod başladı: ${players.map((p) => p.name).join(', ')}');
    await g.baslat();
    durumYayinla();
    unawaited(botKontrol());
  }

  Future<void> botKontrol() async {
    final g = game;
    if (g == null || botOynuyor) return;
    botOynuyor = true;
    try {
      while (g.kazanan == null && aktifBotMu(g)) {
        await bot.turOyna(g, g.aktif);
      }
    } catch (e, st) {
      log('bot hatası: $e\n$st');
    } finally {
      botOynuyor = false;
    }
    durumYayinla();
    bitisKontrol();
  }

  void bitisKontrol() {
    final g = game;
    if (g?.kazanan != null) {
      herkese({'t': 'bitti', 'kazanan': g!.players.indexOf(g.kazanan!)});
      log('oda $kod bitti: ${g.kazanan!.name}');
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
      return await c.future.timeout(const Duration(seconds: 90));
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
  Future<PColor> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler) async {
    if (secenekler.length == 1) return secenekler.first;
    final r = await _sor('jokerRengi', {'kart': joker.id, 'secenekler': [for (final c in secenekler) c.index]});
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

void mesaj(Baglanti b, Map<String, dynamic> m) {
  final t = m['t'] as String?;
  switch (t) {
    case 'kur':
      b.ad = (m['ad'] as String?)?.trim().isNotEmpty == true ? (m['ad'] as String).trim() : 'Oyuncu';
      final oda = Oda(yeniKod(), Koltuk(b.ad, b));
      oda.koltuklar.add(oda.sahip);
      oda.botSayisi = ((m['bot'] as int?) ?? 1).clamp(0, 3);
      odalar[oda.kod] = oda;
      b.oda = oda;
      b.koltuk = oda.sahip;
      log('oda ${oda.kod} kuruldu (${b.ad}, bot ${oda.botSayisi})');
      oda.lobiYayinla();
    case 'katil':
      final kod = (m['oda'] as String? ?? '').toUpperCase().trim();
      final oda = odalar[kod];
      if (oda == null) {
        b.gonder({'t': 'hata', 'm': 'Oda bulunamadı: $kod'});
        return;
      }
      b.ad = (m['ad'] as String?)?.trim().isNotEmpty == true ? (m['ad'] as String).trim() : 'Oyuncu';
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
          b.gonder({'t': 'basladi', 'sen': g.players.indexOf(eski.player!), 'adlar': [for (final p in g.players) p.name], 'botlar': [for (final p in g.players) p.isBot]});
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
      if (oda.koltuklar.any((k) => k.ad == b.ad)) b.ad = '${b.ad} ${oda.koltuklar.length + 1}';
      final k = Koltuk(b.ad, b);
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
      final soz = (m['soz'] as String? ?? '').trim();
      if (oda == null || k == null || soz.isEmpty || soz.length > 60) return;
      final g = oda.game;
      final kim = g == null || k.player == null ? -1 : g.players.indexOf(k.player!);
      oda.herkese({'t': 'sohbet', 'kim': kim, 'ad': k.ad, 'soz': soz});
    case 'ping':
      b.gonder({'t': 'pong'});
    default:
      b.gonder({'t': 'hata', 'm': 'Bilinmeyen mesaj: $t'});
  }
}

void kopti(Baglanti b) {
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

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8765;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  log('Monopoly Deal sunucusu dinliyor: ws://0.0.0.0:$port');
  await for (final req in server) {
    if (req.uri.path == '/saglik') {
      req.response
        ..write('ok odalar=${odalar.length}')
        ..close();
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
