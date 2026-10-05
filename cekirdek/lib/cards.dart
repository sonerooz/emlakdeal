import 'dart:math';

/// Mülk renkleri (10 set).
enum PColor { brown, lightBlue, pink, orange, red, yellow, green, darkBlue, railroad, utility }

extension PColorX on PColor {
  String get ad => const {
        PColor.brown: 'Kahverengi',
        PColor.lightBlue: 'Açık Mavi',
        PColor.pink: 'Mor',
        PColor.orange: 'Turuncu',
        PColor.red: 'Kırmızı',
        PColor.yellow: 'Sarı',
        PColor.green: 'Yeşil',
        PColor.darkBlue: 'Lacivert',
        PColor.railroad: 'Siyah',
        PColor.utility: 'Turkuaz',
      }[this]!;

  /// Kart üstünde kullanılan kısa ad (uzun adlar sığmıyor).
  String get kisaAd => const {
        PColor.brown: 'Kahve',
        PColor.lightBlue: 'A. Mavi',
        PColor.pink: 'Mor',
        PColor.orange: 'Turuncu',
        PColor.red: 'Kırmızı',
        PColor.yellow: 'Sarı',
        PColor.green: 'Yeşil',
        PColor.darkBlue: 'Lacivert',
        PColor.railroad: 'Siyah',
        PColor.utility: 'Turkuaz',
      }[this]!;

  /// Seti tamamlamak için gereken mülk sayısı.
  int get setBoyu => const {
        PColor.brown: 2,
        PColor.lightBlue: 3,
        PColor.pink: 3,
        PColor.orange: 3,
        PColor.red: 3,
        PColor.yellow: 3,
        PColor.green: 3,
        PColor.darkBlue: 2,
        PColor.railroad: 4,
        PColor.utility: 2,
      }[this]!;

  /// Kira tablosu: n mülk için kira (index n-1).
  List<int> get kira => const {
        PColor.brown: [1, 2],
        PColor.lightBlue: [1, 2, 3],
        PColor.pink: [1, 2, 4],
        PColor.orange: [1, 3, 5],
        PColor.red: [2, 3, 6],
        PColor.yellow: [2, 4, 6],
        PColor.green: [2, 4, 7],
        PColor.darkBlue: [3, 8],
        PColor.railroad: [1, 2, 3, 4],
        PColor.utility: [1, 2],
      }[this]!;

  /// Mülk kartının para değeri.
  int get deger => const {
        PColor.brown: 1,
        PColor.lightBlue: 1,
        PColor.pink: 2,
        PColor.orange: 2,
        PColor.red: 3,
        PColor.yellow: 3,
        PColor.green: 4,
        PColor.darkBlue: 4,
        PColor.railroad: 2,
        PColor.utility: 2,
      }[this]!;

  bool get binaOlur => this != PColor.railroad && this != PColor.utility;

  /// Her renk grubu bir Türk büyükşehrini temsil eder; kira sırası = şehir büyüklüğü/zenginliği.
  /// Lacivert en pahalı (İstanbul), kahverengi en ucuz (Gaziantep).
  String get sehir => const {
        PColor.brown: 'Gaziantep',
        PColor.lightBlue: 'Adana',
        PColor.pink: 'Konya',
        PColor.orange: 'Antalya',
        PColor.red: 'Bursa',
        PColor.yellow: 'İzmir',
        PColor.green: 'Ankara',
        PColor.darkBlue: 'İstanbul',
        PColor.railroad: 'Ulaşım',
        PColor.utility: 'Altyapı',
      }[this]!;

  /// Setteki tapu adları: o şehrin en büyük/bilinen ilçeleri (pahalıdan ucuza).
  List<String> get sokaklar => const {
        PColor.brown: ['Şahinbey', 'Şehitkamil'],
        PColor.lightBlue: ['Seyhan', 'Çukurova', 'Yüreğir'],
        PColor.pink: ['Selçuklu', 'Meram', 'Karatay'],
        PColor.orange: ['Muratpaşa', 'Konyaaltı', 'Kaş'],
        PColor.red: ['Nilüfer', 'Osmangazi', 'Gemlik'],
        PColor.yellow: ['Konak', 'Karşıyaka', 'Bornova'],
        PColor.green: ['Çankaya', 'Yenimahalle', 'Keçiören'],
        PColor.darkBlue: ['Beşiktaş', 'Kadıköy'],
        PColor.railroad: ['Sabiha Gökçen Havalimanı', 'Esenboğa Havalimanı', 'Eskihisar Feribot İskelesi', 'Topçular Feribot İskelesi'],
        PColor.utility: ['Doğalgaz İdaresi', 'Telekom Altyapısı'],
      }[this]!;
}

