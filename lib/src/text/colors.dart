import 'package:flutter/painting.dart';

const namedColors = <String, Color>{
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'blue': Color(0xFF0000FF),
  'yellow': Color(0xFFFFFF00),
  'orange': Color(0xFFFFA500),
  'purple': Color(0xFF800080),
  'pink': Color(0xFFFFC0CB),
  'brown': Color(0xFFA52A2A),
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
  'lightblue': Color(0xFFADD8E6),
  'lightgreen': Color(0xFF90EE90),
  'lightgray': Color(0xFFD3D3D3),
  'lightgrey': Color(0xFFD3D3D3),
  'darkblue': Color(0xFF00008B),
  'darkgreen': Color(0xFF006400),
  'darkred': Color(0xFF8B0000),
};

Color? tryParseColor(String spec) {
  final body = spec.startsWith('#') ? spec.substring(1) : spec;
  if (_isHex(body)) {
    int? value;
    if (body.length == 3) {
      final r = body[0];
      final g = body[1];
      final b = body[2];
      value = int.tryParse('FF$r$r$g$g$b$b', radix: 16);
    } else if (body.length == 6) {
      value = int.tryParse('FF$body', radix: 16);
    } else if (body.length == 8) {
      value = int.tryParse(body, radix: 16);
    }
    if (value != null) return Color(value);
  }
  return namedColors[body.toLowerCase()];
}

bool _isHex(String s) {
  if (s.isEmpty) return false;
  for (var k = 0; k < s.length; k++) {
    final c = s.codeUnitAt(k);
    final ok = (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x46) ||
        (c >= 0x61 && c <= 0x66);
    if (!ok) return false;
  }
  return true;
}
