import 'dart:convert';
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emlakdeal_cekirdek/seviye.dart';
import '../dil.dart';
import '../dil/soz.dart';
import '../hesap.dart';
import 'avatar.dart';
import 'guvenlik.dart';

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
  int _ses = 0;
  final _onizleme = AudioPlayer();
  Map<String, dynamic> _klipler = {};
  String? _mesaj;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _avatar = h.avatar;
    _ses = h.ses;
    rootBundle.loadString('assets/ses/manifest.json').then((j) => _klipler = json.decode(j) as Map<String, dynamic>).catchError((_) => _klipler);
    h.baglan().then((_) {
      if (mounted) {
        setState(() {
          _avatar = h.avatar;
          _ses = h.ses;
        });
      }
    });
  }

  @override
  void dispose() {
    _onizleme.dispose();
    super.dispose();
  }

  Future<void> _dinle(int s) async {
    setState(() => _ses = s);
    const tr = 'Üç tam set! Kazandım!';
    final ad = _klipler[Dil.o.en ? 'en|$s|${sozEn(tr)}' : '$s|$tr'];
    if (ad is! String) return;
    try {
      await _onizleme.stop();
      await _onizleme.play(AssetSource('ses/$ad')).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _kaydet() async {
    setState(() {
      _mesgul = true;
      _mesaj = null;
    });
    final hata = await h.profilGuncelle(nick: _nick.text.trim() != h.nick ? _nick.text.trim() : null, avatar: _avatar != h.avatar ? _avatar : null, ses: _ses != h.ses ? _ses : null);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? t('Kaydedildi.');
      });
    }
  }

  Future<void> _epostaBagla() async {
    setState(() => _mesgul = true);
    final hata = await h.epostaBagla(_eposta.text.trim(), _sifre.text);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? t('E-posta hesaba bağlandı; başka cihazdan bu bilgilerle giriş yapabilirsin.');
      });
    }
  }

  Future<bool> _onay(String baslik, String metin) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(baslik),
          content: Text(metin),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Vazgeç'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Devam')))],
        ),
      ) ??
      false;

  Future<void> _cikis() async {
    if (!await _onay(t('Çıkış yapılsın mı?'), t('Bu cihazda yeni bir misafir hesapla başlarsın. Bağlı hesabına tekrar girince ilerlemen geri gelir.'))) return;
    setState(() => _mesgul = true);
    await h.cikis();
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = t('Çıkış yapıldı.');
        _nick.text = h.nick;
        _avatar = h.avatar;
        _eposta.clear();
        _sifre.clear();
      });
    }
  }

  Future<void> _sosyalGiris(String saglayici, String ad) async {
    if (h.misafir && ((h.profil?['oyun'] as int?) ?? 0) > 0) {
      if (!await _onay(t('{ad} ile giriş', {'ad': ad}), t('Bu {ad} hesabı daha önce kullanıldıysa o hesabın ilerlemesi açılır ve bu cihazdaki misafir ilerlemen (Seviye {lv}) bırakılır. İlk kez kullanılıyorsa misafir ilerlemen hesaba bağlanır. Devam edilsin mi?', {'ad': ad, 'lv': h.level}))) return;
    }
    setState(() {
      _mesgul = true;
      _mesaj = null;
    });
    final r = await h.sosyalGiris(saglayici);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = r.hata ?? (r.degisti ? t('{ad} hesabına geçildi; önceki ilerlemen geri geldi.', {'ad': ad}) : t('{ad} hesaba bağlandı.', {'ad': ad}));
        _nick.text = h.nick;
        _avatar = h.avatar;
      });
    }
  }

  Future<void> _epostaGiris() async {
    if (h.misafir && ((h.profil?['oyun'] as int?) ?? 0) > 0) {
      if (!await _onay(t('Hesap değişecek'), t('Bu cihazdaki misafir hesabın (Seviye {lv}) bağlı olmadığı için bırakılır. Devam edilsin mi?', {'lv': h.level}))) return;
    }
    setState(() => _mesgul = true);
    final hata = await h.epostaGiris(_eposta.text.trim(), _sifre.text);
    if (mounted) {
      setState(() {
        _mesgul = false;
        _mesaj = hata ?? t('Giriş yapıldı.');
        _nick.text = h.nick;
        _avatar = h.avatar;
      });
    }
  }

  Future<void> _avatarSec() async {
    final secilen = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF123F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('Avatarını seç'), style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
              for (final a in avatarlar)
                InkWell(
                  onTap: () => Navigator.pop(c, a),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: a == _avatar ? Colors.amber : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(color: a == _avatar ? Colors.amber : Colors.white24, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(a, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (secilen != null && mounted) setState(() => _avatar = secilen);
  }

  Widget _ustBilgi(Map<String, dynamic>? p, {required bool duzenlenebilir}) {
    final lvXp = p?['levelXp'] as int? ?? 0, esik = p?['esik'] as int? ?? levelEsigi(1);
    final avatar = Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(color: Color(0xFF1E7B3A), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: AvatarGorsel(_avatar ?? h.avatar, boyut: 84),
    );
    return Row(children: [
      duzenlenebilir
          ? InkWell(
              onTap: _avatarSec,
              customBorder: const CircleBorder(),
              child: Stack(clipBehavior: Clip.none, children: [
                avatar,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F3D25), width: 2)),
                    child: const Icon(Icons.edit, size: 14, color: Colors.black),
                  ),
                ),
              ]),
            )
          : avatar,
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.nick, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(t('Seviye {lv}  ·  💰 {altin} altın', {'lv': h.level, 'altin': h.altin}), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: esik == 0 ? 1 : (lvXp / esik).clamp(0, 1), minHeight: 10, backgroundColor: Colors.white12, color: Colors.amber),
          ),
          Text(esik == 0 ? t('En yüksek seviye') : '$lvXp / $esik XP', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _misafirSayfa() {
    final p = h.profil;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: Text(t('Profil'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (p == null)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(t('Sunucuya ulaşılamadı; bağlanınca giriş yapabilirsin.'), style: TextStyle(color: Colors.orangeAccent)),
          ),
        _ustBilgi(p, duzenlenebilir: false),
        if (p != null) ...[
          const SizedBox(height: 10),
          Text(t('Oyun: {o}  ·  Galibiyet: {g}', {'o': p['oyun'], 'g': p['galibiyet']}), style: const TextStyle(color: Colors.white)),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Misafir olarak oynuyorsun'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              t('Giriş yapınca: online oyun, arkadaşlar, günlük ödül, dükkân, kendi nickname, avatar ve sesin açılır. Şu ana kadarki ilerlemen hesabına bağlanır; uygulamayı silersen misafir ilerlemesi gider.'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Text(t('Giriş yap'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        _sosyalSatir(),
        const SizedBox(height: 10),
        _epostaFormu(girisVar: true),
        const GizlilikOnayNotu(),
        if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(sunucuMesaj(_mesaj!), style: const TextStyle(color: Colors.white))),
        const SizedBox(height: 8),
        const GizlilikLinki(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (h.misafir) return _misafirSayfa();
    final p = h.profil;
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D25),
      appBar: AppBar(backgroundColor: const Color(0xFF0F3D25), foregroundColor: Colors.white, title: Text(t('Profil'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!h.girisli)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(t('Sunucuya ulaşılamadı; profil çevrimdışı. Bağlanınca kaydedilir.'), style: TextStyle(color: Colors.orangeAccent)),
          ),
        _ustBilgi(p, duzenlenebilir: true),
        const SizedBox(height: 20),
        TextField(controller: _nick, maxLength: 16, style: const TextStyle(color: Colors.white), decoration: _dec(t('Nickname (masada görünür)'))),
        const SizedBox(height: 14),
        Text(t('Oyundaki sesin'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.black, selectedBackgroundColor: Colors.amber, side: const BorderSide(color: Colors.white54)),
          segments: [
            ButtonSegment(value: true, label: Text(t('Kadın')), icon: Icon(Icons.female)),
            ButtonSegment(value: false, label: Text(t('Erkek')), icon: Icon(Icons.male)),
          ],
          selected: {sesKadin(_ses)},
          onSelectionChanged: (s) => _dinle([for (var i = 0; i < sesAdlari.length; i++) if (sesKadin(i) == s.first) i].first),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < sesAdlari.length; i++)
            if (sesKadin(i) == sesKadin(_ses))
              ChoiceChip(
                avatar: Icon(Icons.volume_up, size: 18, color: i == _ses ? Colors.black : Colors.white),
                label: Text('${sesAdlari[i]} · ${t(sesTanimlari[i])}'),
                selected: i == _ses,
                selectedColor: Colors.amber,
                labelStyle: TextStyle(color: i == _ses ? Colors.black : Colors.white),
                backgroundColor: const Color(0xFF37474F),
                side: BorderSide(color: i == _ses ? Colors.amber : Colors.white54),
                showCheckmark: false,
                onSelected: (_) => _dinle(i),
              ),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: _mesgul ? null : _kaydet,
          icon: const Icon(Icons.save),
          label: Text(t('Profili kaydet')),
        ),
        if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(sunucuMesaj(_mesaj!), style: const TextStyle(color: Colors.white))),
        const SizedBox(height: 24),
        if (p != null) ...[
          Text(t('İstatistikler'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(t('Oyun: {o}  ·  Galibiyet: {g}  ·  Online: {og}/{oo}', {'o': p['oyun'], 'g': p['galibiyet'], 'og': p['onlineGalibiyet'], 'oo': p['onlineOyun']}), style: const TextStyle(color: Colors.white)),
          Text(t('Toplam XP: {xp}', {'xp': p['xp']}), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
        ],
        ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('✅ Hesabın güvende'), style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(t('Telefon değişse bile aynı yöntemle girince ilerlemen geri gelir.'), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
              const SizedBox(height: 8),
              if (p?['eposta'] != null) Text('📧 ${p!['eposta']}', style: const TextStyle(color: Colors.white)),
              if (p?['google'] == true) Text(t('🔵 Google bağlı'), style: TextStyle(color: Colors.white)),
              if (p?['facebook'] == true) Text(t('🔷 Facebook bağlı'), style: TextStyle(color: Colors.white)),
              if (p?['apple'] == true) Text(t('🍎 Apple bağlı'), style: TextStyle(color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
            onPressed: _mesgul ? null : _cikis,
            icon: const Icon(Icons.logout),
            label: Text(t('Çıkış yap / başka hesaba geç')),
          ),
          const SizedBox(height: 22),
          const GizlilikLinki(),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300, side: BorderSide(color: Colors.red.shade300)),
            onPressed: _mesgul ? null : () => hesapSilAkisi(context),
            icon: const Icon(Icons.delete_forever),
            label: Text(t('Hesabı sil')),
          ),
          const SizedBox(height: 16),
        ],
      ]),
    );
  }

  Widget _sosyalSatir() {
    final p = h.profil;
    return Column(children: [
      _sosyal('Google', 'google', p?['google'] == true),
      const SizedBox(height: 10),
      _sosyal('Facebook', 'facebook', p?['facebook'] == true),
      if (Platform.isIOS || Platform.isMacOS) ...[
        const SizedBox(height: 10),
        _sosyal('Apple', 'apple', p?['apple'] == true),
      ],
    ]);
  }

  Widget _sosyal(String ad, String saglayici, bool bagli) {
    final google = saglayici == 'google';
    final apple = saglayici == 'apple';
    final bg = bagli ? const Color(0xFF1E5A38) : (google ? Colors.white : apple ? Colors.black : const Color(0xFF1877F2));
    final fg = bagli ? Colors.greenAccent : (google ? const Color(0xFF3C4043) : Colors.white);
    final Widget ikon = bagli
        ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 26)
        : google
            ? const SizedBox(width: 24, height: 24, child: CustomPaint(painter: _GoogleG()))
            : apple
                ? const Icon(Icons.apple, color: Colors.white, size: 28)
                : const Icon(Icons.facebook, color: Colors.white, size: 28);
    return Material(
      color: bg,
      elevation: bagli ? 0 : 3,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _mesgul || bagli ? null : () => _sosyalGiris(saglayici, ad),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: bagli ? BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6))) : null,
          child: Row(children: [
            ikon,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                bagli ? t('{ad} bağlı', {'ad': ad}) : t('{ad} ile bağlan', {'ad': ad}),
                style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (!bagli) Icon(Icons.arrow_forward_ios_rounded, size: 16, color: fg.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }

  Widget _epostaFormu({required bool girisVar}) => Column(children: [
        TextField(controller: _eposta, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _dec(t('E-posta'))),
        const SizedBox(height: 8),
        TextField(controller: _sifre, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _dec(t('Şifre (en az 6)'))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: _mesgul ? null : _epostaBagla,
              child: Text(t('E-postayı bu hesaba bağla'), textAlign: TextAlign.center),
            ),
          ),
          if (girisVar) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: _mesgul ? null : _epostaGiris,
                child: Text(t('Mevcut hesaba giriş yap'), textAlign: TextAlign.center),
              ),
            ),
          ],
        ]),
      ]);

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        counterText: '',
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
      );
}

class _GoogleG extends CustomPainter {
  const _GoogleG();
  @override
  void paint(Canvas c, Size z) {
    final w = z.width;
    final r = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: w * 0.38);
    final k = w * 0.24;
    Paint boya(Color r) => Paint()..color = r..style = PaintingStyle.stroke..strokeWidth = k;
    double d(double x) => x * 3.141592653589793 / 180;
    c.drawArc(r, d(-40), d(-100), false, boya(const Color(0xFFEA4335)));
    c.drawArc(r, d(-140), d(-90), false, boya(const Color(0xFFFBBC05)));
    c.drawArc(r, d(130), d(-85), false, boya(const Color(0xFF34A853)));
    c.drawArc(r, d(45), d(-45), false, boya(const Color(0xFF4285F4)));
    c.drawRect(Rect.fromLTWH(w * 0.5, w * 0.5 - k / 2, w * 0.38, k), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
