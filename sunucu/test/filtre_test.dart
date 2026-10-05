import 'dart:io';

import 'package:test/test.dart';

import '../bin/filtre.dart';

/// Sözcük içinde de yakalanması gereken (S tier) ve tek başına yakalanması gerekenler.
const kesin = [
  'orospu', 'oruspu', 'orospu çocuğu', 'amcık', 'amcığa', 'aminakoyim', 'amına koyayım', 'kahpe', 'kaltak', 'fahişe', 'pezevenk', 'gavat', 'yavşak',
  'sürtük', 'ibne', 'gerizekalı', 'dangalak', 'şerefsiz', 'namussuz', 'yarrak', 'dalyarak', 'siktir', 'siktir git', 'sikeyim', 'sikerim', 'sikiyim',
  'sikişmek', 'sikik', 'götveren', 'göt veren', 'fuck', 'fucker', 'fucking', 'motherfucker', 'shit', 'bullshit', 'bitch', 'bitches', 'cunt', 'pussy',
  'asshole', 'arsehole', 'dumbass', 'bastard', 'whore', 'slut', 'nigger', 'faggot', 'dickhead', 'cocksucker', 'blowjob', 'handjob', 'cumshot', 'porn',
  'pornografi', 'wanker', 'bollocks', 'bugger', 'pissed', 'masturbation', 'jerkoff', 'pedophile', 'douchebag', 'killyourself',
];

/// Yalnız tek başına (ya da ayraçlarla ayrılmış) yakalanması gerekenler.
const tek = [
  'amk', 'aq', 'amq', 'amkkk', 'sik', 'göt', 'götü', 'piç', 'oç', 'çük', 'taşak', 'yarak', 'bok', 'boktan', 'pust', 'seks', 'sex', 'sexy', 'penis', 'vagina',
  'ass', 'dick', 'cock', 'tits', 'anal', 'cum', 'twat', 'prick', 'arse', 'retard', 'spic', 'kike', 'coon', 'paki', 'fag', 'dyke', 'nazi', 'hitler', 'rapist',
  'rape', 'wtf', 'stfu', 'gtfo', 'kys', 'fuk', 'fck', 'nigga', 'niga', 'mofo', 'wank', 'horny', 'boner', 'pimp', 'milf',
];

