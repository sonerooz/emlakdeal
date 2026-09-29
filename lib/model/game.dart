import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cards.dart';

/// Bir oyuncunun karar verme arayüzü. İnsan için UI diyalogları, bot için sezgisel.
abstract class Decider {
  /// Sana oynanan [aciklama] aksiyonuna karşı Just Say No oynamak ister misin? (elinde varsa sorulur)
  Future<bool> justSayNo(Game g, Player me, String aciklama);

  /// [tutar] M öde: banka + mülklerden kart seç. Toplam varlık yetmiyorsa hepsini verir.
  Future<List<GameCard>> ode(Game g, Player me, int tutar, Player alacakli);

  /// Joker mülk için renk seç.
  Future<PColor> jokerRengi(Game g, Player me, GameCard joker, List<PColor> secenekler);

  /// Tur sonunda el 7'yi aşıyorsa atılacak kartları seç.
  Future<List<GameCard>> atilacaklar(Game g, Player me, int adet);

  /// Para talebi (kira/borç/doğum günü): ya ödenecek kartları seç ya da (elinde Reddet varsa)
  /// reddet. Varsayılan: önce [justSayNo], reddetmezse [ode]. İnsan tek modalda görür.
  Future<OdemeKarari> odemeKarari(Game g, Player me, int tutar, Player alacakli, String aciklama,
      {required bool reddedebilir}) async {
    if (reddedebilir && await justSayNo(g, me, aciklama)) return OdemeKarari.reddet();
    return OdemeKarari.ode(await ode(g, me, tutar, alacakli));
  }
}

class OdemeKarari {
  OdemeKarari.ode(this.kartlar) : reddet = false;
  OdemeKarari.reddet()
      : reddet = true,
        kartlar = const [];
  final bool reddet;
  final List<GameCard> kartlar;
}

class Player {
  Player(this.name, {required this.isBot, required this.decider});
  final String name;
  final bool isBot;
  final Decider decider;
  final List<GameCard> hand = [];
  final List<GameCard> bank = [];
  final Map<PColor, List<GameCard>> props = {};
  final Map<PColor, List<GameCard>> binalar = {}; // set başına ev/otel kartları

  int get bankaToplam => bank.fold(0, (s, c) => s + c.paraDegeri);

  List<GameCard> propsOf(PColor c) => props[c] ?? const [];

  bool setTam(PColor c) => propsOf(c).length >= c.setBoyu;

  List<PColor> get tamSetler => PColor.values.where(setTam).toList();

  int get tamSetSayisi => tamSetler.length;

  /// Tüm ödenebilir varlıklar (banka + mülkler + binalar).
  List<GameCard> get varliklar => [
        ...bank,
        for (final l in props.values) ...l,
        for (final l in binalar.values) ...l,
      ];

  int get varlikToplam => varliklar.fold(0, (s, c) => s + c.paraDegeri);

  /// [c] rengi için kira.
  int kira(PColor c) {
    final n = propsOf(c).length;
    if (n == 0) return 0;
    var r = c.kira[min(n, c.setBoyu) - 1];
    if (setTam(c)) {
      for (final b in binalar[c] ?? const <GameCard>[]) {
        r += b.action == ActionType.house ? 3 : 4;
      }
    }
    return r;
  }

  bool get evVar => binalar.values.any((l) => l.any((b) => b.action == ActionType.house));

  void mulkEkle(GameCard c, PColor renk) {
    if (c.isWild) c.wildColor = renk;
    props.putIfAbsent(renk, () => []).add(c);
  }

  /// Kartı nerede olursa olsun çıkarır (el/banka/mülk/bina).
  void kartiCikar(GameCard c) {
    hand.remove(c);
    bank.remove(c);
    for (final k in props.keys.toList()) {
      props[k]!.remove(c);
      if (props[k]!.isEmpty) {
        props.remove(k);
        // set bozulduysa binalar bankaya değil, discard'a gider (kural sadeleştirmesi: bankaya)
        final b = binalar.remove(k);
        if (b != null) bank.addAll(b);
      }
    }
    for (final k in binalar.keys.toList()) {
      binalar[k]!.remove(c);
      if (binalar[k]!.isEmpty) binalar.remove(k);
    }
  }
}

/// Arayüzün animasyonla göstereceği olaylar. Motor, [Game.animator] varsa olayı
/// bekler (böylece botun her hamlesi sırayla ve görünür şekilde işlenir).
enum EvTip { cek, mulk, banka, aksiyon, transfer }

