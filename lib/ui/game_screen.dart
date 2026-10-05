import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle, SystemChrome, SystemUiMode;
import '../ai/bot.dart';
import '../model/cards.dart';
import '../model/game.dart';
import 'card_widget.dart';
import 'package:emlakdeal_cekirdek/aktarim.dart';
import 'dart:io';
import '../ayarlar.dart';
import '../dil.dart';
import '../dil/soz.dart' show sozEn;
import '../ses_servis.dart';
import '../basarimlar.dart';
import '../hesap.dart';
import '../izleme.dart';
import 'package:emlakdeal_cekirdek/seviye.dart';
import '../net/istemci.dart';
import 'dialogs.dart';
import 'guvenlik.dart';
import 'table_3d.dart';
import 'sayac.dart';
import 'konfeti.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.botSayisi = 1, this.net, this.benIdx = 0, this.adlar = const [], this.botlar = const [], this.avatarlar = const [], this.leveller = const [], this.sesler = const [], this.kayit, this.bahis = 0, this.havuz = 0});
  /// Bahisli online oda: kişi başı bahis ve toplam havuz (altın).
  final int bahis;
  final int havuz;
  final List<String> avatarlar;
  final List<int> leveller;
  final List<int> sesler;
  /// Kaydedilmiş tek kişilik oyun (devam et).
  final Map<String, dynamic>? kayit;
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Game game;
  late final _GameDinleyici _dinleyici;
  late final Player ben;
  late final List<Player> botlar;
  late final BotDecider _botAi = BotDecider(zorluk: Ayarlar.o.botZorluk);
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
  final AudioPlayer _klip = AudioPlayer();
  final AudioPlayer _sohbetKlip = AudioPlayer();
  final AudioPlayer _efekt = AudioPlayer();
  final AudioPlayer _efekt2 = AudioPlayer();
  final _sohbetYazi = TextEditingController();
  final List<(Player, String)> _sohbetGecmis = [];
  (Player, String)? _sohbetBalon;
  int _sohbetNo = 0;
  Map<String, dynamic> _klipler = const {};
  bool _sesli = Ayarlar.o.sesli;

  bool get _online => widget.net != null;
  StreamSubscription? _netAbone;
  Future<void> _olayKuyrugu = Future.value();
  bool _turBitiyor = false;
  DateTime? _sureBitis;
  Timer? _sayacTik;
  int _benimTurum = 0;
  int _sonSira = -1;
  late final HumanDecider _insan = HumanDecider(() => context);
  final Map<Player, (String, int)> _profiller = {};
  final Map<Player, int> _sesNo = {};
  Map<String, dynamic>? _odul;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_online) {
      final oy = [
        for (var i = 0; i < widget.adlar.length; i++)
          Player(widget.adlar[i], isBot: widget.botlar[i], decider: i == widget.benIdx ? _insan : _botAi),
      ];
      ben = oy[widget.benIdx];
      botlar = [for (final p in oy) if (p != ben) p];
      game = Game(players: oy);
      for (var i = 0; i < oy.length; i++) {
        _profiller[oy[i]] = (i < widget.avatarlar.length ? widget.avatarlar[i] : (oy[i].isBot ? '🤖' : '🙂'), i < widget.leveller.length ? widget.leveller[i] : 1);
        _sesNo[oy[i]] = i < widget.sesler.length ? widget.sesler[i] : i % sesAdlari.length;
      }
    } else if (widget.kayit != null) {
      final oy = widget.kayit!['oyuncular'] as List;
      ben = Player((oy[0] as Map)['ad'] as String, isBot: false, decider: _insan);
      botlar = [for (var i = 1; i < oy.length; i++) Player((oy[i] as Map)['ad'] as String, isBot: true, decider: _botAi)];
      game = Game(players: [ben, ...botlar]);
      final rng = Random();
      for (final b in botlar) {
        _profiller[b] = (avatarlar[rng.nextInt(avatarlar.length)], 1 + rng.nextInt(12));
      }
      _botSesAta();
    } else {
      ben = Player(Hesap.o.nick, isBot: false, decider: _insan);
      final n = widget.botSayisi.clamp(1, 4);
      final rng = Random();
      final adlar = List.of(botAdlari)..shuffle(rng);
      adlar.removeWhere((a) => a.toLowerCase() == Hesap.o.nick.toLowerCase());
      botlar = [for (var i = 0; i < n; i++) Player(adlar[i], isBot: true, decider: _botAi)];
      game = Game(players: [ben, ...botlar]);
      for (final b in botlar) {
        _profiller[b] = (avatarlar[rng.nextInt(avatarlar.length)], 1 + rng.nextInt(12));
      }
      _botSesAta();
    }
    _profiller[ben] = (Hesap.o.avatar, Hesap.o.level);
    for (final b in botlar) {
      _kBotEl[b] = GlobalKey();
      _kBotSet[b] = GlobalKey();
    }
    _dinleyici = _GameDinleyici(game);
    game.animator = _animasyon;
    game.sozcu = _konus;
    game.sozBekle = _sozBekle;
    _klipleriYukle();
    kartArkasiStili = Hesap.o.kartArkasi;
    Muzik.o.guncelle();
    Izleme.o.olay('oyun_basladi', {'mod': _online ? 'online' : 'bot', 'oyuncu': widget.adlar.isNotEmpty ? widget.adlar.length : widget.botSayisi + 1, 'devam': widget.kayit != null});
    if (_online) {
      _netAbone = widget.net!.mesajlar.listen(_netMesaj);
      Hesap.o.engelleriYukle().catchError((_) => <Map<String, dynamic>>[]);
      widget.net!.koptu.listen((_) {
        if (mounted) _mesaj(t('Sunucu bağlantısı koptu.'));
      });
      return;
    }
    // tek kişilik oyun: her değişiklikte kaydet (uygulama kapanınca devam edilebilir)
    game.addListener(_kaydet);
    game.addListener(_turTakip);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.kayit != null) {
        kayitYukle(game, widget.kayit!);
      } else {
        await game.baslat();
      }
      if (!mounted) return;
      setState(() => _hazir = true);
      _botKontrol();
    });
  }

  void _botSesAta() {
    _sesNo[ben] = Hesap.o.ses;
    final s = botSesleri([for (final b in botlar) b.name], [Hesap.o.ses]);
    for (var i = 0; i < botlar.length; i++) {
      _sesNo[botlar[i]] = s[i];
    }
  }

  /// Sıra değişimini izler: kendi tur sayım (hızlı galibiyet rozeti) ve yerel tur sayacı.
  void _turTakip() {
    if (game.current == _sonSira) return;
    _sonSira = game.current;
    if (game.aktif == ben) {
      _benimTurum++;
    } else if (!_online) {
      _sureBitis = null;
      _sayacKur();
    }
  }

  void _sayacKur() {
    _sayacTik?.cancel();
    if (_sureBitis == null) {
      if (mounted) setState(() {});
      return;
    }
    _sayacTik = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final kalan = _sureBitis!.difference(DateTime.now()).inSeconds;
      setState(() {});
      if (kalan <= 0) {
        _sayacTik?.cancel();
        if (!_online && _sirada) {
          _mesaj(t('Süre doldu, tur geçti.'));
          _turBitir(sureDoldu: true);
        }
      }
    });
  }

  int? get _kalanSn {
    final b = _sureBitis;
    if (b == null) return null;
    final k = b.difference(DateTime.now()).inSeconds;
    return k < 0 ? 0 : k;
  }

  void _kaydet() {
    if (_online || game.kazanan != null) return;
    Ayarlar.o.kayitYaz(kayitJson(game));
  }

  // ----------------------------------------------------------- online
  bool _engelli(Player p) => _online && !p.isBot && p != ben && Hesap.o.engelliMi(p.name);

  Future<void> _rozetMenu(Player p) async {
    if (p.isBot || p == ben) return;
    await kullaniciMenusu(context, p.name, baglam: 'oyun');
  }

  void _netMesaj(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'durum':
        durumYukle(game, Map<String, dynamic>.from(m['d'] as Map));
        final sb = (m['d'] as Map)['sureBitis'];
        _sureBitis = sb is int ? DateTime.fromMillisecondsSinceEpoch(sb) : null;
        _sayacKur();
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
        final sk = game.players[m['kim'] as int];
        if (_engelli(sk)) return;
        _konus(sk, m['soz'] as String);
      case 'sor':
        _soruyaCevap(m);
      case 'hata':
        _mesaj(oyunMetin(m['m'] as String? ?? 'Hata'));
      case 'bilgi':
        _mesaj(oyunMetin(m['m'] as String? ?? ''));
      case 'sohbet':
        final hk = game.players[m['kim'] as int];
        if (_engelli(hk)) return;
        _sohbetGoster(hk, m['soz'] as String);
      case 'siran':
        _efektCal('ef_karistir.mp3');
        if (mounted) _mesaj(t('Sıra sende!'));
      case 'odul':
        _odul = m;
        Hesap.o.odulGeldi(m);
        if (mounted) setState(() {});
      case 'bahisIade':
        Hesap.o.odulGeldi(m);
        if (mounted) _mesaj(t('Oyun iptal oldu, altının iade edildi.'));
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
          deger = (await _insan.jokerRengi(game, ben, kart, sec))?.index ?? -1;
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
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _klip.dispose();
    _sohbetKlip.dispose();
    _efekt.dispose();
    _efekt2.dispose();
    _sohbetYazi.dispose();
    _dinleyici.dispose();
    _netAbone?.cancel();
    widget.net?.kapat();
    game.removeListener(_kaydet);
    game.removeListener(_turTakip);
    _sayacTik?.cancel();
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
    final i = _sesNo[p] ?? game.players.indexOf(p) % sesAdlari.length;
    if (Dil.o.en) {
      final en = sozEn(soz);
      if (en == null) return null;
      for (final k in [i, for (var j = 0; j < sesAdlari.length; j++) j]) {
        final v = _klipler['en|$k|$en'];
        if (v is String) return v;
      }
      return null;
    }
    final v = _klipler['$i|$soz'];
    return v is String ? v : null;
  }

  Future<bool> _klipCal(String ad, {AudioPlayer? oynatici}) async {
    final o = oynatici ?? _klip;
    try {
      final bitti = o.onPlayerComplete.first;
      await o.play(AssetSource('ses/$ad')).timeout(const Duration(seconds: 5));
      await bitti.timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      try {
        await o.stop().timeout(const Duration(seconds: 2));
      } catch (_) {}
      return false;
    }
  }

  Future<void> _sonSoz = Future.value();
  int _sozSayac = 0;

  /// Konuşmayı başlatır ve hemen döner (hamle beklemez); sözler sırayla kuyruklanır.
  Future<void> _konus(Player p, String soz) async {
    if (!mounted) return;
    if (p == ben) {
      if (soz.endsWith('seti artık benim.')) Ayarlar.o.sayacHaciz++;
      if (soz == 'Reddediyorum!') Ayarlar.o.sayacReddet++;
    }
    final no = ++_sozSayac;
    _sonSoz = _sonSoz.then((_) => _seslendir(p, soz, no));
  }

  Future<void> _sozBekle() async {
    try {
      await _sonSoz.timeout(const Duration(seconds: 12));
    } catch (_) {
      _sonSoz = Future.value();
    }
  }

  /// Klip varsa çalar; yoksa (robotik cihaz sesi kullanılmaz) okuma süresi kadar sessiz bekler.
  Future<void> _sesCal(Player p, String soz, {AudioPlayer? oynatici}) async {
    final klip = _klipAdi(p, soz);
    if (_sesli && klip != null && await _klipCal(klip, oynatici: oynatici)) return;
    await Future.delayed(Duration(milliseconds: 500 + sozGoster(soz).length * 35));
  }

  // ----------------------------------------------------------- sohbet / emoji
  static const sohbetSozleri = ['Kahretsin!', 'Sen görürsün!', 'Bir dahaki sefere.', 'Bunun intikamı acı olur!', 'İyi oyundu!', 'Hahaha!',
      'Şans işte.', 'Bravo!', 'Acele et biraz!', 'Teşekkürler.', 'Buna inanamıyorum!', 'Pes ediyorum.'];
  static const sohbetEmojileri = ['😂', '😡', '😎', '👏', '🙏', '🤔', '😱', '🔥', '❤️', '🤝', '🐘'];

  bool _emojiMi(String s) => sohbetEmojileri.contains(s);

  String _sohbetMetni(String s) => sohbetSozleri.contains(s) ? sozGoster(s) : s;

  Future<void> _efektCal(String ad, {bool ikinci = false}) async {
    if (!_sesli) return;
    try {
      await (ikinci ? _efekt2 : _efekt).play(AssetSource('ses/$ad'));
    } catch (_) {}
  }

  void _sohbetAc() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F3D25),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_sohbetGecmis.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: ListView(
                shrinkWrap: true,
                reverse: true,
                children: [
                  for (final (p, m) in _sohbetGecmis.reversed.take(12))
                    Text('${p == ben ? t('Sen') : gorunenAd(p.name)}: ${_sohbetMetni(m)}', style: TextStyle(color: p == ben ? Colors.amber : Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
          ],
          Row(children: [
            Expanded(
              child: TextField(
                controller: _sohbetYazi,
                maxLength: 80,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: t('Mesaj yaz…'), hintStyle: const TextStyle(color: Colors.white38), counterText: '', enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)), isDense: true),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  _sohbetGonder(v.trim());
                  _sohbetYazi.clear();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.amber),
              onPressed: () {
                final v = _sohbetYazi.text.trim();
                if (v.isEmpty) return;
                Navigator.pop(ctx);
                _sohbetGonder(v);
                _sohbetYazi.clear();
              },
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final e in sohbetEmojileri)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _sohbetGonder(e);
                },
                child: Padding(padding: const EdgeInsets.all(4), child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final sz in sohbetSozleri)
              ActionChip(
                backgroundColor: const Color(0xFFF3E3BF),
                surfaceTintColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFFC9962B)),
                label: Text(sozGoster(sz), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sohbetGonder(sz);
                },
              ),
          ]),
        ]),
      ),
    );
  }

  void _sohbetGonder(String soz) {
    soz = _sansur(soz);
    if (_online) {
      widget.net!.gonder({'t': 'sohbet', 'soz': soz});
      return; // sunucudan herkese (bize de) döner
    }
    _sohbetGoster(ben, soz);
    // yerel oyunda botlar bazen cevap verir
    if (!_emojiMi(soz) && botlar.isNotEmpty && Random().nextDouble() < 0.5) {
      final b = botlar[Random().nextInt(botlar.length)];
      final cevap = sohbetSozleri[Random().nextInt(sohbetSozleri.length)];
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) _sohbetGoster(b, cevap);
      });
    }
  }

  static const _kotu = ['amk', 'aq', 'orospu', 'piç', 'sik', 'yarak', 'göt', 'ibne', 'kahpe', 'salak', 'aptal', 'gerizekal', 'bok', 'puşt', 'kaltak', 'fuck', 'shit'];
  String _sansur(String s) => s.split(' ').map((k) {
        final d = k.toLowerCase().replaceAll('ı', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c');
        return _kotu.any((x) => d == x || (x.length >= 4 && d.startsWith(x))) ? '*' * k.length : k;
      }).join(' ');

  void _sohbetGoster(Player p, String soz) {
    if (!mounted) return;
    final no = ++_sohbetNo;
    setState(() {
      _sohbetGecmis.add((p, soz));
      if (_sohbetGecmis.length > 40) _sohbetGecmis.removeAt(0);
      _sohbetBalon = (p, soz);
    });
    if (_emojiMi(soz)) {
    } else {
      _sesCal(p, soz, oynatici: _sohbetKlip);
    }
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && no == _sohbetNo) setState(() => _sohbetBalon = null);
    });
  }

  Future<void> _seslendir(Player p, String soz, int no) async {
    if (!mounted) return;
    setState(() {
      _konusan = p;
      _banner = sozGoster(soz);
    });
    await _sesCal(p, soz);
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
    final adim = kim == ben ? t('Sen') : gorunenAd(kim?.name ?? '');
    Offset elM(Player p) => _masaNokta(p == ben ? _kBenEl : _kBotEl[p]);
    Offset setM(Player p) => _masaNokta(p == ben ? _kBenSet : _kBotSet[p]);
    Offset bankaM(Player p) => _masaNokta(p == ben ? _kBenBanka : _kBotSet[p]);
    final deste = _masaNokta(_kDeck), yakilan = _masaNokta(_kMerkez);
    switch (e.tip) {
      case EvTip.cek:
        _efektCal('ef_dagit.mp3');
        if (kim == ben) {
          // desteden elime: masadan çıkıp 2B ele iner
          await _ucur(e.card, _nokta(_kDeck), _elNoktasi(kim!), ms: 520, w: 60, scaleTo: 1.25);
        } else {
          await _masaUcur(e.card, deste, elM(kim!), arka: true, ms: 480, w: 40, scaleTo: 0.5);
        }
        await Future.delayed(const Duration(milliseconds: 120));
      case EvTip.mulk:
        _efektCal('ef_damga.wav');
        await _masaUcur(e.card, elM(kim!), setM(kim), ms: 520, w: kim == ben ? 56 : 46);
        final renk = e.renk;
        if (renk != null && e.card.isProperty && e.card.action != ActionType.house && e.card.action != ActionType.hotel && kim.propsOf(renk).length + 1 >= renk.setBoyu) {
          _efektCal('ef_set.wav', ikinci: true);
        }
      case EvTip.banka:
        _efektCal('ef_coin.wav');
        await _masaUcur(e.card, elM(kim!), bankaM(kim), ms: 480, w: kim == ben ? 56 : 46);
      case EvTip.aksiyon:
        final orta = Offset((deste.dx + yakilan.dx) / 2, deste.dy - 90);
        await _masaUcur(e.card, elM(kim!), orta, ms: 460, w: 56, scaleTo: 1.8);
        if (!mounted) return;
        setState(() => _banner = '$adim: ${e.etiket != null ? _bas(oyunMetin(e.etiket!)) : e.card.adT}');
        await Future.delayed(Duration(milliseconds: kim == ben ? 700 : 1100));
        if (!mounted) return;
        setState(() => _banner = null);
        await _masaUcur(e.card, orta, yakilan, ms: 320, w: 100, scaleTo: 0.64);
      case EvTip.transfer:
        final from = e.card.isProperty ? setM(kim!) : bankaM(kim!);
        final to = e.card.isProperty ? setM(e.kime!) : bankaM(e.kime!);
        if (mounted) setState(() => _banner = '${_bas(oyunMetin(e.etiket ?? 'Ödeme'))}: ${e.card.adT} → ${e.kime!.name}');
        await _masaUcur(e.card, from, to, ms: 650, w: 50);
        if (mounted) setState(() => _banner = null);
    }
  }

  String _bas(String s) => Dil.o.en && s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

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
    final a = Ayarlar.o;
    a.oynanan++;
    if (k == ben) a.kazanilan++;
    a.kaydet();
    _basarimKontrol(k == ben);
    if (!_online) _sonucGonder(k == ben);
    Izleme.o.olay('oyun_bitti', {'mod': _online ? 'online' : 'bot', 'kazandim': k == ben, 'tur': _benimTurum, 'perf': Izleme.o.performansOzeti()});
    if (!_online) a.kayitYaz(null);
    final oran = a.oynanan == 0 ? 0 : (a.kazanilan * 100 / a.oynanan).round();
    final sira = [...game.players]..sort((x, y) => y.varlikToplam.compareTo(x.varlikToplam));
    Future.delayed(Duration(milliseconds: _online ? 1200 : 1500), () {
      if (!mounted) return;
      final o = _odul;
      final bahisliOyun = _online && ((o?['bahis'] as num?) ?? 0) > 0;
      final net = (o?['net'] as num?)?.toInt() ?? 0;
      if (k == ben) {
        konfetiPatlat(context);
        AltinSes.zafer();
      }
      final altinSesi = bahisliOyun ? net != 0 : ((o?['altin'] as num?) ?? 0) > 0;
      if (altinSesi) {
        Future.delayed(Duration(milliseconds: k == ben ? 2000 : 300), () {
          if (bahisliOyun && net < 0) {
            AltinSes.azaldi();
          } else {
            AltinSes.artti();
          }
        });
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(k == ben ? t('🏆 Kazandın!') : t('😔 {ad} kazandı', {'ad': k.name})),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('{ad} 3 tam set topladı: {setler}.', {'ad': k.name, 'setler': k.tamSetler.map((c) => c.adT).join(', ')})),
            const SizedBox(height: 12),
            for (final p in sira)
              Text('${p == k ? '🏆 ' : ''}${t('{ad}: {n} tam set · {m}M varlık', {'ad': p.name, 'n': p.tamSetSayisi, 'm': p.varlikToplam})}', style: TextStyle(fontWeight: p == ben ? FontWeight.w700 : FontWeight.w400)),
            const SizedBox(height: 12),
            if (o != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(8)),
                child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (((o['xp'] as num?) ?? 0) > 0) ...[
                    SayiSayac(deger: (o['xp'] as num).toInt(), bicim: (n) => '+$n XP', stil: const TextStyle(fontWeight: FontWeight.w800), gecikme: const Duration(milliseconds: 300)),
                    const Text('  ·  ', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  if (!bahisliOyun) ...[
                    SayiSayac(deger: (o['altin'] as num).toInt(), bicim: (n) => '+${t('{n} altın', {'n': n})}', stil: const TextStyle(fontWeight: FontWeight.w800), gecikme: const Duration(milliseconds: 300)),
                    const Text('  ·  ', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  Text(o['levelAtladi'] == true ? t('🎉 Seviye {l}!', {'l': o['level']}) : t('Seviye {l}', {'l': o['level']}), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            if (o != null && bahisliOyun) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: net > 0 ? const Color(0xFFD9F5DC) : (net < 0 ? const Color(0xFFFADBD8) : const Color(0xFFE3EEFA)), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text(
                    switch (o['sonuc']) {
                      'kazandin' => t('🏆 Ödülü kazandın!'),
                      'iade' => t('↩️ Bot kazandı: altının iade edildi'),
                      'terk' => t('🚪 Oyundan düştüğün için altının kayboldu'),
                      _ => t('💸 Altınını kaybettin'),
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (net != 0)
                    SayiSayac(deger: net.abs(), bicim: (n) => '${net > 0 ? '+' : '-'}${t('{n} altın', {'n': n})}', stil: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: net > 0 ? const Color(0xFF1E7B3A) : const Color(0xFFB3261E)), gecikme: const Duration(milliseconds: 300)),
                ]),
              ),
            ],
            if (o != null && o['limitDoldu'] == true && !bahisliOyun)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t('Günlük bot altın sınırına ulaştın; bugün botlu oyunlar altın vermez. Online oyunlarda sınır yok.'), style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
              ),
            Text(t('Toplam: {o} oyun, {k} galibiyet (%{oran})', {'o': a.oynanan, 'k': a.kazanilan, 'oran': oran}), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst), child: Text(t('Menüye dön'))),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (_online) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  return;
                }
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(botSayisi: widget.botSayisi)));
              },
              child: Text(_online ? t('Lobiye dön') : t('Revanş')),
            ),
          ],
        ),
      );
    });
  }

  void _basarimKontrol(bool kazandim) {
    final a = Ayarlar.o;
    final d = BasarimDurumu.o;
    d.seriGuncelle(kazandim);
    final idler = <String>[];
    if (a.oynanan >= 10) idler.add('on_oyun');
    if (a.sayacHaciz > 0) idler.add('haciz');
    if (a.sayacReddet > 0) idler.add('reddet');
    if (kazandim) {
      idler.add('ilk_galibiyet');
      if (a.kazanilan >= 3) idler.add('uc_galibiyet');
      if (a.kazanilan >= 10) idler.add('on_galibiyet');
      if (!_online && botlar.length >= 4) idler.add('dort_bot');
      if (!_online && a.botZorluk == 2) idler.add('zor_bot');
      if (ben.bankaToplam >= 20) idler.add('zengin');
      if (_online) idler.add('online');
      if (d.seri >= 3) idler.add('seri');
      if (_benimTurum > 0 && _benimTurum < 10) idler.add('hizli');
    }
    final yeni = d.ac(idler);
    if (yeni.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF1E7B3A),
        content: Text(t('🏅 Yeni başarım: {liste}', {'liste': yeni.map((b) => '${b.ikon} ${t(b.ad)}').join(', ')}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ));
    }
  }

  /// Botla oynanan oyunun sonucu: XP/altın (hesap sunucusu) + eski liderlik dosyası.
  Future<void> _sonucGonder(bool kazandim) async {
    final r = await Hesap.o.sonuc(kazandi: kazandim, rakip: botlar.length, zorluk: Ayarlar.o.botZorluk, basarimlar: BasarimDurumu.o.acik.toList());
    if (r != null && mounted) setState(() => _odul = r);
    try {
      final adres = '${Ayarlar.o.sunucu.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://')}/sonuc';
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final r = await c.postUrl(Uri.parse(adres));
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode({'ad': Ayarlar.o.ad, 'kazandi': kazandim}));
      await (await r.close()).drain<void>();
    } catch (_) {}
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
  final Map<int, DateTime> _sonTik = {};

  Future<void> _kartTikla(GameCard c) async {
    final simdi = DateTime.now();
    final onceki = _sonTik[c.id];
    if (onceki != null && simdi.difference(onceki) < const Duration(milliseconds: 1500)) return;
    _sonTik[c.id] = simdi;
    if (!_sirada) return _mesaj(t('Sıra sende değil.'));
    if (game.playsLeft <= 0) return _mesaj(t('Hamle hakkın bitti.'));
    if (c.isProperty || c.isMoney) {
      final ok = c.isMoney
          ? await _yap('banka', {'kart': c.id}, () => game.bankayaKoy(ben, c))
          : await _yap('mulk', {'kart': c.id}, () => game.mulkOyna(ben, c));
      if (!ok && mounted) _mesaj(t('Bu hamle yapılamadı.'));
      return _sonra();
    }
    final aktif = _oynanabilir(c);
    final bankaYap = () => _yap('banka', {'kart': c.id}, () => game.bankayaKoy(ben, c));
    if (c.isRent) {
      final ok = aktif ? await _kira(c) : await bankaYap();
      if (!ok && mounted) _mesaj(t('Bu hamle yapılamadı.'));
      return _sonra();
    }
    if (c.isAction && (c.action == ActionType.house || c.action == ActionType.hotel)) {
      final setler = _binaSetleri(c);
      bool ok;
      if (setler.isEmpty) {
        ok = await bankaYap();
      } else {
        setler.sort((a, b) => ben.kira(b).compareTo(ben.kira(a)));
        final s = setler.first;
        ok = await _yap('bina', {'kart': c.id, 'set': s.index}, () => game.binaKoy(ben, c, s));
      }
      if (!ok && mounted) _mesaj(t('Bu hamle yapılamadı.'));
      return _sonra();
    }
    if (c.isAction) {
      final a = c.action!;
      final hep = a == ActionType.doubleRent || a == ActionType.justSayNo;
      final yok = !aktif && a != ActionType.passGo;
      if (hep || yok) {
        final ok = await bankaYap();
        if (!ok && mounted) _mesaj(t('Bu hamle yapılamadı.'));
        return _sonra();
      }
    }
    final secenekler = <_Secenek>[];
    if (c.isRent) secenekler.add(_Secenek(t('💰 Kira iste'), () => _kira(c), aktif: aktif));
    if (c.isAction) {
      final a = c.action!;
      switch (a) {
        case ActionType.passGo:
          secenekler.add(_Secenek(t('▶ 2 Kart Çek'), () => _yap('passGo', {'kart': c.id}, () => game.passGo(ben, c))));
        case ActionType.tahsilat:
          secenekler.add(_Secenek(t('💵 İcra Takibi: 5M al'), () => _tahsilat(c), aktif: aktif));
        case ActionType.birthday:
          secenekler.add(_Secenek(t('🎉 Ev Partisi: herkesten 2M'), () => _yap('dogumGunu', {'kart': c.id}, () => game.dogumGunu(ben, c)), aktif: aktif));
        case ActionType.slyDeal:
          secenekler.add(_Secenek(t('🕵️ Tapu Devri: rakipten tapu al'), () => _slyDeal(c), aktif: aktif));
        case ActionType.forcedDeal:
          secenekler.add(_Secenek(t('🔁 Takas Pazarlığı: tapu takası'), () => _forcedDeal(c), aktif: aktif));
        case ActionType.dealBreaker:
          secenekler.add(_Secenek(t('💥 Haciz: tam seti al'), () => _dealBreaker(c), aktif: aktif));
        case ActionType.house:
        case ActionType.hotel:
          secenekler.add(_Secenek(t('🏗️ {ad} koy (tam sete)', {'ad': a.adT}), () => _bina(c), aktif: aktif));
        case ActionType.doubleRent:
          secenekler.add(_Secenek(t('✖2 Çift kira (kira kartıyla)'), () => _ciftKira(c), aktif: aktif));
        case ActionType.justSayNo:
          secenekler.add(_Secenek(t('ℹ️ Sadece savunmada oynanır'), () async {
            _mesaj(t('Reddet kartı, rakip sana aksiyon oynayınca sorulur.'));
            return false;
          }, aktif: false));
      }
    }
    secenekler.add(_Secenek(t('🏦 Bankaya koy ({n}M para olur)', {'n': c.paraDegeri}), () => _yap('banka', {'kart': c.id}, () => game.bankayaKoy(ben, c))));
    final sec = await showModalBottomSheet<_Secenek>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CardView(c, w: 70),
              const SizedBox(width: 12),
              Expanded(child: Text(c.isAction ? c.action!.aciklamaT : c.adT, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            ]),
          ),
          for (final s in secenekler)
            ListTile(
              enabled: s.aktif,
              title: Text(s.baslik, style: TextStyle(color: s.aktif ? null : Colors.grey)),
              subtitle: s.aktif ? null : Text(t('şu an oynanamaz'), style: const TextStyle(fontSize: 11)),
              onTap: s.aktif ? () => Navigator.pop(ctx, s) : null,
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (sec == null) return;
    _vazgecildi = false;
    final ok = await sec.calistir();
    if (!ok && !_vazgecildi && mounted) _mesaj(t('Bu hamle yapılamadı.'));
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
              subtitle: Text(altYazi == null ? t('🏦 {n}M · varlık {m}M', {'n': r.bankaToplam, 'm': r.varlikToplam}) : altYazi(r)),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(t('Vazgeç')))],
      ),
    );
  }

  /// Rakip kartlarından seçtirir; birden fazla rakip varsa oyuncuya göre gruplar.
  bool _vazgecildi = false;
  bool _iptal() {
    _vazgecildi = true;
    return false;
  }

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
      _mesaj(t('Kimsenin ödeyecek bir şeyi yok.'));
      return false;
    }
    final r = await _rakipSec(t('💵 Kimden 5M?'), adaylar);
    if (r == null) return _iptal();
    return _yap('tahsilat', {'kart': c.id, 'hedef': game.players.indexOf(r)}, () => game.tahsilat(ben, c, r));
  }

  Future<bool> _kira(GameCard c) async {
    final renkler = _kiraRenkleri(c);
    if (renkler.isEmpty) {
      _mesaj(t('Bu renkte tapun yok.'));
      return false;
    }
    // En yüksek kirayı veren renk otomatik seçilir, sorulmaz.
    final renk = renkler.reduce((x, y) => ben.kira(y) > ben.kira(x) ? y : x);
    GameCard? cift;
    final ciftKart = ben.hand.where((x) => x.action == ActionType.doubleRent).toList();
    if (ciftKart.isNotEmpty && game.playsLeft >= 2 && mounted) {
      if (await confirmDlg(context, t('✖2 Zam Geldi?'), t('Zam Geldi kartını da oynayıp {n}M isteyeyim mi? (2 hamle harcar)', {'n': ben.kira(renk) * 2}),
          evet: 'Evet, çift', hayir: 'Hayır, tek')) {
        cift = ciftKart.first;
      }
    }
    return _yap('kira', {'kart': c.id, 'renk': renk.index, if (cift != null) 'cift': cift.id}, () => game.kiraOyna(ben, c, renk, cift: cift));
  }

  Future<bool> _ciftKira(GameCard cift) async {
    final kiralar = ben.hand.where((x) => x.isRent && _kiraRenkleri(x).isNotEmpty).toList();
    if (kiralar.isEmpty) {
      _mesaj(t('Oynanabilir kira kartın yok.'));
      return false;
    }
    if (game.playsLeft < 2) {
      _mesaj(t('Çift kira için 2 hamle gerekir.'));
      return false;
    }
    final c = await _kartSec(t('Hangi kira kartıyla?'), kiralar);
    if (c == null || !mounted) return _iptal();
    final renk = _kiraRenkleri(c).reduce((x, y) => ben.kira(y) > ben.kira(x) ? y : x);
    return _yap('kira', {'kart': c.id, 'renk': renk.index, 'cift': cift.id}, () => game.kiraOyna(ben, c, renk, cift: cift));
  }

  Future<bool> _slyDeal(GameCard c) async {
    final gruplar = {for (final r in _rakipler) r: game.calinabilir(r)};
    if (gruplar.values.every((l) => l.isEmpty)) {
      _mesaj(t('Rakiplerde alınabilir tapu yok (tam setler korunur).'));
      return false;
    }
    final h = await _rakipKartiSec(t('🕵️ Hangi tapuyu alıyorsun?'), gruplar);
    if (h == null) return _iptal();
    return _yap('slyDeal', {'kart': c.id, 'hedefKart': h.id}, () => game.slyDeal(ben, c, h));
  }

  Future<bool> _forcedDeal(GameCard c) async {
    final gruplar = {for (final r in _rakipler) r: game.calinabilir(r)};
    final benimkiler = game.calinabilir(ben);
    if (gruplar.values.every((l) => l.isEmpty) || benimkiler.isEmpty) {
      _mesaj(t('Değiş tokuş için iki tarafta da tamamlanmamış setten tapu olmalı.'));
      return false;
    }
    final o = await _rakipKartiSec(t('🔁 Rakipten hangisini alıyorsun?'), gruplar);
    if (o == null || !mounted) return _iptal();
    final b = await _kartSec(t('🔁 Karşılığında hangisini veriyorsun?'), benimkiler);
    if (b == null) return _iptal();
    return _yap('forcedDeal', {'kart': c.id, 'benim': b.id, 'onun': o.id}, () => game.forcedDeal(ben, c, b, o));
  }

  Future<bool> _dealBreaker(GameCard c) async {
    final adaylar = _rakipler.where((r) => r.tamSetler.isNotEmpty).toList();
    if (adaylar.isEmpty) {
      _mesaj(t('Rakiplerin tam seti yok.'));
      return false;
    }
    final r = await _rakipSec(t('💥 Kimin setini alıyorsun?'), adaylar, altYazi: (p) => t('tam set: {liste}', {'liste': p.tamSetler.map((s) => s.adT).join(', ')}));
    if (r == null || !mounted) return _iptal();
    final s = await _renkSec(t('💥 Hangi tam seti?'), r.tamSetler);
    if (s == null) return _iptal();
    return _yap('dealBreaker', {'kart': c.id, 'hedef': game.players.indexOf(r), 'set': s.index}, () => game.dealBreaker(ben, c, r, s));
  }

  Future<bool> _bina(GameCard c) async {
    final setler = _binaSetleri(c);
    if (setler.isEmpty) {
      _mesaj(c.action == ActionType.house ? t('Evsiz tam setin yok.') : t('Evli (rezidanssız) tam setin yok.'));
      return false;
    }
    final s = await _renkSec(t('🏗️ Hangi sete?'), setler);
    if (s == null) return _iptal();
    return _yap('bina', {'kart': c.id, 'set': s.index}, () => game.binaKoy(ben, c, s));
  }

  Future<void> _turBitir({bool sureDoldu = false}) async {
    if (!_hazir || game.aktif != ben || game.kazanan != null || _botOynuyor) return;
    setState(() => _acikDeste = null);
    if (_online) {
      widget.net!.gonder({'t': 'hamle', 'tip': 'turBitir'});
      return;
    }
    await game.turBitir(sureDoldu: sureDoldu);
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
            ? t('Kartlar dağıtılıyor…')
            : game.kazanan != null
                ? t('Oyun bitti')
                : (_botOynuyor || (_online && game.aktif != ben))
                    ? t('{ad} oynuyor…', {'ad': game.aktif.name})
                    : game.aktif == ben
                        ? t('Sıra sende · {n} hamle', {'n': game.playsLeft})
                        : '${game.aktif.name}…';
        return PopScope(
          canPop: !(_online && widget.bahis > 0 && game.kazanan == null),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final git = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(t('Oyundan çıkılsın mı?')),
                content: Text(t('Altınlı bir oyundasın. Çıkarsan {n} altınını kaybedersin.', {'n': widget.bahis})),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Devam et'))),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Çık'))),
                ],
              ),
            );
            if (git == true && mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
          backgroundColor: const Color(0xFF1B5E3A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D25),
            foregroundColor: Colors.white,
            title: Text(t('Emlak Deal · {n} oyuncu', {'n': game.players.length}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            actions: [
              if (_online && widget.bahis > 0)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE0B13A), borderRadius: BorderRadius.circular(12)),
                    child: Text('🏆 ${widget.havuz}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              IconButton(tooltip: t('Sohbet / emoji'), onPressed: _sohbetAc, icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(
                tooltip: _sesli ? t('Sesi kapat') : t('Sesi aç'),
                onPressed: () => setState(() {
                  _sesli = !_sesli;
                  Ayarlar.o.sesli = _sesli;
                  Ayarlar.o.kaydet();
                  if (!_sesli) {
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
                    profiller: _profiller,
                    ucanlar: _masaUcanlar,
                    ustBilgi: _durumSeridi(durum),
                    rozetMenu: _online && !Hesap.o.misafir ? _rozetMenu : null,
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
              if (_sohbetBalon != null)
                Positioned(
                  right: 12,
                  top: 56,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 240),
                      padding: EdgeInsets.symmetric(horizontal: _emojiMi(_sohbetBalon!.$2) ? 14 : 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _sohbetBalon!.$1 == ben ? const Color(0xFFFFE08A) : Colors.white,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(3)),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                        Text(_sohbetBalon!.$1 == ben ? t('Sen') : gorunenAd(_sohbetBalon!.$1.name), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
                        Text(_sohbetMetni(_sohbetBalon!.$2), style: TextStyle(fontSize: _emojiMi(_sohbetBalon!.$2) ? 40 : 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ]),
                    ),
                  ),
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
                            Text(_konusan == ben ? t('Sen') : gorunenAd(_konusan!.name), style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(_banner!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
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
            Text(oyunMetin(son), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        if (_kalanSn != null && game.kazanan == null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: (_kalanSn! <= 10 ? Colors.redAccent : Colors.black54), borderRadius: BorderRadius.circular(10)),
            child: Text('⏱ $_kalanSn', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        Text(t('Tam set {n}/3', {'n': ben.tamSetSayisi}), style: const TextStyle(color: Colors.white70, fontSize: 11)),
        IconButton(
          tooltip: t('Turu bitir'),
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
      return Text(t('Henüz kart yok'), style: TextStyle(color: Colors.white38, fontSize: kucuk ? 11 : 13));
    }
    final banka = KeyedSubtree(
      key: p == ben ? _kBenBanka : null,
      child: _Deste(
        kartlar: p.bank,
        w: w,
        acik: _acikDeste == '$kim:banka',
        ustBaslik: t('🏦 {n} kart', {'n': p.bank.length}),
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
          ustBaslik: '${c.kisaAdT} ${p.propsOf(c).length}/${c.setBoyu}${p.setTam(c) ? ' ✓' : ''}',
          altBaslik: t('kira {n}M', {'n': p.kira(c)}),
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
        Text(t('Elin ({n}/7)', {'n': ben.hand.length}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
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