enum CardKind { money, property, wild, action, rent }

enum ActionType {
  dealBreaker,
  justSayNo,
  slyDeal,
  forcedDeal,
  tahsilat,
  birthday,
  passGo,
  house,
  hotel,
  doubleRent,
}

extension ActionX on ActionType {
  String get ad => const {
        ActionType.dealBreaker: 'Haciz',
        ActionType.justSayNo: 'Reddet',
        ActionType.slyDeal: 'Tapu Devri',
        ActionType.forcedDeal: 'Takas Pazarlığı',
        ActionType.tahsilat: 'İcra Takibi',
        ActionType.birthday: 'Ev Partisi',
        ActionType.passGo: '2 Kart Çek',
        ActionType.house: 'Ev',
        ActionType.hotel: 'Rezidans',
        ActionType.doubleRent: 'Zam Geldi',
      }[this]!;

  String get aciklama => const {
        ActionType.dealBreaker: 'Rakibin TAM bir setini (ev/rezidans dahil) çal.',
        ActionType.justSayNo: 'Sana oynanan bir aksiyonu iptal et.',
        ActionType.slyDeal: 'Rakipten tamamlanmamış setten bir tapu çal.',
        ActionType.forcedDeal: 'Rakiple bir tapu takas et (tam setler hariç).',
        ActionType.tahsilat: 'Bir rakipten 5M tahsil et.',
        ActionType.birthday: 'Her oyuncudan 2M al.',
        ActionType.passGo: '2 kart çek.',
        ActionType.house: 'Tam bir sete koy: kira +3M.',
        ActionType.hotel: 'Evli tam sete koy: kira +4M.',
        ActionType.doubleRent: 'Bir kira kartıyla oyna: kira 2 katı.',
      }[this]!;

  int get deger => const {
        ActionType.dealBreaker: 5,
        ActionType.justSayNo: 4,
        ActionType.slyDeal: 3,
        ActionType.forcedDeal: 3,
        ActionType.tahsilat: 3,
        ActionType.birthday: 2,
        ActionType.passGo: 1,
        ActionType.house: 3,
        ActionType.hotel: 4,
        ActionType.doubleRent: 1,
      }[this]!;
}

/// Tek bir kart. Her kartın benzersiz [id]'si var (aynı tür kartları ayırt etmek için).
class GameCard {
  GameCard._({
    required this.id,
    required this.kind,
    this.value = 0,
    this.color,
    this.colors = const [],
    this.action,
    this.rentColors = const [],
    this.sokak,
  });

