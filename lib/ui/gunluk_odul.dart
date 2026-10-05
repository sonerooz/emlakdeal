import 'package:flutter/material.dart';
import '../dil.dart';
import '../hesap.dart';
import '../ses_servis.dart';
import 'profil_ekrani.dart';
import 'sayac.dart';

/// 7 günlük seri ödülü penceresi: 1-6. gün küçük kutu, 7. gün büyük kutu.
Future<void> gunlukOdulAc(BuildContext context) => showDialog(context: context, builder: (_) => const _GunlukOdul());

class _GunlukOdul extends StatefulWidget {
  const _GunlukOdul();
  @override
  State<_GunlukOdul> createState() => _GunlukOdulState();
}

class _GunlukOdulState extends State<_GunlukOdul> {
  final h = Hesap.o;
  bool _mesgul = false;
  String? _mesaj;
  int? _kazanc;
  bool _buyuk = false;

  Future<void> _dene() async {
    final g = h.bonusGun;
    AltinSes.artti();
    setState(() {
      _kazanc = h.bonusOdulleri[g - 1];
      _buyuk = g == 7;
      _mesaj = null;
    });
    await Future.delayed(const Duration(milliseconds: 2300));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _al() async {
    setState(() => _mesgul = true);
    final r = await h.bonusAl();
    if (!mounted) return;
    final alindi = r != null && r['alindi'] == true;
    if (alindi) AltinSes.artti();
    setState(() {
      _mesgul = false;
      if (alindi) {
        _kazanc = (r['bonus'] as num?)?.toInt() ?? 0;
        _buyuk = r['buyuk'] == true;
      }
      _mesaj = r == null
          ? t('Sunucuya ulaşılamadı.')
          : r['alindi'] == true
              ? (r['buyuk'] == true ? t('🎉 Büyük kutu açıldı: +{n} altın!', {'n': r['bonus']}) : t('🎁 +{n} altın!', {'n': r['bonus']}))
              : t('Bugünkü ödül zaten alınmış.');
    });
    if (alindi) {
      await Future.delayed(const Duration(milliseconds: 2300));
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _girisYap() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => const ProfilEkrani()));
  }

  @override
  Widget build(BuildContext context) {
    final misafir = h.misafir;
    final oduller = h.bonusOdulleri;
    final gun = h.bonusGun;
    final hazir = !misafir && h.bonusHazir;
    bool alindi(int i) => !misafir && (i < gun || (i == gun && !h.bonusHazir));
    final yarin = oduller[gun % 7];
    final altyazi = misafir
        ? t('Giriş yap, her gün ödül kazan. Seriyi bozma: 7. günün büyük kutusu seni bekliyor!')
        : hazir
            ? t('{gun}. gün ödülün hazır! Her gün gir, seri bozulmasın.', {'gun': gun})
            : t('Bugünkü ödülünü aldın. Yarın: {n} altın', {'n': yarin}) + (gun == 6 ? t(' (BÜYÜK KUTU)') : '');
    return Dialog(
      backgroundColor: const Color(0xFF123F2A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.amber, width: 1.5)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('🎁 Günlük Ödül'), style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(altyazi, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
          const SizedBox(height: 14),
          for (final satir in [
            [1, 2, 3],
            [4, 5, 6]
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                for (final i in satir) ...[
                  if (i != satir.first) const SizedBox(width: 8),
                  Expanded(child: _kutu(i, oduller[i - 1], alindi(i), hazir && i == gun)),
                ]
              ]),
            ),
          _buyukKutu(oduller[6], alindi(7), hazir && gun == 7),
          if (_kazanc != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(children: [
                if (_buyuk) Text(t('🎉 Büyük kutu açıldı!'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                SayiSayac(deger: _kazanc!, bicim: (n) => '💰 +$n', stil: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 34)),
              ]),
            )
          else if (_mesaj != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_mesaj!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: misafir
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _girisYap,
                    icon: const Icon(Icons.login),
                    label: Text(t('Giriş yap, ödülü al'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _mesgul ? null : (h.bonusHazir ? _al : () => Navigator.pop(context)),
                    child: Text(h.bonusHazir ? t('Ödülü al') : t('Tamam'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
          ),
          if (!misafir && !h.bonusHazir && _kazanc == null)
            TextButton(onPressed: _dene, child: Text(t('🧪 Animasyonu dene (ödül verilmez)'), style: const TextStyle(color: Colors.white54))),
          if (misafir)
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Şimdi değil'), style: TextStyle(color: Colors.white54))),
        ]),
      ),
    );
  }

  Widget _kutu(int gun, int miktar, bool alindi, bool bugun) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: alindi ? Colors.green.withValues(alpha: 0.3) : (bugun ? Colors.amber.withValues(alpha: 0.22) : Colors.white10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bugun ? Colors.amber : (alindi ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.white24), width: bugun ? 2.5 : 1),
          boxShadow: bugun ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.35), blurRadius: 12)] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('{gun}. gün', {'gun': gun}), style: TextStyle(color: bugun ? Colors.amber : Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Icon(alindi ? Icons.check_circle : Icons.card_giftcard, size: 32, color: alindi ? Colors.greenAccent : (bugun ? Colors.amber : Colors.white70)),
          const SizedBox(height: 4),
          Text('💰 $miktar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );

  Widget _buyukKutu(int miktar, bool alindi, bool bugun) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: alindi ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)] : [const Color(0xFFFFD54F), const Color(0xFFE09A1B)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bugun ? Colors.white : Colors.amber.shade200, width: bugun ? 3 : 1.5),
          boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: bugun ? 0.6 : 0.25), blurRadius: bugun ? 18 : 8)],
        ),
        child: Row(children: [
          Icon(alindi ? Icons.check_circle : Icons.redeem, size: 52, color: alindi ? Colors.greenAccent : const Color(0xFF5D3A00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('7. GÜN · BÜYÜK KUTU'), style: TextStyle(color: alindi ? Colors.white70 : const Color(0xFF5D3A00), fontWeight: FontWeight.w900, fontSize: 13)),
              Text(t('💰 {n} altın', {'n': miktar}), style: TextStyle(color: alindi ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
              Text(t('Sonraki gün seri başa döner'), style: TextStyle(color: alindi ? Colors.white54 : const Color(0xFF5D3A00), fontSize: 11)),
            ]),
          ),
        ]),
      );
}