class GameEvent {
  GameEvent(this.tip, this.card, {this.kim, this.kime, this.renk, this.etiket});
  final EvTip tip;
  final GameCard card;
  final Player? kim; // hareketi yapan / veren
  final Player? kime; // alan (transfer)
  final PColor? renk;
  final String? etiket; // ortada gösterilecek yazı (aksiyon adı vb.)
}

class Game extends ChangeNotifier {
  Game({required this.players, Random? rng}) : rng = rng ?? Random() {
    deck.addAll(GameCard.yeniDeste());
  }

  /// Arayüz atar: olayı canlandırır, bitince döner.
  Future<void> Function(GameEvent e)? animator;

  Future<void> _anim(GameEvent e) async {
    final a = animator;
    if (a != null) await a(e);
  }

  final List<Player> players;
  final Random rng;
  int _paraId = 1000; // bankaya dönüşen para kartları için benzersiz id
  final List<GameCard> deck = [];
  final List<GameCard> discard = [];
  final List<String> log = [];
  int current = 0;
  int playsLeft = 0;
  Player? kazanan;
  bool turBasladi = false;

  Player get aktif => players[current];
  List<Player> rakipler(Player p) => players.where((x) => x != p).toList();

  /// Bir masadaki kartın sahibi (mülk/bina/banka).
  Player? sahibi(GameCard c) {
    for (final p in players) {
      if (p.varliklar.contains(c)) return p;
    }
    return null;
  }

  void _log(String s) {
    log.add(s);
    if (log.length > 60) log.removeAt(0);
    notifyListeners();
  }

  // ----------------------------------------------------------- deste/çekme
  GameCard? _cek() {
    if (deck.isEmpty) {
      if (discard.isEmpty) return null;
      deck.addAll(discard);
      discard.clear();
      deck.shuffle(rng);
      _log('Deste bitti, atılanlar karıştırıldı.');
    }
    return deck.removeLast();
  }

  Future<void> _cekEle(Player p, int n, {bool canlandir = true}) async {
    for (var i = 0; i < n; i++) {
      final c = _cek();
      if (c == null) break;
      if (canlandir) await _anim(GameEvent(EvTip.cek, c, kim: p));
      p.hand.add(c);
      notifyListeners();
    }
  }

  Future<void> baslat() async {
    for (final p in players) {
      await _cekEle(p, 5, canlandir: false);
    }
    current = rng.nextInt(players.length);
    await turBaslat();
  }

  Future<void> turBaslat() async {
    final p = aktif;
    playsLeft = 3;
    turBasladi = true;
    _log('${p.name} turuna başladı — kart çekiyor.');
    await _cekEle(p, p.hand.isEmpty ? 5 : 2);
  }

  /// Tur sonu: el 7'yi aşıyorsa at, sıradakine geç.
  Future<void> turBitir() async {
    final p = aktif;
    if (p.hand.length > 7) {
      final at = await p.decider.atilacaklar(this, p, p.hand.length - 7);
      for (final c in at) {
        p.hand.remove(c);
        discard.add(c);
      }
      _log('${p.name} ${at.length} kart attı.');
    }
    current = (current + 1) % players.length;
    await turBaslat();
  }

  bool _oynayabilir() => playsLeft > 0 && kazanan == null;

  void _harca([int n = 1]) {
    playsLeft -= n;
    _kazananKontrol();
    notifyListeners();
  }

  void _kazananKontrol() {
    for (final p in players) {
      if (p.tamSetSayisi >= 3) {
        kazanan = p;
        _log('🏆 ${p.name} 3 tam setle kazandı!');
      }
    }
  }

  // ----------------------------------------------------------- basit oynayışlar
  Future<bool> mulkOyna(Player p, GameCard c) async {
    if (!_oynayabilir() || !c.isProperty || !p.hand.contains(c)) return false;
    PColor renk;
    if (c.kind == CardKind.property) {
      renk = c.color!;
    } else {
      final sec = c.isMultiWild ? PColor.values : c.colors;
      renk = await p.decider.jokerRengi(this, p, c, sec);
    }
    await _anim(GameEvent(EvTip.mulk, c, kim: p, renk: renk));
    p.hand.remove(c);
    p.mulkEkle(c, renk);
    _log('${p.name} ${c.ad} tapusunu ${renk.ad} setine koydu.');
    _harca();
    return true;
  }

