import 'token.dart';

class LexerException implements Exception {
  final String message;
  final int line;
  final int column;
  LexerException(this.message, this.line, this.column);
  @override
  String toString() => 'LexerException($line:$column): $message';
}

class Lexer {
  List<Token> tokenize(String source) {
    final tokens = <Token>[];
    var line = 1;
    var col = 1;
    var i = 0;
    var inNoteBody = false;
    var inLegendBody = false;
    var inClassBody = false;
    var inIndentedTreeBody = false;
    TokenType? indentedTreeEndType;
    String? indentedTreeEndKeyword;
    var inDataBody = false;
    TokenType? dataEndType;
    String? dataEndKeyword;

    void emit(TokenType type, String lexeme, int startCol) {
      tokens.add(Token(type, lexeme, line, startCol));
    }

    while (i < source.length) {
      if (inDataBody &&
          col == 1 &&
          i < source.length &&
          source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        final trimmed = raw.trim();
        if (trimmed.toLowerCase() == dataEndKeyword) {
          final endKeyword = dataEndKeyword!;
          final endType = dataEndType!;
          inDataBody = false;
          dataEndType = null;
          dataEndKeyword = null;
          final idx = raw.toLowerCase().indexOf(endKeyword);
          emit(endType, endKeyword, col + idx);
        } else {
          emit(TokenType.text, raw, col);
        }
        col += raw.length;
        i = end;
        continue;
      }

      if (inIndentedTreeBody &&
          col == 1 &&
          i < source.length &&
          source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        final trimmed = raw.trim();
        if (trimmed.toLowerCase() == indentedTreeEndKeyword) {
          final endKeyword = indentedTreeEndKeyword!;
          final endType = indentedTreeEndType!;
          inIndentedTreeBody = false;
          indentedTreeEndType = null;
          indentedTreeEndKeyword = null;
          final idx = raw.toLowerCase().indexOf(endKeyword);
          emit(endType, endKeyword, col + idx);
        } else if (trimmed.isNotEmpty) {
          emit(TokenType.text, trimmed, col);
        }
        col += raw.length;
        i = end;
        continue;
      }

      if (inNoteBody && col == 1 && i < source.length && source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        if (raw.trim() == 'end note') {
          inNoteBody = false;
          final endIdx = raw.indexOf('end');
          emit(TokenType.identifier, 'end', col + endIdx);
          final noteIdx = raw.indexOf('note', endIdx + 3);
          emit(TokenType.identifier, 'note', col + noteIdx);
        } else {
          emit(TokenType.text, raw.trim(), col);
        }
        col += raw.length;
        i = end;
        continue;
      }

      if (inClassBody && col == 1 && i < source.length && source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        final trimmed = raw.trim();
        if (trimmed == '}') {
          inClassBody = false;
          final idx = raw.indexOf('}');
          emit(TokenType.rightBrace, '}', col + idx);
        } else if (trimmed.isEmpty) {
          // skip blank line
        } else {
          emit(TokenType.text, trimmed, col);
        }
        col += raw.length;
        i = end;
        continue;
      }

      if (inLegendBody && col == 1 && i < source.length && source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        final trimmed = raw.trim();
        if (trimmed == 'endlegend') {
          inLegendBody = false;
          final idx = raw.indexOf('endlegend');
          emit(TokenType.identifier, 'endlegend', col + idx);
        } else if (trimmed == 'end legend') {
          inLegendBody = false;
          final endIdx = raw.indexOf('end');
          emit(TokenType.identifier, 'end', col + endIdx);
          final legendIdx = raw.indexOf('legend', endIdx + 3);
          emit(TokenType.identifier, 'legend', col + legendIdx);
        } else {
          emit(TokenType.text, trimmed, col);
        }
        col += raw.length;
        i = end;
        continue;
      }

      final c = source[i];

      if (c == '\n') {
        emit(TokenType.newline, '\n', col);
        i++;
        line++;
        col = 1;
        if (_isMultilineNoteHeader(tokens)) {
          inNoteBody = true;
        }
        if (_isLegendHeader(tokens)) {
          inLegendBody = true;
        }
        if (_isClassBodyHeader(tokens)) {
          inClassBody = true;
        }
        continue;
      }

      if (c == ' ' || c == '\t' || c == '\r') {
        i++;
        col++;
        continue;
      }

      if (c == '/' && i + 1 < source.length && source[i + 1] == "'") {
        final startLine = line;
        final startCol = col;
        i += 2;
        col += 2;
        var closed = false;
        while (i < source.length) {
          if (source[i] == '\n') {
            i++;
            line++;
            col = 1;
            continue;
          }
          if (source[i] == "'" &&
              i + 1 < source.length &&
              source[i + 1] == '/') {
            i += 2;
            col += 2;
            closed = true;
            break;
          }
          i++;
          col++;
        }
        if (!closed) {
          throw LexerException(
              "Unterminated multi-line comment", startLine, startCol);
        }
        continue;
      }

      if (c == "'") {
        while (i < source.length && source[i] != '\n') {
          i++;
          col++;
        }
        continue;
      }

      if (c == '@') {
        final startCol = col;
        if (i + 1 < source.length && _isDigit(source[i + 1])) {
          i++;
          col++;
          final digitStart = i;
          while (i < source.length && _isDigit(source[i])) {
            i++;
            col++;
          }
          emit(TokenType.atTime, source.substring(digitStart, i), startCol);
          continue;
        }
        final start = i;
        i++;
        col++;
        while (i < source.length && _isIdentChar(source[i])) {
          i++;
          col++;
        }
        final word = source.substring(start, i).toLowerCase();
        if (word == '@startuml') {
          emit(TokenType.startUml, word, startCol);
        } else if (word == '@enduml') {
          emit(TokenType.endUml, word, startCol);
        } else if (word == '@startmindmap') {
          emit(TokenType.startMindmap, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inIndentedTreeBody = true;
          indentedTreeEndType = TokenType.endMindmap;
          indentedTreeEndKeyword = '@endmindmap';
        } else if (word == '@endmindmap') {
          emit(TokenType.endMindmap, word, startCol);
        } else if (word == '@startwbs') {
          emit(TokenType.startWbs, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inIndentedTreeBody = true;
          indentedTreeEndType = TokenType.endWbs;
          indentedTreeEndKeyword = '@endwbs';
        } else if (word == '@endwbs') {
          emit(TokenType.endWbs, word, startCol);
        } else if (word == '@startjson') {
          emit(TokenType.startJson, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inDataBody = true;
          dataEndType = TokenType.endJson;
          dataEndKeyword = '@endjson';
        } else if (word == '@endjson') {
          emit(TokenType.endJson, word, startCol);
        } else if (word == '@startyaml') {
          emit(TokenType.startYaml, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inDataBody = true;
          dataEndType = TokenType.endYaml;
          dataEndKeyword = '@endyaml';
        } else if (word == '@endyaml') {
          emit(TokenType.endYaml, word, startCol);
        } else if (word == '@startsalt') {
          emit(TokenType.startSalt, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inDataBody = true;
          dataEndType = TokenType.endSalt;
          dataEndKeyword = '@endsalt';
        } else if (word == '@endsalt') {
          emit(TokenType.endSalt, word, startCol);
        } else if (word == '@startgantt') {
          emit(TokenType.startGantt, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inDataBody = true;
          dataEndType = TokenType.endGantt;
          dataEndKeyword = '@endgantt';
        } else if (word == '@endgantt') {
          emit(TokenType.endGantt, word, startCol);
        } else if (word == '@startnwdiag') {
          emit(TokenType.startNwdiag, word, startCol);
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (i < source.length && source[i] == '\n') {
            emit(TokenType.newline, '\n', col);
            i++;
            line++;
            col = 1;
          }
          inDataBody = true;
          dataEndType = TokenType.endNwdiag;
          dataEndKeyword = '@endnwdiag';
        } else if (word == '@endnwdiag') {
          emit(TokenType.endNwdiag, word, startCol);
        } else {
          throw LexerException('Unknown directive: $word', line, startCol);
        }
        continue;
      }

      if (c == ',') {
        emit(TokenType.comma, ',', col);
        i++;
        col++;
        continue;
      }

      if (c == '{') {
        emit(TokenType.leftBrace, '{', col);
        i++;
        col++;
        continue;
      }

      if (c == '}') {
        final startCol = col;
        final crowLex = _scanCrowFootArrow(source, i);
        if (crowLex != null) {
          emit(TokenType.arrow, crowLex, startCol);
          i += crowLex.length;
          col += crowLex.length;
          continue;
        }
        emit(TokenType.rightBrace, '}', col);
        i++;
        col++;
        continue;
      }

      if (c == '[') {
        emit(TokenType.leftBracket, '[', col);
        i++;
        col++;
        continue;
      }

      if (c == ']') {
        emit(TokenType.rightBracket, ']', col);
        i++;
        col++;
        continue;
      }

      if (c == '(') {
        final startCol = col;
        emit(TokenType.leftParen, '(', startCol);
        i++;
        col++;
        final textStart = i;
        final textStartCol = col;
        while (i < source.length &&
            source[i] != ')' &&
            source[i] != '\n') {
          i++;
          col++;
        }
        final raw = source.substring(textStart, i).trim();
        if (raw.isNotEmpty) {
          emit(TokenType.text, raw, textStartCol);
        }
        if (i < source.length && source[i] == ')') {
          emit(TokenType.rightParen, ')', col);
          i++;
          col++;
        }
        continue;
      }

      if (c == ')') {
        emit(TokenType.rightParen, ')', col);
        i++;
        col++;
        continue;
      }

      if (c == '"') {
        final startCol = col;
        final startLine = line;
        i++;
        col++;
        final buf = StringBuffer();
        while (i < source.length && source[i] != '"') {
          if (source[i] == '\n') {
            throw LexerException(
                'Unterminated string literal', startLine, startCol);
          }
          if (source[i] == '\\' && i + 1 < source.length) {
            final next = source[i + 1];
            if (next == 'n') {
              buf.write('\n');
            } else if (next == '"') {
              buf.write('"');
            } else if (next == '\\') {
              buf.write('\\');
            } else {
              buf.write('\\');
              buf.write(next);
            }
            i += 2;
            col += 2;
            continue;
          }
          buf.write(source[i]);
          i++;
          col++;
        }
        if (i >= source.length) {
          throw LexerException(
              'Unterminated string literal', startLine, startCol);
        }
        i++;
        col++;
        emit(TokenType.stringLiteral, buf.toString(), startCol);
        continue;
      }

      if (c == ':') {
        final startCol = col;
        if (_isInstanceTypeColon(tokens)) {
          emit(TokenType.colon, ':', startCol);
          i++;
          col++;
          continue;
        }
        i++;
        col++;
        final start = i;
        while (i < source.length && source[i] != '\n') {
          i++;
          col++;
        }
        emit(TokenType.colon, ':', startCol);
        final text = source.substring(start, i).trim();
        if (text.isNotEmpty) {
          emit(TokenType.text, text, startCol + 1);
        }
        continue;
      }

      if (c == '-') {
        final startCol = col;
        final lexeme = _scanArrow(source, i);
        if (lexeme != null) {
          emit(TokenType.arrow, lexeme, startCol);
          i += lexeme.length;
          col += lexeme.length;
          continue;
        }
        if (i + 1 < source.length && source[i + 1] == '-') {
          emit(TokenType.minusMinus, '--', startCol);
          i += 2;
          col += 2;
          continue;
        }
        throw LexerException("Unexpected '-'", line, col);
      }

      if (c == '.') {
        final startCol = col;
        if (i + 2 < source.length &&
            source[i + 1] == '.' &&
            source[i + 2] == '.') {
          emit(TokenType.dotDotDot, '...', startCol);
          i += 3;
          col += 3;
          continue;
        }
        final lexeme = _scanArrow(source, i);
        if (lexeme != null) {
          emit(TokenType.arrow, lexeme, startCol);
          i += lexeme.length;
          col += lexeme.length;
          continue;
        }
        if (i + 1 < source.length && source[i + 1] == '.') {
          emit(TokenType.arrow, '..', startCol);
          i += 2;
          col += 2;
          continue;
        }
        throw LexerException("Unexpected '.'", line, col);
      }

      if (c == '*' || c == 'o') {
        final startCol = col;
        final lexeme = _scanArrow(source, i);
        if (lexeme != null) {
          emit(TokenType.arrow, lexeme, startCol);
          i += lexeme.length;
          col += lexeme.length;
          continue;
        }
        if (c == '*' &&
            i + 1 < source.length &&
            source[i + 1] == '*') {
          emit(TokenType.starStar, '**', startCol);
          i += 2;
          col += 2;
          continue;
        }
        if (c == '*') {
          if (tokens.isNotEmpty &&
              tokens.last.type == TokenType.leftBracket) {
            emit(TokenType.identifier, '*', startCol);
            i++;
            col++;
            continue;
          }
          throw LexerException("Unexpected '*'", line, col);
        }
        // 'o' standalone — fall through to identifier scanning below
      }

      if (c == '+') {
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '+') {
          emit(TokenType.plusPlus, '++', startCol);
          i += 2;
          col += 2;
          continue;
        }
        throw LexerException("Unexpected '+'", line, col);
      }

      if (c == '!') {
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '!') {
          emit(TokenType.bangBang, '!!', startCol);
          i += 2;
          col += 2;
          continue;
        }
        throw LexerException("Unexpected '!'", line, col);
      }

      if (c == '=') {
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '=') {
          emit(TokenType.doubleEquals, '==', startCol);
          i += 2;
          col += 2;
          var labelStart = i;
          var labelStartCol = col;
          while (labelStart < source.length &&
              (source[labelStart] == ' ' || source[labelStart] == '\t')) {
            labelStart++;
            labelStartCol++;
          }
          var j = labelStart;
          while (j < source.length && source[j] != '\n') {
            if (j + 1 < source.length &&
                source[j] == '=' &&
                source[j + 1] == '=') {
              break;
            }
            j++;
          }
          final raw = source.substring(labelStart, j);
          final trimmed = raw.trimRight();
          if (trimmed.isNotEmpty) {
            emit(TokenType.text, trimmed, labelStartCol);
          }
          col += j - i;
          i = j;
          if (i + 1 < source.length && source[i] == '=' && source[i + 1] == '=') {
            emit(TokenType.doubleEquals, '==', col);
            i += 2;
            col += 2;
          }
          continue;
        }
        if (i + 1 < source.length && source[i + 1] == '>') {
          emit(TokenType.mapArrow, '=>', startCol);
          i += 2;
          col += 2;
          continue;
        }
        emit(TokenType.equals, '=', startCol);
        i++;
        col++;
        continue;
      }

      if (c == '|') {
        final startCol = col;
        final crowLex = _scanCrowFootArrow(source, i);
        if (crowLex != null) {
          emit(TokenType.arrow, crowLex, startCol);
          i += crowLex.length;
          col += crowLex.length;
          continue;
        }
        if (i + 1 < source.length && source[i + 1] == '|') {
          emit(TokenType.doublePipe, '||', startCol);
          i += 2;
          col += 2;
          final digitStart = i;
          final digitStartCol = col;
          while (i < source.length &&
              source.codeUnitAt(i) >= 0x30 &&
              source.codeUnitAt(i) <= 0x39) {
            i++;
            col++;
          }
          if (i > digitStart) {
            emit(TokenType.text, source.substring(digitStart, i),
                digitStartCol);
          }
          if (i + 1 < source.length && source[i] == '|' && source[i + 1] == '|') {
            emit(TokenType.doublePipe, '||', col);
            i += 2;
            col += 2;
          }
          continue;
        }
        throw LexerException("Unexpected '|'", line, col);
      }

      if (c == '<') {
        final startCol = col;
        final lexeme = _scanArrow(source, i);
        if (lexeme != null) {
          emit(TokenType.arrow, lexeme, startCol);
          i += lexeme.length;
          col += lexeme.length;
          continue;
        }
        if (i + 1 < source.length && source[i + 1] == '<') {
          final close = source.indexOf('>>', i + 2);
          if (close < 0) {
            throw LexerException(
                "Unterminated '<<' stereotype", line, startCol);
          }
          final nl = source.indexOf('\n', i + 2);
          if (nl >= 0 && nl < close) {
            throw LexerException(
                "Unterminated '<<' stereotype", line, startCol);
          }
          final inner = source.substring(i + 2, close).trim();
          emit(TokenType.stereotype, inner, startCol);
          final consumed = close + 2 - i;
          i = close + 2;
          col += consumed;
          continue;
        }
        var depth = 1;
        var j = i + 1;
        final n = source.length;
        var ok = false;
        while (j < n) {
          final ch = source[j];
          if (ch == '\n') break;
          if (ch == '<') {
            depth++;
            j++;
            continue;
          }
          if (ch == '>') {
            depth--;
            j++;
            if (depth == 0) {
              ok = true;
              break;
            }
            continue;
          }
          j++;
        }
        if (!ok) {
          throw LexerException("Unexpected '<'", line, col);
        }
        final inner = source.substring(i + 1, j - 1);
        emit(TokenType.generics, inner, startCol);
        final consumed = j - i;
        i = j;
        col += consumed;
        continue;
      }

      if (c == '#') {
        final startCol = col;
        final start = i;
        i++;
        col++;
        while (i < source.length && _isIdentChar(source[i])) {
          i++;
          col++;
        }
        if (i == start + 1) {
          throw LexerException(
              "Expected color name or hex after '#'", line, startCol);
        }
        emit(TokenType.hashColor, source.substring(start, i), startCol);
        continue;
      }

      if (_isIdentStart(c)) {
        final startCol = col;
        final start = i;
        while (i < source.length) {
          final ch = source[i];
          if (_isIdentChar(ch)) {
            i++;
            col++;
            continue;
          }
          if (ch == '-' &&
              i + 1 < source.length &&
              _isIdentStart(source[i + 1])) {
            i++;
            col++;
            continue;
          }
          break;
        }
        emit(TokenType.identifier, source.substring(start, i), startCol);
        continue;
      }

      throw LexerException("Unexpected character: '$c'", line, col);
    }

    tokens.add(Token(TokenType.eof, '', line, col));
    return tokens;
  }

  static bool _isInstanceTypeColon(List<Token> tokens) {
    var k = tokens.length - 1;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      k--;
    }
    final start = k + 1;
    if (start >= tokens.length) return false;
    final first = tokens[start];
    if (first.type != TokenType.identifier) return false;
    return first.lexeme == 'object' || first.lexeme == 'map';
  }

  static bool _isClassBodyHeader(List<Token> tokens) {
    if (tokens.isEmpty) return false;
    if (tokens.last.type != TokenType.newline) return false;
    var k = tokens.length - 2;
    if (k < 0) return false;
    if (tokens[k].type != TokenType.leftBrace) return false;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      k--;
    }
    final start = k + 1;
    if (start >= tokens.length - 1) return false;
    final first = tokens[start];
    if (first.type != TokenType.identifier) return false;
    const headers = {
      'class',
      'abstract',
      'interface',
      'enum',
      'annotation',
      'exception',
      'object',
      'map',
      'entity',
      'record',
    };
    return headers.contains(first.lexeme);
  }

  static bool _isLegendHeader(List<Token> tokens) {
    if (tokens.isEmpty) return false;
    if (tokens.last.type != TokenType.newline) return false;
    var k = tokens.length - 2;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      k--;
    }
    final start = k + 1;
    if (start >= tokens.length - 1) return false;
    final first = tokens[start];
    if (first.type != TokenType.identifier || first.lexeme != 'legend') {
      return false;
    }
    if (start + 1 == tokens.length - 1) return true;
    final second = tokens[start + 1];
    if (second.type != TokenType.identifier) return false;
    if (second.lexeme != 'left' &&
        second.lexeme != 'right' &&
        second.lexeme != 'center') {
      return false;
    }
    return start + 2 == tokens.length - 1;
  }

