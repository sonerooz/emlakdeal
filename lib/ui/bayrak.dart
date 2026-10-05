import 'dart:math';
import 'package:flutter/material.dart';
import '../dil.dart';

/// Yuvarlak bayrak rozeti: 'tr' Türk, 'en' Amerikan bayrağı.
class Bayrak extends StatelessWidget {
  const Bayrak(this.kod, {super.key, this.boyut = 40});
  final String kod;
  final double boyut;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: boyut,
        height: boyut,
        child: ClipOval(child: CustomPaint(painter: kod == 'tr' ? _TrBayrak() : _AbdBayrak())),
      );
}

/// Türk bayrağı, Bayrak Kanunu ölçüleriyle (boy=1, en=1.5): dış çember r=1/4 merkez (1/2,1/2);
/// iç çember r=1/5 merkezi 1/16 sağda; yıldız çevrel r=1/8, merkez x=19/24, bir ucu sola bakar.
class _TrBayrak extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE30A17));
    c.save();
    c.translate(-0.085 * u, 0);
    final beyaz = Paint()..color = Colors.white;
    final hilal = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(0.5 * u, 0.5 * u), radius: 0.25 * u)),
      Path()..addOval(Rect.fromCircle(center: Offset(0.5625 * u, 0.5 * u), radius: 0.2 * u)),
    );
    c.drawPath(hilal, beyaz);
    final m = Offset(19 / 24 * u, 0.5 * u);
    final R = 0.125 * u, r = R * 0.381966;
    final yildiz = Path();
    for (var i = 0; i < 10; i++) {
      final k = i.isEven ? R : r;
      final a = pi + i * pi / 5;
      final p = m + Offset(cos(a) * k, sin(a) * k);
      i == 0 ? yildiz.moveTo(p.dx, p.dy) : yildiz.lineTo(p.dx, p.dy);
    }
    yildiz.close();
    c.drawPath(yildiz, beyaz);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _AbdBayrak extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, sh = h / 13;
    for (var i = 0; i < 13; i++) {
      c.drawRect(Rect.fromLTWH(0, i * sh, w, sh + 0.5), Paint()..color = i.isEven ? const Color(0xFFB22234) : Colors.white);
    }
    c.drawRect(Rect.fromLTWH(0, 0, w * 0.55, sh * 7), Paint()..color = const Color(0xFF3C3B6E));
    final nokta = Paint()..color = Colors.white;
    for (var r = 0; r < 4; r++) {
      for (var k = 0; k < 4; k++) {
        c.drawCircle(Offset(w * (0.08 + k * 0.125 + (r.isOdd ? 0.06 : 0)), sh * (0.9 + r * 1.7)), w * 0.022, nokta);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

/// Sağ üstteki dil düğmesi: dokununca TR / EN bayrakları açılır.
class DilDugmesi extends StatelessWidget {
  const DilDugmesi({super.key, required this.degisti});
  final VoidCallback degisti;

  Future<void> _ac(BuildContext context) async {
    final sec = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF123F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('Dil / Language'), style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final k in const ['tr', 'en']) ...[
                if (k == 'en') const SizedBox(width: 22),
                InkWell(
                  onTap: () => Navigator.pop(c, k),
                  customBorder: const CircleBorder(),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Dil.o.kod == k ? Colors.amber : Colors.white24, width: 3)),
                      child: Bayrak(k, boyut: 72),
                    ),
                    const SizedBox(height: 8),
                    Text(k == 'tr' ? 'Türkçe' : 'English', style: TextStyle(color: Dil.o.kod == k ? Colors.amber : Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
    if (sec != null) {
      await Dil.o.sec(sec);
      degisti();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
        child: IconButton(
          tooltip: t('Dil / Language'),
          padding: const EdgeInsets.all(4),
          icon: Bayrak(Dil.o.kod, boyut: 40),
          onPressed: () => _ac(context),
        ),
      );
}
