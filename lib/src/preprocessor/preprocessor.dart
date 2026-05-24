import 'dart:convert' as convert;

typedef FileLoader = String Function(String path);

class PreprocessorException implements Exception {
  final String message;
  final int line;
  PreprocessorException(this.message, this.line);
  @override
  String toString() => 'PreprocessorException($line): $message';
}

class _Macro {
  final String name;
  final List<String>? params;
  final String body;
  _Macro(this.name, this.params, this.body);
}

class _CondFrame {
  bool active;
  bool anyTaken;
  bool inElse;
  _CondFrame(this.active, this.anyTaken, this.inElse);
}

class _Subs {
  final Map<String, String> bins = {};
}

class Preprocessor {
  final FileLoader? fileLoader;
  final Map<String, _Macro> _macros = {};
  final _Subs _subs = _Subs();
  final Set<String> _includeStack = {};

  Preprocessor({this.fileLoader});

  String preprocess(String source) {
    final out = StringBuffer();
    _process(source, out, sourceLabel: '<root>');
    final result = out.toString();
    if (source.isNotEmpty &&
        !source.endsWith('\n') &&
        result.endsWith('\n')) {
      return result.substring(0, result.length - 1);
    }
    return result;
  }

  void _process(String source, StringBuffer out,
      {required String sourceLabel}) {
    final lines = const convert.LineSplitter().convert(source);
    final cond = <_CondFrame>[];
    String? capturingSub;
    final captureBuf = StringBuffer();

    bool active() => cond.every((f) => f.active);

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trimLeft();
      final lineNo = i + 1;

      if (capturingSub != null && !_isSubEnd(trimmed)) {
        if (active()) {
          captureBuf.writeln(raw);
        }
        continue;
      }

      if (trimmed.startsWith('!')) {
        final directive = _parseDirective(trimmed);
        switch (directive.name) {
          case 'define':
            if (active()) _handleDefine(directive.rest, lineNo);
            break;
          case 'undef':
          case 'undefine':
            if (active()) _handleUndef(directive.rest, lineNo);
            break;
          case 'if':
            final cnd = active() ? _evalExpr(directive.rest, lineNo) : false;
            cond.add(_CondFrame(cnd, cnd, false));
            break;
          case 'elseif':
            if (cond.isEmpty) {
              throw PreprocessorException(
                  '!elseif without matching !if', lineNo);
            }
            final f = cond.last;
            if (f.inElse) {
              throw PreprocessorException(
                  '!elseif after !else', lineNo);
            }
            final outerActive =
                cond.length == 1 ? true : cond[cond.length - 2].active;
            if (!outerActive || f.anyTaken) {
              f.active = false;
            } else {
              final cnd = _evalExpr(directive.rest, lineNo);
              f.active = cnd;
              if (cnd) f.anyTaken = true;
            }
            break;
          case 'else':
            if (cond.isEmpty) {
              throw PreprocessorException(
                  '!else without matching !if', lineNo);
            }
            final f = cond.last;
            if (f.inElse) {
              throw PreprocessorException(
                  'duplicate !else', lineNo);
            }
            f.inElse = true;
            final outerActive =
                cond.length == 1 ? true : cond[cond.length - 2].active;
            f.active = outerActive && !f.anyTaken;
            if (f.active) f.anyTaken = true;
            break;
          case 'endif':
            if (cond.isEmpty) {
              throw PreprocessorException(
                  '!endif without matching !if', lineNo);
            }
            cond.removeLast();
            break;
          case 'include':
            if (active()) _handleInclude(directive.rest, out, lineNo);
            break;
          case 'includesub':
            if (active()) _handleIncludeSub(directive.rest, out, lineNo);
            break;
          case 'startsub':
            if (active()) {
              if (capturingSub != null) {
                throw PreprocessorException(
                    'nested !startsub is not supported', lineNo);
              }
              final id = directive.rest.trim();
              if (id.isEmpty) {
                throw PreprocessorException(
                    '!startsub requires an id', lineNo);
              }
              capturingSub = id;
              captureBuf.clear();
            }
            break;
          case 'endsub':
            if (capturingSub == null) {
              throw PreprocessorException(
                  '!endsub without matching !startsub', lineNo);
            }
            _subs.bins[capturingSub] = captureBuf.toString();
            capturingSub = null;
            captureBuf.clear();
            break;
          case 'pragma':
            break;
          case 'function':
          case 'procedure':
          case 'return':
          case 'endfunction':
          case 'endprocedure':
          case 'include_many':
            break;
          default:
            break;
        }
        continue;
      }

      if (!active()) continue;

      final expanded = _expand(raw);
      out.writeln(expanded);
    }