  static bool _isMultilineNoteHeader(List<Token> tokens) {
    if (tokens.isEmpty) return false;
    if (tokens.last.type != TokenType.newline) return false;
    var k = tokens.length - 2;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      final t = tokens[k];
      if (t.type == TokenType.colon || t.type == TokenType.text) {
        return false;
      }
      k--;
    }
    final start = k + 1;
    if (start >= tokens.length - 1) return false;
    final first = tokens[start];
    if (first.type != TokenType.identifier || first.lexeme != 'note') {
      return false;
    }
    if (start + 1 >= tokens.length - 1) return false;
    final second = tokens[start + 1];
    if (second.type != TokenType.identifier) return false;
    int afterPosition;
    if (second.lexeme == 'left' || second.lexeme == 'right') {
      if (start + 2 >= tokens.length - 1) return false;
      final third = tokens[start + 2];
      if (third.type != TokenType.identifier || third.lexeme != 'of') {
        return false;
      }
      afterPosition = start + 3;
    } else if (second.lexeme == 'over') {
      afterPosition = start + 2;
    } else {
      return false;
    }
    if (afterPosition >= tokens.length - 1) return false;
    if (tokens[afterPosition].type != TokenType.identifier) return false;
    var k2 = afterPosition + 1;
    while (k2 < tokens.length - 1) {
      final t = tokens[k2];
      if (t.type == TokenType.newline) break;
      if (t.type != TokenType.comma) return false;
      k2++;
      if (k2 >= tokens.length - 1 ||
          tokens[k2].type != TokenType.identifier) {
        return false;
      }
      k2++;
    }
    return true;
  }

  static bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x30 && code <= 0x39) ||
        c == '_';
  }

  static bool _isIdentChar(String c) => _isIdentStart(c);

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static const _crowFootLeftEnds = ['||', '|o', '}o', '}|'];
  static const _crowFootRightEnds = ['||', 'o|', 'o{', '|{'];

  static String? _scanCrowFootArrow(String source, int i) {
    final n = source.length;
    if (i + 2 > n) return null;
    final left = source.substring(i, i + 2);
    if (!_crowFootLeftEnds.contains(left)) return null;
    var j = i + 2;
    if (j >= n) return null;
    final bodyChar = source[j];
    if (bodyChar != '-' && bodyChar != '.') return null;
    while (j < n && source[j] == bodyChar) {
      j++;
    }
    if (j + 2 > n) return null;
    final right = source.substring(j, j + 2);
    if (!_crowFootRightEnds.contains(right)) return null;
    return source.substring(i, j + 2);
  }

  static String? _scanArrow(String source, int i) {
    final start = i;
    final n = source.length;
    if (i >= n) return null;
    final first = source[i];

    int? consumeBody(int j) {
      var k = j;
      var sawDashes = false;
      var sawDots = false;
      while (k < n && source[k] == '-') {
        sawDashes = true;
        k++;
      }
      while (k < n && source[k] == '.') {
        sawDots = true;
        k++;
      }
      if (k < n && source[k] == '[') {
        final close = source.indexOf(']', k + 1);
        if (close < 0) return null;
        k = close + 1;
        while (k < n && source[k] == '-') {
          sawDashes = true;
          k++;
        }
        while (k < n && source[k] == '.') {
          sawDots = true;
          k++;
        }
      }
      if (!sawDashes && !sawDots) return null;
      return k;
    }

    if (first == '-') {
      var j = i + 1;
      if (j < n && source[j] == '-') j++;
      if (j < n && source[j] == '[') {
        final close = source.indexOf(']', j + 1);
        if (close < 0) return null;
        j = close + 1;
        if (j >= n) return null;
        if (source[j] == '-') {
          j++;
          if (j < n && source[j] == '-') j++;
        } else if (source[j] == '.') {
          while (j < n && source[j] == '.') {
            j++;
          }
        } else {
          return null;
        }
      }
      if (j < n && source[j] == '.') {
        while (j < n && source[j] == '.') {
          j++;
        }
      }
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        return source.substring(start, j);
      }
      if (j < n && source[j] == '|') {
        j++;
        if (j < n && source[j] == '>') {
          j++;
          return source.substring(start, j);
        }
        return null;
      }
      if (j < n && (source[j] == '*' || source[j] == 'o')) {
        j++;
        return source.substring(start, j);
      }
      return null;
    }
    if (first == '.') {
      var j = i + 1;
      if (j >= n || source[j] != '.') return null;
      j++;
      while (j < n && source[j] == '.') {
        j++;
      }
      if (j < n && source[j] == '>') {
        j++;
        return source.substring(start, j);
      }
      if (j < n && source[j] == '|') {
        j++;
        if (j < n && source[j] == '>') {
          j++;
          return source.substring(start, j);
        }
        return null;
      }
      if (j < n && (source[j] == '*' || source[j] == 'o')) {
        j++;
        return source.substring(start, j);
      }
      return null;
    }
    if (first == '*' || first == 'o') {
      var j = i + 1;
      final after = consumeBody(j);
      if (after == null) return null;
      j = after;
      if (j < n && source[j] == '>') {
        j++;
        return source.substring(start, j);
      }
      if (j < n && source[j] == '|') {
        j++;
        if (j < n && source[j] == '>') {
          j++;
          return source.substring(start, j);
        }
        return null;
      }
      if (j < n && (source[j] == '*' || source[j] == 'o')) {
        j++;
        return source.substring(start, j);
      }
      return source.substring(start, j);
    }
    if (first == '<') {
      var j = i + 1;
      if (j < n && source[j] == '<') {
        j++;
        if (j >= n || source[j] != '-') return null;
        j++;
        if (j < n && source[j] == '-') j++;
        if (j < n && source[j] == '[') {
          final close = source.indexOf(']', j + 1);
          if (close < 0) return null;
          j = close + 1;
          if (j >= n || source[j] != '-') return null;
          j++;
          if (j < n && source[j] == '-') j++;
        }
        return source.substring(start, j);
      }
      if (j < n && source[j] == '|') {
        j++;
        final after = consumeBody(j);
        if (after == null) return null;
        j = after;
        return source.substring(start, j);
      }
      if (j >= n) return null;
      if (source[j] == '-' || source[j] == '.') {
        final after = consumeBody(j);
        if (after == null) return null;
        j = after;
        if (j < n && (source[j] == '*' || source[j] == 'o')) {
          j++;
        }
        return source.substring(start, j);
      }
      return null;
    }
    return null;
  }
}
