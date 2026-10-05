import 'package:flutter/material.dart';
import '../dil.dart';
import '../hesap.dart';
import '../ses_servis.dart';
import 'card_widget.dart';
import 'profil_ekrani.dart';
import 'sayac.dart';

/// Altın dükkânı: kart arkası, masa çuhası, özel avatar paketi. Satın alınan eşya seçilebilir.
class DukkanEkrani extends StatefulWidget {
  const DukkanEkrani({super.key});
  @override
  State<DukkanEkrani> createState() => _DukkanEkraniState();
}

class _DukkanEkraniState extends State<DukkanEkrani> {
  final h = Hesap.o;
  List<Map<String, dynamic>>? _esyalar;
  String? _mesaj;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    h.magaza().then((l) {
      if (mounted) setState(() => _esyalar = l);
    }).catchError((_) {
      if (mounted) setState(() => _mesaj = t('Dükkâna ulaşılamadı.'));
    });
  }

  Future<void> _al(String id) async {
    setState(() => _mesgul = true);
    final hata = await h.satinAl(id);
    if (hata == null) AltinSes.azaldi();
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? t('Satın alındı!');
      });
    }
  }

  Future<void> _sec(String tur, String id) async {
    setState(() => _mesgul = true);
    final hata = await h.secim(kartArkasi: tur == 'kart' ? id : null, masa: tur == 'masa' ? id : null);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? t('Seçildi.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sahip = {'klasik', 'yesil', ...h.esyalar};
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D25),
        foregroundColor: Colors.white,
        title: Text(t('Dükkân')),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: SayiGecis(deger: h.altin, bicim: (n) => '💰 $n', stil: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16))))],
      ),
      body: _esyalar == null
          ? Center(child: _mesaj != null ? Text(sunucuMesaj(_mesaj!), style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: Colors.amber))
          : ListView(padding: const EdgeInsets.all(14), children: [
              Text(t('Altın; oyun sonu ödülleri ve günlük bonusla kazanılır.'), style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 10),
              if (h.misafir)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
                  child: Row(children: [
                    Expanded(child: Text(t('Satın almak için giriş yapmalısın. Gezinebilirsin.'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilEkrani()));
                        if (mounted) setState(() {});
                      },
                      child: Text(t('Giriş yap')),
                    ),
                  ]),
                ),
              _baslik(t('Kart arkası')),
              _satir('kart', 'klasik', t('Klasik (kırmızı)'), 0, sahip, h.kartArkasi),
              for (final e in _esyalar!.where((e) => e['tur'] == 'kart')) _satir('kart', e['id'] as String, e['ad'] as String, e['fiyat'] as int, sahip, h.kartArkasi),
              _baslik(t('Masa çuhası')),
              _satir('masa', 'yesil', t('Yeşil çuha'), 0, sahip, h.masa),
              for (final e in _esyalar!.where((e) => e['tur'] == 'masa')) _satir('masa', e['id'] as String, e['ad'] as String, e['fiyat'] as int, sahip, h.masa),
              _baslik(t('Avatarlar')),
              for (final e in _esyalar!.where((e) => e['tur'] == 'avatar')) _satir('avatar', e['id'] as String, e['ad'] as String, e['fiyat'] as int, sahip, null),
              if (_mesaj != null) Padding(padding: const EdgeInsets.all(12), child: Text(sunucuMesaj(_mesaj!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
    );
  }

  Widget _baslik(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6), child: Text(s, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16)));

  Widget _satir(String tur, String id, String ad, int fiyat, Set<String> sahip, String? secili) {
    final var_ = sahip.contains(id);
    final secildi = secili == id;
    Widget onizleme;
    if (tur == 'kart') {
      onizleme = CardBack(w: 40, stil: id);
    } else if (tur == 'masa') {
      onizleme = Container(width: 56, height: 40, decoration: BoxDecoration(color: masaRengi(id), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF5C3A1E), width: 3)));
    } else {
      onizleme = const Text('🐉🦅🦈🐬', style: TextStyle(fontSize: 18));
    }
    return Card(
      color: secildi ? const Color(0xFF1E7B3A) : Colors.white10,
      child: ListTile(
        leading: onizleme,
        title: Text(sunucuMesaj(ad), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(var_ ? (secildi ? t('Seçili') : t('Sende var')) : t('{n} altın', {'n': fiyat}), style: const TextStyle(color: Colors.white70)),
        trailing: var_
            ? (tur == 'avatar' || secildi
                ? const Icon(Icons.check_circle, color: Colors.amber)
                : TextButton(onPressed: _mesgul ? null : () => _sec(tur, id), child: Text(t('Seç'), style: TextStyle(color: Colors.amber))))
            : FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: _mesgul || h.misafir || h.altin < fiyat ? null : () => _al(id),
                child: Text(t('Al · {n}', {'n': fiyat})),
              ),
      ),
    );
  }
}

/// Masa çuhası rengi (eşya id → renk).
Color masaRengi(String id) => const {
      'yesil': Color(0xFF1B5E3A),
      'masa_bordo': Color(0xFF6E1B2B),
      'masa_lacivert': Color(0xFF1B2E5E),
      'masa_siyah': Color(0xFF1C1C1C),
    }[id] ?? const Color(0xFF1B5E3A);
