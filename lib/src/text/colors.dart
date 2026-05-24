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
  'lightyellow': Color(0xFFFFFFE0),
  'lightpink': Color(0xFFFFB6C1),
  'lightcyan': Color(0xFFE0FFFF),
  'lightcoral': Color(0xFFF08080),
  'lightsalmon': Color(0xFFFFA07A),
  'lightseagreen': Color(0xFF20B2AA),
  'lightskyblue': Color(0xFF87CEFA),
  'lightsteelblue': Color(0xFFB0C4DE),
  'darkblue': Color(0xFF00008B),
  'darkgreen': Color(0xFF006400),
  'darkred': Color(0xFF8B0000),
  'salmon': Color(0xFFFA8072),
  'gold': Color(0xFFFFD700),
  'silver': Color(0xFFC0C0C0),
  'cyan': Color(0xFF00FFFF),
  'magenta': Color(0xFFFF00FF),
  'olive': Color(0xFF808000),
  'navy': Color(0xFF000080),
  'teal': Color(0xFF008080),
  'maroon': Color(0xFF800000),
  'aqua': Color(0xFF00FFFF),
  'fuchsia': Color(0xFFFF00FF),
  'lime': Color(0xFF00FF00),
  'indigo': Color(0xFF4B0082),
  'violet': Color(0xFFEE82EE),
  'beige': Color(0xFFF5F5DC),
  'tan': Color(0xFFD2B48C),
  'khaki': Color(0xFFF0E68C),
  'plum': Color(0xFFDDA0DD),
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
