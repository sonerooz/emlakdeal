import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'ayarlar.dart';

/// Buton tık sesi; yalnız oyuncu sesleri açıkken çalar.
class Tik {
  Tik._();
  static final AudioPlayer _o = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  static bool _hazir = false;

  static Future<void> cal() async {
    if (!Ayarlar.o.sesli) return;
    try {
      await _o.stop();
      await _o.play(AssetSource('ses/ef_tik.wav'), volume: 0.7);
      _hazir = true;
    } catch (_) {}
  }

  static bool get hazir => _hazir;
}

/// Temadaki her ink efektinde (düğme, InkWell, çip…) tık sesi çalan sarmalayıcı.
class TikSplashFabrikasi extends InteractiveInkFeatureFactory {
  const TikSplashFabrikasi(this.taban);
  final InteractiveInkFeatureFactory taban;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    Tik.cal();
    return taban.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

/// Arka plan müziği: açıksa uygulama açık kaldığı sürece (menü, dükkân, oyun) çalar.
class Muzik with WidgetsBindingObserver {
  Muzik._();
  static final Muzik o = Muzik._();
  final AudioPlayer _p = AudioPlayer();
  bool _caliyor = false;
  bool _arkaPlanda = false;

  void baslat() => WidgetsBinding.instance.addObserver(this);

  /// Ayarlar.muzik'e göre başlatır ya da durdurur.
  Future<void> guncelle() async {
    final ister = Ayarlar.o.muzik && !_arkaPlanda;
    if (ister == _caliyor) return;
    _caliyor = ister;
    try {
      if (ister) {
        await _p.setReleaseMode(ReleaseMode.loop);
        await _p.setVolume(0.35);
        await _p.play(AssetSource('ses/muzik.mp3'));
      } else {
        await _p.pause();
      }
    } catch (_) {
      _caliyor = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final arka = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (arka == _arkaPlanda) return;
    if (state == AppLifecycleState.inactive) return;
    _arkaPlanda = arka;
    if (arka && _caliyor) {
      _caliyor = false;
      _p.pause();
    } else if (!arka) {
      guncelle();
    }
  }
}

/// Altın kazanma / harcama sesleri; yalnız oyuncu sesleri açıkken çalar.
class AltinSes {
  AltinSes._();
  static final AudioPlayer _o = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  static Future<void> _cal(String ad) async {
    if (!Ayarlar.o.sesli) return;
    try {
      await _o.stop();
      await _o.play(AssetSource('ses/$ad'), volume: 0.8);
    } catch (_) {}
  }

  static Future<void> artti() => _cal('ef_altin_art.wav');
  static Future<void> azaldi() => _cal('ef_altin_azal.wav');
  static Future<void> zafer() => _cal('ef_zafer.wav');
}