  /// Oynanmış joker mülkün rengini değiştir (ücretsiz, kendi turunda).
  Future<bool> jokerRengiDegistir(Player p, GameCard c) async {
    if (!c.isWild || kazanan != null) return false;
    final eski = c.wildColor;
    final sec = c.isMultiWild ? PColor.values : c.colors;
    final yeni = await p.decider.jokerRengi(this, p, c, sec);
    if (yeni == eski) return false;
    p.kartiCikar(c);
    p.mulkEkle(c, yeni);
    _log('${p.name} jokeri ${yeni.ad} setine taşıdı.');
    _kazananKontrol();
    notifyListeners();
    return true;
  }

  Future<bool> bankayaKoy(Player p, GameCard c) async {
    if (!_oynayabilir() || c.isProperty || !p.hand.contains(c)) return false;
    await _anim(GameEvent(EvTip.banka, c, kim: p));
    p.hand.remove(c);
    if (c.isMoney) {
      p.bank.add(c);
      _log('${p.name} ${c.ad} kartını bankaya koydu.');
    } else {
      // Aksiyon/kira kartı bankaya girince düz para kartına dönüşür (geri alınamaz).
      p.bank.add(GameCard.para(_paraId++, c.paraDegeri));
      _log('${p.name} ${c.ad} kartını ${c.paraDegeri}M para olarak bankaya koydu.');
    }
    _harca();
    return true;
  }

  // ----------------------------------------------------------- ödeme
  Future<void> _tahsil(Player borclu, Player alacakli, int tutar, String sebep) async {
    if (tutar <= 0) return;
    if (borclu.varliklar.isEmpty) {
      _log('${borclu.name} ödeyecek hiçbir şeyi yok.');
      return;
    }
    List<GameCard> odeme;
    if (borclu.varlikToplam <= tutar) {
      odeme = List.of(borclu.varliklar);
    } else {
      odeme = await borclu.decider.ode(this, borclu, tutar, alacakli);
    }
    var toplam = 0;
    for (final c in odeme) {
      await _anim(GameEvent(EvTip.transfer, c, kim: borclu, kime: alacakli, etiket: sebep));
      borclu.kartiCikar(c);
      toplam += c.paraDegeri;
      if (c.isProperty) {
        alacakli.mulkEkle(c, c.etkinRenk ?? c.colors.first);
      } else {
        alacakli.bank.add(c);
      }
    }
    _log('${borclu.name} → ${alacakli.name}: $sebep için ${toplam}M ödedi.');
    _kazananKontrol();
    notifyListeners();
  }

  // ----------------------------------------------------------- para talebi (öde ya da reddet)
  /// Kira/borç/doğum günü: hedef tek karar verir — öder ya da Reddet oynar. Reddedilirse
  /// saldıran kendi Reddet'iyle karşı çıkabilir; o zaman hedef yeniden karar verir (zincir).
  Future<void> _talep(Player saldiran, Player hedef, int tutar, String aciklama, String sebep) async {
    if (tutar <= 0) return;
    while (true) {
      final hedefJsn = hedef.hand.where((c) => c.action == ActionType.justSayNo).toList();
      if (hedef.varliklar.isEmpty && hedefJsn.isEmpty) {
        _log('${hedef.name} ödeyecek hiçbir şeyi yok.');
        return;
      }
      OdemeKarari karar;
      if (hedef.varliklar.isEmpty) {
        karar = (hedefJsn.isNotEmpty && await hedef.decider.justSayNo(this, hedef, aciklama))
            ? OdemeKarari.reddet()
            : OdemeKarari.ode(const []);
      } else {
        karar = await hedef.decider.odemeKarari(this, hedef, tutar, saldiran, aciklama, reddedebilir: hedefJsn.isNotEmpty);
      }
      if (!karar.reddet) {
        if (karar.kartlar.isEmpty) {
          _log('${hedef.name} ödeyecek hiçbir şeyi yok.');
          return;
        }
        await _tahsilKartlarla(hedef, saldiran, karar.kartlar, sebep);
        return;
      }
      // Reddet
      hedef.hand.remove(hedefJsn.first);
      discard.add(hedefJsn.first);
      _log('${hedef.name} Reddet oynadı — $sebep iptal!');
      notifyListeners();
      final saldiranJsn = saldiran.hand.where((c) => c.action == ActionType.justSayNo).toList();
      if (saldiranJsn.isEmpty || !await saldiran.decider.justSayNo(this, saldiran, 'Reddet (${hedef.name} $sebep ödemeyi reddetti)')) {
        return;
      }
      saldiran.hand.remove(saldiranJsn.first);
      discard.add(saldiranJsn.first);
      _log('${saldiran.name} Reddet ile karşılık verdi — talep yeniden geçerli!');
      notifyListeners();
    }
  }

