/// Oyun konuşmasının İngilizcesi (Türkçe şablon cümle → İngilizce). Eşleşme yoksa null.
const Map<String, String> _renkEn = {
  'Kahverengi': 'Brown',
  'Açık Mavi': 'Light Blue',
  'Mor': 'Purple',
  'Turuncu': 'Orange',
  'Kırmızı': 'Red',
  'Sarı': 'Yellow',
  'Yeşil': 'Green',
  'Lacivert': 'Dark Blue',
  'Siyah': 'Black',
  'Turkuaz': 'Turquoise',
};

const Map<String, String> _sabitEn = {
  'Tapu takası yapıyorum.': "I'm swapping properties.",
  'Senden 5M tahsil ediyorum.': "I'm collecting 5M from you.",
  'Reddediyorum!': 'Just say no!',
  'Reddini reddediyorum!': 'I reject your rejection!',
  'Ödeyecek hiçbir şeyim yok.': 'I have nothing to pay with.',
  'İki kart çekiyorum.': "I'm drawing two cards.",
  'Bugün doğum günüm! Herkesten 2M istiyorum.': "It's my birthday! 2M from everyone, please.",
  'Üç tam set! Kazandım!': 'Three full sets! I win!',
  'Çift kira!': 'Double rent!',
  'Süren bitti, sıra bende!': "Time's up, my turn!",
  'Joker tapuyu alıyorum.': "I'm taking the wild property.",
  'Kahretsin!': 'Damn it!',
  'Sen görürsün!': "You'll see!",
  'Bir dahaki sefere.': 'Next time.',
  'Bunun intikamı acı olur!': "You'll pay for this!",
  'İyi oyundu!': 'Good game!',
  'Hahaha!': 'Hahaha!',
  'Şans işte.': 'Just luck.',
  'Bravo!': 'Bravo!',
  'Acele et biraz!': 'Hurry up!',
  'Teşekkürler.': 'Thanks.',
  'Buna inanamıyorum!': "I can't believe it!",
  'Pes ediyorum.': 'I give up.',
};

// Şablon: (desen, üretici). Yakalama grupları: renk(ler) ve sayı(lar).
final List<(RegExp, String Function(Match))> _sablonlar = [
  (RegExp(r'^(.+) setinden (\d+)M kira istiyorum\.$'), (m) => "I'm charging ${m[2]}M rent for the ${_renkEn[m[1]]} set."),
  (RegExp(r'^(.+) tapu setini haciz ediyorum!$'), (m) => "I'm seizing the ${_renkEn[m[1]]} set!"),
  (RegExp(r'^(.+) seti artık benim\.$'), (m) => 'The ${_renkEn[m[1]]} set is mine now.'),
  (RegExp(r'^Jokeri (.+) setine koyuyorum\.$'), (m) => "I'm putting the wild card on the ${_renkEn[m[1]]} set."),
  (RegExp(r'^(.+) setine ev koyuyorum\.$'), (m) => "I'm adding a house to the ${_renkEn[m[1]]} set."),
  (RegExp(r'^(.+) setine otel koyuyorum\.$'), (m) => "I'm adding a hotel to the ${_renkEn[m[1]]} set."),
  (RegExp(r'^Buyur, (\d+)M\.$'), (m) => 'Here you go, ${m[1]}M.'),
  (RegExp(r'^Elimde bu kadar var: (\d+)M\.$'), (m) => "That's all I have: ${m[1]}M."),
  (RegExp(r'^(\d+)M bankaya\.$'), (m) => '${m[1]}M to the bank.'),
  (RegExp(r'^Hamle kartını (\d+)M olarak bankaya koyuyorum\.$'), (m) => "I'm banking this action card as ${m[1]}M."),
  (RegExp(r'^(.+) tapu alıyorum\.$'), (m) => "I'm taking a ${_renkEn[m[1]]} property."),
  (RegExp(r'^(.+) tapu masaya\.$'), (m) => '${_renkEn[m[1]]} property on the table.'),
];

String? sozEn(String tr) {
  final s = tr.trim();
  final sabit = _sabitEn[s];
  if (sabit != null) return sabit;
  for (final (desen, uret) in _sablonlar) {
    final m = desen.firstMatch(s);
    if (m == null) continue;
    final renk = m[1];
    if (renk != null && int.tryParse(renk) == null && !_renkEn.containsKey(renk)) continue;
    return uret(m);
  }
  return null;
}
