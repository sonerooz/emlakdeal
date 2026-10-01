import 'package:flutter/material.dart';
import '../ayarlar.dart';

/// İlk açılışta (ve menüden) 6 adımlık görsel öğretici.
class OgreticiEkrani extends StatefulWidget {
  const OgreticiEkrani({super.key});
  @override
  State<OgreticiEkrani> createState() => _OgreticiEkraniState();
}

class _OgreticiEkraniState extends State<OgreticiEkrani> {
  final _pc = PageController();
  int _i = 0;

  static const _adimlar = [
    (Icons.flag, 'Amaç', 'Farklı renkte 3 TAM tapu seti toplayan kazanır. Set boyları kartın üstünde yazar (2, 3 ya da 4 tapu).'),
    (Icons.style, 'Tur', 'Her tur 2 kart çek, en fazla 3 hamle yap. Tapu ya da para kartına bir kez dokun: tapu sete, para bankaya gider.'),
    (Icons.attach_money, 'Para ve ödeme', 'Hamle kartları bankaya konursa para olur. Borç; banka ve tapulardan ödenir, elden ödenmez. Yetmezse her şeyini verirsin.'),
    (Icons.receipt_long, 'Kira', 'Kira kartı: o renkte tapun varsa HERKESTEN kira alırsın. Çift Kira ile iki katı (2 hamle harcar).'),
    (Icons.gavel, 'Saldırı kartları', 'Tapu Devri: tam olmayan setten tapu al. Değiş Tokuş: takas. Haciz: TAM seti al. Tahsilat: birinden 5M. Reddet: sana oynanan hamleyi iptal eder.'),
    (Icons.threed_rotation, 'Masa', 'Masayı parmağınla döndür, iki parmakla yakınlaştır. Sağ alttaki rozetlerle oyuncuya odaklan, tepeden bak, sıfırla. Jokerine dokunup rengini değiştirebilirsin.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _adimlar.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final (ikon, baslik, metin) = _adimlar[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: Icon(ikon, size: 64, color: Colors.black),
                    ),
                    const SizedBox(height: 28),
                    Text(baslik, style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    Text(metin, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.45)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _adimlar.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: i == _i ? Colors.amber : Colors.white30, shape: BoxShape.circle),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Row(children: [
              TextButton(onPressed: _bitir, child: const Text('Atla', style: TextStyle(color: Colors.white70))),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                onPressed: _i == _adimlar.length - 1 ? _bitir : () => _pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(_i == _adimlar.length - 1 ? 'Başla' : 'İleri', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _bitir() {
    Ayarlar.o.ogreticiGoruldu = true;
    Ayarlar.o.kaydet();
    Navigator.of(context).pop();
  }
}
