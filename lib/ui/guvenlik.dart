import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dil.dart';
import '../hesap.dart';

const _zemin = Color(0xFF123F2A);

const _nedenler = <(String, String)>[
  ('hakaret', 'Hakaret / küfür'),
  ('uygunsuz_isim', 'Uygunsuz isim'),
  ('hile', 'Hile'),
  ('spam', 'Spam'),
  ('diger', 'Diğer'),
];

void _bilgi(ScaffoldMessengerState m, String metin) =>
    m.showSnackBar(SnackBar(content: Text(sunucuMesaj(metin)), behavior: SnackBarBehavior.floating));

/// Yasal sayfayı (`gizlilik` | `hesap-sil`) dış tarayıcıda açar; dil = geçerli dil.
Future<void> yasalSayfaAc(BuildContext context, {String sayfa = 'gizlilik'}) async {
  final m = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(Hesap.o.yasalUrl(sayfa)), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) _bilgi(m, t('Sayfa açılamadı.'));
}

/// Profil sayfalarında düz "Gizlilik Politikası" satırı.
class GizlilikLinki extends StatelessWidget {
  const GizlilikLinki({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          onPressed: () => yasalSayfaAc(context),
          icon: const Icon(Icons.privacy_tip_outlined, size: 18),
          label: Text(t('Gizlilik Politikası'), style: const TextStyle(decoration: TextDecoration.underline)),
        ),
      );
}

/// Giriş/kayıt formlarının altındaki küçük onay notu (dokununca politika açılır).
class GizlilikOnayNotu extends StatelessWidget {
  const GizlilikOnayNotu({super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => yasalSayfaAc(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            t('Devam ederek Gizlilik Politikasını kabul etmiş olursun.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11.5, decoration: TextDecoration.underline),
          ),
        ),
      );
}

/// Bir oyuncuyu şikayet etme diyaloğu: neden seçimi + isteğe bağlı kısa not.
Future<void> sikayetEt(BuildContext context, String hedef, {String baglam = 'oyun'}) async {
  final m = ScaffoldMessenger.of(context);
  final gonderildi = await showDialog<bool>(
    context: context,
    builder: (c) => _SikayetDiyalogu(hedef: hedef, baglam: baglam),
  );
  if (gonderildi == true) _bilgi(m, t('Şikayetin alındı, teşekkürler.'));
}

class _SikayetDiyalogu extends StatefulWidget {
  const _SikayetDiyalogu({required this.hedef, required this.baglam});
  final String hedef, baglam;
  @override
  State<_SikayetDiyalogu> createState() => _SikayetDiyaloguState();
}

class _SikayetDiyaloguState extends State<_SikayetDiyalogu> {
  String? _neden;
  final _not = TextEditingController();
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final h = await Hesap.o.sikayetGonder(widget.hedef, _neden!, not: _not.text, baglam: widget.baglam);
    if (!mounted) return;
    if (h == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _mesgul = false;
        _hata = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _zemin,
        title: Text(t('{ad} şikayet edilsin mi?', {'ad': widget.hedef}), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Şikayet nedenini seç:'), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (k, ad) in _nedenler)
                ChoiceChip(
                  label: Text(t(ad)),
                  selected: _neden == k,
                  selectedColor: Colors.amber,
                  backgroundColor: const Color(0xFF37474F),
                  labelStyle: TextStyle(color: _neden == k ? Colors.black : Colors.white),
                  side: BorderSide(color: _neden == k ? Colors.amber : Colors.white54),
                  showCheckmark: false,
                  onSelected: _mesgul ? null : (_) => setState(() => _neden = k),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _not,
              maxLength: 200,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: t('Not (isteğe bağlı)'),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
            if (_hata != null) Text(sunucuMesaj(_hata!), style: const TextStyle(color: Colors.orangeAccent)),
          ]),
        ),
        actions: [
          TextButton(onPressed: _mesgul ? null : () => Navigator.pop(context, false), child: Text(t('Vazgeç'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: _neden == null || _mesgul ? null : _gonder,
            child: Text(t('Gönder')),
          ),
        ],
      );
}

/// Onay isteyip engeller. Başarıyla engellendiyse true döner.
Future<bool> engelleOnayli(BuildContext context, String nick) async {
  final m = ScaffoldMessenger.of(context);
  final onay = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: _zemin,
          title: Text(t('{ad} engellensin mi?', {'ad': nick}), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 18)),
          content: Text(t('Engellenen kişinin sohbet mesajlarını, emojilerini ve konuşmalarını görmez, duymazsın. Engeli Arkadaşlar ekranından kaldırabilirsin.'), style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Vazgeç'))),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: Text(t('Engelle'))),
          ],
        ),
      ) ??
      false;
  if (!onay) return false;
  final h = await Hesap.o.engelle(nick);
  _bilgi(m, h ?? t('{ad} engellendi.', {'ad': nick}));
  return h == null;
}

