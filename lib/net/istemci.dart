import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Sunucuya WebSocket bağlantısı; JSON mesaj gönderir, gelenleri akıtır.
class Istemci {
  Istemci(this.adres);
  final String adres; // ws://192.168.1.21:8765
  WebSocket? _ws;
  final _gelen = StreamController<Map<String, dynamic>>.broadcast();
  final _kopma = StreamController<void>.broadcast();
  Stream<Map<String, dynamic>> get mesajlar => _gelen.stream;
  Stream<void> get koptu => _kopma.stream;
  bool get bagli => _ws != null && _ws!.readyState == WebSocket.open;

  Future<void> baglan() async {
    final ws = await WebSocket.connect(adres).timeout(const Duration(seconds: 8));
    _ws = ws;
    ws.listen((v) {
      try {
        _gelen.add(jsonDecode(v as String) as Map<String, dynamic>);
      } catch (_) {}
    }, onDone: () {
      _ws = null;
      _kopma.add(null);
    }, onError: (_) {
      _ws = null;
      _kopma.add(null);
    });
  }

  void gonder(Map<String, dynamic> m) {
    final ws = _ws;
    if (ws == null) return;
    ws.add(jsonEncode(m));
  }

  /// Belirli bir tipteki ilk mesajı bekler.
  Future<Map<String, dynamic>> bekle(String tip, {Duration sure = const Duration(seconds: 10)}) =>
      mesajlar.firstWhere((m) => m['t'] == tip).timeout(sure);

  Future<void> kapat() async {
    await _ws?.close();
    _ws = null;
  }
}
