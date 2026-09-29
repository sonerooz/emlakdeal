import 'package:flutter/material.dart';
import '../ai/bot.dart';
import '../model/cards.dart';
import '../model/game.dart';
import 'card_widget.dart';
import 'dialogs.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Ekranda uçan bir kart (animasyon katmanı).
class _Ucan {
  _Ucan({required this.card, required this.arka, required this.ctl, required this.from, required this.to, required this.w, this.scaleTo = 1});
  final GameCard card;
  final bool arka;
  final AnimationController ctl;
  final Offset from, to;
  final double w;
  final double scaleTo;
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final Game game;
  late final Player ben;
  late final Player bot;
  final BotDecider _botAi = BotDecider();
  bool _botOynuyor = false;
  bool _bittiGosterildi = false;
  bool _hazir = false;
  String? _acikDeste; // açılmış deste anahtarı: "ben:pink", "ben:banka", "bot:red" ...

  // animasyon
  final _kStack = GlobalKey();
  final _kDeck = GlobalKey();
  final _kMerkez = GlobalKey();
  final _kBenEl = GlobalKey();
  final _kBenSet = GlobalKey();
  final _kBenBanka = GlobalKey();
  final _kBotEl = GlobalKey();
  final _kBotSet = GlobalKey();
  final List<_Ucan> _ucanlar = [];
  String? _banner;

