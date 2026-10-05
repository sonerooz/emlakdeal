import 'package:flutter/material.dart';
import '../dil.dart';
import '../hesap.dart';
import '../ses_servis.dart';
import 'profil_ekrani.dart';
import 'sayac.dart';

/// Günlük görevler: tamamlayınca ekstra XP ve altın.
class GorevlerEkrani extends StatefulWidget {
  const GorevlerEkrani({super.key});
  @override
  State<GorevlerEkrani> createState() => _GorevlerEkraniState();
}

class _GorevlerEkraniState extends State<GorevlerEkrani> {
  final h = Hesap.o;
  List<Map<String, dynamic>>? _liste;
  bool _hata = false;
  String? _mesgul;
  String? _bilgi;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (h.misafir) return;
    final l = await h.gorevler();
    if (!mounted) return;
    setState(() {
      _liste = l;
      _hata = l == null;
    });
  }

  Future<void> _al(Map<String, dynamic> g) async {
    setState(() => _mesgul = g['id'] as String);
    final r = await h.gorevAl(g['id'] as String);
    if (!mounted) return;
    if (r != null) AltinSes.artti();
    setState(() {
      _mesgul = null;
      if (r != null) {
        _liste = [for (final x in (r['gorevler'] as List)) Map<String, dynamic>.from(x as Map)];
        _bilgi = '+${r['xp']} XP  ·  ${t('{n} altın', {'n': r['altin']})}${r['levelAtladi'] == true ? '  ·  ${t('Seviye {n}', {'n': r['level']})}' : ''}';
      } else {
        _bilgi = t('Sunucuya ulaşılamadı.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kota = h.botKotaKullanilan, limit = h.botKotaLimit;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D25),
        foregroundColor: Colors.white,
        title: Text(t('Günlük görevler')),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: SayiGecis(deger: h.altin, bicim: (n) => '💰 $n', stil: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16))))],
      ),
      body: h.misafir
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('Günlük görevler için giriş yapmalısın.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfilEkrani())),
                    icon: const Icon(Icons.login),
                    label: Text(t('Giriş yap')),
                  ),
                ]),
              ),
            )
          : _liste == null
              ? Center(child: _hata ? Text(t('Sunucuya ulaşılamadı.'), style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: Colors.amber))
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    Text(t('Her gün yeni görevler gelir. Tamamla, ödülü al: ekstra XP ve altın!'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 10),
                    if (_bilgi != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Text('🎉 $_bilgi', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    for (final g in _liste!) _gorev(g),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('Bugünkü bot oyunu kotası'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(value: (kota / limit).clamp(0, 1).toDouble(), minHeight: 10, backgroundColor: Colors.white12, color: h.botKotaDoldu ? Colors.redAccent : Colors.amber),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          h.botKotaDoldu
                              ? t('Günlük sınıra ulaştın: botlu oyunlar bugün altın vermez. Online oyunlarda sınır yok.')
                              : t('Botlu oyunlardan günde en çok {n} altın kazanılır ({k} kullanıldı). Online oyunlarda sınır yok.', {'n': limit, 'k': kota}),
                          style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                        ),
                      ]),
                    ),
                  ]),
                ),
    );
  }

  Widget _gorev(Map<String, dynamic> g) {
    final hedef = g['hedef'] as int, il = g['ilerleme'] as int;
    final tamam = g['tamam'] == true, alindi = g['alindi'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alindi ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tamam && !alindi ? Colors.amber : Colors.white12, width: tamam && !alindi ? 1.8 : 1),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t(g['ad'] as String), style: TextStyle(color: alindi ? Colors.white38 : Colors.white, fontWeight: FontWeight.w800, fontSize: 15, decoration: alindi ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: il / hedef, minHeight: 8, backgroundColor: Colors.white12, color: tamam ? Colors.greenAccent : Colors.lightBlueAccent),
            ),
            const SizedBox(height: 4),
            Text('$il / $hedef   ·   +${g['xp']} XP   ·   ${t('{n} altın', {'n': g['altin']})}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 10),
        if (alindi)
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 30)
        else if (tamam)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            onPressed: _mesgul != null ? null : () => _al(g),
            child: Text(t('Al')),
          )
        else
          const Icon(Icons.lock_clock, color: Colors.white30, size: 28),
      ]),
    );
  }
}
