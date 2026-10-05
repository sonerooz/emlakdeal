// Küfür / uygunsuz içerik filtresi (Türkçe + İngilizce).
// kufurluMu(): kullanıcı adı, serbest metin vb. için karar; sansurle(): sohbette kötü sözcükleri yıldızlar.
//
// Yöntem: metin normalleştirilir (küçük harf, Türkçe harf katlama, leetspeak, ayraç temizliği), sözcüklere ayrılır;
// uzun/kesin kökler sözcük içinde her yerde (S), kısa/belirsiz kökler yalnız sözcük başında (P) ya da tam eşleşmede (E)
// aranır (Scunthorpe sorunu). Masum sözcükler eşleşmeden önce maskelenir.

const kotuIsimMesaji = 'Bu isim uygun değil.';

// ----------------------------------------------------------------- normalleştirme

const _leet = <String, String>{
  '0': 'o', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', r'$': 's', '!': 'i', '+': 't', '|': 'i', '€': 'e', '£': 'e', '¡': 'i',
};

const _katla = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ū': 'u', 'ů': 'u',
  'ñ': 'n', 'ń': 'n', 'ý': 'y', 'ÿ': 'y', 'ß': 's', 'š': 's', 'ś': 's', 'ž': 'z', 'ź': 'z', 'ż': 'z',
  'ć': 'c', 'č': 'c', 'ł': 'l', 'đ': 'd', 'ď': 'd', 'ř': 'r', 'ť': 't',
  // Kiril ve Yunan benzer harfler
  'а': 'a', 'в': 'b', 'е': 'e', 'к': 'k', 'м': 'm', 'н': 'h', 'о': 'o', 'р': 'p', 'с': 'c', 'т': 't', 'у': 'y', 'х': 'x', 'і': 'i', 'ѕ': 's', 'ј': 'j',
  'α': 'a', 'ο': 'o', 'ρ': 'p', 'ν': 'v', 'ι': 'i', 'κ': 'k', 'τ': 't', 'υ': 'u',
};

/// Metni küçük harfe çevirir; Türkçe harfler (ş ı ğ ö ü ç) korunur, ASCII I ve İ → i (yani "SİKTİR" ve "SIKTIR" aynı).
/// 1 → i ya da l (iki varyant); diğer rakam/simgeler leetspeak tablosuyla harfe döner.
List<String> _siki(String metin) {
  final b = StringBuffer();
  var birSayisi = 0;
  for (final r in metin.runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // tam genişlik
    if (c == 0x200B || c == 0x200C || c == 0x200D || c == 0xFEFF || c == 0x00AD || c == 0x2060) continue;
    if (c >= 0x0300 && c <= 0x036F) continue; // birleşik aksan
    var ch = String.fromCharCode(c);
    if (ch == 'I' || ch == 'İ') {
      b.write('i');
      continue;
    }
    if (ch == 'ı') {
      b.write('ı');
      continue;
    }
    ch = ch.toLowerCase();
    ch = _katla[ch] ?? ch;
    if (ch == '1') {
      b.write('~');
      birSayisi++;
      continue;
    }
    b.write(_leet[ch] ?? ch);
  }
  final s = b.toString();
  if (birSayisi == 0) return [s];
  if (birSayisi > 4) return [s.replaceAll('~', 'i'), s.replaceAll('~', 'l')];
  final sonuc = <String>[];
  for (var m = 0; m < (1 << birSayisi); m++) {
    var n = 0;
    sonuc.add(s.replaceAllMapped('~', (_) => ((m >> n++) & 1) == 0 ? 'i' : 'l'));
  }
  return sonuc;
}

String _katlaTr(String s) => s.replaceAll('ş', 's').replaceAll('ı', 'i').replaceAll('ğ', 'g').replaceAll('ö', 'o').replaceAll('ü', 'u').replaceAll('ç', 'c');

// ----------------------------------------------------------------- kök listeleri
// Kök yazımı: her harf otomatik "+" (tekrar eden harf) olur. "/" ile başlayan kök ham düzenli ifadedir.

String _k(String kok) => kok.startsWith('/') ? kok.substring(1) : kok.split('').map((c) => '$c+').join();
String _hepsi(List<String> l) => l.map(_k).join('|');