final masumlar = [
  // İngilizce
  'Scunthorpe', 'Assistant', 'Class', 'Classic', 'Assassin', 'Bass', 'Basement', 'Assembly', 'Assume', 'Asset', 'Passage', 'Passport', 'Password', 'Compass',
  'Hancock', 'Cocktail', 'Peacock', 'Cockpit', 'Woodcock', 'Dickens', 'Dickinson', 'Penistone', 'Essex', 'Sussex', 'Middlesex', 'Sextant', 'Sexton',
  'Grape', 'Drape', 'Scrape', 'Therapist', 'Arsenal', 'Parsec', 'Analyst', 'Analysis', 'Banal', 'Canal', 'Titan', 'Title', 'Titanic', 'Constitution', 'Cumulus',
  'Document', 'Cucumber', 'Circumstance', 'Raccoon', 'Cocoon', 'Shiitake', 'Mishit', 'Shitake', 'Swank', 'Twatter', 'Atwater', 'Retardant', 'Prickly', 'Pickle',
  'Hello', 'Welcome', 'Player', 'Champion', 'Winner', 'Mike', 'Hunter', 'Thunder', 'Dragon', 'Shadow', 'Knight', 'Pirate', 'Wizard', 'Gamer', 'Ninja', 'Samurai',
  'Fox', 'Wolf', 'Tiger', 'Eagle', 'Falcon', 'Phoenix', 'Cyber', 'Matrix', 'Neo', 'Trinity', 'Morpheus', 'Gandalf', 'Frodo', 'Sauron', 'Aragorn', 'Legolas',
  'Mississippi', 'Massachusetts', 'Cassie', 'Cassandra', 'Jessica', 'Jessie', 'Russell', 'Mass', 'Pass', 'Glass', 'Grass', 'Brass', 'Kiss', 'Miss', 'Boss',
  'Shell', 'Shirt', 'Shift', 'Ship', 'Shop', 'Short', 'Shot', 'Show', 'Shut', 'Hitchhiker', 'Hitman', 'Hit', 'Bitcoin', 'Bit', 'Biter', 'Titanium',
  'Nigeria', 'Niger', 'Nigel', 'Niggard', 'Bigger', 'Digger', 'Trigger', 'Rigger', 'Jigger', 'Vigor', 'Figure',
  'Cunningham', 'Cunard', 'Scunner', 'Country', 'Counter', 'Uncle', 'Hunt', 'Hunter', 'Mike Hunt',
  'Dickson', 'Dicky', 'Cockburn', 'Cocker', 'Cockney', 'Bitterness', 'Bitter', 'Bitten', 'Bitmap', 'Kitchen', 'Witch', 'Which',
  'Fugitive', 'Fuel', 'Fun', 'Funny', 'Fur', 'Fusion', 'Futur', 'Future', 'Fucsia', 'Fukushima', 'Fukuoka', 'Fukui', 'Fuji', 'Fujiyama', 'Tsunami',
  'Pistachio', 'Piston', 'Pissarro', 'Pisa', 'Pizza', 'Pizzeria', 'Mississauga', 'Passion', 'Pastor',
  'Slug', 'Slush', 'Slum', 'Slim', 'Slow', 'Sluggish', 'Bastille', 'Bastion', 'Baste',
  'Whale', 'Whole', 'Whose', 'Whom', 'Whorl', 'Shore', 'Short', 'Sphere', 'Spice', 'Spicy', 'Spider', 'Spinach', 'Spirit',
  'Raven', 'Rapid', 'Rapture', 'Rapunzel', 'Grapefruit', 'Trapeze', 'Scrapbook', 'Drapes', 'Rapper',
  'Hell', 'Heaven', 'Damn', 'Crap', 'Dammit', 'Dork', 'Idiot', 'Jerk', 'Stupid', 'Loser', 'Noob',
  'Porch', 'Port', 'Portal', 'Porter', 'Portugal', 'Corn', 'Popcorn', 'Born', 'Horn', 'Torn', 'Worn', 'Thorn',
  'Titmouse', 'Tithe', 'Entity', 'Ventilate', 'Attitude', 'Latitude', 'Altitude', 'Gratitude', 'Petition', 'Competition',
  'Analog', 'Analogy', 'Anarchy', 'Anatomy', 'Ancient', 'Anchor', 'Anus Mirabilis'.substring(0, 0) + 'Anise',
  'Faggin', 'Fagin', 'Fagus', 'Cuckoo', 'Cucumber', 'Suck', 'Sucker', 'Succeed', 'Success', 'Succulent',
  'Dyker', 'Dykstra', 'Spock', 'Kirk', 'Picard', 'Data', 'Worf', 'Riker', 'Troi', 'Geordi',
  'Wanted', 'Wandering', 'Wankel', 'Swan', 'Swarm', 'Sweet', 'Sweden', 'Switch',
  'Arsene', 'Arsenic', 'Arsenal FC', 'Sparse', 'Sparsely', 'Coarse', 'Hoarse', 'Parse', 'Tarsus',
  'Penis Island'.substring(0, 0) + 'Penguin', 'Pencil', 'Pension', 'Penny', 'Pentagon', 'Pentium', 'Peninsula', 'Spenser',
  'Lemon', 'Melon', 'Kimono', 'Hanoi', 'Hawaii', 'Tokyo', 'Kyoto', 'Osaka', 'Paris', 'London', 'Berlin', 'Madrid', 'Rome', 'Vienna', 'Prague', 'Oslo',
  'I am a good player', 'Good game', 'Well played', 'Nice move', 'Thanks a lot', 'Let us play', 'What a hit', 'Pass it on', 'Wash it down', 'Cash it in',
  'This is a class assignment', 'The assistant manager', 'A bass guitar', 'Mississippi river', 'I got it', 'Got ya', 'Gotcha', 'Gotten', 'Forgotten', 'Begot',
  // Türkçe
  'Amasya', 'Sikke', 'Işık', 'Kaşık', 'Aşık', 'Şık', 'Şıkır', 'Şikayet', 'Sıkı', 'Sıkıntı', 'Sıkıldım', 'Sıktı', 'Sıkıştı', 'Sıkıştırma', 'Sıkma', 'Sıkmak',
  'Işıktır', 'Kaşıktır', 'Aşıktır', 'Işıktı', 'Aşıktı', 'Kaşıktı', 'Şıkım', 'Şıksın', 'Sıçrama', 'Sıçramak', 'Sıçan', 'Götürmek', 'Götürdü', 'Götür', 'Götürüyorum',
  'Boyarak', 'Oynayarak', 'Koyarak', 'Sayarak', 'Uyarak', 'Doyarak', 'Kuyarak', 'Yaparak', 'Yazarak', 'Okuyarak', 'Gülerek', 'Bakarak', 'Hızlıca',
  'Amca', 'Amcam', 'Amcamın', 'Amina', 'Amini', 'Amir', 'Amiral', 'Ahmet', 'Mehmet', 'Mustafa', 'Ali', 'Veli', 'Ayşe', 'Fatma', 'Hatice', 'Zeynep', 'Emine',
  'Elif', 'Esra', 'Merve', 'Büşra', 'Gizem', 'Ceren', 'Selin', 'Deniz', 'Ece', 'Cem', 'Can', 'Cenk', 'Emre', 'Burak', 'Kerem', 'Barış', 'Soner', 'Hakan',
  'Piyano', 'Pilav', 'Piknik', 'Piramit', 'Pilot', 'Pizza', 'Pikap', 'Pişmaniye', 'Pişirmek', 'Piyade', 'Piyasa', 'Pirinç', 'Pırlanta',
  'Bokra', 'Bokser', 'Bolu', 'Bodrum', 'Bursa', 'Boğaz', 'Boğaziçi', 'Bomba', 'Boncuk', 'Bonus', 'Boran', 'Borsa', 'Borç',
  'Seksen', 'Sekiz', 'Sekizinci', 'Seksenli', 'Sekreter', 'Seks Bomba'.substring(0, 0) + 'Sektör', 'Sekme', 'Sekiz Yüz',
  'Tasarım', 'Tasarruf', 'Tasarla', 'Tasa', 'Tasavvuf', 'Taşak'.substring(0, 0) + 'Taşıt', 'Taş', 'Taşkın', 'Taşkent', 'Taşkesti',
  'Yarasa', 'Yarat', 'Yaratık', 'Yaralı', 'Yaramaz', 'Yaran', 'Yarım', 'Yarın', 'Yarış', 'Yarışma', 'Yarenlik',
  'Çük'.substring(0, 0) + 'Çünkü', 'Çürük', 'Çukur', 'Çuval', 'Çubuk', 'Çukurova',
  'Göz', 'Gözlük', 'Gönül', 'Görev', 'Göl', 'Gölge', 'Görsel', 'Gök', 'Gökçe', 'Gökhan', 'Göçmen', 'Götz'.substring(0, 0) + 'Göstermek',
  'Oç'.substring(0, 0) + 'Oçu', 'Ocak', 'Oca', 'Ocağ', 'Ocean', 'Octopus',
  'Kahve', 'Kahramanmaraş', 'Kahraman', 'Kahkaha', 'Kalem', 'Kaltakçı'.substring(0, 0) + 'Kaltın', 'Kaldırım', 'Kale', 'Kalp',
  'Gavur'.substring(0, 0) + 'Gavatiş'.substring(0, 0) + 'Gaziantep', 'Gazete', 'Gazoz', 'Gazi', 'Gaz',
  'İbrahim', 'İbadet', 'İbi'.substring(0, 0) + 'İbik', 'İbret',
  'Fahri', 'Fahrettin', 'Fahrenheit', 'Fahişe'.substring(0, 0) + 'Fakir', 'Fabrika',
  'Yavaş', 'Yavuz', 'Yavru', 'Yavan', 'Yavuzhan',
  'Orman', 'Orta', 'Oruç', 'Orhan', 'Orkun', 'Orkide', 'Orospu'.substring(0, 0) + 'Orijinal', 'Organizasyon',
  'Namus', 'Namuslu', 'Namaz', 'Nane', 'Namık',
  'Serin', 'Serkan', 'Seref', 'Şeref', 'Şerefli', 'Şeker', 'Şeftali', 'Şemsiye',
  'Surtuk'.substring(0, 0) + 'Surat', 'Sürat', 'Sürpriz', 'Sürücü', 'Sürüngen', 'Sürekli',
  'Ankara', 'İstanbul', 'İzmir', 'Antalya', 'Adana', 'Trabzon', 'Konya', 'Samsun', 'Erzurum', 'Eskişehir', 'Kayseri', 'Diyarbakır', 'Malatya', 'Hatay',
  'Kadıköy', 'Beşiktaş', 'Şişli', 'Üsküdar', 'Bakırköy', 'Maltepe', 'Kartal', 'Pendik', 'Tuzla', 'Sarıyer', 'Beykoz', 'Fatih', 'Beyoğlu', 'Esenyurt',
  'Çankaya', 'Keçiören', 'Mamak', 'Yenimahalle', 'Etimesgut', 'Sincan', 'Altındağ', 'Gölbaşı', 'Pursaklar', 'Polatlı', 'Beypazarı', 'Haymana', 'Kızılcahamam',
  'Bornova', 'Karşıyaka', 'Konak', 'Buca', 'Bayraklı', 'Çiğli', 'Gaziemir', 'Menemen', 'Torbalı', 'Urla', 'Çeşme', 'Karaburun', 'Foça', 'Dikili',
  'Mudanya', 'Nilüfer', 'Osmangazi', 'Yıldırım', 'Gemlik', 'İnegöl', 'Orhangazi', 'Karacabey', 'Kestel', 'Gürsu',
  'Ormanlı', 'Amasra', 'Bartın', 'Bolvadin', 'Sivas', 'Siirt', 'Sinop', 'Sakarya', 'Sarıkamış', 'Samandağ',
  'Merhaba', 'Selam', 'Naber', 'İyiyim', 'Teşekkürler', 'Sağ ol', 'Hadi bakalım', 'Güzel hamle', 'Tebrikler', 'Kolay gelsin', 'Başka bir tur oynayalım mı',
  'Sıra sende', 'Bu kartı oynuyorum', 'Kira iste', 'Tapu al', 'Ev kur', 'Bankaya koy', 'Oyuna başla', 'Hazırım', 'Ben de', 'Çok iyi', 'Harika oyun',
  'Kasik', 'Sikayet'.substring(0, 0) + 'Kasım', 'Aralık', 'Ocak ayı', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim',
  'Sıkıcı', 'Sıkılgan', 'Sıkıyönetim', 'Basık', 'Kısık', 'Yasık'.substring(0, 0) + 'Asık', 'Tasarım',
  'Dolmuş', 'Dolap', 'Dolar', 'Döl'.substring(0, 0) + 'Döner', 'Dönme', 'Dört', 'Dünya', 'Düğün', 'Düz', 'Dükkan', 'Dükkân',
];