  Future<void> _tahsilKartlarla(Player borclu, Player alacakli, List<GameCard> odeme, String sebep) async {
    var toplam = 0;
    for (final c in odeme) {
      if (!borclu.varliklar.contains(c)) continue;
      await _anim(GameEvent(EvTip.transfer, c, kim: borclu, kime: alacakli, etiket: sebep));
      borclu.kartiCikar(c);
      toplam += c.paraDegeri;
      if (c.isProperty) {
        alacakli.mulkEkle(c, c.etkinRenk ?? c.colors.first);
      } else {
        alacakli.bank.add(c);
      }
    }
    _log('${borclu.name} → ${alacakli.name}: $sebep için ${toplam}M ödedi.');
    _kazananKontrol();
    notifyListeners();
  }

  // ----------------------------------------------------------- Just Say No zinciri
  /// [hedef] JSN oynarsa aksiyon iptal olur; saldıran JSN ile karşı çıkabilir (zincir).
  /// true = aksiyon İPTAL edildi.
  Future<bool> _jsnZinciri(Player saldiran, Player hedef, String aciklama) async {
    var savunan = hedef;
    var saldiranP = saldiran;
    var iptal = false;
    while (true) {
      final jsn = savunan.hand.where((c) => c.action == ActionType.justSayNo).toList();
      if (jsn.isEmpty) return iptal;
      final oyna = await savunan.decider.justSayNo(this, savunan, aciklama);
      if (!oyna) return iptal;
      savunan.hand.remove(jsn.first);
      discard.add(jsn.first);
      iptal = !iptal;
      _log('${savunan.name} Reddet oynadı${iptal ? ' — aksiyon iptal!' : ' — reddi reddetti!'}');
      notifyListeners();
      final t = savunan;
      savunan = saldiranP;
      saldiranP = t;
    }
  }

  // ----------------------------------------------------------- aksiyonlar
  Future<void> _aksiyonuAt(Player p, GameCard c, [String? etiket]) async {
    await _anim(GameEvent(EvTip.aksiyon, c, kim: p, etiket: etiket ?? c.ad));
    p.hand.remove(c);
    discard.add(c);
    notifyListeners();
  }

  Future<bool> passGo(Player p, GameCard c) async {
    if (!_oynayabilir() || c.action != ActionType.passGo) return false;
    await _aksiyonuAt(p, c);
    await _cekEle(p, 2);
    _log('${p.name} 2 Kart Çek oynadı: 2 kart çekti.');
    _harca();
    return true;
  }

  Future<bool> borcTahsildari(Player p, GameCard c, Player r) async {
    if (!_oynayabilir() || c.action != ActionType.debtCollector || r == p) return false;
    await _aksiyonuAt(p, c);
    _log('${p.name} Borç Tahsildarı: ${r.name} 5M ödemeli.');
    await _talep(p, r, 5, 'Borç Tahsildarı (5M)', 'Borç Tahsildarı');
    _harca();
    return true;
  }

  Future<bool> dogumGunu(Player p, GameCard c) async {
    if (!_oynayabilir() || c.action != ActionType.birthday) return false;
    await _aksiyonuAt(p, c);
    _log('${p.name} Doğum Günüm: herkes 2M veriyor.');
    for (final r in players.where((x) => x != p)) {
      await _talep(p, r, 2, 'Doğum Günüm (2M)', 'Doğum Günü');
    }
    _harca();
    return true;
  }

  /// Kira: [renk] için rakipten kira al. [cift] verilirse Çift Kira kartı da harcanır.
  Future<bool> kiraOyna(Player p, GameCard c, PColor renk, {GameCard? cift}) async {
    if (!_oynayabilir() || !c.isRent) return false;
    if (!c.isWildRent && !c.rentColors.contains(renk)) return false;
    if (p.propsOf(renk).isEmpty) return false;
    if (cift != null && (playsLeft < 2 || cift.action != ActionType.doubleRent)) return false;
    var tutar = p.kira(renk);
    await _aksiyonuAt(p, c);
    if (cift != null) {
      await _aksiyonuAt(p, cift, 'Çift Kira');
      tutar *= 2;
    }
    _log('${p.name} ${renk.ad} kirası: ${tutar}M${cift != null ? ' (çift)' : ''} — herkes öder.');
    for (final r in rakipler(p)) {
      await _talep(p, r, tutar, '${renk.ad} kirası (${tutar}M)', 'kira');
    }
    _harca(cift != null ? 2 : 1);
    return true;
  }

