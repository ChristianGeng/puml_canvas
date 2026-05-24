import '../ast/diagram.dart';

class EbnfParseResult {
  final List<EbnfRule> rules;
  final String remainder;
  const EbnfParseResult({required this.rules, required this.remainder});
}

class EbnfParseException implements Exception {
  final String message;
  final int position;
  EbnfParseException(this.message, this.position);
  @override
  String toString() => 'EbnfParseException($position): $message';
}

enum _EbnfTokKind {
  identifier,
  terminal,
  special,
  comment,
  equals,
  semicolon,
  comma,
  pipe,
  lbracket,
  rbracket,
  lbrace,
  rbrace,
  lparen,
  rparen,
}

class _EbnfTok {
  final _EbnfTokKind kind;
  final String value;
  final int start;
  final int end;
  const _EbnfTok({
    required this.kind,
    required this.value,
    required this.start,
    required this.end,
  });
}

class EbnfBodyParser {
  EbnfParseResult parse(String body) {
    final rules = <EbnfRule>[];
    var cursor = 0;
    while (cursor < body.length) {
      final ruleStart = _skipWhitespace(body, cursor);
      if (ruleStart >= body.length) {
        cursor = ruleStart;
        break;
      }
      try {
        final result = _parseOneRule(body, ruleStart);
        rules.add(result.rule);
        cursor = result.end;
      } catch (_) {
        return EbnfParseResult(
          rules: rules,
          remainder: body.substring(ruleStart).trimRight(),
        );
      }
    }
    return EbnfParseResult(rules: rules, remainder: '');
  }

  _RuleResult _parseOneRule(String body, int start) {
    final tokens = <_EbnfTok>[];
    var pos = start;
    while (pos < body.length) {
      pos = _skipWhitespace(body, pos);
      if (pos >= body.length) break;
      final tok = _nextToken(body, pos);
      tokens.add(tok);
      pos = tok.end;
      if (tok.kind == _EbnfTokKind.semicolon) break;
    }
    if (tokens.isEmpty) {
      throw EbnfParseException('Empty rule', start);
    }
    if (tokens.last.kind != _EbnfTokKind.semicolon) {
      throw EbnfParseException('Rule missing semicolon', start);
    }
    final cursor = _Cursor(tokens);
    final head = cursor.expect(_EbnfTokKind.identifier);
    cursor.expect(_EbnfTokKind.equals);
    final expr = _parseAlternation(cursor);
    cursor.expect(_EbnfTokKind.semicolon);
    if (!cursor.atEnd) {
      throw EbnfParseException(
        'Trailing tokens after semicolon',
        cursor.current.start,
      );
    }
    return _RuleResult(
      rule: EbnfRule(name: head.value, expression: expr),
      end: pos,
    );
  }

  EbnfExpr _parseAlternation(_Cursor cursor) {
    final items = <EbnfExpr>[_parseSequence(cursor)];
    while (cursor.match(_EbnfTokKind.pipe)) {
      items.add(_parseSequence(cursor));
    }
    if (items.length == 1) return items.single;
    return EbnfAlternation(items);
  }

  EbnfExpr _parseSequence(_Cursor cursor) {
    final items = <EbnfExpr>[_parseFactor(cursor)];
    while (cursor.match(_EbnfTokKind.comma)) {
      items.add(_parseFactor(cursor));
    }
    if (items.length == 1) return items.single;
    return EbnfSequence(items);
  }

  EbnfExpr _parseFactor(_Cursor cursor) {
    if (cursor.atEnd) {
      throw EbnfParseException('Unexpected end of rule', -1);
    }
    final tok = cursor.current;
    switch (tok.kind) {
      case _EbnfTokKind.terminal:
        cursor.advance();
        return EbnfTerminal(tok.value);
      case _EbnfTokKind.identifier:
        cursor.advance();
        return EbnfNonTerminal(tok.value);
      case _EbnfTokKind.special:
        cursor.advance();
        return EbnfSpecial(tok.value);
      case _EbnfTokKind.comment:
        cursor.advance();
        return EbnfComment(tok.value);
      case _EbnfTokKind.lparen:
        cursor.advance();
        final inner = _parseAlternation(cursor);
        cursor.expect(_EbnfTokKind.rparen);
        return EbnfGroup(inner);
      case _EbnfTokKind.lbracket:
        cursor.advance();
        final inner = _parseAlternation(cursor);
        cursor.expect(_EbnfTokKind.rbracket);
        return EbnfOptional(inner);
      case _EbnfTokKind.lbrace:
        cursor.advance();
        final inner = _parseAlternation(cursor);
        cursor.expect(_EbnfTokKind.rbrace);
        return EbnfRepetition(inner);
      default:
        throw EbnfParseException(
          'Unexpected token: ${tok.value}',
          tok.start,
        );
    }
  }