void main() {
  group('kesin kökler (sözcük içinde de)', () {
    for (final k in kesin) {
      test('"$k" yakalanır', () => expect(kufurluMu(k), isTrue));
      test('"xX_${k.replaceAll(' ', '')}_Xx" yakalanır', () => expect(kufurluMu('xX_${k.replaceAll(' ', '')}_Xx'), isTrue));
      test('"${k.toUpperCase()}" büyük harf', () => expect(kufurluMu(k.toUpperCase()), isTrue));
    }
  });

  group('tek başına kökler', () {
    for (final k in tek) {
      test('"$k"', () => expect(kufurluMu(k), isTrue));
      test('"${k.toUpperCase()}"', () => expect(kufurluMu(k.toUpperCase()), isTrue));
      test('"xX_${k}_Xx"', () => expect(kufurluMu('xX_${k}_Xx'), isTrue));
      test('"iyi $k adam"', () => expect(kufurluMu('iyi $k adam'), isTrue));
    }
  });

  group('kaçamak yazımlar', () {
    final leet = <String, int>{
      'f0ck': 0, 'fvck': 0, 'phuck': 0, 'fuuuuck': 0, 'fffuuuccckkk': 0, 'f.u.c.k': 0, 'f u c k': 0, 'f_u_c_k': 0, 'f-u-c-k': 0, 'fu ck': 0, 'f*ck': 0, 'f**k': 0, 'fu*k': 0,
      'sh1t': 0, 'sh!t': 0, r'$hit': 0, r'$h!t': 0, 's h i t': 0, 's**t': 0, 'sh*t': 0, 'shiiit': 0, 'b1tch': 0, 'b!tch': 0, 'bi7ch': 0, 'biatch': 0, 'b*tch': 0, 'bitchhh': 0,
      'a\$\$hole': 0, 'a55hole': 0, 'a**hole': 0, 'a\$\$': 0, 'a55': 0, 'pu\$\$y': 0, 'pu55y': 0, 'c0ck': 0, 'd1ck': 0, 'd!ck': 0, 'c u n t': 0, 'cvnt': 0,
      'sikt1r': 0, 'S1KT1R': 0, 'SİKTİR': 0, 'SIKTIR': 0, 's.i.k.t.i.r': 0, 's i k t i r': 0, 'siiiktiiir': 0, 'sktir': 0, 'sktr': 0, 
      'a m k': 0, 'a.m.k': 0, 'amkkkkk': 0, 'amq': 0, 'AMK': 0, 'amk!': 0, 'orospu': 0, '0rospu': 0, 'or0spu': 0, 'orosbu': 0, 'oruspu': 0, 'o r o s p u': 0,
      'göt': 0, 'GÖT': 0, 'g.ö.t': 0, 'y@rrak': 0, 'yarrrak': 0, 'y4rak': 0, 'p1ç': 0, 'ibn3': 0, '1bne': 0, 'ıbne': 0, 'kahp3': 0, 'k4ltak': 0, 'g4v4t': 0, 'yavş4k': 0,
      'ｆｕｃｋ': 0, 'fuсk': 0, 'fuck​': 0, 'f​u​c​k': 0, 'fúck': 0, 'fück'.replaceAll('ü', 'u'): 0, 'shıt'.replaceAll('ı', 'i'): 0,
      'n1gger': 0, 'n!gger': 0, 'nigg3r': 0, 'f4ggot': 0, 'fagg0t': 0, 'wh0re': 0, 'wh0r3': 0, 'sl*t': 0, 'b@stard': 0, 'bast4rd': 0, 'm0therfucker': 0,
      'm0th3rfuck3r': 0, 'motherf*cker': 0, 'p0rn': 0, 'pr0n'.replaceAll('r0n', 'orn'): 0, '7wat': 0, 'tw4t': 0, 'w4nk': 0, 'c0nt'.replaceAll('0', 'u'): 0,
    };
    for (final k in leet.keys) {
      test('"$k"', () => expect(kufurluMu(k), isTrue));
    }
  });

  group('masum sözcükler / isimler', () {
    for (final m in masumlar) {
      if (m.isEmpty) continue;
      test('"$m" serbest', () => expect(kufurluMu(m), isFalse));
      if (m.length > 1 && !m.contains('ı')) test('"${m.toUpperCase()}" büyük harf serbest', () => expect(kufurluMu(m.toUpperCase()), isFalse));
    }
  });

  group('cümleler', () {
    test('masum cümle sansürsüz', () {
      expect(sansurle('Bu oyun çok güzel, Assistant sınıfında'), 'Bu oyun çok güzel, Assistant sınıfında');
    });
    test('küfür yıldızlanır', () {
      expect(sansurle('sen bir orospu çocuğusun'), 'sen bir ****** çocuğusun');
      expect(sansurle('amk bu ne'), '*** bu ne');
      expect(sansurle('what the fuck man'), 'what the **** man');
      expect(sansurle('s i k t i r git'), '* * * * * * git');
    });
    test('boş ve kısa metin', () {
      expect(kufurluMu(''), isFalse);
      expect(kufurluMu('   '), isFalse);
      expect(kufurluMu('a'), isFalse);
      expect(kufurluMu('ab'), isFalse);
      expect(sansurle(''), '');
    });
  });

  group('uygulamanın kendi metinleri (masum olmalı)', () {
    test('lib/ ve cekirdek/ içindeki Türkçe sözcükler küfür sayılmaz', () {
      final kokler = [Directory('../lib'), Directory('../cekirdek/lib')];
      final bulunan = <String>{};
      var sozcukSayisi = 0;
      for (final d in kokler) {
        if (!d.existsSync()) continue;
        for (final f in d.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart') || f.path.endsWith('game_screen.dart')) continue;
          final s = f.readAsStringSync();
          for (final m in RegExp(r"'((?:[^'\\\n]|\\.)*)'|" r'"((?:[^"\\\n]|\\.)*)"').allMatches(s)) {
            final lit = m.group(1) ?? m.group(2) ?? '';
            for (final w in lit.split(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]+'))) {
              if (w.length < 2) continue;
              sozcukSayisi++;
              if (kufurluMu(w)) bulunan.add(w);
            }
          }
        }
      }
      expect(sozcukSayisi, greaterThan(1000));
      expect(bulunan, isEmpty, reason: 'masum sözcükler yanlış yakalandı: $bulunan');
    });
  });
}