  /// Rakibin tamamlanmamış setinden alınabilir mülkler.
  List<GameCard> calinabilir(Player r) => [
        for (final e in r.props.entries)
          if (!r.setTam(e.key)) ...e.value,
      ];

  Future<bool> slyDeal(Player p, GameCard c, GameCard hedefMulk) async {
    if (!_oynayabilir() || c.action != ActionType.slyDeal) return false;
    final r = sahibi(hedefMulk);
    if (r == null || r == p || !calinabilir(r).contains(hedefMulk)) return false;
    await _aksiyonuAt(p, c);
    _log('${p.name} Tapu Devri: ${hedefMulk.ad} çalmak istiyor.');
    if (!await _jsnZinciri(p, r, 'Tapu Devri (${hedefMulk.ad})')) {
      final renk = hedefMulk.etkinRenk!;
      await _anim(GameEvent(EvTip.transfer, hedefMulk, kim: r, kime: p, etiket: 'Tapu Devri'));
      r.kartiCikar(hedefMulk);
      p.mulkEkle(hedefMulk, renk);
      _log('${p.name} ${hedefMulk.ad} tapusunu aldı.');
    }
    _harca();
    return true;
  }

  Future<bool> forcedDeal(Player p, GameCard c, GameCard benimki, GameCard onunki) async {
    if (!_oynayabilir() || c.action != ActionType.forcedDeal) return false;
    final r = sahibi(onunki);
    if (r == null || r == p || !calinabilir(r).contains(onunki) || !calinabilir(p).contains(benimki)) return false;
    await _aksiyonuAt(p, c);
    _log('${p.name} Değiş Tokuş: ${benimki.ad} ↔ ${onunki.ad}.');
    if (!await _jsnZinciri(p, r, 'Değiş Tokuş (${onunki.ad})')) {
      final rb = benimki.etkinRenk!, ro = onunki.etkinRenk!;
      await _anim(GameEvent(EvTip.transfer, onunki, kim: r, kime: p, etiket: 'Değiş Tokuş'));
      await _anim(GameEvent(EvTip.transfer, benimki, kim: p, kime: r, etiket: 'Değiş Tokuş'));
      p.kartiCikar(benimki);
      r.kartiCikar(onunki);
      p.mulkEkle(onunki, ro);
      r.mulkEkle(benimki, rb);
      _log('Takas yapıldı.');
    }
    _harca();
    return true;
  }

  Future<bool> dealBreaker(Player p, GameCard c, Player r, PColor set) async {
    if (!_oynayabilir() || c.action != ActionType.dealBreaker || r == p) return false;
    if (!r.setTam(set)) return false;
    await _aksiyonuAt(p, c);
    _log('${p.name} Haciz: ${set.ad} setini istiyor!');
    if (!await _jsnZinciri(p, r, 'Haciz (${set.ad} seti)')) {
      final kartlar = List.of(r.propsOf(set));
      final binalar = List.of(r.binalar[set] ?? const <GameCard>[]);
      for (final k in kartlar) {
        await _anim(GameEvent(EvTip.transfer, k, kim: r, kime: p, etiket: 'Haciz'));
        r.props[set]!.remove(k);
        p.mulkEkle(k, set);
        notifyListeners();
      }
      r.props.remove(set);
      r.binalar.remove(set);
      if (binalar.isNotEmpty) p.binalar.putIfAbsent(set, () => []).addAll(binalar);
      _log('${p.name} ${set.ad} setini aldı!');
    }
    _harca();
    return true;
  }

  /// Ev/otel: tam bir sete koy.
  Future<bool> binaKoy(Player p, GameCard c, PColor set) async {
    if (!_oynayabilir()) return false;
    if (c.action != ActionType.house && c.action != ActionType.hotel) return false;
    if (!p.setTam(set) || !set.binaOlur) return false;
    final mevcut = p.binalar[set] ?? const <GameCard>[];
    final evVar = mevcut.any((b) => b.action == ActionType.house);
    final otelVar = mevcut.any((b) => b.action == ActionType.hotel);
    if (c.action == ActionType.house && evVar) return false;
    if (c.action == ActionType.hotel && (!evVar || otelVar)) return false;
    await _anim(GameEvent(EvTip.mulk, c, kim: p, renk: set));
    p.hand.remove(c);
    p.binalar.putIfAbsent(set, () => []).add(c);
    _log('${p.name} ${set.ad} setine ${c.ad} koydu.');
    _harca();
    return true;
  }
}
