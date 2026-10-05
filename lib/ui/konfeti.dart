import 'dart:math';
import 'package:flutter/material.dart';

/// Ekranın üstüne konfeti patlatır (iki alt köşeden fışkırır, yukarıdan da yağar); ~4 sn sonra kendini kaldırır.
void konfetiPatlat(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _Konfeti(bitti: () => e.remove()));
  overlay.insert(e);
}

class _Parca {
  _Parca(this.kaynakX, this.kaynakY, this.vx, this.vy, this.boyut, this.renk, this.donus, this.faz, this.gecikme, this.daire);
  final double kaynakX, kaynakY; // 0..1 (ekran oranı)
  final double vx, vy, boyut, donus, faz, gecikme;
  final Color renk;
  final bool daire;
}

class _Konfeti extends StatefulWidget {
  const _Konfeti({required this.bitti});
  final VoidCallback bitti;
  @override
  State<_Konfeti> createState() => _KonfetiState();
}

class _KonfetiState extends State<_Konfeti> with SingleTickerProviderStateMixin {
  static const sure = Duration(milliseconds: 4200);
  late final AnimationController _c = AnimationController(vsync: this, duration: sure)..forward().whenComplete(widget.bitti);
  late final List<_Parca> _p;

  @override
  void initState() {
    super.initState();
    final r = Random();
    const renkler = [Color(0xFFFFC107), Color(0xFFE91E63), Color(0xFF29B6F6), Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFFFF7043), Colors.white];
    _p = [];
    for (var i = 0; i < 150; i++) {
      final sol = i.isEven;
      final aci = (sol ? -pi / 2 + 0.25 + r.nextDouble() * 0.7 : -pi / 2 - 0.25 - r.nextDouble() * 0.7);
      final hiz = 700 + r.nextDouble() * 900;
      _p.add(_Parca(sol ? 0.0 : 1.0, 1.0, cos(aci) * hiz, sin(aci) * hiz, 6 + r.nextDouble() * 7, renkler[r.nextInt(renkler.length)], (r.nextDouble() - .5) * 18, r.nextDouble() * 6.28, r.nextDouble() * 0.15, r.nextInt(5) == 0));
    }
    for (var i = 0; i < 70; i++) {
      _p.add(_Parca(r.nextDouble(), -0.05, (r.nextDouble() - .5) * 120, 80 + r.nextDouble() * 160, 6 + r.nextDouble() * 6, renkler[r.nextInt(renkler.length)], (r.nextDouble() - .5) * 14, r.nextDouble() * 6.28, 0.25 + r.nextDouble() * 1.2, r.nextInt(5) == 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _KonfetiCizer(_p, _c.value * sure.inMilliseconds / 1000)),
          ),
        ),
      );
}

class _KonfetiCizer extends CustomPainter {
  _KonfetiCizer(this.p, this.t);
  final List<_Parca> p;
  final double t; // sn
  static const g = 1100.0, surtunme = 1.7;

  @override
  void paint(Canvas canvas, Size s) {
    final boya = Paint();
    for (final k in p) {
      final u = t - k.gecikme;
      if (u <= 0) continue;
      final d = (1 - exp(-surtunme * u)) / surtunme;
      var x = k.kaynakX * s.width + k.vx * d + sin(u * 4 + k.faz) * 14;
      final y = k.kaynakY * s.height + k.vy * d + 0.5 * g * u * u * 0.55;
      if (y > s.height + 30) continue;
      final solma = t > 3.3 ? (1 - (t - 3.3) / 0.9).clamp(0.0, 1.0) : 1.0;
      boya.color = k.renk.withValues(alpha: solma);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(k.faz + u * k.donus);
      // dönerken ince/kalın görünsün (3B takla hissi)
      canvas.scale(1, 0.25 + 0.75 * cos(u * 6 + k.faz).abs());
      if (k.daire) {
        canvas.drawCircle(Offset.zero, k.boyut / 2, boya);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: k.boyut, height: k.boyut * 0.55), boya);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_KonfetiCizer old) => old.t != t;
}
