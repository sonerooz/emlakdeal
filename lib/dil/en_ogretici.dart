// Etkilesimli ogretici demolarinin metinleri (Turkce -> Ingilizce).
const Map<String, String> enOgretici = {
  'Her tur 2 kart çek (elin boşsa 5). En fazla 3 hamle yaparsın; 3. hamlede tur kendiliğinden biter. Tapu ya da para kartına bir kez dokun: tapu sete, para bankaya gider. Kira ve ev kartlarına dokununca oyun en uygun yeri kendisi seçer; oynayacak yer yoksa kart para olarak bankaya girer. Tur sonunda elinde en fazla 7 kart kalabilir.':
      'Draw 2 cards each turn (5 if your hand is empty). You make up to 3 moves; the turn ends by itself after the 3rd. Tap a property or money card once: properties go to a set, money goes to the bank. When you tap rent and house cards the game picks the best target itself; if there is nowhere to play the card, it goes to the bank as money. You may keep at most 7 cards at the end of your turn.',
  'Tapu Devri: tam olmayan setten bir tapu al. Takas Pazarlığı: tapu takas et (tam setler hariç). Haciz: rakibin TAM setini ev/rezidansıyla birlikte al. İcra Takibi: seçtiğin birinden 5M. Her biri 1 hamle harcar. Şimdi hepsini tek tek deneyelim.':
      'Deed Transfer: take a property from an incomplete set. Swap Meet: swap properties (complete sets excluded). Seizure: take a rival COMPLETE set together with its houses/hotels. Pay Up: 5M from anyone you choose. Each uses 1 move. Now let us try them one by one.',
  'Ev (+3M) ve Rezidans (+4M) sadece TAM setlere konur. Her sete bir Ev konur; Rezidans için önce Ev gerekir. Ulaşım ve Altyapı setlerine konmaz. Set bozulursa ev ve rezidans para olarak bankana döner.':
      'Houses (+3M) and Hotels (+4M) can only go on COMPLETE sets. One House per set; a Hotel needs a House first. Not allowed on Railroad and Utility sets. If a set breaks, its houses and hotels return to your bank as cash.',
  'Joker Tapu istediğin renkte sayılır; iki renkli jokerler yalnızca üstlerindeki iki renkten biri olur. Kendi turunda masadaki jokere dokunup rengini değiştirebilirsin; seti tamamlamanın en kolay yolu budur. Çok renkli Joker Tapu para değeri taşımaz, ödemede verilemez. Şimdi jokerle set tamamlamayı dene.':
      'A Wild Property counts as any color you like; two-color wilds can only be one of the two colors printed on them. On your turn, tap a wild on the table to change its color; this is the easiest way to complete a set. The multi-color Wild Property has no cash value and cannot be given as payment. Now try completing a set with a wild.',
  'Geri': 'Back',
  'Görevi tamamla': 'Finish the task',
  'Bu demoyu atla': 'Skip this demo',
  'boş': 'empty',
  'Elin': 'Your hand',
  'Masan': 'Your table',
  '🤖 Rakip': '🤖 Rival',
  '🤖 Rakipler': '🤖 Rivals',
  'Tapu setleri': 'Property sets',
  'Tapu kartlarına dokunarak masana koy. Aynı renkteki tapular bir sette toplanır; sette kaç tapu gerektiği başlıkta yazar (ör. 0/2). Tüm kartları koy.':
      'Tap the property cards to place them on your table. Properties of the same color form a set; the title shows how many are needed (e.g. 0/2). Place all the cards.',
  'Harika! İki set de tamam. Oyunu, FARKLI renkte 3 tam set toplayan kazanır.':
      'Great! Both sets are complete. Whoever collects 3 complete sets of DIFFERENT colors wins.',
  '{renk} seti tamamlandı! Set boyu (2, 3 ya da 4) kartın üstünde yazar.':
      'The {renk} set is complete! The set size (2, 3 or 4) is printed on the card.',
  'Joker {renk} oldu ve set tamamlandı! Oyunda da kendi turunda masadaki jokere dokunup rengini değiştirebilirsin.':
      'The wild became {renk} and the set is complete! In a real game you can also tap a wild on the table on your turn to change its color.',
  '{a} bu seti tamamlamıyor. {b} setin 2/{n}: jokeri {b} yap.':
      '{a} does not complete this set. Your {b} set is 2/{n}: make the wild {b}.',
  'Joker tapu (her renk)': 'Wild property (any color)',
  'İki renkli joker': 'Two-color wild',
  'Joker Tapu istediğin renkte sayılır. {h} setin 2/{n} ama joker şu an {b} sette duruyor. Jokere dokun, rengini {h} yap ve seti tamamla.':
      'A Wild Property counts as any color you like. Your {h} set is 2/{n} but the wild currently sits in the {b} set. Tap the wild, change its color to {h} and complete the set.',
  'İki renkli joker yalnızca üstünde yazan iki renkten biri olur. {h} setin 2/{n}, joker şu an {b}. Jokere dokun, rengini {h} yap.':
      'A two-color wild can only be one of the two colors printed on it. Your {h} set is 2/{n}, the wild is currently {b}. Tap the wild and change its color to {h}.',
  '👆 Jokere dokun': '👆 Tap the wild',
  'Kira kartı': 'Rent card',
  'Kira kartını oynamak için o renklerden birinde tapun olmalı. Elindeki kira kartına dokun: oyun en yüksek kirayı veren rengi kendisi seçer.':
      'To play a rent card you need a property in one of its colors. Tap the rent card in your hand: the game picks the color with the highest rent by itself.',
  'Kira kartı oynandı: {n} Yeşil tapun var, kira {k}M. HERKES sana {k}M öder. Tapu sayın ve ev/rezidans kirayı artırır; Zam Geldi kartı kirayı 2 katına çıkarır (2 hamle harcar).':
      'Rent card played: you own {n} Green properties, so the rent is {k}M. EVERYONE pays you {k}M. More properties and houses/hotels raise the rent; a Rent Hike card doubles it (uses 2 moves).',
  'Tapu Devri': 'Deed Transfer',
  'Önce Tapu Devri kartına dokun, sonra rakibin bir tapusuna dokun. Kural: sadece tamamlanmamış setten tapu alınır.':
      "First tap the Deed Transfer card, then tap one of the rival's properties. Rule: you can only take a property from an incomplete set.",
  'Önce elindeki Tapu Devri kartına dokun.': 'First tap the Deed Transfer card in your hand.',
  'Kahverengi set TAM, tam setteki tapu çalınamaz. Tamamlanmamış sete dokun. (Tam seti almak için Haciz gerekir.)':
      'The Brown set is COMPLETE; properties in a complete set cannot be stolen. Tap the incomplete set. (Taking a complete set needs Seizure.)',
  'Tapuyu çaldın! Tapu Devri yalnızca rakibin TAMAMLANMAMIŞ setindeki tapuyu alır.':
      "You stole the property! Deed Transfer only takes a property from a rival's INCOMPLETE set.",
  'Şimdi rakibin bir tapusuna dokun.': "Now tap one of the rival's properties.",
  'Takas Pazarlığı': 'Swap Meet',
  'Kartına dokun, sonra rakibin tamamlanmamış setinden (Kırmızı) bir tapu seç, sonra kendi tamamlanmamış setinden (Sarı) bir tapu seç. Tam setler (Açık Mavi 🔒) takas edilemez.':
      "Tap the card, then pick a property from the rival's incomplete set (Red), then one from your own incomplete set (Yellow). Complete sets (Light Blue 🔒) cannot be swapped.",
  'Önce rakipten almak istediğin tapuya dokun (Kırmızı).': 'First tap the property you want from the rival (Red).',
  'Şimdi rakibin almak istediğin tapusuna dokun (Kırmızı).': 'Now tap the rival property you want (Red).',
  'Önce elindeki Takas Pazarlığı kartına dokun.': 'First tap the Swap Meet card in your hand.',
  'Tam setindeki tapuyu veremezsin. Tamamlanmamış setinden bir tapu seç (Sarı).':
      'You cannot give a property from a complete set. Pick one from your incomplete set (Yellow).',
  'Şimdi rakipten almak istediğin tapuya dokun.': 'Now tap the property you want from the rival.',
  'Önce kendi tamamlanmamış setinden vereceğin tapuya dokun (Sarı).':
      'First tap the property you will give from your own incomplete set (Yellow).',
  'Takas tamam! İki taraftan da tamamlanmamış setlerden birer tapu değişir; tam setler takas edilemez.':
      "Swap done! One property from each side's incomplete sets changes hands; complete sets cannot be swapped.",
  'Şimdi kendi tamamlanmamış setinden vereceğin tapuya dokun (Sarı).':
      'Now tap the property you will give from your own incomplete set (Yellow).',
  'Haciz': 'Seizure',
  'Haciz kartına dokun, sonra rakibin TAM setine dokun. Tek tapu değil, seti komple alırsın.':
      "Tap the Seizure card, then tap the rival's COMPLETE set. You take the whole set, not a single property.",
  'Önce elindeki Haciz kartına dokun.': 'First tap the Seizure card in your hand.',
  'Haciz yalnızca TAM seti alır. Mor set 1/3, tam olan Açık Mavi sete dokun.':
      'Seizure only takes a COMPLETE set. The Purple set is 1/3; tap the complete Light Blue set.',
  'Tüm seti aldın! Haciz, rakibin tamamlanmış setini (üstündeki ev/rezidansla birlikte) komple alır. Güçlü bir karttır, rakip Reddet ile karşılık verebilir.':
      "You took the whole set! Seizure takes a rival's complete set (with its houses/hotels). It is powerful, but the rival can answer with Reject.",
  'Şimdi rakibin tam setine dokun.': "Now tap the rival's complete set.",
  'Reddet': 'Reject',
  'Rakip sana saldırınca Reddet kartıyla hamleyi iptal edebilirsin. Rakip sana Haciz oynadı ve Yeşil setini istiyor! Reddet kartına dokun.':
      'When a rival attacks you, you can cancel the move with a Reject card. The rival played Seizure on you and wants your Green set! Tap a Reject card.',
  '🤖 Rakip Haciz oynadı: Yeşil setini istiyor!': '🤖 The rival played Seizure: they want your Green set!',
  '🤖 Rakip Reddet ile karşılık verdi: Haciz yeniden geçerli!': '🤖 The rival answered with Reject: Seizure is back on!',
  '✋ Reddet oynadın: Haciz iptal! Ama rakip de elindeki Reddet ile karşılık verdi: Haciz yeniden geçerli. Sen de bir kez daha Reddet oynayabilirsin.':
      '✋ You played Reject: Seizure cancelled! But the rival answered with their own Reject: Seizure is back on. You can play another Reject.',
  'Sen de Reddet oynadın ve zinciri kazandın. Haciz kesin iptal! Reddet hamle harcamaz; elinde varsa her saldırıda kullanabilirsin.':
      'You played Reject again and won the chain. Seizure is cancelled for good! Reject uses no move; you can use it on every attack if you hold one.',
  'Setini kaybettin! Elinde Reddet varken kabul etme. Tekrar deneniyor…':
      'You lost your set! Do not accept while you hold a Reject. Trying again…',
  'Kabul et (setimi ver)': 'Accept (give my set)',
  'Ev ve Rezidans': 'House and Hotel',
  'Ev ve Rezidans kartları setin ÜSTÜNE konur. Elindeki Ev kartına dokun: set tamam olduğu için kart setin üstüne oturur ve kira artar. Sonra Rezidansı koy; Rezidans için Ev şart. Önce Rezidans kartına dokunmayı dene, sonra doğru sırayla koy.':
      'House and Hotel cards go ON TOP of the set. Tap the House card in your hand: because the set is complete it sits on top of the set and the rent rises. Then place the Hotel; a Hotel needs a House first. Try tapping the Hotel first, then place them in the right order.',
  'Rezidans buraya': 'Hotel here',
  'Ev buraya': 'House here',
  'Rezidans için önce sete bir Ev koymalısın.': 'You must place a House on the set before a Hotel.',
  'Kırmızı set artık {k}M kira getiriyor! Ev ve Rezidans yalnızca TAM setlere konur (Ulaşım ve Altyapı hariç).':
      'The Red set now earns {k}M rent! Houses and Hotels only go on COMPLETE sets (not Railroad or Utility).',
  'Ev kondu, kira {k}M oldu (+3M). Şimdi Rezidansı koy.': 'House placed, rent is now {k}M (+3M). Now place the Hotel.',
  'Kira': 'Rent',
  'Giriş yap, ödülleri topla': 'Sign in to collect rewards',
  '{n} ödül seni bekliyor': '{n} reward(s) waiting for you',
  'XP ve altın kazan': 'Earn XP and gold',
};
