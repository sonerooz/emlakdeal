import 'package:flutter/material.dart';

/// Emoji avatarı ya da misafir görselini çizer ('misafir' → assets/img/misafir.png).
class AvatarGorsel extends StatelessWidget {
  const AvatarGorsel(this.avatar, {super.key, required this.boyut});
  final String avatar;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    if (avatar == 'misafir') {
      return ClipOval(child: Image.asset('assets/img/misafir.png', width: boyut, height: boyut, fit: BoxFit.cover));
    }
    return Text(avatar, style: TextStyle(fontSize: boyut * 0.52));
  }
}
