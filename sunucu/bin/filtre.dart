/// Serbest sohbet için basit Türkçe küfür/hakaret filtresi: eşleşen sözcükler yıldızlanır.
/// Kök eşleme (ekler dahil), büyük/küçük ve Türkçe karakter duyarsız.
const _kokler = [
  'amk', 'aq', 'amq', 'amına', 'amina', 'orospu', 'oç', 'oc', 'piç', 'pic', 'sik', 'siktir', 'yarak', 'yarrak', 'göt', 'got', 'ibne',
  'pezevenk', 'kahpe', 'sürtük', 'surtuk', 'gavat', 'fahişe', 'fahise', 'salak', 'gerizekalı', 'gerizekali', 'aptal', 'mal',
  'bok', 'puşt', 'pust', 'kaltak', 'döl', 'dol', 'ananı', 'anani', 'avradını', 'avradini', 'fuck', 'shit', 'bitch', 'asshole',
];

String _duz(String s) => s
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll('â', 'a');

String sansurle(String metin) {
  final kelimeler = metin.split(RegExp(r'(\s+)'));
  final cikti = <String>[];
  for (final k in kelimeler) {
    final d = _duz(k.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''));
    final kotu = d.isNotEmpty && _kokler.any((kok) => d == kok || (kok.length >= 4 && d.startsWith(kok)));
    cikti.add(kotu ? '*' * k.length : k);
  }
  return cikti.join(' ');
}