  @override
  void initState() {
    super.initState();
    ben = Player('Sen', isBot: false, decider: HumanDecider(() => context));
    bot = Player('Bot', isBot: true, decider: _botAi);
    game = Game(players: [ben, bot]);
    game.animator = _animasyon;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await game.baslat();
      if (!mounted) return;
      setState(() => _hazir = true);
      _botKontrol();
    });
  }

  @override
  void dispose() {
    for (final u in _ucanlar) {
      u.ctl.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------- animasyon
  Offset _nokta(GlobalKey k, {Offset fallback = const Offset(200, 400)}) {
    final stackBox = _kStack.currentContext?.findRenderObject() as RenderBox?;
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null || !box.hasSize) return fallback;
    return stackBox.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  Future<void> _ucur(GameCard card, Offset from, Offset to, {bool arka = false, int ms = 420, double w = 74, double scaleTo = 1}) async {
    if (!mounted) return;
    final ctl = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    final u = _Ucan(card: card, arka: arka, ctl: ctl, from: from, to: to, w: w, scaleTo: scaleTo);
    setState(() => _ucanlar.add(u));
    try {
      await ctl.forward();
    } finally {
      if (mounted) setState(() => _ucanlar.remove(u));
      ctl.dispose();
    }
  }

  Offset _elNoktasi(Player p) => p == ben ? _nokta(_kBenEl) : _nokta(_kBotEl);
  Offset _setNoktasi(Player p) => p == ben ? _nokta(_kBenSet) : _nokta(_kBotSet);
  Offset _bankaNoktasi(Player p) => p == ben ? _nokta(_kBenBanka) : _nokta(_kBotSet);

  Future<void> _animasyon(GameEvent e) async {
    if (!mounted) return;
    if (_acikDeste != null) setState(() => _acikDeste = null); // hareket başlayınca desteler toplanır
    final kim = e.kim;
    switch (e.tip) {
      case EvTip.cek:
        await _ucur(e.card, _nokta(_kDeck), _elNoktasi(kim!), arka: kim != ben, ms: 520, w: kim == ben ? 60 : 34, scaleTo: kim == ben ? 1.25 : 1.2);
        await Future.delayed(const Duration(milliseconds: 120));
      case EvTip.mulk:
        await _ucur(e.card, _elNoktasi(kim!), _setNoktasi(kim), ms: 480, w: kim == ben ? 74 : 56);
      case EvTip.banka:
        await _ucur(e.card, _elNoktasi(kim!), _bankaNoktasi(kim), ms: 450, w: kim == ben ? 74 : 56);
      case EvTip.aksiyon:
        final merkez = _nokta(_kMerkez);
        await _ucur(e.card, _elNoktasi(kim!), merkez, ms: 420, w: 74, scaleTo: 1.7);
        if (!mounted) return;
        setState(() => _banner = '${kim == ben ? 'Sen' : 'Bot'}: ${e.etiket ?? e.card.ad}');
        await Future.delayed(Duration(milliseconds: kim == ben ? 700 : 1100));
        if (!mounted) return;
        setState(() => _banner = null);
        await _ucur(e.card, merkez, _nokta(_kDeck), ms: 300, w: 74, scaleTo: 0.5);
      case EvTip.transfer:
        final from = e.card.isProperty ? _setNoktasi(kim!) : _bankaNoktasi(kim!);
        final to = e.card.isProperty ? _setNoktasi(e.kime!) : _bankaNoktasi(e.kime!);
        if (mounted) setState(() => _banner = '${e.etiket ?? 'Ödeme'}: ${e.card.ad} → ${e.kime!.name}');
        await _ucur(e.card, from, to, ms: 600, w: 64);
        if (mounted) setState(() => _banner = null);
    }
  }

  // ----------------------------------------------------------- akış
  Future<void> _botKontrol() async {
    if (_botOynuyor || game.kazanan != null || !game.aktif.isBot) return;
    _botOynuyor = true;
    if (mounted) setState(() {});
    try {
      await _botAi.turOyna(game, bot);
    } finally {
      _botOynuyor = false;
    }
    if (mounted) setState(() {});
    _bitisKontrol();
  }

  void _bitisKontrol() {
    if (game.kazanan == null || _bittiGosterildi) return;
    _bittiGosterildi = true;
    final k = game.kazanan!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(k == ben ? '🏆 Kazandın!' : '😔 Bot kazandı'),
          content: Text('${k.name} 3 tam set topladı: ${k.tamSetler.map((c) => c.ad).join(', ')}.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst), child: const Text('Menüye dön')),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
              },
              child: const Text('Yeni oyun'),
            ),
          ],
        ),
      );
    });
  }

  bool get _sirada => _hazir && game.aktif == ben && game.kazanan == null && !_botOynuyor && _ucanlar.isEmpty;

  void _mesaj(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(milliseconds: 1400)));

  Future<void> _sonra() async {
    if (mounted) setState(() => _acikDeste = null);
    _bitisKontrol();
    if (game.kazanan == null && game.aktif == ben && game.playsLeft <= 0) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && game.aktif == ben && game.playsLeft <= 0) await _turBitir();
    }
  }

  // ----------------------------------------------------------- kart tıklama
  Future<void> _kartTikla(GameCard c) async {
    if (!_sirada) return _mesaj('Sıra sende değil.');
    if (game.playsLeft <= 0) return _mesaj('Hamle hakkın bitti.');
    // Tapu (joker dahil) ve para kartları menüsüz, tek dokunuşla oynanır; joker yalnızca rengi sorar.
    if (c.isProperty || c.isMoney) {
      final ok = c.isMoney ? await game.bankayaKoy(ben, c) : await game.mulkOyna(ben, c);
      if (!ok && mounted) _mesaj('Bu hamle yapılamadı.');
      return _sonra();
    }
    final secenekler = <_Secenek>[];
    if (c.isRent) secenekler.add(_Secenek('💰 Kira iste', () => _kira(c)));
    if (c.isAction) {
      final a = c.action!;
      switch (a) {
        case ActionType.passGo:
          secenekler.add(_Secenek('▶ 2 Kart Çek', () => game.passGo(ben, c)));
        case ActionType.debtCollector:
          secenekler.add(_Secenek('💵 Borç Tahsildarı: 5M al', () => game.borcTahsildari(ben, c)));
        case ActionType.birthday:
          secenekler.add(_Secenek('🎂 Doğum Günüm: 2M al', () => game.dogumGunu(ben, c)));
        case ActionType.slyDeal:
          secenekler.add(_Secenek('🕵️ Tapu Devri: rakipten tapu al', () => _slyDeal(c)));
        case ActionType.forcedDeal:
          secenekler.add(_Secenek('🔁 Değiş Tokuş: tapu takası', () => _forcedDeal(c)));
        case ActionType.dealBreaker:
          secenekler.add(_Secenek('💥 Haciz: tam seti al', () => _dealBreaker(c)));
        case ActionType.house:
        case ActionType.hotel:
          secenekler.add(_Secenek('🏗️ ${a.ad} koy (tam sete)', () => _bina(c)));
        case ActionType.doubleRent:
          secenekler.add(_Secenek('✖2 Çift kira (kira kartıyla)', () => _ciftKira(c)));
        case ActionType.justSayNo:
          secenekler.add(_Secenek('ℹ️ Sadece savunmada oynanır', () async {
            _mesaj('Reddet kartı, rakip sana aksiyon oynayınca sorulur.');
            return false;
          }));
      }
    }
    secenekler.add(_Secenek('🏦 Bankaya koy (${c.paraDegeri}M para olur)', () => game.bankayaKoy(ben, c)));
    final sec = await showModalBottomSheet<_Secenek>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CardView(c, w: 70),
              const SizedBox(width: 12),
              Expanded(child: Text(c.isAction ? c.action!.aciklama : c.ad, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            ]),
          ),
          for (final s in secenekler) ListTile(title: Text(s.baslik), onTap: () => Navigator.pop(ctx, s)),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (sec == null) return;
    final ok = await sec.calistir();
    if (!ok && mounted) _mesaj('Bu hamle yapılamadı.');
    await _sonra();
  }

  /// Tek seçenek varsa sormadan onu döndürür.
  Future<PColor?> _renkSec(String baslik, List<PColor> renkler, {String Function(PColor)? altYazi}) async {
    if (renkler.length == 1) return renkler.first;
    return pickColor(context, baslik, renkler, iptalOlur: true, altYazi: altYazi);
  }

  Future<GameCard?> _kartSec(String baslik, List<GameCard> kartlar) async {
    if (kartlar.length == 1) return kartlar.first;
    final s = await pickCards(context, title: baslik, cards: kartlar, exact: 1, max: 1, iptalOlur: true);
    return s.isEmpty ? null : s.first;
  }

  Future<bool> _kira(GameCard c) async {
    final renkler = (c.isWildRent ? PColor.values : c.rentColors).where((k) => ben.propsOf(k).isNotEmpty).toList();
    if (renkler.isEmpty) {
      _mesaj('Bu renkte tapun yok.');
      return false;
    }
    final renk = await _renkSec('💰 Hangi rengin kirası?', renkler, altYazi: (k) => '— ${ben.kira(k)}M');
    if (renk == null) return false;
    GameCard? cift;
    final ciftKart = ben.hand.where((x) => x.action == ActionType.doubleRent).toList();
    if (ciftKart.isNotEmpty && game.playsLeft >= 2 && mounted) {
      if (await confirmDlg(context, '✖2 Çift Kira?', 'Çift Kira kartını da oynayıp ${ben.kira(renk) * 2}M isteyeyim mi? (2 hamle harcar)',
          evet: 'Evet, çift', hayir: 'Hayır, tek')) {
        cift = ciftKart.first;
      }
    }
    return game.kiraOyna(ben, c, renk, cift: cift);
  }

  Future<bool> _ciftKira(GameCard cift) async {
    final kiralar = ben.hand.where((x) => x.isRent).toList();
    if (kiralar.isEmpty) {
      _mesaj('Elinde kira kartı yok.');
      return false;
    }
    if (game.playsLeft < 2) {
      _mesaj('Çift kira için 2 hamle gerekir.');
      return false;
    }
    final c = await _kartSec('Hangi kira kartıyla?', kiralar);
    if (c == null) return false;
    final renkler = (c.isWildRent ? PColor.values : c.rentColors).where((k) => ben.propsOf(k).isNotEmpty).toList();
    if (renkler.isEmpty) {
      _mesaj('Bu renkte tapun yok.');
      return false;
    }
    if (!mounted) return false;
    final renk = await _renkSec('💰 Hangi rengin kirası?', renkler, altYazi: (k) => '— ${ben.kira(k) * 2}M (çift)');
    if (renk == null) return false;
    return game.kiraOyna(ben, c, renk, cift: cift);
  }

  Future<bool> _slyDeal(GameCard c) async {
    final hedefler = game.calinabilir(bot);
    if (hedefler.isEmpty) {
      _mesaj('Rakipte alınabilir tapu yok (tam setler korunur).');
      return false;
    }
    final h = await _kartSec('🕵️ Hangi tapuyu alıyorsun?', hedefler);
    if (h == null) return false;
    return game.slyDeal(ben, c, h);
  }

  Future<bool> _forcedDeal(GameCard c) async {
    final onunkiler = game.calinabilir(bot);
    final benimkiler = game.calinabilir(ben);
    if (onunkiler.isEmpty || benimkiler.isEmpty) {
      _mesaj('Değiş tokuş için iki tarafta da tamamlanmamış setten tapu olmalı.');
      return false;
    }
    final o = await _kartSec('🔁 Rakipten hangisini alıyorsun?', onunkiler);
    if (o == null || !mounted) return false;
    final b = await _kartSec('🔁 Karşılığında hangisini veriyorsun?', benimkiler);
    if (b == null) return false;
    return game.forcedDeal(ben, c, b, o);
  }

  Future<bool> _dealBreaker(GameCard c) async {
    final setler = bot.tamSetler;
    if (setler.isEmpty) {
      _mesaj('Rakibin tam seti yok.');
      return false;
    }
    final s = await _renkSec('💥 Hangi tam seti alıyorsun?', setler);
    if (s == null) return false;
    return game.dealBreaker(ben, c, s);
  }

  Future<bool> _bina(GameCard c) async {
    final setler = ben.tamSetler.where((s) {
      if (!s.binaOlur) return false;
      final m = ben.binalar[s] ?? const <GameCard>[];
      final ev = m.any((b) => b.action == ActionType.house);
      final otel = m.any((b) => b.action == ActionType.hotel);
      return c.action == ActionType.house ? !ev : (ev && !otel);
    }).toList();
    if (setler.isEmpty) {
      _mesaj(c.action == ActionType.house ? 'Evsiz tam setin yok.' : 'Evli (otelsiz) tam setin yok.');
      return false;
    }
    final s = await _renkSec('🏗️ Hangi sete?', setler);
    if (s == null) return false;
    return game.binaKoy(ben, c, s);
  }

  Future<void> _turBitir() async {
    if (!_hazir || game.aktif != ben || game.kazanan != null || _botOynuyor) return;
    setState(() => _acikDeste = null);
    await game.turBitir();
    if (mounted) setState(() {});
    _botKontrol();
  }

  Future<void> _jokerTasi(GameCard c) async {
    if (!_sirada) return;
    await game.jokerRengiDegistir(ben, c);
    await _sonra();
  }

  // ----------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final durum = !_hazir
            ? 'Kartlar dağıtılıyor…'
            : game.kazanan != null
                ? 'Oyun bitti'
                : _botOynuyor
                    ? 'Bot oynuyor…'
                    : game.aktif == ben
                        ? 'Sıra sende · ${game.playsLeft} hamle'
                        : 'Bot…';
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E3A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D25),
            foregroundColor: Colors.white,
            title: const Text('Monopoly Deal', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: Stack(key: _kStack, children: [
              Column(children: [
                _rakipPaneli(),
                _ortaPanel(durum),
                Expanded(child: _benimAlanim()),
                _el(),
              ]),
              for (final u in _ucanlar)
                AnimatedBuilder(
                  animation: u.ctl,
                  builder: (_, __) {
                    final t = Curves.easeInOut.transform(u.ctl.value);
                    final p = Offset.lerp(u.from, u.to, t)!;
                    final s = 1 + (u.scaleTo - 1) * t;
                    final w = u.w * s;
                    return Positioned(
                      left: p.dx - w / 2,
                      top: p.dy - w * 1.45 / 2,
                      child: IgnorePointer(child: u.arka ? CardBack(w: w) : CardView(u.card, w: w)),
                    );
                  },
                ),
              if (_banner != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                        child: Text(_banner!, style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _rakipPaneli() {
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.smart_toy, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          const Text('Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Spacer(),
          Row(key: _kBotEl, children: [
            for (var i = 0; i < bot.hand.length.clamp(0, 8); i++) const Padding(padding: EdgeInsets.only(left: 2), child: CardBack(w: 16)),
            const SizedBox(width: 6),
            Text('${bot.hand.length} kart', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 6),
        // Rakibin masası: sınırlı yükseklik, gerekirse kaydırılır (benim masam sabit kalsın diye)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 118),
          child: SingleChildScrollView(child: Container(key: _kBotSet, child: _desteler(bot, kucuk: true))),
        ),
      ]),
    );
  }

  Widget _ortaPanel(String durum) {
    final son = game.log.isEmpty ? '' : game.log.last;
    final ust = game.discard.isEmpty ? null : game.discard.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        Column(key: _kDeck, mainAxisSize: MainAxisSize.min, children: [
          const CardBack(w: 34),
          Text('${game.deck.length}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
        const SizedBox(width: 6),
        SizedBox(key: _kMerkez, width: 34, height: 34 * 1.45 + 14, child: ust == null ? const SizedBox() : Opacity(opacity: 0.85, child: CardView(ust, w: 34))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(durum, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(son, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        IconButton(
          tooltip: 'Turu bitir',
          color: _sirada ? Colors.amber : Colors.white24,
          onPressed: _sirada ? _turBitir : null,
          icon: const Icon(Icons.skip_next, size: 30),
        ),
      ]),
    );
  }

  Widget _benimAlanim() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Masan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Tam set: ${ben.tamSetSayisi}/3', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Expanded(child: Align(alignment: Alignment.topLeft, child: _desteler(ben))),
      ]),
    );
  }

  /// Oyuncunun masası: renk başına bir tapu destesi + banka destesi. Dokununca deste yana açılır.
  Widget _desteler(Player p, {bool kucuk = false}) {
    final renkler = PColor.values.where((c) => p.propsOf(c).isNotEmpty).toList();
    final kim = p == ben ? 'ben' : 'bot';
    final w = kucuk ? 34.0 : 52.0;
    if (renkler.isEmpty && p.bank.isEmpty) {
      return Text('Henüz kart yok', style: TextStyle(color: Colors.white38, fontSize: kucuk ? 11 : 13));
    }
    final ogeler = <Widget>[
      for (final c in renkler)
        _Deste(
          kartlar: [...p.propsOf(c), ...(p.binalar[c] ?? const <GameCard>[])],
          w: w,
          acik: _acikDeste == '$kim:${c.name}',
          ustBaslik: '${c.ad} ${p.propsOf(c).length}/${c.setBoyu}${p.setTam(c) ? ' ✓' : ''}',
          altBaslik: 'kira ${p.kira(c)}M',
          vurgu: p.setTam(c),
          renk: c.renk,
          onTap: () => setState(() => _acikDeste = _acikDeste == '$kim:${c.name}' ? null : '$kim:${c.name}'),
          onKartTap: p == ben ? (k) => k.isWild ? _jokerTasi(k) : null : null,
        ),
      // banka destesi
      KeyedSubtree(
        key: p == ben ? _kBenBanka : null,
        child: _Deste(
          kartlar: p.bank,
          w: w,
          acik: _acikDeste == '$kim:banka',
          ustBaslik: '🏦 ${p.bank.length} kart',
          altBaslik: '${p.bankaToplam}M',
          vurgu: false,
          renk: const Color(0xFF1E7B3A),
          onTap: () => setState(() => _acikDeste = _acikDeste == '$kim:banka' ? null : '$kim:banka'),
        ),
      ),
    ];
    return Container(
      key: p == ben ? _kBenSet : null,
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: ogeler),
    );
  }

  Widget _el() {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Elin (${ben.hand.length}/7)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(
          key: _kBenEl,
          height: 112,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in ben.hand)
              Padding(padding: const EdgeInsets.only(right: 6), child: CardView(c, w: 74, dim: !_sirada, onTap: () => _kartTikla(c))),
          ]),
        ),
      ]),
    );
  }
}

