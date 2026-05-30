import 'dart:convert';

/// Builds the official plantuml.com rendering URL for a PlantUML [source].
///
/// Uses the server's hexadecimal encoding (`~h` prefix), which simply hex
/// encodes the UTF-8 bytes of the source. This avoids the deflate/custom-base64
/// scheme (which would need a compression dependency and is not available on
/// web) while still matching the source exactly, so the original rendering on
/// the right always corresponds to whatever is in the editor on the left.
String plantUmlImageUrl(String source, {String format = 'png'}) {
  final bytes = utf8.encode(source.trim());
  final hex = StringBuffer();
  for (final b in bytes) {
    hex.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return 'https://www.plantuml.com/plantuml/$format/~h$hex';
}