/// Bir oyuncu için küçük menü (alttan): Şikayet et / Engelle (ya da Engeli kaldır). Engel durumu değiştiyse true döner.
Future<bool> kullaniciMenusu(BuildContext context, String nick, {String baglam = 'oyun'}) async {
  final engelli = Hesap.o.engelliMi(nick);
  final sec = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: _zemin,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(nick, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        ListTile(leading: const Icon(Icons.flag_outlined, color: Colors.white), title: Text(t('Şikayet et'), style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(c, 'sikayet')),
        ListTile(
          leading: Icon(engelli ? Icons.lock_open : Icons.block, color: engelli ? Colors.greenAccent : Colors.redAccent),
          title: Text(engelli ? t('Engeli kaldır') : t('Engelle'), style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(c, 'engel'),
        ),
      ]),
    ),
  );
  if (sec == null || !context.mounted) return false;
  if (sec == 'sikayet') {
    await sikayetEt(context, nick, baglam: baglam);
    return false;
  }
  if (engelli) {
    final m = ScaffoldMessenger.of(context);
    final h = await Hesap.o.engeliKaldir(nick);
    _bilgi(m, h ?? t('{ad} için engel kaldırıldı.', {'ad': nick}));
    return h == null;
  }
  return engelleOnayli(context, nick);
}

/// Hesabı silme akışı: açıklama → silinecekler → onay kutusu + "SIL" (+ e-posta hesabında parola). Silindiyse true.
Future<bool> hesapSilAkisi(BuildContext context) async {
  final devam = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: _zemin,
          title: Text(t('Hesabı sil'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5))),
                child: Text(
                  t('Seviye {lv} ve {altin} altınınla buraya kadar geldin. Gitmene üzülürüz, kalmaya ne dersin?', {'lv': Hesap.o.level, 'altin': Hesap.o.altin}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              Text(t('Hesabın ve ona bağlı tüm veriler kalıcı olarak silinir. Bu işlem geri alınamaz.'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              Text(t('Silinecekler:'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              for (final s in const ['Profilin, nickname ve avatarın', 'Seviye, XP ve altınların', 'Dükkândan aldığın eşyalar', 'Arkadaş listen ve engellerin', 'Oyun geçmişin ve başarımların', 'Bağlı e-posta, Google ve Facebook girişin'])
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('•  ${t(s)}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.white60, alignment: Alignment.centerLeft),
                onPressed: () => yasalSayfaAc(c, sayfa: 'hesap-sil'),
                child: Text(t('Hesap silme sayfası'), style: const TextStyle(decoration: TextDecoration.underline, fontSize: 12)),
              ),
            ]),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                onPressed: () => Navigator.pop(c, false),
                child: Text(t('Vazgeç')),
              ),
            ),
            Center(child: TextButton(style: TextButton.styleFrom(foregroundColor: Colors.white38, textStyle: const TextStyle(fontSize: 12)), onPressed: () => Navigator.pop(c, true), child: Text(t('Devam')))),
          ],
        ),
      ) ??
      false;
  if (!devam || !context.mounted) return false;
  final silindi = await showDialog<bool>(context: context, builder: (c) => const _HesapSilOnay()) ?? false;
  if (silindi && context.mounted) {
    final m = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    _bilgi(m, t('Hesabın silindi. Misafir olarak devam edebilirsin.'));
  }
  return silindi;
}

class _HesapSilOnay extends StatefulWidget {
  const _HesapSilOnay();
  @override
  State<_HesapSilOnay> createState() => _HesapSilOnayState();
}

class _HesapSilOnayState extends State<_HesapSilOnay> {
  final _sil = TextEditingController();
  final _parola = TextEditingController();
  bool _anladim = false, _mesgul = false;
  String? _hata;
  final bool _parolaGerek = Hesap.o.profil?['eposta'] != null;

  @override
  void dispose() {
    _sil.dispose();
    _parola.dispose();
    super.dispose();
  }

  bool get _hazir => _anladim && _sil.text.trim() == 'SIL' && (!_parolaGerek || _parola.text.isNotEmpty) && !_mesgul;

  Future<void> _gonder() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final h = await Hesap.o.hesapSil(parola: _parolaGerek ? _parola.text : null);
    if (!mounted) return;
    if (h == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _mesgul = false;
        _hata = h;
      });
    }
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _zemin,
        title: Text(t('Son onay'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Colors.redAccent,
              value: _anladim,
              onChanged: _mesgul ? null : (v) => setState(() => _anladim = v ?? false),
              title: Text(t('Hesabımın ve verilerimin kalıcı olarak silineceğini anlıyorum.'), style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            TextField(controller: _sil, enabled: !_mesgul, autocorrect: false, textCapitalization: TextCapitalization.characters, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white), decoration: _dec(t('Onaylamak için SIL yaz'))),
            if (_parolaGerek) ...[
              const SizedBox(height: 10),
              TextField(controller: _parola, enabled: !_mesgul, obscureText: true, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white), decoration: _dec(t('Parolan'))),
            ],
            if (_hata != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(sunucuMesaj(_hata!), style: const TextStyle(color: Colors.orangeAccent))),
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              onPressed: _mesgul ? null : () => Navigator.pop(context, false),
              child: Text(t('Vazgeç')),
            ),
          ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent.withValues(alpha: 0.7), textStyle: const TextStyle(fontSize: 12)),
              onPressed: _hazir ? _gonder : null,
              child: _mesgul ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(t('Hesabı kalıcı sil')),
            ),
          ),
        ],
      );
}