/// Üst üste konmuş kart destesi; [acik] ise kartlar yana yelpaze gibi açılır.
class _Deste extends StatelessWidget {
  const _Deste({
    required this.kartlar,
    required this.w,
    required this.acik,
    required this.ustBaslik,
    required this.altBaslik,
    required this.vurgu,
    required this.renk,
    required this.onTap,
    this.onKartTap,
  });
  final List<GameCard> kartlar;
  final double w;
  final bool acik;
  final String ustBaslik, altBaslik;
  final bool vurgu;
  final Color renk;
  final VoidCallback onTap;
  final void Function(GameCard)? onKartTap;

  @override
  Widget build(BuildContext context) {
    final h = w * 1.45;
    final n = kartlar.length;
    final gorunen = n.clamp(0, 4);
    Widget kapali = SizedBox(
      width: w + 3.0 * (gorunen - 1) + 2,
      height: h + 3.0 * (gorunen - 1),
      child: Stack(children: [
        for (var i = 0; i < gorunen; i++)
          Positioned(left: 3.0 * i, top: 3.0 * (gorunen - 1 - i), child: CardView(kartlar[n - gorunen + i], w: w)),
        if (n > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54)),
              child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
    Widget acikGorunum = SizedBox(
      height: h,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < n; i++)
          Padding(
            padding: EdgeInsets.only(right: i == n - 1 ? 0 : 3),
            child: GestureDetector(
              onTap: onKartTap == null ? null : () => onKartTap!(kartlar[i]),
              child: CardView(kartlar[i], w: w, selected: kartlar[i].isWild && onKartTap != null),
            ),
          ),
      ]),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: vurgu ? 0.22 : (acik ? 0.14 : 0.06)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: vurgu ? Colors.amber : (acik ? Colors.white70 : Colors.white24), width: vurgu ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(backgroundColor: renk, radius: 5),
            const SizedBox(width: 4),
            Text(ustBaslik, style: TextStyle(color: Colors.white, fontSize: w < 40 ? 10 : 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 3),
          acik ? acikGorunum : kapali,
          const SizedBox(height: 2),
          Text(altBaslik, style: TextStyle(color: Colors.white70, fontSize: w < 40 ? 9 : 10)),
        ]),
      ),
    );
  }
}

class _Secenek {
  _Secenek(this.baslik, this.calistir);
  final String baslik;
  final Future<bool> Function() calistir;
}
