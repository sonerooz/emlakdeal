import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../ayarlar.dart';
import '../dil.dart';
import '../hesap.dart';
import '../net/istemci.dart';
import 'game_screen.dart';
import 'sosyal_ekrani.dart';

/// Online oyun: oda listesi, rastgele katıl, oda kur (özel oda şifreli), bekleme odası.
class LobiEkrani extends StatefulWidget {
  const LobiEkrani({super.key, this.odaKodu});

  /// Davetle gelindiyse otomatik katılınacak oda.
  final String? odaKodu;
  @override
  State<LobiEkrani> createState() => _LobiEkraniState();
}

class _LobiEkraniState extends State<LobiEkrani> {
  Istemci? _net;
  StreamSubscription? _abone;
  Timer? _yenile;
  Map<String, dynamic>? _oda;
  List<Map<String, dynamic>> _liste = [];
  bool _listeGeldi = false;
  int _bot = 1;
  int _sure = 120;
  bool _hazir = false;
  bool _mesgul = true;
  String? _hata;
  Map<String, dynamic>? _sonKatil;

  @override
  void initState() {
    super.initState();
    _baglan();
  }

  @override
  void dispose() {
    _yenile?.cancel();
    _abone?.cancel();
    if (_oda == null) _net?.kapat();
    super.dispose();
  }