    if (cond.isNotEmpty) {
      throw PreprocessorException(
          'unterminated !if in $sourceLabel', lines.length);
    }
    if (capturingSub != null) {
      throw PreprocessorException(
          'unterminated !startsub in $sourceLabel', lines.length);
    }
  }

  bool _isSubEnd(String trimmed) {
    if (!trimmed.startsWith('!')) return false;
    final d = _parseDirective(trimmed);
    return d.name == 'endsub';
  }

  _Directive _parseDirective(String trimmed) {
    final body = trimmed.substring(1);
    var i = 0;
    while (i < body.length && _isNameChar(body.codeUnitAt(i))) {
      i++;
    }
    final name = body.substring(0, i).toLowerCase();
    final rest = body.substring(i).trimLeft();
    return _Directive(name, rest);
  }

  bool _isNameChar(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F;

  void _handleDefine(String rest, int lineNo) {
    if (rest.isEmpty) {
      throw PreprocessorException('!define requires a name', lineNo);
    }
    var i = 0;
    while (i < rest.length && _isNameStart(rest.codeUnitAt(i), i == 0)) {
      i++;
    }
    if (i == 0) {
      throw PreprocessorException('!define requires a name', lineNo);
    }
    final name = rest.substring(0, i);
    List<String>? params;
    var pos = i;
    if (pos < rest.length && rest[pos] == '(') {
      final close = rest.indexOf(')', pos);
      if (close < 0) {
        throw PreprocessorException(
            'unterminated !define parameter list', lineNo);
      }
      final inside = rest.substring(pos + 1, close);
      params = inside
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      pos = close + 1;
    }
    final value = rest.substring(pos).trim();
    _macros[name] = _Macro(name, params, value);
  }

  bool _isNameStart(int c, bool first) {
    if (first) {
      return (c >= 0x41 && c <= 0x5A) ||
          (c >= 0x61 && c <= 0x7A) ||
          c == 0x5F;
    }
    return _isNameChar(c);
  }

  void _handleUndef(String rest, int lineNo) {
    final name = rest.trim();
    if (name.isEmpty) {
      throw PreprocessorException('!undef requires a name', lineNo);
    }
    _macros.remove(name);
  }

  void _handleInclude(String rest, StringBuffer out, int lineNo) {
    if (fileLoader == null) {
      throw PreprocessorException(
          'file loader not configured for !include', lineNo);
    }
    var path = rest.trim();
    String? subId;
    final bang = path.indexOf('!');
    if (bang >= 0) {
      subId = path.substring(bang + 1).trim();
      path = path.substring(0, bang).trim();
    }
    if (_includeStack.contains(path)) {
      throw PreprocessorException(
          'circular include of "$path"', lineNo);
    }
    final String content;
    try {
      content = fileLoader!(path);
    } catch (e) {
      throw PreprocessorException(
          'failed to load "$path": $e', lineNo);
    }
    _includeStack.add(path);
    try {
      if (subId == null) {
        _process(content, out, sourceLabel: path);
      } else {
        final scratch = StringBuffer();
        _process(content, scratch, sourceLabel: path);
        final bin = _subs.bins[subId];
        if (bin == null) {
          throw PreprocessorException(
              'no !startsub "$subId" in "$path"', lineNo);
        }
        out.write(bin);
      }
    } finally {
      _includeStack.remove(path);
    }
  }

  void _handleIncludeSub(String rest, StringBuffer out, int lineNo) {
    if (fileLoader == null) {
      throw PreprocessorException(
          'file loader not configured for !includesub', lineNo);
    }
    final spec = rest.trim();
    final bang = spec.indexOf('!');
    if (bang < 0) {
      throw PreprocessorException(
          '!includesub requires "path!sub_id"', lineNo);
    }
    final path = spec.substring(0, bang).trim();
    final subId = spec.substring(bang + 1).trim();
    if (_includeStack.contains(path)) {
      throw PreprocessorException(
          'circular include of "$path"', lineNo);
    }
    final String content;
    try {
      content = fileLoader!(path);
    } catch (e) {
      throw PreprocessorException(
          'failed to load "$path": $e', lineNo);
    }
    _includeStack.add(path);
    try {
      final scratch = StringBuffer();
      _process(content, scratch, sourceLabel: path);
      final bin = _subs.bins[subId];
      if (bin == null) {
        throw PreprocessorException(
            'no !startsub "$subId" in "$path"', lineNo);
      }
      out.write(bin);
    } finally {
      _includeStack.remove(path);
    }
  }

  String _expand(String line) {
    final out = StringBuffer();
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == '"') {
        out.write(c);
        i++;
        while (i < line.length) {
          out.write(line[i]);
          if (line[i] == '"') {
            i++;
            break;
          }
          i++;
        }
        continue;
      }
      if (_isIdStart(line.codeUnitAt(i))) {
        var j = i;
        while (j < line.length && _isNameChar(line.codeUnitAt(j))) {
          j++;
        }
        final name = line.substring(i, j);
        final macro = _macros[name];
        if (macro != null) {
          if (macro.params != null) {
            if (j < line.length && line[j] == '(') {
              final args = _parseArgs(line, j);
              if (args != null) {
                final expanded = _applyMacro(macro, args.values);
                out.write(expanded);
                i = args.endPos;
                continue;
              }
            }
            out.write(name);
            i = j;
          } else {
            out.write(macro.body);
            i = j;
          }
          continue;
        }
        out.write(name);
        i = j;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  bool _isIdStart(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;

  _ArgList? _parseArgs(String line, int openPos) {
    var i = openPos + 1;
    final args = <String>[];
    final cur = StringBuffer();
    var depth = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == '"') {
        cur.write(c);
        i++;
        while (i < line.length) {
          cur.write(line[i]);
          if (line[i] == '"') {
            i++;
            break;
          }
          i++;
        }
        continue;
      }
      if (c == '(') {
        depth++;
        cur.write(c);
        i++;
        continue;
      }
      if (c == ')') {
        if (depth == 0) {
          args.add(cur.toString().trim());
          return _ArgList(args, i + 1);
        }
        depth--;
        cur.write(c);
        i++;
        continue;
      }
      if (c == ',' && depth == 0) {
        args.add(cur.toString().trim());
        cur.clear();
        i++;
        continue;
      }
      cur.write(c);
      i++;
    }
    return null;
  }

  String _applyMacro(_Macro macro, List<String> args) {
    final params = macro.params!;
    if (args.length != params.length) {
      return macro.body;
    }
    var body = macro.body;
    for (var k = 0; k < params.length; k++) {
      body = _replaceIdentifier(body, params[k], args[k]);
    }
    return body;
  }

  String _replaceIdentifier(String body, String name, String value) {
    final out = StringBuffer();
    var i = 0;
    while (i < body.length) {
      if (_isIdStart(body.codeUnitAt(i))) {
        var j = i;
        while (j < body.length && _isNameChar(body.codeUnitAt(j))) {
          j++;
        }
        final word = body.substring(i, j);
        if (word == name) {
          out.write(value);
        } else {
          out.write(word);
        }
        i = j;
      } else {
        out.write(body[i]);
        i++;
      }
    }
    return out.toString();
  }

  bool _evalExpr(String src, int lineNo) {
    final p = _ExprParser(src, lineNo, _macros);
    final v = p.parseOr();
    p.expectEnd();
    return _truthy(v);
  }

  bool _truthy(_Value v) {
    if (v is _BoolValue) return v.value;
    if (v is _IntValue) return v.value != 0;
    if (v is _StringValue) return v.value.isNotEmpty;
    return false;
  }
}

