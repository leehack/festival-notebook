import 'package:flutter/material.dart';

const ink = Color(0xff23433a);
const paper = Color(0xfff5efe2);
const berry = Color(0xffa84d50);
const muted = Color(0xff68796d);
Widget label(String s) => Text(
  s,
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: muted,
  ),
);
Widget heading(String s, {double size = 28}) => Text(
  s,
  style: TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: ink,
  ),
);
Widget card(Widget child) => Material(
  color: const Color(0xfffffcf5),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: Color(0xffe1dccd)),
  ),
  child: Padding(padding: const EdgeInsets.all(26), child: child),
);