  int _skipWhitespace(String body, int pos) {
    var p = pos;
    while (p < body.length) {
      final c = body[p];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        p++;
        continue;
      }
      if (c == '(' && p + 1 < body.length && body[p + 1] == '*') {
        final close = body.indexOf('*)', p + 2);
        if (close < 0) {
          return body.length;
        }
        p = close + 2;
        continue;
      }
      break;
    }
    return p;
  }

  _EbnfTok _nextToken(String body, int pos) {
    final c = body[pos];
    switch (c) {
      case '=':
        return _EbnfTok(
          kind: _EbnfTokKind.equals,
          value: '=',
          start: pos,
          end: pos + 1,
        );
      case ';':
        return _EbnfTok(
          kind: _EbnfTokKind.semicolon,
          value: ';',
          start: pos,
          end: pos + 1,
        );
      case '.':
        return _EbnfTok(
          kind: _EbnfTokKind.semicolon,
          value: '.',
          start: pos,
          end: pos + 1,
        );
      case ',':
        return _EbnfTok(
          kind: _EbnfTokKind.comma,
          value: ',',
          start: pos,
          end: pos + 1,
        );
      case '|':
        return _EbnfTok(
          kind: _EbnfTokKind.pipe,
          value: '|',
          start: pos,
          end: pos + 1,
        );
      case '[':
        return _EbnfTok(
          kind: _EbnfTokKind.lbracket,
          value: '[',
          start: pos,
          end: pos + 1,
        );
      case ']':
        return _EbnfTok(
          kind: _EbnfTokKind.rbracket,
          value: ']',
          start: pos,
          end: pos + 1,
        );
      case '{':
        return _EbnfTok(
          kind: _EbnfTokKind.lbrace,
          value: '{',
          start: pos,
          end: pos + 1,
        );
      case '}':
        return _EbnfTok(
          kind: _EbnfTokKind.rbrace,
          value: '}',
          start: pos,
          end: pos + 1,
        );
      case '(':
        return _EbnfTok(
          kind: _EbnfTokKind.lparen,
          value: '(',
          start: pos,
          end: pos + 1,
        );
      case ')':
        return _EbnfTok(
          kind: _EbnfTokKind.rparen,
          value: ')',
          start: pos,
          end: pos + 1,
        );
      case '"':
      case "'":
        return _readQuoted(body, pos, c);
      case '?':
        return _readSpecial(body, pos);
      default:
        if (_isIdentStart(c)) {
          return _readIdentifier(body, pos);
        }
        throw EbnfParseException("Unexpected character '$c'", pos);
    }
  }

  _EbnfTok _readQuoted(String body, int pos, String quote) {
    var p = pos + 1;
    final buf = StringBuffer();
    while (p < body.length && body[p] != quote) {
      if (body[p] == '\n') {
        throw EbnfParseException('Unterminated terminal', pos);
      }
      buf.write(body[p]);
      p++;
    }
    if (p >= body.length) {
      throw EbnfParseException('Unterminated terminal', pos);
    }
    return _EbnfTok(
      kind: _EbnfTokKind.terminal,
      value: buf.toString(),
      start: pos,
      end: p + 1,
    );
  }

  _EbnfTok _readSpecial(String body, int pos) {
    var p = pos + 1;
    final buf = StringBuffer();
    while (p < body.length && body[p] != '?') {
      if (body[p] == '\n') {
        throw EbnfParseException('Unterminated special sequence', pos);
      }
      buf.write(body[p]);
      p++;
    }
    if (p >= body.length) {
      throw EbnfParseException('Unterminated special sequence', pos);
    }
    return _EbnfTok(
      kind: _EbnfTokKind.special,
      value: buf.toString().trim(),
      start: pos,
      end: p + 1,
    );
  }

  _EbnfTok _readIdentifier(String body, int pos) {
    var p = pos;
    while (p < body.length && _isIdentChar(body[p])) {
      p++;
    }
    return _EbnfTok(
      kind: _EbnfTokKind.identifier,
      value: body.substring(pos, p),
      start: pos,
      end: p,
    );
  }

  static bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        c == '_';
  }

  static bool _isIdentChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x30 && code <= 0x39) ||
        c == '_' ||
        c == '-';
  }
}

class _RuleResult {
  final EbnfRule rule;
  final int end;
  const _RuleResult({required this.rule, required this.end});
}

class _Cursor {
  final List<_EbnfTok> tokens;
  int pos = 0;
  _Cursor(this.tokens);

  bool get atEnd => pos >= tokens.length;

  _EbnfTok get current => tokens[pos];

  _EbnfTok advance() => tokens[pos++];

  bool match(_EbnfTokKind kind) {
    if (atEnd) return false;
    if (current.kind != kind) return false;
    advance();
    return true;
  }

  _EbnfTok expect(_EbnfTokKind kind) {
    if (atEnd) {
      throw EbnfParseException('Expected $kind, got end of rule', -1);
    }
    final tok = current;
    if (tok.kind != kind) {
      throw EbnfParseException(
        'Expected $kind, got ${tok.kind} (${tok.value})',
        tok.start,
      );
    }
    advance();
    return tok;
  }
}
