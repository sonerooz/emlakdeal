// Herkese açık yasal sayfalar: gizlilik politikası, hesap silme rehberi, kullanım koşulları.
// Üretim: GET /gizlilik, /hesap-sil, /kosullar (?dil=en ya da Accept-Language: en*).
import 'dart:io';

const sonGuncelleme = '2026-10-04';

String destekEposta() {
  final e = Platform.environment['DESTEK_EPOSTA']?.trim();
  if (e != null && e.isNotEmpty) return e;
  return 'DESTEK_EPOSTA_AYARLANMADI';
}

String _h(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Dil seçimi: ?dil=en | tr; yoksa Accept-Language; varsayılan Türkçe.
bool ingilizceMi(HttpRequest req) {
  final d = req.uri.queryParameters['dil']?.toLowerCase();
  if (d != null && d.isNotEmpty) return d.startsWith('en');
  final a = (req.headers.value('accept-language') ?? '').toLowerCase().trim();
  return a.startsWith('en');
}

String _sayfa({required bool en, required String baslik, required String yol, required String govde}) {
  final diger = en ? 'Türkçe' : 'English';
  final digerDil = en ? 'tr' : 'en';
  return '''<!doctype html>
<html lang="${en ? 'en' : 'tr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_h(baslik)} - Emlak Deal</title>
<style>
:root{--bg:#f6f4ee;--kart:#fff;--yazi:#1d2b24;--soluk:#5b6b62;--vurgu:#1f6b4a;--cizgi:#dcd8cc}
@media (prefers-color-scheme:dark){:root{--bg:#14201a;--kart:#1c2b23;--yazi:#e8eee9;--soluk:#a2b3a9;--vurgu:#6fcf9f;--cizgi:#2f4237}}
body{margin:0;background:var(--bg);color:var(--yazi);font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 18px 60px}
.kart{background:var(--kart);border:1px solid var(--cizgi);border-radius:14px;padding:22px 22px 8px}
h1{font-size:1.7rem;margin:.2em 0 .1em}
h2{font-size:1.15rem;margin:1.6em 0 .4em;color:var(--vurgu)}
p,li{color:var(--yazi)}
.soluk{color:var(--soluk);font-size:.9rem}
a{color:var(--vurgu)}
ul{padding-left:1.2em}
.dil{float:right;font-size:.9rem}
table{border-collapse:collapse;width:100%;font-size:.93rem;margin:.6em 0 1em;display:block;overflow-x:auto}
th,td{border:1px solid var(--cizgi);padding:6px 9px;text-align:left;vertical-align:top}
th{background:rgba(127,127,127,.12)}
code{background:rgba(127,127,127,.15);padding:1px 5px;border-radius:5px}
</style>
</head>
<body>
<main>
<div class="kart">
<a class="dil" href="/$yol?dil=$digerDil">$diger</a>
$govde
</div>
</main>
</body>
</html>''';
}

String gizlilikSayfasi({required bool en}) {
  final m = _h(destekEposta());
  if (en) {
    return _sayfa(en: true, baslik: 'Privacy Policy', yol: 'gizlilik', govde: '''
<h1>Privacy Policy</h1>
<p class="soluk">Emlak Deal &middot; Last updated: $sonGuncelleme</p>
<p>Emlak Deal is a card game you can play against bots or online with friends. This page explains what data the game collects, why, how long we keep it and how you can delete it. If you have questions, contact us at <a href="mailto:$m">$m</a>.</p>

<h2>1. Data we collect</h2>
<table>
<tr><th>Data</th><th>Why</th></tr>
<tr><td>Nickname and avatar</td><td>Shown to other players, on leaderboards and in friend lists.</td></tr>
<tr><td>Random device key (generated on your device; not your advertising ID or hardware ID)</td><td>Lets a guest account continue on the same device without signing up.</td></tr>
<tr><td>Email address and password (only if you sign up with email; the password is stored as a salted hash)</td><td>Signing in to your account.</td></tr>
<tr><td>Facebook or Google account ID and the first name offered by the provider (only if you sign in with them)</td><td>Signing in and suggesting a first nickname. We do not receive your password, friends list or contacts.</td></tr>
<tr><td>Game statistics, level, XP, in-game gold, achievements, match history, items you own, daily reward progress</td><td>Running the game, progression and leaderboards. Items are bought with in-game gold only; there are no real-money purchases.</td></tr>
<tr><td>Friends list, block list, reports you send</td><td>Social features and keeping the community safe.</td></tr>
<tr><td>Error reports (app version, device model, OS version, language, error message and technical trace) and anonymous usage and performance events</td><td>Finding and fixing crashes and slowdowns. Tokens, passwords and email addresses are removed from reports on the device before sending.</td></tr>
<tr><td>IP address and request time (server logs)</td><td>Security, abuse prevention and operating the service.</td></tr>
</table>
<p>The game currently shows no advertising and does not use advertising or cross-app tracking identifiers. In-game chat messages are filtered for offensive words and are not stored permanently.</p>

<h2>2. Children</h2>
<p>Emlak Deal is not directed to children under 13, and we do not knowingly collect personal data from them. If you believe a child has created an account, write to us and we will delete it.</p>

<h2>3. Sharing</h2>
<p>We do not sell your data. Other players can see your nickname, avatar, level and online status. We use these service providers only as needed: Google and Facebook (if you choose to sign in with them) and our hosting and network provider (server infrastructure and secure access via Tailscale). We may disclose data if required by law.</p>

<h2>4. Retention</h2>
<ul>
<li>Account data is kept until you delete your account.</li>
<li>Guest accounts that are inactive for a long time may be removed.</li>
<li>Error reports and usage events are kept for a limited time (up to about 12 months) and are not linked to your identity after account deletion.</li>
<li>Server logs containing IP addresses are rotated and kept for a short period.</li>
<li>Reports about other players are kept for moderation; after you delete your account, personal fields in them are anonymised.</li>
</ul>

<h2>5. Your rights and deleting your data</h2>
<p>You can delete your account and all linked data at any time inside the game: <b>Profile &rarr; Delete account</b>. You can also follow the steps on the <a href="/hesap-sil?dil=en">account deletion page</a> or email us. Deletion is permanent and removes your profile, sign-in IDs, email, friends, blocks, purchases, achievements, match history and leaderboard entry. Depending on your country you may also have rights to access, correct or export your data; write to us and we will respond.</p>

<h2>6. Security</h2>
<p>Connections use HTTPS/TLS. Passwords are stored only as salted hashes and sign-in tokens can be revoked by signing out. No system is perfectly secure, but we take reasonable measures to protect your data.</p>

<h2>7. Changes</h2>
<p>If we change this policy we will update the date above. Material changes will be announced in the game.</p>

<h2>8. Contact</h2>
<p><a href="mailto:$m">$m</a></p>
''');
  }
  return _sayfa(en: false, baslik: 'Gizlilik Politikası', yol: 'gizlilik', govde: '''
<h1>Gizlilik Politikası</h1>
<p class="soluk">Emlak Deal &middot; Son güncelleme: $sonGuncelleme</p>
<p>Emlak Deal, botlara karşı ya da arkadaşlarınla çevrim içi oynayabileceğin bir kart oyunudur. Bu sayfa oyunun hangi verileri neden topladığını, ne kadar sakladığını ve bunları nasıl silebileceğini anlatır. Sorular için: <a href="mailto:$m">$m</a>.</p>

<h2>1. Topladığımız veriler</h2>
<table>
<tr><th>Veri</th><th>Amaç</th></tr>
<tr><td>Takma ad (nickname) ve avatar</td><td>Diğer oyunculara, liderlik tablosunda ve arkadaş listesinde gösterilir.</td></tr>
<tr><td>Cihazda üretilen rastgele cihaz anahtarı (reklam kimliği ya da donanım kimliği değildir)</td><td>Misafir hesabın kayıt olmadan aynı cihazda devam etmesi.</td></tr>
<tr><td>E-posta adresi ve parola (yalnız e-posta ile kayıt olursan; parola tuzlu özet olarak saklanır)</td><td>Hesabına giriş.</td></tr>
<tr><td>Facebook ya da Google hesap kimliği ve sağlayıcının verdiği ilk ad (yalnız onlarla giriş yaparsan)</td><td>Giriş ve ilk takma ad önerisi. Parolanı, arkadaş listeni ya da rehberini almayız.</td></tr>
<tr><td>Oyun istatistikleri, seviye, XP, oyun içi altın, başarımlar, maç geçmişi, sahip olunan eşyalar, günlük ödül ilerlemesi</td><td>Oyunun işleyişi, ilerleme ve liderlik tabloları. Eşyalar yalnız oyun içi altınla alınır; gerçek parayla satın alma yoktur.</td></tr>
<tr><td>Arkadaş listesi, engel listesi, gönderdiğin şikayetler</td><td>Sosyal özellikler ve topluluğun güvenliği.</td></tr>
<tr><td>Hata raporları (uygulama sürümü, cihaz modeli, işletim sistemi sürümü, dil, hata mesajı ve teknik iz) ile anonim kullanım ve performans olayları</td><td>Çökme ve yavaşlamaları bulup düzeltmek. Jeton, parola ve e-posta gibi bilgiler rapor gönderilmeden önce cihazda silinir.</td></tr>
<tr><td>IP adresi ve istek zamanı (sunucu günlükleri)</td><td>Güvenlik, kötüye kullanımın önlenmesi ve hizmetin işletilmesi.</td></tr>
</table>
<p>Oyun şu an reklam göstermez; reklam kimliği ya da uygulamalar arası takip tanımlayıcısı kullanmaz. Oyun içi sohbet mesajları uygunsuz sözcükler için süzülür ve kalıcı olarak saklanmaz.</p>

<h2>2. Çocuklar</h2>
<p>Emlak Deal 13 yaşından küçük çocuklara yönelik değildir ve bu yaştaki çocuklardan bilerek kişisel veri toplamayız. Bir çocuğun hesap açtığını düşünüyorsan bize yaz, hesabı sileriz.</p>

<h2>3. Paylaşım</h2>
<p>Verilerini satmayız. Diğer oyuncular takma adını, avatarını, seviyeni ve çevrim içi durumunu görebilir. Hizmet sağlayıcıları yalnız gerektiği kadar kullanırız: Google ve Facebook (onlarla giriş yapmayı seçersen) ile barındırma ve ağ sağlayıcımız (sunucu altyapısı ve Tailscale üzerinden güvenli erişim). Yasal zorunluluk halinde veriler yetkili makamlarla paylaşılabilir.</p>

<h2>4. Saklama süresi</h2>
<ul>
<li>Hesap verileri, hesabını silene kadar saklanır.</li>
<li>Uzun süre kullanılmayan misafir hesaplar silinebilir.</li>
<li>Hata raporları ve kullanım olayları sınırlı süre (en çok yaklaşık 12 ay) saklanır; hesap silindikten sonra kimliğinle ilişkilendirilmez.</li>
<li>IP adresi içeren sunucu günlükleri döndürülür ve kısa süre saklanır.</li>
<li>Diğer oyunculara ilişkin şikayetler moderasyon için saklanır; hesabını silersen içlerindeki kişisel alanlar anonimleştirilir.</li>
</ul>

<h2>5. Haklarının kullanımı ve verilerini silme</h2>
<p>Hesabını ve bağlı tüm verileri istediğin zaman oyun içinden silebilirsin: <b>Profil &rarr; Hesabı sil</b>. <a href="/hesap-sil">Hesap silme sayfasındaki</a> adımları izleyebilir ya da bize e-posta yazabilirsin. Silme kalıcıdır; profilin, giriş kimliklerin, e-postan, arkadaşların, engellerin, satın alımların, başarımların, maç geçmişin ve liderlik kaydın kaldırılır. Bulunduğun ülkeye göre verilerine erişme, düzeltme ve dışa aktarma haklarına da sahip olabilirsin; bize yaz, yanıtlarız.</p>

<h2>6. Güvenlik</h2>
<p>Bağlantılar HTTPS/TLS ile korunur. Parolalar yalnız tuzlu özet olarak saklanır; çıkış yaparak oturum anahtarını iptal edebilirsin. Hiçbir sistem tamamen güvenli değildir, ancak verilerini korumak için makul önlemler alırız.</p>

<h2>7. Değişiklikler</h2>
<p>Politikayı değiştirirsek yukarıdaki tarihi güncelleriz. Önemli değişiklikler oyunda duyurulur.</p>

<h2>8. İletişim</h2>
<p><a href="mailto:$m">$m</a></p>
''');
}

String hesapSilSayfasi({required bool en}) {
  final m = _h(destekEposta());
  if (en) {
    return _sayfa(en: true, baslik: 'Delete your account', yol: 'hesap-sil', govde: '''
<h1>Delete your account</h1>
<p class="soluk">Emlak Deal &middot; Last updated: $sonGuncelleme</p>
<h2>Inside the game (fastest)</h2>
<ol>
<li>Open Emlak Deal and go to <b>Profile</b>.</li>
<li>Tap <b>Delete account</b>.</li>
<li>Type <code>SIL</code> to confirm (and your password if your account has one).</li>
</ol>
<p>Your account is deleted immediately.</p>
<h2>If you cannot open the game</h2>
<p>Email <a href="mailto:$m">$m</a> from the address linked to your account (or tell us your nickname and sign-in method). We will delete the account and reply when it is done, normally within 30 days.</p>
<h2>Facebook sign-in</h2>
<p>If you signed in with Facebook, you can also remove Emlak Deal in Facebook &rarr; Settings &rarr; Apps and Websites &rarr; Remove. Facebook then sends us a deletion request and we delete your game account automatically; you can check the result with the confirmation code Facebook shows.</p>
<h2>What is deleted</h2>
<ul>
<li>Profile: nickname, avatar, level, XP, gold, statistics, daily reward progress</li>
<li>Sign-in data: email, password hash, Facebook/Google/Apple IDs, device key, sessions</li>
<li>Friends, block list, purchases and owned items, achievements, match history, leaderboard entry</li>
</ul>
<h2>What we keep</h2>
<ul>
<li>Reports about player behaviour are kept for moderation, with personal fields (your ID and notes) removed.</li>
<li>Error and usage logs are kept without any link to your identity.</li>
<li>Server logs with IP addresses are rotated and removed after a short period.</li>
</ul>
<p>Deletion cannot be undone. After deleting, you can start over with a new guest account on the same device. See also the <a href="/gizlilik?dil=en">Privacy Policy</a>.</p>
''');
  }
  return _sayfa(en: false, baslik: 'Hesabını sil', yol: 'hesap-sil', govde: '''
<h1>Hesabını sil</h1>
<p class="soluk">Emlak Deal &middot; Son güncelleme: $sonGuncelleme</p>
<h2>Oyunun içinden (en hızlısı)</h2>
<ol>
<li>Emlak Deal'ı aç ve <b>Profil</b>'e git.</li>
<li><b>Hesabı sil</b>'e dokun.</li>
<li>Onaylamak için <code>SIL</code> yaz (hesabında parola varsa parolanı da gir).</li>
</ol>
<p>Hesabın hemen silinir.</p>
<h2>Oyunu açamıyorsan</h2>
<p><a href="mailto:$m">$m</a> adresine, hesabına bağlı e-posta adresinden (ya da takma adını ve giriş yöntemini belirterek) yaz. Hesabı sileriz ve işlem bitince yanıtlarız; genellikle 30 gün içinde.</p>
<h2>Facebook ile giriş</h2>
<p>Facebook ile giriş yaptıysan Facebook &rarr; Ayarlar &rarr; Uygulamalar ve Web Siteleri &rarr; Kaldır yoluyla da Emlak Deal'ı kaldırabilirsin. Facebook bize silme isteği gönderir, oyun hesabın otomatik silinir; Facebook'un gösterdiği onay koduyla sonucu görebilirsin.</p>
<h2>Neler silinir</h2>
<ul>
<li>Profil: takma ad, avatar, seviye, XP, altın, istatistikler, günlük ödül ilerlemesi</li>
<li>Giriş verileri: e-posta, parola özeti, Facebook/Google/Apple kimlikleri, cihaz anahtarı, oturumlar</li>
<li>Arkadaşlar, engel listesi, satın alımlar ve sahip olunan eşyalar, başarımlar, maç geçmişi, liderlik kaydı</li>
</ul>
<h2>Neler saklanır</h2>
<ul>
<li>Oyuncu davranışına ilişkin şikayetler moderasyon için saklanır; kişisel alanlar (kimliğin ve notlar) çıkarılır.</li>
<li>Hata ve kullanım günlükleri kimliğinle ilişkisi olmadan saklanır.</li>
<li>IP adresi içeren sunucu günlükleri döndürülür ve kısa süre sonra silinir.</li>
</ul>
<p>Silme geri alınamaz. Sildikten sonra aynı cihazda yeni bir misafir hesapla baştan başlayabilirsin. Ayrıca <a href="/gizlilik">Gizlilik Politikası</a>'na bak.</p>
''');
}

String kosullarSayfasi({required bool en}) {
  final m = _h(destekEposta());
  if (en) {
    return _sayfa(en: true, baslik: 'Terms of Use', yol: 'kosullar', govde: '''
<h1>Terms of Use</h1>
<p class="soluk">Emlak Deal &middot; Last updated: $sonGuncelleme</p>
<p>By using Emlak Deal you agree to these terms.</p>
<h2>1. Use of the game</h2>
<p>The game is provided for entertainment, free of charge and "as is". Keep your sign-in details safe; you are responsible for activity on your account.</p>
<h2>2. Conduct</h2>
<ul>
<li>Do not use offensive, hateful, sexual or harassing nicknames or messages.</li>
<li>Do not cheat, exploit bugs, spam or impersonate others.</li>
<li>You can report and block other players in the game. We may reset nicknames, restrict or delete accounts that break these rules.</li>
</ul>
<h2>3. Virtual items</h2>
<p>In-game gold and items have no cash value and cannot be exchanged for money.</p>
<h2>4. Accounts</h2>
<p>You can delete your account at any time (<a href="/hesap-sil?dil=en">how</a>). We may remove accounts that are inactive or that violate these terms.</p>
<h2>5. Liability</h2>
<p>To the extent permitted by law we are not liable for indirect losses arising from use of the game. Service interruptions may occur.</p>
<h2>6. Privacy and contact</h2>
<p>See the <a href="/gizlilik?dil=en">Privacy Policy</a>. Contact: <a href="mailto:$m">$m</a>.</p>
''');
  }
  return _sayfa(en: false, baslik: 'Kullanım Koşulları', yol: 'kosullar', govde: '''
<h1>Kullanım Koşulları</h1>
<p class="soluk">Emlak Deal &middot; Son güncelleme: $sonGuncelleme</p>
<p>Emlak Deal'ı kullanarak bu koşulları kabul etmiş olursun.</p>
<h2>1. Oyunun kullanımı</h2>
<p>Oyun eğlence amaçlı, ücretsiz ve "olduğu gibi" sunulur. Giriş bilgilerini güvende tut; hesabındaki işlemlerden sen sorumlusun.</p>
<h2>2. Davranış kuralları</h2>
<ul>
<li>Hakaret, nefret, cinsel içerik ya da taciz içeren takma ad ve mesajlar kullanma.</li>
<li>Hile yapma, hatalardan yararlanma, spam yapma, başkasının kimliğine bürünme.</li>
<li>Oyunda diğer oyuncuları şikayet edebilir ve engelleyebilirsin. Bu kuralları ihlal eden hesapların adını sıfırlayabilir, hesabı kısıtlayabilir ya da silebiliriz.</li>
</ul>
<h2>3. Sanal eşyalar</h2>
<p>Oyun içi altın ve eşyaların nakit değeri yoktur, paraya çevrilemez.</p>
<h2>4. Hesaplar</h2>
<p>Hesabını istediğin zaman silebilirsin (<a href="/hesap-sil">nasıl</a>). Uzun süre kullanılmayan ya da koşulları ihlal eden hesapları kaldırabiliriz.</p>
<h2>5. Sorumluluk</h2>
<p>Yasaların izin verdiği ölçüde, oyunun kullanımından doğan dolaylı zararlardan sorumlu değiliz. Hizmette kesintiler olabilir.</p>
<h2>6. Gizlilik ve iletişim</h2>
<p><a href="/gizlilik">Gizlilik Politikası</a>'na bak. İletişim: <a href="mailto:$m">$m</a>.</p>
''');
}

/// Facebook veri silme durum sayfası: GET /hesap-sil-durum?kod=...
String silmeDurumSayfasi({required bool en, required String kod, required ({String zaman, String durum})? kayit}) {
  final k = _h(kod);
  if (kayit == null) {
    return _sayfa(
        en: en,
        baslik: en ? 'Deletion status' : 'Silme durumu',
        yol: 'hesap-sil-durum',
        govde: en
            ? '<h1>Deletion status</h1><p>No deletion request was found for code <code>$k</code>.</p>'
            : '<h1>Silme durumu</h1><p><code>$k</code> koduyla bir silme isteği bulunamadı.</p>');
  }
  final z = _h(kayit.zaman);
  return _sayfa(
      en: en,
      baslik: en ? 'Deletion status' : 'Silme durumu',
      yol: 'hesap-sil-durum',
      govde: en
          ? '<h1>Deletion status</h1><p>Request <code>$k</code> was completed on $z. Your Emlak Deal data has been deleted.</p>'
          : '<h1>Silme durumu</h1><p><code>$k</code> isteği $z tarihinde tamamlandı. Emlak Deal verilerin silindi.</p>');
}
