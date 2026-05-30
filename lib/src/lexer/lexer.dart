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
    var inTitleBody = false;
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
          col += raw.length;
          i = end;
          continue;
        }
        // Multi-line `<marker>:body...;` accumulation. Detect a leading
        // `+`/`-`/`*` marker followed by `:` (with optional `[#color]` between
        // them) whose closing `;` is NOT on the same line. Concatenate
        // subsequent lines (joined with `\n`) into the same text token until we
        // hit one whose last non-whitespace character is `;`. This lets the
        // parser handle Creole/HTML markup, lists, headings, and horizontal
        // rules inside `**:..;` bodies as opaque label content.
        if (trimmed.isNotEmpty && _isMultilineMarkerBodyOpen(trimmed)) {
          final buf = StringBuffer(trimmed);
          col += raw.length;
          i = end;
          // Track whether we're currently inside a `<code>...</code>` (or
          // similar verbatim) block. A `;` at the end of a line inside such a
          // block must NOT terminate the multi-line body — only a line that
          // is exactly `;` (after trimming) or a line that ends with `;`
          // outside any verbatim block terminates accumulation.
          var codeDepth = _verbatimDepthDelta(trimmed);
          while (i < source.length && source[i] == '\n') {
            i++;
            line++;
            col = 1;
            // Accumulate until we see a terminator line.
            var innerEnd = i;
            while (innerEnd < source.length && source[innerEnd] != '\n') {
              innerEnd++;
            }
            final innerRaw = source.substring(i, innerEnd);
            final innerTrim = innerRaw.trim();
            if (innerTrim.toLowerCase() == indentedTreeEndKeyword) {
              // Body unterminated at end-of-diagram — emit what we have and
              // let the end keyword be handled on the next outer iteration.
              break;
            }
            buf.write('\n');
            buf.write(innerTrim);
            col += innerRaw.length;
            i = innerEnd;
            // A lone `;` line always terminates. Otherwise only terminate on
            // a `;`-ending line when we are NOT inside a verbatim block.
            if (innerTrim == ';') {
              break;
            }
            codeDepth += _verbatimDepthDelta(innerTrim);
            if (codeDepth <= 0 && innerTrim.endsWith(';')) {
              break;
            }
          }
          emit(TokenType.text, buf.toString(), 1);
          continue;
        }
        if (trimmed.isNotEmpty) {
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
        final trimmed = raw.trim();
        if (trimmed == 'end note' ||
            trimmed == 'endnote' ||
            trimmed == 'endrnote' ||
            trimmed == 'endhnote') {
          inNoteBody = false;
          if (trimmed == 'end note') {
            final endIdx = raw.indexOf('end');
            emit(TokenType.identifier, 'end', col + endIdx);
            final noteIdx = raw.indexOf('note', endIdx + 3);
            emit(TokenType.identifier, 'note', col + noteIdx);
          } else {
            final idx = raw.indexOf(trimmed);
            emit(TokenType.identifier, trimmed, col + idx);
          }
        } else if (trimmed == 'end ref' || trimmed == 'endref') {
          inNoteBody = false;
          if (trimmed == 'end ref') {
            final endIdx = raw.indexOf('end');
            emit(TokenType.identifier, 'end', col + endIdx);
            final refIdx = raw.indexOf('ref', endIdx + 3);
            emit(TokenType.identifier, 'ref', col + refIdx);
          } else {
            final idx = raw.indexOf(trimmed);
            emit(TokenType.identifier, trimmed, col + idx);
          }
        } else {
          emit(TokenType.text, trimmed, col);
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

      if (inTitleBody && col == 1 && i < source.length && source[i] != '\n') {
        var end = i;
        while (end < source.length && source[end] != '\n') {
          end++;
        }
        final raw = source.substring(i, end);
        final trimmed = raw.trim();
        if (trimmed == 'end title') {
          inTitleBody = false;
          final endIdx = raw.indexOf('end');
          emit(TokenType.identifier, 'end', col + endIdx);
          final titleIdx = raw.indexOf('title', endIdx + 3);
          emit(TokenType.identifier, 'title', col + titleIdx);
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
        if (_isTitleHeader(tokens)) {
          inTitleBody = true;
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

      // PlantUML accepts `;` as an optional statement terminator on many
      // constructs (e.g. activity arrow labels `-> text;`, stray line
      // terminators). The colon-scanner already absorbs `;` as text for
      // `:foo;` actions and the `#color;key:value` inline-style lexer
      // consumes its own internal `;`. Anywhere else, a bare `;` is benign
      // punctuation that we drop as whitespace so downstream parsers see a
      // clean token stream.
      if (c == ';') {
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

      if (c == '/') {
        final startCol = col;
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        // PlantUML sequence-diagram sync marker: a bare `/` at line start
        // (followed only by whitespace and a newline/EOF) means "place the
        // next event at the same Y as the previous one". Emit a dedicated
        // token so the parser can recognize it; visual alignment is
        // currently deferred and the parser consumes it as a no-op.
        if (_isLineStart(tokens)) {
          var k = i + 1;
          while (k < source.length &&
              (source[k] == ' ' || source[k] == '\t')) {
            k++;
          }
          if (k >= source.length || source[k] == '\n' || source[k] == '\r') {
            emit(TokenType.slash, '/', startCol);
            i++;
            col++;
            continue;
          }
        }
        // PlantUML use-case/actor "phantom" / hidden-node marker: a trailing
        // `/` immediately after a node declaration (e.g. `(Name)/`,
        // `usecase/ UC3`, `actor/ Woman3`). The marker is followed by a
        // whitespace, newline, or EOF — never by an identifier character —
        // which disambiguates it from a `/` that would otherwise belong to
        // an arrow body (already handled above). Emit a dedicated slash
        // token so the parser can consume it as a no-op modifier. Visual
        // hiding is currently deferred.
        if (i + 1 >= source.length ||
            source[i + 1] == ' ' ||
            source[i + 1] == '\t' ||
            source[i + 1] == '\n' ||
            source[i + 1] == '\r') {
          emit(TokenType.slash, '/', startCol);
          i++;
          col++;
          continue;
        }
        throw LexerException("Unexpected '/'", line, col);
      }

      if (c == '\\') {
        final startCol = col;
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        // Accept `\n` literal as an escaped-newline token. PlantUML embeds
        // `\n` inside bracketed names / labels to force a line break.
        // Parsers that care convert the lexeme to a real newline; others
        // can join it as a no-op space.
        if (i + 1 < source.length && source[i + 1] == 'n') {
          emit(TokenType.text, r'\n', startCol);
          i += 2;
          col += 2;
          continue;
        }
        throw LexerException("Unexpected '\\'", line, col);
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
        // Timing-diagram anchor forms (captured as a single `atTime` lexeme so
        // the parser sees one token regardless of inner punctuation):
        //   @<digits>[:<digits>[:<digits>]]     time / H:M:S
        //   @<digits>/<digits>/<digits>         date YYYY/MM/DD
        //   @<digits>[+-]<...>                  arithmetic
        //   @-<digits> / @+<digits>             negative/positive relative
        //   @:<label>[+-N]                      labeled anchor
        //   @<ident>[+-N]                       lane-focus / named anchor
        // Anything starting with `@start...`/`@end...` (a letter immediately
        // after `@`) is treated as a directive keyword by the fallthrough
        // below.
        if (i + 1 < source.length &&
            (_isDigit(source[i + 1]) ||
                source[i + 1] == ':' ||
                source[i + 1] == '-' ||
                source[i + 1] == '+')) {
          i++;
          col++;
          final lexStart = i;
          while (i < source.length) {
            final ch = source[i];
            if (_isDigit(ch) ||
                ch == ':' ||
                ch == '/' ||
                ch == '+' ||
                ch == '-' ||
                ch == '.' ||
                _isIdentChar(ch)) {
              i++;
              col++;
              continue;
            }
            break;
          }
          emit(TokenType.atTime, source.substring(lexStart, i), startCol);
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
        } else if (word == '@startebnf') {
          emit(TokenType.startEbnf, word, startCol);
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
          dataEndType = TokenType.endEbnf;
          dataEndKeyword = '@endebnf';
        } else if (word == '@endebnf') {
          emit(TokenType.endEbnf, word, startCol);
        } else if (word == '@startregex') {
          emit(TokenType.startEbnf, '@startebnf', startCol);
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
          dataEndType = TokenType.endEbnf;
          dataEndKeyword = '@endregex';
        } else if (word == '@endregex') {
          emit(TokenType.endEbnf, '@endebnf', startCol);
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
        } else if (word == '@unlinked') {
          // PlantUML class-diagram selector used by `hide` / `remove`
          // directives. Emit as a generic identifier so the parser can consume
          // it as part of the `hide`/`remove` rest-of-line.
          emit(TokenType.identifier, word, startCol);
        } else if (word.length > 1 && !word.startsWith('@start') &&
            !word.startsWith('@end')) {
          // Timing-diagram lane-focus anchor: `@<laneName>` selects the lane
          // for the relative-time statements that follow. The lexeme drops the
          // leading `@` so the parser can use it as an alias reference (the
          // original case is preserved). Any arithmetic suffix (`+N`/`-N`) is
          // captured as part of the same atTime lexeme.
          var rest = source.substring(start + 1, i);
          while (i < source.length &&
              (source[i] == '+' || source[i] == '-' ||
                  source[i] == '*' ||
                  _isDigit(source[i]) || _isIdentChar(source[i]))) {
            rest += source[i];
            i++;
            col++;
          }
          emit(TokenType.atTime, rest, startCol);
        } else {
          throw LexerException("Unknown directive '$word'", line, startCol);
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
        // Single-line class body: `class X { +a() ; ... }` — when this `{` was
        // emitted on a line that begins with a class-header keyword and the
        // matching `}` appears on the same line, capture the body content as
        // a sequence of text tokens (one per `;`-separated segment) so the
        // parser's class-body branch processes them like a multi-line body.
        if (_isSingleLineClassBodyOpen(tokens)) {
          var j = i;
          while (j < source.length && source[j] != '\n' && source[j] != '}') {
            j++;
          }
          if (j < source.length && source[j] == '}') {
            final raw = source.substring(i, j);
            for (final seg in raw.split(';')) {
              final t = seg.trim();
              if (t.isEmpty) continue;
              emit(TokenType.text, t, col);
            }
            col += j - i;
            i = j;
            emit(TokenType.rightBrace, '}', col);
            i++;
            col++;
          }
        }
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
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        emit(TokenType.rightBrace, '}', col);
        i++;
        col++;
        continue;
      }

      if (c == '[') {
        final startCol = col;
        // PlantUML sequence found-message: `[->`, `[-->`, `[->>`, etc. start
        // with a `[` glyph in arrow-start position. Try the arrow scanner
        // first; if it matches we emit a single `arrow` token. Otherwise
        // fall back to the normal `leftBracket` punctuation.
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        // PlantUML multi-line bracketed description body: a `[` followed only
        // by whitespace and a newline opens a free-form text block that
        // extends to the matching closing `]`. Absorb the body verbatim as a
        // single `text` token so embedded Creole separators (`----`, `====`,
        // `....`) and inline markup (`<b>`, `<color:...>`) survive without
        // tripping the normal punctuation scanner. The parser then sees:
        // leftBracket, text, rightBracket, which it already handles via the
        // multi-line bracket block path.
        var k = i + 1;
        while (k < source.length &&
            (source[k] == ' ' || source[k] == '\t')) {
          k++;
        }
        if (k < source.length && (source[k] == '\n' || source[k] == '\r')) {
          emit(TokenType.leftBracket, '[', startCol);
          i = k;
          // Advance over the trailing whitespace + newline ourselves so the
          // body capture starts on the next line.
          while (i < source.length && source[i] != '\n') {
            if (source[i] == '\r') {
              i++;
            } else {
              i++;
            }
          }
          if (i < source.length && source[i] == '\n') {
            i++;
            line++;
            col = 1;
          }
          final bodyStart = i;
          // Walk lines until we find a line whose first non-whitespace char
          // is `]` (the closing marker). Allow any inner content verbatim,
          // including blank lines and embedded `[` (won't open a nested block
          // here — the whole body is opaque).
          while (i < source.length) {
            // Check if current line starts with `]` (after optional indent).
            var ls = i;
            while (ls < source.length &&
                (source[ls] == ' ' || source[ls] == '\t')) {
              ls++;
            }
            if (ls < source.length && source[ls] == ']') {
              // Emit captured body (trim trailing newline) as a text token.
              final raw = source.substring(bodyStart, i);
              if (raw.isNotEmpty) {
                emit(TokenType.text, raw, 1);
              }
              col = (ls - i) + 1;
              i = ls;
              emit(TokenType.rightBracket, ']', col);
              i++;
              col++;
              break;
            }
            // Advance to end of line.
            while (i < source.length && source[i] != '\n') {
              i++;
            }
            if (i < source.length && source[i] == '\n') {
              i++;
              line++;
              col = 1;
            } else {
              break;
            }
          }
          continue;
        }
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

      if (c == '?') {
        final startCol = col;
        // PlantUML sequence short-found message: `?->`, `?-->`, `?->>`. The
        // `?` sigil on the left of an arrow body starts a message whose
        // source is an anonymous short stub. There is no other PlantUML use
        // of a bare `?` at this lexer position, so if the arrow scan fails
        // we report it as unexpected.
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        throw LexerException("Unexpected '?'", line, col);
      }

      if (c == '(') {
        final startCol = col;
        // PlantUML sequence "arrow with duration" — `(N)<-`, `(N)<--` etc.
        // The `(<digits>)` segment sits IMMEDIATELY before a backward arrow
        // body. Try the arrow scanner first so the whole construct tokenizes
        // as a single `arrow` token; if it doesn't match, fall back to the
        // normal parenthesized-text behaviour used by `usecase` labels.
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
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
        // PlantUML chained-lollipop arrow starting with `)`: `)-0-(0`,
        // `)-(0-`, `)-0)-`. Try arrow scan first; fall back to plain
        // rightParen.
        if (i + 1 < source.length &&
            (source[i + 1] == '-' || source[i + 1] == '.')) {
          final startCol = col;
          final arrowLex = _scanArrow(source, i);
          if (arrowLex != null) {
            emit(TokenType.arrow, arrowLex, startCol);
            i += arrowLex.length;
            col += arrowLex.length;
            continue;
          }
        }
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
        // Strings may span multiple source lines. Embedded newlines are
        // preserved verbatim in the lexeme so downstream parsers (e.g. the
        // use-case diagram with multi-line labels and `--`/`==`/`..` section
        // separators) can examine the raw structure.
        while (i < source.length && source[i] != '"') {
          if (source[i] == '\n') {
            buf.write('\n');
            i++;
            line++;
            col = 1;
            continue;
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
        // `::` separator inside a qualified class name (e.g. `X1::X2::foo`).
        // When the previous emitted token is an identifier and the input has
        // `::` followed by an ident-start char, coalesce the separator and
        // the following identifier run into the previous token's lexeme so
        // downstream parsing sees a single identifier.
        if (i + 2 < source.length &&
            source[i + 1] == ':' &&
            _isIdentStart(source[i + 2]) &&
            tokens.isNotEmpty &&
            tokens.last.type == TokenType.identifier) {
          var j = i + 2;
          while (j < source.length) {
            if (_isIdentChar(source[j])) {
              j++;
              continue;
            }
            if (j + 1 < source.length &&
                source[j] == ':' &&
                source[j + 1] == ':') {
              j += 2;
              continue;
            }
            break;
          }
          // Trim a trailing `::` (left dangling — shouldn't normally happen).
          while (j > i + 2 && source[j - 1] == ':') {
            j--;
          }
          final suffix = source.substring(i, j);
          final prev = tokens.removeLast();
          tokens.add(Token(
            TokenType.identifier,
            prev.lexeme + suffix,
            prev.line,
            prev.column,
          ));
          col += j - i;
          i = j;
          continue;
        }
        if (_isInstanceTypeColon(tokens)) {
          emit(TokenType.colon, ':', startCol);
          i++;
          col++;
          continue;
        }
        // Colon-wrapped actor declaration `:Name:` at line start, with an
        // arrow or further structure following on the same line:
        //   `:user: --> (Use case 1)`
        // Without special handling, the colon scanner below greedily eats
        // the entire rest of the line as the colon's "message text" — which
        // means the trailing arrow/ellipse is hidden from the parser. By
        // detecting this shape and emitting only `:` + `text(Name)` + `:`,
        // we leave the remainder of the line to tokenize normally as an
        // arrow + parenthesized use-case target. The pattern matches only
        // when the leading colon is at line start.
        if (_isLineStart(tokens)) {
          final inner = _scanColonWrappedActor(source, i);
          if (inner != null) {
            // `inner` is the inclusive index of the CLOSING `:` on the same
            // line. Emit `colon`, `text(name)`, `colon` and let the main
            // loop continue from one past the closing colon.
            emit(TokenType.colon, ':', startCol);
            final nameStart = i + 1;
            final name = source.substring(nameStart, inner).trim();
            if (name.isNotEmpty) {
              emit(TokenType.text, name, startCol + 1);
            }
            // Advance past `:Name:` so the residual `--> (...)` content
            // tokenizes through the normal lexer paths below.
            final consumed = inner - i + 1;
            col += consumed;
            i = inner + 1;
            emit(TokenType.colon, ':', col - 1);
            continue;
          }
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
        // Negative number literal: `-<digit>...`. Used in inline JSON arrays
        // inside `@startuml` blocks (e.g. `[-1, -1.1]`). Emit as an
        // identifier so token-level brace-block reconstruction can replay
        // the literal verbatim into the JSON decoder.
        if (i + 1 < source.length && _isDigit(source[i + 1])) {
          final start = i;
          i++;
          col++;
          while (i < source.length &&
              (_isDigit(source[i]) || source[i] == '.')) {
            i++;
            col++;
          }
          emit(TokenType.identifier, source.substring(start, i), startCol);
          continue;
        }
        // Class diagram visibility prefix on a class-header keyword at the
        // start of a line: `-class`, `-interface`, etc. Drop the `-` and
        // continue lexing the keyword.
        if (_isLineStart(tokens) && _isVisibilityPrefixedHeader(source, i)) {
          i++;
          col++;
          continue;
        }
        // Single `-` as a class-diagram association arrow: `Foo - Bar`.
        // Emit as `minusMinus` so the relationship parser treats it like `--`.
        if (i + 1 < source.length &&
            (source[i + 1] == ' ' || source[i + 1] == '\t')) {
          emit(TokenType.minusMinus, '-', startCol);
          i++;
          col++;
          continue;
        }
        // Activity-diagram bullet/stereotype shortcut at line start:
        // `-<<stereotype>>...` is a `-`-prefixed action whose leading
        // stereotype rides the same line. Emit `-` as a `minusMinus` token
        // so the activity parser's bullet path picks it up. Without this,
        // the lexer would throw and reject the otherwise legal source.
        if (_isLineStart(tokens) &&
            i + 1 < source.length &&
            source[i + 1] == '<') {
          emit(TokenType.minusMinus, '-', startCol);
          i++;
          col++;
          continue;
        }
        // Timing-diagram `{-}` shorthand: a `-` token between braces is a
        // hidden-state marker. Emit as an identifier so the timing-state
        // reader can incorporate it into the brace block.
        if (i + 1 < source.length && source[i + 1] == '}') {
          emit(TokenType.identifier, '-', startCol);
          i++;
          col++;
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
          // `... text ...` captures the inline text between the two markers
          // so inline markup like `~~` doesn't get re-tokenized.
          if (_isLineStart(tokens.sublist(0, tokens.length - 1))) {
            var j = i;
            while (j < source.length &&
                source[j] != '\n' &&
                !(j + 2 < source.length &&
                    source[j] == '.' &&
                    source[j + 1] == '.' &&
                    source[j + 2] == '.')) {
              j++;
            }
            final raw = source.substring(i, j).trim();
            if (raw.isNotEmpty) {
              emit(TokenType.text, raw, col);
            }
            col += j - i;
            i = j;
            if (i + 2 < source.length &&
                source[i] == '.' &&
                source[i + 1] == '.' &&
                source[i + 2] == '.') {
              emit(TokenType.dotDotDot, '...', col);
              i += 3;
              col += 3;
            } else if (raw.isEmpty && i < source.length && source[i] == '\n') {
              // Multi-line delay form:
              //   ...
              //   Some ~~text~~
              //   ...
              // Conservative: consume the next single non-empty line as the
              // delay label only when the line *after* that is a standalone
              // `...`. This avoids swallowing valid statements after a bare
              // `...` separator (`...\n[-> Bob\n...`).
              final midStart = i + 1;
              var midEnd = midStart;
              while (midEnd < source.length && source[midEnd] != '\n') {
                midEnd++;
              }
              final midText = source.substring(midStart, midEnd).trim();
              // Sniff for the closing `...` on the very next line.
              final afterMid = midEnd + 1;
              var closeEnd = afterMid;
              while (closeEnd < source.length && source[closeEnd] != '\n') {
                closeEnd++;
              }
              final closeText =
                  source.substring(afterMid, closeEnd).trim();
              if (midText.isNotEmpty && closeText == '...') {
                emit(TokenType.text, midText, 1);
                // Advance to the start of the closing `...` (skip any
                // leading whitespace on that line).
                var k = afterMid;
                while (k < closeEnd &&
                    (source[k] == ' ' || source[k] == '\t')) {
                  k++;
                }
                i = k;
                line += 2;
                col = (k - afterMid) + 1;
                emit(TokenType.dotDotDot, '...', col);
                i += 3;
                col += 3;
              }
            }
          }
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
        // PlantUML class-diagram short-form dotted association: a single `.`
        // between identifiers acts like `..` (dashed link). Accept when the
        // dot sits between whitespace so we don't disturb the dotted-ident
        // coalescing or the `...` paragraph marker handling above.
        if (i + 1 < source.length &&
            (source[i + 1] == ' ' || source[i + 1] == '\t')) {
          emit(TokenType.arrow, '.', startCol);
          i++;
          col++;
          continue;
        }
        // Trailing `.` after an identifier (followed by whitespace, newline or
        // EOF): absorb the dot into the preceding identifier (`Proc.`, `etc.`).
        if (tokens.isNotEmpty &&
            tokens.last.type == TokenType.identifier &&
            (i + 1 >= source.length ||
                source[i + 1] == ' ' ||
                source[i + 1] == '\t' ||
                source[i + 1] == '\n' ||
                source[i + 1] == '\r')) {
          final prev = tokens.removeLast();
          tokens.add(Token(
            TokenType.identifier,
            '${prev.lexeme}.',
            prev.line,
            prev.column,
          ));
          i++;
          col++;
          continue;
        }
        // Dotted identifier continuation: when the previous emitted token is
        // an identifier and the next char is identifier-start, treat the dot
        // as part of a qualified identifier (e.g. `foo1.foo2.foo3`). Coalesce
        // the dot and the following identifier run into the previous token's
        // lexeme so downstream parsing sees a single identifier.
        if (tokens.isNotEmpty &&
            tokens.last.type == TokenType.identifier &&
            i + 1 < source.length &&
            _isIdentStart(source[i + 1])) {
          var j = i + 1;
          while (j < source.length &&
              (_isIdentChar(source[j]) || source[j] == '.')) {
            j++;
          }
          // Avoid eating a trailing `.` not followed by ident — back off.
          while (j > i + 1 && source[j - 1] == '.') {
            j--;
          }
          final suffix = source.substring(i, j);
          final prev = tokens.removeLast();
          tokens.add(Token(
            TokenType.identifier,
            prev.lexeme + suffix,
            prev.line,
            prev.column,
          ));
          col += j - i;
          i = j;
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
          // PlantUML state-diagram history pseudo-state `[H*]`: the `*` follows
          // an identifier that itself follows a `[` (e.g. `[H*]`, `State3[H*]`).
          // Emit as an identifier so the bracketed name parses cleanly. The
          // closing `]` keeps the construct unambiguous.
          if (tokens.length >= 2 &&
              tokens.last.type == TokenType.identifier &&
              tokens[tokens.length - 2].type == TokenType.leftBracket) {
            emit(TokenType.identifier, '*', startCol);
            i++;
            col++;
            continue;
          }
          // `remove *` (and `hide *` / `show *` / `restore *`) — wildcard
          // selector for class-diagram directives. Emit as identifier so the
          // parser's rest-of-line consumer can swallow it.
          if (tokens.isNotEmpty &&
              tokens.last.type == TokenType.identifier &&
              const {'remove', 'hide', 'show', 'restore'}
                  .contains(tokens.last.lexeme)) {
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
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        // Visibility prefix on class-header keyword: `+class "X" { }`.
        if (_isLineStart(tokens) && _isVisibilityPrefixedHeader(source, i)) {
          i++;
          col++;
          continue;
        }
        // Timing-diagram relative-time anchor at line start: `+<digits>`
        // selects the current lane's last anchor + N. Emit as an identifier
        // with a `+`-prefixed lexeme so the timing parser can decode it.
        if (_isLineStart(tokens) &&
            i + 1 < source.length &&
            _isDigit(source[i + 1])) {
          final start = i;
          i++;
          col++;
          while (i < source.length && _isDigit(source[i])) {
            i++;
            col++;
          }
          emit(TokenType.identifier, source.substring(start, i), startCol);
          continue;
        }
        throw LexerException("Unexpected '+'", line, col);
      }

      if (c == '~') {
        // Visibility prefix on class-header keyword: `~class "X" { }`.
        if (_isLineStart(tokens) && _isVisibilityPrefixedHeader(source, i)) {
          i++;
          col++;
          continue;
        }
        // PlantUML wavy-line relation arrow: `~~`, `~~>`, `~~~~`, etc. Treat
        // as a dashed/wavy connector arrow for relation lines (e.g. component
        // diagram `node1 ~~ node4`). Scan a run of `~` plus an optional `>`
        // head so the parser sees a single arrow token. Also supports a
        // direction-hint with embedded lollipop (`~up(0)~>`, `~le(0)~>`),
        // and a trailing `(` lollipop marker (`#~~(`).
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '~') {
          var j = i + 1;
          while (j < source.length && source[j] == '~') {
            j++;
          }
          if (j < source.length && source[j] == '>') {
            j++;
            if (j < source.length && source[j] == '>') j++;
          } else if (j < source.length && source[j] == '(') {
            // Trailing lollipop marker `~~(` or `~~(0)`.
            j++;
            while (j < source.length && _isDigit(source[j])) {
              j++;
            }
            if (j < source.length && source[j] == ')') j++;
          }
          emit(TokenType.arrow, source.substring(i, j), startCol);
          col += j - i;
          i = j;
          continue;
        }
        // Single `~` followed by a direction-hint and lollipop:
        // `~up(0)~>`, `~le(0)~>`, `~ri(0)~>`, `~do(0)~>`.
        {
          var j = i + 1;
          var matched = false;
          for (final dir in const [
            'left', 'right', 'up', 'down', 'le', 'ri', 'do'
          ]) {
            if (j + dir.length < source.length &&
                source.substring(j, j + dir.length) == dir &&
                (source[j + dir.length] == '(' ||
                    source[j + dir.length] == '~' ||
                    _isDigit(source[j + dir.length]))) {
              j += dir.length;
              matched = true;
              break;
            }
          }
          if (matched) {
            if (j < source.length && source[j] == '(') {
              var k = j + 1;
              while (k < source.length && _isDigit(source[k])) {
                k++;
              }
              if (k < source.length && source[k] == ')') {
                j = k + 1;
              }
            } else if (j < source.length && _isDigit(source[j])) {
              while (j < source.length && _isDigit(source[j])) {
                j++;
              }
              if (j < source.length && source[j] == ')') j++;
            }
            while (j < source.length && source[j] == '~') {
              j++;
            }
            if (j < source.length && source[j] == '>') {
              j++;
              if (j < source.length && source[j] == '>') j++;
            }
            emit(TokenType.arrow, source.substring(i, j), startCol);
            col += j - i;
            i = j;
            continue;
          }
        }
        throw LexerException("Unexpected '~'", line, col);
      }

      if (c == '&' && _isLineStart(tokens)) {
        emit(TokenType.amp, '&', col);
        i++;
        col++;
        continue;
      }

      // `$` is now treated as a valid identifier-start character (see
      // `_isIdentStart`) so `$tag` / `$C1` tokens flow through the generic
      // identifier branch below. The previous line-start `$xxx` comment
      // behaviour has been dropped — PlantUML's `$xxx` is a preprocessor
      // variable reference, not a comment.

      if (c == '!') {
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '!') {
          if (_isLineStart(tokens)) {
            while (i < source.length && source[i] != '\n') {
              i++;
              col++;
            }
            continue;
          }
          emit(TokenType.bangBang, '!!', startCol);
          i += 2;
          col += 2;
          continue;
        }
        if (_isLineStart(tokens)) {
          final lineEnd = source.indexOf('\n', i);
          final lineText = source
              .substring(i + 1, lineEnd < 0 ? source.length : lineEnd)
              .trimLeft()
              .toLowerCase();
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          if (lineText.startsWith('procedure') ||
              lineText.startsWith('unquoted procedure') ||
              lineText.startsWith('final procedure') ||
              lineText.startsWith('function') ||
              lineText.startsWith('unquoted function') ||
              lineText.startsWith('final function') ||
              lineText.startsWith('return function') ||
              lineText.startsWith('definelong')) {
            while (i < source.length) {
              if (source[i] == '\n') {
                i++;
                line++;
                col = 1;
                continue;
              }
              if (col == 1 && source[i] == '!') {
                final e = source.indexOf('\n', i);
                final text = source
                    .substring(i + 1, e < 0 ? source.length : e)
                    .trimLeft()
                    .toLowerCase();
                if (text.startsWith('endprocedure') ||
                    text.startsWith('endfunction') ||
                    text.startsWith('enddefinelong')) {
                  while (i < source.length && source[i] != '\n') {
                    i++;
                    col++;
                  }
                  break;
                }
              }
              i++;
              col++;
            }
          }
          continue;
        }
        throw LexerException("Unexpected '!'", line, col);
      }

      if (c == '=') {
        final startCol = col;
        if (i + 1 < source.length && source[i + 1] == '=') {
          // `==` only acts as a section-divider marker at line start. Mid-line
          // `==` (e.g. `node1 == node5` in a component diagram) is a bold
          // connector arrow — scan as such so the relation parser sees one
          // arrow token between the two endpoints.
          if (!_isLineStart(tokens)) {
            var j = i + 1;
            while (j < source.length && source[j] == '=') {
              j++;
            }
            if (j < source.length && source[j] == '>') {
              j++;
              if (j < source.length && source[j] == '>') j++;
            }
            emit(TokenType.arrow, source.substring(i, j), startCol);
            col += j - i;
            i = j;
            continue;
          }
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
          // PlantUML shorthand `|||` = opening `||` + closing `|` (no count).
          // Only kick in when EXACTLY three pipes (next char isn't another |).
          if (i < source.length &&
              source[i] == '|' &&
              (i + 1 >= source.length || source[i + 1] != '|')) {
            emit(TokenType.doublePipe, '||', col);
            i += 1;
            col += 1;
            continue;
          }
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
        // PlantUML `<style>` ... `</style>` block: CSS-like declarations that
        // customize rendering. We consume-and-ignore the entire block so the
        // surrounding diagram source still parses. Style application is
        // deferred. Match is case-insensitive on the opening tag and the
        // search for the closing tag, mirroring PlantUML's tolerance.
        if (i + 7 <= source.length) {
          final maybeOpen = source.substring(i, i + 7).toLowerCase();
          if (maybeOpen == '<style>') {
            final lower = source.toLowerCase();
            final closeIdx = lower.indexOf('</style>', i + 7);
            if (closeIdx < 0) {
              throw LexerException(
                  "Unterminated '<style>' block", line, startCol);
            }
            // Advance position/line/column past everything up through the
            // closing `</style>` tag. The block is treated as whitespace.
            final endAfterClose = closeIdx + 8;
            for (var k = i; k < endAfterClose; k++) {
              if (source[k] == '\n') {
                line++;
                col = 1;
              } else {
                col++;
              }
            }
            i = endAfterClose;
            continue;
          }
        }
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
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
        // PlantUML state-diagram border-style modifier: `##color`,
        // `##[dashed]color`, `##[bold]`, `##[dotted]green`, or bare `##`.
        // Absorb the whole construct into a single hashColor lexeme so the
        // parser can treat it the same way as a `#color` background.
        if (i + 1 < source.length && source[i + 1] == '#') {
          final start = i;
          i += 2;
          col += 2;
          // Optional `[modifier]` bracketed style hint.
          if (i < source.length && source[i] == '[') {
            i++;
            col++;
            while (i < source.length && source[i] != ']' && source[i] != '\n') {
              i++;
              col++;
            }
            if (i < source.length && source[i] == ']') {
              i++;
              col++;
            }
          }
          // Optional trailing color name / hex.
          while (i < source.length && _isIdentChar(source[i])) {
            i++;
            col++;
          }
          emit(TokenType.hashColor, source.substring(start, i), startCol);
          continue;
        }
        // Visibility prefix on class-header keyword at line start:
        // `#class "X" { }`. Drop the `#` and let the keyword lex normally.
        if (_isLineStart(tokens) && _isVisibilityPrefixedHeader(source, i)) {
          i++;
          col++;
          continue;
        }
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
        // PlantUML inline style first clause: when the leading identifier is
        // a key (`#line:red`, `#line.bold`, `#text:red`) rather than a bg
        // color, absorb the `:value` or `.value` suffix so it stays part of
        // the same hashColor token. This lets the parser tolerate
        // colorless inline-style prefixes without throwing.
        if (i < source.length &&
            (source[i] == ':' || source[i] == '.') &&
            i + 1 < source.length &&
            _isIdentChar(source[i + 1])) {
          i++;
          col++;
          while (i < source.length && _isIdentChar(source[i])) {
            i++;
            col++;
          }
        }
        // PlantUML gradient color suffix on a `#<color>` token:
        // `#red-green`, `#color1/color2`, `#color1|color2`. Absorb the
        // separator + second name so the gradient stays one hashColor token.
        // Rendering as a true gradient is deferred; downstream solid-color
        // resolution picks the first name.
        if (i < source.length &&
            (source[i] == '-' || source[i] == '/' || source[i] == '|') &&
            i + 1 < source.length &&
            _isIdentStart(source[i + 1])) {
          i++;
          col++;
          while (i < source.length && _isIdentChar(source[i])) {
            i++;
            col++;
          }
        }
        // PlantUML hex-escape suffix on a `#<color>` token used in note
        // background colors: `#blue\9932CC`. Absorb `\<hexdigits>` so the
        // whole construct stays a single hashColor lexeme.
        if (i + 1 < source.length &&
            source[i] == r'\' &&
            _isHexDigit(source[i + 1])) {
          i++;
          col++;
          while (i < source.length && _isHexDigit(source[i])) {
            i++;
            col++;
          }
        }
        // PlantUML inline style: `#<color>[;key:value][;key.modifier]...`
        // Absorb any trailing `;key(:|.)value` clauses into a single
        // hashColor lexeme. Visual styling is deferred — the parser only
        // needs the leading `#color` for rendering; the rest is preserved on
        // the lexeme so callers that care can inspect it.
        while (i < source.length && source[i] == ';') {
          final saveI = i;
          final saveCol = col;
          i++;
          col++;
          if (i >= source.length || !_isIdentChar(source[i])) {
            i = saveI;
            col = saveCol;
            break;
          }
          while (i < source.length && _isIdentChar(source[i])) {
            i++;
            col++;
          }
          if (i < source.length &&
              (source[i] == ':' || source[i] == '.') &&
              i + 1 < source.length &&
              _isIdentChar(source[i + 1])) {
            i++;
            col++;
            while (i < source.length && _isIdentChar(source[i])) {
              i++;
              col++;
            }
          }
        }
        emit(TokenType.hashColor, source.substring(start, i), startCol);
        continue;
      }

      if ((c == 'x' || c == '}' || c == '^') &&
          i + 1 < source.length &&
          (source[i + 1] == '-' ||
              source[i + 1] == '.' ||
              // PlantUML sequence: `x<->x`, `x<-` use `x` as a tail decoration
              // followed by a bidirectional/backward arrow body.
              (c == 'x' && source[i + 1] == '<'))) {
        final startCol = col;
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
      }
      // PlantUML chained-lollipop component arrows starting with a bare digit
      // or closing paren: `0)-(0-(0`, `)-0-(0`. Try the arrow scanner only
      // when the next char is a `)` or `-` to avoid swallowing plain numbers.
      if ((c == '0' || c == ')') &&
          i + 1 < source.length &&
          (source[i + 1] == ')' ||
              source[i + 1] == '-' ||
              source[i + 1] == '.' ||
              source[i + 1] == '(')) {
        final startCol = col;
        final arrowLex = _scanArrow(source, i);
        if (arrowLex != null) {
          emit(TokenType.arrow, arrowLex, startCol);
          i += arrowLex.length;
          col += arrowLex.length;
          continue;
        }
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
          // PlantUML gradient colors: `Color1/Color2`, `Color1|Color2` (and
          // `Color1-Color2`, already covered above). Absorb the separator
          // and second name so the value lexes as one identifier. Rendering
          // a true gradient is deferred; downstream resolves to the first
          // color via `tryParseColor`.
          if ((ch == '/' || ch == '|') &&
              i + 1 < source.length &&
              _isIdentStart(source[i + 1])) {
            i++;
            col++;
            continue;
          }
          break;
        }
        final word = source.substring(start, i);
        emit(TokenType.identifier, word, startCol);
        // `autonumber`, `header`, `footer` accept free-form rest-of-line
        // arguments (dotted versions, `%page%` placeholders, etc.); capture
        // the rest as a text token so the lexer doesn't choke on `.` or `%`.
        // `header`/`footer` optionally allow a leading alignment word; emit
        // that as its own identifier first so the parser can read alignment.
        // `mainframe` accepts an arbitrary label (including inline markup
        // like `**bold**`) for the wrapping UML frame tab, so we capture the
        // whole remainder as a single text token instead of letting `**`
        // become a starStar token mid-label.
        if ((word == 'autonumber' ||
                word == 'header' ||
                word == 'footer' ||
                word == 'newpage' ||
                word == 'mainframe' ||
                word == 'title' ||
                word == 'caption') &&
            _isLineStart(tokens.sublist(0, tokens.length - 1))) {
          while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
            i++;
            col++;
          }
          if (word == 'header' || word == 'footer') {
            const aligns = {'left', 'right', 'center'};
            for (final a in aligns) {
              if (i + a.length <= source.length &&
                  source.substring(i, i + a.length) == a &&
                  (i + a.length == source.length ||
                      source[i + a.length] == ' ' ||
                      source[i + a.length] == '\t' ||
                      source[i + a.length] == '\n')) {
                emit(TokenType.identifier, a, col);
                i += a.length;
                col += a.length;
                while (i < source.length &&
                    (source[i] == ' ' || source[i] == '\t')) {
                  i++;
                  col++;
                }
                break;
              }
            }
          }
          final restStart = i;
          final restStartCol = col;
          while (i < source.length && source[i] != '\n') {
            i++;
            col++;
          }
          final rest = source.substring(restStart, i).trim();
          if (rest.isNotEmpty) {
            emit(TokenType.text, rest, restStartCol);
          }
          // PlantUML's block-form `title <inline text>\n<body lines>\nend title`
          // mixes an inline opener with additional body lines. The
          // `_isTitleHeader` post-newline check only catches the `title` alone
          // on a line case (no inline text); here we proactively look ahead
          // for a future `end title` line. If one exists before EOF/@enduml,
          // capture subsequent lines as the title body so inline HTML markup
          // (`<u>`, `<img:...>`, etc.) is preserved verbatim instead of being
          // mis-lexed as arrows or stereotypes.
          if (word == 'title' && _hasUpcomingEndTitle(source, i)) {
            inTitleBody = true;
          }
        }
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

  static bool _hasUpcomingEndTitle(String source, int from) {
    var p = from;
    while (p < source.length) {
      // Advance to the next line start.
      while (p < source.length && source[p] != '\n') {
        p++;
      }
      if (p >= source.length) return false;
      p++; // skip '\n'
      // Read the next line.
      var end = p;
      while (end < source.length && source[end] != '\n') {
        end++;
      }
      final trimmed = source.substring(p, end).trim();
      if (trimmed == 'end title') return true;
      // Stop scanning if we leave the diagram body; treat these as outside
      // the block so we don't accidentally swallow following content.
      if (trimmed == '@enduml' || trimmed.startsWith('@end')) return false;
      p = end;
    }
    return false;
  }

  static bool _isTitleHeader(List<Token> tokens) {
    // `title` alone on a line opens a multi-line title block terminated by
    // `end title`. The lexer's `title` rest-of-line capture only emits a
    // trailing text token when the rest is non-empty, so the line tokens for
    // the block form are exactly `title` + `newline`.
    if (tokens.isEmpty) return false;
    if (tokens.last.type != TokenType.newline) return false;
    var k = tokens.length - 2;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      k--;
    }
    final start = k + 1;
    // Need exactly two tokens before the trailing newline: `title` identifier
    // and the closing newline itself.
    if (start != tokens.length - 2) return false;
    final first = tokens[start];
    if (first.type != TokenType.identifier || first.lexeme != 'title') {
      return false;
    }
    return true;
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
    if (first.type != TokenType.identifier ||
        (first.lexeme != 'note' &&
            first.lexeme != 'hnote' &&
            first.lexeme != 'rnote' &&
            first.lexeme != 'ref')) {
      return false;
    }
    if (start + 1 >= tokens.length - 1) return false;
    final second = tokens[start + 1];
    if (second.type != TokenType.identifier) return false;
    int afterPosition;
    if (first.lexeme == 'ref') {
      // `ref over X[, Y...]` — no `left`/`right` variants.
      if (second.lexeme != 'over') return false;
      afterPosition = start + 2;
    } else if (second.lexeme == 'left' ||
        second.lexeme == 'right' ||
        second.lexeme == 'top' ||
        second.lexeme == 'bottom') {
      // `note right of X` / `note top of X` (and `note right`, target-less)
      // both open a body.
      if (start + 2 < tokens.length - 1 &&
          tokens[start + 2].type == TokenType.identifier &&
          tokens[start + 2].lexeme == 'of') {
        afterPosition = start + 3;
      } else {
        return start + 2 == tokens.length - 1;
      }
    } else if (second.lexeme == 'over') {
      afterPosition = start + 2;
    } else if (second.lexeme == 'as' && first.lexeme == 'note') {
      // `note as <id>` — free-standing class-diagram note declaration.
      // Requires an identifier after `as` and nothing else on the header
      // line; subsequent lines until `end note` are the body.
      if (start + 2 >= tokens.length - 1) return false;
      if (tokens[start + 2].type != TokenType.identifier) return false;
      return start + 3 == tokens.length - 1;
    } else {
      return false;
    }
    if (afterPosition >= tokens.length - 1) return false;
    // Accept either a bare identifier (`note right of Foo`) or a
    // parenthesized use-case target (`note right of (Use)`). The latter is
    // tokenized as `leftParen text|identifier rightParen`.
    final int afterTarget;
    if (tokens[afterPosition].type == TokenType.identifier) {
      afterTarget = afterPosition + 1;
    } else if (tokens[afterPosition].type == TokenType.leftParen) {
      var k3 = afterPosition + 1;
      if (k3 < tokens.length - 1 &&
          (tokens[k3].type == TokenType.text ||
              tokens[k3].type == TokenType.identifier)) {
        k3++;
      }
      if (k3 >= tokens.length - 1 ||
          tokens[k3].type != TokenType.rightParen) {
        return false;
      }
      afterTarget = k3 + 1;
    } else {
      return false;
    }
    var k2 = afterTarget;
    while (k2 < tokens.length - 1) {
      final t = tokens[k2];
      if (t.type == TokenType.newline) break;
      if (t.type == TokenType.hashColor) {
        k2++;
        continue;
      }
      if (t.type == TokenType.comma) {
        k2++;
        if (k2 >= tokens.length - 1 ||
            tokens[k2].type != TokenType.identifier) {
          return false;
        }
        k2++;
        continue;
      }
      // PlantUML's `rnote`/`hnote`/`note ... over X` headers may include
      // arbitrary trailing content on the same line (e.g.
      // `rnote over server "r" as rectangle`). Such content is treated as
      // the first body line by the parser; once we see any non-comma,
      // non-color token we accept the header as multi-line so the lexer
      // enters body mode for the subsequent lines until `endrnote` /
      // `endhnote` / `end note`.
      return true;
    }
    return true;
  }

  static bool _isLineStart(List<Token> tokens) {
    if (tokens.isEmpty) return true;
    return tokens.last.type == TokenType.newline;
  }

  /// True when [trimmed] is an opening line of a WBS/mindmap multi-line body
  /// marker (`<+/-/*>+[#color]?:body`) whose closing `;` is NOT on the same
  /// line. The caller is responsible for accumulating subsequent lines until
  /// the closing `;` is reached.
  static bool _isMultilineMarkerBodyOpen(String trimmed) {
    if (trimmed.isEmpty) return false;
    final first = trimmed[0];
    if (first != '+' && first != '-' && first != '*') return false;
    var k = 0;
    while (k < trimmed.length &&
        (trimmed[k] == '+' || trimmed[k] == '-' || trimmed[k] == '*')) {
      k++;
    }
    if (k == 0) return false;
    // Optional `_` boxless suffix (`++_:body`).
    if (k < trimmed.length && trimmed[k] == '_') k++;
    // Skip whitespace between marker run and `[#color]?` / `:`.
    while (k < trimmed.length &&
        (trimmed[k] == ' ' || trimmed[k] == '\t')) {
      k++;
    }
    // Optional `[#color]` inline color before `:`.
    if (k < trimmed.length && trimmed[k] == '[') {
      final close = trimmed.indexOf(']', k);
      if (close < 0) return false;
      k = close + 1;
      while (k < trimmed.length &&
          (trimmed[k] == ' ' || trimmed[k] == '\t')) {
        k++;
      }
    }
    if (k >= trimmed.length || trimmed[k] != ':') return false;
    // Opening colon present; multi-line body is "open" if the line does NOT
    // end with `;` (after trimming).
    return !trimmed.endsWith(';');
  }

  /// Net change to verbatim-block nesting depth contributed by [trimmed].
  /// Counts case-insensitive `<code>` / `</code>` (and similar `<pre>`) tags.
  /// Used by the `**:..;` multi-line body accumulator so that a stray `;`
  /// inside a verbatim block (e.g. `void f1();`) does not prematurely
  /// terminate body accumulation.
  static int _verbatimDepthDelta(String trimmed) {
    if (trimmed.isEmpty) return 0;
    final lower = trimmed.toLowerCase();
    var delta = 0;
    const openTags = ['<code>', '<pre>'];
    const closeTags = ['</code>', '</pre>'];
    for (final tag in openTags) {
      var idx = 0;
      while (true) {
        final hit = lower.indexOf(tag, idx);
        if (hit < 0) break;
        delta++;
        idx = hit + tag.length;
      }
    }
    for (final tag in closeTags) {
      var idx = 0;
      while (true) {
        final hit = lower.indexOf(tag, idx);
        if (hit < 0) break;
        delta--;
        idx = hit + tag.length;
      }
    }
    return delta;
  }

  /// True when the just-emitted `{` (last token in [tokens]) belongs to a
  /// single-line class-body declaration of the form
  /// `[<kind>] [name] [<<stereo>>] [as alias] { ... }`. Walks backward from
  /// the `{` to the line start (or BOF) looking for a class-header keyword.
  static bool _isSingleLineClassBodyOpen(List<Token> tokens) {
    if (tokens.isEmpty) return false;
    if (tokens.last.type != TokenType.leftBrace) return false;
    var k = tokens.length - 2;
    while (k >= 0 && tokens[k].type != TokenType.newline) {
      k--;
    }
    final start = k + 1;
    if (start >= tokens.length) return false;
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
      'circle',
      'diamond',
      'dataclass',
      'metaclass',
      'protocol',
      'stereotype',
      'struct',
    };
    return headers.contains(first.lexeme);
  }

  /// True if the character at [pos] in [source] is a class-diagram visibility
  /// marker (`+`, `-`, `#`, `~`) immediately followed (no whitespace) by a
  /// class-header keyword such as `class`, `interface`, etc. The detector is
  /// only meaningful at the start of a line; callers gate on that.
  static bool _isVisibilityPrefixedHeader(String source, int pos) {
    if (pos >= source.length) return false;
    final p = pos + 1;
    if (p >= source.length) return false;
    const headers = [
      'class',
      'interface',
      'abstract',
      'annotation',
      'enum',
      'entity',
      'exception',
      'object',
      'record',
      'struct',
      'protocol',
      'metaclass',
      'dataclass',
      'circle',
      'diamond',
      'stereotype',
    ];
    for (final h in headers) {
      if (p + h.length > source.length) continue;
      if (source.substring(p, p + h.length) != h) continue;
      final after = p + h.length;
      if (after == source.length) return true;
      final next = source[after];
      // The keyword must end at a non-identifier char (space, brace, quote,
      // etc.) so we don't accidentally match `~classifier`.
      if (!_isIdentChar(next)) return true;
    }
    return false;
  }

  /// Detects a `:Name:` colon-wrapped actor at the head of a use-case relation
  /// line such as `:user: --> (Use case 1)`. Returns the absolute index of
  /// the CLOSING `:` if the pattern matches, or `null` otherwise.
  ///
  /// The detector is intentionally conservative — it requires a `-`/`<`
  /// arrow body followed by a `(` on the SAME source line after the closing
  /// `:`. This preserves the existing sequence-diagram colon-text behaviour
  /// for lines like `:user: as User` (no arrow follows) and `Alice : hi`.
  static int? _scanColonWrappedActor(String source, int colonIndex) {
    final n = source.length;
    if (colonIndex >= n || source[colonIndex] != ':') return null;
    var j = colonIndex + 1;
    // Inner name: any printable chars except `:` and newline. Must be
    // non-empty after trimming.
    final nameStart = j;
    while (j < n && source[j] != ':' && source[j] != '\n') {
      j++;
    }
    if (j >= n || source[j] != ':') return null;
    final innerColon = j;
    if (source.substring(nameStart, innerColon).trim().isEmpty) return null;
    // Inspect what follows on the same line. We require an arrow body
    // (`-`/`<`) and a parenthesized target before the newline. If the tail
    // doesn't match, leave it to the legacy `:text...` lexer path so we
    // don't break sequence-diagram syntax.
    var k = innerColon + 1;
    while (k < n && (source[k] == ' ' || source[k] == '\t')) {
      k++;
    }
    if (k >= n || source[k] == '\n') return null;
    if (source[k] != '-' && source[k] != '<') return null;
    // Don't require a parenthesised target — allow bare identifier or
    // bracketed component target too (e.g. `:actor: -0)- foo`).
    return innerColon;
  }

  static bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x30 && code <= 0x39) ||
        c == '_' ||
        // PlantUML permits `$`-prefixed identifiers (e.g. `$tag`, `$C1`) which
        // act as preprocessor variables or tag names. Treat `$` as a valid
        // identifier-start char so `class $C1`, `remove $tag13`,
        // `hide $tag13` etc. tokenize cleanly.
        c == '\$';
  }

  static bool _isIdentChar(String c) => _isIdentStart(c);

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isHexDigit(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
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

  // PlantUML "duration" annotation `(<digits>)` embedded in a sequence arrow:
  //   `A ->(10) B`     trailing on a forward arrow
  //   `A (10)<- B`     leading on a backward arrow
  //   `A -->(20) B`    dashed variant
  // Returns the index AFTER the closing `)` if a duration annotation starts
  // at `j`, or `j` unchanged if no annotation matched. Refuses to absorb
  // `(<digits>)` followed by characters that look like a comment / label
  // continuation rather than arrow body chars.
  static int _consumeArrowDuration(String source, int j) {
    final n = source.length;
    if (j >= n || source[j] != '(') return j;
    var k = j + 1;
    final digitStart = k;
    while (k < n && _isDigit(source[k])) {
      k++;
    }
    if (k == digitStart) return j;
    if (k >= n || source[k] != ')') return j;
    return k + 1;
  }

  // Public entry point. Delegates to [_scanArrowCore] for the structural
  // body/head match, then absorbs an optional trailing `(<digits>)` duration
  // annotation so the whole `->(N)` / `-->(N)` form tokenizes as one arrow.
  // The leading `(N)<-` form is handled inside [_scanArrowCore] itself
  // via the `first == '('` dispatch.
  static String? _scanArrow(String source, int i) {
    final lex = _scanArrowCore(source, i);
    if (lex == null) return null;
    final after = _consumeArrowDuration(source, i + lex.length);
    if (after > i + lex.length) {
      return source.substring(i, after);
    }
    return lex;
  }

  static String? _scanArrowCore(String source, int i) {
    final start = i;
    final n = source.length;
    if (i >= n) return null;
    final first = source[i];

    // PlantUML "duration" annotation as the LEADING segment of a backward
    // arrow: `(10)<-`, `(20)<--`. Absorb `(<digits>)` then recurse to scan
    // the actual arrow body. If no real arrow follows, this isn't an arrow.
    //
    // Also handles PlantUML class diagram lollipop interface notation: an
    // empty `()` immediately followed by a dash/dot arrow body (`()- foo`,
    // `()-- foo`, `()..> foo`). The `()` represents an unnamed lollipop
    // (provided/required interface marker); we accept the whole construct as
    // one arrow lexeme so the relation parses cleanly.
    if (first == '(') {
      if (i + 1 < n && source[i + 1] == ')') {
        final inner = _scanArrowCore(source, i + 2);
        if (inner != null) {
          return source.substring(start, i + 2 + inner.length);
        }
        // PlantUML lollipop interface notation with a bare dash/dot connector:
        // `()-`, `()--`, `()..`. Accept any run of dashes or dots after the
        // closing `)` so `bar ()- foo` tokenizes as `bar`, arrow `()-`, `foo`.
        var k = i + 2;
        while (k < n && (source[k] == '-' || source[k] == '.')) {
          k++;
        }
        if (k > i + 2) {
          return source.substring(start, k);
        }
      }
      final afterDuration = _consumeArrowDuration(source, i);
      if (afterDuration == i) return null;
      final inner = _scanArrowCore(source, afterDuration);
      if (inner == null) return null;
      return source.substring(start, afterDuration + inner.length);
    }

    int? consumeBody(int j) {
      var k = j;
      var sawDashes = false;
      var sawDots = false;
      while (k < n && (source[k] == '-' || source[k] == '\\' || source[k] == '/')) {
        sawDashes = true;
        k++;
      }
      while (k < n && source[k] == '.') {
        sawDots = true;
        k++;
      }
      // PlantUML direction-hint segment inside an arrow body: `*-down-`,
      // `.up.|>`, `o-left->`. After the leading body run, consume an
      // optional `up`/`down`/`left`/`right` (or 2-letter abbreviation)
      // followed by more body chars.
      if ((sawDashes || sawDots) && k < n) {
        for (final dir in const [
          'left', 'right', 'up', 'down', 'le', 'ri', 'do'
        ]) {
          if (k + dir.length < n &&
              source.substring(k, k + dir.length) == dir &&
              (source[k + dir.length] == '-' ||
                  source[k + dir.length] == '.')) {
            k += dir.length;
            while (k < n && (source[k] == '-' || source[k] == '\\' || source[k] == '/')) {
              sawDashes = true;
              k++;
            }
            while (k < n && source[k] == '.') {
              sawDots = true;
              k++;
            }
            break;
          }
        }
      }
      if (k < n && source[k] == '[') {
        final close = source.indexOf(']', k + 1);
        if (close < 0) return null;
        k = close + 1;
        while (k < n && (source[k] == '-' || source[k] == '\\' || source[k] == '/')) {
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

    // PlantUML sequence "lost" message terminators: a trailing `]` or `?` after
    // a complete arrow marks the target endpoint as anonymous (diagram edge or
    // short stub). The marker may appear AFTER any head-side decoration
    // (`>`, `>>`, `o`, `x`, `\`, `\\`, `/`, `//`, or a half-arrow body), so
    // every arrow-end branch must call this AFTER it finishes consuming the
    // head glyphs. A trailing `]` is only valid when there is no unmatched
    // `[` earlier in the lexeme (that would be a `[#color]` modifier).
    int consumeLostEnd(int j) {
      if (j < n && source[j] == '?') return j + 1;
      if (j < n && source[j] == ']') {
        // Disambiguate from a modifier close: a modifier `[X]` is always
        // followed by more body characters, so when `]` is the LAST char of
        // the lexeme we treat it as a lost-end marker. Here we check whether
        // any later head/body char would follow — if not, accept it.
        return j + 1;
      }
      return j;
    }

    if (first == '-') {
      var j = i + 1;
      // PlantUML direction-hint arrows: `-left->`, `-right->`, `-up->`,
      // `-down->`. Also accepts 2-letter abbreviations `-le->`, `-ri->`,
      // `-up->`, `-do->`. After the initial `-`, consume the direction keyword
      // if present. The keyword may be followed by `-`, `[`, `.`, or a
      // parenthesised lollipop digit `(0)`. Also accepts `-le0`/`-ri0` form
      // (digit directly without parens) for `:actor: -ri0)- foo` shape.
      for (final dir in const [
        'left', 'right', 'up', 'down', 'le', 'ri', 'do'
      ]) {
        if (j + dir.length < n &&
            source.substring(j, j + dir.length) == dir &&
            (source[j + dir.length] == '-' ||
                source[j + dir.length] == '[' ||
                source[j + dir.length] == '.' ||
                source[j + dir.length] == '(' ||
                _isDigit(source[j + dir.length]))) {
          j += dir.length;
          break;
        }
      }
      // Optional embedded lollipop after direction-hint OR as a middle marker
      // (`-(0)-`, `-(0)->`, `-0)-`). Consume `(0)` / `(N)` / `0)` / `0` so the
      // rest of the arrow body scan continues at the trailing `-`. If the
      // construct is followed by a trailing dash run with no head glyph,
      // accept the whole thing as a valid middle-marker arrow.
      var lollipopConsumed = false;
      if (j < n && source[j] == '(') {
        var k = j + 1;
        while (k < n && _isDigit(source[k])) {
          k++;
        }
        if (k > j + 1 && k < n && source[k] == ')') {
          j = k + 1;
          lollipopConsumed = true;
        }
      }
      if (lollipopConsumed) {
        // Trailing dash run -> middle-marker arrow, e.g. `-(0)-`, `-(N)-`.
        if (j < n && source[j] == '-') {
          while (j < n && source[j] == '-') {
            j++;
          }
          // If a head glyph follows the trailing dash, fall through to the
          // normal head consumption logic; otherwise return the lexeme.
          if (j >= n ||
              (source[j] != '>' &&
                  source[j] != '|' &&
                  source[j] != '*' &&
                  source[j] != 'o' &&
                  source[j] != '+' &&
                  source[j] != '#' &&
                  source[j] != '^')) {
            return source.substring(start, j);
          }
        }
      }
      // PlantUML use-case / class diagrams allow elongated dashed bodies like
      // `--->`, `---->` to hint at edge length. Consume any run of dashes
      // after the initial `-` so the whole body is part of the arrow lexeme.
      while (j < n && source[j] == '-') {
        j++;
      }
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
        }
        // No additional body chars required after `]` — falls through to the
        // arrow suffix scan (>, |, *, o) below.
      }
      if (j < n && source[j] == '.') {
        while (j < n && source[j] == '.') {
          j++;
        }
      }
      while (j < n && (source[j] == '\\' || source[j] == '/')) {
        j++;
      }
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        // PlantUML sequence "lost" message terminators after `>` / `>>` /
        // `>o` / `>x` / `>>o` / `>>x`.
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      if (j < n && source[j] == '|') {
        j++;
        // PlantUML deployment heads `--||>` (double pipe with arrow).
        if (j < n && source[j] == '|') j++;
        if (j < n && source[j] == '>') {
          j++;
          return source.substring(start, j);
        }
        return null;
      }
      // PlantUML deployment head `--:|>` (colon prefix on a pipe-arrow head).
      if (j < n && source[j] == ':') {
        j++;
        if (j < n && source[j] == '|') {
          j++;
          if (j < n && source[j] == '|') j++;
          if (j < n && source[j] == '>') {
            j++;
            return source.substring(start, j);
          }
        }
        return null;
      }
      if (j < n && (source[j] == '*' || source[j] == 'o')) {
        j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // PlantUML cloud / component lollipop arrows that wrap a number or
      // parenthesised number as a MIDDLE marker with a trailing dash run:
      //   `-0-`, `-0)-`, `-(0-`, `-(0)-`  (cloud lollipop forms)
      // The marker can also be terminal (no trailing dashes), in which case
      // it acts as a head decoration: `--0`, `--^`, `--+`, `--#`, `--(0`.
      if (j < n && source[j] == '0') {
        var k = j + 1;
        if (k < n && source[k] == ')') k++;
        // Trailing dash run -> middle-of-arrow form.
        if (k < n && source[k] == '-') {
          while (k < n && source[k] == '-') {
            k++;
          }
          return source.substring(start, k);
        }
        // Terminal head decoration form: `--0`, `--0)`.
        k = j + 1;
        k = consumeLostEnd(k);
        return source.substring(start, k);
      }
      // PlantUML artifact / component head decorations after a dashed/dotted
      // body: `--+`, `--#`, `--^`. Consume the single head glyph as
      // part of the arrow lexeme so the relation parser sees one token.
      // For `+`, only treat as a head when not followed by another `+` —
      // `--++` is a sequence-diagram inline-activation suffix (`--` then
      // `++`) which must NOT be eaten here.
      if (j < n &&
          ((source[j] == '+' && (j + 1 >= n || source[j + 1] != '+')) ||
              source[j] == '#' ||
              source[j] == '^' ||
              source[j] == '@')) {
        j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // PlantUML lollipop interface marker as a trailing head: `-()`, `--()`,
      // `..()`, or `--(0` (numbered lollipop). Consume the `()` pair so the
      // whole construct is one arrow; also accept the parenthesised numbered
      // form (`-(0-`, `-(0)-`, `--(0`).
      if (j + 1 < n && source[j] == '(' && source[j + 1] == ')') {
        return source.substring(start, j + 2);
      }
      // PlantUML lollipop "start" marker `--(` (open paren with no following
      // digit or close): accept as a single arrow lexeme so `f --( b` parses
      // as relation rather than splitting `--` and stranding the `(` as a
      // leftParen token that downstream relation parsers misread as an
      // ellipse-name opener.
      if (j < n &&
          source[j] == '(' &&
          (j + 1 >= n || (source[j + 1] != ')' && !_isDigit(source[j + 1])))) {
        return source.substring(start, j + 1);
      }
      if (j + 1 < n && source[j] == '(' && _isDigit(source[j + 1])) {
        var k = j + 2;
        while (k < n && _isDigit(source[k])) {
          k++;
        }
        if (k < n && source[k] == ')') k++;
        // If followed by trailing dashes, this is a middle-of-arrow marker
        // (`-(0-`, `-(0)-`): consume the dash run as the arrow tail.
        if (k < n && source[k] == '-') {
          while (k < n && source[k] == '-') {
            k++;
          }
        }
        return source.substring(start, k);
      }
      // Half-arrow bodies like `-\` or `-/` end with the slash/backslash itself.
      if (j > i + 1 && j - 1 < n && (source[j - 1] == '\\' || source[j - 1] == '/')) {
        // Optional `o` / `x` cap immediately after a half-arrow body, then a
        // lost-end marker: `-\o?`, `-/o?`, `-\\o?`, etc.
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      return null;
    }
    if (first == '.') {
      var j = i + 1;
      // PlantUML use-case diagrams use `.>` as a short-form dashed arrow with
      // a right head (commonly seen with `: include` / `: extends` labels).
      // Allow a single-dot body so the lexer recognizes `.>` / `.>>` / `.>o`
      // alongside the canonical `..>` body.
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // PlantUML direction-hint dashed arrow body: `.up.|>`, `.down.>`,
      // `.left.>`, `.right.>`. After the leading `.`, recognize a
      // direction keyword followed by another `.` run (then the standard
      // head consumption logic continues below).
      for (final dir in const [
        'left', 'right', 'up', 'down', 'le', 'ri', 'do'
      ]) {
        if (j + dir.length < n &&
            source.substring(j, j + dir.length) == dir &&
            source[j + dir.length] == '.') {
          j += dir.length;
          // Consume the trailing dot run; fall through to head scan.
          while (j < n && source[j] == '.') {
            j++;
          }
          if (j < n && source[j] == '>') {
            j++;
            if (j < n && source[j] == '>') j++;
            if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
            j = consumeLostEnd(j);
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
            j = consumeLostEnd(j);
            return source.substring(start, j);
          }
          return null;
        }
      }
      if (j >= n || source[j] != '.') return null;
      j++;
      while (j < n && source[j] == '.') {
        j++;
      }
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        // Allow trailing lost-message terminators on the dotted/dashed body.
        j = consumeLostEnd(j);
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
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // Trailing lollipop marker on a dotted body: `..()`, `.()`.
      if (j + 1 < n && source[j] == '(' && source[j + 1] == ')') {
        return source.substring(start, j + 2);
      }
      return null;
    }
    // PlantUML chained-lollipop arrows starting with a bare digit or a
    // closing paren: `0)-(0-(0`, `)-0-(0`, `0)-`. Walk a permissive
    // run of `0`, `(`, `)`, `-`, `.` chars; stop at whitespace/EOL/identifier.
    if (first == '0' || first == ')') {
      var j = i + 1;
      while (j < n) {
        final ch = source[j];
        if (ch == '0' ||
            ch == '(' ||
            ch == ')' ||
            ch == '-' ||
            ch == '.') {
          j++;
          continue;
        }
        break;
      }
      // Must contain at least one body separator to count as an arrow.
      final lex = source.substring(start, j);
      if (lex.contains('-') || lex.contains('.')) {
        return lex;
      }
      return null;
    }
    if (first == '*' ||
        first == 'o' ||
        first == '#' ||
        first == 'x' ||
        first == '}' ||
        first == '+' ||
        first == '^') {
      var j = i + 1;
      // PlantUML sequence arrows allow `o` / `x` as a TAIL decoration that
      // precedes a bidirectional head: `o<->o`, `x<->x`, `o<-`, `x<-`.
      // When the first char is `o` or `x` and the next is `<` (head glyph),
      // delegate to the `<`-branch logic by parsing the rest as a normal
      // bidirectional / backward arrow body, then bolt the leading `o` / `x`
      // back on.
      if ((first == 'o' || first == 'x') && j < n && source[j] == '<') {
        // Reuse the `<`-branch by recursing on the substring starting at the
        // `<`; if it matches, prepend our leading char. Also allow the
        // arrow lexeme to absorb a trailing matching `o`/`x` (already handled
        // inside the `<`-branch via the existing `o`/`x` consumption after
        // `>`). For backward-only forms (`o<-`), the inner scan ends without
        // a trailing decoration; we don't add one ourselves.
        final inner = _scanArrow(source, j);
        if (inner != null) {
          return source.substring(start, j + inner.length);
        }
      }
      // PlantUML hash-prefix wavy arrow (`#~~`, `#~~(`, `#~~>`, `#~~>>`).
      // The `#` indicates a styled connector and the `~~` body is a wavy line.
      if (first == '#' && j < n && source[j] == '~') {
        var k = j;
        while (k < n && source[k] == '~') {
          k++;
        }
        if (k > j + 1) {
          // Trailing lollipop `(` or `(0)`.
          if (k < n && source[k] == '(') {
            k++;
            while (k < n && _isDigit(source[k])) {
              k++;
            }
            if (k < n && source[k] == ')') k++;
            return source.substring(start, k);
          }
          if (k < n && source[k] == '>') {
            k++;
            if (k < n && source[k] == '>') k++;
            return source.substring(start, k);
          }
          return source.substring(start, k);
        }
      }
      final after = consumeBody(j);
      if (after == null) return null;
      j = after;
      // PlantUML middle marker `0)` / `(0)` inside body, e.g. `*-0)-+`.
      // After the initial body consumption, if a `0)` or `(0)` is followed
      // by more body chars and a head, fold it into the lexeme.
      if (j < n && source[j] == '0') {
        var k = j + 1;
        if (k < n && source[k] == ')') k++;
        // Trailing body chars after the lollipop.
        if (k < n && (source[k] == '-' || source[k] == '.')) {
          while (k < n && (source[k] == '-' || source[k] == '.')) {
            k++;
          }
          j = k;
        }
      } else if (j < n && source[j] == '(') {
        var k = j + 1;
        while (k < n && _isDigit(source[k])) {
          k++;
        }
        if (k > j + 1 && k < n && source[k] == ')') {
          k++;
          if (k < n && (source[k] == '-' || source[k] == '.')) {
            while (k < n && (source[k] == '-' || source[k] == '.')) {
              k++;
            }
            j = k;
          }
        }
      }
      if (j < n && source[j] == '>') {
        j++;
        // Double-head `>>` (thin / async) — `o->>`, `x->>`.
        if (j < n && source[j] == '>') j++;
        // After `>` (or `>>`), allow an optional trailing `o` / `x` cap so
        // forms like `o->o`, `o->x`, `x->o`, `x->x`, `o->>o` tokenize as a
        // single arrow. Then accept a trailing `?` / `]` lost-end marker
        // (e.g. `o->o?`, `x->o?`, `x->?`).
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        j = consumeLostEnd(j);
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
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // Single-glyph head terminators `+`, `#`, `^` (e.g. `*-0)-+`).
      if (j < n &&
          (source[j] == '+' || source[j] == '#' || source[j] == '^')) {
        j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      return source.substring(start, j);
    }
    if (first == '<') {
      var j = i + 1;
      if (j < n && source[j] == '-') {
        var k = j;
        // PlantUML bidirectional arrows tolerate optional embedded lollipop
        // markers in the body: `<-0->`, `<-(0)->`, `<-(0)-->`. Walk through
        // any mix of dashes, dots, slashes plus a `0` or `(<digits>)` lump.
        while (k < n) {
          final ch = source[k];
          if (ch == '-' || ch == '.' || ch == '\\' || ch == '/') {
            k++;
            continue;
          }
          if (ch == '0') {
            k++;
            if (k < n && source[k] == ')') k++;
            continue;
          }
          if (ch == '(') {
            var m = k + 1;
            while (m < n && _isDigit(source[m])) {
              m++;
            }
            if (m > k + 1 && m < n && source[m] == ')') {
              k = m + 1;
              continue;
            }
            break;
          }
          break;
        }
        if (k < n && source[k] == '>') {
          var m = k + 1;
          // Double-head bidirectional `<-->>` or `<<-->>`.
          if (m < n && source[m] == '>') m++;
          if (m < n && (source[m] == 'o' || source[m] == 'x')) m++;
          // Bidirectional with lost-endpoint marker (`<->?`, `<->o?`, etc.).
          // The arrow is structurally bidirectional but with an anonymous
          // right endpoint — the parser will normalize it to a forward
          // direction since you can't have a bidirectional arrow to an
          // anonymous target.
          m = consumeLostEnd(m);
          return source.substring(start, m);
        }
      }
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
        // Reverse arrow (`<-`) may terminate at a lost-endpoint marker `]`
        // or `?`. Without this, sources like `Bob <-]`, `Bob x<-]` (the `x`
        // branch recurses here) tokenize as just `<-` and leave the `]` as
        // a stray token. Mirrors `consumeLostEnd` calls in the forward
        // branches above.
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      return null;
    }
    if (first == '\\' || first == '/') {
      var j = i + 1;
      final after = consumeBody(j);
      if (after == null) return null;
      j = after;
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      if (j < n && (source[j] == '*' || source[j] == 'o')) {
        j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      return source.substring(start, j);
    }
    // PlantUML sequence "found" message: source is an anonymous endpoint.
    //   `[->`  — start at left diagram edge
    //   `?->`  — start at a short stub to the left of the target
    // Plus dashed (`[-->`, `?-->`), double-head (`[->>`, `?->>`), the
    // mirrored reverse forms (`[<-`, `?<-`) used to draw an arrow that points
    // BACK to the external endpoint, and the full head/tail decoration matrix
    // (`?x->`, `?o->o`, `[<->`, `[o<->o`, `?-\`, `?-\\o`, etc.). This branch
    // is the left-side mirror of the right-side decoration matrix handled by
    // the `o` / `x` / `<` / `-` first-char branches above.
    if (first == '[' || first == '?') {
      var j = i + 1;
      // Optional TAIL decoration `o` / `x` BEFORE the head/body glyphs:
      // `?o->`, `?x->`, `?o<->o`, `?x<->x`, `[o->o`, `[x->`, etc.
      // The tail decoration always precedes the head glyph (`<` or body).
      if (j < n && (source[j] == 'o' || source[j] == 'x')) {
        // Only treat as tail decoration when followed by a head/body glyph.
        if (j + 1 < n &&
            (source[j + 1] == '<' ||
                source[j + 1] == '-' ||
                source[j + 1] == '.' ||
                source[j + 1] == '\\' ||
                source[j + 1] == '/')) {
          j++;
        }
      }
      // Reverse-form prefix: `[<-`, `?<-`, `[<<-`, `?<<-`, `?o<-`, `?x<-`,
      // `?o<->o`, `?x<->x`. The arrow points back to the external endpoint;
      // direction is decoded by the parser.
      if (j < n && source[j] == '<') {
        j++;
        if (j < n && source[j] == '<') j++;
      }
      final after = consumeBody(j);
      if (after == null) {
        // No body — not an arrow, just a stray `[` or `?`.
        return null;
      }
      j = after;
      if (j < n && source[j] == '>') {
        j++;
        if (j < n && source[j] == '>') j++;
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        // Allow a trailing lost-end marker on the right side of a found
        // message — e.g. `?->]`, `[->o?`, `?<->?`, `[->>o]`. Symmetrical
        // to the right-side `consumeLostEnd` calls above.
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // Half-arrow body endings (`\`, `/`, `\\`, `//`) followed by optional
      // `o` / `x` cap, with no `>` head glyph: `?-\`, `[-/o`, `?-\\o`.
      if (j > i + 1 && j - 1 < n &&
          (source[j - 1] == '\\' || source[j - 1] == '/')) {
        if (j < n && (source[j] == 'o' || source[j] == 'x')) j++;
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      // Reverse form ends after the body (head was already consumed before).
      // Require that a head glyph was seen somewhere: either a leading `<` or
      // a trailing `>` above. If neither, this isn't an arrow (don't eat `[`).
      final lex = source.substring(start, j);
      if (lex.contains('<') || lex.contains('>')) {
        // Allow a trailing lost-end marker on reverse forms too.
        j = consumeLostEnd(j);
        return source.substring(start, j);
      }
      return null;
    }
    return null;
  }
}
