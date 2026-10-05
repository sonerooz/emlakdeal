import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_screen.dart';
import 'ayarlar.dart';
import 'ses_servis.dart';
import 'dil.dart';
import 'ui/bayrak.dart';
import 'ui/avatar.dart';
import 'ui/gunluk_odul.dart';
import 'ui/gorevler_ekrani.dart';
import 'basarimlar.dart';
import 'hesap.dart';
import 'izleme.dart';
import 'net/istemci.dart';
import 'ui/card_widget.dart' show kartArkasiStili;
import 'ui/dukkan_ekrani.dart';
import 'ui/lobi.dart' show LobiEkrani;
import 'ui/sosyal_ekrani.dart';
import 'ui/profil_ekrani.dart';
import 'ui/basarimlar_ekrani.dart';
import 'ui/ogretici.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    Izleme.o.kur();
    await Ayarlar.o.yukle();
    Dil.o.baslat();
    await BasarimDurumu.o.yukle();
    await Hesap.o.yukle();
    Hesap.o.baglan().then(
      (_) => kartArkasiStili = Hesap.o.kartArkasi,
    ); // arka planda; sunucu yoksa sessiz
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    Muzik.o.baslat();
    Muzik.o.guncelle();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(_SistemCubugu());
    runApp(const EmlakDealApp());
  }, (e, st) => Izleme.o.hata('$e', '$st', kaynak: 'zone'));
}

class _SistemCubugu with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}

