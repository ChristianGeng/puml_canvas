enum TokenType {
  startUml,
  endUml,
  startMindmap,
  endMindmap,
  startWbs,
  endWbs,
  startJson,
  endJson,
  startYaml,
  endYaml,
  startSalt,
  endSalt,
  startGantt,
  endGantt,
  startNwdiag,
  endNwdiag,
  identifier,
  stringLiteral,
  arrow,
  colon,
  comma,
  text,
  plusPlus,
  minusMinus,
  starStar,
  bangBang,
  hashColor,
  doubleEquals,
  doublePipe,
  dotDotDot,
  equals,
  mapArrow,
  atTime,
  leftBrace,
  rightBrace,
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  newline,
  eof,
}

class Token {
  final TokenType type;
  final String lexeme;
  final int line;
  final int column;

  const Token(this.type, this.lexeme, this.line, this.column);

  @override
  String toString() => 'Token($type, "$lexeme", $line:$column)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          type == other.type &&
          lexeme == other.lexeme &&
          line == other.line &&
          column == other.column;

  @override
  int get hashCode => Object.hash(type, lexeme, line, column);
}
