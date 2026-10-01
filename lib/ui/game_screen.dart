import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import '../ai/bot.dart';
import '../model/cards.dart';
import '../model/game.dart';
import 'card_widget.dart';
import 'package:monodeal_cekirdek/aktarim.dart';
import '../net/istemci.dart';
import 'dialogs.dart';
import 'table_3d.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.botSayisi = 1, this.net, this.benIdx = 0, this.adlar = const [], this.botlar = const []});
  final int botSayisi; // 1..4 (yerel oyun)
  /// Online mod: sunucu bağlantısı; oyun motoru sunucuda, burası ayna + arayüz.
  final Istemci? net;
  final int benIdx;
  final List<String> adlar;
  final List<bool> botlar;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

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
  late final _GameDinleyici _dinleyici;
  late final Player ben;
  late final List<Player> botlar;
  final BotDecider _botAi = BotDecider();
  bool _botOynuyor = false;
  bool _bittiGosterildi = false;
  bool _hazir = false;
  String? _acikDeste;

  final _kStack = GlobalKey();
  final _kDeck = GlobalKey();
  final _kMerkez = GlobalKey();
  final _kBenEl = GlobalKey();
  final _kBenSet = GlobalKey();
  final _kBenBanka = GlobalKey();
  final Map<Player, GlobalKey> _kBotEl = {};
  final Map<Player, GlobalKey> _kBotSet = {};
  final List<_Ucan> _ucanlar = [];
  final List<MasaUcus> _masaUcanlar = [];
  final _kMasa = GlobalKey();
  String? _banner;
  Player? _konusan;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _klip = AudioPlayer();
  Map<String, dynamic> _klipler = const {};
  bool _sesli = true;
  bool _ttsHazir = false;
  final Map<Player, Map<String, String>> _sesler = {};
  final Map<Player, double> _perde = {};

  bool get _online => widget.net != null;
  StreamSubscription? _netAbone;
  Future<void> _olayKuyrugu = Future.value();
  bool _turBitiyor = false;
  late final HumanDecider _insan = HumanDecider(() => context);

  @override
  void initState() {
    super.initState();
    if (_online) {
      final oy = [
        for (var i = 0; i < widget.adlar.length; i++)
          Player(widget.adlar[i], isBot: widget.botlar[i], decider: i == widget.benIdx ? _insan : _botAi),
      ];
      ben = oy[widget.benIdx];
      botlar = [for (final p in oy) if (p != ben) p];
      game = Game(players: oy);
    } else {
      ben = Player('Sen', isBot: false, decider: _insan);
      final n = widget.botSayisi.clamp(1, 4);
      botlar = [for (var i = 1; i <= n; i++) Player(n == 1 ? 'Bot' : 'Bot $i', isBot: true, decider: _botAi)];
      game = Game(players: [ben, ...botlar]);
    }
    for (final b in botlar) {
      _kBotEl[b] = GlobalKey();
      _kBotSet[b] = GlobalKey();
    }
    _dinleyici = _GameDinleyici(game);
    game.animator = _animasyon;
    game.sozcu = _konus;
    game.sozBekle = _sozBekle;
    _ttsKur();
    _klipleriYukle();
    if (_online) {
      _netAbone = widget.net!.mesajlar.listen(_netMesaj);
      widget.net!.koptu.listen((_) {
        if (mounted) _mesaj('Sunucu bağlantısı koptu.');
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await game.baslat();
      if (!mounted) return;
      setState(() => _hazir = true);
      _botKontrol();
    });
  }

  // ----------------------------------------------------------- online
  void _netMesaj(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'durum':
        durumYukle(game, Map<String, dynamic>.from(m['d'] as Map));
        if (!_hazir) setState(() => _hazir = true);
        _bitisKontrol();
        // hamle hakkı bitince tur kendiliğinden biter (yerel moddaki _sonra ile aynı)
        if (game.kazanan == null && game.aktif == ben && game.playsLeft <= 0 && !_turBitiyor) {
          _turBitiyor = true;
          Future.delayed(const Duration(milliseconds: 700), () async {
            if (mounted && game.aktif == ben && game.playsLeft <= 0) await _turBitir();
            _turBitiyor = false;
          });
        }
      case 'olay':
        final e = olayOku(game, Map<String, dynamic>.from(m['o'] as Map));
        _olayKuyrugu = _olayKuyrugu.then((_) => _animasyon(e));
      case 'soz':
        _konus(game.players[m['kim'] as int], m['soz'] as String);
      case 'sor':
        _soruyaCevap(m);
      case 'hata':
        _mesaj(m['m'] as String? ?? 'Hata');
      case 'bitti':
        _bitisKontrol();
    }
  }

  Future<void> _soruyaCevap(Map<String, dynamic> m) async {
    final id = m['id'] as int;
    dynamic deger;
    try {
      // açık diyalog/animasyon varsa önce o bitsin
      await _olayKuyrugu;
      switch (m['tur']) {
        case 'justSayNo':
          deger = await _insan.justSayNo(game, ben, m['aciklama'] as String);
        case 'ode':
          final l = await _insan.ode(game, ben, m['tutar'] as int, game.players[m['alacakli'] as int]);
          deger = [for (final c in l) c.id];
        case 'odemeKarari':
          final k = await _insan.odemeKarari(game, ben, m['tutar'] as int, game.players[m['alacakli'] as int], m['aciklama'] as String,
              reddedebilir: m['reddedebilir'] as bool);
          deger = {'reddet': k.reddet, 'kartlar': [for (final c in k.kartlar) c.id]};
        case 'jokerRengi':
          final sec = [for (final i in (m['secenekler'] as List)) PColor.values[i as int]];
          final kart = kartBul(game, m['kart'] as int) ?? ben.hand.first;
          deger = (await _insan.jokerRengi(game, ben, kart, sec)).index;
        case 'atilacaklar':
          final l = await _insan.atilacaklar(game, ben, m['adet'] as int);
          deger = [for (final c in l) c.id];
      }
    } catch (_) {
      deger = null;
    }
    widget.net?.gonder({'t': 'karar', 'id': id, 'deger': deger});
  }

  /// Hamle: online ise sunucuya gönderir (sonuç durum mesajıyla gelir), değilse yerel motoru çağırır.
  Future<bool> _yap(String tip, Map<String, dynamic> veri, Future<bool> Function() yerel) async {
    if (_online) {
      widget.net!.gonder({'t': 'hamle', 'tip': tip, ...veri});
      return true;
    }
    return yerel();
  }

  @override
  void dispose() {
    _tts.stop();
    _klip.dispose();
    _dinleyici.dispose();
    _netAbone?.cancel();
    widget.net?.kapat();
    for (final u in _ucanlar) {
      u.ctl.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------- konuşma / ses
  Future<void> _klipleriYukle() async {
    try {
      final j = await rootBundle.loadString('assets/ses/manifest.json');
      _klipler = json.decode(j) as Map<String, dynamic>;
    } catch (_) {}
  }

  /// Gemini ile önceden üretilmiş klip (oyuncu sırası|cümle). Yoksa null.
  String? _klipAdi(Player p, String soz) {
    final i = game.players.indexOf(p);
    final v = _klipler['$i|$soz'];
    return v is String ? v : null;
  }

  Future<bool> _klipCal(String ad) async {
    try {
      final bitti = _klip.onPlayerComplete.first;
      await _klip.play(AssetSource('ses/$ad'));
      await bitti.timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ttsKur() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      final sesler = <Map<String, String>>[];
      try {
        final v = await _tts.getVoices;
        if (v is List) {
          for (final e in v) {
            if (e is Map && '${e['locale']}'.toLowerCase().startsWith('tr')) {
              sesler.add({'name': '${e['name']}', 'locale': '${e['locale']}'});
            }
          }
        }
      } catch (_) {}
      // Her oyuncuya farklı ses; ses yoksa perde ile ayır.
      const perdeler = [1.0, 0.8, 1.25, 0.9, 1.1];
      for (var i = 0; i < game.players.length; i++) {
        final p = game.players[i];
        _perde[p] = perdeler[i % perdeler.length];
        if (sesler.isNotEmpty) _sesler[p] = sesler[i % sesler.length];
      }
      _ttsHazir = true;
    } catch (_) {}
  }

  Future<void> _sonSoz = Future.value();
  int _sozSayac = 0;

  /// Konuşmayı başlatır ve hemen döner (hamle beklemez); sözler sırayla kuyruklanır.
  Future<void> _konus(Player p, String soz) async {
    if (!mounted) return;
    final no = ++_sozSayac;
    _sonSoz = _sonSoz.then((_) => _seslendir(p, soz, no));
  }

  Future<void> _sozBekle() => _sonSoz;

  Future<void> _seslendir(Player p, String soz, int no) async {
    if (!mounted) return;
    setState(() {
      _konusan = p;
      _banner = soz;
    });
    final klip = _klipAdi(p, soz);
    if (_sesli && klip != null && await _klipCal(klip)) {
      // önceden üretilmiş doğal ses çalındı
    } else if (_sesli && _ttsHazir) {
      try {
        final v = _sesler[p];
        if (v != null) await _tts.setVoice(v);
        await _tts.setPitch(_perde[p] ?? 1.0);
        await _tts.speak(soz.replaceAllMapped(RegExp(r'(\d+)M'), (m) => '${m[1]} milyon')).timeout(const Duration(seconds: 8));
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 900));
      }
    } else {
      await Future.delayed(Duration(milliseconds: 500 + soz.length * 35));
    }
    if (mounted && no == _sozSayac) {
      setState(() {
        _banner = null;
        _konusan = null;
      });
    }
  }

  // ----------------------------------------------------------- animasyon
  Offset _nokta(GlobalKey? k, {Offset fallback = const Offset(200, 400)}) {
    final stackBox = _kStack.currentContext?.findRenderObject() as RenderBox?;
    final box = k?.currentContext?.findRenderObject() as RenderBox?;
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

  /// Bir anahtarın merkezini MASA koordinatlarına çevirir (masa içindeyse doğrudan,
  /// dışındaysa -elim gibi- perspektiften geri yansıtarak).
  Offset _masaNokta(GlobalKey? k, {Offset fallback = const Offset(550, 900)}) {
    final masaBox = _kMasa.currentContext?.findRenderObject() as RenderBox?;
    final box = k?.currentContext?.findRenderObject() as RenderBox?;
    if (masaBox == null || box == null || !box.hasSize) return fallback;
    final merkez = box.size.center(Offset.zero);
    RenderObject? r = box;
    while (r != null && r != masaBox) {
      r = r.parent;
    }
    if (r == masaBox) return box.localToGlobal(merkez, ancestor: masaBox);
    return masaBox.globalToLocal(box.localToGlobal(merkez));
  }

  Future<void> _masaUcur(GameCard card, Offset from, Offset to, {bool arka = false, int ms = 480, double w = 56, double scaleTo = 1}) async {
    if (!mounted) return;
    final ctl = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    final u = MasaUcus(card: card, arka: arka, ctl: ctl, from: from, to: to, w: w, scaleTo: scaleTo);
    setState(() => _masaUcanlar.add(u));
    try {
      await ctl.forward();
    } finally {
      if (mounted) setState(() => _masaUcanlar.remove(u));
      ctl.dispose();
    }
  }

  Offset _elNoktasi(Player p) => p == ben ? _nokta(_kBenEl) : _nokta(_kBotEl[p]);

  Future<void> _animasyon(GameEvent e) async {
    if (!mounted) return;
    if (_acikDeste != null) setState(() => _acikDeste = null);
    final kim = e.kim;
    final adim = kim == ben ? 'Sen' : kim?.name ?? '';
    Offset elM(Player p) => _masaNokta(p == ben ? _kBenEl : _kBotEl[p]);
    Offset setM(Player p) => _masaNokta(p == ben ? _kBenSet : _kBotSet[p]);
    Offset bankaM(Player p) => _masaNokta(p == ben ? _kBenBanka : _kBotSet[p]);
    final deste = _masaNokta(_kDeck), yakilan = _masaNokta(_kMerkez);
    switch (e.tip) {
      case EvTip.cek:
        if (kim == ben) {
          // desteden elime: masadan çıkıp 2B ele iner
          await _ucur(e.card, _nokta(_kDeck), _elNoktasi(kim!), ms: 520, w: 60, scaleTo: 1.25);
        } else {
          await _masaUcur(e.card, deste, elM(kim!), arka: true, ms: 480, w: 40, scaleTo: 0.5);
        }
        await Future.delayed(const Duration(milliseconds: 120));
      case EvTip.mulk:
        await _masaUcur(e.card, elM(kim!), setM(kim), ms: 520, w: kim == ben ? 56 : 46);
      case EvTip.banka:
        await _masaUcur(e.card, elM(kim!), bankaM(kim), ms: 480, w: kim == ben ? 56 : 46);
      case EvTip.aksiyon:
        final orta = Offset((deste.dx + yakilan.dx) / 2, deste.dy - 90);
        await _masaUcur(e.card, elM(kim!), orta, ms: 460, w: 56, scaleTo: 1.8);
        if (!mounted) return;
        setState(() => _banner = '$adim: ${e.etiket ?? e.card.ad}');
        await Future.delayed(Duration(milliseconds: kim == ben ? 700 : 1100));
        if (!mounted) return;
        setState(() => _banner = null);
        await _masaUcur(e.card, orta, yakilan, ms: 320, w: 100, scaleTo: 0.64);
      case EvTip.transfer:
        final from = e.card.isProperty ? setM(kim!) : bankaM(kim!);
        final to = e.card.isProperty ? setM(e.kime!) : bankaM(e.kime!);
        if (mounted) setState(() => _banner = '${e.etiket ?? 'Ödeme'}: ${e.card.ad} → ${e.kime!.name}');
        await _masaUcur(e.card, from, to, ms: 650, w: 50);
        if (mounted) setState(() => _banner = null);
    }
  }

  // ----------------------------------------------------------- akış
  /// Sıradaki(ler) botsa sırayla oynatır; sıra insana gelince durur.
  Future<void> _botKontrol() async {
    if (_botOynuyor || _online) return;
    _botOynuyor = true;
    if (mounted) setState(() {});
    try {
      while (game.kazanan == null && game.aktif.isBot && mounted) {
        await _botAi.turOyna(game, game.aktif);
        if (mounted) setState(() {});
      }
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
          title: Text(k == ben ? '🏆 Kazandın!' : '😔 ${k.name} kazandı'),
          content: Text('${k.name} 3 tam set topladı: ${k.tamSetler.map((c) => c.ad).join(', ')}.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst), child: const Text('Menüye dön')),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (_online) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  return;
                }
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(botSayisi: widget.botSayisi)));
              },
              child: const Text('Yeni oyun'),
            ),
          ],
        ),
      );
    });
  }

  bool get _sirada => _hazir && game.aktif == ben && game.kazanan == null && !_botOynuyor && _ucanlar.isEmpty && _masaUcanlar.isEmpty;

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

  List<Player> get _rakipler => game.rakipler(ben);

  // ----------------------------------------------------------- oynanabilirlik (soluk gösterim)
  List<GameCard> _tumCalinabilir() => [for (final r in _rakipler) ...game.calinabilir(r)];

  List<PColor> _kiraRenkleri(GameCard c) =>
      (c.isWildRent ? PColor.values : c.rentColors).where((k) => ben.propsOf(k).isNotEmpty).toList();

  List<PColor> _binaSetleri(GameCard c) => ben.tamSetler.where((s) {
        if (!s.binaOlur) return false;
        final m = ben.binalar[s] ?? const <GameCard>[];
        final ev = m.any((b) => b.action == ActionType.house);
        final otel = m.any((b) => b.action == ActionType.hotel);
        return c.action == ActionType.house ? !ev : (ev && !otel);
      }).toList();

  /// Kartın ASIL işlevi şu an oynanabilir mi? (Bankaya koymak her zaman mümkün, o sayılmaz.)
  bool _oynanabilir(GameCard c) {
    if (c.isMoney || c.isProperty) return true;
    if (c.isRent) return _kiraRenkleri(c).isNotEmpty;
    final rakipVarlik = _rakipler.any((r) => r.varliklar.isNotEmpty);
    switch (c.action!) {
      case ActionType.passGo:
        return true;
      case ActionType.tahsilat:
      case ActionType.birthday:
        return rakipVarlik;
      case ActionType.slyDeal:
        return _tumCalinabilir().isNotEmpty;
      case ActionType.forcedDeal:
        return _tumCalinabilir().isNotEmpty && game.calinabilir(ben).isNotEmpty;
      case ActionType.dealBreaker:
        return _rakipler.any((r) => r.tamSetler.isNotEmpty);
      case ActionType.house:
      case ActionType.hotel:
        return _binaSetleri(c).isNotEmpty;
      case ActionType.doubleRent:
        return game.playsLeft >= 2 && ben.hand.any((k) => k.isRent && _kiraRenkleri(k).isNotEmpty);
      case ActionType.justSayNo:
        return false;
    }
  }

  // ----------------------------------------------------------- kart tıklama
  Future<void> _kartTikla(GameCard c) async {
    if (!_sirada) return _mesaj('Sıra sende değil.');
    if (game.playsLeft <= 0) return _mesaj('Hamle hakkın bitti.');
    if (c.isProperty || c.isMoney) {
      final ok = c.isMoney
          ? await _yap('banka', {'kart': c.id}, () => game.bankayaKoy(ben, c))
          : await _yap('mulk', {'kart': c.id}, () => game.mulkOyna(ben, c));
      if (!ok && mounted) _mesaj('Bu hamle yapılamadı.');
      return _sonra();
    }
    final aktif = _oynanabilir(c);
    final secenekler = <_Secenek>[];
    if (c.isRent) secenekler.add(_Secenek('💰 Kira iste', () => _kira(c), aktif: aktif));
    if (c.isAction) {
      final a = c.action!;
      switch (a) {
        case ActionType.passGo:
          secenekler.add(_Secenek('▶ 2 Kart Çek', () => _yap('passGo', {'kart': c.id}, () => game.passGo(ben, c))));
        case ActionType.tahsilat:
          secenekler.add(_Secenek('💵 Tahsilat: 5M al', () => _tahsilat(c), aktif: aktif));
        case ActionType.birthday:
          secenekler.add(_Secenek('🎂 Doğum Günüm: herkesten 2M', () => _yap('dogumGunu', {'kart': c.id}, () => game.dogumGunu(ben, c)), aktif: aktif));
        case ActionType.slyDeal:
          secenekler.add(_Secenek('🕵️ Tapu Devri: rakipten tapu al', () => _slyDeal(c), aktif: aktif));
        case ActionType.forcedDeal:
          secenekler.add(_Secenek('🔁 Değiş Tokuş: tapu takası', () => _forcedDeal(c), aktif: aktif));
        case ActionType.dealBreaker:
          secenekler.add(_Secenek('💥 Haciz: tam seti al', () => _dealBreaker(c), aktif: aktif));
        case ActionType.house:
        case ActionType.hotel:
          secenekler.add(_Secenek('🏗️ ${a.ad} koy (tam sete)', () => _bina(c), aktif: aktif));
        case ActionType.doubleRent:
          secenekler.add(_Secenek('✖2 Çift kira (kira kartıyla)', () => _ciftKira(c), aktif: aktif));
        case ActionType.justSayNo:
          secenekler.add(_Secenek('ℹ️ Sadece savunmada oynanır', () async {
            _mesaj('Reddet kartı, rakip sana aksiyon oynayınca sorulur.');
            return false;
          }, aktif: false));
      }
    }
    secenekler.add(_Secenek('🏦 Bankaya koy (${c.paraDegeri}M para olur)', () => _yap('banka', {'kart': c.id}, () => game.bankayaKoy(ben, c))));
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
          for (final s in secenekler)
            ListTile(
              enabled: s.aktif,
              title: Text(s.baslik, style: TextStyle(color: s.aktif ? null : Colors.grey)),
              subtitle: s.aktif ? null : const Text('şu an oynanamaz', style: TextStyle(fontSize: 11)),
              onTap: s.aktif ? () => Navigator.pop(ctx, s) : null,
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (sec == null) return;
    final ok = await sec.calistir();
    if (!ok && mounted) _mesaj('Bu hamle yapılamadı.');
    await _sonra();
  }

  Future<PColor?> _renkSec(String baslik, List<PColor> renkler, {String Function(PColor)? altYazi}) async {
    if (renkler.length == 1) return renkler.first;
    return pickColor(context, baslik, renkler, iptalOlur: true, altYazi: altYazi);
  }

  /// Rakipler arasından seçtirir (tek rakip varsa sormaz).
  Future<Player?> _rakipSec(String baslik, List<Player> adaylar, {String Function(Player)? altYazi}) async {
    if (adaylar.length == 1) return adaylar.first;
    return showDialog<Player>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik, style: const TextStyle(fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in adaylar)
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: Text(r.name),
              subtitle: Text(altYazi == null ? '🏦 ${r.bankaToplam}M · varlık ${r.varlikToplam}M' : altYazi(r)),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Vazgeç'))],
      ),
    );
  }

  /// Rakip kartlarından seçtirir; birden fazla rakip varsa oyuncuya göre gruplar.
  Future<GameCard?> _rakipKartiSec(String baslik, Map<Player, List<GameCard>> gruplar) async {
    final hepsi = [for (final l in gruplar.values) ...l];
    if (hepsi.length == 1) return hepsi.first;
    final r = await pickCardsEx(context,
        title: baslik,
        cards: hepsi,
        exact: 1,
        max: 1,
        iptalOlur: true,
        gruplar: gruplar.length == 1 ? null : {for (final e in gruplar.entries) if (e.value.isNotEmpty) '🤖 ${e.key.name}': e.value});
    return r.kartlar.isEmpty ? null : r.kartlar.first;
  }

  Future<GameCard?> _kartSec(String baslik, List<GameCard> kartlar) async {
    if (kartlar.length == 1) return kartlar.first;
    final s = await pickCards(context, title: baslik, cards: kartlar, exact: 1, max: 1, iptalOlur: true);
    return s.isEmpty ? null : s.first;
  }

  Future<bool> _tahsilat(GameCard c) async {
    final adaylar = _rakipler.where((r) => r.varliklar.isNotEmpty).toList();
    if (adaylar.isEmpty) {
      _mesaj('Kimsenin ödeyecek bir şeyi yok.');
      return false;
    }
    final r = await _rakipSec('💵 Kimden 5M?', adaylar);
    if (r == null) return false;
    return _yap('tahsilat', {'kart': c.id, 'hedef': game.players.indexOf(r)}, () => game.tahsilat(ben, c, r));
  }

  Future<bool> _kira(GameCard c) async {
    final renkler = _kiraRenkleri(c);
    if (renkler.isEmpty) {
      _mesaj('Bu renkte tapun yok.');
      return false;
    }
    // En yüksek kirayı veren renk otomatik seçilir, sorulmaz.
    final renk = renkler.reduce((x, y) => ben.kira(y) > ben.kira(x) ? y : x);
    GameCard? cift;
    final ciftKart = ben.hand.where((x) => x.action == ActionType.doubleRent).toList();
    if (ciftKart.isNotEmpty && game.playsLeft >= 2 && mounted) {
      if (await confirmDlg(context, '✖2 Çift Kira?', 'Çift Kira kartını da oynayıp ${ben.kira(renk) * 2}M isteyeyim mi? (2 hamle harcar)',
          evet: 'Evet, çift', hayir: 'Hayır, tek')) {
        cift = ciftKart.first;
      }
    }
    return _yap('kira', {'kart': c.id, 'renk': renk.index, if (cift != null) 'cift': cift.id}, () => game.kiraOyna(ben, c, renk, cift: cift));
  }

  Future<bool> _ciftKira(GameCard cift) async {
    final kiralar = ben.hand.where((x) => x.isRent && _kiraRenkleri(x).isNotEmpty).toList();
    if (kiralar.isEmpty) {
      _mesaj('Oynanabilir kira kartın yok.');
      return false;
    }
    if (game.playsLeft < 2) {
      _mesaj('Çift kira için 2 hamle gerekir.');
      return false;
    }
    final c = await _kartSec('Hangi kira kartıyla?', kiralar);
    if (c == null || !mounted) return false;
    final renk = _kiraRenkleri(c).reduce((x, y) => ben.kira(y) > ben.kira(x) ? y : x);
    return _yap('kira', {'kart': c.id, 'renk': renk.index, 'cift': cift.id}, () => game.kiraOyna(ben, c, renk, cift: cift));
  }

  Future<bool> _slyDeal(GameCard c) async {
    final gruplar = {for (final r in _rakipler) r: game.calinabilir(r)};
    if (gruplar.values.every((l) => l.isEmpty)) {
      _mesaj('Rakiplerde alınabilir tapu yok (tam setler korunur).');
      return false;
    }
    final h = await _rakipKartiSec('🕵️ Hangi tapuyu alıyorsun?', gruplar);
    if (h == null) return false;
    return _yap('slyDeal', {'kart': c.id, 'hedefKart': h.id}, () => game.slyDeal(ben, c, h));
  }

  Future<bool> _forcedDeal(GameCard c) async {
    final gruplar = {for (final r in _rakipler) r: game.calinabilir(r)};
    final benimkiler = game.calinabilir(ben);
    if (gruplar.values.every((l) => l.isEmpty) || benimkiler.isEmpty) {
      _mesaj('Değiş tokuş için iki tarafta da tamamlanmamış setten tapu olmalı.');
      return false;
    }
    final o = await _rakipKartiSec('🔁 Rakipten hangisini alıyorsun?', gruplar);
    if (o == null || !mounted) return false;
    final b = await _kartSec('🔁 Karşılığında hangisini veriyorsun?', benimkiler);
    if (b == null) return false;
    return _yap('forcedDeal', {'kart': c.id, 'benim': b.id, 'onun': o.id}, () => game.forcedDeal(ben, c, b, o));
  }

  Future<bool> _dealBreaker(GameCard c) async {
    final adaylar = _rakipler.where((r) => r.tamSetler.isNotEmpty).toList();
    if (adaylar.isEmpty) {
      _mesaj('Rakiplerin tam seti yok.');
      return false;
    }
    final r = await _rakipSec('💥 Kimin setini alıyorsun?', adaylar, altYazi: (p) => 'tam set: ${p.tamSetler.map((s) => s.ad).join(', ')}');
    if (r == null || !mounted) return false;
    final s = await _renkSec('💥 Hangi tam seti?', r.tamSetler);
    if (s == null) return false;
    return _yap('dealBreaker', {'kart': c.id, 'hedef': game.players.indexOf(r), 'set': s.index}, () => game.dealBreaker(ben, c, r, s));
  }

  Future<bool> _bina(GameCard c) async {
    final setler = _binaSetleri(c);
    if (setler.isEmpty) {
      _mesaj(c.action == ActionType.house ? 'Evsiz tam setin yok.' : 'Evli (otelsiz) tam setin yok.');
      return false;
    }
    final s = await _renkSec('🏗️ Hangi sete?', setler);
    if (s == null) return false;
    return _yap('bina', {'kart': c.id, 'set': s.index}, () => game.binaKoy(ben, c, s));
  }

  Future<void> _turBitir() async {
    if (!_hazir || game.aktif != ben || game.kazanan != null || _botOynuyor) return;
    setState(() => _acikDeste = null);
    if (_online) {
      widget.net!.gonder({'t': 'hamle', 'tip': 'turBitir'});
      return;
    }
    await game.turBitir();
    if (mounted) setState(() {});
    _botKontrol();
  }

  Future<void> _jokerTasi(GameCard c) async {
    if (!_sirada) return;
    await _yap('joker', {'kart': c.id}, () => game.jokerRengiDegistir(ben, c));
    await _sonra();
  }

  // ----------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dinleyici,
      builder: (context, _) {
        final durum = !_hazir
            ? 'Kartlar dağıtılıyor…'
            : game.kazanan != null
                ? 'Oyun bitti'
                : (_botOynuyor || (_online && game.aktif != ben))
                    ? '${game.aktif.name} oynuyor…'
                    : game.aktif == ben
                        ? 'Sıra sende · ${game.playsLeft} hamle'
                        : '${game.aktif.name}…';
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E3A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D25),
            foregroundColor: Colors.white,
            title: Text('Monopoly Deal · ${game.players.length} oyuncu', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            actions: [
              IconButton(
                tooltip: _sesli ? 'Sesi kapat' : 'Sesi aç',
                onPressed: () => setState(() {
                  _sesli = !_sesli;
                  if (!_sesli) {
                    _tts.stop();
                    _klip.stop();
                  }
                }),
                icon: Icon(_sesli ? Icons.record_voice_over : Icons.voice_over_off),
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(key: _kStack, children: [
              Column(children: [
                Expanded(
                  child: Table3D(
                    game: game,
                    ben: ben,
                    seat: (p) => _desteler(p, kucuk: p != ben),
                    deckKey: _kDeck,
                    discardKey: _kMerkez,
                    handKeys: _kBotEl,
                    tableKey: _kMasa,
                    ucanlar: _masaUcanlar,
                    ustBilgi: _durumSeridi(durum),
                  ),
                ),
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
                    child: Align(
                      alignment: const Alignment(0, -0.55),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _konusan == null ? Colors.black87 : (_konusan == ben ? const Color(0xFF1E7B3A) : const Color(0xFF263B6B)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (_konusan != null)
                            Text(_konusan == ben ? 'Sen' : _konusan!.name, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(_banner!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
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

  Widget _durumSeridi(String durum) {
    final son = game.log.isEmpty ? '' : game.log.last;
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(durum, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(son, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        Text('Tam set ${ben.tamSetSayisi}/3', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        IconButton(
          tooltip: 'Turu bitir',
          color: _sirada ? Colors.amber : Colors.white24,
          onPressed: _sirada ? _turBitir : null,
          icon: const Icon(Icons.skip_next, size: 28),
        ),
      ]),
    );
  }

  Widget _desteler(Player p, {bool kucuk = false}) {
    final renkler = PColor.values.where((c) => p.propsOf(c).isNotEmpty).toList();
    final kim = p == ben ? 'ben' : p.name;
    final w = kucuk ? 38.0 : 46.0;
    if (renkler.isEmpty && p.bank.isEmpty) {
      return Text('Henüz kart yok', style: TextStyle(color: Colors.white38, fontSize: kucuk ? 11 : 13));
    }
    final banka = KeyedSubtree(
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
    );
    final ogeler = <Widget>[
      banka,
      for (final c in renkler)
        _Deste(
          kartlar: [...p.propsOf(c), ...(p.binalar[c] ?? const <GameCard>[])],
          w: w,
          acik: _acikDeste == '$kim:${c.name}',
          ustBaslik: '${c.kisaAd} ${p.propsOf(c).length}/${c.setBoyu}${p.setTam(c) ? ' ✓' : ''}',
          altBaslik: 'kira ${p.kira(c)}M',
          vurgu: p.setTam(c),
          renk: c.renk,
          onTap: () => setState(() => _acikDeste = _acikDeste == '$kim:${c.name}' ? null : '$kim:${c.name}'),
          onKartTap: p == ben ? (k) => k.isWild ? _jokerTasi(k) : null : null,
        ),
    ];
    return Container(
      key: p == ben ? _kBenSet : _kBotSet[p],
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
              Padding(
                padding: const EdgeInsets.only(right: 6),
                // Sıra sende değilse ya da kartın asıl işlevi şu an mümkün değilse soluk
                child: CardView(c, w: 74, dim: !_sirada || !_oynanabilir(c), onTap: () => _kartTikla(c)),
              ),
          ]),
        ),
      ]),
    );
  }
}

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
  _Secenek(this.baslik, this.calistir, {this.aktif = true});
  final String baslik;
  final Future<bool> Function() calistir;
  final bool aktif;
}

/// Motor Flutter'dan bağımsız; UI için ChangeNotifier köprüsü.
class _GameDinleyici extends ChangeNotifier {
  _GameDinleyici(this.game) {
    game.addListener(notifyListeners);
  }
  final Game game;
  @override
  void dispose() {
    game.removeListener(notifyListeners);
    super.dispose();
  }
}
