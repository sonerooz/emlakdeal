import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'hesap.dart';

/// Çökme raporu + basit analitik + performans ölçümü; hepsi kendi sunucumuza gider
/// (/api/hata, /api/olay). Dış servis (Crashlytics) gerekmez.
class Izleme {
  Izleme._();
  static final Izleme o = Izleme._();
  static const surum = '1.0.0+2032';
  final _son = <String>[];
  int _kare = 0, _yavasKare = 0;
  double _toplamMs = 0;

  void kur() {
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      hata('${d.exceptionAsString()}', d.stack?.toString());
    };
    PlatformDispatcher.instance.onError = (e, st) {
      hata('$e', '$st');
      return true;
    };
    SchedulerBinding.instance.addTimingsCallback(_kareler);
  }

  void _kareler(List<FrameTiming> l) {
    for (final f in l) {
      final ms = f.totalSpan.inMicroseconds / 1000;
      _kare++;
      _toplamMs += ms;
      if (ms > 32) _yavasKare++;
    }
  }

  /// Oyun sonunda performans özeti (ortalama kare süresi, takılan kare oranı).
  Map<String, dynamic> performansOzeti() {
    final r = {'kare': _kare, 'ortMs': _kare == 0 ? 0 : (_toplamMs / _kare * 10).round() / 10, 'yavasYuzde': _kare == 0 ? 0 : (_yavasKare * 1000 / _kare).round() / 10};
    _kare = 0;
    _yavasKare = 0;
    _toplamMs = 0;
    return r;
  }

  Future<void> hata(String mesaj, String? yigin) async {
    // aynı hatayı üst üste gönderme
    final anahtar = mesaj.split('\n').first;
    if (_son.contains(anahtar)) return;
    _son.add(anahtar);
    if (_son.length > 20) _son.removeAt(0);
    unawaited(Hesap.o.gonder('/api/hata', {'surum': surum, 'cihaz': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.substring(0, 60.clamp(0, ('${Platform.operatingSystem} ${Platform.operatingSystemVersion}').length)), 'mesaj': mesaj, 'yigin': yigin}));
  }

  Future<void> olay(String ad, [Map<String, dynamic>? veri]) async {
    unawaited(Hesap.o.gonder('/api/olay', {'ad': ad, 'veri': veri}));
  }
}