class _Directive {
  final String name;
  final String rest;
  _Directive(this.name, this.rest);
}

class _ArgList {
  final List<String> values;
  final int endPos;
  _ArgList(this.values, this.endPos);
}

sealed class _Value {}

class _BoolValue extends _Value {
  final bool value;
  _BoolValue(this.value);
}

class _IntValue extends _Value {
  final int value;
  _IntValue(this.value);
}

class _StringValue extends _Value {
  final String value;
  _StringValue(this.value);
}

class _ExprParser {
  final String src;
  final int lineNo;
  final Map<String, _Macro> macros;
  int pos = 0;

  _ExprParser(this.src, this.lineNo, this.macros);

  void _skip() {
    while (pos < src.length && (src[pos] == ' ' || src[pos] == '\t')) {
      pos++;
    }
  }

  bool _match(String s) {
    _skip();
    if (pos + s.length > src.length) return false;
    if (src.substring(pos, pos + s.length) != s) return false;
    pos += s.length;
    return true;
  }

  bool _peek(String s) {
    _skip();
    if (pos + s.length > src.length) return false;
    return src.substring(pos, pos + s.length) == s;
  }

  _Value parseOr() {
    var left = parseAnd();
    while (_match('||')) {
      final right = parseAnd();
      left = _BoolValue(_truthy(left) || _truthy(right));
    }
    return left;
  }