class EmlakDealApp extends StatelessWidget {
  const EmlakDealApp({super.key});
  @override
  Widget build(BuildContext context) {
    final taban = ThemeData(
      colorSchemeSeed: const Color(0xFF1B5E3A),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Emlak Deal',
      debugShowCheckedModeBanner: false,
      theme: taban.copyWith(
        splashFactory: TikSplashFabrikasi(taban.splashFactory),
      ),
      navigatorObservers: [IzlemeGozlemci()],
      home: const SplashEkrani(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _bot = 1;
  Istemci? _varlik; // çevrim içi kaydı: arkadaş davetleri buradan gelir

  Future<void> _varlikBaglan() async {
    if (Hesap.o.token == null || Hesap.o.misafir || _varlik != null) return;
    try {
      final n = Istemci(Ayarlar.o.sunucu);
      try {
        await n.baglan();
      } catch (_) {
        final y = Istemci(Ayarlar.sunucuYerel);
        await y.baglan();
        _varlik = y;
      }
      _varlik ??= n;
      _varlik!.gonder({'t': 'kimlik', 'token': Hesap.o.token});
      _varlik!.mesajlar.listen((m) {
        if (m['t'] == 'davet' && mounted)
          _davetGeldi(m['kim'] as String, m['oda'] as String);
      });
    } catch (_) {}
  }

  void _davetGeldi(String kim, String oda) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('🎉 Oyun daveti')),
        content: Text(
          t('{kim} seni "{oda}" odasına çağırıyor.', {'kim': kim, 'oda': oda}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('Şimdi değil')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ac(LobiEkrani(odaKodu: oda));
            },
            child: Text(t('Katıl')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _varlik?.kapat();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() {});
      _varlikBaglan();
    });
    if (Ayarlar.o.ogreticiGoruldu) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _odulKontrol());
    }
    if (!Ayarlar.o.ogreticiGoruldu) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const OgreticiEkrani())),
      );
    }
  }

  Future<void> _ac(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {});
    _varlikBaglan();
  }

  Future<void> _girisIste(String ozellik) async {
    final git = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Giriş gerekli')),
        content: Text(
          t(
            '{ozellik} için giriş yapmalısın. Şimdiye kadarki ilerlemen hesabına bağlanır.',
            {'ozellik': t(ozellik)},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Şimdi değil')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Giriş yap')),
          ),
        ],
      ),
    );
    if (git == true && mounted) _ac(const ProfilEkrani());
  }

  static bool _odulGosterildi = false;

  Future<void> _odulKontrol() async {
    await Hesap.o.baglan();
    if (!mounted) return;
    setState(() {});
    if (_odulGosterildi || Hesap.o.misafir || !Hesap.o.bonusHazir) return;
    _odulGosterildi = true;
    await gunlukOdulAc(context);
    if (mounted) setState(() {});
  }

  Future<void> _botOyunu() async {
    final a = Ayarlar.o;
    final basla = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF123F2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t('Botlara karşı'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  t('Kaç bota karşı?'),
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  style: _segStil,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                  ],
                  selected: {_bot},
                  onSelectionChanged: (s) => set(() => _bot = s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  t('{n} oyuncu · sen + {b} bot', {'n': _bot + 1, 'b': _bot}),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Text(
                  t('Bot zorluğu'),
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  style: _segStil,
                  segments: [
                    ButtonSegment(value: 0, label: Text(t('Kolay'))),
                    ButtonSegment(value: 1, label: Text(t('Normal'))),
                    ButtonSegment(value: 2, label: Text(t('Zor'))),
                  ],
                  selected: {a.botZorluk},
                  onSelectionChanged: (s) => set(() => a.botZorluk = s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    t(
                      'Kolay bot fırsatların bir kısmını kaçırır, Reddet kartını nadiren kullanır.',
                    ),
                    t('Normal bot mantıklı oynar.'),
                    t(
                      'Zor bot her fırsatı kullanır, elini erken zenginleştirir.',
                    ),
                  ][a.botZorluk],
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t('Oyunu başlat')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (basla != true || !mounted) return;
    await a.kaydet();
    await a.kayitYaz(null);
    _ac(GameScreen(botSayisi: _bot));
  }

  static final _segStil = SegmentedButton.styleFrom(
    foregroundColor: Colors.white,
    selectedForegroundColor: Colors.black,
    selectedBackgroundColor: Colors.amber,
    side: const BorderSide(color: Colors.white54),
  );

  Widget _ikonDugme(
    IconData acik,
    IconData kapali,
    bool acikMi,
    String ipucu,
    VoidCallback f,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white12,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24),
    ),
    child: IconButton(
      tooltip: ipucu,
      icon: Icon(
        acikMi ? acik : kapali,
        color: acikMi ? Colors.amber : Colors.white54,
      ),
      onPressed: f,
    ),
  );

  Widget _karo(IconData ikon, String etiket, Color renk, VoidCallback f) =>
      Expanded(
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: 30, color: renk),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    etiket,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final a = Ayarlar.o;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E3A), Color(0xFF0F3D25)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DilDugmesi(degisti: () => setState(() {})),
                    const SizedBox(width: 10),
                    _ikonDugme(
                      Icons.music_note,
                      Icons.music_off,
                      a.muzik,
                      t('Müzik'),
                      () {
                        setState(() => a.muzik = !a.muzik);
                        a.kaydet();
                        Muzik.o.guncelle();
                      },
                    ),
                    const SizedBox(width: 10),
                    _ikonDugme(
                      Icons.volume_up,
                      Icons.volume_off,
                      a.sesli,
                      t('Oyuncu sesleri'),
                      () {
                        setState(() => a.sesli = !a.sesli);
                        a.kaydet();
                        if (a.sesli) Tik.cal();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, k) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: k.maxHeight - 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap: () => _ac(const ProfilEkrani()),
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 136,
                                        height: 136,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black26,
                                          border: Border.all(
                                            color: Colors.amber,
                                            width: 4,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black38,
                                              blurRadius: 18,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: AvatarGorsel(
                                          Hesap.o.avatar,
                                          boyut: 136,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        Hesap.o.nick,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 18,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              t('Seviye {n}', {
                                                'n': Hesap.o.level,
                                              }),
                                              style: const TextStyle(
                                                color: Colors.amber,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GorevlerEkrani()));
                                    if (mounted) setState(() {});
                                  },
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.05)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(color: Hesap.o.gorevHazir > 0 ? Colors.amber : Colors.white24, width: Hesap.o.gorevHazir > 0 ? 1.8 : 1),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.withValues(alpha: 0.2)),
                                        child: Badge(
                                          isLabelVisible: Hesap.o.gorevHazir > 0,
                                          label: Text('${Hesap.o.gorevHazir}'),
                                          backgroundColor: Colors.redAccent,
                                          textColor: Colors.white,
                                          child: const Icon(Icons.task_alt, color: Colors.amber),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(t('Günlük görevler'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text(
                                            Hesap.o.misafir
                                                ? t('Giriş yap, ödülleri topla')
                                                : (Hesap.o.gorevHazir > 0 ? t('{n} ödül seni bekliyor', {'n': Hesap.o.gorevHazir}) : t('XP ve altın kazan')),
                                            style: TextStyle(color: Hesap.o.gorevHazir > 0 ? Colors.amber : Colors.white60, fontSize: 12.5),
                                          ),
                                        ]),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white54),
                                    ]),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              if (a.kayit != null) ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _ac(GameScreen(kayit: a.kayit)),
                                  icon: const Icon(Icons.play_circle),
                                  label: Text(t('Kaldığın yerden devam et')),
                                ),
                                const SizedBox(height: 10),
                              ],
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: a.kayit != null
                                      ? Colors.white24
                                      : Colors.amber,
                                  foregroundColor: a.kayit != null
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: _botOyunu,
                                icon: const Icon(Icons.smart_toy),
                                label: Text(
                                  a.kayit != null
                                      ? t('Yeni oyun (botlara karşı)')
                                      : t('Botlara karşı oyna'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () => Hesap.o.misafir
                                    ? _girisIste('Online oyun')
                                    : _ac(const LobiEkrani()),
                                icon: Icon(
                                  Hesap.o.misafir ? Icons.lock : Icons.wifi,
                                ),
                                label: Text(t('Online oyna')),
                              ),
                              const SizedBox(height: 28),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _karo(
                                      Icons.storefront,
                                      t('Dükkân'),
                                      Colors.amber,
                                      () => _ac(const DukkanEkrani()),
                                    ),
                                    const SizedBox(width: 10),
                                    _karo(
                                      Icons.group,
                                      t('Arkadaşlar'),
                                      Colors.lightBlueAccent,
                                      () => Hesap.o.misafir
                                          ? _girisIste('Arkadaşlar')
                                          : _ac(const SosyalEkrani()),
                                    ),
                                    const SizedBox(width: 10),
                                    _karo(
                                      Icons.emoji_events,
                                      t('Başarımlar'),
                                      Colors.orangeAccent,
                                      () => _ac(const BasarimlarEkrani()),
                                    ),
                                    const SizedBox(width: 10),
                                    _karo(
                                      Icons.school,
                                      t('Nasıl oynanır'),
                                      Colors.lightGreenAccent,
                                      () => _ac(const OgreticiEkrani()),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashEkrani extends StatefulWidget {
  const SplashEkrani({super.key});
  @override
  State<SplashEkrani> createState() => _SplashEkraniState();
}

class _SplashEkraniState extends State<SplashEkrani> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const MenuScreen(),
          transitionsBuilder: (_, an, __, child) =>
              FadeTransition(opacity: an, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E3A), Color(0xFF0F3D25)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/img/logo.png', width: 160, height: 160),
              const SizedBox(height: 18),
              Text(
                t('EMLAK'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              Text(
                t('DEAL'),
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('Türkiye şehirleri tapu kart oyunu'),
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
