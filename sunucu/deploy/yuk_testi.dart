// Emlak Deal yük testi (ELLE çalıştırılır; paket gerektirmez).
//   dart deploy/yuk_testi.dart --url wss://oyun.ornek.com --baglanti 200 --sure 60
//   dart deploy/yuk_testi.dart --url wss://oyun.ornek.com --odalar tokenlar.txt --sure 300
// Mod 1 (varsayılan): N boş WS bağlantısı açar, her saniye ping atar, gecikmeyi (ms) ölçer.
// Mod 2 (--odalar): dosyadaki her oturum belirteci (satır başına bir adet; e-posta/sosyal girişli hesap
//   belirteçleri) 3 botlu bir oda kurup oyunu başlatır => oda zamanlayıcıları + bot düşünme yükü.
//   Belirteç üretmek için test hesapları açıp /api/giris ile token alın.
// DİKKAT: canlı sunucuya karşı çalıştırma; önce odalar=0 olduğunu doğrula. Test odaları kapanınca kendiliğinden silinir.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> a) async {
  String arg(String ad, String varsayilan) {
    final i = a.indexOf('--$ad');
    return i >= 0 && i + 1 < a.length ? a[i + 1] : varsayilan;
  }

  final url = arg('url', 'ws://127.0.0.1:8765');
  final n = int.parse(arg('baglanti', '50'));
  final sure = int.parse(arg('sure', '30'));
  final tokenDosya = arg('odalar', '');
  final gecikmeler = <int>[];
  var hata = 0, kopan = 0, acilan = 0;
  final soketler = <WebSocket>[];

  Future<void> bagla(String? token) async {
    try {
      final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 15));
      soketler.add(ws);
      acilan++;
      DateTime? gonderildi;
      ws.listen((v) {
        final m = jsonDecode(v as String) as Map<String, dynamic>;
        if (m['t'] == 'pong' && gonderildi != null) {
          gecikmeler.add(DateTime.now().difference(gonderildi!).inMilliseconds);
        }
      }, onDone: () => kopan++, onError: (_) => hata++);
      if (token != null) {
        ws.add(jsonEncode({'t': 'kur', 'token': token, 'bot': 3}));
        await Future.delayed(const Duration(seconds: 1));
        ws.add(jsonEncode({'t': 'basla'}));
      }
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (ws.readyState != WebSocket.open) return t.cancel();
        gonderildi = DateTime.now();
        ws.add(jsonEncode({'t': 'ping'}));
      });
    } catch (_) {
      hata++;
    }
  }

  final tokenlar = tokenDosya.isEmpty
      ? <String?>[for (var i = 0; i < n; i++) null]
      : File(tokenDosya).readAsLinesSync().map((s) => s.trim()).where((s) => s.isNotEmpty).cast<String?>().toList();

  print('Hedef: $url  bağlantı: ${tokenlar.length}  süre: ${sure}s  mod: ${tokenDosya.isEmpty ? "boş bağlantı" : "oda+bot"}');
  for (final t in tokenlar) {
    await bagla(t);
    await Future.delayed(const Duration(milliseconds: 50)); // kademeli
  }
  print('açılan: $acilan, hata: $hata');

  final ilkSaglik = await _saglik(url);
  print('sağlık (başta): $ilkSaglik');
  await Future.delayed(Duration(seconds: sure));

  gecikmeler.sort();
  int yuzde(double p) => gecikmeler.isEmpty ? -1 : gecikmeler[((gecikmeler.length - 1) * p).round()];
  print('--- SONUÇ ---');
  print('ping örnek: ${gecikmeler.length}  p50: ${yuzde(0.5)} ms  p95: ${yuzde(0.95)} ms  p99: ${yuzde(0.99)} ms  max: ${yuzde(1)} ms');
  print('hata: $hata  beklenmedik kopan: $kopan');
  print('sağlık (sonda): ${await _saglik(url)}');
  print('Yorum: p95 < 200 ms ve hata=0 ise bu yükte rahat. Sunucuda `docker stats` / `top` ile CPU ve RAM\'e de bak.');
  for (final s in soketler) {
    await s.close();
  }
  exit(0);
}

Future<String> _saglik(String wsUrl) async {
  try {
    final http = wsUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');
    final c = HttpClient();
    final r = await (await c.getUrl(Uri.parse('$http/saglik'))).close();
    final s = await r.transform(utf8.decoder).join();
    c.close();
    return s;
  } catch (e) {
    return 'ulaşılamadı: $e';
  }
}
