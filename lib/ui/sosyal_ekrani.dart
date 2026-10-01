import 'package:flutter/material.dart';
import '../hesap.dart';

/// Arkadaşlar (ekle/sil, çevrim içi durumu, odaya davet) ve oyun geçmişi + kazanma grafiği.
class SosyalEkrani extends StatefulWidget {
  const SosyalEkrani({super.key, this.odaKodu, this.davetGonder});
  /// Lobideyken: davet için oda kodu ve gönderici.
  final String? odaKodu;
  final void Function(String nick)? davetGonder;
  @override
  State<SosyalEkrani> createState() => _SosyalEkraniState();
}

class _SosyalEkraniState extends State<SosyalEkrani> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  final h = Hesap.o;
  final _nick = TextEditingController();
  List<Map<String, dynamic>>? _arkadaslar;
  List<Map<String, dynamic>>? _gecmis;
  String? _mesaj;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final a = await h.arkadaslar();
      final g = await h.gecmis();
      if (mounted) setState(() {
        _arkadaslar = a;
        _gecmis = g;
      });
    } catch (e) {
      if (mounted) setState(() => _mesaj = 'Sunucuya ulaşılamadı.');
    }
  }

  Future<void> _ekle() async {
    final hata = await h.arkadasEkle(_nick.text);
    setState(() => _mesaj = hata ?? 'Eklendi.');
    _nick.clear();
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D25),
        foregroundColor: Colors.white,
        title: const Text('Arkadaşlar & Geçmiş'),
        bottom: TabBar(controller: _tab, indicatorColor: Colors.amber, labelColor: Colors.amber, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: 'Arkadaşlar'), Tab(text: 'Geçmiş')]),
      ),
      body: TabBarView(controller: _tab, children: [
        ListView(padding: const EdgeInsets.all(14), children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nick,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Takma adla ekle', labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber))),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: _ekle, child: const Text('Ekle')),
          ]),
          if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_mesaj!, style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 10),
          if (_arkadaslar == null)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.amber)))
          else if (_arkadaslar!.isEmpty)
            const Text('Henüz arkadaş yok. Takma adıyla ekle; çevrim içiyse odana davet edebilirsin.', style: TextStyle(color: Colors.white54))
          else
            for (final a in _arkadaslar!)
              ListTile(
                leading: Text(a['avatar'] as String? ?? '🙂', style: const TextStyle(fontSize: 26)),
                title: Text('${a['nick']}  ·  Sv ${a['level']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  a['cevrimici'] == true ? (a['odada'] != null ? 'Çevrim içi · odada (${a['odada']})' : 'Çevrim içi') : 'Çevrim dışı',
                  style: TextStyle(color: a['cevrimici'] == true ? Colors.greenAccent : Colors.white38, fontSize: 12),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.davetGonder != null && a['cevrimici'] == true)
                    TextButton(onPressed: () => widget.davetGonder!(a['nick'] as String), child: const Text('Davet et', style: TextStyle(color: Colors.amber))),
                  IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.white38),
                    onPressed: () async {
                      await h.arkadasSil(a['nick'] as String);
                      _yukle();
                    },
                  ),
                ]),
              ),
        ]),
        _gecmis == null
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : ListView(padding: const EdgeInsets.all(14), children: [
                _grafik(_gecmis!),
                const SizedBox(height: 10),
                if (_gecmis!.isEmpty) const Text('Henüz oyun yok.', style: TextStyle(color: Colors.white54)),
                for (final g in _gecmis!)
                  ListTile(
                    dense: true,
                    leading: Icon(g['kazandi'] == true ? Icons.emoji_events : Icons.close, color: g['kazandi'] == true ? Colors.amber : Colors.white38),
                    title: Text('${g['kazandi'] == true ? 'Galibiyet' : 'Mağlubiyet'} · ${g['mod'] == 'online' ? 'online' : 'botla'} · ${g['rakip']} rakip', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${(g['tarih'] as String).replaceFirst('T', ' ').substring(0, 16)}  ·  +${g['xp']} XP, +${g['altin']} altın', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
              ]),
      ]),
    );
  }

  /// Son oyunların kazanma oranı (çubuk) + son 10 oyun şeridi.
  Widget _grafik(List<Map<String, dynamic>> l) {
    if (l.isEmpty) return const SizedBox();
    final toplam = l.length, g = l.where((e) => e['kazandi'] == true).length;
    final oran = g / toplam;
    final son = l.take(10).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Son $toplam oyun: $g galibiyet (%${(oran * 100).round()})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: oran, minHeight: 14, backgroundColor: Colors.redAccent.withValues(alpha: 0.5), color: Colors.greenAccent)),
        const SizedBox(height: 10),
        const Text('Son 10 oyun', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Row(children: [
          for (final e in son)
            Expanded(
              child: Container(
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: e['kazandi'] == true ? Colors.greenAccent : Colors.redAccent.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                alignment: Alignment.center,
                child: Text(e['kazandi'] == true ? 'G' : 'M', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
        ]),
      ]),
    );
  }
}
