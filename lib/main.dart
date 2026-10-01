import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/game_screen.dart';
import 'ayarlar.dart';
import 'ui/ayarlar_ekrani.dart';
import 'ui/lobi.dart';
import 'ui/ogretici.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Ayarlar.o.yukle();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MonoDealApp());
}

class MonoDealApp extends StatelessWidget {
  const MonoDealApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Monopoly Deal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E3A), useMaterial3: true),
        home: const MenuScreen(),
      );
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _bot = 1;

  @override
  void initState() {
    super.initState();
    if (!Ayarlar.o.ogreticiGoruldu) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OgreticiEkrani())));
    }
  }

  Future<void> _ac(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1B5E3A), Color(0xFF0F3D25)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('MONOPOLY', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const Text('DEAL', style: TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 8, height: 0.9)),
              const SizedBox(height: 12),
              const Text('Kart oyunu', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),
              const Text('Kaç bota karşı?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white,
                  selectedForegroundColor: Colors.black,
                  selectedBackgroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.white54),
                ),
                segments: const [
                  ButtonSegment(value: 1, label: Text('1 bot')),
                  ButtonSegment(value: 2, label: Text('2 bot')),
                  ButtonSegment(value: 3, label: Text('3 bot')),
                  ButtonSegment(value: 4, label: Text('4 bot')),
                ],
                selected: {_bot},
                onSelectionChanged: (s) => setState(() => _bot = s.first),
              ),
              const SizedBox(height: 6),
              Text('${_bot + 1} oyuncu · sen + $_bot bot', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 28),
              if (Ayarlar.o.kayit != null) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  onPressed: () => _ac(GameScreen(kayit: Ayarlar.o.kayit)),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Kaldığın yerden devam et'),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Ayarlar.o.kayit != null ? Colors.white24 : Colors.amber,
                    foregroundColor: Ayarlar.o.kayit != null ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                onPressed: () {
                  Ayarlar.o.kayitYaz(null);
                  _ac(GameScreen(botSayisi: _bot));
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(Ayarlar.o.kayit != null ? 'Yeni oyun' : 'Oyna'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                onPressed: () => _ac(const LobiEkrani()),
                icon: const Icon(Icons.wifi),
                label: const Text('Online oyna (arkadaşlarla)'),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: () => _ac(const OgreticiEkrani()),
                  icon: const Icon(Icons.school),
                  label: const Text('Nasıl oynanır'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: () => showDialog(context: context, builder: (_) => const _KurallarDlg()),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Kurallar'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: () => _ac(const AyarlarEkrani()),
                  icon: const Icon(Icons.settings),
                  label: const Text('Ayarlar'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _KurallarDlg extends StatelessWidget {
  const _KurallarDlg();
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Kurallar'),
        content: const SingleChildScrollView(
          child: Text(
            '• Amaç: farklı renkte 3 TAM tapu seti toplamak.\n'
            '• Her tur 2 kart çek (elin boşsa 5), en fazla 3 hamle; 3. hamlede tur kendiliğinden biter.\n'
            '• Tapu ve para kartlarına tek dokunuş yeter (tapu sete, para bankaya). Hamle kartlarında menü açılır.\n'
            '• Elinde soluk görünen kartların asıl işlevi şu an oynanamaz (yine de bankaya konabilir).\n'
            '• Bankaya konan hamle/kira kartı para kartına dönüşür, geri alınamaz.\n'
            '• Kira: elindeki kira kartıyla, o renkte tapun varsa HERKESTEN kira al. Çift Kira ile 2 katı (2 hamle).\n'
            '• Ödeme banka + tapulardan yapılır, elden yapılmaz. Yetmiyorsa her şeyini verirsin.\n'
            '• Tapu Devri: tamamlanmamış setten tapu al. Değiş Tokuş: takas. Haciz: TAM seti al. Tahsilat: seçtiğin birinden 5M.\n'
            '• Reddet: sana oynanan hamleyi iptal eder (karşı taraf da Reddet ile karşılık verebilir).\n'
            '• Ev (+3M) ve Otel (+4M) sadece tam setlere (Siyah / Açık Yeşil hariç).\n'
            '• Joker tapular istediğin renkte sayılır; kendi turunda destede jokere dokunup rengini değiştirebilirsin.\n'
            '• Tur sonunda elinde en fazla 7 kart kalabilir.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
      );
}
