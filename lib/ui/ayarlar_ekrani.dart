import 'package:flutter/material.dart';
import '../ayarlar.dart';

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});
  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  final a = Ayarlar.o;
  late final _ad = TextEditingController(text: a.ad);
  late final _sunucu = TextEditingController(text: a.sunucu);

  @override
  void dispose() {
    a.ad = _ad.text.trim().isEmpty ? 'Sen' : _ad.text.trim();
    a.sunucu = _sunucu.text.trim();
    a.kaydet();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oran = a.oynanan == 0 ? 0 : (a.kazanilan * 100 / a.oynanan).round();
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: const Text('Ayarlar')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _ad, style: const TextStyle(color: Colors.white), decoration: _dec('Adın (masada görünür)')),
        const SizedBox(height: 16),
        SwitchListTile(
          value: a.sesli,
          onChanged: (v) => setState(() => a.sesli = v),
          activeColor: Colors.amber,
          title: const Text('Oyuncu sesleri', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Kira istiyorum, reddediyorum… konuşmaları', style: TextStyle(color: Colors.white54)),
        ),
        const SizedBox(height: 8),
        const Text('Bot zorluğu', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
          segments: const [
            ButtonSegment(value: 0, label: Text('Kolay')),
            ButtonSegment(value: 1, label: Text('Normal')),
            ButtonSegment(value: 2, label: Text('Zor')),
          ],
          selected: {a.botZorluk},
          onSelectionChanged: (s) => setState(() => a.botZorluk = s.first),
        ),
        const SizedBox(height: 6),
        Text(
          const ['Kolay bot fırsatların yarısını kaçırır, Reddet\'i nadiren kullanır.', 'Normal bot mantıklı oynar.', 'Zor bot her fırsatı kullanır, elini erken zenginleştirir.'][a.botZorluk],
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 20),
        TextField(controller: _sunucu, style: const TextStyle(color: Colors.white70, fontSize: 13), decoration: _dec('Online sunucu adresi')),
        const SizedBox(height: 24),
        const Text('İstatistikler', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Oynanan: ${a.oynanan}   Kazanılan: ${a.kazanilan}   Başarı: %$oran', style: const TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            a.oynanan = 0;
            a.kazanilan = 0;
          }),
          child: const Text('İstatistikleri sıfırla', style: TextStyle(color: Colors.white54)),
        ),
      ]),
    );
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
      );
}