/// S: sözcüğün herhangi bir yerinde. Masum sözcüklerde geçmesi çok zor olan uzun/kesin kökler.
const _sTr = [
  'orospu', 'oruspu', 'orosbu', 'orusbu', 'orspu', 'orospi', 'oropsu',
  'amcik', 'amcig', 'amcuk', 'amcug',
  r'/m+i+n+a+k+o+[yd]+',
  'kahpe', 'kahbe', 'kaltak', 'fahise', 'pezevenk', 'pezeveng', 'gavat', 'yavsak', 'surtuk', 'ibne',
  'gerizekali', 'gerzek', 'dangalak', 'serefsiz', 'namussuz', 'haysiyetsiz', 'avradini',
  'dalyarak', 'dalyarrak', 'dalyaragi', 'dalyarag',
  r'/y+a+r{2,}a+[kg]+',
  'gotveren', 'gotlek', 'gotos', 'masturb', 'pornografi',
];

/// P: yalnız sözcüğün başında (kök + herhangi bir ek).
const _pTr = ['amk', 'amq', 'yarak', 'yarag', 'tasak', 'tasag', 'kodugumun', 'kodumun', 'sktir'];

/// E: tam eşleşme.
const _eTr = [
  'aq', 'sktr', 'bok', 'boktan', 'boku', 'bokun', 'bokunu', 'bokum', 'boklar', 'boklu', 'bokluk', 'boktur', 'bokuna', 'boka',
  'pust', 'pustlar', 'pusttur', 'pustluk', 'seks', 'sekss', 'sex', 'sexy', 'sexs', 'vajina', 'vagina', 'penis', 'penisi', 'porno', 'pornosu',
  'kavat', 'kavatlar',
];

const _sEn = [
  r'/f+[uv]+c+k+', r'/p+h+[uv]+c+k+', r'/f+u+k{2,}', 'motherf', 'shit', 'bitch', r'/b+[ie]+a+t+c+h+', 'cunt', 'pussy', 'asshole', 'arsehole', 'asswipe',
  'dumbass', 'fatass', 'kissass', 'asslicker', 'bastard', 'whore', 'slut', r'/n+i+g{2,}e+r+', r'/f+a+g{2,}[oe]+t+', 'dickhead', 'cocksuck',
  'blowjob', 'handjob', 'rimjob', 'cumshot', 'jizz', 'porn', 'hentai', 'wanker', r'/b+o+l{2,}o+c+k+', r'/b+u+g{2,}e+r+', r'/p+i+s{2,}', 'masturbat',
  'jerkoff', 'jackoff', 'fellatio', 'cunnilingus', 'mongoloid', 'wetback', 'pedophil', 'paedophil', 'killyourself', 'douchebag', 'scumbag', 'fuckwit',
];

const _eEn = [
  'ass', 'asses', 'dick', 'dicks', 'cock', 'cocks', 'penis', 'vagina', 'dildo', 'dildos', 'orgasm', 'orgasms', 'boob', 'boobs', 'boobies',
  'tit', 'tits', 'titty', 'titties', 'anal', 'anus', 'cum', 'milf', 'milfs', 'horny', 'boner', 'twat', 'twats', 'tosser', 'tossers', 'prick', 'pricks',
  'arse', 'arses', 'retard', 'retards', 'retarded', 'spastic', 'spaz', 'kike', 'kikes', 'chink', 'chinks', 'gook', 'gooks', 'spic', 'spics',
  'beaner', 'beaners', 'coon', 'coons', 'paki', 'pakis', 'negro', 'negroes', 'tranny', 'trannies', 'fag', 'fags', 'faggy', 'dyke', 'dykes',
  'nazi', 'nazis', 'hitler', 'rape', 'raped', 'rapes', 'raping', 'rapist', 'rapists', 'pedo', 'pedos', 'incest', 'kys',
  'wtf', 'stfu', 'gtfo', 'fuk', 'fuq', 'fck', 'fcuk', 'fvk', 'shyt', 'shite', 'shitz', 'biatch', 'bytch', 'cunts', 'pussies', 'douche',
  'douches', 'wank', 'wanks', 'wanking', 'pornhub', 'slutty', 'whores', 'prostitute', 'prostitutes', 'pimp', 'pimps', 'hooker', 'hookers',
  'nigga', 'niggas', 'niggah', 'nigguh', 'niga', 'nigas', 'nigaz', 'niggaz', 'mofo', 'mofos', 'fuker', 'fukker', 'sex', 'sexy', 'sexs', 'sexxy',
  'blowie', 'gangbang', 'bukkake', 'cuck', 'cucks', 'sluts',
];

