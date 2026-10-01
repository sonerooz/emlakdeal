import 'package:flutter/material.dart';
import 'package:monodeal_cekirdek/seviye.dart';
import '../hesap.dart';

/// Profil: nick, avatar, level/XP/altın, istatistikler, e-posta ile hesabı güvenceye alma.
class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});
  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  final h = Hesap.o;
  late final _nick = TextEditingController(text: h.nick);
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  String? _avatar;
  String? _mesaj;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _avatar = h.avatar;
    h.baglan().then((_) {
      if (mounted) setState(() => _avatar = h.avatar);
    });
  }

  Future<void> _kaydet() async {
    setState(() {
      _mesgul = true;
      _mesaj = null;
    });
    final hata = await h.profilGuncelle(nick: _nick.text.trim() != h.nick ? _nick.text.trim() : null, avatar: _avatar != h.avatar ? _avatar : null);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? 'Kaydedildi.';
      });
    }
  }

  Future<void> _epostaBagla() async {
    setState(() => _mesgul = true);
    final hata = await h.epostaBagla(_eposta.text.trim(), _sifre.text);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? 'E-posta hesaba bağlandı; başka cihazdan bu bilgilerle giriş yapabilirsin.';
      });
    }
  }

  Future<void> _epostaGiris() async {
    setState(() => _mesgul = true);
    final hata = await h.epostaGiris(_eposta.text.trim(), _sifre.text);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? 'Giriş yapıldı.';
        _nick.text = h.nick;
        _avatar = h.avatar;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = h.profil;
    final lvXp = p?['levelXp'] as int? ?? 0, esik = p?['esik'] as int? ?? levelEsigi(1);
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!h.girisli)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Sunucuya ulaşılamadı; profil çevrimdışı. Bağlanınca kaydedilir.', style: TextStyle(color: Colors.orangeAccent)),
          ),
        Row(children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: Color(0xFF1E7B3A), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(_avatar ?? h.avatar, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.nick, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('Seviye ${h.level}  ·  💰 ${h.altin} altın', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: esik == 0 ? 1 : (lvXp / esik).clamp(0, 1), minHeight: 10, backgroundColor: Colors.white12, color: Colors.amber),
              ),
              Text(esik == 0 ? 'En yüksek seviye' : '$lvXp / $esik XP', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _nick, maxLength: 16, style: const TextStyle(color: Colors.white), decoration: _dec('Takma ad (masada görünür)')),
        const SizedBox(height: 8),
        const Text('Avatar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in avatarlar)
            InkWell(
              onTap: () => setState(() => _avatar = a),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: a == _avatar ? Colors.amber : Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(color: a == _avatar ? Colors.amber : Colors.white24, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(a, style: const TextStyle(fontSize: 28)),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: _mesgul ? null : _kaydet,
          icon: const Icon(Icons.save),
          label: const Text('Profili kaydet'),
        ),
        if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_mesaj!, style: const TextStyle(color: Colors.white))),
        const SizedBox(height: 24),
        if (p != null) ...[
          const Text('İstatistikler', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Oyun: ${p['oyun']}  ·  Galibiyet: ${p['galibiyet']}  ·  Online: ${p['onlineGalibiyet']}/${p['onlineOyun']}', style: const TextStyle(color: Colors.white)),
          Text('Toplam XP: ${p['xp']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
        ],
        const Text('Hesabı güvenceye al', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          p?['eposta'] != null ? 'Bağlı e-posta: ${p!['eposta']}' : 'E-posta ve şifre ekle; telefon değişince aynı hesaba girersin. Google / Facebook / Apple ile giriş yakında.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(controller: _eposta, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _dec('E-posta')),
        const SizedBox(height: 8),
        TextField(controller: _sifre, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _dec('Şifre (en az 6)')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: _mesgul ? null : _epostaBagla,
              child: const Text('Bu hesaba bağla'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: _mesgul ? null : _epostaGiris,
              child: const Text('Giriş yap'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _sosyal('Google', Icons.g_mobiledata),
          const SizedBox(width: 8),
          _sosyal('Facebook', Icons.facebook),
          const SizedBox(width: 8),
          _sosyal('Apple', Icons.apple),
        ]),
      ]),
    );
  }

  Widget _sosyal(String ad, IconData ik) => Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white38, side: const BorderSide(color: Colors.white24)),
          onPressed: null,
          icon: Icon(ik),
          label: Text(ad, style: const TextStyle(fontSize: 12)),
        ),
      );

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        counterText: '',
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
      );
}
