import 'package:flutter/painting.dart';

import 'colors.dart';

TextSpan parseInlineMarkup(String input, TextStyle baseStyle) {
  final parser = _Parser(input);
  final children = parser.parse();
  return TextSpan(style: baseStyle, children: children);
}

enum _TagKind { bold, italic, underline, strikethrough, color, size }

class _OpenTag {
  final _TagKind kind;
  final String rawOpen;
  final List<InlineSpan> children;
  final Color? color;
  final double? size;
  _OpenTag({
    required this.kind,
    required this.rawOpen,
    this.color,
    this.size,
  }) : children = <InlineSpan>[];
}

class _Parser {
  final String input;
  int _pos = 0;
  final StringBuffer _buf = StringBuffer();
  final List<_OpenTag> _stack = <_OpenTag>[];
  final List<InlineSpan> _root = <InlineSpan>[];

  _Parser(this.input);

  List<InlineSpan> parse() {
    while (_pos < input.length) {
      final ch = input[_pos];

      if (ch == '\\' && _pos + 1 < input.length && input[_pos + 1] == 'n') {
        _flushText();
        _appendSpan(const TextSpan(text: '\n'));
        _pos += 2;
        continue;
      }

      if (ch == '<') {
        if (_tryConsumeTag()) continue;
      }

      if (ch == '*' && _peek(1) == '*') {
        if (_toggleMarkdown(_TagKind.bold, '**')) {
          _pos += 2;
          continue;
        }
      }

      if (ch == '/' && _peek(1) == '/') {
        if (_toggleMarkdown(_TagKind.italic, '//')) {
          _pos += 2;
          continue;
        }
      }

      if (ch == '_' && _peek(1) == '_') {
        if (_toggleMarkdown(_TagKind.underline, '__')) {
          _pos += 2;
          continue;
        }
      }

      if (ch == '~' && _peek(1) == '~') {
        if (_toggleMarkdown(_TagKind.strikethrough, '~~')) {
          _pos += 2;
          continue;
        }
      }

      _buf.write(ch);
      _pos++;
    }

    _flushText();
    while (_stack.isNotEmpty) {
      _collapseTop();
    }
    return _root;
  }

  String? _peek(int offset) {
    final p = _pos + offset;
    if (p < 0 || p >= input.length) return null;
    return input[p];
  }

  bool _toggleMarkdown(_TagKind kind, String marker) {
    final idx = _findOpenIndex(kind);
    if (idx >= 0) {
      _flushText();
      _closeTo(idx);
      return true;
    }
    _flushText();
    _stack.add(_OpenTag(kind: kind, rawOpen: marker));
    return true;
  }

  int _findOpenIndex(_TagKind kind) {
    for (var i = _stack.length - 1; i >= 0; i--) {
      if (_stack[i].kind == kind) return i;
    }
    return -1;
  }

  bool _tryConsumeTag() {
    final close = input.indexOf('>', _pos + 1);
    if (close < 0) return false;
    final inner = input.substring(_pos + 1, close);
    if (inner.isEmpty) return false;

    final lower = inner.toLowerCase();

    if (lower == 'br' || lower == 'br/' || lower == 'br /') {
      _flushText();
      _appendSpan(const TextSpan(text: '\n'));
      _pos = close + 1;
      return true;
    }

    final isClosing = inner.startsWith('/');
    if (isClosing) {
      final name = inner.substring(1).toLowerCase().trim();
      final kind = _kindForCloseName(name);
      if (kind == null) return false;
      final idx = _findOpenIndex(kind);
      if (idx < 0) return false;
      _flushText();
      _closeTo(idx);
      _pos = close + 1;
      return true;
    }

    final tag = _parseOpenTag(inner);
    if (tag == null) return false;
    _flushText();
    _stack.add(tag);
    _pos = close + 1;
    return true;
  }

  _TagKind? _kindForCloseName(String name) {
    switch (name) {
      case 'b':
        return _TagKind.bold;
      case 'i':
        return _TagKind.italic;
      case 'u':
        return _TagKind.underline;
      case 's':
      case 'strike':
        return _TagKind.strikethrough;
      case 'color':
        return _TagKind.color;
      case 'size':
        return _TagKind.size;
      default:
        return null;
    }
  }

  _OpenTag? _parseOpenTag(String inner) {
    final trimmed = inner.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    if (lower == 'b') {
      return _OpenTag(kind: _TagKind.bold, rawOpen: '<$inner>');
    }
    if (lower == 'i') {
      return _OpenTag(kind: _TagKind.italic, rawOpen: '<$inner>');
    }
    if (lower == 'u') {
      return _OpenTag(kind: _TagKind.underline, rawOpen: '<$inner>');
    }
    if (lower == 's' || lower == 'strike') {
      return _OpenTag(kind: _TagKind.strikethrough, rawOpen: '<$inner>');
    }

    if (lower.startsWith('color:') || lower.startsWith('color=')) {
      final spec = trimmed.substring(6).trim();
      final color = tryParseColor(spec);
      if (color == null) return null;
      return _OpenTag(
        kind: _TagKind.color,
        rawOpen: '<$inner>',
        color: color,
      );
    }

    if (lower.startsWith('size:') || lower.startsWith('size=')) {
      final spec = trimmed.substring(5).trim();
      final size = double.tryParse(spec);
      if (size == null || size <= 0) return null;
      return _OpenTag(
        kind: _TagKind.size,
        rawOpen: '<$inner>',
        size: size,
      );
    }

    return null;
  }

  void _flushText() {
    if (_buf.isEmpty) return;
    final text = _buf.toString();
    _buf.clear();
    _appendSpan(TextSpan(text: text));
  }

  void _appendSpan(InlineSpan span) {
    if (_stack.isEmpty) {
      _root.add(span);
    } else {
      _stack.last.children.add(span);
    }
  }

  void _closeTo(int idx) {
    while (_stack.length > idx + 1) {
      _collapseTopAsLiteral();
    }
    _collapseTop();
  }

  void _collapseTop() {
    final top = _stack.removeLast();
    final span = TextSpan(
      style: _styleFor(top),
      children: top.children.isEmpty ? null : top.children,
      text: top.children.isEmpty ? '' : null,
    );
    _appendSpan(span);
  }

  void _collapseTopAsLiteral() {
    final top = _stack.removeLast();
    final spans = <InlineSpan>[TextSpan(text: top.rawOpen)];
    spans.addAll(top.children);
    for (final s in spans) {
      _appendSpan(s);
    }
  }

  TextStyle _styleFor(_OpenTag tag) {
    switch (tag.kind) {
      case _TagKind.bold:
        return const TextStyle(fontWeight: FontWeight.bold);
      case _TagKind.italic:
        return const TextStyle(fontStyle: FontStyle.italic);
      case _TagKind.underline:
        return const TextStyle(decoration: TextDecoration.underline);
      case _TagKind.strikethrough:
        return const TextStyle(decoration: TextDecoration.lineThrough);
      case _TagKind.color:
        return TextStyle(color: tag.color);
      case _TagKind.size:
        return TextStyle(fontSize: tag.size);
    }
  }
}