/// Türkçe i/ı, ş/s, ö/o ayrımı önemli olan kökler: "ışıktır", "kaşık", "şık", "götürmek" gibi masum sözcükleri korur.
/// Noktalı i zorunlu; s yerine ş de olabilir. "SIKTIR" gibi büyük harf yazım _siki'de i'ye döndüğü için yakalanır.
final _sikS = RegExp(
  r'[sş]+i+k+t+i+r+|[sş]+i+k+e+y+i+m+|[sş]+i+k+e+r+i+m+|[sş]+i+k+i+y+i+m+|[sş]+i+k+e+c+e+m+|[sş]+i+k+i+c+e+m+|[sş]+i+k+c+e+m+|'
  r'[sş]+i+k+i+[sş]+|[sş]+i+k+i+k+|[sş]+i+k+t+i+[gğ]+|[sş]+i+k+i+l+e+c+e+k+|[sş]+i+k+m+i+[sş]+|[sş]+i+k+t+i+m+|[gğ]+ö+t+ü+n+ü+|'
  r'sı+ç+(?:tı|tım|mak|ayım|arım|tığ)',
);
final _sikE = RegExp(
  r'^(?:s+i+k+|o+ç+|pi+ç+(?:ler|lik|ten|in|i|e|lerin|liği|ligi)?|ç+ü+k+(?:ü|ler|ünü|üm|ün)?|'
  r'gö+t+(?:ü|u|un|ün|üne|une|ünü|unu|ler|lerin|leri|ten|e|üm|ünden|lek|os|veren)?|go+t+(?:u|un|une|unu|lerin|leri|lek|os|veren|unden))$',
);

final _sRe = RegExp(_hepsi([..._sTr, ..._sEn]));
final _pRe = RegExp('^(?:${_hepsi(_pTr)})');
final _eRe = RegExp('^(?:${_hepsi([..._eTr, ..._eEn])})\$');

/// Masum sözcükler: S kökleriyle yanlış eşleşmesin diye eşleşmeden önce # ile maskelenir.
const _masum = ['scunthorpe', 'shiitake', 'shitake', 'shittim', 'mishit', 'pissarro', 'pissouri', 'pissiz'];
final _masumRe = RegExp(_hepsi(_masum));

/// Joker (f*ck, s**t, o*ospu) karşılaştırması için çıplak sözcükler.
const _joker = [
  'fuck', 'fucker', 'fucking', 'shit', 'shitty', 'bitch', 'cunt', 'pussy', 'whore', 'slut', 'dick', 'cock', 'asshole', 'bastard', 'nigger', 'faggot', 'motherfucker',
  'orospu', 'amcik', 'yarrak', 'yarak', 'siktir', 'sikerim', 'sikeyim', 'kahpe', 'pezevenk', 'yavsak', 'gavat', 'kaltak', 'ibne', 'serefsiz', 'gotveren',
  'pic', 'got', 'sik', 'porno', 'penis', 'vagina',
];

final _ifade = [
  RegExp(r'\bamin[ai] ?koy'),
  RegExp(r'\bmin[ai] ?koy'),
  RegExp(r'\bgot veren'),
  RegExp(r'\banan[ai] ?(?:sik|avrad)'),
  RegExp(r'\bbacin[ai] ?sik'),
  RegExp(r'\borospu c[oi]c'),
];

// ----------------------------------------------------------------- eşleştirme

