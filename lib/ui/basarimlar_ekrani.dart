import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../ayarlar.dart';
import '../basarimlar.dart';

/// Başarımlar ve sunucudaki liderlik tablosu.
class BasarimlarEkrani extends StatefulWidget {
  const BasarimlarEkrani({super.key});
  @override
  State<BasarimlarEkrani> createState() => _BasarimlarEkraniState();
}

class _BasarimlarEkraniState extends State<BasarimlarEkrani> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>>? _lider;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _liderlikYukle();
  }

  /// ws://host:port → http://host:port/liderlik
  static String liderlikAdresi(String sunucu) => '${sunucu.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://')}/liderlik';

  Future<void> _liderlikYukle() async {
    try {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final r = await c.getUrl(Uri.parse(liderlikAdresi(Ayarlar.o.sunucu)));
      final y = await r.close();
      final j = jsonDecode(await y.transform(utf8.decoder).join()) as List;
      if (mounted) setState(() => _lider = [for (final e in j) Map<String, dynamic>.from(e as Map)]);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Sunucuya ulaşılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = BasarimDurumu.o;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D25),
        foregroundColor: Colors.white,
        title: const Text('Başarımlar'),
        bottom: TabBar(controller: _tab, indicatorColor: Colors.amber, labelColor: Colors.amber, unselectedLabelColor: Colors.white70, tabs: [
          Tab(text: 'Rozetler ${d.acik.length}/${basarimlar.length}'),
          const Tab(text: 'Liderlik'),
        ]),
      ),
      body: TabBarView(controller: _tab, children: [
        ListView(padding: const EdgeInsets.all(12), children: [
          for (final b in basarimlar)
            Opacity(
              opacity: d.acik.contains(b.id) ? 1 : 0.45,
              child: ListTile(
                leading: Text(b.ikon, style: const TextStyle(fontSize: 30)),
                title: Text(b.ad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Text(b.aciklama, style: const TextStyle(color: Colors.white70)),
                trailing: d.acik.contains(b.id) ? const Icon(Icons.check_circle, color: Colors.amber) : const Icon(Icons.lock_outline, color: Colors.white30),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Seri: ${d.seri} galibiyet · Toplam ${Ayarlar.o.oynanan} oyun, ${Ayarlar.o.kazanilan} galibiyet',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ]),
        _lider == null
            ? Center(child: _hata != null ? Text(_hata!, style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: Colors.amber))
            : RefreshIndicator(
                onRefresh: _liderlikYukle,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _lider!.length,
                  itemBuilder: (_, i) {
                    final e = _lider![i];
                    final ben = e['ad'] == Ayarlar.o.ad;
                    return ListTile(
                      leading: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}.', style: TextStyle(color: Colors.white, fontSize: i < 3 ? 24 : 16, fontWeight: FontWeight.w800)),
                      title: Text(e['ad'] as String, style: TextStyle(color: ben ? Colors.amber : Colors.white, fontWeight: FontWeight.w800)),
                      subtitle: Text('${e['galibiyet']} galibiyet / ${e['oyun']} oyun${(e['online'] ?? 0) > 0 ? ' · ${e['online']} online' : ''}', style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ),
      ]),
    );
  }
}
