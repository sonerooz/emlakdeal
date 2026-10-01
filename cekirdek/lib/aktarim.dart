import 'cards.dart';
import 'game.dart';

/// Oyun durumunun JSON'a aktarımı (sunucu → istemci) ve istemcide yerel aynaya yüklenmesi.

List<Map<String, dynamic>> _kartlar(Iterable<GameCard> l) => [for (final c in l) c.toJson()];

Map<String, dynamic> oyuncuJson(Player p, {required bool elAcik}) => {
      'ad': p.name,
      'bot': p.isBot,
      'elSayisi': p.hand.length,
      if (elAcik) 'el': _kartlar(p.hand),
      'banka': _kartlar(p.bank),
      'tapular': {for (final e in p.props.entries) '${e.key.index}': _kartlar(e.value)},
      'binalar': {for (final e in p.binalar.entries) '${e.key.index}': _kartlar(e.value)},
    };

/// [icin] oyuncusunun eli açık, diğerlerinin yalnız sayısı gider.
Map<String, dynamic> durumJson(Game g, {Player? icin}) => {
      'oyuncular': [for (final p in g.players) oyuncuJson(p, elAcik: p == icin)],
      'deste': g.deck.length,
      'atik': _kartlar(g.discard.length > 6 ? g.discard.sublist(g.discard.length - 6) : g.discard),
      'atikSayisi': g.discard.length,
      'sira': g.current,
      'hamle': g.playsLeft,
      'kazanan': g.kazanan == null ? null : g.players.indexOf(g.kazanan!),
      'log': g.log.length > 12 ? g.log.sublist(g.log.length - 12) : g.log,
      'basladi': g.turBasladi,
    };

GameCard _bos() => GameCard.para(-1, 0);

List<GameCard> _oku(dynamic l) => [for (final j in (l as List? ?? const [])) GameCard.fromJson(Map<String, dynamic>.from(j as Map))];

/// Sunucudan gelen durumu yerel [g] aynasına yazar (oyuncu sırası sunucuyla aynı olmalı).
void durumYukle(Game g, Map<String, dynamic> j) {
  final oy = j['oyuncular'] as List;
  for (var i = 0; i < g.players.length && i < oy.length; i++) {
    final p = g.players[i];
    final o = Map<String, dynamic>.from(oy[i] as Map);
    p.hand
      ..clear()
      ..addAll(o.containsKey('el') ? _oku(o['el']) : List.generate(o['elSayisi'] as int, (_) => _bos()));
    p.bank
      ..clear()
      ..addAll(_oku(o['banka']));
    p.props.clear();
    for (final e in (o['tapular'] as Map).entries) {
      p.props[PColor.values[int.parse(e.key as String)]] = _oku(e.value);
    }
    p.binalar.clear();
    for (final e in (o['binalar'] as Map).entries) {
      p.binalar[PColor.values[int.parse(e.key as String)]] = _oku(e.value);
    }
  }
  g.deck
    ..clear()
    ..addAll(List.generate(j['deste'] as int, (_) => _bos()));
  g.discard
    ..clear()
    ..addAll(_oku(j['atik']));
  g.current = j['sira'] as int;
  g.playsLeft = j['hamle'] as int;
  g.kazanan = j['kazanan'] == null ? null : g.players[j['kazanan'] as int];
  g.log
    ..clear()
    ..addAll((j['log'] as List).cast<String>());
  g.turBasladi = j['basladi'] as bool;
  g.notifyListeners();
}

Map<String, dynamic> olayJson(Game g, GameEvent e) => {
      'tip': e.tip.index,
      'kart': e.card.toJson(),
      if (e.kim != null) 'kim': g.players.indexOf(e.kim!),
      if (e.kime != null) 'kime': g.players.indexOf(e.kime!),
      if (e.renk != null) 'renk': e.renk!.index,
      if (e.etiket != null) 'etiket': e.etiket,
    };

GameEvent olayOku(Game g, Map<String, dynamic> j) => GameEvent(
      EvTip.values[j['tip'] as int],
      GameCard.fromJson(Map<String, dynamic>.from(j['kart'] as Map)),
      kim: j['kim'] == null ? null : g.players[j['kim'] as int],
      kime: j['kime'] == null ? null : g.players[j['kime'] as int],
      renk: j['renk'] == null ? null : PColor.values[j['renk'] as int],
      etiket: j['etiket'] as String?,
    );

/// Yerel aynada id ile kart bulur (el, banka, tapular, binalar, atık).
GameCard? kartBul(Game g, int id) {
  for (final p in g.players) {
    for (final c in p.hand) {
      if (c.id == id) return c;
    }
    for (final c in p.bank) {
      if (c.id == id) return c;
    }
    for (final l in p.props.values) {
      for (final c in l) {
        if (c.id == id) return c;
      }
    }
    for (final l in p.binalar.values) {
      for (final c in l) {
        if (c.id == id) return c;
      }
    }
  }
  for (final c in g.discard) {
    if (c.id == id) return c;
  }
  return null;
}

// ----------------------------------------------------------- tam kayıt (tek kişilik oyun)

/// Oyunun TAMAMI (deste, atık, tüm eller): uygulama kapanınca devam etmek için.
Map<String, dynamic> kayitJson(Game g) => {
      'oyuncular': [
        for (final p in g.players)
          {
            'ad': p.name,
            'bot': p.isBot,
            'el': _kartlar(p.hand),
            'banka': _kartlar(p.bank),
            'tapular': {for (final e in p.props.entries) '${e.key.index}': _kartlar(e.value)},
            'binalar': {for (final e in p.binalar.entries) '${e.key.index}': _kartlar(e.value)},
          }
      ],
      'deste': _kartlar(g.deck),
      'atik': _kartlar(g.discard),
      'sira': g.current,
      'hamle': g.playsLeft,
      'log': g.log.length > 30 ? g.log.sublist(g.log.length - 30) : g.log,
      'basladi': g.turBasladi,
      'paraId': g.paraId,
    };

/// [kayitJson] çıktısını, oyuncuları aynı sırada kurulmuş [g]'ye yükler.
void kayitYukle(Game g, Map<String, dynamic> j) {
  final oy = j['oyuncular'] as List;
  for (var i = 0; i < g.players.length && i < oy.length; i++) {
    final p = g.players[i];
    final o = Map<String, dynamic>.from(oy[i] as Map);
    p.hand
      ..clear()
      ..addAll(_oku(o['el']));
    p.bank
      ..clear()
      ..addAll(_oku(o['banka']));
    p.props.clear();
    for (final e in (o['tapular'] as Map).entries) {
      p.props[PColor.values[int.parse(e.key as String)]] = _oku(e.value);
    }
    p.binalar.clear();
    for (final e in (o['binalar'] as Map).entries) {
      p.binalar[PColor.values[int.parse(e.key as String)]] = _oku(e.value);
    }
  }
  g.deck
    ..clear()
    ..addAll(_oku(j['deste']));
  g.discard
    ..clear()
    ..addAll(_oku(j['atik']));
  g.current = j['sira'] as int;
  g.playsLeft = j['hamle'] as int;
  g.kazanan = null;
  g.log
    ..clear()
    ..addAll((j['log'] as List).cast<String>());
  g.turBasladi = j['basladi'] as bool;
  g.paraId = (j['paraId'] as int?) ?? 1000;
  g.notifyListeners();
}
