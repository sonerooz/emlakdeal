import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});
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
              const Text('Kart oyunu · 1v1', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 48),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber, foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen())),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bot\'a karşı oyna'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: () => showDialog(context: context, builder: (_) => const _KurallarDlg()),
                icon: const Icon(Icons.menu_book),
                label: const Text('Kurallar'),
              ),
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
            '• Tapu ve para kartlarına tek dokunuş yeter (tapu sete, para bankaya). Aksiyonlarda menü açılır.\n'
            '• Bankaya konan aksiyon/kira kartı para kartına dönüşür, geri alınamaz.\n'
            '• Kira: elindeki kira kartıyla, o renkte tapun varsa rakipten kira al. Çift Kira ile 2 katı (2 hamle).\n'
            '• Ödeme banka + tapulardan yapılır, elden yapılmaz. Yetmiyorsa her şeyini verirsin.\n'
            '• Tapu Devri: tamamlanmamış setten tapu al. Değiş Tokuş: takas. Haciz: TAM seti al.\n'
            '• Reddet: sana oynanan aksiyonu iptal eder (rakip de Reddet ile karşılık verebilir).\n'
            '• Ev (+3M) ve Otel (+4M) sadece tam setlere (tren/hizmet hariç).\n'
            '• Joker tapular istediğin renkte sayılır; kendi turunda dokunup rengini değiştirebilirsin.\n'
            '• Tur sonunda elinde en fazla 7 kart kalabilir.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
      );
}
