import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayarlar.dart';
import 'dil.dart';
import 'hesap.dart';

class _Kayit {
  _Kayit(this.rapor);
  final Map<String, dynamic> rapor;
  int sayac = 1, gonderilen = 1;
}

/// Çökme raporu + basit analitik + performans ölçümü; hepsi kendi sunucumuza gider
/// (/api/hata, /api/olay). Dış servis (Crashlytics) gerekmez.
class Izleme with WidgetsBindingObserver {
  Izleme._();
  @visibleForTesting
  Izleme.testIcin();
  static final Izleme o = Izleme._();

  static const kuyrukAnahtari = 'izleme_kuyruk';
  static const kuyrukMax = 20, kuyrukBayt = 60000, izMax = 30;

  String surum = 'bilinmiyor';

  /// Testte sunucu yerine konur; true = rapor teslim edildi.
  Future<bool> Function(Map<String, dynamic> rapor)? gonderici;

  final _iz = <String>[];
  final _kayitlar = <String, _Kayit>{};
  bool _bosaltiyor = false;
  Timer? _zaman; // ignore: unused_field
  Future<void>? _hazir;
  int _kare = 0, _yavasKare = 0;
  double _toplamMs = 0;

  List<String> get izler => List.unmodifiable(_iz);

  void kur() {
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      hata(d.exceptionAsString(), d.stack?.toString(), kaynak: 'flutter');
    };
    PlatformDispatcher.instance.onError = (e, st) {
      hata('$e', '$st', kaynak: 'native');
      return true;
    };
    if (!kIsWeb) {
      final port = RawReceivePort((dynamic p) {
        if (p is List && p.length >= 2)
          hata('${p[0]}', '${p[1]}', kaynak: 'native');
      });
      Isolate.current.addErrorListener(port.sendPort);
    }
    SchedulerBinding.instance.addTimingsCallback(_kareler);
    WidgetsBinding.instance.addObserver(this);
    iz('dil: ${Dil.o.kod}');
    _zaman = Timer.periodic(const Duration(seconds: 30), (_) {
      topluGonder();
      kuyrukBosalt();
    });
    _hazir = _baslat();
  }

  Future<void> _baslat() async {
    try {
      final p = await PackageInfo.fromPlatform();
      surum = '${p.version}+${p.buildNumber}';
    } catch (_) {}
    await kuyrukBosalt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    iz('yasam: ${state.name}');
    if (state == AppLifecycleState.resumed) {
      kuyrukBosalt();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      topluGonder();
    }
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
    final r = {
      'kare': _kare,
      'ortMs': _kare == 0 ? 0 : (_toplamMs / _kare * 10).round() / 10,
      'yavasYuzde': _kare == 0 ? 0 : (_yavasKare * 1000 / _kare).round() / 10,
    };
    _kare = 0;
    _yavasKare = 0;
    _toplamMs = 0;
    return r;
  }

  // ------------------------------------------------------------ kırıntı izi
  /// Son ~30 ekran/olay/durum satırı; hata raporuna eklenir.
  void iz(String satir) {
    final t = DateTime.now();
    String iki(int n) => n.toString().padLeft(2, '0');
    _iz.add(
      '${iki(t.hour)}:${iki(t.minute)}:${iki(t.second)} ${_kisalt(maskele(satir), 160)}',
    );
    while (_iz.length > izMax) {
      _iz.removeAt(0);
    }
  }

  // ------------------------------------------------------------ gizlilik
  static String _kisalt(String s, int n) =>
      s.length <= n ? s : s.substring(0, n);

  /// Token, e-posta, uzun anahtar benzeri dizeleri maskeler.
  static String maskele(String s) {
    var r = s;
    for (final h in [Hesap.o.token, Hesap.o.cihaz]) {
      if (h != null && h.length >= 8) r = r.replaceAll(h, '***');
    }
    r = r.replaceAllMapped(
      RegExp(r'(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (m) => '${m[1]} ***',
    );
    r = r.replaceAllMapped(
      RegExp(
        "(token|key|secret|password|parola|sifre)([\"']?\\s*[:=]\\s*[\"']?)[^\\s\"',&}]+",
        caseSensitive: false,
      ),
      (m) => '${m[1]}${m[2]}***',
    );
    r = r.replaceAllMapped(
      RegExp(r'[A-Za-z0-9_-]{32,}'),
      (m) => RegExp(r'\d').hasMatch(m[0]!) ? '***' : m[0]!,
    );
    r = r.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '***@***');
    return r;
  }

  // ------------------------------------------------------------ raporlama
  String _cihaz() {
    final s = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return _kisalt(s, 120);
  }

  String _model() {
    try {
      final d = PlatformDispatcher.instance;
      final v = d.views.isEmpty ? null : d.views.first;
      final boyut = v == null
          ? '?'
          : '${v.physicalSize.width.round()}x${v.physicalSize.height.round()}@${v.devicePixelRatio.toStringAsFixed(1)}';
      return 'ekran $boyut ${d.locale}';
    } catch (_) {
      return 'bilinmiyor';
    }
  }

  Map<String, dynamic> _rapor(
    String mesaj,
    String? yigin,
    String kaynak,
    int sayac,
  ) => {
    'surum': surum,
    'cihaz': _cihaz(),
    'model': _model(),
    'dil': Dil.o.kod,
    'mesaj': _kisalt(maskele(mesaj), 1000),
    'yigin': yigin == null ? null : _kisalt(maskele(yigin), 4000),
    'sayac': sayac,
    'iz': List<String>.from(_iz),
    'kaynak': kaynak,
  };

  Future<void> hata(
    String mesaj,
    String? yigin, {
    String kaynak = 'flutter',
  }) async {
    await _hazir;
    final anahtar = _kisalt(maskele(mesaj.split('\n').first), 200);
    iz('hata: ${_kisalt(anahtar, 80)}');
    final var_ = _kayitlar[anahtar];
    if (var_ != null) {
      var_.sayac++; // 30 sn'lik toplu gönderim bu sayıyı taşır
      return;
    }
    if (_kayitlar.length >= 50) _kayitlar.remove(_kayitlar.keys.first);
    final k = _Kayit(_rapor(mesaj, yigin, kaynak, 1));
    _kayitlar[anahtar] = k;
    await _teslim(k.rapor);
  }

  /// Oturumda tekrar eden hataların sayaç farkını tek rapor olarak yollar.
  Future<void> topluGonder() async {
    for (final k in _kayitlar.values) {
      final fark = k.sayac - k.gonderilen;
      if (fark <= 0) continue;
      k.gonderilen = k.sayac;
      final r = Map<String, dynamic>.from(k.rapor)
        ..['sayac'] = fark
        ..['iz'] = List<String>.from(_iz);
      await _teslim(r);
    }
  }

  Future<void> _teslim(Map<String, dynamic> rapor) async {
    var tamam = false;
    try {
      tamam = await (gonderici ?? _http)(rapor);
    } catch (_) {}
    if (!tamam) {
      iz('ag: rapor gönderilemedi, kuyruğa alındı');
      await _kuyrugaAl(rapor);
    }
  }

  // ------------------------------------------------------------ kuyruk
  Future<List<Map<String, dynamic>>> _kuyrukOku() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(kuyrukAnahtari);
      if (s == null) return [];
      return [
        for (final e in jsonDecode(s) as List)
          Map<String, dynamic>.from(e as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _kuyrukYaz(List<Map<String, dynamic>> l) async {
    try {
      final p = await SharedPreferences.getInstance();
      while (l.length > kuyrukMax) {
        l.removeAt(0);
      }
      var s = jsonEncode(l);
      while (s.length > kuyrukBayt && l.length > 1) {
        l.removeAt(0);
        s = jsonEncode(l);
      }
      if (l.isEmpty) {
        await p.remove(kuyrukAnahtari);
      } else {
        await p.setString(kuyrukAnahtari, s);
      }
    } catch (_) {}
  }

  Future<void> _kuyrugaAl(Map<String, dynamic> rapor) async {
    final l = await _kuyrukOku();
    l.add(rapor);
    await _kuyrukYaz(l);
  }

  /// Açılışta / öne gelince / 30 sn'de bir: bekleyen raporları sırayla yeniden dener.
  Future<void> kuyrukBosalt() async {
    if (_bosaltiyor) return;
    _bosaltiyor = true;
    try {
      final l = await _kuyrukOku();
      if (l.isEmpty) return;
      final kalan = <Map<String, dynamic>>[];
      var durdu = false;
      for (final r in l) {
        if (durdu) {
          kalan.add(r);
          continue;
        }
        var tamam = false;
        try {
          tamam = await (gonderici ?? _http)(r);
        } catch (_) {}
        if (!tamam) {
          durdu = true;
          kalan.add(r);
        }
      }
      await _kuyrukYaz(kalan);
    } finally {
      _bosaltiyor = false;
    }
  }

  // ------------------------------------------------------------ ağ
  static String _kok(String ws) =>
      ws.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');

  /// Bağımsız POST: /api/hata yetkisiz de kabul eder, token varsa eklenir.
  /// 5xx/ağ hatası = teslim edilemedi (yeniden denenir); 4xx = kalıcı red, tekrar deneme.
  Future<bool> _http(Map<String, dynamic> rapor) async {
    final kokler = <String>{_kok(Ayarlar.o.sunucu), _kok(Ayarlar.sunucuYerel)};
    final govde = jsonEncode(rapor);
    for (final kok in kokler) {
      for (final yetkili in [true, false]) {
        if (yetkili && Hesap.o.token == null) continue;
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        try {
          final r = await c.postUrl(Uri.parse('$kok/api/hata'));
          if (yetkili)
            r.headers.set('authorization', 'Bearer ${Hesap.o.token}');
          r.headers.contentType = ContentType.json;
          r.write(govde);
          final y = await r.close().timeout(const Duration(seconds: 10));
          await y.drain<void>();
          if (y.statusCode < 300) return true;
          if (y.statusCode == 401) continue;
          if (y.statusCode < 500) return true;
          break;
        } catch (_) {
          break;
        } finally {
          c.close(force: true);
        }
      }
    }
    return false;
  }

  Future<void> olay(String ad, [Map<String, dynamic>? veri]) async {
    iz('olay: $ad');
    unawaited(Hesap.o.gonder('/api/olay', {'ad': ad, 'veri': veri}));
  }
}

/// Ekran geçişlerini kırıntı izine yazar (MaterialApp.navigatorObservers).
class IzlemeGozlemci extends NavigatorObserver {
  String _ad(Route<dynamic>? r) =>
      r == null ? '-' : (r.settings.name ?? r.runtimeType.toString());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? onceki) =>
      Izleme.o.iz('ekran: aç ${_ad(route)}');
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? onceki) =>
      Izleme.o.iz('ekran: kapat ${_ad(route)} -> ${_ad(onceki)}');
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      Izleme.o.iz('ekran: değiş ${_ad(oldRoute)} -> ${_ad(newRoute)}');
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? onceki) =>
      Izleme.o.iz('ekran: sil ${_ad(route)}');
}