  _Value parseAnd() {
    var left = parseNot();
    while (_match('&&')) {
      final right = parseNot();
      left = _BoolValue(_truthy(left) && _truthy(right));
    }
    return left;
  }

  _Value parseNot() {
    _skip();
    if (_match('!')) {
      final v = parseNot();
      return _BoolValue(!_truthy(v));
    }
    return parseCompare();
  }

  _Value parseCompare() {
    final left = parsePrimary();
    _skip();
    for (final op in const ['==', '!=', '<=', '>=', '<', '>']) {
      if (_peek(op)) {
        pos += op.length;
        final right = parsePrimary();
        return _BoolValue(_compare(left, right, op));
      }
    }
    return left;
  }

  bool _compare(_Value a, _Value b, String op) {
    if (a is _IntValue && b is _IntValue) {
      switch (op) {
        case '==':
          return a.value == b.value;
        case '!=':
          return a.value != b.value;
        case '<':
          return a.value < b.value;
        case '>':
          return a.value > b.value;
        case '<=':
          return a.value <= b.value;
        case '>=':
          return a.value >= b.value;
      }
    }
    final as = _asString(a);
    final bs = _asString(b);
    switch (op) {
      case '==':
        return as == bs;
      case '!=':
        return as != bs;
      case '<':
        return as.compareTo(bs) < 0;
      case '>':
        return as.compareTo(bs) > 0;
      case '<=':
        return as.compareTo(bs) <= 0;
      case '>=':
        return as.compareTo(bs) >= 0;
    }
    return false;
  }

  String _asString(_Value v) {
    if (v is _StringValue) return v.value;
    if (v is _IntValue) return v.value.toString();
    if (v is _BoolValue) return v.value.toString();
    return '';
  }

  _Value parsePrimary() {
    _skip();
    if (pos >= src.length) {
      throw PreprocessorException(
          'unexpected end of expression', lineNo);
    }
    final c = src[pos];
    if (c == '(') {
      pos++;
      final v = parseOr();
      _skip();
      if (pos >= src.length || src[pos] != ')') {
        throw PreprocessorException(
            'expected ")"', lineNo);
      }
      pos++;
      return v;
    }
    if (c == '"') {
      pos++;
      final sb = StringBuffer();
      while (pos < src.length && src[pos] != '"') {
        sb.write(src[pos]);
        pos++;
      }
      if (pos >= src.length) {
        throw PreprocessorException(
            'unterminated string literal', lineNo);
      }
      pos++;
      return _StringValue(sb.toString());
    }
    if (_isDigit(c)) {
      var j = pos;
      while (j < src.length && _isDigit(src[j])) {
        j++;
      }
      final n = int.parse(src.substring(pos, j));
      pos = j;
      return _IntValue(n);
    }
    if (_isIdent(c)) {
      var j = pos;
      while (j < src.length && _isIdentChar(src[j])) {
        j++;
      }
      final name = src.substring(pos, j);
      pos = j;
      if (name == 'defined') {
        _skip();
        if (pos >= src.length || src[pos] != '(') {
          throw PreprocessorException(
              'defined requires "(name)"', lineNo);
        }
        pos++;
        _skip();
        var k = pos;
        while (k < src.length && _isIdentChar(src[k])) {
          k++;
        }
        final n = src.substring(pos, k);
        pos = k;
        _skip();
        if (pos >= src.length || src[pos] != ')') {
          throw PreprocessorException(
              'expected ")"', lineNo);
        }
        pos++;
        return _BoolValue(macros.containsKey(n));
      }
      if (name == 'true') return _BoolValue(true);
      if (name == 'false') return _BoolValue(false);
      final macro = macros[name];
      if (macro == null) return _StringValue('');
      final body = macro.body;
      final n = int.tryParse(body);
      if (n != null) return _IntValue(n);
      return _StringValue(body);
    }
    throw PreprocessorException(
        'unexpected character "$c" in expression', lineNo);
  }

  bool _isDigit(String s) {
    final c = s.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  bool _isIdent(String s) {
    final c = s.codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        c == 0x5F;
  }

  bool _isIdentChar(String s) {
    final c = s.codeUnitAt(0);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        c == 0x5F;
  }

  bool _truthy(_Value v) {
    if (v is _BoolValue) return v.value;
    if (v is _IntValue) return v.value != 0;
    if (v is _StringValue) return v.value.isNotEmpty;
    return false;
  }

  void expectEnd() {
    _skip();
    if (pos != src.length) {
      throw PreprocessorException(
          'trailing characters in expression: "${src.substring(pos)}"',
          lineNo);
    }
  }
}

