import 'package:flutter/material.dart';
import '../ayarlar.dart';
import '../dil.dart';
import '../basarimlar.dart';
import '../hesap.dart';

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

  Future<void> _liderlikYukle() async {
    try {
      final l = await Hesap.o.liderlik();
      if (mounted) setState(() => _lider = l);
    } catch (e) {
      if (mounted) setState(() => _hata = t('Sunucuya ulaşılamadı.'));
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
        title: Text(t('Başarımlar')),
        bottom: TabBar(controller: _tab, indicatorColor: Colors.amber, labelColor: Colors.amber, unselectedLabelColor: Colors.white70, tabs: [
          Tab(text: t('Rozetler {a}/{b}', {'a': d.acik.length, 'b': basarimlar.length})),
          Tab(text: t('Liderlik')),
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
            child: Text(t('Seri: {seri} galibiyet · Toplam {oyun} oyun, {gal} galibiyet', {'seri': d.seri, 'oyun': Ayarlar.o.oynanan, 'gal': Ayarlar.o.kazanilan}),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ]),
        _lider == null
            ? Center(child: _hata != null ? Text(sunucuMesaj(_hata!), style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: Colors.amber))
            : RefreshIndicator(
                onRefresh: _liderlikYukle,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _lider!.length,
                  itemBuilder: (_, i) {
                    final e = _lider![i];
                    final ben = e['nick'] == Hesap.o.nick;
                    return ListTile(
                      leading: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}.', style: TextStyle(color: Colors.white, fontSize: i < 3 ? 24 : 16, fontWeight: FontWeight.w800)),
                      title: Text('${e['avatar'] ?? ''} ${e['nick']}  ·  ${t('Sv')} ${e['level']}', style: TextStyle(color: ben ? Colors.amber : Colors.white, fontWeight: FontWeight.w800)),
                      subtitle: Text('${t('{xp} XP · {gal} galibiyet / {oyun} oyun', {'xp': e['xp'], 'gal': e['galibiyet'], 'oyun': e['oyun']})}${(e['onlineGalibiyet'] ?? 0) > 0 ? ' · ${t('{n} online', {'n': e['onlineGalibiyet']})}' : ''}', style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ),
      ]),
    );
  }
}