bool _jokerEsler(String t) {
  if (!t.contains('*') && !t.contains('#')) return false;
  final gercek = t.replaceAll(RegExp(r'[*#]'), '').length;
  if (gercek < 2 || t.length < 4) return false;
  final tk = _katlaTr(t);
  for (final j in _joker) {
    if (j.length != tk.length) continue;
    var ok = true;
    for (var i = 0; i < j.length; i++) {
      final c = tk[i];
      if (c != '*' && c != '#' && c != j[i]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// sk: sıkı (ı, ş, ö … korunmuş), fk: Türkçe harfleri katlanmış.
bool _sozcukKotu(String sk, String fk) {
  if (sk.isEmpty) return false;
  if (_jokerEsler(sk)) return true;
  if (_sikS.hasMatch(sk) || _sikE.hasMatch(sk)) return true;
  final f = fk.replaceAll(_masumRe, '#');
  return _sRe.hasMatch(f) || _pRe.hasMatch(f) || _eRe.hasMatch(f);
}

List<String> _parcala(String s) => s.split(RegExp(r'[^a-zçğıöşü*#]+')).where((e) => e.isNotEmpty).toList();

/// Tek harflik sözcük dizilerini ("s i k t i r") birleştirir.
List<String> _birlestir(List<String> p) {
  final sonuc = <String>[];
  final tek = StringBuffer();
  void bosalt() {
    if (tek.isNotEmpty) {
      sonuc.add(tek.toString());
      tek.clear();
    }
  }
  for (final x in p) {
    if (x.length == 1) {
      tek.write(x);
    } else {
      bosalt();
      sonuc.add(x);
    }
  }
  bosalt();
  return sonuc;
}

bool _varyantKotu(String sik) {
  final parcalar = _birlestir(_parcala(sik));
  for (final p in parcalar) {
    if (_sozcukKotu(p, _katlaTr(p))) return true;
  }
  // çok kısa parçaların birleşimi: "fu ck", "sh it" (ikisi de ≤ 2 harf; "his hit" gibi gerçek cümleleri yakalamaz)
  for (var i = 0; i + 1 < parcalar.length; i++) {
    var j = i;
    final b = StringBuffer();
    while (j < parcalar.length && parcalar[j].length <= 2 && j - i < 4) {
      b.write(parcalar[j]);
      j++;
      if (j - i >= 2 && _sozcukKotu(b.toString(), _katlaTr(b.toString()))) return true;
    }
  }
  final f = _katlaTr(parcalar.join(' '));
  for (final r in _ifade) {
    if (r.hasMatch(f)) return true;
  }
  return false;
}

/// Metin küfür / uygunsuz sözcük içeriyor mu?
bool kufurluMu(String metin) {
  if (metin.trim().isEmpty) return false;
  for (final v in _siki(metin)) {
    if (_varyantKotu(v)) return true;
    if (v.contains('v') && _varyantKotu(v.replaceAll('v', 'u'))) return true;
  }
  if (metin.contains('0')) {
    for (final v in _siki(metin.replaceAll('0', 'u'))) {
      if (_varyantKotu(v)) return true;
    }
  }
  return false;
}

/// Sohbet: kötü sözcükleri aynı uzunlukta yıldızla değiştirir ("s i k t i r" gibi harf dizilerini de).
String sansurle(String metin) {
  final kelimeler = metin.split(' ');
  final yildiz = List<bool>.filled(kelimeler.length, false);
  for (var i = 0; i < kelimeler.length; i++) {
    if (kelimeler[i].isNotEmpty && kufurluMu(kelimeler[i])) yildiz[i] = true;
  }
  for (var i = 0; i < kelimeler.length; i++) {
    if (yildiz[i] || kelimeler[i].isEmpty || kelimeler[i].length > 2) continue;
    var j = i;
    var son = i;
    final b = StringBuffer();
    while (j < kelimeler.length && kelimeler[j].isNotEmpty && kelimeler[j].length <= 2 && j - i < 8) {
      b.write(kelimeler[j]);
      j++;
      if (j - i >= 2 && kufurluMu(b.toString())) son = j;
    }
    for (var k = i; k < son; k++) {
      yildiz[k] = true;
    }
  }
  return [for (var i = 0; i < kelimeler.length; i++) yildiz[i] ? '*' * kelimeler[i].length.clamp(1, 12) : kelimeler[i]].join(' ');
}
