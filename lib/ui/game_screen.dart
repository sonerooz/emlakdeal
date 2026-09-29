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
  bool _hazir = false; // başlangıç dağıtımı bitti mi

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
  String? _banner; // ortadaki büyük etiket ("Bot: Sly Deal")
  GameCard? _bannerKart;

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
    final g = box.localToGlobal(box.size.center(Offset.zero));
    return stackBox.globalToLocal(g);
  }

  Future<void> _ucur(GameCard card, Offset from, Offset to,
      {bool arka = false, int ms = 420, double w = 74, double scaleTo = 1}) async {
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
    final kim = e.kim;
    switch (e.tip) {
      case EvTip.cek:
        // desteden ele: insan için açık kart, bot için kapalı; biraz büyüyerek gelir
        await _ucur(e.card, _nokta(_kDeck), _elNoktasi(kim!), arka: kim != ben, ms: 520, w: kim == ben ? 60 : 34, scaleTo: kim == ben ? 1.25 : 1.2);
        await Future.delayed(const Duration(milliseconds: 120));
      case EvTip.mulk:
        await _ucur(e.card, _elNoktasi(kim!), _setNoktasi(kim), ms: 480, w: kim == ben ? 74 : 56);
      case EvTip.banka:
        await _ucur(e.card, _elNoktasi(kim!), _bankaNoktasi(kim), ms: 450, w: kim == ben ? 74 : 56);
      case EvTip.aksiyon:
        // elden ortaya büyüyerek gel, etiketle bekle, sonra atılanlara küçülerek git
        final merkez = _nokta(_kMerkez);
        await _ucur(e.card, _elNoktasi(kim!), merkez, ms: 420, w: 74, scaleTo: 1.7);
        if (!mounted) return;
        setState(() {
          _banner = '${kim == ben ? 'Sen' : 'Bot'}: ${e.etiket ?? e.card.ad}';
          _bannerKart = e.card;
        });
        await Future.delayed(Duration(milliseconds: kim == ben ? 700 : 1100));
        if (!mounted) return;
        setState(() {
          _banner = null;
          _bannerKart = null;
        });
        await _ucur(e.card, merkez, _nokta(_kDeck), ms: 300, w: 74, scaleTo: 0.5);
      case EvTip.transfer:
        final from = e.card.isProperty ? _setNoktasi(kim!) : (kim == ben ? _bankaNoktasi(ben) : _setNoktasi(bot));
        final to = e.card.isProperty ? _setNoktasi(e.kime!) : _bankaNoktasi(e.kime!);
        if (mounted) setState(() => _banner = '${e.etiket ?? 'Ödeme'}: ${e.card.ad} → ${e.kime!.name}');
        await _ucur(e.card, from, to, ms: 600, w: 64);
        if (mounted) setState(() => _banner = null);
    }
  }

  // ----------------------------------------------------------- bot / akış
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

  /// Her insan hamlesinden sonra: ekranı tazele, kazanan var mı bak, 3 hamle bittiyse turu otomatik bitir.
  Future<void> _sonra() async {
    if (mounted) setState(() {});
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
    if (c.isMoney) {
      secenekler.add(_Secenek('🏦 Bankaya koy (${c.value}M)', () => game.bankayaKoy(ben, c)));
    }
    if (c.isRent) {
      secenekler.add(_Secenek('💰 Kira iste', () => _kira(c)));
    }
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
    if (!c.isProperty && !c.isMoney) {
      secenekler.add(_Secenek('🏦 Bankaya koy (${c.paraDegeri}M)', () => game.bankayaKoy(ben, c)));
    }
    final sec = await showModalBottomSheet<_Secenek>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CardView(c, w: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.isAction ? c.action!.aciklama : c.ad,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
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

  Future<bool> _kira(GameCard c) async {
    final renkler = (c.isWildRent ? PColor.values : c.rentColors).where((k) => ben.propsOf(k).isNotEmpty).toList();
    if (renkler.isEmpty) {
      _mesaj('Bu renkte mülkün yok.');
      return false;
    }
    final renk = await pickColor(context, '💰 Hangi rengin kirası?', renkler,
        iptalOlur: true, altYazi: (k) => '— ${ben.kira(k)}M');
    if (renk == null) return false;
    GameCard? cift;
    final ciftKart = ben.hand.where((x) => x.action == ActionType.doubleRent).toList();
    if (ciftKart.isNotEmpty && game.playsLeft >= 2 && mounted) {
      if (await confirmDlg(context, '✖2 Çift Kira?',
          'Çift Kira kartını da oynayıp ${ben.kira(renk) * 2}M isteyeyim mi? (2 hamle harcar)',
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
    final sec = await pickCards(context, title: 'Hangi kira kartıyla?', cards: kiralar, exact: 1, max: 1, iptalOlur: true);
    if (sec.isEmpty) return false;
    final c = sec.first;
    final renkler = (c.isWildRent ? PColor.values : c.rentColors).where((k) => ben.propsOf(k).isNotEmpty).toList();
    if (renkler.isEmpty) {
      _mesaj('Bu renkte mülkün yok.');
      return false;
    }
    if (!mounted) return false;
    final renk = await pickColor(context, '💰 Hangi rengin kirası?', renkler,
        iptalOlur: true, altYazi: (k) => '— ${ben.kira(k) * 2}M (çift)');
    if (renk == null) return false;
    return game.kiraOyna(ben, c, renk, cift: cift);
  }

  Future<bool> _slyDeal(GameCard c) async {
    final hedefler = game.calinabilir(bot);
    if (hedefler.isEmpty) {
      _mesaj('Rakipte alınabilir tapu yok (tam setler korunur).');
      return false;
    }
    final sec = await pickCards(context, title: '🕵️ Hangi tapuyu alıyorsun?', cards: hedefler, exact: 1, max: 1, iptalOlur: true);
    if (sec.isEmpty) return false;
    return game.slyDeal(ben, c, sec.first);
  }

  Future<bool> _forcedDeal(GameCard c) async {
    final onunkiler = game.calinabilir(bot);
    final benimkiler = game.calinabilir(ben);
    if (onunkiler.isEmpty || benimkiler.isEmpty) {
      _mesaj('Değiş tokuş için iki tarafta da tamamlanmamış setten tapu olmalı.');
      return false;
    }
    final o = await pickCards(context, title: '🔁 Rakipten hangisini alıyorsun?', cards: onunkiler, exact: 1, max: 1, iptalOlur: true);
    if (o.isEmpty || !mounted) return false;
    final b = await pickCards(context, title: '🔁 Karşılığında hangisini veriyorsun?', cards: benimkiler, exact: 1, max: 1, iptalOlur: true);
    if (b.isEmpty) return false;
    return game.forcedDeal(ben, c, b.first, o.first);
  }

  Future<bool> _dealBreaker(GameCard c) async {
    final setler = bot.tamSetler;
    if (setler.isEmpty) {
      _mesaj('Rakibin tam seti yok.');
      return false;
    }
    final s = await pickColor(context, '💥 Hangi tam seti alıyorsun?', setler, iptalOlur: true);
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
    final s = await pickColor(context, '🏗️ Hangi sete?', setler, iptalOlur: true);
    if (s == null) return false;
    return game.binaKoy(ben, c, s);
  }

  Future<void> _turBitir() async {
    if (!_hazir || game.aktif != ben || game.kazanan != null || _botOynuyor) return;
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
              // uçan kartlar
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
              // orta etiket
              if (_banner != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                        child: Text(_banner!,
                            style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w800)),
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
            for (var i = 0; i < bot.hand.length.clamp(0, 8); i++)
              const Padding(padding: EdgeInsets.only(left: 2), child: CardBack(w: 16)),
            const SizedBox(width: 6),
            Text('${bot.hand.length} kart', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(width: 12),
          Text('🏦 ${bot.bankaToplam}M', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Container(key: _kBotSet, child: _setSatiri(bot, kucuk: true)),
      ]),
    );
  }

  Widget _ortaPanel(String durum) {
    final son = game.log.isEmpty ? '' : game.log.last;
    final ust = game.discard.isEmpty ? null : game.discard.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        // deste
        Column(key: _kDeck, mainAxisSize: MainAxisSize.min, children: [
          const CardBack(w: 34),
          Text('${game.deck.length}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
        const SizedBox(width: 6),
        // atılanlar / orta
        SizedBox(
          key: _kMerkez,
          width: 34,
          height: 34 * 1.45 + 14,
          child: ust == null ? const SizedBox() : Opacity(opacity: 0.85, child: CardView(ust, w: 34)),
        ),
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
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Setlerin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('Tam set: ${ben.tamSetSayisi}/3', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Container(key: _kBenSet, constraints: const BoxConstraints(minHeight: 40), child: _setSatiri(ben)),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Bankan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${ben.bankaToplam}M', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          SizedBox(
            key: _kBenBanka,
            height: 58,
            child: ben.bank.isEmpty
                ? const Align(alignment: Alignment.centerLeft, child: Text('boş', style: TextStyle(color: Colors.white38)))
                : ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in ben.bank) Padding(padding: const EdgeInsets.only(right: 4), child: CardView(c, w: 40)),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _setSatiri(Player p, {bool kucuk = false}) {
    if (p.props.isEmpty) {
      return Text('Henüz tapu yok', style: TextStyle(color: Colors.white38, fontSize: kucuk ? 11 : 13));
    }
    final renkler = PColor.values.where((c) => p.propsOf(c).isNotEmpty).toList();
    return Wrap(spacing: 6, runSpacing: 6, children: [for (final c in renkler) _setKutusu(p, c, kucuk)]);
  }

  Widget _setKutusu(Player p, PColor c, bool kucuk) {
    final n = p.propsOf(c).length;
    final tam = p.setTam(c);
    final binalar = p.binalar[c] ?? const <GameCard>[];
    final w = kucuk ? 30.0 : 42.0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: tam ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tam ? Colors.amber : Colors.white24, width: tam ? 2 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(backgroundColor: c.renk, radius: kucuk ? 5 : 6),
          const SizedBox(width: 4),
          Text('${c.ad} $n/${c.setBoyu}${tam ? ' ✓' : ''}',
              style: TextStyle(color: Colors.white, fontSize: kucuk ? 10 : 12, fontWeight: FontWeight.w700)),
          if (!kucuk) ...[
            const SizedBox(width: 6),
            Text('kira ${p.kira(c)}M', style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ]),
        if (!kucuk) const SizedBox(height: 3),
        if (!kucuk)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final k in p.propsOf(c))
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: CardView(k, w: w, onTap: (p == ben && k.isWild) ? () => _jokerTasi(k) : null),
              ),
            for (final b in binalar) Padding(padding: const EdgeInsets.only(right: 3), child: CardView(b, w: w)),
          ]),
        if (kucuk && binalar.isNotEmpty)
          Text(binalar.map((b) => b.action == ActionType.house ? '🏠' : '🏨').join(), style: const TextStyle(fontSize: 10)),
      ]),
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
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CardView(c, w: 74, dim: !_sirada, onTap: () => _kartTikla(c)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Secenek {
  _Secenek(this.baslik, this.calistir);
  final String baslik;
  final Future<bool> Function() calistir;
}
