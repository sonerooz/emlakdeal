import 'package:flutter/material.dart';

/// 0'dan [deger]'e akarak sayan metin (ör. "+120 XP").
class SayiSayac extends StatelessWidget {
  const SayiSayac({super.key, required this.deger, required this.bicim, this.stil, this.sure = const Duration(milliseconds: 1100), this.gecikme = Duration.zero});
  final int deger;
  final String Function(int) bicim;
  final TextStyle? stil;
  final Duration sure;
  final Duration gecikme;

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: Future.delayed(gecikme),
        builder: (_, s) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: s.connectionState == ConnectionState.done ? deger.toDouble() : 0),
          duration: sure,
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(bicim(v.round()), style: stil),
        ),
      );
}

/// Değer değişince eski değerden yenisine akarak sayan metin (ilk gösterimde animasyonsuz).
class SayiGecis extends StatelessWidget {
  const SayiGecis({super.key, required this.deger, required this.bicim, this.stil, this.sure = const Duration(milliseconds: 1200)});
  final int deger;
  final String Function(int) bicim;
  final TextStyle? stil;
  final Duration sure;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: deger.toDouble(), end: deger.toDouble()),
        duration: sure,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(bicim(v.round()), style: stil),
      );
}