  /// Bankaya konan aksiyon/kira kartı bu düz para kartına dönüşür.
  factory GameCard.para(int id, int value) => GameCard._(id: id, kind: CardKind.money, value: value);

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind.index,
        'v': value,
        if (color != null) 'c': color!.index,
        if (colors.isNotEmpty) 'cs': [for (final c in colors) c.index],
        if (action != null) 'a': action!.index,
        if (rentColors.isNotEmpty) 'rc': [for (final c in rentColors) c.index],
        if (sokak != null) 's': sokak,
        if (wildColor != null) 'w': wildColor!.index,
      };

  factory GameCard.fromJson(Map<String, dynamic> j) => GameCard._(
        id: j['id'] as int,
        kind: CardKind.values[j['k'] as int],
        value: (j['v'] as int?) ?? 0,
        color: j['c'] == null ? null : PColor.values[j['c'] as int],
        colors: [for (final c in (j['cs'] as List?) ?? const []) PColor.values[c as int]],
        action: j['a'] == null ? null : ActionType.values[j['a'] as int],
        rentColors: [for (final c in (j['rc'] as List?) ?? const []) PColor.values[c as int]],
        sokak: j['s'] as String?,
      )..wildColor = j['w'] == null ? null : PColor.values[j['w'] as int];

  final int id;
  final CardKind kind;
  final int value; // para değeri
  final PColor? color; // property: rengi. wild: seçilmiş rengi (oynanınca)
  final List<PColor> colors; // wild: seçilebilir renkler (boş = her renk)
  final ActionType? action;
  final List<PColor> rentColors; // rent: geçerli renkler (boş = joker kira)
  final String? sokak; // property: tapu adı (Türkçe baskı)

  /// Oynanmış joker mülkün şu anki rengi (değiştirilebilir).
  PColor? wildColor;

  bool get isMoney => kind == CardKind.money;
  bool get isProperty => kind == CardKind.property || kind == CardKind.wild;
  bool get isWild => kind == CardKind.wild;
  bool get isMultiWild => kind == CardKind.wild && colors.isEmpty;
  bool get isAction => kind == CardKind.action;
  bool get isRent => kind == CardKind.rent;
  bool get isWildRent => kind == CardKind.rent && rentColors.isEmpty;

  /// Mülk olarak hangi renkte sayılıyor.
  PColor? get etkinRenk => kind == CardKind.property ? color : wildColor;

  /// Para/ödeme değeri.
  int get paraDegeri {
    if (kind == CardKind.property) return color!.deger;
    return value;
  }

  String get ad {
    switch (kind) {
      case CardKind.money:
        return '${value}M';
      case CardKind.property:
        return sokak ?? color!.ad;
      case CardKind.wild:
        return colors.isEmpty ? 'Joker Tapu' : '${colors[0].ad} / ${colors[1].ad}';
      case CardKind.action:
        return action!.ad;
      case CardKind.rent:
        return rentColors.isEmpty ? 'Joker Kira' : 'Kira ${rentColors[0].ad}/${rentColors[1].ad}';
    }
  }

  String get kisaAd {
    switch (kind) {
      case CardKind.money:
        return '${value}M';
      case CardKind.property:
        return sokak ?? color!.ad;
      case CardKind.wild:
        return colors.isEmpty ? 'Joker' : 'Joker';
      case CardKind.action:
        return action!.ad;
      case CardKind.rent:
        return rentColors.isEmpty ? 'Joker Kira' : 'Kira';
    }
  }

  // ------------------------------------------------------------ deste
  static List<GameCard> yeniDeste() {
    final d = <GameCard>[];
    var id = 0;
    void ekle(GameCard Function(int) f, int adet) {
      for (var i = 0; i < adet; i++) d.add(f(id++));
    }

    // Para (20)
    for (final e in {1: 6, 2: 5, 3: 3, 4: 3, 5: 2, 10: 1}.entries) {
      ekle((i) => GameCard._(id: i, kind: CardKind.money, value: e.key), e.value);
    }
    // Mülkler (28)
    for (final c in PColor.values) {
      for (var k = 0; k < c.setBoyu; k++) {
        final ad = k < c.sokaklar.length ? c.sokaklar[k] : null;
        d.add(GameCard._(id: id++, kind: CardKind.property, color: c, sokak: ad));
      }
    }
    // Joker mülkler (11)
    GameCard w(int i, List<PColor> cs, int v) =>
        GameCard._(id: i, kind: CardKind.wild, colors: cs, value: v);
    ekle((i) => w(i, [PColor.pink, PColor.orange], 2), 2);
    ekle((i) => w(i, [PColor.red, PColor.yellow], 3), 2);
    ekle((i) => w(i, [PColor.lightBlue, PColor.brown], 1), 1);
    ekle((i) => w(i, [PColor.lightBlue, PColor.railroad], 4), 1);
    ekle((i) => w(i, [PColor.darkBlue, PColor.green], 4), 1);
    ekle((i) => w(i, [PColor.railroad, PColor.green], 4), 1);
    ekle((i) => w(i, [PColor.railroad, PColor.utility], 2), 1);
    ekle((i) => w(i, const [], 0), 2); // çok renkli joker (değeri 0)
    // Aksiyonlar (34)
    GameCard a(int i, ActionType t) =>
        GameCard._(id: i, kind: CardKind.action, action: t, value: t.deger);
    for (final e in {
      ActionType.dealBreaker: 2,
      ActionType.justSayNo: 3,
      ActionType.slyDeal: 3,
      ActionType.forcedDeal: 3,
      ActionType.tahsilat: 3,
      ActionType.birthday: 3,
      ActionType.passGo: 10,
      ActionType.house: 3,
      ActionType.hotel: 2,
      ActionType.doubleRent: 2,
    }.entries) {
      ekle((i) => a(i, e.key), e.value);
    }
    // Kira (13)
    GameCard r(int i, List<PColor> cs, int v) =>
        GameCard._(id: i, kind: CardKind.rent, rentColors: cs, value: v);
    ekle((i) => r(i, [PColor.darkBlue, PColor.green], 1), 2);
    ekle((i) => r(i, [PColor.red, PColor.yellow], 1), 2);
    ekle((i) => r(i, [PColor.pink, PColor.orange], 1), 2);
    ekle((i) => r(i, [PColor.lightBlue, PColor.brown], 1), 2);
    ekle((i) => r(i, [PColor.railroad, PColor.utility], 1), 2);
    ekle((i) => r(i, const [], 3), 3);
    assert(d.length == 106);
    d.shuffle(Random());
    return d;
  }
}
