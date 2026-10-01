import 'dart:math';
import 'package:flutter/material.dart';
import '../model/cards.dart';
import '../model/game.dart';
import 'card_widget.dart';

/// Masa düzleminde uçan kart (masa koordinatlarında, perspektifle birlikte döner).
class MasaUcus {
  MasaUcus({required this.card, required this.arka, required this.ctl, required this.from, required this.to, required this.w, this.scaleTo = 1});
  final GameCard card;
  final bool arka;
  final AnimationController ctl;
  final Offset from, to;
  final double w;
  final double scaleTo;
}

/// Perspektifli 3B masa: ortada çekme destesi + yakılan hamle kartları, oyuncular
/// masa etrafında; her koltuğun önünde tapular, solunda banka. Sürükle = döndür/eğ,
/// pinch = yakınlaştır, çift dokun = kamerayı sıfırla.
class Table3D extends StatefulWidget {
  const Table3D({
    super.key,
    required this.game,
    required this.ben,
    required this.seat,
    required this.deckKey,
    required this.discardKey,
    required this.handKeys,
    required this.tableKey,
    this.ucanlar = const [],
    this.ustBilgi,
  });
  final Game game;
  final Player ben;
  /// Bir oyuncunun masa alanı (tapular + banka); game_screen'in `_desteler`i.
  final Widget Function(Player p) seat;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final Map<Player, GlobalKey> handKeys;
  /// Masa kutusunun anahtarı; koordinat dönüşümleri için (RenderBox = 1100×1100 düzlem).
  final GlobalKey tableKey;
  /// Masa düzleminde hareket eden kartlar.
  final List<MasaUcus> ucanlar;
  /// Masanın üstüne bindirilen durum şeridi.
  final Widget? ustBilgi;

  @override
  State<Table3D> createState() => Table3DState();
}

class Table3DState extends State<Table3D> with SingleTickerProviderStateMixin {
  static const double masa = 1100; // sanal masa boyutu (mantıksal birim)
  /// Koltuk yarıçapı oyuncu sayısına göre: 2 kişide en küçük masa, 5 kişide en büyük.
  double get koltukR => 250 + (n - 2) * 42;
  double get masaR => koltukR + 175;
  static const double _egimMin = 0.02, _egimMax = 1.25;

  double yaw = 0, tilt = 0.95, zoom = 1;
  double _z0 = 1, _yaw0 = 0, _tilt0 = 0.95;
  Offset _p0 = Offset.zero;
  bool _ilk = true;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  int get n => widget.game.players.length;

  /// Oyuncunun masa etrafındaki açısı (ben altta, saat yönünde).
  double aci(Player p) {
    final i = widget.game.players.indexOf(p), b = widget.game.players.indexOf(widget.ben);
    return pi / 2 + ((i - b) % n) * 2 * pi / n;
  }

  /// Kamerayı o oyuncunun karşısına döndür.
  void oyuncuyaDon(Player p) {
    var hedef = pi / 2 - aci(p);
    var d = (hedef - yaw) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    kameraGit(yaw: yaw + d, tilt: 0.95, zoom: _zoomVarsayilan * 1.15);
  }

  /// Tepeden kuş bakışı.
  void tepeden() => kameraGit(yaw: yaw, tilt: 0.02, zoom: _zoomVarsayilan * 0.9);

  double _yawBas = 0, _tiltBas = 0, _zoomBas = 0, _yawHedef = 0, _tiltHedef = 0, _zoomHedef = 0;

  void kameraGit({required double yaw, required double tilt, required double zoom}) {
    _yawBas = this.yaw; _tiltBas = this.tilt; _zoomBas = this.zoom;
    _yawHedef = yaw; _tiltHedef = tilt.clamp(_egimMin, _egimMax); _zoomHedef = zoom.clamp(0.3, 2.6);
    _anim
      ..removeListener(_tick)
      ..addListener(_tick)
      ..forward(from: 0);
  }

