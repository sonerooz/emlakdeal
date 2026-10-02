/// Level/XP/altın kuralları (uygulama ve sunucu ortak).
///
/// Level L'den L+1'e geçiş eşiği: L*100 + fib(min(L,12))*10, fib(1)=1, fib(2)=2, fib(3)=3, fib(4)=5…
/// (1→2: 110, 2→3: 220, 3→4: 330, 4→5: 450). En yüksek level 80.
const maxLevel = 80;

int fib(int n) {
  var a = 1, b = 2; // fib(1)=1, fib(2)=2
  if (n <= 1) return 1;
  for (var i = 2; i < n; i++) {
    final t = a + b;
    a = b;
    b = t;
  }
  return b;
}

/// [level]'den bir sonrakine geçmek için gereken XP.
/// fib terimi 12'de sabitlenir (üstel patlamayı önler): 80. seviyeye toplam ≈ 450 bin XP.
int levelEsigi(int level) => level >= maxLevel ? 0 : level * 100 + fib(level < 12 ? level : 12) * 10;

/// Toplam XP'den level ve o leveldeki ilerleme.
({int level, int levelXp, int esik}) levelHesapla(int toplamXp) {
  var level = 1, kalan = toplamXp;
  while (level < maxLevel && kalan >= levelEsigi(level)) {
    kalan -= levelEsigi(level);
    level++;
  }
  return (level: level, levelXp: kalan, esik: levelEsigi(level));
}

/// Oyun sonu ödülü. [rakip]: rakip sayısı, [zorluk]: bot zorluğu (0-2), online'da 1.
({int xp, int altin}) odul({required bool kazandi, required int rakip, required bool online, int zorluk = 1}) {
  var xp = kazandi ? 100 : 30;
  var altin = kazandi ? 50 : 10;
  xp += (rakip - 1) * (kazandi ? 20 : 5);
  altin += (rakip - 1) * (kazandi ? 10 : 2);
  final carpan = online ? 1.5 : (zorluk == 0 ? 0.7 : zorluk == 2 ? 1.3 : 1.0);
  return (xp: (xp * carpan).round(), altin: (altin * carpan).round());
}

/// Bot takma adları (nick göstermek için).
const botAdlari = ['Kerem', 'Elif', 'Can', 'Zeynep', 'Mert', 'Defne', 'Emre', 'Nehir', 'Burak', 'Ece', 'Deniz', 'Selin', 'Arda', 'Lara', 'Kaan', 'Mina'];
const avatarlar = ['🦊', '🐻', '🐼', '🦁', '🐯', '🐸', '🐵', '🦄', '🐙', '🦉', '🐧', '🐨', '🐲', '🦋', '🐺', '🦩', '🐘'];
