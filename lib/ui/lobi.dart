import 'dart:async';
import 'package:flutter/material.dart';
import '../ayarlar.dart';
import '../hesap.dart';
import '../net/istemci.dart';
import 'game_screen.dart';
import 'sosyal_ekrani.dart';

const varsayilanSunucu = 'wss://emlakdeal.tailb92005.ts.net';

/// Online oyun: sunucuya bağlan, oda kur / odaya katıl, oyuncuları gör, başlat.
class LobiEkrani extends StatefulWidget {
  const LobiEkrani({super.key, this.odaKodu});
  /// Davetle gelindiyse otomatik katılınacak oda.
  final String? odaKodu;
  @override
  State<LobiEkrani> createState() => _LobiEkraniState();
}

class _LobiEkraniState extends State<LobiEkrani> {
  final _ad = TextEditingController(text: Ayarlar.o.ad);
  final _sunucu = TextEditingController(text: Ayarlar.o.sunucu);
  final _kod = TextEditingController();
  Istemci? _net;
  StreamSubscription? _abone;
  Map<String, dynamic>? _oda;
  int _bot = 1;
  int _sure = 60;
  bool _hazir = false;
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    if (widget.odaKodu != null) {
      _kod.text = widget.odaKodu!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _baglan({'t': 'katil', 'ad': _ad.text, 'oda': _kod.text, 'token': Hesap.o.token}));
    }
  }

  @override
  void dispose() {
    _abone?.cancel();
    if (_oda == null) _net?.kapat();
    super.dispose();
  }

  Future<void> _baglan(Map<String, dynamic> ilkMesaj) async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    Ayarlar.o.ad = _ad.text.trim().isEmpty ? 'Oyuncu' : _ad.text.trim();
    Ayarlar.o.sunucu = _sunucu.text.trim();
    Ayarlar.o.kaydet();
    try {
      Istemci net;
      try {
        net = Istemci(_sunucu.text.trim());
        await net.baglan();
      } catch (e) {
        // ev içindeyken dış adres (hairpin NAT) çalışmayabilir: yerel adresi dene
        if (_sunucu.text.trim() == Ayarlar.sunucuYerel) rethrow;
        net = Istemci(Ayarlar.sunucuYerel);
        await net.baglan();
      }
      _net = net;
      _abone = net.mesajlar.listen(_mesaj);
      net.koptu.listen((_) {
        if (mounted && _oda != null) setState(() {
          _oda = null;
          _hata = 'Sunucu bağlantısı koptu.';
        });
      });
      net.gonder(ilkMesaj);
    } catch (e) {
      setState(() => _hata = 'Bağlanılamadı: ${_sunucu.text}\n$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  void _mesaj(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'oda':
        setState(() {
          _oda = m;
          _bot = m['bot'] as int;
          _sure = (m['sure'] as int?) ?? 60;
        });
      case 'hata':
        setState(() => _hata = m['m'] as String?);
      case 'bilgi':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m['m'] as String? ?? '')));
      case 'basladi':
        final net = _net!;
        _abone?.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GameScreen(
            net: net,
            benIdx: m['sen'] as int,
            adlar: (m['adlar'] as List).cast<String>(),
            botlar: (m['botlar'] as List).cast<bool>(),
            avatarlar: (m['avatarlar'] as List?)?.cast<String>() ?? const [],
            leveller: (m['leveller'] as List?)?.cast<int>() ?? const [],
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final oda = _oda;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: const Text('Online oyun')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (oda == null) ...[
            TextField(controller: _ad, style: const TextStyle(color: Colors.white), decoration: _dec('Adın')),
            const SizedBox(height: 12),
            TextField(controller: _sunucu, style: const TextStyle(color: Colors.white70, fontSize: 13), decoration: _dec('Sunucu')),
            const SizedBox(height: 24),
            const Text('Oda kur', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            _botSecici(),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: _mesgul ? null : () => _baglan({'t': 'kur', 'ad': _ad.text, 'bot': _bot, 'token': Hesap.o.token}),
              icon: const Icon(Icons.add_home),
              label: const Text('Oda kur'),
            ),
            const SizedBox(height: 28),
            const Text('Odaya katıl', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _kod,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 20, fontWeight: FontWeight.w800),
              decoration: _dec('Oda kodu (4 harf)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: _mesgul ? null : () => _baglan({'t': 'katil', 'ad': _ad.text, 'oda': _kod.text, 'token': Hesap.o.token}),
              icon: const Icon(Icons.login),
              label: const Text('Katıl'),
            ),
          ] else ...[
            Center(
              child: Column(children: [
                const Text('ODA KODU', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12)),
                Text(oda['kod'] as String, style: const TextStyle(color: Colors.amber, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10)),
                const Text('Arkadaşların bu kodla katılır', style: TextStyle(color: Colors.white54, fontSize: 12)),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SosyalEkrani(odaKodu: oda['kod'] as String, davetGonder: (nick) => _net?.gonder({'t': 'davet', 'nick': nick})),
                  )),
                  icon: const Icon(Icons.person_add, color: Colors.amber),
                  label: const Text('Arkadaş davet et', style: TextStyle(color: Colors.amber)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            for (final o in (oda['oyuncular'] as List))
              ListTile(
                leading: Text((o['avatar'] as String?) ?? '🙂', style: TextStyle(fontSize: 26, color: (o['bagli'] as bool) ? null : Colors.white30)),
                title: Text('${o['ad']}  ·  Sv ${o['level'] ?? 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: o['ad'] == oda['sahip'] ? const Text('Oda sahibi', style: TextStyle(color: Colors.amber, fontSize: 12)) : null,
                trailing: (o['hazir'] as bool? ?? false)
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                    : const Text('bekliyor', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            for (var i = 1; i <= (oda['bot'] as int); i++)
              ListTile(
                leading: const Icon(Icons.smart_toy, color: Colors.white70),
                title: Text((oda['bot'] as int) == 1 ? 'Bot' : 'Bot $i', style: const TextStyle(color: Colors.white70)),
              ),
            const SizedBox(height: 12),
            if (oda['sahip'] == oda['oyuncular'][oda['sen'] as int]['ad']) ...[
              const Text('Bot sayısı', style: TextStyle(color: Colors.white70)),
              _botSecici(onChanged: (b) => _net?.gonder({'t': 'bot', 'bot': b})),
              const SizedBox(height: 12),
              const Text('Tur süresi', style: TextStyle(color: Colors.white70)),
              SegmentedButton<int>(
                style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Yok')),
                  ButtonSegment(value: 30, label: Text('30 sn')),
                  ButtonSegment(value: 60, label: Text('60 sn')),
                  ButtonSegment(value: 90, label: Text('90 sn')),
                ],
                selected: {_sure},
                onSelectionChanged: (s) {
                  setState(() => _sure = s.first);
                  _net?.gonder({'t': 'sure', 'sure': s.first});
                },
              ),
              const SizedBox(height: 16),
              Builder(builder: (_) {
                final oy = oda['oyuncular'] as List;
                final hepsiHazir = oy.every((o) => (o['hazir'] as bool? ?? false) || !(o['bagli'] as bool));
                final yeter = oy.length + (oda['bot'] as int) >= 2;
                return FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: yeter && hepsiHazir ? () => _net?.gonder({'t': 'basla'}) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(hepsiHazir ? 'Oyunu başlat' : 'Herkesin hazır olması bekleniyor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                );
              }),
            ] else ...[
              Text('Tur süresi: ${_sure == 0 ? 'yok' : '$_sure sn'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _hazir ? Colors.greenAccent : Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  setState(() => _hazir = !_hazir);
                  _net?.gonder({'t': 'hazir', 'hazir': _hazir});
                },
                icon: Icon(_hazir ? Icons.check : Icons.hourglass_top),
                label: Text(_hazir ? 'Hazırım ✓ (vazgeç)' : 'Hazırım', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Oda sahibinin başlatması bekleniyor…', style: TextStyle(color: Colors.white70)))),
            ],
          ],
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_hata!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ),
          if (_mesgul) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator(color: Colors.amber))),
        ]),
      ),
    );
  }

  Widget _botSecici({void Function(int)? onChanged}) => SegmentedButton<int>(
        style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
        segments: const [
          ButtonSegment(value: 0, label: Text('Bot yok')),
          ButtonSegment(value: 1, label: Text('1 bot')),
          ButtonSegment(value: 2, label: Text('2 bot')),
          ButtonSegment(value: 3, label: Text('3 bot')),
        ],
        selected: {_bot},
        onSelectionChanged: (s) {
          setState(() => _bot = s.first);
          onChanged?.call(s.first);
        },
      );

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
      );
}