  Future<void> _baglan() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      Istemci net;
      try {
        net = Istemci(Ayarlar.o.sunucu);
        await net.baglan();
      } catch (e) {
        // ev içindeyken dış adres (hairpin NAT) çalışmayabilir: yerel adresi dene
        net = Istemci(Ayarlar.sunucuYerel);
        await net.baglan();
      }
      _net = net;
      _abone = net.mesajlar.listen(_mesaj);
      net.koptu.listen((_) {
        if (!mounted) return;
        _yenile?.cancel();
        setState(() {
          _oda = null;
          _hazir = false;
          _listeGeldi = false;
          _hata = t('Sunucu bağlantısı koptu.');
        });
      });
      _listeIste();
      _yenile = Timer.periodic(const Duration(seconds: 4), (_) => _listeIste());
      if (widget.odaKodu != null) _katil(widget.odaKodu!);
    } catch (e) {
      if (mounted) setState(() => _hata = t('Sunucuya bağlanılamadı.'));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  void _listeIste() {
    if (_oda == null) _net?.gonder({'t': 'liste'});
  }

  void _katil(String kod, {String? sifre}) {
    _sonKatil = {'t': 'katil', 'oda': kod, 'token': Hesap.o.token, 'ad': Hesap.o.nick, if (sifre != null) 'sifre': sifre};
    setState(() => _hata = null);
    _net?.gonder(_sonKatil!);
  }

  Future<String?> _sifreSor() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('🔒 Özel oda')),
        content: TextField(controller: c, autofocus: true, obscureText: true, decoration: InputDecoration(labelText: t('Oda şifresi')), onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Vazgeç'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(t('Katıl'))),
        ],
      ),
    );
  }

  Future<void> _listedenKatil(Map<String, dynamic> o) async {
    String? sifre;
    if (o['ozel'] == true) {
      sifre = await _sifreSor();
      if (sifre == null || !mounted) return;
    }
    _katil(o['kod'] as String, sifre: sifre);
  }

  bool _dolu(Map<String, dynamic> o) => (o['oyuncu'] as int) + (o['bot'] as int) >= 5;

  void _rastgele() {
    final adaylar = _liste.where((o) => o['ozel'] != true && !_dolu(o) && ((o['bahis'] as int?) ?? 0) <= Hesap.o.altin).toList();
    if (adaylar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Altınına uygun açık oda yok. Kendi odanı kurabilirsin.'))));
      return;
    }
    _katil(adaylar[Random().nextInt(adaylar.length)]['kod'] as String);
  }

  Future<void> _kodlaKatil() async {
    final c = TextEditingController();
    final kod = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Kodla katıl')),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(letterSpacing: 4, fontSize: 20, fontWeight: FontWeight.w800),
          decoration: InputDecoration(labelText: t('Oda kodu (4 harf)')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Vazgeç'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(t('Katıl'))),
        ],
      ),
    );
    if (kod == null || kod.trim().isEmpty || !mounted) return;
    _katil(kod.trim().toUpperCase());
  }

  Future<void> _odaKur() async {
    final sifre = TextEditingController();
    var bot = 1;
    var bahis = _varsayilanTutar();
    var ozel = false;
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF123F2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 18),
                Text(t('Oda kur'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                Text(t('Bot sayısı'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _botSecici(bot, (b) => set(() => bot = b)),
                const SizedBox(height: 14),
                Text(t('Oda tutarı (altın)'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(t('Herkes bu kadar altınla girer, gerçek oyuncuların toplamı kazanana gider. Bot kazanırsa herkese iade edilir.'), style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
                const SizedBox(height: 8),
                _bahisSecici(bahis, (b) => set(() => bahis = b)),
                const SizedBox(height: 6),
                Text(bahis == 0 ? t('Online oda kurmak için en az 50 altın gerekir. Şu an: {n} altın', {'n': Hesap.o.altin}) : t('Altının: {n}', {'n': Hesap.o.altin}), style: TextStyle(color: bahis == 0 ? Colors.orangeAccent : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.amber,
                  title: Text(t('Özel oda'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(t('Girmek için şifre gerekir'), style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: ozel,
                  onChanged: (v) => set(() => ozel = v),
                ),
                if (ozel)
                  TextField(controller: sifre, maxLength: 20, style: const TextStyle(color: Colors.white), decoration: _dec(t('Oda şifresi')), onChanged: (_) => set(() {})),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  onPressed: bahis == 0 || (ozel && sifre.text.trim().isEmpty) ? null : () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.add_home),
                  label: Text(t('Odayı aç')),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (tamam != true || !mounted) return;
    setState(() => _hata = null);
    _net?.gonder({'t': 'kur', 'ad': Hesap.o.nick, 'bot': bot, 'bahis': bahis, 'token': Hesap.o.token, if (ozel) 'sifre': sifre.text.trim()});
  }

  void _mesaj(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'odalar':
        if (_oda == null) {
          setState(() {
            _liste = [for (final o in (m['liste'] as List)) Map<String, dynamic>.from(o as Map)];
            _listeGeldi = true;
          });
        }
      case 'oda':
        setState(() {
          _oda = m;
          _bot = m['bot'] as int;
          _sure = (m['sure'] as int?) ?? 120;
          final sen = m['sen'] as int?;
          final oy = m['oyuncular'] as List?;
          if (sen != null && oy != null && sen < oy.length) _hazir = (oy[sen]['hazir'] as bool?) ?? false;
        });
      case 'bahisKesildi':
        Hesap.o.odulGeldi(m);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Odaya giriş: {n} altın ödendi', {'n': m['bahis']}))));
      case 'bahisIade':
        Hesap.o.odulGeldi(m);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Oyun başlayamadı, altının iade edildi.'))));
      case 'hata':
        if (m['giris'] == true) {
          setState(() => _hata = t('Online oyun için giriş yapmalısın.'));
          return;
        }
        if (m['sifre'] == true && _sonKatil != null) {
          final kod = _sonKatil!['oda'] as String;
          if ((_sonKatil!['sifre'] as String? ?? '').isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Şifre yanlış.'))));
          }
          _sifreSor().then((s) {
            if (s != null && mounted) _katil(kod, sifre: s);
          });
          return;
        }
        setState(() => _hata = m['m'] == null ? null : sunucuMesaj(m['m'] as String));
      case 'bilgi':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sunucuMesaj(m['m'] as String? ?? ''))));
      case 'basladi':
        final net = _net!;
        _abone?.cancel();
        _yenile?.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GameScreen(
            net: net,
            benIdx: m['sen'] as int,
            adlar: (m['adlar'] as List).cast<String>(),
            botlar: (m['botlar'] as List).cast<bool>(),
            avatarlar: (m['avatarlar'] as List?)?.cast<String>() ?? const [],
            leveller: (m['leveller'] as List?)?.cast<int>() ?? const [],
            sesler: (m['sesler'] as List?)?.cast<int>() ?? const [],
            bahis: (m['bahis'] as int?) ?? 0,
            havuz: (m['havuz'] as int?) ?? 0,
          ),
        ));
    }
  }

  Widget _odaSatiri(Map<String, dynamic> o) {
    final ozel = o['ozel'] == true;
    final dolu = _dolu(o);
    final bot = o['bot'] as int;
    final sure = o['sure'] as int;
    final bahis = (o['bahis'] as int?) ?? 0;
    final yetmez = bahis > Hesap.o.altin;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Icon(ozel ? Icons.lock : Icons.meeting_room, color: ozel ? Colors.orangeAccent : Colors.lightGreenAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('{ad} odası', {'ad': o['sahip']}), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              '${t('{n} oyuncu', {'n': o['oyuncu']})}${bot > 0 ? t(' + {n} bot', {'n': bot}) : ''} · ${sure == 0 ? t('süresiz') : t('{n} sn', {'n': sure})}${ozel ? t(' · özel') : ''} · 💰 ${t('{n} altınlık', {'n': bahis})}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: dolu || _mesgul || yetmez ? null : () => _listedenKatil(o),
          child: Text(dolu ? t('Dolu') : (yetmez ? t('Altın yetmez') : t('Katıl')), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  List<Widget> _listeEkrani() => [
        Text('${Hesap.o.avatar}  ${t('{ad} olarak oynuyorsun', {'ad': Hesap.o.nick})}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              onPressed: _net == null || _mesgul ? null : _odaKur,
              icon: const Icon(Icons.add_home),
              label: Text(t('Oda kur')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              onPressed: _net == null || _mesgul ? null : _rastgele,
              icon: const Icon(Icons.shuffle),
              label: Text(t('Rastgele katıl')),
            ),
          ),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Text(t('Açık odalar'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16))),
          TextButton.icon(onPressed: _net == null ? null : _kodlaKatil, icon: const Icon(Icons.pin, size: 18), label: Text(t('Kodla katıl'))),
          IconButton(onPressed: _net == null ? _baglan : _listeIste, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ]),
        const SizedBox(height: 6),
        if (_net != null && _listeGeldi && _liste.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(t('Şu an açık oda yok.\nİlk odayı sen kur!'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.5)),
          ),
        for (final o in _liste) _odaSatiri(o),
      ];

  List<Widget> _odaEkrani(Map<String, dynamic> oda) => [
        Center(
          child: Column(children: [
            Text(t('ODA KODU'), style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12)),
            Text(oda['kod'] as String, style: const TextStyle(color: Colors.amber, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10)),
            Text(oda['ozel'] == true ? t('🔒 Özel oda · şifreyi arkadaşınla paylaş') : t('Herkese açık oda'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SosyalEkrani(odaKodu: oda['kod'] as String, davetGonder: (nick) => _net?.gonder({'t': 'davet', 'nick': nick})),
              )),
              icon: const Icon(Icons.person_add, color: Colors.amber),
              label: Text(t('Arkadaş davet et'), style: TextStyle(color: Colors.amber)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (((oda['bahis'] as int?) ?? 0) > 0)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.6))),
            child: Column(children: [
              Text(t('💰 {n} altınlık oda', {'n': oda['bahis']}), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(t('Ödül: {n} altın (gerçek oyuncu sayısı × oda tutarı)', {'n': (oda['oyuncular'] as List).length * (oda['bahis'] as int)}), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        const SizedBox(height: 6),
        for (final o in (oda['oyuncular'] as List))
          ListTile(
            leading: Text((o['avatar'] as String?) ?? '🙂', style: TextStyle(fontSize: 26, color: (o['bagli'] as bool) ? null : Colors.white30)),
            title: Text('${o['ad']}  ·  ${t('Sv')} ${o['level'] ?? 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: o['ad'] == oda['sahip'] ? Text(t('Oda sahibi'), style: TextStyle(color: Colors.amber, fontSize: 12)) : null,
            trailing: (o['hazir'] as bool? ?? false)
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : Text(t('bekliyor'), style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        for (var i = 1; i <= (oda['bot'] as int); i++)
          ListTile(
            leading: const Icon(Icons.smart_toy, color: Colors.white70),
            title: Text((oda['bot'] as int) == 1 ? 'Bot' : 'Bot $i', style: const TextStyle(color: Colors.white70)),
          ),
        const SizedBox(height: 12),
        if (oda['sahip'] == oda['oyuncular'][oda['sen'] as int]['ad']) ...[
          Text(t('Bot sayısı'), style: TextStyle(color: Colors.white70)),
          _botSecici(_bot, (b) {
            setState(() => _bot = b);
            _net?.gonder({'t': 'bot', 'bot': b});
          }),
          const SizedBox(height: 12),
          Text(t('Oda tutarı (altın)'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          _bahisSecici((oda['bahis'] as int?) ?? 0, (b) => _net?.gonder({'t': 'bahis', 'bahis': b})),
          const SizedBox(height: 12),
          Text(t('Tur süresi'), style: TextStyle(color: Colors.white70)),
          SegmentedButton<int>(
            style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
            segments: [
              ButtonSegment(value: 0, label: Text(t('Yok'))),
              ButtonSegment(value: 60, label: Text(t('60 sn'))),
              ButtonSegment(value: 120, label: Text(t('120 sn'))),
              ButtonSegment(value: 180, label: Text(t('180 sn'))),
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
            final yeter = oy.length >= 2;
            return FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: yeter && hepsiHazir ? () => _net?.gonder({'t': 'basla'}) : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(!yeter ? t('Online oyun için en az 2 gerçek oyuncu gerekir') : (hepsiHazir ? t('Oyunu başlat') : t('Herkesin hazır olması bekleniyor')), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            );
          }),
        ] else ...[
          Text(t('Tur süresi: {x}', {'x': _sure == 0 ? t('yok') : t('{n} sn', {'n': _sure})}), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _hazir ? Colors.greenAccent : Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () {
              setState(() => _hazir = !_hazir);
              _net?.gonder({'t': 'hazir', 'hazir': _hazir});
            },
            icon: Icon(_hazir ? Icons.check : Icons.hourglass_top),
            label: Text(_hazir ? t('Hazırım ✓ (vazgeç)') : t('Hazırım'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Center(child: Padding(padding: EdgeInsets.all(12), child: Text(t('Oda sahibinin başlatması bekleniyor…'), style: TextStyle(color: Colors.white70)))),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final oda = _oda;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: Text(oda == null ? t('Online oyun') : t('Oda'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (oda == null) ..._listeEkrani() else ..._odaEkrani(oda),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_hata!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ),
          if (_net == null && !_mesgul) Center(child: TextButton.icon(onPressed: _baglan, icon: const Icon(Icons.refresh), label: Text(t('Tekrar dene')))),
          if (_mesgul) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator(color: Colors.amber))),
        ]),
      ),
    );
  }

  static const _bahisler = [50, 100, 250, 500, 1000, 2500, 5000];

  /// Altına uyan en büyük "makul" varsayılan tutar (100 tercih edilir).
  int _varsayilanTutar() {
    if (Hesap.o.altin >= 100) return 100;
    return Hesap.o.altin >= 50 ? 50 : 0;
  }

  Widget _bahisSecici(int secili, void Function(int) onChanged) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final b in _bahisler)
            Builder(builder: (_) {
              final yetmez = b > Hesap.o.altin;
              final sec = secili == b;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: yetmez ? null : () => onChanged(b),
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sec ? Colors.amber : Colors.white.withValues(alpha: yetmez ? 0.04 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sec ? Colors.amber : (yetmez ? Colors.white12 : Colors.white54), width: sec ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text('$b', style: TextStyle(color: sec ? Colors.black : (yetmez ? Colors.white30 : Colors.white), fontWeight: FontWeight.w900, fontSize: 17)),
                    Text(yetmez ? '🔒' : '💰', style: const TextStyle(fontSize: 11)),
                  ]),
                ),
              );
            }),
        ],
      );

  Widget _botSecici(int secili, void Function(int) onChanged) => SegmentedButton<int>(
        style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
        segments: [
          ButtonSegment(value: 0, label: Text(t('Yok'))),
          ButtonSegment(value: 1, label: Text(t('1 bot'))),
          ButtonSegment(value: 2, label: Text(t('2 bot'))),
          ButtonSegment(value: 3, label: Text(t('3 bot'))),
        ],
        selected: {secili},
        onSelectionChanged: (s) => onChanged(s.first),
      );

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(color: Colors.white70),
        counterStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
      );
}