  void _tick() => setState(() {
        final t = Curves.easeInOut.transform(_anim.value);
        yaw = _yawBas + (_yawHedef - _yawBas) * t;
        tilt = _tiltBas + (_tiltHedef - _tiltBas) * t;
        zoom = _zoomBas + (_zoomHedef - _zoomBas) * t;
      });

  void sifirla() => kameraGit(yaw: 0, tilt: 0.95, zoom: _zoomVarsayilan);

  double _zoomVarsayilan = 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final vw = c.maxWidth, vh = c.maxHeight;
      if (_ilk) {
        _ilk = false;
        _zoomVarsayilan = zoom = (vw / (masaR * 1.3)).clamp(0.35, 1.4);
      }
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..rotateX(-tilt)
        ..scale(zoom)
        ..rotateZ(yaw);
      return ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: sifirla,
          onScaleStart: (d) {
            _anim.removeListener(_tick);
            _z0 = zoom;
            _yaw0 = yaw;
            _tilt0 = tilt;
            _p0 = d.focalPoint;
          },
          onScaleUpdate: (d) {
            final dx = d.focalPoint.dx - _p0.dx, dy = d.focalPoint.dy - _p0.dy;
            setState(() {
              zoom = (_z0 * d.scale).clamp(0.3, 2.6);
              yaw = _yaw0 + dx * 0.008;
              tilt = (_tilt0 - dy * 0.005).clamp(_egimMin, _egimMax);
            });
          },
          child: Stack(children: [
            // oda
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: const Alignment(0, -0.3), radius: 1.2, colors: [const Color(0xFF3B2A1E), const Color(0xFF17100B)]),
                ),
              ),
            ),
            Positioned.fill(
              child: OverflowBox(
                minWidth: masa,
                maxWidth: masa,
                minHeight: masa,
                maxHeight: masa,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(0, vh * 0.08),
                  child: Transform(
                    transform: m,
                    alignment: Alignment.center,
                    child: SizedBox(key: widget.tableKey, width: masa, height: masa, child: _masa()),
                  ),
                ),
              ),
            ),
            if (widget.ustBilgi != null) Positioned(left: 0, right: 0, top: 0, child: widget.ustBilgi!),
            Positioned(right: 4, bottom: 4, child: _kameraButonlari()),
          ]),
        ),
      );
    });
  }

  Widget _kameraButonlari() {
    final g = widget.game;
    Widget b(IconData ik, String tip, VoidCallback f, {Color? renk}) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: f,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
              child: Icon(ik, size: 20, color: renk ?? Colors.white70),
            ),
          ),
        );
    Widget oyuncu(Player p) {
      final aktif = g.aktif == p;
      final ad = p == widget.ben ? 'Sen' : p.name.replaceAll('Bot ', 'B');
      return Tooltip(
        message: '${p.name} masasına bak',
        child: InkWell(
          onTap: () => oyuncuyaDon(p),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: aktif ? Colors.amber : Colors.black54, shape: BoxShape.circle, border: Border.all(color: aktif ? Colors.amber : Colors.white24)),
            alignment: Alignment.center,
            child: Text(ad, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: aktif ? Colors.black : Colors.white)),
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final p in g.players) oyuncu(p),
      const SizedBox(height: 4),
      b(Icons.vertical_align_top, 'Tepeden bak', tepeden),
      b(Icons.center_focus_strong, 'Kamerayı sıfırla', sifirla),
    ]);
  }

  Widget _masa() {
    final g = widget.game;
    const cx = masa / 2, cy = masa / 2;
    return Stack(clipBehavior: Clip.none, children: [
      // çuha + ahşap kenar
      Positioned(
        left: cx - masaR,
        top: cy - masaR,
        child: Container(
          width: masaR * 2,
          height: masaR * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF2E8B57), Color(0xFF1B5E3A), Color(0xFF12452A)], stops: [0, 0.7, 1]),
            border: Border.all(color: const Color(0xFF5C3A1E), width: 26),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 60, spreadRadius: 10, offset: Offset(0, 30))],
          ),
        ),
      ),
      Positioned(
        left: cx - masaR + 50,
        top: cy - masaR + 50,
        child: Container(
          width: masaR * 2 - 100,
          height: masaR * 2 - 100,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white12, width: 2)),
        ),
      ),
      // orta: deste + yakılanlar
      Positioned(left: cx - 120, top: cy - 60, child: _orta(g)),
      // koltuklar
      for (final p in g.players) _koltuk(p),
      // masada uçan kartlar
      for (final u in widget.ucanlar)
        AnimatedBuilder(
          animation: u.ctl,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(u.ctl.value);
            final p = Offset.lerp(u.from, u.to, t)!;
            final s = 1 + (u.scaleTo - 1) * t;
            final w = u.w * s;
            // yolun ortasında hafif "kalkma" (yükselme hissi): daha büyük + gölge
            final kalk = sin(t * pi);
            return Positioned(
              left: p.dx - w / 2,
              top: p.dy - w * 1.45 / 2 - kalk * 14,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1 + kalk * 0.12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(w * 0.09), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35 + kalk * 0.3), blurRadius: 6 + kalk * 16, offset: Offset(0, 4 + kalk * 14))]),
                    child: u.arka ? CardBack(w: w) : CardView(u.card, w: w),
                  ),
                ),
              ),
            );
          },
        ),
    ]);
  }

  Widget _orta(Game g) {
    final son = g.discard.length;
    final gorunen = g.discard.sublist(max(0, son - 5));
    return SizedBox(
      width: 240,
      height: 120,
      child: Row(children: [
        Column(key: widget.deckKey, mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 70,
            height: 70 * 1.45 + 8,
            child: Stack(children: [
              for (var i = 0; i < min(4, (g.deck.length / 25).ceil()); i++)
                Positioned(left: 0, top: 8.0 - i * 2.5, child: const CardBack(w: 64)),
            ]),
          ),
          Text('${g.deck.length}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(width: 26),
        SizedBox(
          key: widget.discardKey,
          width: 110,
          height: 110,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 10,
              top: 6,
              child: Container(
                width: 64,
                height: 64 * 1.45,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24, width: 1.5)),
                alignment: Alignment.center,
                child: const Text('YAKILAN', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            for (var i = 0; i < gorunen.length; i++)
              Positioned(
                left: 10 + ((gorunen[i].id * 7) % 9) - 4,
                top: 6 + ((gorunen[i].id * 5) % 7) - 3,
                child: Transform.rotate(
                  angle: (((gorunen[i].id * 37) % 40) - 20) * pi / 180,
                  child: CardView(gorunen[i], w: 64),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _koltuk(Player p) {
    final g = widget.game;
    final a = aci(p);
    const cx = masa / 2, cy = masa / 2;
    final px = cx + cos(a) * koltukR, py = cy + sin(a) * koltukR;
    final aktif = g.aktif == p;
    final ben = p == widget.ben;
    return Positioned(
      left: px,
      top: py,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: a - pi / 2,
          child: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // tapular + banka (merkeze yakın taraf)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: aktif ? Colors.amber : Colors.white12, width: aktif ? 2 : 1),
                ),
                child: widget.seat(p),
              ),
              const SizedBox(height: 6),
              // isim + el (oyuncunun kendi kenarı)
              GestureDetector(
                onTap: () => oyuncuyaDon(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: aktif ? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ben ? Icons.person : Icons.smart_toy, size: 16, color: aktif ? Colors.black : Colors.white70),
                    const SizedBox(width: 6),
                    Text(p.name, style: TextStyle(color: aktif ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('set ${p.tamSetSayisi}/3 · ${p.bankaToplam}M', style: TextStyle(color: aktif ? Colors.black87 : Colors.white70, fontSize: 11)),
                    if (!ben) ...[
                      const SizedBox(width: 8),
                      Row(key: widget.handKeys[p], mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < p.hand.length.clamp(0, 7); i++)
                          const Padding(padding: EdgeInsets.only(left: 1.5), child: CardBack(w: 12)),
                        const SizedBox(width: 4),
                        Text('${p.hand.length}', style: TextStyle(color: aktif ? Colors.black87 : Colors.white70, fontSize: 11)),
                      ]),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
