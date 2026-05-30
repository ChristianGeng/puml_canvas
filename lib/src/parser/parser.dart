import 'dart:convert';

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import '../lexer/token.dart';
import '../text/colors.dart' as text_colors;
import 'ebnf_parser.dart';

class ParserException implements Exception {
  final String message;
  final int line;
  final int column;
  ParserException(this.message, this.line, this.column);
  @override
  String toString() => 'ParserException($line:$column): $message';
}

const _groupKinds = <String, GroupKind>{
  'alt': GroupKind.alt,
  'opt': GroupKind.opt,
  'loop': GroupKind.loop,
  'par': GroupKind.par,
  'group': GroupKind.group,
  'partition': GroupKind.group,
};

const _participantKinds = <String, ParticipantKind>{
  'participant': ParticipantKind.participant,
  'actor': ParticipantKind.actor,
  'boundary': ParticipantKind.boundary,
  'control': ParticipantKind.control,
  'entity': ParticipantKind.entity,
  'database': ParticipantKind.database,
  'collections': ParticipantKind.collections,
  'queue': ParticipantKind.queue,
};

class Parser {
  late List<Token> _tokens;
  var _pos = 0;
  final _autonumber = _AutonumberState();
  var _decorations = _DiagramDecorationBuilder();
  final _pendingMessageAliases = <String, String>{};
  Message? _lastForwardMessage;
  // Monotonic counter used to mint unique placeholder aliases for anonymous
  // "found" / "lost" message endpoints. Reset per parse() invocation.
  int _externalEndpointCounter = 0;
  // Monotonic counter used to mint unique placeholder aliases for empty
  // bracket components (`[ ]`). Reset per parse() invocation.
  int _anonBracketCounter = 0;
  bool _autoactivate = false;
  // Set by `hide unlinked` at top-level sequence scope. Order-independent —
  // applied as a filter on participantsInOrder() at render time.
  bool _hideUnlinked = false;
  // Set by `hide footbox` at top-level sequence scope. Order-independent —
  // suppresses the bottom (foot) participant boxes/symbols at render time.
  bool _hideFootbox = false;
  // Set by `skinparam actorStyle <value>` at top-level sequence scope.
  // Layout/renderer use this to switch actor visuals (e.g. `awesome` paints
  // a cartoonier figure instead of the default stick figure).
  String? _actorStyle;
  // Set by `ignore newpage` at top-level sequence scope. When true,
  // subsequent `newpage` / `newpage <title>` directives are consumed but
  // produce no NewPage event — the diagram renders as a single page.
  bool _ignoreNewpage = false;
  // Set by `_tryConsumeAllowmixing()` whenever the `allowmixing` directive
  // is seen at line start. Used by host parsers (notably class diagram) to
  // accept-and-skip mixed-element declarations (component / use-case shape
  // keywords like `actor`, `actor/`, `usecase/`, `agent`, `card`, ...) that
  // they don't natively model. Resets per `parse()` invocation.
  bool _allowMixing = false;
  // Set by the `mainframe <label>` directive at top-level sequence scope.
  // Layout consumes this to wrap the diagram in a UML frame with a folded-
  // corner tab in the top-left. Inline markup (e.g. `**bold**`) is honoured
  // at render time via `parseInlineMarkup`.
  String? _mainframeLabel;
  // Stack of (caller, callee, callColor) frames used by `autoactivate on` to
  // lower `return label` into a reverse dashed message + Deactivate. Only
  // forward, non-self, non-destroy calls push a frame.
  final List<(String, String, Color?)> _callStack = [];
  // Insertion-ordered set of participant aliases seen so far during the
  // current sequence-diagram parse. Populated by explicit participant
  // declarations and by message endpoints (excluding the synthetic
  // `__external_*` placeholders for found/lost arrows). Consumed by
  // `_parseNote` to resolve `note across` / `hnote across` shorthand to the
  // current first..last participant span.
  final Set<String> _declaredAliases = <String>{};
  // Inline member declarations of the form `ClassName : member` collected
  // during class-diagram parsing. Merged into the corresponding ClassDecl's
  // `members` list at the end of the parse. Reset per `parse()` invocation.
  final Map<String, List<ClassMember>> _classInlineMembers =
      <String, List<ClassMember>>{};

  Diagram parse(List<Token> tokens) {
    _tokens = tokens;
    _pos = 0;
    _autonumber.reset();
    _decorations = _DiagramDecorationBuilder();
    _pendingMessageAliases.clear();
    _lastForwardMessage = null;
    _externalEndpointCounter = 0;
    _anonBracketCounter = 0;
    _autoactivate = false;
    _hideUnlinked = false;
    _hideFootbox = false;
    _actorStyle = null;
    _ignoreNewpage = false;
    _allowMixing = false;
    _mainframeLabel = null;
    _callStack.clear();
    _declaredAliases.clear();
    _classInlineMembers.clear();

    _skipNewlines();
    if (_check(TokenType.startMindmap)) {
      _advance();
      _skipNewlines();
      return _parseMindmapDiagram();
    }
    if (_check(TokenType.startWbs)) {
      _advance();
      _skipNewlines();
      return _parseWbsDiagram();
    }
    if (_check(TokenType.startJson)) {
      _advance();
      _skipNewlines();
      return _parseJsonDiagram();
    }
    if (_check(TokenType.startYaml)) {
      _advance();
      _skipNewlines();
      return _parseYamlDiagram();
    }
    if (_check(TokenType.startSalt)) {
      _advance();
      _skipNewlines();
      return _parseSaltDiagram();
    }
    if (_check(TokenType.startGantt)) {
      _advance();
      _skipNewlines();
      return _parseGanttDiagram();
    }
    if (_check(TokenType.startNwdiag)) {
      _advance();
      _skipNewlines();
      return _parseNetworkDiagram();
    }
    if (_check(TokenType.startEbnf)) {
      _advance();
      _skipNewlines();
      return _parseEbnfDiagram();
    }
    _expect(TokenType.startUml);
    _skipNewlines();

    if (_looksLikeTimingDiagram()) {
      return _parseTimingDiagram();
    }
    // Sequence indicators (`participant`/`actor`/etc. at a line start) win
    // over activity's `partition` so a sequence diagram that uses partition
    // as a group block doesn't get misrouted.
    if (_hasSequenceParticipantMarker() && _looksLikeActivityDiagram()) {
      // Fall through to sequence below.
    } else if (_looksLikeActivityDiagram()) {
      return _parseActivityDiagram();
    }
    // An unambiguous class marker (`class`, `enum`, `abstract`, etc.) at line
    // start wins over the use-case heuristic — use-case detection can fire on
    // PlantUML class-diagram constructs that include parenthesized endpoints
    // (e.g. association-class `(A, B) .. C`) which look use-case-like but are
    // class-diagram syntax when a class header keyword is present.
    if (_hasUnambiguousClassMarker()) {
      return _parseClassDiagram();
    }
    // State-diagram markers (`[*]`, `state`/`State` keyword) are very strong
    // signals — give state detection priority over use-case detection so
    // sources that mix `[*]` pseudo-states with direction-hint arrows or
    // arrow-style modifiers (`-[#color]->`) don't get misrouted.
    if (_looksLikeStateDiagram()) {
      return _parseStateDiagram();
    }
    // When the source has an unambiguous component-/deployment-diagram
    // keyword at line start (e.g. `artifact`, `cloud`, `node`, `card`,
    // `agent`, `stack`, `sprite`, `hexagon`, or a typed-container keyword
    // like `database`/`queue`/`storage`), the component-diagram detector
    // takes priority over the use-case detector. This prevents a stray
    // `rectangle` declaration (which is overloaded between the two diagram
    // families) from routing a deployment source to the use-case parser.
    if (_hasUnambiguousComponentMarker() && _looksLikeComponentDiagram()) {
      return _parseComponentDiagram();
    }
    if (_looksLikeUseCaseDiagram()) {
      return _parseUseCaseDiagram();
    }
    // A bare `json` keyword inside `@startuml ... @enduml` declares an
    // inline JSON-rendered block. Route to the JSON diagram parser before
    // the component / class detectors so that JSON-body content (e.g.
    // bracket tokens at line start inside arrays) doesn't accidentally
    // trigger component-diagram routing.
    if (_looksLikeInlineJsonDiagram()) {
      return _parseInlineJsonAsDataDiagram();
    }
    if (_looksLikeComponentDiagram()) {
      return _parseComponentDiagram();
    }
    if (_looksLikeClassDiagram()) {
      return _parseClassDiagram();
    }

    final participants = <Participant>[];
    final events = <SequenceEvent>[];
    final boxes = <ParticipantBox>[];
    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeAllowmixing()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeInlineJsonBlock()) {
        _skipNewlines();
        continue;
      }
      final kind = _check(TokenType.identifier)
          ? _participantKinds[_peek().lexeme]
          : null;
      if (kind != null) {
        participants.add(_parseParticipant(kind));
      } else if (_check(TokenType.colon)) {
        // Implicit actor declaration: `:Display name: [as Alias]` at line
        // start. The leading `:` and the trailing `:` form a colon-wrapped
        // display name. Defaults the kind to actor.
        participants.add(_parseInlineActorDeclaration());
      } else if (_isKeyword('create')) {
        _parseCreate(participants, events);
      } else if (_isKeyword('destroy')) {
        _parseDestroy(events);
      } else if (_isKeyword('box')) {
        boxes.add(_parseBox(participants));
      } else if (_isKeyword('autonumber')) {
        _parseAutonumber();
      } else if (_isKeyword('autoactivate')) {
        _parseAutoactivate();
      } else if (_isKeyword('hide') || _isKeyword('show')) {
        _parseHideShow();
      } else if (_isKeyword('mainframe')) {
        _parseMainframe();
      } else {
        _parseEvent(events);
      }
      _skipNewlines();
    }

    _expect(TokenType.endUml);
    return SequenceDiagram(
      participants: List.unmodifiable(participants),
      events: List.unmodifiable(events),
      boxes: List.unmodifiable(boxes),
      aliasDisplayNames: Map.unmodifiable(_pendingMessageAliases),
      autoactivate: _autoactivate,
      hideUnlinked: _hideUnlinked,
      hideFootbox: _hideFootbox,
      actorStyle: _actorStyle,
      mainframeLabel: _mainframeLabel,
      decorations: _decorations.build(),
    );
  }

  /// Parses a `mainframe <label>` directive at sequence-top-level scope.
  ///
  /// The lexer captures the rest of the line as a single text token so
  /// inline markup (e.g. `**bold**`) survives intact. A bare `mainframe`
  /// with no label is accepted and stored as an empty string so layout
  /// still draws the wrapping frame.
  void _parseMainframe() {
    _advance(); // consume 'mainframe' identifier
    String label = '';
    if (_check(TokenType.text)) {
      label = _advance().lexeme;
    }
    _mainframeLabel = label;
  }

  /// Parses a sequence-scope `hide` / `show` directive line.
  ///
  /// `hide unlinked` sets [_hideUnlinked], which the layout uses to drop
  /// participants that no message references. `hide footbox` sets
  /// [_hideFootbox], which suppresses the bottom row of participant
  /// boxes/symbols at render time. Other variants (e.g. `show Alice`) are
  /// accepted but currently no-ops; we consume the rest of the line so they
  /// parse without error.
  void _parseHideShow() {
    final keyword = _advance().lexeme; // 'hide' or 'show'
    if (keyword == 'hide' && _check(TokenType.identifier)) {
      final word = _peek().lexeme;
      if (word == 'unlinked') {
        _advance();
        _hideUnlinked = true;
      } else if (word == 'footbox') {
        _advance();
        _hideFootbox = true;
      }
    }
    _consumeRestOfLine();
  }

  bool _tryParseDecoration() {
    if (_isKeyword('title')) {
      final t = _peek();
      if (_decorations.title != null) {
        throw ParserException('Duplicate title directive', t.line, t.column);
      }
      _decorations.title = _parseDecorationText('title');
      return true;
    }
    if (_isKeyword('caption')) {
      final t = _peek();
      if (_decorations.caption != null) {
        throw ParserException(
            'Duplicate caption directive', t.line, t.column);
      }
      _decorations.caption = _parseDecorationText('caption');
      return true;
    }
    if (_isKeyword('header')) {
      final t = _peek();
      if (_decorations.header != null) {
        throw ParserException('Duplicate header directive', t.line, t.column);
      }
      _decorations.header = _parseHeaderFooter('header');
      return true;
    }
    if (_isKeyword('footer')) {
      final t = _peek();
      if (_decorations.footer != null) {
        throw ParserException('Duplicate footer directive', t.line, t.column);
      }
      _decorations.footer = _parseHeaderFooter('footer');
      return true;
    }
    if (_isKeyword('legend')) {
      final t = _peek();
      if (_decorations.legend != null) {
        throw ParserException('Duplicate legend directive', t.line, t.column);
      }
      _decorations.legend = _parseLegend();
      return true;
    }
    if (_isKeyword('skinparam')) {
      _parseSkinparam();
      return true;
    }
    return false;
  }

  void _parseSkinparam() {
    _advance();
    if (_check(TokenType.leftBrace)) {
      _parseSkinparamBlock('');
      return;
    }
    if (!_check(TokenType.identifier)) {
      final t = _peek();
      throw ParserException(
          "Expected skinparam key, got ${t.type}", t.line, t.column);
    }
    final first = _advance().lexeme;
    if (_check(TokenType.leftBrace)) {
      _parseSkinparamBlock(first);
      return;
    }
    // PlantUML supports per-stereotype overrides at the top level:
    // `skinparam <key><<Stereo>> <value>` and the multi-line block form
    // `skinparam <key><<Stereo>> { ... }`. We don't model per-stereotype
    // skin overrides yet, so consume the stereotype tag, then either skip
    // the rest of the line or, if a `{` block opens, brace-balance-skip
    // until the matching `}`.
    if (_check(TokenType.stereotype)) {
      _advance();
      // Optional second stereotype (e.g. `skinparam r<<a>><<b>> { ... }`).
      while (_check(TokenType.stereotype)) {
        _advance();
      }
      if (_check(TokenType.leftBrace)) {
        var depth = 0;
        while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
          if (_check(TokenType.leftBrace)) {
            depth++;
            _advance();
            continue;
          }
          if (_check(TokenType.rightBrace)) {
            depth--;
            _advance();
            if (depth == 0) break;
            continue;
          }
          _advance();
        }
        if (_check(TokenType.newline)) _advance();
        return;
      }
      while (!_check(TokenType.newline) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        _advance();
      }
      if (_check(TokenType.newline)) _advance();
      return;
    }
    _applySkinparam(first, _readSkinparamValue());
    if (_check(TokenType.newline)) _advance();
  }

  void _parseSkinparamBlock(String prefix) {
    _advance();
    _skipNewlines();
    while (!_check(TokenType.rightBrace) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      if (!_check(TokenType.identifier)) {
        final t = _peek();
        throw ParserException(
            "Expected skinparam key inside block, got ${t.type}",
            t.line,
            t.column);
      }
      final key = _advance().lexeme;
      // PlantUML lets per-stereotype overrides ride inside a skinparam block,
      // e.g. `BackgroundColor<< Main >> YellowGreen`. The lexer emits the
      // `<< ... >>` as a single [TokenType.stereotype] token. We don't yet
      // model per-stereotype skin overrides, so consume the rest of the line
      // and continue without applying anything.
      if (_check(TokenType.stereotype)) {
        while (!_check(TokenType.newline) &&
            !_check(TokenType.rightBrace) &&
            !_check(TokenType.eof) &&
            !_check(TokenType.endUml)) {
          _advance();
        }
        _skipNewlines();
        continue;
      }
      final value = _readSkinparamValue();
      _applySkinparam('$prefix$key', value);
      _skipNewlines();
    }
    if (_check(TokenType.rightBrace)) {
      _advance();
    }
  }

  Token _readSkinparamValue() {
    if (_check(TokenType.hashColor) ||
        _check(TokenType.identifier) ||
        _check(TokenType.stringLiteral)) {
      return _advance();
    }
    final t = _peek();
    throw ParserException(
        "Expected skinparam value, got ${t.type}", t.line, t.column);
  }

  void _applySkinparam(String key, Token value) {
    final lower = key.toLowerCase();
    Color? parseColor() {
      return text_colors.tryParseColor(value.lexeme);
    }

    double? parseSize() {
      final n = int.tryParse(value.lexeme);
      return n?.toDouble();
    }

    SkinParams? update;
    switch (lower) {
      case 'actorstyle':
        _actorStyle = value.lexeme;
        return;
      case 'backgroundcolor':
        final c = parseColor();
        if (c != null) update = SkinParams(backgroundColor: c);
      case 'defaultfontsize':
        final s = parseSize();
        if (s != null) update = SkinParams(defaultFontSize: s);
      case 'sequencearrowcolor':
        final c = parseColor();
        if (c != null) update = SkinParams(sequenceArrowColor: c);
      case 'sequencelifelinebackgroundcolor':
        final c = parseColor();
        if (c != null) update = SkinParams(sequenceLifeLineBackgroundColor: c);
      case 'participantbackgroundcolor':
        final c = parseColor();
        if (c != null) update = SkinParams(participantBackgroundColor: c);
      case 'participantbordercolor':
        final c = parseColor();
        if (c != null) update = SkinParams(participantBorderColor: c);
      case 'notebackgroundcolor':
        final c = parseColor();
        if (c != null) update = SkinParams(noteBackgroundColor: c);
      case 'notebordercolor':
        final c = parseColor();
        if (c != null) update = SkinParams(noteBorderColor: c);
      default:
        return;
    }
    if (update != null) {
      _decorations.skin = _decorations.skin.merge(update);
    }
  }

  String _parseDecorationText(String keyword) {
    final startToken = _advance();
    if (_check(TokenType.newline)) {
      return _consumeMultilineBody(keyword, startToken);
    }
    final text = _collectInlineText();
    if (text == null) {
      throw ParserException(
          "Expected text after '$keyword'", startToken.line, startToken.column);
    }
    // PlantUML's block form `title <inline text>\n<body>\nend title` mixes an
    // inline opener line with additional body lines. If we see body content
    // followed by `end <keyword>`, treat the inline text as the first body
    // line and append the remaining lines.
    if (_check(TokenType.newline) && _peekHasMatchingEnd(keyword)) {
      final rest = _consumeMultilineBody(keyword, startToken);
      if (rest.isEmpty) {
        return text.replaceAll(r'\n', '\n');
      }
      return '${text.replaceAll(r'\n', '\n')}\n$rest';
    }
    // PlantUML allows `\n` as a literal newline marker in single-line
    // decoration text (title, caption, header, footer). Normalize it so the
    // renderer sees a real newline character.
    return text.replaceAll(r'\n', '\n');
  }

  /// Returns true if the token stream from the current position contains an
  /// `end <keyword>` (e.g. `end title`) before EOF / `@enduml`. Used to detect
  /// the mixed block form where the opener line carries inline text and
  /// subsequent lines extend the body.
  bool _peekHasMatchingEnd(String keyword) {
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.eof || t.type == TokenType.endUml) return false;
      if (t.type == TokenType.identifier &&
          t.lexeme == 'end' &&
          k + 1 < _tokens.length &&
          _tokens[k + 1].type == TokenType.identifier &&
          _tokens[k + 1].lexeme == keyword) {
        return true;
      }
    }
    return false;
  }

  HeaderFooter _parseHeaderFooter(String keyword) {
    final startToken = _advance();
    var align = TextAlign.center;
    if (_check(TokenType.identifier)) {
      final word = _peek().lexeme;
      if (word == 'center' || word == 'left' || word == 'right') {
        final next = _pos + 1 < _tokens.length ? _tokens[_pos + 1] : null;
        if (next != null &&
            (next.type == TokenType.newline ||
                next.type == TokenType.identifier ||
                next.type == TokenType.stringLiteral ||
                next.type == TokenType.text ||
                next.type == TokenType.colon)) {
          _advance();
          switch (word) {
            case 'left':
              align = TextAlign.left;
            case 'right':
              align = TextAlign.right;
            default:
              align = TextAlign.center;
          }
        }
      }
    }
    if (_check(TokenType.newline)) {
      final body = _consumeMultilineBody(keyword, startToken);
      return HeaderFooter(text: body, align: align);
    }
    final text = _collectInlineText();
    if (text == null) {
      throw ParserException(
          "Expected text after '$keyword'", startToken.line, startToken.column);
    }
    return HeaderFooter(text: text, align: align);
  }

  String? _collectInlineText() {
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) return _advance().lexeme;
      return null;
    }
    final parts = <String>[];
    while (!_check(TokenType.newline) && !_check(TokenType.eof)) {
      parts.add(_advance().lexeme);
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  Legend _parseLegend() {
    final startToken = _advance();
    var align = TextAlign.left;
    if (_check(TokenType.identifier)) {
      final word = _peek().lexeme;
      if (word == 'center' || word == 'left' || word == 'right') {
        final next = _pos + 1 < _tokens.length ? _tokens[_pos + 1] : null;
        if (next != null && next.type == TokenType.newline) {
          _advance();
          switch (word) {
            case 'left':
              align = TextAlign.left;
            case 'right':
              align = TextAlign.right;
            default:
              align = TextAlign.center;
          }
        }
      }
    }
    if (!_check(TokenType.newline)) {
      throw ParserException("Expected newline after 'legend'", startToken.line,
          startToken.column);
    }
    _advance();
    final lines = <String>[];
    while (true) {
      if (_check(TokenType.eof) || _check(TokenType.endUml)) {
        throw ParserException("Expected 'endlegend' to close legend",
            startToken.line, startToken.column);
      }
      if (_check(TokenType.identifier) && _peek().lexeme == 'endlegend') {
        _advance();
        return Legend(text: lines.join('\n'), align: align);
      }
      if (_isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'legend') {
        _advance();
        _advance();
        return Legend(text: lines.join('\n'), align: align);
      }
      if (_check(TokenType.text)) {
        lines.add(_advance().lexeme);
      }
      if (_check(TokenType.newline)) _advance();
    }
  }

  String _consumeMultilineBody(String keyword, Token openToken) {
    _advance();
    final lines = <String>[];
    var current = <String>[];
    while (true) {
      if (_check(TokenType.eof) || _check(TokenType.endUml)) {
        throw ParserException(
            "Expected 'end $keyword' to close multi-line $keyword",
            openToken.line,
            openToken.column);
      }
      final atLineStart =
          _pos == 0 || _tokens[_pos - 1].type == TokenType.newline;
      if (atLineStart &&
          _isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == keyword) {
        _advance();
        _advance();
        return lines.join('\n');
      }
      if (_check(TokenType.newline)) {
        _advance();
        lines.add(current.join(' '));
        current = <String>[];
        continue;
      }
      current.add(_advance().lexeme);
    }
  }

  ParticipantBox _parseBox(List<Participant> topLevelParticipants) {
    final boxToken = _advance();
    if (!_check(TokenType.stringLiteral)) {
      final t = _peek();
      throw ParserException(
          "Expected box label string after 'box', got ${t.type}",
          t.line,
          t.column);
    }
    final label = _advance().lexeme;

    Color? color;
    if (_check(TokenType.hashColor)) {
      final t = _advance();
      color = _parseColor(t.lexeme, t);
    }

    _skipNewlines();

    final inner = <Participant>[];
    final children = <ParticipantBox>[];
    while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
      if (_isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'box') {
        _advance();
        _advance();
        return ParticipantBox(
          label: label,
          color: color,
          participants: List.unmodifiable(inner),
          children: List.unmodifiable(children),
        );
      }
      if (_isKeyword('box')) {
        children.add(_parseBox(topLevelParticipants));
        _skipNewlines();
        continue;
      }
      final kind = _check(TokenType.identifier)
          ? _participantKinds[_peek().lexeme]
          : null;
      if (kind == null) {
        final t = _peek();
        throw ParserException(
            'Only participant declarations are allowed inside a box, got \'${t.lexeme}\'',
            t.line,
            t.column);
      }
      final p = _parseParticipant(kind);
      inner.add(p);
      topLevelParticipants.add(p);
      _skipNewlines();
    }
    throw ParserException(
        "Expected 'end box' to close box", boxToken.line, boxToken.column);
  }

  void _parseEvent(List<SequenceEvent> out) {
    if (_check(TokenType.leftBrace) &&
        _pos + 2 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.identifier &&
        _tokens[_pos + 2].type == TokenType.rightBrace) {
      _advance();
      _advance();
      _advance();
      if (_check(TokenType.newline) || _check(TokenType.eof)) {
        return;
      }
      if (_check(TokenType.arrow)) {
        _collectLineRemainder();
        return;
      }
    }
    if (_isKeyword('autonumber')) {
      _parseAutonumber();
      return;
    }
    if (_isKeyword('autoactivate')) {
      _parseAutoactivate();
      return;
    }
    if (_isKeyword('return')) {
      _advance();
      final label = _collectInlineText();
      // PlantUML semantics: `return` is a reply from the current callee back
      // to its caller. Whenever the call stack has a frame (because
      // `autoactivate on` was active OR the caller used an explicit `++`/`**`
      // suffix) we pop it so chained returns unwind to the original caller.
      // Otherwise fall back to the last forward message (legacy behaviour).
      String? callee;
      String? caller;
      if (_callStack.isNotEmpty) {
        final frame = _callStack.removeLast();
        caller = frame.$1;
        callee = frame.$2;
      } else {
        final last = _lastForwardMessage;
        if (last != null) {
          caller = last.from;
          callee = last.to;
        }
      }
      if (callee != null && caller != null) {
        out.add(Message(
          from: callee,
          to: caller,
          label: label == null ? null : _expandText(label),
          lineStyle: LineStyle.dashed,
          head: ArrowHead.open,
          direction: MessageDirection.backward,
          activation: ActivationSuffix.deactivateSource,
        ));
        out.add(Deactivate(callee));
      }
      return;
    }
    if (_isKeyword('note') ||
        _isKeyword('hnote') ||
        _isKeyword('rnote')) {
      out.add(_parseNote());
      return;
    }
    if (_isKeyword('ref')) {
      out.add(_parseRef());
      return;
    }
    if (_isKeyword('activate')) {
      _advance();
      final name = _expect(TokenType.identifier).lexeme;
      Color? actColor;
      if (_check(TokenType.hashColor)) {
        final t = _advance();
        final raw =
            t.lexeme.startsWith('#') ? t.lexeme.substring(1) : t.lexeme;
        actColor = text_colors.tryParseColor(raw);
      }
      out.add(Activate(name, color: actColor));
      return;
    }
    if (_isKeyword('deactivate')) {
      _advance();
      final name = _expect(TokenType.identifier).lexeme;
      if (_check(TokenType.hashColor)) {
        _advance();
      }
      out.add(Deactivate(name));
      return;
    }
    if (_check(TokenType.doubleEquals)) {
      out.add(_parseTitleSeparator());
      return;
    }
    if (_check(TokenType.doublePipe)) {
      out.add(_parseDelaySeparator());
      return;
    }
    if (_check(TokenType.dotDotDot)) {
      _advance();
      String? skipLabel;
      if (_check(TokenType.text)) {
        skipLabel = _expandText(_advance().lexeme);
      }
      if (_check(TokenType.dotDotDot)) {
        _advance();
      }
      out.add(Separator(kind: SeparatorKind.skip, label: skipLabel));
      return;
    }
    if (_check(TokenType.minusMinus)) {
      _advance();
      out.add(const Separator(kind: SeparatorKind.dash));
      return;
    }
    if (_isKeyword('ignore') &&
        _pos + 1 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.identifier &&
        _tokens[_pos + 1].lexeme == 'newpage') {
      _advance();
      _advance();
      _collectLineRemainder();
      _ignoreNewpage = true;
      return;
    }
    if (_isKeyword('newpage')) {
      _advance();
      final title = _collectLineRemainder();
      if (_ignoreNewpage) {
        return;
      }
      out.add(NewPage(title));
      return;
    }
    if (_isKeyword('return')) {
      _advance();
      _collectLineRemainder();
      return;
    }
    if (_isKeyword('break')) {
      _advance();
      _collectLineRemainder();
      return;
    }
    if (_check(TokenType.identifier)) {
      final kind = _groupKinds[_peek().lexeme];
      if (kind != null) {
        out.add(_parseGroup(kind));
        return;
      }
    }
    // PlantUML sync directive: a standalone `/` line aligns the next event
    // with the previous one at the same Y. Visual alignment is currently
    // deferred — consume the token so the surrounding source still parses.
    if (_check(TokenType.slash)) {
      _advance();
      return;
    }
    // PlantUML standalone `&` line (used with `!pragma teoz true`): the next
    // event begins at the same Y as the previous one. Visual sync alignment
    // is currently deferred — we just consume the `&` and re-dispatch.
    //   * Bare `&` followed by a newline → no event.
    //   * `& A -> B` (prefix message form) → handled inside `_parseMessage`,
    //     which checks for a leading `&` itself; we fall through without
    //     consuming.
    //   * `& note ...` (prefix note form) → consume `&` and recurse into
    //     `_parseNote`.
    if (_check(TokenType.amp)) {
      if (_pos + 1 >= _tokens.length) {
        _advance();
        return;
      }
      final next = _tokens[_pos + 1];
      if (next.type == TokenType.newline ||
          next.type == TokenType.eof ||
          next.type == TokenType.endUml) {
        _advance();
        return;
      }
      if (next.type == TokenType.identifier &&
          (next.lexeme == 'note' ||
              next.lexeme == 'hnote' ||
              next.lexeme == 'rnote')) {
        _advance();
        out.add(_parseNote());
        return;
      }
      // Fall through: `_parseMessage` consumes the leading `&` for the
      // prefix message form and records `synchronized: true`.
    }
    _parseMessage(out);
  }

  Separator _parseTitleSeparator() {
    final open = _advance();
    String? label;
    if (_check(TokenType.text)) {
      label = _advance().lexeme;
    }
    if (!_check(TokenType.doubleEquals)) {
      throw ParserException(
          "Expected closing '==' for title separator", open.line, open.column);
    }
    _advance();
    return Separator(kind: SeparatorKind.title, label: label);
  }

  Separator _parseDelaySeparator() {
    final open = _advance();
    int? pixels;
    if (_check(TokenType.text)) {
      final t = _advance();
      pixels = int.tryParse(t.lexeme);
      if (pixels == null) {
        throw ParserException(
            "Expected integer between '||' markers, got '${t.lexeme}'",
            t.line,
            t.column);
      }
    }
    if (!_check(TokenType.doublePipe)) {
      throw ParserException(
          "Expected closing '||' for delay separator", open.line, open.column);
    }
    _advance();
    return Separator(kind: SeparatorKind.delay, delayPixels: pixels);
  }

  void _parseCreate(
      List<Participant> participants, List<SequenceEvent> events) {
    _advance();
    if (_check(TokenType.identifier)) {
      final kind = _participantKinds[_peek().lexeme];
      if (kind != null) {
        final participant = _parseParticipant(kind);
        participants.add(participant);
        events.add(Create(participant.alias));
        return;
      }
    }
    if (!_check(TokenType.identifier)) {
      final t = _peek();
      throw ParserException(
          "Expected participant name after 'create', got ${t.type}",
          t.line,
          t.column);
    }
    events.add(Create(_advance().lexeme));
  }

  void _parseAutoactivate() {
    _advance();
    // Optional argument: `on` / `off`. Anything else (or nothing) defaults to
    // turning autoactivate on, matching PlantUML's behaviour.
    var enable = true;
    if (_check(TokenType.identifier)) {
      final word = _peek().lexeme.toLowerCase();
      if (word == 'on') {
        _advance();
      } else if (word == 'off') {
        _advance();
        enable = false;
      }
    }
    _consumeRestOfLine();
    _autoactivate = enable;
    if (!enable) {
      _callStack.clear();
    }
  }

  void _parseAutonumber() {
    _advance();

    // The lexer captures the remainder of the autonumber line as a single
    // text token so multi-level versions (1.1.1), `inc <level>`, and quoted
    // formats can be parsed without lexer interference.
    String? raw;
    if (_check(TokenType.text)) {
      raw = _advance().lexeme.trim();
    }

    if (raw == null || raw.isEmpty) {
      _autonumber.current = 1;
      _autonumber.increment = 1;
      _autonumber.format = '%d';
      _autonumber.stopped = false;
      _autonumber.levels = null;
      return;
    }

    final lower = raw.toLowerCase();
    if (lower == 'stop') {
      _autonumber.stopped = true;
      return;
    }
    if (lower.startsWith('resume')) {
      _autonumber.stopped = false;
      final rest = raw.substring(6).trim();
      if (rest.isNotEmpty) {
        // `resume [increment] ["format"]` — keeps the counter; replaces
        // increment and/or format when present.
        final quoteIdx = rest.indexOf('"');
        final argsRaw =
            quoteIdx >= 0 ? rest.substring(0, quoteIdx).trim() : rest;
        if (quoteIdx >= 0) {
          final endQuote = rest.lastIndexOf('"');
          if (endQuote > quoteIdx) {
            _autonumber.format = rest.substring(quoteIdx + 1, endQuote);
          }
        }
        if (argsRaw.isNotEmpty) {
          final n = int.tryParse(argsRaw.split(RegExp(r'\s+')).first);
          if (n != null) _autonumber.increment = n;
        }
      }
      return;
    }
    if (lower.startsWith('inc ')) {
      final levelName = raw.substring(4).trim();
      final levels = _autonumber.levels ?? [_autonumber.current];
      final idx = levelName.isEmpty
          ? 0
          : levelName.codeUnitAt(0) - 'A'.codeUnitAt(0);
      if (idx >= 0 && idx < 26) {
        while (levels.length <= idx) {
          levels.add(0);
        }
        levels[idx]++;
        for (var k = idx + 1; k < levels.length; k++) {
          levels[k] = 1;
        }
        _autonumber.levels = levels;
        _autonumber.current = levels.first;
      }
      return;
    }

    // Extract optional trailing quoted format.
    String? format;
    final quoteIdx = raw.indexOf('"');
    final args = quoteIdx >= 0 ? raw.substring(0, quoteIdx).trim() : raw;
    if (quoteIdx >= 0) {
      final endQuote = raw.lastIndexOf('"');
      if (endQuote > quoteIdx) {
        format = raw.substring(quoteIdx + 1, endQuote);
      }
    }

    final parts = args.isEmpty ? <String>[] : args.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      final first = parts[0];
      if (first.contains('.')) {
        final levels = first
            .split('.')
            .map((s) => int.tryParse(s) ?? 1)
            .toList();
        _autonumber.levels = levels;
        _autonumber.current = levels.first;
      } else {
        final n = int.tryParse(first);
        if (n != null) {
          _autonumber.current = n;
          _autonumber.levels = null;
        }
      }
      if (parts.length >= 2) {
        final inc = int.tryParse(parts[1]);
        if (inc != null) _autonumber.increment = inc;
      }
    } else {
      _autonumber.current = 1;
    }
    if (format != null) _autonumber.format = format;
    _autonumber.stopped = false;
  }

  // Append matching close tags for any markup left open in the format string
  // so subsequent label text isn't inadvertently styled by the autonumber.
  String _closeOpenTags(String s) {
    final openRe = RegExp(r'<\s*(b|i|u|s|strike|color|font|size)\b[^>]*>',
        caseSensitive: false);
    final closeRe =
        RegExp(r'<\s*/\s*(b|i|u|s|strike|color|font|size)\s*>',
            caseSensitive: false);
    final stack = <String>[];
    var pos = 0;
    while (pos < s.length) {
      final lt = s.indexOf('<', pos);
      if (lt < 0) break;
      final openMatch = openRe.matchAsPrefix(s, lt);
      if (openMatch != null) {
        stack.add(openMatch.group(1)!.toLowerCase());
        pos = openMatch.end;
        continue;
      }
      final closeMatch = closeRe.matchAsPrefix(s, lt);
      if (closeMatch != null) {
        final tag = closeMatch.group(1)!.toLowerCase();
        for (var i = stack.length - 1; i >= 0; i--) {
          if (stack[i] == tag) {
            stack.removeAt(i);
            break;
          }
        }
        pos = closeMatch.end;
        continue;
      }
      pos = lt + 1;
    }
    final buf = StringBuffer(s);
    for (var i = stack.length - 1; i >= 0; i--) {
      buf.write('</${stack[i]}>');
    }
    return buf.toString();
  }

  // Expand inline placeholders in text: `<U+HHHH>` to the unicode character
  // and `%autonumber%` to the most-recently displayed autonumber value.
  String _expandText(String text) {
    var out = text.replaceAllMapped(
      RegExp(r'<U\+([0-9A-Fa-f]{2,6})>'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    final last = _autonumber.lastDisplayed;
    if (last != null) {
      out = out.replaceAll('%autonumber%', last);
    }
    return out;
  }

  String _formatAutonumber(int n, String format) {
    final cstyle = RegExp(r'%(0([1-9]))?d');
    final m2 = cstyle.firstMatch(format);
    if (m2 != null) {
      final widthGroup = m2.group(2);
      final text = widthGroup != null
          ? n.toString().padLeft(int.parse(widthGroup), '0')
          : n.toString();
      return format.replaceRange(m2.start, m2.end, text);
    }
    // PlantUML placeholders: a run of `0`s = zero-padded to that width; a run
    // of `#`s = unpadded number.
    final puml = RegExp(r'0+|#+');
    final match = puml.firstMatch(format);
    if (match != null) {
      final token = match.group(0)!;
      final text = token.startsWith('0')
          ? n.toString().padLeft(token.length, '0')
          : n.toString();
      return format.replaceRange(match.start, match.end, text);
    }
    return '$format $n';
  }

  void _parseDestroy(List<SequenceEvent> events) {
    _advance();
    if (!_check(TokenType.identifier)) {
      final t = _peek();
      throw ParserException(
          "Expected participant name after 'destroy', got ${t.type}",
          t.line,
          t.column);
    }
    events.add(Destroy(_advance().lexeme));
  }

  Participant _parseParticipant(ParticipantKind kind) {
    _advance();

    String? displayName;
    final String alias;

    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      _expectKeyword('as');
      alias = _expect(TokenType.identifier).lexeme;
    } else if (_check(TokenType.colon)) {
      // `<kind> :Display name: [as Alias]` — colon-wrapped display name.
      final decl = _consumeColonWrappedDisplayName();
      displayName = decl.displayName;
      alias = decl.alias ?? _deriveAliasFromDisplayName(decl.displayName);
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        displayName = first;
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected participant name, got ${t.type}', t.line, t.column);
    }

    int? order;
    Color? color;
    List<ParticipantLabelSection>? labelSections;
    String? stereotype;
    // Consume optional trailing modifiers in any order: #color, order N,
    // `<< Stereotype >>`, and multi-line `[ ... ]` rich label (kept as
    // display name when given).
    while (true) {
      if (_check(TokenType.stereotype)) {
        final lex = _advance().lexeme;
        stereotype ??= lex.isEmpty ? null : lex;
        continue;
      }
      if (_check(TokenType.hashColor)) {
        final t = _advance();
        // Strip leading '#' before parsing.
        final raw =
            t.lexeme.startsWith('#') ? t.lexeme.substring(1) : t.lexeme;
        color ??= text_colors.tryParseColor(raw);
        continue;
      }
      if (_isKeyword('order')) {
        _advance();
        if (_check(TokenType.text) || _check(TokenType.identifier)) {
          order = int.tryParse(_advance().lexeme);
        }
        continue;
      }
      if (_check(TokenType.leftBracket)) {
        _advance();
        final rawLines = <String>[];
        var current = StringBuffer();
        void flush() {
          rawLines.add(current.toString().trim());
          current = StringBuffer();
        }
        // Lexer-absorbed multi-line bracket body: a single text token whose
        // lexeme contains embedded newlines. Split on `\n` and feed each line
        // into the raw-lines list directly so the rich-label decoder below
        // sees the same per-line structure as the legacy token-walking path.
        if (_check(TokenType.text) &&
            _pos + 1 < _tokens.length &&
            _tokens[_pos + 1].type == TokenType.rightBracket &&
            _peek().lexeme.contains('\n')) {
          final body = _advance().lexeme;
          for (final line in body.split('\n')) {
            rawLines.add(line.trim());
          }
        } else {
          while (!_check(TokenType.rightBracket) &&
              !_check(TokenType.eof) &&
              !_check(TokenType.endUml)) {
            if (_check(TokenType.newline)) {
              _advance();
              flush();
              continue;
            }
            final t = _advance();
            if (current.isNotEmpty) current.write(' ');
            // Re-quote string literals so `""` markers in rich labels survive.
            if (t.type == TokenType.stringLiteral) {
              current.write('"${t.lexeme}"');
            } else {
              current.write(t.lexeme);
            }
          }
          if (current.isNotEmpty) flush();
        }
        if (_check(TokenType.rightBracket)) _advance();

        final sections = <ParticipantLabelSection>[];
        var currentLines = <ParticipantLabelLine>[];
        // `----` lexes into multiple `--` tokens joined by spaces; collapse
        // whitespace before matching so any run of >=3 dashes counts.
        final dashRe = RegExp(r'^-{3,}$');
        final codeRe = RegExp(r'^""\s*(.*?)\s*""$');
        var hasRichMarker = false;
        for (final raw in rawLines) {
          if (raw.isEmpty) continue;
          final collapsed = raw.replaceAll(' ', '');
          if (dashRe.hasMatch(collapsed)) {
            hasRichMarker = true;
            if (currentLines.isNotEmpty) {
              sections.add(ParticipantLabelSection(currentLines));
              currentLines = <ParticipantLabelLine>[];
            }
            continue;
          }
          if (raw.startsWith('=')) {
            hasRichMarker = true;
            currentLines.add(ParticipantLabelLine(
                raw.substring(1).trim(), ParticipantLabelStyle.title));
            continue;
          }
          final codeMatch = codeRe.firstMatch(raw);
          if (codeMatch != null) {
            hasRichMarker = true;
            currentLines.add(ParticipantLabelLine(
                codeMatch.group(1) ?? '', ParticipantLabelStyle.code));
            continue;
          }
          currentLines
              .add(ParticipantLabelLine(raw, ParticipantLabelStyle.normal));
        }
        if (currentLines.isNotEmpty) {
          sections.add(ParticipantLabelSection(currentLines));
        }
        if (hasRichMarker && sections.isNotEmpty) {
          labelSections = sections;
          displayName ??= sections
              .expand((s) => s.lines)
              .map((l) => l.text)
              .where((t) => t.isNotEmpty)
              .join('\n');
        } else {
          displayName ??= rawLines.where((l) => l.isNotEmpty).join('\n');
        }
        continue;
      }
      break;
    }
    _declaredAliases.add(alias);
    return Participant(
        alias: alias,
        displayName: displayName,
        kind: kind,
        order: order,
        labelSections: labelSections,
        color: color,
        stereotype: stereotype);
  }

  /// Parses an implicit actor declaration of the form `:Display name: [as
  /// Alias]` at sequence top-level. The current token must be the opening
  /// [TokenType.colon]. The lifted display name and (optional) explicit alias
  /// are wrapped into a [Participant] with [ParticipantKind.actor]; when no
  /// `as` clause is given the alias is derived from the display name by
  /// stripping internal whitespace and embedded `\n` markers.
  Participant _parseInlineActorDeclaration() {
    final decl = _consumeColonWrappedDisplayName();
    final alias = decl.alias ?? _deriveAliasFromDisplayName(decl.displayName);
    _declaredAliases.add(alias);
    return Participant(
      alias: alias,
      displayName: decl.displayName,
      kind: ParticipantKind.actor,
    );
  }

  /// Consumes a `:Display name:` block (optionally followed by `as Alias`).
  ///
  /// The opening colon must be the current token. The lexer emits the rest
  /// of the line as a single [TokenType.text] token immediately after the
  /// colon — that text holds the display-name characters, the closing `:`,
  /// and optionally a trailing ` as Alias`. The display name supports `\n`
  /// (literal backslash + `n`) which is converted to a real newline so it
  /// renders on multiple lines.
  _ColonWrappedName _consumeColonWrappedDisplayName() {
    final open = _expect(TokenType.colon);
    if (!_check(TokenType.text)) {
      throw ParserException(
          "Expected display name after ':', got ${_peek().type}",
          open.line,
          open.column);
    }
    final textTok = _advance();
    final raw = textTok.lexeme;
    final closingColon = raw.indexOf(':');
    if (closingColon < 0) {
      throw ParserException(
          "Expected closing ':' after display name", open.line, open.column);
    }
    final namePart = raw.substring(0, closingColon);
    var remainder = raw.substring(closingColon + 1).trim();
    final displayName = namePart.replaceAll(r'\n', '\n');

    // PlantUML "phantom"/hidden-node marker: a trailing `/` immediately after
    // the closing colon (e.g. `:Actor:/` or `:Actor:/ as Alias`). Consume the
    // marker as a no-op so the rest of the line still parses normally. Visual
    // hiding is currently deferred.
    if (remainder.startsWith('/')) {
      remainder = remainder.substring(1).trimLeft();
    }

    // Strip an optional trailing `<< Stereotype >>` so the leftover remainder
    // still matches the legacy `as Alias` pattern. The lexer keeps the rest
    // of the colon-actor line as a single text token, so we cannot rely on
    // the standalone [TokenType.stereotype] token here.
    String? stereotype;
    final stereoEnd = remainder.lastIndexOf('>>');
    if (stereoEnd >= 0 && stereoEnd == remainder.length - 2) {
      final stereoStart = remainder.lastIndexOf('<<', stereoEnd);
      if (stereoStart >= 0) {
        stereotype =
            remainder.substring(stereoStart + 2, stereoEnd).trim();
        if (stereotype.isEmpty) stereotype = null;
        remainder = remainder.substring(0, stereoStart).trim();
      }
    }

    String? alias;
    if (remainder.isNotEmpty) {
      final asMatch = RegExp(r'^as\s+(\S+)\s*$').firstMatch(remainder);
      if (asMatch == null) {
        throw ParserException(
            "Unexpected text after display name: '$remainder'",
            textTok.line,
            textTok.column + closingColon + 1);
      }
      alias = asMatch.group(1);
    }
    return _ColonWrappedName(displayName, alias, stereotype: stereotype);
  }

  /// Derives an alias from a display name by stripping all whitespace
  /// (including embedded newlines from `\n` markers). Keeps the casing.
  ///
  /// Examples:
  /// - `First Actor` -> `FirstActor`
  /// - `Another\nactor` -> `Anotheractor` (after newline conversion)
  ///
  /// If the result is empty (e.g. all-whitespace display name) we fall
  /// back to the raw display name so the participant still gets a
  /// non-empty alias.
  static String _deriveAliasFromDisplayName(String displayName) {
    final stripped = displayName.replaceAll(RegExp(r'\s+'), '');
    return stripped.isEmpty ? displayName : stripped;
  }

  Note _parseNote() {
    // Capture the keyword variant so we can attach the visible shape:
    //   `note`  -> rectangle (default)
    //   `rnote` -> rectangle (explicit)
    //   `hnote` -> hexagon
    final keywordTok = _advance();
    final NoteShape shape = (keywordTok.lexeme == 'hnote')
        ? NoteShape.hexagon
        : NoteShape.rectangle;

    final NotePosition position;
    var requireTarget = true;
    // PlantUML shorthand: `note across` / `hnote across` / `rnote across`
    // attach the note to every participant currently declared, equivalent to
    // `note over <first>, <last>`. Implemented as a synonym branch so the
    // surviving Note carries the full participant list and downstream layout
    // treats it identically to an over-multiple-participants note.
    var across = false;
    if (_isKeyword('left')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
      } else if (!_check(TokenType.identifier) &&
          !_check(TokenType.stringLiteral)) {
        // No `of` and no participant identifier → note attaches to the
        // previous message's relevant participant. Layout currently treats
        // this the same as a target-less note.
        requireTarget = false;
      }
      // `note left <Id>` (without `of`) is accepted as PlantUML shorthand;
      // the identifier is consumed below as the target participant.
      position = NotePosition.leftOf;
    } else if (_isKeyword('right')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
      } else if (!_check(TokenType.identifier) &&
          !_check(TokenType.stringLiteral)) {
        requireTarget = false;
      }
      position = NotePosition.rightOf;
    } else if (_isKeyword('over')) {
      _advance();
      position = NotePosition.over;
    } else if (_isKeyword('across')) {
      _advance();
      position = NotePosition.over;
      requireTarget = false;
      across = true;
    } else {
      final t = _peek();
      throw ParserException(
          "Expected 'left of', 'right of', 'over', or 'across', got '${t.lexeme}'",
          t.line,
          t.column);
    }

    final participants = <String>[];
    if (requireTarget) {
      participants.add(_expect(TokenType.identifier).lexeme);
      if (position == NotePosition.over) {
        while (_check(TokenType.comma)) {
          _advance();
          participants.add(_expect(TokenType.identifier).lexeme);
        }
      }
    } else if (across) {
      // Snapshot the participant set at the point the `across` note is
      // encountered. Forward references would yield an empty list, which the
      // layout already handles as "spans all" via the over-multiple path.
      participants.addAll(_declaredAliases);
    }
    Color? color;
    if (_check(TokenType.hashColor)) {
      final t = _advance();
      final raw = t.lexeme.startsWith('#') ? t.lexeme.substring(1) : t.lexeme;
      color = text_colors.tryParseColor(raw);
    }

    final String text;
    if (_check(TokenType.colon)) {
      _advance();
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected note text, got ${t.type}', t.line, t.column);
      }
      text = _expandText(_advance().lexeme);
    } else if (_check(TokenType.newline)) {
      text = _expandText(_consumeMultilineNoteBody());
    } else {
      // Trailing content on the same line as the header (PlantUML allows
      // e.g. `rnote over server "r" as rectangle` where the trailing
      // tokens are the first body line). Collect lexemes until the
      // newline, then continue consuming the multi-line body.
      final firstLine = _collectHeaderTrailingAsBodyLine();
      if (_check(TokenType.newline)) {
        final rest = _consumeMultilineNoteBody();
        text = _expandText(rest.isEmpty ? firstLine : '$firstLine\n$rest');
      } else {
        final t = _peek();
        throw ParserException(
            "Expected ':' or newline after note header, got ${t.type}",
            t.line,
            t.column);
      }
    }

    return Note(
      position: position,
      participants: List.unmodifiable(participants),
      text: text,
      color: color,
      shape: shape,
    );
  }

  /// Collects tokens on the remainder of the current line into a single
  /// body line string. Used when a `note`/`rnote`/`hnote` header has
  /// arbitrary trailing content (not introduced by `:`) on the same line
  /// as the header, which PlantUML treats as the first body line.
  ///
  /// String literals had their surrounding quotes stripped by the lexer;
  /// we re-add them here so the original quoted-token shape is preserved
  /// in the body text.
  String _collectHeaderTrailingAsBodyLine() {
    final buf = StringBuffer();
    var first = true;
    while (!_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      final t = _advance();
      if (!first) buf.write(' ');
      first = false;
      if (t.type == TokenType.stringLiteral) {
        buf.write('"');
        buf.write(t.lexeme);
        buf.write('"');
      } else {
        buf.write(t.lexeme);
      }
    }
    return buf.toString();
  }

  String _consumeMultilineNoteBody() {
    _advance();
    final lines = <String>[];
    while (true) {
      if (_check(TokenType.eof) || _check(TokenType.endUml)) {
        final t = _peek();
        throw ParserException(
            "Expected 'end note' to close multi-line note", t.line, t.column);
      }
      final atLineStart =
          _pos == 0 || _tokens[_pos - 1].type == TokenType.newline;
      if (atLineStart &&
          _isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'note') {
        _advance();
        _advance();
        return lines.join('\n');
      }
      // Lexer emits `endnote`, `endrnote`, `endhnote` as single identifier
      // tokens. Accept any of them as terminators for the multi-line body
      // of `note` / `rnote` / `hnote` (PlantUML is lenient about cross
      // pairing).
      if (atLineStart &&
          (_isKeyword('endnote') ||
              _isKeyword('endrnote') ||
              _isKeyword('endhnote'))) {
        _advance();
        return lines.join('\n');
      }
      if (_check(TokenType.text)) {
        lines.add(_advance().lexeme);
      }
      if (_check(TokenType.newline)) _advance();
    }
  }

  RefBox _parseRef() {
    _advance();
    if (!_isKeyword('over')) {
      final t = _peek();
      throw ParserException(
          "Expected 'over' after 'ref', got '${t.lexeme}'", t.line, t.column);
    }
    _advance();

    final participants = <String>[_expect(TokenType.identifier).lexeme];
    while (_check(TokenType.comma)) {
      _advance();
      participants.add(_expect(TokenType.identifier).lexeme);
    }

    final String text;
    if (_check(TokenType.colon)) {
      _advance();
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected ref text, got ${t.type}', t.line, t.column);
      }
      text = _advance().lexeme;
    } else if (_check(TokenType.newline)) {
      text = _consumeMultilineRefBody();
    } else {
      final t = _peek();
      throw ParserException(
          "Expected ':' or newline after ref header, got ${t.type}",
          t.line,
          t.column);
    }

    return RefBox(
      participants: List.unmodifiable(participants),
      text: text,
    );
  }

  String _consumeMultilineRefBody() {
    _advance();
    final lines = <String>[];
    while (true) {
      if (_check(TokenType.eof) || _check(TokenType.endUml)) {
        final t = _peek();
        throw ParserException(
            "Expected 'end ref' to close multi-line ref", t.line, t.column);
      }
      final atLineStart =
          _pos == 0 || _tokens[_pos - 1].type == TokenType.newline;
      if (atLineStart &&
          _isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'ref') {
        _advance();
        _advance();
        return lines.join('\n');
      }
      if (atLineStart && _isKeyword('endref')) {
        _advance();
        return lines.join('\n');
      }
      if (_check(TokenType.text)) {
        lines.add(_advance().lexeme);
      }
      if (_check(TokenType.newline)) _advance();
    }
  }

  Group _parseGroup(GroupKind kind) {
    _advance();
    // PlantUML allows `alt#TabColor #BodyColor label` where the first colour
    // (attached to the keyword without whitespace) tints the small kind tab
    // and the second colour (with whitespace) fills the first branch body.
    // The lexer already emits these as separate `hashColor` tokens regardless
    // of attachment, so peek for up to two consecutive hashColor tokens.
    Color? tabColor;
    if (_check(TokenType.hashColor)) {
      final tok = _advance();
      tabColor = _parseColor(tok.lexeme, tok);
    }
    Color? firstBodyColor;
    if (_check(TokenType.hashColor)) {
      final tok = _advance();
      firstBodyColor = _parseColor(tok.lexeme, tok);
    }
    final firstLabel = _collectLineRemainder();
    _skipNewlines();

    final branches = <GroupBranch>[];
    final firstEvents = <SequenceEvent>[];
    while (!_isKeyword('else') &&
        !_isKeyword('end') &&
        !_check(TokenType.endUml) &&
        !_check(TokenType.eof)) {
      _parseEvent(firstEvents);
      _skipNewlines();
    }
    branches.add(GroupBranch(
      label: firstLabel,
      events: List.unmodifiable(firstEvents),
      bodyColor: firstBodyColor,
    ));

    while (_isKeyword('else')) {
      _advance();
      Color? bodyColor;
      if (_check(TokenType.hashColor)) {
        final tok = _advance();
        bodyColor = _parseColor(tok.lexeme, tok);
      }
      final label = _collectLineRemainder();
      _skipNewlines();
      final inner = <SequenceEvent>[];
      while (!_isKeyword('else') &&
          !_isKeyword('end') &&
          !_check(TokenType.endUml) &&
          !_check(TokenType.eof)) {
        _parseEvent(inner);
        _skipNewlines();
      }
      branches.add(GroupBranch(
        label: label,
        events: List.unmodifiable(inner),
        bodyColor: bodyColor,
      ));
    }

    _expectKeyword('end');
    return Group(
      kind: kind,
      branches: List.unmodifiable(branches),
      tabColor: tabColor,
    );
  }

  String? _collectLineRemainder() {
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) return _advance().lexeme;
      return null;
    }
    final parts = <String>[];
    while (!_check(TokenType.newline) && !_check(TokenType.eof)) {
      parts.add(_advance().lexeme);
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  void _parseMessage(List<SequenceEvent> out) {
    // PlantUML allows "found" messages where the source is anonymous and the
    // arrow itself begins the line (`[-> Target` or `?-> Target`). In that
    // case the lexer absorbs the `[` / `?` sigil into the arrow token, so we
    // don't see a preceding identifier.
    //
    // PlantUML `& Source -> Target` (parallel/sync marker, used together with
    // `!pragma teoz true`) means this message shares its START Y coordinate
    // with the previous message. Consume the leading `&` token if present.
    var synchronized = false;
    if (_check(TokenType.amp)) {
      _advance();
      synchronized = true;
    }
    String? from;
    if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
      from = _advance().lexeme;
    } else if (!_check(TokenType.arrow)) {
      final t = _peek();
      throw ParserException(
          'Expected participant, got ${t.type}', t.line, t.column);
    }

    if (!_check(TokenType.arrow)) {
      final t = _peek();
      throw ParserException(
          'Expected arrow after participant, got ${t.type}', t.line, t.column);
    }
    final arrowToken = _advance();
    final decoded = _decodeArrow(arrowToken);

    // If the arrow encoded a found-marker (`[->` / `?->`) the source must be
    // external and there must not have been a preceding identifier.
    if (decoded.leftExternal != null && from != null) {
      throw ParserException(
          "Unexpected source identifier '$from' before found-message arrow",
          arrowToken.line, arrowToken.column);
    }
    if (decoded.leftExternal == null && from == null) {
      throw ParserException(
          'Expected participant before arrow', arrowToken.line, arrowToken.column);
    }

    String? to;
    if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
      if (decoded.rightExternal != null) {
        final t = _peek();
        throw ParserException(
            "Unexpected target identifier '${t.lexeme}' after lost-message arrow",
            t.line, t.column);
      }
      to = _advance().lexeme;
    } else if (decoded.rightExternal == null) {
      final t = _peek();
      throw ParserException(
          'Expected participant, got ${t.type}', t.line, t.column);
    }
    // Synthesize placeholder aliases for external endpoints. They must never
    // be touched by participantsInOrder (the AST's `Message.fromExternal` /
    // `toExternal` fields gate that) but layout still keys per-event maps by
    // the alias string, so we need a deterministic placeholder.
    String resolveExternalAlias(MessageExternal kind, int seq) =>
        '__external_${kind.name}_$seq';
    if (decoded.leftExternal != null) {
      from = resolveExternalAlias(
          decoded.leftExternal!, _externalEndpointCounter++);
    }
    if (decoded.rightExternal != null) {
      to = resolveExternalAlias(
          decoded.rightExternal!, _externalEndpointCounter++);
    }
    // `"display" as Alias` rebinds the target's alias; remember the display
    // name so the auto-declared participant still shows it. Anonymous
    // endpoints (`->]` / `->?`) never carry an `as` rebinding.
    String? toDisplay;
    if (decoded.rightExternal == null && _isKeyword('as')) {
      _advance();
      if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
        toDisplay = to;
        to = _advance().lexeme;
        if (!_pendingMessageAliases.containsKey(to)) {
          _pendingMessageAliases[to] = toDisplay!;
        }
      }
    }
    // Track participants implicitly declared by this message so `note across`
    // / `hnote across` can later span the full participant set. Synthetic
    // external placeholders (`__external_*`) are excluded — they never appear
    // as participants in the rendered diagram.
    if (decoded.leftExternal == null && from != null) {
      _declaredAliases.add(from);
    }
    if (decoded.rightExternal == null && to != null) {
      _declaredAliases.add(to);
    }
    // Optional per-message color spec `#RRGGBB` between target and `:`. The
    // color may appear either before or after the activation suffix (PlantUML
    // tolerates `A -> B ++ #color` and `A -> B #color ++`).
    Color? messageColor;
    if (_check(TokenType.hashColor)) {
      final t = _advance();
      final raw = t.lexeme.startsWith('#') ? t.lexeme.substring(1) : t.lexeme;
      messageColor = text_colors.tryParseColor(raw);
    }

    // PlantUML allows up to two chained activation suffixes after a forward
    // message: a source-deactivate (`--`) combined with a target-side effect
    // (`++`, `**`, or `!!`), in either order (`--++` or `++--`). We collect
    // them into `deactivateSource` + `targetEffect`. The legacy single-slot
    // `Message.activation` field below is set from whichever suffix is
    // present so existing consumers keep working.
    bool deactivateSource = false;
    ActivationSuffix? targetEffect;

    ActivationSuffix? consumeSuffix() {
      if (_check(TokenType.plusPlus)) {
        _advance();
        return ActivationSuffix.activateTarget;
      }
      if (_check(TokenType.minusMinus)) {
        _advance();
        return ActivationSuffix.deactivateSource;
      }
      if (_check(TokenType.starStar)) {
        _advance();
        return ActivationSuffix.createTarget;
      }
      if (_check(TokenType.bangBang)) {
        _advance();
        return ActivationSuffix.destroyTarget;
      }
      return null;
    }

    void applySuffix(ActivationSuffix s, Token token) {
      switch (s) {
        case ActivationSuffix.deactivateSource:
          if (deactivateSource) {
            throw ParserException(
                "Duplicate '--' activation suffix",
                token.line, token.column);
          }
          deactivateSource = true;
        case ActivationSuffix.activateTarget:
        case ActivationSuffix.createTarget:
        case ActivationSuffix.destroyTarget:
          if (targetEffect != null) {
            throw ParserException(
                "Conflicting activation suffix '${token.lexeme}'",
                token.line, token.column);
          }
          targetEffect = s;
      }
    }

    // First suffix.
    Token? firstSuffixToken;
    if (_check(TokenType.plusPlus) ||
        _check(TokenType.minusMinus) ||
        _check(TokenType.starStar) ||
        _check(TokenType.bangBang)) {
      firstSuffixToken = _peek();
    }
    final firstSuffix = consumeSuffix();
    if (firstSuffix != null) {
      applySuffix(firstSuffix, firstSuffixToken!);
    }
    // Optional chained second suffix (e.g. `--++` or `++--`). Whitespace
    // between them is tolerated by the lexer because `--` and `++` are
    // emitted as separate tokens; PlantUML accepts both contiguous and
    // space-separated forms.
    Token? secondSuffixToken;
    if (_check(TokenType.plusPlus) ||
        _check(TokenType.minusMinus) ||
        _check(TokenType.starStar) ||
        _check(TokenType.bangBang)) {
      secondSuffixToken = _peek();
    }
    final secondSuffix = consumeSuffix();
    if (secondSuffix != null) {
      applySuffix(secondSuffix, secondSuffixToken!);
    }

    // Legacy single-slot encoding kept on the Message for backward
    // compatibility. Prefer the target-side effect; otherwise fall back to
    // the source-deactivate marker.
    final activation = targetEffect ??
        (deactivateSource ? ActivationSuffix.deactivateSource : null);

    // Accept `#color` AFTER the activation suffix too (e.g. `A -> B ++ #red`).
    if (messageColor == null && _check(TokenType.hashColor)) {
      final t = _advance();
      final raw = t.lexeme.startsWith('#') ? t.lexeme.substring(1) : t.lexeme;
      messageColor = text_colors.tryParseColor(raw);
    }

    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        label = _advance().lexeme;
      }
    }

    if (_check(TokenType.plusPlus) ||
        _check(TokenType.minusMinus) ||
        _check(TokenType.starStar) ||
        _check(TokenType.bangBang)) {
      final t = _peek();
      throw ParserException(
          "Activation suffix '${t.lexeme}' must appear immediately after the target identifier",
          t.line,
          t.column);
    }

    String? finalLabel = label;
    if (!_autonumber.stopped) {
      final levels = _autonumber.levels;
      final formatted = levels != null
          ? levels.join('.')
          : _formatAutonumber(_autonumber.current, _autonumber.format);
      _autonumber.lastDisplayed = levels != null
          ? levels.join('.')
          : _autonumber.current.toString();
      final expanded = label == null ? null : _expandText(label);
      if (expanded == null || expanded.isEmpty) {
        finalLabel = formatted;
      } else {
        finalLabel = '${_closeOpenTags(formatted)} $expanded';
      }
      if (levels != null) {
        levels[levels.length - 1] += _autonumber.increment;
      } else {
        _autonumber.current += _autonumber.increment;
      }
    } else if (label != null) {
      finalLabel = _expandText(label);
    }

    final message = Message(
      from: from!,
      to: to!,
      label: finalLabel,
      lineStyle: decoded.lineStyle,
      head: decoded.head,
      direction: decoded.direction,
      hidden: decoded.hidden,
      color: messageColor ?? decoded.color,
      activation: activation,
      fromExternal: decoded.leftExternal,
      toExternal: decoded.rightExternal,
      tailDecoration: decoded.tailDecoration,
      duration: decoded.duration,
      synchronized: synchronized,
    );
    out.add(message);
    if (message.direction == MessageDirection.forward) {
      _lastForwardMessage = message;
    }
    // Emit secondary events. Order matters: a chained `--++` first
    // deactivates the source (closing the caller's frame) and then activates
    // the target (opening a new frame). Layout consumes these as independent
    // per-participant stack operations, so emitting them sequentially is
    // sufficient — there is no AST-level "two suffixes on one message" type.
    if (deactivateSource) {
      out.add(Deactivate(from));
      // Pop the matching call-stack frame so a later `return` (or chained
      // `--`) still unwinds to the correct earlier caller. We pop the
      // topmost frame whose callee is `from`; if there is no match (e.g. a
      // stray `--`), the stack is left untouched.
      for (var k = _callStack.length - 1; k >= 0; k--) {
        if (_callStack[k].$2 == from) {
          _callStack.removeAt(k);
          break;
        }
      }
    }
    switch (targetEffect) {
      case ActivationSuffix.activateTarget:
        // Carry the per-message color into the activation bar so explicit
        // `A -> B ++ #color` (and the reversed `++ ... #color` ordering)
        // both colour the bar consistently with `autoactivate on`.
        out.add(Activate(to, color: message.color));
      case ActivationSuffix.createTarget:
        out.add(Create(to));
      case ActivationSuffix.destroyTarget:
        out.add(Destroy(to));
      case ActivationSuffix.deactivateSource:
      case null:
        break;
    }
    // Maintain a call stack of (caller, callee, color) frames so a later
    // `return` can unwind to the correct earlier caller. Two cases push:
    //
    //  1. `autoactivate on` is active — every forward, non-self, non-destroy,
    //     non-deactivate call pushes (and gets an implicit Activate(to) if
    //     not already activated by an explicit `++`).
    //  2. The call has an explicit `++` or `**` target-side suffix — the
    //     user opted into activation/creation, so a `return` should be able
    //     to unwind it regardless of the autoactivate setting. Self-calls
    //     only push when the explicit suffix is present (matching the
    //     existing `autoactivate skips push for self calls` test).
    //
    // `!!` (destroyTarget) never pushes, and a backward / hidden message
    // never pushes. A standalone `--` (deactivate-only) doesn't push either;
    // a chained `--++` / `--**` DOES push because the target side opens a
    // new frame.
    final isForward = message.direction == MessageDirection.forward;
    final pushable = !message.hidden &&
        targetEffect != ActivationSuffix.destroyTarget;
    final explicitOpenSuffix = targetEffect == ActivationSuffix.activateTarget ||
        targetEffect == ActivationSuffix.createTarget;
    final autoactivateAppliesHere = _autoactivate && from != to;
    if (isForward && pushable && (autoactivateAppliesHere || explicitOpenSuffix)) {
      final implicitColor = message.color;
      // Under `autoactivate on`, emit an implicit Activate(to) unless the
      // explicit `++` already did so. Explicit-only pushes do NOT add an
      // implicit Activate — `++` already emitted one and `**` deliberately
      // creates without activating.
      if (autoactivateAppliesHere &&
          targetEffect != ActivationSuffix.activateTarget &&
          targetEffect != ActivationSuffix.createTarget) {
        out.add(Activate(to, color: implicitColor));
      }
      _callStack.add((from, to, implicitColor));
    }
  }

  _DecodedArrow _decodeArrow(Token token) {
    final lexeme = token.lexeme;
    // Extract external-endpoint markers FIRST so they don't confuse the
    // bracket-modifier extraction below. `[` is overloaded: at the very
    // start it's a found-message marker, but inside the arrow body it's the
    // opening delimiter of a `[#color]` / `[hidden]` modifier. We detect the
    // found-marker by checking whether the next char is a body/head glyph.
    var working = lexeme;
    // PlantUML "transmission duration" annotation `(<digits>)` embedded in
    // the arrow. Two acceptable positions:
    //   `->(N)`  / `-->(N)`     trailing on a forward arrow
    //   `(N)<-`  / `(N)<--`     leading on a backward arrow
    // Extract the integer N (if any) and STRIP the `(...)` from the working
    // lexeme so the existing head/body decode logic runs unchanged.
    int? duration;
    final durationMatch =
        RegExp(r'\((\d+)\)').firstMatch(working);
    if (durationMatch != null) {
      duration = int.parse(durationMatch.group(1)!);
      working = working.substring(0, durationMatch.start) +
          working.substring(durationMatch.end);
    }
    MessageExternal? leftExternal;
    MessageExternal? rightExternal;
    if (working.isNotEmpty && working[0] == '?') {
      leftExternal = MessageExternal.fromShort;
      working = working.substring(1);
    } else if (working.length >= 2 &&
        working[0] == '[' &&
        _isArrowHeadOrBodyChar(working[1])) {
      leftExternal = MessageExternal.fromEdge;
      working = working.substring(1);
    }
    if (working.isNotEmpty) {
      final lastCh = working[working.length - 1];
      if (lastCh == '?') {
        rightExternal = MessageExternal.toShort;
        working = working.substring(0, working.length - 1);
      } else if (lastCh == ']' &&
          // Only when not the closing of a bracket modifier. A modifier
          // takes the form `...[X]...` where `]` is followed by `-`/`.`
          // body characters. By the time we're inspecting the LAST char of
          // the arrow lexeme, any modifier-bracket must already have body
          // chars after it; so a trailing `]` is unambiguously a
          // lost-message marker.
          !working.contains('[')) {
        rightExternal = MessageExternal.toEdge;
        working = working.substring(0, working.length - 1);
      } else if (lastCh == ']' && working.contains('[')) {
        // Distinguish lost-marker from modifier-close: the modifier-close
        // is followed by body chars, so by the time it's the LAST char of
        // the lexeme it can only be a lost-marker. We still guard with an
        // additional check: the matching `[` must be the FIRST char (the
        // found-marker case is already handled above) OR there must be no
        // arrow head (`>` / `<`) after the `[`...`]` span. Practically the
        // outer scanner only ever lets a trailing `]` survive when it's a
        // lost-marker, so we treat it as such.
        rightExternal = MessageExternal.toEdge;
        working = working.substring(0, working.length - 1);
      }
    }

    final openBracket = working.indexOf('[');
    var stripped = working;
    var hidden = false;
    Color? color;
    if (openBracket >= 0) {
      final closeBracket = working.indexOf(']', openBracket + 1);
      if (closeBracket >= 0) {
        final modifier = working.substring(openBracket + 1, closeBracket);
        var afterClose = closeBracket + 1;
        while (afterClose < working.length && working[afterClose] == '-') {
          afterClose++;
        }
        stripped = working.substring(0, openBracket) +
            working.substring(afterClose);
        if (modifier == 'hidden') {
          hidden = true;
        } else {
          color = _parseColor(modifier, token);
        }
      }
    }
    final base = _decodeBareArrow(stripped, token);
    // Pragmatic normalization: a bidirectional arrow that ends at an anonymous
    // ("found" / "lost") endpoint can't actually be bidirectional — there is
    // no participant on the anonymous side to receive a return triangle. We
    // collapse it to a directed arrow that flows from the external endpoint
    // toward the real participant on the OTHER side: `A <-> ?` becomes
    // forward (away from A, toward the stub), and `? <-> B` also becomes
    // forward (from the stub on the left, toward B on the right). This
    // matches the PlantUML convention where found messages point at the
    // real participant and lost messages point away from it.
    var direction = base.direction;
    if (direction == MessageDirection.bidirectional) {
      if (rightExternal != null && leftExternal == null) {
        direction = MessageDirection.forward;
      } else if (leftExternal != null && rightExternal == null) {
        // Left-external found message: collapse bidirectional to forward so
        // the arrow flows from the anonymous source (left) to the real
        // target (right). The head/tail decorations from `_decodeBareArrow`
        // are preserved.
        direction = MessageDirection.forward;
      }
    }
    return _DecodedArrow(
      base.lineStyle,
      base.head,
      direction,
      hidden: hidden,
      color: color,
      leftExternal: leftExternal,
      rightExternal: rightExternal,
      tailDecoration: base.tailDecoration,
      duration: duration,
    );
  }

  static bool _isArrowHeadOrBodyChar(String c) {
    // `o` / `x` are legitimate first chars after a found-marker `[` when used
    // as a tail decoration on the left side (e.g. `[o->`, `[x<->x`). They are
    // NOT the start of a bracket-modifier (those are `[#color]` / `[hidden]`
    // which always start with `#` or a known modifier word).
    return c == '-' ||
        c == '.' ||
        c == '<' ||
        c == '\\' ||
        c == '/' ||
        c == 'o' ||
        c == 'x';
  }

  _DecodedArrow _decodeBareArrow(String lexeme, Token token) {
    bool isBody(String ch) =>
        ch == '-' || ch == '.' || ch == '\\' || ch == '/';

    var left = 0;
    var right = lexeme.length;
    final leftGlyphs = <String>[];
    while (left < right && !isBody(lexeme[left])) {
      leftGlyphs.add(lexeme[left]);
      left++;
    }
    final rightGlyphs = <String>[];
    while (right > left && !isBody(lexeme[right - 1])) {
      rightGlyphs.insert(0, lexeme[right - 1]);
      right--;
    }
    final body = lexeme.substring(left, right);
    if (body.isEmpty && leftGlyphs.isEmpty && rightGlyphs.isEmpty) {
      throw ParserException(
          "Unknown arrow form '${token.lexeme}'", token.line, token.column);
    }
    final dashed = body.contains('..') || body.contains('--');

    // Peel a TAIL decoration (`o` / `x`) from the leading glyphs when it sits
    // BEFORE a head glyph. `o->` / `x->` are forward arrows with a tail
    // decoration; `o<->o` / `x<->x` are bidirectional. The peeled decoration
    // travels in the Message's `tailDecoration` field, not as a head.
    EndpointDecoration? tailDecoration;
    if (leftGlyphs.length >= 2 &&
        (leftGlyphs.first == 'o' || leftGlyphs.first == 'x') &&
        (leftGlyphs[1] == '<')) {
      tailDecoration = leftGlyphs.first == 'o'
          ? EndpointDecoration.openCircle
          : EndpointDecoration.cross;
      leftGlyphs.removeAt(0);
    } else if (leftGlyphs.length == 1 &&
        (leftGlyphs.first == 'o' || leftGlyphs.first == 'x') &&
        rightGlyphs.isNotEmpty &&
        rightGlyphs.first == '>') {
      // `o->` / `x->` / `o->o` / `x->o`: leading char is the tail decoration
      // of a FORWARD arrow (no `<` head on the left). The actual head sits in
      // the right-glyph cluster.
      tailDecoration = leftGlyphs.first == 'o'
          ? EndpointDecoration.openCircle
          : EndpointDecoration.cross;
      leftGlyphs.removeAt(0);
    }

    ArrowHead? leftHead;
    var leftIsHead = false;
    if (leftGlyphs.isNotEmpty) {
      final g = leftGlyphs.first;
      if (g == '<') {
        leftIsHead = true;
        // `<<-` → open (thin/async); `<-` → filled.
        leftHead = leftGlyphs.length >= 2 && leftGlyphs[1] == '<'
            ? ArrowHead.open
            : ArrowHead.filled;
      } else if (g == 'o') {
        leftIsHead = true;
        leftHead = ArrowHead.openCircle;
      } else if (g == 'x') {
        leftIsHead = true;
        leftHead = ArrowHead.cross;
      }
    }

    ArrowHead? rightHead;
    var rightIsHead = false;
    if (rightGlyphs.isNotEmpty) {
      final g = rightGlyphs.last;
      if (g == '>') {
        rightIsHead = true;
        rightHead = ArrowHead.filled;
      } else if (g == 'o' || g == 'x' || g == '*') {
        rightIsHead = true;
        if (g == 'o') {
          rightHead = ArrowHead.openCircle;
        } else if (g == 'x') {
          rightHead = ArrowHead.cross;
        } else {
          rightHead = ArrowHead.filled;
        }
      }
      // `>>` after `>` → thin/open head; trailing `o`/`x` after `>` or `>>`
      // is the visible cap shape (PlantUML stacks the cap over the V-tip;
      // we approximate by using the cap as the head, since the body has no
      // V drawn separately).
      if (rightGlyphs.length >= 2 && rightGlyphs[0] == '>') {
        // Trailing `o` / `x` wins as the visible head shape (matches `->o`
        // semantics). Otherwise `>>` is a thin/open head.
        final last = rightGlyphs.last;
        if (last == 'o') {
          rightHead = ArrowHead.openCircle;
        } else if (last == 'x') {
          rightHead = ArrowHead.cross;
        } else if (rightGlyphs[1] == '>') {
          rightHead = ArrowHead.open;
        }
      }
    }

    // Half-arrow markers (`\`, `/`) at body edges act as a (forward/backward)
    // open arrowhead when no explicit head glyph is present.
    final bodyStartsHalf = body.isNotEmpty &&
        (body[0] == '\\' || body[0] == '/');
    final bodyEndsHalf = body.isNotEmpty &&
        (body[body.length - 1] == '\\' || body[body.length - 1] == '/');
    if (!rightIsHead && bodyEndsHalf) {
      rightIsHead = true;
      rightHead = ArrowHead.open;
    }
    if (!leftIsHead && bodyStartsHalf && !rightIsHead) {
      // Only treat left half-marker as backward head when no right head exists,
      // otherwise it stays decorative on a forward arrow.
      leftIsHead = true;
      leftHead = ArrowHead.open;
    }

    final lineStyle = dashed ? LineStyle.dashed : LineStyle.solid;
    if (leftIsHead && rightIsHead) {
      // Prefer the right head as the carried head; renderer will mirror it.
      return _DecodedArrow(
          lineStyle, rightHead!, MessageDirection.bidirectional,
          tailDecoration: tailDecoration);
    }
    if (leftIsHead) {
      return _DecodedArrow(
          lineStyle, leftHead!, MessageDirection.backward,
          tailDecoration: tailDecoration);
    }
    if (rightIsHead) {
      return _DecodedArrow(
          lineStyle, rightHead!, MessageDirection.forward,
          tailDecoration: tailDecoration);
    }
    // No head glyphs at all — fallback forward filled.
    return _DecodedArrow(
        lineStyle, ArrowHead.filled, MessageDirection.forward,
        tailDecoration: tailDecoration);
  }

  Color _parseColor(String spec, Token token) {
    // The lexer may absorb a PlantUML inline-style suffix into the hashColor
    // lexeme (e.g. `#red;line.bold;text:red`). Only the leading color is used
    // for fill/border resolution today — trailing style clauses are tolerated
    // but ignored. Visual styling for `line:`, `line.bold`, `text:` is
    // deferred.
    final semi = spec.indexOf(';');
    final head = semi < 0 ? spec : spec.substring(0, semi);
    final color = text_colors.tryParseColor(head);
    if (color == null) {
      throw ParserException("Unknown color '$head'", token.line, token.column);
    }
    return color;
  }

  Token _peek() => _tokens[_pos];

  Token _advance() => _tokens[_pos++];

  bool _check(TokenType type) => _tokens[_pos].type == type;

  bool _isKeyword(String word) =>
      _check(TokenType.identifier) && _peek().lexeme == word;

  Token _expect(TokenType type) {
    if (!_check(type)) {
      final t = _peek();
      throw ParserException('Expected $type, got ${t.type}', t.line, t.column);
    }
    return _advance();
  }

  void _expectKeyword(String word) {
    if (!_isKeyword(word)) {
      final t = _peek();
      throw ParserException(
          "Expected '$word', got '${t.lexeme}'", t.line, t.column);
    }
    _advance();
  }

  void _skipNewlines() {
    while (_check(TokenType.newline)) {
      _advance();
    }
  }

  bool _hasSequenceParticipantMarker() {
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart &&
          t.type == TokenType.identifier &&
          _participantKinds.containsKey(t.lexeme)) {
        return true;
      }
      atLineStart = false;
    }
    return false;
  }

  bool _looksLikeActivityDiagram() {
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length - 1; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      final next = _tokens[k + 1];
      if (atLineStart && t.type == TokenType.colon) {
        if (next.type == TokenType.text && next.lexeme.endsWith(';')) {
          return true;
        }
      }
      // Bullet shortcut: `- text` at the start of a line is an action node
      // (equivalent to `:text;`). The lexer emits `minusMinus` with lexeme
      // `-` for a single dash followed by whitespace.
      if (atLineStart &&
          t.type == TokenType.minusMinus &&
          t.lexeme == '-' &&
          next.type != TokenType.newline &&
          next.type != TokenType.endUml &&
          next.type != TokenType.eof) {
        return true;
      }
      if (atLineStart && t.type == TokenType.identifier) {
        final nextIsNewlineOrEnd = next.type == TokenType.newline ||
            next.type == TokenType.endUml ||
            next.type == TokenType.eof;
        if ((t.lexeme == 'start' || t.lexeme == 'stop') && nextIsNewlineOrEnd) {
          return true;
        }
        if (t.lexeme == 'if' || t.lexeme == 'while') {
          if (next.type == TokenType.leftParen) return true;
        }
        if (t.lexeme == 'repeat' &&
            (nextIsNewlineOrEnd ||
                (next.type == TokenType.identifier &&
                    next.lexeme == 'while'))) {
          return true;
        }
        if (t.lexeme == 'repeatwhile') {
          return true;
        }
        if (t.lexeme == 'fork' && nextIsNewlineOrEnd) {
          return true;
        }
        if (t.lexeme == 'partition') {
          return true;
        }
      }
      atLineStart = false;
    }
    return false;
  }

  ActivityDiagram _parseActivityDiagram() {
    final nodes = <ActivityNode>[];
    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_check(TokenType.stereotype)) {
        _attachPendingStereotype(nodes);
        _skipNewlines();
        continue;
      }
      final node = _parseActivityNode();
      if (node != null) nodes.add(node);
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    return ActivityDiagram(
      nodes: List.unmodifiable(nodes),
      decorations: _decorations.build(),
    );
  }

  /// Consume a stand-alone `<<stereotype>>` token and attach the stereotype
  /// name to the most recently parsed [Action] in [nodes], when there is one.
  /// PlantUML lets SDL/UML stereotypes appear on the line after `:action;`
  /// to select an alternative node shape (`<<input>>`, `<<sendSignal>>`,
  /// ...). When no preceding action is available the token is silently
  /// consumed for parser robustness.
  void _attachPendingStereotype(List<ActivityNode> nodes) {
    final stereo = _advance().lexeme;
    if (nodes.isEmpty) return;
    final last = nodes.last;
    if (last is Action && last.stereotype == null) {
      nodes[nodes.length - 1] =
          Action(text: last.text, note: last.note, stereotype: stereo);
    }
  }

  ActivityNode? _parseActivityNode() {
    if (_check(TokenType.colon)) {
      return _parseAction();
    }
    if (_check(TokenType.minusMinus) && _peek().lexeme == '-') {
      return _parseBulletAction();
    }
    // PlantUML activity diagrams allow a stand-alone arrow label between two
    // nodes: `-> some text;`. The label has no source identifier — it
    // annotates the implicit transition from the previously parsed node to
    // the next one. We currently consume the line for parser robustness; the
    // label text is not yet rendered.
    if (_check(TokenType.arrow)) {
      _skipUntilNewline();
      return null;
    }
    if (_isKeyword('start')) {
      _advance();
      return const StartNode();
    }
    if (_isKeyword('stop')) {
      _advance();
      return const StopNode();
    }
    if (_isKeyword('end')) {
      _advance();
      return const EndNode();
    }
    if (_isKeyword('if')) {
      return _parseIfBlock();
    }
    if (_isKeyword('while')) {
      return _parseWhileBlock();
    }
    if (_isKeyword('repeat')) {
      return _parseRepeatBlock();
    }
    if (_isKeyword('fork')) {
      return _parseForkBlock();
    }
    if (_isKeyword('split')) {
      return _parseSplitBlock();
    }
    if (_isKeyword('partition')) {
      return _parsePartition();
    }
    if (_isKeyword('detach')) {
      _advance();
      return const Detach();
    }
    if (_isKeyword('break')) {
      _advance();
      return const Break();
    }
    if (_isKeyword('kill')) {
      _advance();
      return const Kill();
    }
    if (_isKeyword('note')) {
      // Skip standalone activity notes for now (parser robustness).
      _skipUntilNewline();
      return null;
    }
    final t = _peek();
    throw ParserException(
        "Unexpected token '${t.lexeme}' in activity diagram", t.line, t.column);
  }

  Action _parseAction() {
    _advance();
    String text = '';
    if (_check(TokenType.text)) {
      text = _advance().lexeme;
    }
    if (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    return Action(text: text);
  }

  /// Parses a bullet shortcut action: `- text` at the start of a line.
  /// Equivalent to `:text;` in standard activity syntax. The leading `-` was
  /// lexed as a single-character `minusMinus` token. A leading
  /// `<<stereotype>>` token (e.g. `-<<icon>>...`) is lifted onto the
  /// resulting [Action.stereotype] field rather than concatenated into the
  /// label.
  Action _parseBulletAction() {
    _advance(); // consume the leading `-`
    String? stereotype;
    if (_check(TokenType.stereotype)) {
      stereotype = _advance().lexeme;
    }
    final parts = <String>[];
    while (!_check(TokenType.newline) &&
        !_check(TokenType.endUml) &&
        !_check(TokenType.eof)) {
      // A trailing stereotype on the same bullet line also rides as
      // metadata on the action rather than as text.
      if (_check(TokenType.stereotype)) {
        stereotype ??= _advance().lexeme;
        continue;
      }
      parts.add(_advance().lexeme);
    }
    return Action(text: parts.join(' ').trim(), stereotype: stereotype);
  }

  IfBlock _parseIfBlock() {
    final branches = <IfBranch>[];
    final first = _readIfHeader('if');
    branches.add(IfBranch(
      condition: first.condition,
      thenLabel: first.thenLabel,
      body: _parseActivityBlock(_ifBlockTerminator),
    ));
    while (_isKeyword('elseif')) {
      final more = _readIfHeader('elseif');
      branches.add(IfBranch(
        condition: more.condition,
        thenLabel: more.thenLabel,
        body: _parseActivityBlock(_ifBlockTerminator),
      ));
    }
    String? elseLabel;
    var elseBody = const <ActivityNode>[];
    if (_isKeyword('else')) {
      _advance();
      if (_check(TokenType.leftParen)) {
        _advance();
        if (_check(TokenType.text)) {
          elseLabel = _advance().lexeme;
        }
        if (_check(TokenType.rightParen)) _advance();
      }
      elseBody = _parseActivityBlock(_ifBlockTerminator);
    }
    if (!_isKeyword('endif')) {
      final t = _peek();
      throw ParserException(
          "Expected 'endif' to close if block, got '${t.lexeme}'",
          t.line,
          t.column);
    }
    _advance();
    return IfBlock(
      branches: List.unmodifiable(branches),
      elseLabel: elseLabel,
      elseBody: List.unmodifiable(elseBody),
    );
  }

  bool _ifBlockTerminator() =>
      _isKeyword('elseif') || _isKeyword('else') || _isKeyword('endif');

  _IfHeader _readIfHeader(String kw) {
    _advance();
    String condition = '';
    if (_check(TokenType.leftParen)) {
      _advance();
      if (_check(TokenType.text)) {
        condition = _advance().lexeme;
      }
      if (_check(TokenType.rightParen)) _advance();
    }
    // Optional `is (value)` clause that labels the THEN branch with the
    // matched value: `if (color?) is (red) then`. The value text may contain
    // inline color markup such as `<color:red>red`, which the lexer captures
    // verbatim as the parenthesized text token. We currently consume but do
    // not retain the value — the label is informational and not yet
    // surfaced in the activity AST.
    if (_isKeyword('is')) {
      _advance();
      if (_check(TokenType.leftParen)) {
        _advance();
        if (_check(TokenType.text)) {
          _advance();
        }
        if (_check(TokenType.rightParen)) _advance();
      }
    }
    String? thenLabel;
    if (_isKeyword('then')) {
      _advance();
      if (_check(TokenType.leftParen)) {
        _advance();
        if (_check(TokenType.text)) {
          thenLabel = _advance().lexeme;
        }
        if (_check(TokenType.rightParen)) _advance();
      }
    }
    return _IfHeader(condition: condition, thenLabel: thenLabel);
  }

  WhileBlock _parseWhileBlock() {
    _advance();
    String condition = '';
    if (_check(TokenType.leftParen)) {
      _advance();
      if (_check(TokenType.text)) {
        condition = _advance().lexeme;
      }
      if (_check(TokenType.rightParen)) _advance();
    }
    String? isLabel;
    if (_isKeyword('is')) {
      _advance();
      if (_check(TokenType.leftParen)) {
        _advance();
        if (_check(TokenType.text)) {
          isLabel = _advance().lexeme;
        }
        if (_check(TokenType.rightParen)) _advance();
      }
    }
    final body = _parseActivityBlock(() => _isKeyword('endwhile'));
    if (!_isKeyword('endwhile')) {
      final t = _peek();
      throw ParserException(
          "Expected 'endwhile' to close while block, got '${t.lexeme}'",
          t.line,
          t.column);
    }
    _advance();
    String? endLabel;
    if (_check(TokenType.leftParen)) {
      _advance();
      if (_check(TokenType.text)) {
        endLabel = _advance().lexeme;
      }
      if (_check(TokenType.rightParen)) _advance();
    }
    return WhileBlock(
      condition: condition,
      isLabel: isLabel,
      endLabel: endLabel,
      body: List.unmodifiable(body),
    );
  }

  RepeatBlock _parseRepeatBlock() {
    _advance();
    final body = _parseActivityBlock(() =>
        (_isKeyword('repeat') && _peekAhead(1, 'while')) ||
        _isKeyword('repeatwhile'));
    String? whileCondition;
    String? isLabel;
    String? notLabel;
    // Accept both the two-token form `repeat while ( ... )` and the single
    // compound identifier `repeatwhile ( ... )` that PlantUML also permits.
    if ((_isKeyword('repeat') && _peekAhead(1, 'while')) ||
        _isKeyword('repeatwhile')) {
      final isCompound = _isKeyword('repeatwhile');
      _advance();
      if (!isCompound) _advance();
      if (_check(TokenType.leftParen)) {
        _advance();
        if (_check(TokenType.text)) {
          whileCondition = _advance().lexeme;
        }
        if (_check(TokenType.rightParen)) _advance();
      }
      for (var i = 0; i < 2; i++) {
        if (_isKeyword('is') && isLabel == null) {
          _advance();
          if (_check(TokenType.leftParen)) {
            _advance();
            if (_check(TokenType.text)) {
              isLabel = _advance().lexeme;
            }
            if (_check(TokenType.rightParen)) _advance();
          }
        } else if (_isKeyword('not') && notLabel == null) {
          _advance();
          if (_check(TokenType.leftParen)) {
            _advance();
            if (_check(TokenType.text)) {
              notLabel = _advance().lexeme;
            }
            if (_check(TokenType.rightParen)) _advance();
          }
        } else {
          break;
        }
      }
    }
    return RepeatBlock(
      body: List.unmodifiable(body),
      whileCondition: whileCondition,
      isLabel: isLabel,
      notLabel: notLabel,
    );
  }

  ForkBlock _parseForkBlock() {
    _advance();
    final branches = <List<ActivityNode>>[];
    branches.add(_parseActivityBlock(
        () => (_isKeyword('fork') && _peekAhead(1, 'again')) || _isEndFork()));
    while (_isKeyword('fork') && _peekAhead(1, 'again')) {
      _advance();
      _advance();
      branches.add(_parseActivityBlock(() =>
          (_isKeyword('fork') && _peekAhead(1, 'again')) || _isEndFork()));
    }
    if (!_isEndFork()) {
      final t = _peek();
      throw ParserException(
          "Expected 'end fork' to close fork block, got '${t.lexeme}'",
          t.line,
          t.column);
    }
    _advance();
    _advance();
    return ForkBlock(branches: List.unmodifiable(branches));
  }

  bool _isEndFork() => _isKeyword('end') && _peekAhead(1, 'fork');

  /// Parses a `split` / `split again` / `end split` multi-way branch block.
  /// Mirrors [_parseForkBlock] but uses the split-specific terminators and
  /// returns a [SplitBlock]. Each branch is a sub-flow whose nodes may be
  /// followed by stand-alone `<<stereotype>>` tokens; those are attached by
  /// the shared [_parseActivityBlock] path.
  SplitBlock _parseSplitBlock() {
    _advance();
    final branches = <List<ActivityNode>>[];
    branches.add(_parseActivityBlock(() =>
        (_isKeyword('split') && _peekAhead(1, 'again')) || _isEndSplit()));
    while (_isKeyword('split') && _peekAhead(1, 'again')) {
      _advance();
      _advance();
      branches.add(_parseActivityBlock(() =>
          (_isKeyword('split') && _peekAhead(1, 'again')) || _isEndSplit()));
    }
    if (!_isEndSplit()) {
      final t = _peek();
      throw ParserException(
          "Expected 'end split' to close split block, got '${t.lexeme}'",
          t.line,
          t.column);
    }
    _advance();
    _advance();
    return SplitBlock(branches: List.unmodifiable(branches));
  }

  bool _isEndSplit() => _isKeyword('end') && _peekAhead(1, 'split');

  Partition _parsePartition() {
    _advance();
    String name = '';
    if (_check(TokenType.stringLiteral)) {
      name = _advance().lexeme;
    } else if (_check(TokenType.identifier)) {
      name = _advance().lexeme;
    }
    if (!_check(TokenType.leftBrace)) {
      final t = _peek();
      throw ParserException(
          "Expected '{' after partition name, got ${t.type}", t.line, t.column);
    }
    _advance();
    final body = _parseActivityBlock(() => _check(TokenType.rightBrace));
    if (!_check(TokenType.rightBrace)) {
      final t = _peek();
      throw ParserException(
          "Expected '}' to close partition", t.line, t.column);
    }
    _advance();
    return Partition(name: name, body: List.unmodifiable(body));
  }

  List<ActivityNode> _parseActivityBlock(bool Function() terminator) {
    final body = <ActivityNode>[];
    _skipNewlines();
    while (
        !_check(TokenType.endUml) && !_check(TokenType.eof) && !terminator()) {
      if (_check(TokenType.stereotype)) {
        _attachPendingStereotype(body);
        _skipNewlines();
        continue;
      }
      final node = _parseActivityNode();
      if (node != null) body.add(node);
      _skipNewlines();
    }
    return body;
  }

  bool _peekAhead(int offset, String word) {
    final k = _pos + offset;
    if (k >= _tokens.length) return false;
    final t = _tokens[k];
    return t.type == TokenType.identifier && t.lexeme == word;
  }

  void _skipUntilNewline() {
    while (!_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      _advance();
    }
  }

  bool _looksLikeStateDiagram() {
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.identifier &&
          (t.lexeme == 'state' || t.lexeme == 'State')) {
        return true;
      }
      if (t.type == TokenType.leftBracket) {
        if (k + 2 < _tokens.length &&
            _tokens[k + 1].type == TokenType.identifier &&
            _tokens[k + 1].lexeme == '*' &&
            _tokens[k + 2].type == TokenType.rightBracket) {
          return true;
        }
      }
    }
    return false;
  }

  StateDiagram _parseStateDiagram() {
    final states = <StateDecl>[];
    final transitions = <StateTransition>[];
    final byName = <String, int>{};

    void addState(StateDecl decl) {
      final idx = byName[decl.name];
      if (idx != null) {
        states[idx] = _mergeStateDecls(states[idx], decl);
        return;
      }
      // Suppress auto-declaration of a top-level state when the same name
      // already appears nested inside a previously-declared composite. This
      // avoids duplicate top-level boxes when a cross-container transition
      // (e.g. `X --> Z` between siblings nested under different parents)
      // is parsed AFTER the containers have been declared. The auto-declared
      // stubs carry no payload (no displayName / nested children), so we can
      // safely drop them when a richer or equivalently-named nested state
      // already exists in the tree.
      if (decl.displayName == null &&
          decl.nestedStates.isEmpty &&
          decl.nestedTransitions.isEmpty &&
          decl.concurrentRegions.isEmpty &&
          decl.descriptions.isEmpty &&
          _findNestedStateByName(states, decl.name)) {
        return;
      }
      byName[decl.name] = states.length;
      states.add(decl);
    }

    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeAllowmixing()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeInlineJsonBlock()) {
        _skipNewlines();
        continue;
      }
      // Anonymous brace block at top level (e.g. `{ state B }`). PlantUML
      // accepts this as a free-standing nested-state region declaration. We
      // recurse into the body so any contained `state X` declarations are
      // captured. This keeps weakly-structured state sources parseable.
      if (_check(TokenType.leftBrace)) {
        _advance();
        _skipNewlines();
        while (!_check(TokenType.rightBrace) &&
            !_check(TokenType.eof) &&
            !_check(TokenType.endUml)) {
          if (_isKeyword('state') || _isKeyword('State')) {
            addState(_parseStateDecl());
          } else if (_isKeyword('note')) {
            _skipNoteBlock();
          } else if (_check(TokenType.leftBrace)) {
            _consumeBraceBlock();
          } else {
            final t = _parseStateTransitionOrRef(addState);
            if (t != null) transitions.add(t);
          }
          _skipNewlines();
        }
        if (_check(TokenType.rightBrace)) _advance();
        _skipNewlines();
        continue;
      }
      if (_isKeyword('state') || _isKeyword('State')) {
        addState(_parseStateDecl());
      } else if (_isKeyword('note')) {
        _skipNoteBlock();
      } else if (_isKeyword('hide') || _isKeyword('show')) {
        _consumeRestOfLine();
      } else if (_isKeyword('scale')) {
        // PlantUML viewport directive `scale 600 width` / `scale 0.5` /
        // `scale max 1024*768`. Consume the rest of the line; rendering
        // honors only the diagram bounds today.
        _consumeRestOfLine();
      } else if (_check(TokenType.arrow)) {
        // Stray arrow at the start of a line (e.g. `->o f : <>->o g`). These
        // appear in sources where the label uses arrow glyphs that the lexer
        // happily tokenizes as a leading arrow. We have no LHS state to bind
        // to, so consume the rest of the line gracefully.
        _consumeRestOfLine();
      } else if (_isKeyword('mainframe')) {
        // `mainframe <label>` is a PlantUML decorator that wraps the
        // diagram in a UML frame with a folded-corner label. Inside a
        // state diagram we currently consume-and-ignore: the lexer emits
        // `identifier(mainframe)` + optional `text(label)`, which we drop.
        _advance();
        if (_check(TokenType.text)) _advance();
      } else if (_isStateContainerHeader()) {
        // `frame X { ... }`, `folder X { ... }`, etc. wrap a state-diagram
        // region. Consume the keyword + optional label, then recurse into
        // the brace body so the contained `state` / transitions still land
        // in the surrounding diagram.
        _consumeStateContainerInto(addState, transitions);
      } else {
        final t = _parseStateTransitionOrRef(addState);
        if (t != null) transitions.add(t);
      }
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    // PlantUML resolves state names globally, regardless of declaration order.
    // A composite/aliased state declared at top level owns its name; an empty
    // nested stub of the same name (auto-declared by a forward-referencing
    // transition inside another composite) is dropped so the state isn't
    // duplicated. The naming transition stays and becomes a cross-boundary edge.
    final ownedTopLevel = <String>{
      for (final s in states)
        if (_hasStatePayload(s)) s.name,
    };
    if (ownedTopLevel.isNotEmpty) {
      for (var i = 0; i < states.length; i++) {
        states[i] = _pruneNestedStubs(states[i], ownedTopLevel);
      }
    }
    return StateDiagram(
      states: List.unmodifiable(states),
      transitions: List.unmodifiable(transitions),
      decorations: _decorations.build(),
    );
  }

  StateDecl _parseStateDecl() {
    _advance();
    String name;
    String? displayName;
    // PlantUML dotted-name nesting (`state A.X`) only applies to bare
    // identifier names. A quoted name is a literal label and must never be
    // split, even if it contains dots. Track which form produced [name] so
    // the wrap step below knows whether to split on `.`.
    var splittable = false;
    if (_check(TokenType.stringLiteral)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        displayName = first;
        name = _expect(TokenType.identifier).lexeme;
      } else {
        // `state "alias2"` with no `as`: the quoted string is both the
        // visible label and the state's canonical name. Strip leading /
        // trailing whitespace for the name only (display preserves the
        // literal).
        displayName = first;
        name = first.trim();
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        // `state alias4 as "long name"` (reverse alias form): the identifier
        // is the canonical name and the following string literal is the
        // display label. The classic `state alias as Ident` is the other
        // branch.
        if (_check(TokenType.stringLiteral)) {
          name = first;
          displayName = _advance().lexeme;
        } else {
          displayName = first;
          name = _expect(TokenType.identifier).lexeme;
        }
      } else {
        name = first;
        splittable = true;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected state name, got ${t.type}', t.line, t.column);
    }

    String? stereotype;
    if (_check(TokenType.stereotype)) {
      final lex = _advance().lexeme;
      if (lex.isNotEmpty) stereotype = lex;
    }
    // PlantUML inline state styling: `#color[;key:value]...` for the
    // background and `##[modifier]color` for the border. Both lex to a
    // single hashColor token; we accept any number in either order and
    // defer the visual application to a future pass.
    while (_check(TokenType.hashColor)) {
      _advance();
    }
    // Stereotype can also appear *after* a `#color` styling token on the
    // same declaration line; accept that ordering too so that
    // `state X #lightblue <<choice>>` parses the same as
    // `state X <<choice>> #lightblue`.
    if (stereotype == null && _check(TokenType.stereotype)) {
      final lex = _advance().lexeme;
      if (lex.isNotEmpty) stereotype = lex;
    }
    // Optional trailing description: `state Foo : text`. The lexer emits
    // `colon` + `text` for whatever follows the colon (everything up to
    // the next newline). Captured into [descriptions] for rendering below
    // the state title; the display name is still derived from the alias
    // form when provided.
    final declDescriptions = <String>[];
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        declDescriptions.add(_advance().lexeme);
      }
    }

    final nested = <StateDecl>[];
    final nestedTrans = <StateTransition>[];
    final regions = <List<StateDecl>>[];
    var currentRegion = <StateDecl>[];
    var hasRegions = false;
    var horizontalRegions = false;

    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();

      final byName = <String, int>{};
      void addNested(StateDecl decl) {
        final idx = byName[decl.name];
        if (idx != null) {
          nested[idx] = _mergeStateDecls(nested[idx], decl);
          return;
        }
        byName[decl.name] = nested.length;
        nested.add(decl);
        currentRegion.add(decl);
      }

      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_check(TokenType.minusMinus) ||
            _check(TokenType.doublePipe)) {
          if (_check(TokenType.doublePipe)) {
            horizontalRegions = true;
          }
          _advance();
          hasRegions = true;
          regions.add(List<StateDecl>.from(currentRegion));
          currentRegion = <StateDecl>[];
          _skipNewlines();
          continue;
        }
        if (_isKeyword('state') || _isKeyword('State')) {
          addNested(_parseStateDecl());
        } else if (_isKeyword('note')) {
          _skipNoteBlock();
        } else if (_isKeyword('hide') || _isKeyword('show')) {
          _consumeRestOfLine();
        } else {
          final t = _parseStateTransitionOrRef(addNested);
          if (t != null) nestedTrans.add(t);
        }
        _skipNewlines();
      }
      if (_check(TokenType.rightBrace)) {
        _advance();
      }
      if (hasRegions) {
        regions.add(List<StateDecl>.from(currentRegion));
      }
    }

    final leaf = StateDecl(
      name: name,
      displayName: displayName,
      nestedStates: List.unmodifiable(nested),
      nestedTransitions: List.unmodifiable(nestedTrans),
      concurrentRegions: hasRegions
          ? List.unmodifiable(regions.map(List<StateDecl>.unmodifiable))
          : const [],
      descriptions: List.unmodifiable(declDescriptions),
      stereotype: stereotype,
      horizontalRegions: hasRegions && horizontalRegions,
    );
    // PlantUML dotted-name nesting: `state A.X` declares leaf `X` inside
    // composite `A`; `state A.B.C` nests `A { B { C } }`. The parsed payload
    // (display/stereotype/body) stays on the leaf; each ancestor becomes an
    // otherwise-empty composite wrapping its child. Quoted names and pseudo
    // refs are never split (see [splittable]).
    if (splittable && name.contains('.')) {
      return _wrapDottedName(name, leaf);
    }
    return leaf;
  }

  /// Wrap a dotted state name into nested composites. [fullName] is the dotted
  /// identifier (e.g. `A.B.C`) and [leafPayload] carries the declaration's
  /// body/stereotype/description. The leaf is renamed to the final segment and
  /// each preceding segment becomes an empty composite around its child. The
  /// returned decl is the top ancestor (`A`). Empty segments (a stray `.`) are
  /// ignored so the original name survives unchanged.
  StateDecl _wrapDottedName(String fullName, StateDecl leafPayload) {
    final segments = fullName.split('.').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return leafPayload;
    var current = StateDecl(
      name: segments.last,
      displayName: leafPayload.displayName,
      nestedStates: leafPayload.nestedStates,
      nestedTransitions: leafPayload.nestedTransitions,
      concurrentRegions: leafPayload.concurrentRegions,
      descriptions: leafPayload.descriptions,
      stereotype: leafPayload.stereotype,
      horizontalRegions: leafPayload.horizontalRegions,
    );
    for (var i = segments.length - 2; i >= 0; i--) {
      current = StateDecl(
        name: segments[i],
        nestedStates: List.unmodifiable(<StateDecl>[current]),
      );
    }
    return current;
  }

  /// Merge a re-declaration of the same state name into the [existing] decl.
  /// Scalar fields keep the original "incoming wins if present" semantics;
  /// descriptions concatenate. Nested children are UNIONED by name (recursing
  /// for deeper composites) rather than replaced, so dotted decls sharing a
  /// prefix (`state A.X` + `state A.Y`) accumulate siblings instead of the
  /// second overwriting the first. When [incoming] declares no nested children
  /// the [existing] children are preserved verbatim, so a state that is never
  /// re-declared with a body is byte-identical to the pre-merge behavior.
  StateDecl _mergeStateDecls(StateDecl existing, StateDecl incoming) {
    final List<StateDecl> mergedNested;
    if (incoming.nestedStates.isEmpty) {
      mergedNested = existing.nestedStates;
    } else if (existing.nestedStates.isEmpty) {
      mergedNested = incoming.nestedStates;
    } else {
      final result = List<StateDecl>.from(existing.nestedStates);
      final byName = <String, int>{
        for (var i = 0; i < result.length; i++) result[i].name: i,
      };
      for (final child in incoming.nestedStates) {
        final idx = byName[child.name];
        if (idx != null) {
          result[idx] = _mergeStateDecls(result[idx], child);
        } else {
          byName[child.name] = result.length;
          result.add(child);
        }
      }
      mergedNested = List.unmodifiable(result);
    }
    return StateDecl(
      name: existing.name,
      displayName: incoming.displayName ?? existing.displayName,
      nestedStates: mergedNested,
      nestedTransitions: incoming.nestedTransitions.isNotEmpty
          ? incoming.nestedTransitions
          : existing.nestedTransitions,
      concurrentRegions: incoming.concurrentRegions.isNotEmpty
          ? incoming.concurrentRegions
          : existing.concurrentRegions,
      descriptions: <String>[
        ...existing.descriptions,
        ...incoming.descriptions,
      ],
      stereotype: incoming.stereotype ?? existing.stereotype,
      horizontalRegions:
          incoming.horizontalRegions || existing.horizontalRegions,
    );
  }

  /// True when [name] appears as a nested state anywhere inside [states]
  /// (recursively walking nestedStates and concurrentRegions). Used to
  /// suppress duplicate top-level state stubs that the implicit-declaration
  /// path would otherwise emit when a cross-container transition references
  /// a state already declared inside a composite.
  bool _findNestedStateByName(List<StateDecl> states, String name) {
    for (final s in states) {
      for (final n in s.nestedStates) {
        if (n.name == name) return true;
        if (_findNestedStateByName([n], name)) return true;
      }
      for (final region in s.concurrentRegions) {
        for (final n in region) {
          if (n.name == name) return true;
          if (_findNestedStateByName([n], name)) return true;
        }
      }
    }
    return false;
  }

  /// True when [s] carries real content (nested children, regions, a display
  /// name, descriptions, or a stereotype) rather than being a bare stub.
  bool _hasStatePayload(StateDecl s) =>
      s.nestedStates.isNotEmpty ||
      s.concurrentRegions.isNotEmpty ||
      s.descriptions.isNotEmpty ||
      s.displayName != null ||
      s.stereotype != null;

  /// True when [s] is an empty auto-declared stub: a bare name with no payload
  /// and no nested transitions of its own.
  bool _isStateStub(StateDecl s) =>
      s.displayName == null &&
      s.stereotype == null &&
      s.nestedStates.isEmpty &&
      s.nestedTransitions.isEmpty &&
      s.concurrentRegions.isEmpty &&
      s.descriptions.isEmpty;

  /// Rebuild [decl] dropping any empty nested-state stub whose name is owned by
  /// a top-level state in [ownedNames], recursing through nested states and
  /// concurrent regions. The transition that referenced the stub is untouched.
  StateDecl _pruneNestedStubs(StateDecl decl, Set<String> ownedNames) {
    if (decl.nestedStates.isEmpty && decl.concurrentRegions.isEmpty) {
      return decl;
    }
    final nested = <StateDecl>[
      for (final c in decl.nestedStates)
        if (!(_isStateStub(c) && ownedNames.contains(c.name)))
          _pruneNestedStubs(c, ownedNames),
    ];
    final regions = <List<StateDecl>>[
      for (final region in decl.concurrentRegions)
        <StateDecl>[
          for (final c in region)
            if (!(_isStateStub(c) && ownedNames.contains(c.name)))
              _pruneNestedStubs(c, ownedNames),
        ],
    ];
    return StateDecl(
      name: decl.name,
      displayName: decl.displayName,
      nestedStates: List.unmodifiable(nested),
      nestedTransitions: decl.nestedTransitions,
      concurrentRegions: decl.concurrentRegions.isEmpty
          ? const []
          : List.unmodifiable(regions.map(List<StateDecl>.unmodifiable)),
      descriptions: decl.descriptions,
      stereotype: decl.stereotype,
      horizontalRegions: decl.horizontalRegions,
    );
  }

  /// True when the current token is a `frame` / `folder` / etc. container
  /// keyword used to visually group a region inside a state diagram. These
  /// containers carry no state-diagram semantics on their own — we accept
  /// them so that mixed PlantUML sources still parse.
  bool _isStateContainerHeader() {
    if (!_check(TokenType.identifier)) return false;
    const containerKws = {'frame', 'folder', 'package', 'node', 'cloud'};
    return containerKws.contains(_peek().lexeme);
  }

  /// Consumes a `frame X { ... }` style container at state-diagram scope by
  /// flattening its body into the surrounding diagram. The keyword and any
  /// optional label/string are skipped; if a brace block follows, contained
  /// state declarations and transitions are added to the outer collections.
  void _consumeStateContainerInto(
    void Function(StateDecl) addState,
    List<StateTransition> transitions,
  ) {
    _advance(); // consume container keyword
    // Optional label (identifier and/or quoted string), and optional
    // `as <alias>` rename — we only care about reaching the body.
    while (_check(TokenType.identifier) ||
        _check(TokenType.stringLiteral) ||
        _check(TokenType.stereotype) ||
        _check(TokenType.hashColor)) {
      _advance();
    }
    if (!_check(TokenType.leftBrace)) return;
    _advance();
    _skipNewlines();
    while (!_check(TokenType.rightBrace) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      if (_isKeyword('state') || _isKeyword('State')) {
        addState(_parseStateDecl());
      } else if (_isKeyword('note')) {
        _skipNoteBlock();
      } else if (_isKeyword('hide') || _isKeyword('show')) {
        _consumeRestOfLine();
      } else if (_isStateContainerHeader()) {
        _consumeStateContainerInto(addState, transitions);
      } else if (_check(TokenType.leftBrace)) {
        _consumeBraceBlock();
      } else {
        final t = _parseStateTransitionOrRef(addState);
        if (t != null) transitions.add(t);
      }
      _skipNewlines();
    }
    if (_check(TokenType.rightBrace)) _advance();
  }

  StateTransition? _parseStateTransitionOrRef(
      void Function(StateDecl) addState) {
    final from = _readStateRef();
    // `name : description` form — a member-style state description that
    // attaches to an already-declared (or implicitly-declared) state. We
    // capture the text into [StateDecl.descriptions] so the renderer can
    // display the lines below the state title.
    if (_check(TokenType.colon)) {
      _advance();
      String? desc;
      if (_check(TokenType.text)) {
        desc = _advance().lexeme;
      }
      if (!_isStatePseudoRef(from)) {
        addState(_refStub(
          from,
          descriptions: desc != null ? <String>[desc] : const <String>[],
        ));
      }
      return null;
    }
    // PlantUML bare state declaration with a stereotype but no `state` keyword
    // (e.g. `end <<end>>`). Accept the stereotype and any trailing line-tail
    // styling as an implicit state declaration so the surrounding diagram
    // parses cleanly. The stereotype rides on the StateDecl so layouts can
    // dispatch pseudo-state shapes (start/end/choice/fork/join).
    if (_check(TokenType.stereotype)) {
      final stereo = _advance().lexeme;
      while (_check(TokenType.hashColor)) {
        _advance();
      }
      if (_check(TokenType.colon)) {
        _advance();
        if (_check(TokenType.text)) _advance();
      }
      if (!_isStatePseudoRef(from)) {
        addState(_refStub(
          from,
          stereotype: stereo.isEmpty ? null : stereo,
        ));
      }
      return null;
    }
    // PlantUML bare state declaration without keyword or stereotype
    // (e.g. `State S1` parsed token-by-token, ends at newline). Accept it as
    // an implicit state declaration so the surrounding diagram still parses.
    if (_check(TokenType.newline) ||
        _check(TokenType.eof) ||
        _check(TokenType.endUml)) {
      if (!_isStatePseudoRef(from)) {
        addState(_refStub(from));
      }
      return null;
    }
    if (!_check(TokenType.arrow)) {
      final t = _peek();
      throw ParserException(
          "Expected arrow after state name, got ${t.type}", t.line, t.column);
    }
    final arrowTok = _advance();
    final dir = _classifyArrowDirection(arrowTok.lexeme);
    final to = _readStateRef();
    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        label = _advance().lexeme;
      }
    }
    if (!_isStatePseudoRef(from)) {
      addState(_refStub(from));
    }
    if (!_isStatePseudoRef(to)) {
      addState(_refStub(to));
    }
    return StateTransition(
      from: _refLeafName(from),
      to: _refLeafName(to),
      label: label,
      direction: dir,
    );
  }

  /// Leaf name a transition endpoint resolves to: the final segment of a
  /// dotted identifier (`A.X` -> `X`), so cross-composite arrows connect to
  /// the nested leaf. Pseudo refs (`[*]`, `[H]`, `[H*]`) and non-dotted names
  /// pass through unchanged.
  String _refLeafName(String ref) {
    if (_isStatePseudoRef(ref) || !ref.contains('.')) return ref;
    final segments = ref.split('.').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? ref : segments.last;
  }

  /// Build the implicit state declaration a transition endpoint implies. A
  /// dotted endpoint (`A.X`) creates the same nested composite shape as a
  /// `state A.X` declaration so undeclared composites still materialize and
  /// the payload lands on the leaf. Non-dotted refs stay flat as before.
  StateDecl _refStub(
    String ref, {
    List<String> descriptions = const <String>[],
    String? stereotype,
  }) {
    if (!ref.contains('.')) {
      return StateDecl(
        name: ref,
        descriptions: descriptions,
        stereotype: stereotype,
      );
    }
    final segments = ref.split('.').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      return StateDecl(
        name: ref,
        descriptions: descriptions,
        stereotype: stereotype,
      );
    }
    return _wrapDottedName(
      ref,
      StateDecl(
        name: segments.last,
        descriptions: descriptions,
        stereotype: stereotype,
      ),
    );
  }

  /// Resolve a state-transition arrow lexeme into a layout direction. Word
  /// hints (`up`/`down`/`left`/`right`) win; otherwise a SHORT arrow (single
  /// leading dash, e.g. `->`, `.>`) means horizontal/right and a LONG arrow
  /// (`-->`, `..>`) means vertical/down.
  StateArrowDirection _classifyArrowDirection(String lexeme) {
    final l = lexeme.toLowerCase();
    if (l.contains('up')) return StateArrowDirection.up;
    if (l.contains('down')) return StateArrowDirection.down;
    if (l.contains('left')) return StateArrowDirection.left;
    if (l.contains('right')) return StateArrowDirection.right;
    // Count leading dashes/dots before any letter or `>` to gauge length.
    final dashes = RegExp(r'^[-.]+').firstMatch(l)?.group(0)?.length ?? 0;
    if (dashes <= 1) return StateArrowDirection.right;
    return StateArrowDirection.down;
  }

  bool _isStatePseudoRef(String ref) {
    return ref == '[*]' || ref == '[H]' || ref == '[H*]';
  }

  String _readStateRef() {
    if (_check(TokenType.leftBracket)) {
      _advance();
      // PlantUML state pseudo-states inside brackets: `[*]` initial/final,
      // `[H]` shallow history, `[H*]` deep history. Accept any identifier
      // followed by an optional `*` (already merged into the identifier by
      // the lexer for the history form) and return a canonicalized name so
      // the diagram parses cleanly. Visual differentiation is deferred.
      if (!_check(TokenType.identifier)) {
        final t = _peek();
        throw ParserException(
            "Expected identifier inside '[]', got '${t.lexeme}'",
            t.line,
            t.column);
      }
      final inner = _advance().lexeme;
      // Allow `[H*]` where the lexer kept `*` as a separate identifier token.
      String tail = '';
      if (_check(TokenType.identifier) && _peek().lexeme == '*') {
        _advance();
        tail = '*';
      }
      if (!_check(TokenType.rightBracket)) {
        final t = _peek();
        throw ParserException(
            "Expected ']' to close pseudo-state, got ${t.type}",
            t.line,
            t.column);
      }
      _advance();
      return '[$inner$tail]';
    }
    if (_check(TokenType.identifier)) {
      final name = _advance().lexeme;
      // PlantUML chained history reference: `StateName[H]`, `StateName[H*]`.
      // The bracketed history marker attaches to the preceding state name.
      // We surface it as a synthetic pseudo-state name `[H]` / `[H*]` (the
      // base name is preserved for the surrounding container) so the
      // renderer can draw a small history-marker circle. This loses the
      // composite-vs-shallow association in the AST but matches PlantUML's
      // visual rendering of history pseudo-states.
      if (_check(TokenType.leftBracket)) {
        final save = _pos;
        _advance();
        if (_check(TokenType.identifier)) {
          final inner = _advance().lexeme;
          var tail = '';
          if (_check(TokenType.identifier) && _peek().lexeme == '*') {
            _advance();
            tail = '*';
          }
          if (_check(TokenType.rightBracket)) {
            _advance();
            if (inner == 'H' || inner == 'h') {
              return '[H$tail]';
            }
            return name;
          }
        }
        _pos = save;
      }
      return name;
    }
    final t = _peek();
    throw ParserException(
        "Expected state name, got ${t.type}", t.line, t.column);
  }

  bool _looksLikeUseCaseDiagram() {
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart &&
          t.type == TokenType.identifier &&
          (t.lexeme == 'usecase' || t.lexeme == 'rectangle')) {
        return true;
      }
      // Direction-hint arrow (`-left->`, `-up->`, `..down..>`, etc.) on a
      // relation line is a strong use-case-/class-diagram indicator since
      // sequence diagrams never use directional hint arrows. Route to use
      // case so the existing direction-aware layout handles the source.
      //
      // Exception: if the same logical line carries a bracketed component
      // (`[Name]`) on either side of the arrow, the line is a component-
      // diagram relation — defer to the component-diagram detector so that
      // `[Component] -left-> left` etc. don't get misrouted.
      if (t.type == TokenType.arrow && _isDirectionHintArrow(t.lexeme)) {
        var lineHasBracketComponent = false;
        for (var b = k - 1; b >= 0; b--) {
          final tb = _tokens[b];
          if (tb.type == TokenType.newline) break;
          if (tb.type == TokenType.leftBracket ||
              tb.type == TokenType.rightBracket) {
            lineHasBracketComponent = true;
            break;
          }
        }
        if (!lineHasBracketComponent) {
          for (var f = k + 1; f < _tokens.length; f++) {
            final tf = _tokens[f];
            if (tf.type == TokenType.newline ||
                tf.type == TokenType.eof ||
                tf.type == TokenType.endUml) {
              break;
            }
            if (tf.type == TokenType.leftBracket) {
              lineHasBracketComponent = true;
              break;
            }
          }
        }
        if (!lineHasBracketComponent) return true;
      }
      // `left to right direction` / `top to bottom direction` at the start
      // of a line is a use-case-/component-diagram directive. Route to use
      // case so the directive is consumed cleanly and any inline relations
      // (including direction-hint arrows) parse without error.
      //
      // Exception: if a later line contains a bracketed component (`[Name]`)
      // the source is a component diagram — defer to the component-diagram
      // detector which also consumes the directive cleanly.
      if (atLineStart &&
          t.type == TokenType.identifier &&
          (t.lexeme == 'left' || t.lexeme == 'top') &&
          k + 3 < _tokens.length &&
          _tokens[k + 1].type == TokenType.identifier &&
          _tokens[k + 1].lexeme == 'to' &&
          _tokens[k + 2].type == TokenType.identifier &&
          (_tokens[k + 2].lexeme == 'right' ||
              _tokens[k + 2].lexeme == 'bottom') &&
          _tokens[k + 3].type == TokenType.identifier &&
          _tokens[k + 3].lexeme == 'direction') {
        var hasBracketComponent = false;
        for (var j = k + 4; j < _tokens.length; j++) {
          final tj = _tokens[j];
          if (tj.type == TokenType.endUml || tj.type == TokenType.eof) break;
          if (tj.type == TokenType.leftBracket) {
            // Skip state pseudo-state literal `[*]`.
            if (j + 2 < _tokens.length &&
                _tokens[j + 1].type == TokenType.identifier &&
                _tokens[j + 1].lexeme == '*' &&
                _tokens[j + 2].type == TokenType.rightBracket) {
              continue;
            }
            hasBracketComponent = true;
            break;
          }
        }
        if (!hasBracketComponent) return true;
      }
      // PlantUML "phantom" / hidden-node marker: a trailing `/` immediately
      // after the `usecase`/`actor` keyword (e.g. `usecase/ UC3`,
      // `actor/ Woman3`) is use-case-specific syntax. Detecting it here
      // routes such declarations to the use-case parser even when no other
      // use-case indicator appears on the line.
      if (atLineStart &&
          t.type == TokenType.identifier &&
          (t.lexeme == 'usecase' || t.lexeme == 'actor') &&
          k + 1 < _tokens.length &&
          _tokens[k + 1].type == TokenType.slash) {
        return true;
      }
      // A parenthesized use-case ellipse `(Name)` appearing as the source or
      // target of an arrow is a use-case-specific construct. We scan each
      // arrow line and treat the presence of such an ellipse alongside an
      // arrow (in either direction) as a strong indicator. This lets
      // PlantUML's minimal use-case syntax (`User -> (Start)`,
      // `:user: --> (Use case 1)`) route to the use-case parser without
      // requiring an explicit `usecase`/`rectangle` keyword.
      if (t.type == TokenType.leftParen) {
        var j = k + 1;
        var sawInner = false;
        if (j < _tokens.length && _tokens[j].type == TokenType.text) {
          j++;
          sawInner = true;
        }
        // Require non-empty parentheses to qualify as a use-case ellipse.
        // Empty `()` is a component-diagram interface shorthand and must not
        // route the source to the use-case parser.
        if (sawInner &&
            j < _tokens.length &&
            _tokens[j].type == TokenType.rightParen) {
          // Walk forwards/backwards on this logical line to confirm an arrow
          // sits adjacent to this ellipse.
          for (var b = k - 1; b >= 0; b--) {
            final tb = _tokens[b];
            if (tb.type == TokenType.newline) break;
            if (tb.type == TokenType.arrow ||
                tb.type == TokenType.minusMinus) {
              return true;
            }
          }
          for (var f = j + 1; f < _tokens.length; f++) {
            final tf = _tokens[f];
            if (tf.type == TokenType.newline ||
                tf.type == TokenType.eof ||
                tf.type == TokenType.endUml) {
              break;
            }
            if (tf.type == TokenType.arrow ||
                tf.type == TokenType.minusMinus) {
              return true;
            }
          }
        }
      }
      // `:Display name:` colon-wrapped actor at the head of a relation. The
      // lexer flattens the rest of the line (after the leading `:`) into a
      // single text token; that text contains the second `:` followed by an
      // arrow and an ellipse target. Detecting this lets us route minimal
      // syntaxes like `:user: --> (Use case 1)` to the use-case parser
      // instead of the default sequence-diagram path.
      if (atLineStart && t.type == TokenType.colon) {
        final next = k + 1 < _tokens.length ? _tokens[k + 1] : null;
        if (next != null && next.type == TokenType.text) {
          final raw = next.lexeme;
          final closing = raw.indexOf(':');
          if (closing >= 0) {
            final tail = raw.substring(closing + 1);
            if (_useCaseColonTailIndicator.hasMatch(tail)) {
              return true;
            }
            // PlantUML "phantom" / hidden-node marker: a trailing `/`
            // immediately after the closing colon of `:Display:` (e.g.
            // `:First Actor:/` or `:Actor:/ as Alias`) is use-case-specific
            // syntax. Detecting it here routes the colon-wrapped declaration
            // to the use-case parser instead of the default sequence path.
            if (tail.trimLeft().startsWith('/')) {
              return true;
            }
          }
        }
      }
      atLineStart = false;
    }
    return false;
  }

  // Matches the residual text after the closing `:` of a colon-wrapped actor
  // when the rest of the line is an arrow + parenthesized use-case target.
  // Examples that should match (note: the leading `:user:` has already been
  // stripped, we only see the tail):
  //   ' --> (Use case 1)'
  //   ' ---> (Use the application) : A label'
  //   ' -> (Start)'
  static final RegExp _useCaseColonTailIndicator =
      RegExp(r'\s*-+>?\s*\(');

  bool _hasUnambiguousClassMarker() {
    const classOnly = {
      'class',
      'abstract',
      'enum',
      'annotation',
      'exception',
      'object',
      'map',
      'record',
    };
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart &&
          t.type == TokenType.identifier &&
          classOnly.contains(t.lexeme)) {
        return true;
      }
      atLineStart = false;
    }
    return false;
  }

  bool _looksLikeClassDiagram() {
    const headers = {
      'class',
      'interface',
      'enum',
      'abstract',
      'annotation',
      'exception',
      'object',
      'map',
      'record',
    };
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.identifier && headers.contains(t.lexeme)) {
        return true;
      }
      if (t.type == TokenType.identifier && t.lexeme == 'entity') {
        if (_entityIsClassHeader(k)) return true;
      }
      if (t.type == TokenType.arrow && _isUnambiguousClassArrow(t.lexeme)) {
        return true;
      }
    }
    return false;
  }

  bool _entityIsClassHeader(int k) {
    var j = k + 1;
    while (j < _tokens.length) {
      final t = _tokens[j];
      if (t.type == TokenType.newline) return false;
      if (t.type == TokenType.leftBrace) return true;
      if (t.type == TokenType.eof || t.type == TokenType.endUml) return false;
      j++;
    }
    return false;
  }

  static bool _isDirectionHintArrow(String lexeme) {
    // Direction-hint arrows embed the words `left` / `right` / `up` / `down`
    // inside the arrow body between dash runs, e.g. `-left->`, `-right->`,
    // `-up->`, `-down->`. Only treat as a hint when the directional word
    // sits between dashes/dots (so plain text containing these substrings
    // doesn't accidentally classify).
    for (final w in const ['left', 'right', 'up', 'down']) {
      final idx = lexeme.indexOf(w);
      if (idx <= 0) continue;
      final before = lexeme[idx - 1];
      final afterIdx = idx + w.length;
      if (afterIdx >= lexeme.length) continue;
      final after = lexeme[afterIdx];
      const sep = {'-', '.'};
      if (sep.contains(before) && sep.contains(after)) return true;
    }
    return false;
  }

  static bool _isUnambiguousClassArrow(String lexeme) {
    // Arrows that cannot appear in sequence diagrams: any arrow involving '|'
    // (inheritance triangle), filled/hollow diamond ends, '..' dependency,
    // or trailing '*' / 'o' that wasn't preceded by '-'/'>' (those would be
    // sequence arrow ends like '->o'). Sequence arrows allow trailing 'o'
    // and 'x' but never lead with them.
    if (lexeme.contains('|')) return true;
    if (lexeme.startsWith('*')) return true;
    if (lexeme.endsWith('*')) return true;
    if (lexeme.contains('..')) return true;
    // Sequence diagrams now allow `o`/`x` prefixes when paired with a head
    // marker (`<` / `>`) or half-arrow marker (`\`, `/`). Otherwise it's a
    // class arrow (composition / cross / aggregation tail).
    if (lexeme.startsWith('o') || lexeme.startsWith('x')) {
      final tail = lexeme.substring(1);
      final sequenceLike = tail.contains('<') ||
          tail.contains('>') ||
          tail.contains('\\') ||
          tail.contains('/');
      if (!sequenceLike) return true;
      return false;
    }
    // Extended class arrow head prefixes only valid in class diagrams.
    if (lexeme.startsWith('#') ||
        lexeme.startsWith('}') ||
        lexeme.startsWith('+') ||
        lexeme.startsWith('^')) {
      return true;
    }
    return false;
  }

  ClassDiagram _parseClassDiagram() {
    final classes = <ClassDecl>[];
    final relationships = <Relationship>[];
    final freeNotes = <FreeNote>[];
    var attachedNoteCounter = 0;

    void parseEntry() {
      // `hide`, `show`, `remove`, `restore` are visual / semantic directives
      // (filter members by selector, drop a class, etc.). Visual rendering is
      // deferred — accept-and-skip the rest of the line so they don't break
      // parsing. Multi-line `note ... end note` blocks are NOT introduced by
      // these keywords so a flat consume is safe.
      if (_isKeyword('hide') ||
          _isKeyword('show') ||
          _isKeyword('remove') ||
          _isKeyword('restore')) {
        _consumeRestOfLine();
        return;
      }
      if (_isKeyword('package') || _isKeyword('together')) {
        _parseClassPackage(classes, relationships, freeNotes,
            () => attachedNoteCounter++);
        return;
      }
      if (_isKeyword('note')) {
        final note = _tryParseClassNote(() => attachedNoteCounter++);
        if (note != null) {
          freeNotes.add(note);
          return;
        }
        // Unrecognised note form (e.g. `note on link …`, `note left:` without
        // a target). Consume gracefully so the rest of the diagram parses.
        _skipNoteBlock();
        return;
      }
      // Under `allowmixing`, accept the `actor/` and `usecase/` phantom-shape
      // declarations before the class-header dispatch so the slash isn't
      // mistaken for a relationship operator. Also accept any host mixed
      // element keyword that ISN'T already a class header (otherwise
      // class-only headers like `entity`, `interface`, `circle` would lose
      // their dedicated parse paths).
      if (_allowMixing && _isHostMixedSlashedKeyword()) {
        _consumeHostMixedElementDecl();
        return;
      }
      if (_allowMixing &&
          _isHostMixedElementKeyword() &&
          !_isClassHeaderKeyword()) {
        _consumeHostMixedElementDecl();
        return;
      }
      if (_isClassHeaderKeyword()) {
        classes.add(_parseClassDecl());
      } else if (_check(TokenType.leftParen) &&
          _tryParseAssociationClassRelation(
              relationships, classes,
              {for (final c in classes) c.name})) {
        // Association class form `(A, B) <arrow> C` — consumed above.
      } else {
        // PlantUML allows inline member declarations of the form
        // `ClassName : member`. If the line starts with an identifier
        // followed by `:`, treat the colon-trailing text as a no-op member
        // declaration on an (implicit) class. Visual member rendering for
        // this shorthand is deferred — we just accept the syntax so the
        // diagram parses. Same applies to `Name $tag` (tag-suffixed bare
        // class declaration) which is handled by `_parseClassRelationship`'s
        // missing-arrow recovery path.
        _parseClassRelationship(
          relationships,
          freeNotes,
          classes,
          {for (final c in classes) c.name},
        );
      }
    }

    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeAllowmixing()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeInlineJsonBlock()) {
        _skipNewlines();
        continue;
      }
      parseEntry();
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    // Auto-declare any class referenced by a relationship that wasn't given an
    // explicit declaration; PlantUML implicitly creates such classes.
    final declared = {for (final c in classes) c.name};
    final noteAliases = {for (final n in freeNotes) n.alias};
    for (final r in relationships) {
      for (final ref in [r.from, r.to]) {
        if (declared.contains(ref) || noteAliases.contains(ref)) continue;
        classes.add(ClassDecl(name: ref));
        declared.add(ref);
      }
    }
    // Merge any inline `ClassName : member` declarations onto the matching
    // ClassDecl. We rebuild the decl with a combined `members` list (preserving
    // any block-form members already parsed) so renderers see the full set.
    if (_classInlineMembers.isNotEmpty) {
      for (var i = 0; i < classes.length; i++) {
        final c = classes[i];
        final extras = _classInlineMembers[c.name];
        if (extras == null || extras.isEmpty) continue;
        classes[i] = ClassDecl(
          name: c.name,
          kind: c.kind,
          members: List.unmodifiable([...c.members, ...extras]),
          instanceOf: c.instanceOf,
          stereotype: c.stereotype,
          generics: c.generics,
        );
      }
    }
    return ClassDiagram(
      classes: List.unmodifiable(classes),
      relationships: List.unmodifiable(relationships),
      freeNotes: List.unmodifiable(freeNotes),
      decorations: _decorations.build(),
    );
  }

  void _skipNoteBlock() {
    final headerEnd = _findNextNewline();
    final sawNewlineInHeader = headerEnd != null;
    // A note header that contains an inline `:` is a single-line declaration
    // (e.g. `note left: text`). Don't scan onward for `end note`, otherwise
    // the next multi-line note block on a subsequent line would be swallowed.
    var headerHasInlineColon = false;
    if (headerEnd != null) {
      for (var k = _pos; k < headerEnd; k++) {
        if (_tokens[k].type == TokenType.colon) {
          headerHasInlineColon = true;
          break;
        }
      }
    }
    while (!_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      _advance();
    }
    if (!sawNewlineInHeader) return;
    if (headerHasInlineColon) return;
    if (_check(TokenType.newline)) _advance();
    while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
      if (_check(TokenType.identifier) && _peek().lexeme == 'end') {
        final save = _pos;
        _advance();
        if (_check(TokenType.identifier) && _peek().lexeme == 'note') {
          _advance();
          return;
        }
        _pos = save;
      }
      if (_check(TokenType.identifier) && _peek().lexeme == 'endnote') {
        _advance();
        return;
      }
      _advance();
    }
  }

  int? _findNextNewline() {
    for (var k = _pos; k < _tokens.length; k++) {
      if (_tokens[k].type == TokenType.newline) return k;
      if (_tokens[k].type == TokenType.eof) return null;
    }
    return null;
  }

  void _consumeRestOfLine() {
    while (!_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      _advance();
    }
  }

  /// Consumes an optional `between A and B` y-axis range clause used in
  /// `analog "X" between -4.5 and 6.5 as VCC`. Tolerates negative-number
  /// identifiers and decimal values. Visual axis scaling is deferred.
  void _consumeOptionalAnalogBetween() {
    if (!_isKeyword('between')) return;
    _advance();
    // Consume the lower bound (identifier such as `-4.5`, `350`).
    if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
      _advance();
    }
    if (_isKeyword('and')) {
      _advance();
      if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
        _advance();
      }
    }
  }

  /// Consumes a mixed-element top-level declaration inside a host parser
  /// that doesn't natively model the element kind (e.g. `node`, `cloud`,
  /// `agent`, `database` inside a use case diagram under `allowmixing`).
  /// The form is `<keyword> <identifier-or-string> [as <alias>]`. If the
  /// declaration opens a brace-balanced container body, it is consumed too.
  /// A coerced [UseCaseNode] is added so downstream relations resolve.
  // PlantUML element-type keywords that can introduce a `<kind> <name>`
  // declaration in component / use case / mixed diagrams. Used by the
  // use case parser to lower every such shape to an actor-kind node so the
  // alias enters the node list (rendering-shape mapping is deferred). The
  // four keywords already handled specially (`actor`, `usecase`, `rectangle`,
  // `package`) are intentionally omitted here so they keep their dedicated
  // parse paths.
  static const _mixedElementKeywords = {
    'action',
    'agent',
    'artifact',
    'boundary',
    'card',
    'circle',
    'cloud',
    'collections',
    'component',
    'control',
    'database',
    'entity',
    'file',
    'folder',
    'frame',
    'hexagon',
    'interface',
    'label',
    'node',
    'person',
    'process',
    'queue',
    'stack',
    'storage',
  };

  bool _isMixedElementKeyword() {
    if (!_check(TokenType.identifier)) return false;
    return _mixedElementKeywords.contains(_peek().lexeme);
  }

  void _consumeMixedTopLevelDecl(void Function(UseCaseNode) addNode) {
    _advance(); // consume keyword
    String? label;
    String? alias;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) alias = _advance().lexeme;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier) ||
            _check(TokenType.stringLiteral)) {
          alias = _advance().lexeme;
          label = first;
        }
      } else {
        alias = first;
      }
    }
    if (_check(TokenType.hashColor)) _advance();
    // PlantUML allows a trailing multi-line `[ ... ]` block as a free-form
    // description body on shape declarations (`folder name [\n...\n]`,
    // `node name [\n...\n]`, etc.). Consume it as a no-op so the line parses.
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    _skipNewlines();
    if (_check(TokenType.leftBrace)) {
      _consumeBraceBlock();
    }
    if (alias != null) {
      addNode(UseCaseNode(
        alias: alias,
        label: label ?? alias,
        kind: UseCaseNodeKind.actor,
      ));
    }
  }

  // Element-type keywords that may appear under `allowmixing` in a HOST
  // class / sequence / state / etc. diagram and should be accept-and-skipped
  // there. Superset of `_mixedElementKeywords` because the host diagram has
  // no native modeling for many of these (`actor`, `usecase`, `rectangle`,
  // `package`, `state` are all valid mixed shapes too in this context).
  static const _hostMixedElementKeywords = {
    'action',
    'actor',
    'agent',
    'artifact',
    'boundary',
    'card',
    'circle',
    'cloud',
    'collections',
    'component',
    'control',
    'database',
    'entity',
    'file',
    'folder',
    'frame',
    'hexagon',
    'interface',
    'label',
    'node',
    'package',
    'person',
    'process',
    'queue',
    'rectangle',
    'stack',
    'state',
    'storage',
    'usecase',
  };

  bool _isHostMixedElementKeyword() {
    if (!_check(TokenType.identifier)) return false;
    return _hostMixedElementKeywords.contains(_peek().lexeme);
  }

  /// True when the current token is one of `actor` or `usecase` followed
  /// immediately by `/` — the "phantom" / hidden variants `actor/` and
  /// `usecase/` used in use-case / mixed diagrams.
  bool _isHostMixedSlashedKeyword() {
    if (!_check(TokenType.identifier)) return false;
    final lex = _peek().lexeme;
    if (lex != 'actor' && lex != 'usecase') return false;
    if (_pos + 1 >= _tokens.length) return false;
    return _tokens[_pos + 1].type == TokenType.slash;
  }

  /// Accept-and-skip a mixed-element declaration in a host (non-component /
  /// non-use-case) diagram under `allowmixing`. Handles:
  ///   `<kw> <ident> [as <alias>]` and quoted-string variants
  ///   `<kw>/ <ident-or-string>` (phantom forms `actor/`, `usecase/`)
  ///   trailing inline-style `#color;line:X;text:Y` and `<<stereotype>>`
  ///   optional `{ ... }` body (consumed brace-balanced)
  void _consumeHostMixedElementDecl() {
    _advance(); // consume keyword
    if (_check(TokenType.slash)) {
      _advance(); // consume `/`
    }
    if (_check(TokenType.stringLiteral)) {
      _advance();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier) ||
            _check(TokenType.stringLiteral)) {
          _advance();
        }
      }
    } else if (_check(TokenType.identifier)) {
      _advance();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier) ||
            _check(TokenType.stringLiteral)) {
          _advance();
        }
      }
    }
    while (_check(TokenType.hashColor) || _check(TokenType.stereotype)) {
      _advance();
    }
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    _skipNewlines();
    if (_check(TokenType.leftBrace)) {
      _consumeBraceBlock();
    }
  }

  /// Consumes the `allowmixing` directive line as a no-op. PlantUML uses it to
  /// permit mixing element types (e.g. actor + json + class) in one diagram.
  /// Our parsers accept the directive but currently rely on the caller's host
  /// parser to also accept the mixed elements as best-effort no-op declarations.
  bool _tryConsumeAllowmixing() {
    if (_isKeyword('allowmixing')) {
      _advance();
      _consumeRestOfLine();
      _allowMixing = true;
      return true;
    }
    return false;
  }

  /// Consumes a balanced `{ ... }` block at the current position, respecting
  /// nested braces. Stops at EOF/@enduml even if the block is unbalanced.
  /// Returns true if a block was consumed. String literals are already
  /// tokenized by the lexer so braces inside strings never reach this layer.
  bool _consumeBraceBlock() {
    if (!_check(TokenType.leftBrace)) return false;
    var depth = 0;
    while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
      final t = _peek();
      if (t.type == TokenType.leftBrace) {
        depth++;
        _advance();
        continue;
      }
      if (t.type == TokenType.rightBrace) {
        depth--;
        _advance();
        if (depth == 0) return true;
        continue;
      }
      _advance();
    }
    return true;
  }

  /// Consumes a `json <name> { ... }` or `json "Display" as <alias> { ... }`
  /// declaration at the current position as a no-op (no AST node is produced).
  /// Used by host parsers (use case / class / state / component / sequence /
  /// allowmixing-style) to swallow embedded JSON blocks gracefully.
  ///
  /// Returns true when consumption happened. Both the `json` keyword and the
  /// trailing brace-balanced body are consumed.
  bool _tryConsumeInlineJsonBlock() {
    if (!_isKeyword('json')) return false;
    _advance(); // consume 'json'
    // Optional display name as string literal, optionally followed by `as <alias>`.
    if (_check(TokenType.stringLiteral)) {
      _advance();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) {
          _advance();
        }
      }
    } else if (_check(TokenType.identifier)) {
      _advance();
      // Allow optional `as <alias>` for safety.
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) {
          _advance();
        }
      }
    }
    _skipNewlines();
    if (_check(TokenType.leftBrace)) {
      _consumeBraceBlock();
    } else {
      _consumeRestOfLine();
    }
    return true;
  }

  void _parseClassPackage(
    List<ClassDecl> classes,
    List<Relationship> relationships,
    List<FreeNote> freeNotes,
    int Function() nextAttachedId,
  ) {
    _advance();
    if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
      _advance();
    }
    if (_check(TokenType.stereotype)) {
      _advance();
    }
    // Optional background color: `package X #color { ... }` or gradient
    // forms `#color1/color2` (already absorbed as a single hashColor token).
    if (_check(TokenType.hashColor)) {
      _advance();
    }
    if (!_check(TokenType.leftBrace)) {
      _consumeRestOfLine();
      return;
    }
    _advance();
    _skipNewlines();
    while (!_check(TokenType.rightBrace) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_isKeyword('hide')) {
        _consumeRestOfLine();
        _skipNewlines();
        continue;
      }
      if (_isKeyword('package') || _isKeyword('together')) {
        _parseClassPackage(classes, relationships, freeNotes, nextAttachedId);
        _skipNewlines();
        continue;
      }
      if (_isKeyword('note')) {
        final note = _tryParseClassNote(nextAttachedId);
        if (note != null) {
          freeNotes.add(note);
          _skipNewlines();
          continue;
        }
      }
      if (_isClassHeaderKeyword()) {
        classes.add(_parseClassDecl());
      } else {
        _parseClassRelationship(relationships, freeNotes);
      }
      _skipNewlines();
    }
    if (_check(TokenType.rightBrace)) _advance();
  }

  FreeNote? _tryParseClassNote(int Function() nextAttachedId) {
    final saved = _pos;
    _advance();
    if (_check(TokenType.stringLiteral)) {
      final text = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) {
          final alias = _advance().lexeme;
          return FreeNote(alias: alias, text: text);
        }
      }
      _pos = saved;
      return null;
    }
    // `note as N1` ... body ... `end note` — free-standing multi-line note.
    if (_isKeyword('as')) {
      _advance();
      if (!_check(TokenType.identifier)) {
        _pos = saved;
        return null;
      }
      final alias = _advance().lexeme;
      if (!_check(TokenType.newline)) {
        _pos = saved;
        return null;
      }
      final text = _consumeMultilineNoteBody();
      return FreeNote(alias: alias, text: text);
    }
    NotePosition? position;
    if (_isKeyword('left')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
        position = NotePosition.leftOf;
      }
    } else if (_isKeyword('right')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
        position = NotePosition.rightOf;
      }
    } else if (_isKeyword('top')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
        position = NotePosition.over;
      }
    } else if (_isKeyword('bottom')) {
      _advance();
      if (_isKeyword('of')) {
        _advance();
        position = NotePosition.over;
      }
    } else if (_isKeyword('over')) {
      _advance();
      position = NotePosition.over;
    }
    if (position == null) {
      _pos = saved;
      return null;
    }
    if (!_check(TokenType.identifier)) {
      _pos = saved;
      return null;
    }
    final target = _advance().lexeme;
    String text;
    if (_check(TokenType.colon)) {
      _advance();
      text = _check(TokenType.text) ? _advance().lexeme : '';
    } else if (_check(TokenType.newline)) {
      text = _consumeMultilineNoteBody();
    } else {
      _pos = saved;
      return null;
    }
    final alias = '__note_${nextAttachedId()}';
    return FreeNote(alias: alias, text: text, attachedTo: target);
  }

  bool _isClassHeaderKeyword() {
    if (_check(TokenType.leftParen) &&
        _pos + 1 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.rightParen) {
      return true;
    }
    if (_check(TokenType.generics) &&
        (_peek().lexeme == '<>' || _peek().lexeme.isEmpty)) {
      // `<> name` — PlantUML diamond-shape class declaration. Also matches
      // a bare `<>` token whose inner is empty (lexer represents `<>` as a
      // generics token with empty body).
      return true;
    }
    if (!_check(TokenType.identifier)) return false;
    const headers = {
      'class',
      'interface',
      'enum',
      'abstract',
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
    if (!headers.contains(_peek().lexeme)) return false;
    // Ambiguity: shape keywords like `diamond`, `circle`, `object` may also be
    // used as user-chosen class identifiers in relationship lines (e.g.
    // `diamond - "from 0..*" Station`). For SHAPE-ish keywords only, if the
    // next token is a relationship operator, treat the line as a relationship.
    // Core declaration keywords (`class`, `interface`, `enum`, `abstract`,
    // `annotation`, `record`, `entity`, `exception`) always start a header
    // regardless of what follows (e.g. `class "Foo" {}` has stringLiteral
    // after `class` — that's the display name, not multiplicity).
    const shapeishHeaders = {
      'diamond',
      'circle',
      'object',
      'stereotype',
      'struct',
      'protocol',
      'metaclass',
      'dataclass',
      'map',
    };
    if (!shapeishHeaders.contains(_peek().lexeme)) return true;
    if (_pos + 1 < _tokens.length) {
      final next = _tokens[_pos + 1].type;
      if (next == TokenType.arrow ||
          next == TokenType.minusMinus ||
          next == TokenType.dotDotDot ||
          next == TokenType.colon) {
        return false;
      }
    }
    return true;
  }

  ClassDecl _parseClassDecl() {
    var kind = ClassKind.class_;
    if (_check(TokenType.leftParen) &&
        _pos + 1 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.rightParen) {
      _advance();
      _advance();
      kind = ClassKind.circle;
    } else if (_check(TokenType.generics) &&
        (_peek().lexeme == '<>' || _peek().lexeme.isEmpty)) {
      _advance();
      kind = ClassKind.diamond;
    } else {
    final firstWord = _advance().lexeme;
    if (firstWord == 'abstract') {
      kind = ClassKind.abstractClass;
      if (_isKeyword('class')) {
        _advance();
      }
    } else {
      switch (firstWord) {
        case 'class':
          kind = ClassKind.class_;
        case 'interface':
          kind = ClassKind.interface;
        case 'enum':
          kind = ClassKind.enum_;
        case 'annotation':
          kind = ClassKind.annotation;
        case 'exception':
          kind = ClassKind.exception;
        case 'object':
          kind = ClassKind.object_;
        case 'map':
          kind = ClassKind.map_;
        case 'entity':
          kind = ClassKind.entity_;
        case 'record':
          kind = ClassKind.record_;
        case 'circle':
          kind = ClassKind.circle;
        case 'diamond':
          kind = ClassKind.diamond;
        case 'dataclass':
          kind = ClassKind.dataclass;
        case 'metaclass':
          kind = ClassKind.metaclass;
        case 'protocol':
          kind = ClassKind.protocol;
        case 'stereotype':
          kind = ClassKind.stereotype_;
        case 'struct':
          kind = ClassKind.struct;
      }
    }
    }
    if (!_check(TokenType.identifier) && !_check(TokenType.stringLiteral)) {
      final t = _peek();
      throw ParserException(
          'Expected class name, got ${t.type}', t.line, t.column);
    }
    final name = _advance().lexeme;
    // PlantUML 'as' alias: `class "This is my class" as class1` or
    // `class class2 as "It works this way too"`. Both forms are accepted; the
    // alias replaces the display name internally so downstream relationships
    // can resolve. Visual rendering of the alias-vs-name distinction is
    // deferred.
    String resolvedName = name;
    if (_isKeyword('as')) {
      _advance();
      if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
        resolvedName = _advance().lexeme;
      }
    }
    // PlantUML shape hints after the class name: `circle Foo ()`,
    // `diamond Bar <>`. Consume and ignore — the kind already encodes the
    // shape; the trailing glyph is purely a visual decoration.
    if (_check(TokenType.leftParen) &&
        _pos + 1 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.rightParen) {
      _advance();
      _advance();
    } else if (_check(TokenType.generics) && _peek().lexeme.isEmpty) {
      _advance();
    }
    String? generics;
    String? stereotype;
    for (var k = 0; k < 2; k++) {
      if (_check(TokenType.generics) && generics == null) {
        generics = _advance().lexeme;
      } else if (_check(TokenType.stereotype) && stereotype == null) {
        stereotype = _advance().lexeme;
      } else {
        break;
      }
    }
    // Consume optional `$tag` suffix on the class declaration (e.g.
    // `class C1 $tag13`). Visual / semantic tag handling is deferred.
    while (_check(TokenType.identifier) && _peek().lexeme.startsWith('\$')) {
      _advance();
    }
    // Consume optional trailing background color: `class Foo #red`,
    // `class Foo #red-green` (gradient). The lexer absorbs gradient forms
    // (`#a/b`, `#a|b`, `#a-b`) into a single hashColor token. Color is
    // captured but visual rendering is deferred.
    if (_check(TokenType.hashColor)) {
      _advance();
    }

    String? instanceOf;
    if ((kind == ClassKind.object_ || kind == ClassKind.map_) &&
        _check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        instanceOf = _advance().lexeme;
      } else if (_check(TokenType.identifier)) {
        instanceOf = _advance().lexeme;
      }
    }

    // Skip optional 'extends X' / 'implements Y' (ignored at AST level;
    // relationships should be expressed via explicit relationship lines).
    while (_check(TokenType.identifier) &&
        (_peek().lexeme == 'extends' || _peek().lexeme == 'implements')) {
      _advance();
      while (_check(TokenType.identifier)) {
        _advance();
        if (_check(TokenType.comma)) {
          _advance();
        } else {
          break;
        }
      }
    }

    final members = <ClassMember>[];
    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_check(TokenType.text)) {
          final line = _advance().lexeme;
          final ClassMember? parsed;
          if (kind == ClassKind.object_) {
            parsed = _parseAttributeLine(line, isMap: false);
          } else if (kind == ClassKind.map_) {
            parsed = _parseAttributeLine(line, isMap: true);
          } else {
            parsed = _parseMemberLine(line, kind);
          }
          if (parsed != null) members.add(parsed);
        } else {
          // Skip stray tokens defensively.
          _advance();
        }
        _skipNewlines();
      }
      if (_check(TokenType.rightBrace)) {
        _advance();
      }
    }
    return ClassDecl(
      name: resolvedName,
      kind: kind,
      members: List.unmodifiable(members),
      instanceOf: instanceOf,
      stereotype: stereotype,
      generics: generics,
    );
  }

  ClassMember? _parseAttributeLine(String raw, {required bool isMap}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '--') return const MemberDivider(DividerKind.solid);
    if (trimmed == '..') return const MemberDivider(DividerKind.dashed);
    if (trimmed == '==') return const MemberDivider(DividerKind.doubleLine);
    final sep = isMap ? '=>' : '=';
    final idx = trimmed.indexOf(sep);
    if (idx < 0) {
      return Attribute(name: trimmed, value: '', isMap: isMap);
    }
    final name = trimmed.substring(0, idx).trim();
    var value = trimmed.substring(idx + sep.length).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    return Attribute(name: name, value: value, isMap: isMap);
  }

  ClassMember? _parseMemberLine(String raw, ClassKind classKind) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '--') return const MemberDivider(DividerKind.solid);
    if (trimmed == '..') return const MemberDivider(DividerKind.dashed);
    if (trimmed == '==') return const MemberDivider(DividerKind.doubleLine);

    if (classKind == ClassKind.enum_) {
      final hasParens = trimmed.contains('(');
      final firstChar = trimmed[0];
      if (!hasParens && !'+-#~{'.contains(firstChar)) {
        return EnumValue(trimmed);
      }
    }

    var rest = trimmed;
    var isRequired = false;
    if (rest.startsWith('*')) {
      rest = rest.substring(1).trimLeft();
      isRequired = true;
    }
    String? stereotype;
    final stereoEnd = rest.lastIndexOf('>>');
    if (stereoEnd >= 0) {
      final stereoStart = rest.lastIndexOf('<<', stereoEnd);
      if (stereoStart >= 0 && stereoEnd == rest.length - 2) {
        stereotype = rest.substring(stereoStart + 2, stereoEnd).trim();
        rest = rest.substring(0, stereoStart).trimRight();
      }
    }
    var visibility = Visibility.public;
    if (rest.isEmpty) return null;
    final firstChar = rest[0];
    switch (firstChar) {
      case '+':
        visibility = Visibility.public;
        rest = rest.substring(1).trimLeft();
      case '-':
        visibility = Visibility.private;
        rest = rest.substring(1).trimLeft();
      case '#':
        visibility = Visibility.protected;
        rest = rest.substring(1).trimLeft();
      case '~':
        visibility = Visibility.packagePrivate;
        rest = rest.substring(1).trimLeft();
    }

    var isStatic = false;
    var isAbstract = false;
    while (rest.startsWith('{')) {
      final close = rest.indexOf('}');
      if (close < 0) break;
      final modifier = rest.substring(1, close).trim().toLowerCase();
      if (modifier == 'static') isStatic = true;
      if (modifier == 'abstract') isAbstract = true;
      rest = rest.substring(close + 1).trimLeft();
    }
    if (rest.isEmpty) return null;

    final parenIdx = rest.indexOf('(');
    if (parenIdx >= 0) {
      final closeParen = rest.indexOf(')', parenIdx);
      if (closeParen < 0) {
        final name = rest.substring(0, parenIdx);
        return Method(
          name: name,
          visibility: visibility,
          isStatic: isStatic,
          isAbstract: isAbstract,
          signature: rest,
        );
      }
      final name = rest.substring(0, parenIdx);
      final signature = rest.substring(0, closeParen + 1);
      String? returnType;
      final tail = rest.substring(closeParen + 1).trim();
      if (tail.startsWith(':')) {
        returnType = tail.substring(1).trim();
      } else if (tail.isNotEmpty) {
        returnType = tail;
      }
      return Method(
        name: name,
        visibility: visibility,
        isStatic: isStatic,
        isAbstract: isAbstract,
        signature: signature,
        returnType: returnType,
      );
    }
    final colonIdx = rest.indexOf(':');
    if (colonIdx >= 0) {
      final name = rest.substring(0, colonIdx).trim();
      final type = rest.substring(colonIdx + 1).trim();
      return Field(
        name: name,
        visibility: visibility,
        isStatic: isStatic,
        type: type.isEmpty ? null : type,
        required: isRequired,
        stereotype: stereotype,
      );
    }
    return Field(
      name: rest,
      visibility: visibility,
      isStatic: isStatic,
      required: isRequired,
      stereotype: stereotype,
    );
  }

  void _parseClassRelationship(
      List<Relationship> out, [
    List<FreeNote>? freeNotes,
    List<ClassDecl>? classes,
    Set<String>? declaredNames,
  ]) {
    String? fromMult;
    final from = _readRelationshipEnd();
    if (_check(TokenType.generics)) {
      _advance();
    }
    if (_check(TokenType.stringLiteral)) {
      fromMult = _advance().lexeme;
    }
    Token arrowToken;
    if (_check(TokenType.arrow)) {
      arrowToken = _advance();
    } else if (_check(TokenType.minusMinus)) {
      arrowToken = _advance();
    } else if (_check(TokenType.colon)) {
      // Inline member declaration: `ClassName : member`. Consume the colon
      // and the text token (if any). The member is parsed via the same
      // `_parseMemberLine` path used for block-form members and queued in
      // `_classInlineMembers` so it can be merged onto the (possibly
      // implicit) `ClassDecl` at the end of the parse. The class itself is
      // also registered as an implicit declaration if it hasn't been seen.
      _advance();
      String? memberText;
      if (_check(TokenType.text)) memberText = _advance().lexeme;
      if (classes != null && declaredNames != null) {
        if (!declaredNames.contains(from)) {
          classes.add(ClassDecl(name: from));
          declaredNames.add(from);
        }
      }
      if (memberText != null) {
        final parsed = _parseMemberLine(memberText, ClassKind.class_);
        if (parsed != null) {
          _classInlineMembers.putIfAbsent(from, () => <ClassMember>[]).add(parsed);
        }
      }
      return;
    } else if (_check(TokenType.newline) ||
        _check(TokenType.eof) ||
        _check(TokenType.endUml) ||
        _check(TokenType.identifier)) {
      // Bare identifier on a line with no arrow — likely a tag-suffixed
      // class shorthand (e.g. `class C1 $tag13` parsed; here we recover from
      // the trailing tag token which the lexer emitted as a separate
      // identifier). Consume to end of line as a no-op so the implicit class
      // is still picked up by the auto-declaration sweep.
      if (classes != null && declaredNames != null) {
        if (!declaredNames.contains(from)) {
          classes.add(ClassDecl(name: from));
          declaredNames.add(from);
        }
      }
      _consumeRestOfLine();
      return;
    } else {
      final t = _peek();
      throw ParserException(
          'Expected relationship arrow after \'$from\', got ${t.type}',
          t.line,
          t.column);
    }
    String? toMult;
    if (_check(TokenType.stringLiteral)) {
      // A leading string literal here is ambiguous: it may be the to-end
      // multiplicity (e.g. `*-- "*" Leg`) or the quoted target class name
      // (e.g. `*-- "foo/dummy" : use`). Disambiguate by looking ahead — if
      // the next token is another identifier or string literal it was a
      // multiplicity; otherwise it's the target.
      final lookahead = _pos + 1 < _tokens.length ? _tokens[_pos + 1] : null;
      if (lookahead != null &&
          (lookahead.type == TokenType.identifier ||
              lookahead.type == TokenType.stringLiteral)) {
        toMult = _advance().lexeme;
      }
    }
    final to = _readRelationshipEnd();
    if (_check(TokenType.generics)) {
      _advance();
    }
    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        label = _advance().lexeme;
      }
    }
    final decoded = _decodeRelationshipArrow(arrowToken);
    String resolvedFrom = from;
    String resolvedTo = to;
    String? resolvedFromMult = fromMult;
    String? resolvedToMult = toMult;
    CrowFoot? resolvedFromCrow = decoded.fromCrowFoot;
    CrowFoot? resolvedToCrow = decoded.toCrowFoot;
    if (decoded.reverse) {
      resolvedFrom = to;
      resolvedTo = from;
      resolvedFromMult = toMult;
      resolvedToMult = fromMult;
      resolvedFromCrow = decoded.toCrowFoot;
      resolvedToCrow = decoded.fromCrowFoot;
    }
    out.add(Relationship(
      from: resolvedFrom,
      to: resolvedTo,
      kind: decoded.kind,
      label: label,
      fromMultiplicity: resolvedFromMult,
      toMultiplicity: resolvedToMult,
      fromCrowFoot: resolvedFromCrow,
      toCrowFoot: resolvedToCrow,
    ));
  }

  String _readRelationshipEnd() {
    if (_check(TokenType.identifier)) {
      return _advance().lexeme;
    }
    if (_check(TokenType.stringLiteral)) {
      return _advance().lexeme;
    }
    final t = _peek();
    throw ParserException(
        'Expected class name, got ${t.type}', t.line, t.column);
  }

  /// Attempts to consume a PlantUML association-class line of the form
  /// `(A, B) <arrow> C` — a dotted/dashed connector linking the relation
  /// between two classes to a third "association" class. Returns `true` if
  /// the line was successfully recognised and consumed.
  ///
  /// The two member endpoints are accepted as either identifiers or string
  /// literals (the lexer collapses everything between the parens into a
  /// single `text` token when it sees `(` followed by non-arrow content, so
  /// this handler also accepts the `leftParen text rightParen` shape and
  /// splits the comma-separated members from the text payload).
  ///
  /// Visual rendering of the dotted association-class connector is deferred;
  /// here we just register the relationship endpoints as classes (auto-decl)
  /// and emit a plain `link` relation from the first member to the
  /// association class so the diagram still parses cleanly.
  bool _tryParseAssociationClassRelation(
    List<Relationship> out,
    List<ClassDecl> classes,
    Set<String> declaredNames,
  ) {
    final savedPos = _pos;
    if (!_check(TokenType.leftParen)) return false;
    _advance(); // consume '('
    final members = <String>[];
    if (_check(TokenType.text)) {
      // The greedy `(` lexer path collapses `Student, Course` into a single
      // text token. Split on commas (whitespace-trimmed) to recover the
      // member endpoint names.
      final raw = _advance().lexeme;
      for (final part in raw.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) members.add(trimmed);
      }
    } else {
      while (
          _check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
        members.add(_advance().lexeme);
        if (_check(TokenType.comma)) {
          _advance();
          continue;
        }
        break;
      }
    }
    if (!_check(TokenType.rightParen)) {
      _pos = savedPos;
      return false;
    }
    _advance(); // consume ')'
    Token arrowToken;
    if (_check(TokenType.arrow)) {
      arrowToken = _advance();
    } else if (_check(TokenType.minusMinus)) {
      arrowToken = _advance();
    } else {
      _pos = savedPos;
      return false;
    }
    if (!_check(TokenType.identifier) && !_check(TokenType.stringLiteral)) {
      _pos = savedPos;
      return false;
    }
    final assocClass = _advance().lexeme;
    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        label = _advance().lexeme;
      }
    }
    final decoded = _decodeRelationshipArrow(arrowToken);
    // Auto-declare any referenced class so it shows up in the AST.
    for (final ref in [...members, assocClass]) {
      if (!declaredNames.contains(ref)) {
        classes.add(ClassDecl(name: ref));
        declaredNames.add(ref);
      }
    }
    // Emit a single connector from the first member to the association class
    // as a stand-in. Full association-class semantics (a midpoint anchor
    // between the two members linked to the class) is deferred.
    if (members.isNotEmpty) {
      out.add(Relationship(
        from: members.first,
        to: assocClass,
        kind: decoded.kind,
        label: label,
      ));
    }
    return true;
  }

  _DecodedRelArrow _decodeRelationshipArrow(Token token) {
    final lexeme = token.lexeme;
    final crow = _decodeCrowFootArrow(lexeme);
    if (crow != null) return crow;
    if (lexeme.startsWith('#')) {
      return _DecodedRelArrow(RelationshipKind.squareLink, reverse: false);
    }
    if (lexeme.endsWith('#')) {
      return _DecodedRelArrow(RelationshipKind.squareLink, reverse: true);
    }
    if (lexeme.startsWith('x')) {
      return _DecodedRelArrow(RelationshipKind.crossLink, reverse: false);
    }
    if (lexeme.endsWith('x')) {
      return _DecodedRelArrow(RelationshipKind.crossLink, reverse: true);
    }
    if (lexeme.startsWith('}')) {
      return _DecodedRelArrow(RelationshipKind.bracketLink, reverse: false);
    }
    if (lexeme.endsWith('{')) {
      return _DecodedRelArrow(RelationshipKind.bracketLink, reverse: true);
    }
    if (lexeme.startsWith('+')) {
      return _DecodedRelArrow(RelationshipKind.plusLink, reverse: false);
    }
    if (lexeme.endsWith('+')) {
      return _DecodedRelArrow(RelationshipKind.plusLink, reverse: true);
    }
    if (lexeme.startsWith('^')) {
      return _DecodedRelArrow(RelationshipKind.caretLink, reverse: false);
    }
    if (lexeme.endsWith('v')) {
      return _DecodedRelArrow(RelationshipKind.caretLink, reverse: true);
    }
    final hasLeftTriangle = lexeme.startsWith('<|');
    final hasRightTriangle = lexeme.endsWith('|>');
    final startsDiamondFilled = lexeme.startsWith('*');
    final endsDiamondFilled = lexeme.endsWith('*');
    final startsDiamondHollow = lexeme.startsWith('o');
    final endsDiamondHollow = lexeme.endsWith('o');
    final hasLeftArrow = lexeme.startsWith('<');
    final hasRightArrow = lexeme.endsWith('>') && !hasRightTriangle;
    final dashed = lexeme.contains('.');

    if (hasLeftTriangle) {
      return _DecodedRelArrow(
        dashed ? RelationshipKind.realization : RelationshipKind.inheritance,
        reverse: false,
      );
    }
    if (hasRightTriangle) {
      return _DecodedRelArrow(
        dashed ? RelationshipKind.realization : RelationshipKind.inheritance,
        reverse: true,
      );
    }
    if (startsDiamondFilled) {
      return _DecodedRelArrow(RelationshipKind.composition, reverse: false);
    }
    if (endsDiamondFilled) {
      return _DecodedRelArrow(RelationshipKind.composition, reverse: true);
    }
    if (startsDiamondHollow) {
      return _DecodedRelArrow(RelationshipKind.aggregation, reverse: false);
    }
    if (endsDiamondHollow) {
      return _DecodedRelArrow(RelationshipKind.aggregation, reverse: true);
    }
    if (hasRightArrow) {
      return _DecodedRelArrow(
        dashed
            ? RelationshipKind.dependency
            : RelationshipKind.directedAssociation,
        reverse: false,
      );
    }
    if (hasLeftArrow) {
      return _DecodedRelArrow(
        dashed
            ? RelationshipKind.dependency
            : RelationshipKind.directedAssociation,
        reverse: true,
      );
    }
    return _DecodedRelArrow(
      dashed ? RelationshipKind.link : RelationshipKind.association,
      reverse: false,
    );
  }

  _DecodedRelArrow? _decodeCrowFootArrow(String lexeme) {
    if (lexeme.length < 5) return null;
    const leftEnds = {'||', '|o', '}o', '}|'};
    const rightEnds = {'||', 'o|', 'o{', '|{'};
    final left = lexeme.substring(0, 2);
    final right = lexeme.substring(lexeme.length - 2);
    if (!leftEnds.contains(left) || !rightEnds.contains(right)) return null;
    final body = lexeme.substring(2, lexeme.length - 2);
    if (body.isEmpty) return null;
    final isDashes = body.split('').every((c) => c == '-');
    final isDots = body.split('').every((c) => c == '.');
    if (!isDashes && !isDots) return null;
    CrowFoot fromKind;
    switch (left) {
      case '||':
        fromKind = CrowFoot.one;
      case '|o':
        fromKind = CrowFoot.zeroOrOne;
      case '}o':
        fromKind = CrowFoot.zeroOrMany;
      case '}|':
        fromKind = CrowFoot.oneOrMany;
      default:
        return null;
    }
    CrowFoot toKind;
    switch (right) {
      case '||':
        toKind = CrowFoot.one;
      case 'o|':
        toKind = CrowFoot.zeroOrOne;
      case 'o{':
        toKind = CrowFoot.zeroOrMany;
      case '|{':
        toKind = CrowFoot.oneOrMany;
      default:
        return null;
    }
    return _DecodedRelArrow(
      isDots ? RelationshipKind.link : RelationshipKind.association,
      reverse: false,
      fromCrowFoot: fromKind,
      toCrowFoot: toKind,
    );
  }

  /// Returns true when the source has at least one component-/deployment-
  /// only keyword at line start (e.g. `artifact`, `cloud`, `card`, `agent`,
  /// `stack`, `sprite`, `hexagon`) and no use-case-only marker (`usecase`,
  /// `actor`) at line start anywhere in the source. Used to override
  /// use-case detection when an overloaded keyword (like `rectangle`) shows
  /// up later in the source alongside clear component-only signals.
  bool _hasUnambiguousComponentMarker() {
    // Keywords that only appear in deployment / component diagrams (no
    // overlap with use-case-diagram syntax).
    const componentOnlyKeywords = {
      'artifact',
      'cloud',
      'card',
      'agent',
      'stack',
      'sprite',
      'hexagon',
      'file',
      'database',
      'queue',
      'storage',
      'component',
      'Component',
    };
    const useCaseOnlyKeywords = {'usecase', 'actor'};
    var atLineStart = true;
    var sawComponentMarker = false;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart && t.type == TokenType.identifier) {
        if (useCaseOnlyKeywords.contains(t.lexeme)) {
          // Mixed-source guard: any line-start use-case keyword means we
          // should defer to the use-case parser's normal routing logic.
          return false;
        }
        if (componentOnlyKeywords.contains(t.lexeme)) {
          sawComponentMarker = true;
        }
      }
      atLineStart = false;
    }
    return sawComponentMarker;
  }

  bool _looksLikeComponentDiagram() {
    const containerKeywords = {
      'package',
      'node',
      'cloud',
      'frame',
      'folder',
      'file',
      'hexagon',
    };
    const ambiguousContainerKeywords = {'database', 'queue', 'storage'};
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart && t.type == TokenType.identifier) {
        // Accept the `component` keyword regardless of letter case — PlantUML
        // tolerates `Component "X" as Y` interchangeably with `component ...`.
        if (t.lexeme.toLowerCase() == 'component') return true;
        if (t.lexeme == 'artifact') return true;
        // Mixed-element keywords introduced via `allowmixing`. Their presence
        // at line start is a strong component-diagram indicator since this is
        // the most lenient host parser for mixed contents.
        if (t.lexeme == 'agent') return true;
        if (t.lexeme == 'stack') return true;
        // `sprite $name [...] { ... }` declaration only appears in
        // component-style diagrams; treat as a component-diagram signal so
        // sources that lead with a sprite still dispatch here.
        if (t.lexeme == 'sprite') return true;
        // `rectangle` and `card` are component-style container keywords; their
        // presence at line start dispatches into the component parser.
        if (t.lexeme == 'rectangle') return true;
        if (t.lexeme == 'card') return true;
        if (containerKeywords.contains(t.lexeme)) return true;
        if (ambiguousContainerKeywords.contains(t.lexeme)) {
          for (var j = k + 1; j < _tokens.length; j++) {
            final tt = _tokens[j];
            if (tt.type == TokenType.leftBrace) return true;
            if (tt.type == TokenType.newline ||
                tt.type == TokenType.eof ||
                tt.type == TokenType.endUml) {
              break;
            }
          }
        }
      }
      if (atLineStart && t.type == TokenType.leftBracket) {
        if (k + 2 < _tokens.length &&
            _tokens[k + 1].type == TokenType.identifier &&
            _tokens[k + 1].lexeme == '*' &&
            _tokens[k + 2].type == TokenType.rightBracket) {
          // Skip: this is the state pseudo-state literal.
        } else {
          var found = false;
          for (var j = k + 1; j < _tokens.length; j++) {
            final tt = _tokens[j];
            if (tt.type == TokenType.rightBracket) {
              found = true;
              break;
            }
            if (tt.type == TokenType.newline ||
                tt.type == TokenType.eof ||
                tt.type == TokenType.endUml) {
              break;
            }
          }
          if (found) return true;
        }
      }
      if (atLineStart &&
          t.type == TokenType.leftParen &&
          k + 1 < _tokens.length &&
          _tokens[k + 1].type == TokenType.rightParen) {
        return true;
      }
      // Mid-line `<arrow> [Name]` or `[Name] <arrow>` patterns are also a
      // component-diagram signal — sequence diagrams don't accept bracketed
      // participants. Catches forms like `Interface <- [Component]`.
      if ((t.type == TokenType.arrow || t.type == TokenType.minusMinus) &&
          k + 1 < _tokens.length &&
          _tokens[k + 1].type == TokenType.leftBracket) {
        return true;
      }
      atLineStart = false;
    }
    return false;
  }

  ComponentDiagram _parseComponentDiagram() {
    final nodes = <ComponentNode>[];
    final containers = <ComponentContainer>[];
    final relations = <ComponentRelation>[];
    final seenAliases = <String>{};
    var leftToRight = false;

    void addNode(ComponentNode node) {
      if (seenAliases.add(node.alias)) {
        nodes.add(node);
      }
    }

    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_tryParseDirectionDirective(setLeftToRight: () {
        leftToRight = true;
      })) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeAllowmixing()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeInlineJsonBlock()) {
        _skipNewlines();
        continue;
      }
      if (_isKeyword('hide') ||
          _isKeyword('show') ||
          _isKeyword('remove') ||
          _isKeyword('restore')) {
        _consumeRestOfLine();
        _skipNewlines();
        continue;
      }
      if (_isKeyword('note')) {
        _skipNoteBlock();
        _skipNewlines();
        continue;
      }
      // `agent <name>` declares a node in mixed/component-style diagrams.
      // Treat it as a generic component for AST purposes.
      if (_isKeyword('agent')) {
        addNode(_parseAgentDecl());
        _skipNewlines();
        continue;
      }
      // `stack { ... }` container — when followed by `{`, recurse using the
      // existing component-container helper (with the kind mapped to package
      // as a best-effort fallback since there's no dedicated stack kind).
      // When followed by an identifier (no brace), treat as a generic node.
      if (_isKeyword('stack')) {
        if (_stackKeywordIsContainer()) {
          containers.add(_parseStackContainer(addNode));
        } else {
          addNode(_parseAgentDecl(asKind: ComponentNodeKind.component));
        }
        _skipNewlines();
        continue;
      }
      // `sprite $name [WxH/depth] { hex_grid }` — a sprite/icon definition.
      // We don't yet render sprite bitmaps; consume the whole declaration
      // (including the brace-balanced hex grid body) as a no-op so sources
      // that lead with a sprite still parse.
      if (_isKeyword('sprite')) {
        _skipSpriteBlock();
        _skipNewlines();
        continue;
      }
      // Bare `[ ... ]` block at line start whose body spans multiple lines is
      // a free-form description / comment attached to the previous element.
      // The body has no embedded identifier-as-alias, so just consume the
      // block (including the newline-broken interior) and continue.
      if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
        _skipMultiLineBracketBlock();
        _skipNewlines();
        continue;
      }
      if (_isComponentDeclKeyword()) {
        if (_componentDeclOpensContainer()) {
          containers.add(_parseComponentAsContainer(addNode,
              relations: relations));
        } else {
          addNode(_parseComponentDecl());
        }
      } else if (_isKeyword('artifact')) {
        if (_typedNodeKeywordIsContainer()) {
          containers.add(
              _parseComponentContainer(addNode, relations: relations));
        } else {
          addNode(_parseArtifactDecl());
        }
      } else if (_isKeyword('interface')) {
        addNode(_parseInterfaceDecl());
      } else if (_isKeyword('label')) {
        // PlantUML `label "<text>" [as Alias]` declares a free-standing label
        // element. Model as a component-kind node for AST purposes; visual
        // rendering of labels is currently deferred.
        addNode(_parseLabelDecl());
      } else if (_isKeyword('database')) {
        if (_typedNodeKeywordIsContainer()) {
          containers.add(
              _parseComponentContainer(addNode, relations: relations));
        } else {
          addNode(_parseTypedNodeDecl(ComponentNodeKind.database));
        }
      } else if (_isKeyword('queue')) {
        if (_typedNodeKeywordIsContainer()) {
          containers.add(
              _parseComponentContainer(addNode, relations: relations));
        } else {
          addNode(_parseTypedNodeDecl(ComponentNodeKind.queue));
        }
      } else if (_isKeyword('storage')) {
        if (_typedNodeKeywordIsContainer()) {
          containers.add(
              _parseComponentContainer(addNode, relations: relations));
        } else {
          addNode(_parseTypedNodeDecl(ComponentNodeKind.storage));
        }
      } else if (_isComponentContainerKeyword()) {
        containers.add(
            _parseComponentContainer(addNode, relations: relations));
      } else if (_check(TokenType.leftBracket) && !_bracketIsRelationStart()) {
        addNode(_parseBracketComponent());
      } else if (_check(TokenType.leftParen) &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.rightParen &&
          !_parenIsRelationStart()) {
        addNode(_parseParenInterface());
      } else {
        _parseComponentRelation(relations, addNode);
      }
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    return ComponentDiagram(
      nodes: List.unmodifiable(nodes),
      containers: List.unmodifiable(containers),
      relations: List.unmodifiable(relations),
      leftToRightDirection: leftToRight,
      decorations: _decorations.build(),
    );
  }

  bool _isComponentContainerKeyword() {
    if (!_check(TokenType.identifier)) return false;
    // `file` is included here so PlantUML deployment-style declarations like
    // `file f #color { [c1] [c2] }` or bare `file f #color` flow through the
    // shared container parser, which already handles trailing stereotypes,
    // inline-style hashColor tokens, multi-line `[...]` description blocks
    // and a brace-balanced body.
    const kws = {'package', 'node', 'cloud', 'frame', 'folder', 'rectangle',
        'card', 'file', 'hexagon'};
    return kws.contains(_peek().lexeme);
  }

  /// True if the current token is `component` or `Component` — PlantUML
  /// tolerates either case for the component declaration keyword.
  bool _isComponentDeclKeyword() {
    if (!_check(TokenType.identifier)) return false;
    final lex = _peek().lexeme;
    return lex == 'component' || lex == 'Component';
  }

  /// True if a `component <name>` declaration is followed by a `{` on the
  /// same logical line — meaning it opens a nested container body rather
  /// than just declaring a leaf component.
  bool _componentDeclOpensContainer() {
    for (var k = _pos + 1; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.leftBrace) return true;
      if (t.type == TokenType.newline ||
          t.type == TokenType.eof ||
          t.type == TokenType.endUml) {
        return false;
      }
    }
    return false;
  }

  /// True if the `[` at the current position is followed by a newline before
  /// any closing `]` — i.e. a bare multi-line `[ ... ]` descriptive block.
  ///
  /// The lexer collapses the multi-line body of `[ ... ]` into a single `text`
  /// token (so embedded Creole separators / inline markup don't trip the
  /// punctuation scanner). Detect that shape as well: a leftBracket followed
  /// directly by a text token and a rightBracket on the SAME logical position
  /// run is the absorbed multi-line form.
  bool _isMultiLineBracketBlock() {
    if (!_check(TokenType.leftBracket)) return false;
    // Lexer-absorbed form: `[` then `text` then `]` with no other tokens
    // between. The text token's lexeme contains embedded newlines.
    if (_pos + 2 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.text &&
        _tokens[_pos + 2].type == TokenType.rightBracket &&
        _tokens[_pos + 1].lexeme.contains('\n')) {
      return true;
    }
    var sawNewline = false;
    for (var k = _pos + 1; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.rightBracket) return sawNewline;
      if (t.type == TokenType.newline) {
        sawNewline = true;
        continue;
      }
      if (t.type == TokenType.eof || t.type == TokenType.endUml) {
        return false;
      }
    }
    return false;
  }

  /// Consumes a multi-line `[ ... ]` block (already validated by
  /// [_isMultiLineBracketBlock]) including the closing `]`.
  void _skipMultiLineBracketBlock() {
    _advance(); // consume `[`
    while (!_check(TokenType.rightBracket) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      _advance();
    }
    if (_check(TokenType.rightBracket)) _advance();
  }

  /// Consumes a `sprite $name [WxH/depth] { hex_grid_lines }` declaration as
  /// a no-op. The hex-grid body is brace-balanced so we count braces while
  /// consuming the rest of the block.
  void _skipSpriteBlock() {
    _advance(); // consume 'sprite'
    while (!_check(TokenType.leftBrace) &&
        !_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      _advance();
    }
    if (!_check(TokenType.leftBrace)) return;
    var depth = 0;
    while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
      if (_check(TokenType.leftBrace)) {
        depth++;
        _advance();
        continue;
      }
      if (_check(TokenType.rightBrace)) {
        depth--;
        _advance();
        if (depth == 0) return;
        continue;
      }
      _advance();
    }
  }

  /// Parses a `component <name> { ... }` declaration where the name is
  /// followed by a brace-balanced body — i.e. the component acts as a
  /// container for nested components, bracketed components, and relations.
  /// Modelled as a [ContainerKind.package] container for layout purposes
  /// since component diagrams don't have a dedicated `componentContainer`
  /// AST kind yet.
  ComponentContainer _parseComponentAsContainer(
      void Function(ComponentNode) addNode,
      {List<ComponentRelation>? relations}) {
    final relOut = relations ?? <ComponentRelation>[];
    final kwToken = _advance(); // consume `component`/`Component`
    String? label;
    String? alias;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
    } else if (_check(TokenType.identifier) && _peek().lexeme != 'as') {
      label = _advance().lexeme;
    }
    if (_isKeyword('as')) {
      _advance();
      // Accept both `component alias as Identifier` and
      // `component alias as "Display"` forms. In the latter case the
      // identifier consumed as `label` above is actually the alias and
      // the quoted string becomes the display label.
      if (_check(TokenType.stringLiteral)) {
        final displayed = _advance().lexeme;
        alias = label;
        label = displayed;
      } else {
        alias = _expect(TokenType.identifier).lexeme;
      }
    }
    // Tolerate trailing stereotype / hash color on the header line.
    for (var k = 0; k < 2; k++) {
      if (_check(TokenType.stereotype)) {
        _advance();
      } else if (_check(TokenType.hashColor)) {
        _advance();
      } else {
        break;
      }
    }
    final contained = <String>[];
    final nested = <ComponentContainer>[];
    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
          _skipMultiLineBracketBlock();
          _skipNewlines();
          continue;
        }
        if (_isComponentDeclKeyword()) {
          if (_componentDeclOpensContainer()) {
            nested.add(
                _parseComponentAsContainer(addNode, relations: relOut));
          } else {
            final node = _parseComponentDecl();
            addNode(node);
            contained.add(node.alias);
          }
        } else if (_isKeyword('artifact')) {
          if (_typedNodeKeywordIsContainer()) {
            nested.add(
                _parseComponentContainer(addNode, relations: relOut));
          } else {
            final node = _parseArtifactDecl();
            addNode(node);
            contained.add(node.alias);
          }
        } else if (_isKeyword('interface')) {
          final node = _parseInterfaceDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isPortKeyword()) {
          final kind = _portKindFor(_peek().lexeme);
          final node = _parsePortDecl(kind);
          addNode(node);
          contained.add(node.alias);
        } else if (_check(TokenType.leftBracket) &&
            !_bracketIsRelationStart()) {
          final node = _parseBracketComponent();
          addNode(node);
          contained.add(node.alias);
        } else if (_check(TokenType.leftBracket) &&
            _bracketIsRelationStart()) {
          _parseComponentRelation(relOut, addNode);
        } else if (_isComponentContainerKeyword()) {
          nested.add(_parseComponentContainer(addNode, relations: relOut));
        } else {
          // Unknown / unsupported line — consume it so the body parses.
          _consumeRestOfLine();
        }
        _skipNewlines();
      }
      if (_check(TokenType.rightBrace)) _advance();
    }
    return ComponentContainer(
      kind: ContainerKind.package,
      label: label ?? alias ?? kwToken.lexeme,
      alias: alias ?? label ?? kwToken.lexeme,
      nodeAliases: List.unmodifiable(contained),
      nestedContainers: List.unmodifiable(nested),
    );
  }

  bool _typedNodeKeywordIsContainer() {
    for (var k = _pos + 1; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.leftBrace) return true;
      if (t.type == TokenType.newline ||
          t.type == TokenType.eof ||
          t.type == TokenType.endUml) {
        return false;
      }
    }
    return false;
  }

  bool _bracketIsRelationStart() {
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.rightBracket) {
        if (k + 1 < _tokens.length) {
          final next = _tokens[k + 1].type;
          return next == TokenType.arrow || next == TokenType.minusMinus;
        }
        return false;
      }
      if (t.type == TokenType.newline ||
          t.type == TokenType.eof ||
          t.type == TokenType.endUml) {
        return false;
      }
    }
    return false;
  }

  bool _parenIsRelationStart() {
    var k = _pos + 2;
    if (k >= _tokens.length) return false;
    while (k < _tokens.length) {
      final t = _tokens[k];
      if (t.type == TokenType.arrow || t.type == TokenType.minusMinus) {
        return true;
      }
      if (t.type == TokenType.newline ||
          t.type == TokenType.eof ||
          t.type == TokenType.endUml ||
          t.type == TokenType.colon) {
        return false;
      }
      k++;
    }
    return false;
  }

  /// Parses an `agent <Name>` or `agent "Display" as Alias` declaration.
  /// Used in mixed/component-style diagrams where PlantUML allows the
  /// `agent` element. Modelled as a generic component for now (no dedicated
  /// AST kind yet).
  ComponentNode _parseAgentDecl(
      {ComponentNodeKind asKind = ComponentNodeKind.component}) {
    _advance(); // consume keyword
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected element name, got ${t.type}', t.line, t.column);
    }
    // Optional trailing `<<Stereo>>` / `#color;line:X;text:Y` on the element
    // header line, in any order. Visual styling is currently deferred — we
    // just consume so the declaration parses.
    for (var k = 0; k < 3; k++) {
      if (_check(TokenType.stereotype)) {
        _advance();
      } else if (_check(TokenType.hashColor)) {
        _advance();
      } else {
        break;
      }
    }
    // PlantUML allows a trailing multi-line `[ ... ]` block as a free-form
    // description body. Consume as a no-op so the line parses.
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: asKind,
    );
  }

  /// True if the `stack` keyword at the current position is followed by a
  /// `{` on the same logical line — meaning it opens a container body.
  bool _stackKeywordIsContainer() {
    for (var k = _pos + 1; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.leftBrace) return true;
      if (t.type == TokenType.newline ||
          t.type == TokenType.eof ||
          t.type == TokenType.endUml) {
        return false;
      }
    }
    return false;
  }

  /// Parses a `stack { ... }` container. PlantUML's stack has no dedicated
  /// AST kind in this codebase yet, so we lower it to a package container
  /// for rendering. Embedded `json` blocks and unknown identifier-only
  /// declarations inside the body are accepted as no-ops so mixed contents
  /// don't break parsing.
  ComponentContainer _parseStackContainer(
      void Function(ComponentNode) addNode) {
    final kwToken = _advance(); // consume 'stack'
    String? label;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
    } else if (_check(TokenType.identifier) && _peek().lexeme != 'as') {
      label = _advance().lexeme;
    }
    String? alias;
    if (_isKeyword('as')) {
      _advance();
      // Accept both `stack alias as Identifier` and
      // `stack alias as "Display"` forms.
      if (_check(TokenType.stringLiteral)) {
        final displayed = _advance().lexeme;
        alias = label;
        label = displayed;
      } else {
        alias = _expect(TokenType.identifier).lexeme;
      }
    }
    final contained = <String>[];
    final nested = <ComponentContainer>[];
    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_tryConsumeInlineJsonBlock()) {
          _skipNewlines();
          continue;
        }
        if (_isKeyword('component')) {
          final node = _parseComponentDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('artifact')) {
          if (_typedNodeKeywordIsContainer()) {
            nested.add(_parseComponentContainer(addNode));
          } else {
            final node = _parseArtifactDecl();
            addNode(node);
            contained.add(node.alias);
          }
        } else if (_isKeyword('interface')) {
          final node = _parseInterfaceDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('agent')) {
          final node = _parseAgentDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isComponentContainerKeyword()) {
          nested.add(_parseComponentContainer(addNode));
        } else {
          // Unknown line — consume it so the container body parses.
          _consumeRestOfLine();
        }
        _skipNewlines();
      }
      if (_check(TokenType.rightBrace)) _advance();
    }
    return ComponentContainer(
      kind: ContainerKind.package,
      label: label ?? alias ?? kwToken.lexeme,
      alias: alias ?? label ?? kwToken.lexeme,
      nodeAliases: List.unmodifiable(contained),
      nestedContainers: List.unmodifiable(nested),
    );
  }

  ContainerKind _containerKindFor(String keyword) {
    switch (keyword) {
      case 'package':
        return ContainerKind.package;
      case 'node':
        return ContainerKind.node;
      case 'cloud':
        return ContainerKind.cloud;
      case 'frame':
        return ContainerKind.frame;
      case 'database':
        return ContainerKind.database;
      case 'queue':
        return ContainerKind.queue;
      case 'storage':
        return ContainerKind.storage;
      // PlantUML supports additional container shapes (`folder`, `rectangle`,
      // `card`) that this codebase doesn't yet have dedicated AST kinds for.
      // Map them to the nearest visual equivalent (frame for folder, package
      // for rectangle/card) so containers nested via these keywords parse
      // and render without error.
      case 'folder':
        return ContainerKind.frame;
      case 'rectangle':
      case 'card':
      case 'hexagon':
      case 'artifact':
        return ContainerKind.package;
    }
    return ContainerKind.package;
  }

  ComponentNode _parseComponentDecl() {
    _advance();
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.leftBracket)) {
      // `component [Name] as Alias` — bracketed-name form. The bracketed
      // name is the display label; the alias defaults to the same when no
      // explicit `as` clause is present.
      final name = _readBracketedName();
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = name;
      } else {
        alias = name;
        displayName = name;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected component name, got ${t.type}', t.line, t.column);
    }
    // Tolerate trailing stereotype (`<< Apache >>`) and/or `#color` on the
    // component header line in any order — PlantUML allows these in either
    // position after the alias.
    for (var k = 0; k < 3; k++) {
      if (_check(TokenType.hashColor)) {
        _advance();
      } else if (_check(TokenType.stereotype)) {
        _advance();
      } else {
        break;
      }
    }
    // Consume optional `$tag` suffix(es) on the component declaration (e.g.
    // `component C1 $tag13 $tag1`). Visual / semantic tag handling is
    // deferred — accept and discard.
    while (_check(TokenType.identifier) && _peek().lexeme.startsWith('\$')) {
      _advance();
    }
    // PlantUML allows a trailing multi-line `[ ... ]` block as a free-form
    // description body on shape declarations. Consume as a no-op so the line
    // parses. Visual rendering of the description is deferred.
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: ComponentNodeKind.component,
    );
  }

  ComponentNode _parseArtifactDecl() {
    _advance();
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected artifact name, got ${t.type}', t.line, t.column);
    }
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: ComponentNodeKind.artifact,
    );
  }

  /// Parses a PlantUML `label "<text>" [as Alias]` declaration in a component
  /// diagram. Modelled as a generic component node since there's no dedicated
  /// label AST kind. Visual rendering of labels is currently deferred.
  ComponentNode _parseLabelDecl() {
    _advance(); // consume `label`
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected label text, got ${t.type}', t.line, t.column);
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: ComponentNodeKind.component,
    );
  }

  ComponentNode _parseInterfaceDecl() {
    _advance();
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected interface name, got ${t.type}', t.line, t.column);
    }
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: ComponentNodeKind.interface,
    );
  }

  /// Parses a `port <name>`, `portin <name>`, or `portout <name>` declaration
  /// inside a component container. The bare-identifier form is the common
  /// case; the quoted-label `as <alias>` form is also accepted.
  ComponentNode _parsePortDecl(ComponentNodeKind kind) {
    _advance(); // consume `port`/`portin`/`portout`
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected port name, got ${t.type}', t.line, t.column);
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: kind,
    );
  }

  bool _isPortKeyword() {
    if (!_check(TokenType.identifier)) return false;
    final lex = _peek().lexeme;
    return lex == 'port' || lex == 'portin' || lex == 'portout';
  }

  ComponentNodeKind _portKindFor(String keyword) {
    switch (keyword) {
      case 'portin':
        return ComponentNodeKind.portIn;
      case 'portout':
        return ComponentNodeKind.portOut;
      default:
        return ComponentNodeKind.port;
    }
  }

  ComponentNode _parseTypedNodeDecl(ComponentNodeKind kind) {
    _advance();
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected node name, got ${t.type}', t.line, t.column);
    }
    // Optional trailing `<<Stereo>>` / `#color`.
    for (var k = 0; k < 2; k++) {
      if (_check(TokenType.stereotype)) {
        _advance();
      } else if (_check(TokenType.hashColor)) {
        _advance();
      } else {
        break;
      }
    }
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: kind,
    );
  }

  String _readBracketedName() {
    _advance();
    if (_check(TokenType.stringLiteral)) {
      final name = _advance().lexeme;
      if (!_check(TokenType.rightBracket)) {
        final t = _peek();
        throw ParserException(
            "Expected ']' to close bracketed component, got ${t.type}",
            t.line,
            t.column);
      }
      _advance();
      return name;
    }
    final parts = <String>[];
    while (!_check(TokenType.rightBracket) &&
        !_check(TokenType.newline) &&
        !_check(TokenType.eof) &&
        !_check(TokenType.endUml)) {
      parts.add(_advance().lexeme);
    }
    if (!_check(TokenType.rightBracket)) {
      final t = _peek();
      throw ParserException(
          "Expected ']' to close bracketed component, got ${t.type}",
          t.line,
          t.column);
    }
    _advance();
    if (parts.isEmpty) {
      // Empty bracket `[ ]` — accept as an anonymous placeholder. Synthesise
      // a unique alias so the rest of the parser can index it without
      // colliding with other anonymous slots.
      _anonBracketCounter++;
      return '__anon_$_anonBracketCounter';
    }
    // PlantUML embeds `\n` inside bracketed names to force a line break.
    // The lexer emits the literal `\n` as a `text` token; reconstruct the
    // name preserving the escape, then convert to a real newline. Other
    // adjacent tokens are joined with a single space so multi-word names
    // like `[Auth Service]` still come out as `Auth Service`.
    final buf = StringBuffer();
    for (var k = 0; k < parts.length; k++) {
      final p = parts[k];
      if (k > 0) {
        final prev = parts[k - 1];
        if (prev != r'\n' && p != r'\n') buf.write(' ');
      }
      buf.write(p);
    }
    return buf.toString().replaceAll(r'\n', '\n');
  }

  ComponentNode _parseBracketComponent() {
    final name = _readBracketedName();
    String alias = name;
    String? displayName;
    if (_isKeyword('as')) {
      _advance();
      alias = _expect(TokenType.identifier).lexeme;
      displayName = name;
    }
    // Optional trailing `<<Stereo>>` / `#color` on the bracket-component line
    // (e.g. `[AA] <<static lib>>`). Stereotypes are not currently mapped to
    // per-element style overrides — accept and discard.
    for (var k = 0; k < 2; k++) {
      if (_check(TokenType.stereotype)) {
        _advance();
      } else if (_check(TokenType.hashColor)) {
        _advance();
      } else {
        break;
      }
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias.trim(),
      kind: ComponentNodeKind.component,
    );
  }

  ComponentNode _parseParenInterface() {
    _advance();
    _expect(TokenType.rightParen);
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
        displayName = first;
      } else {
        alias = first;
      }
    } else {
      final t = _peek();
      throw ParserException(
          'Expected interface name after \'()\', got ${t.type}',
          t.line,
          t.column);
    }
    return ComponentNode(
      alias: alias,
      label: displayName ?? alias,
      kind: ComponentNodeKind.interface,
    );
  }

  ComponentContainer _parseComponentContainer(
      void Function(ComponentNode) addNode,
      {List<ComponentRelation>? relations}) {
    final relOut = relations ?? <ComponentRelation>[];
    final kwToken = _advance();
    final kind = _containerKindFor(kwToken.lexeme);
    String? label;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
    } else if (_check(TokenType.identifier) && !_check(TokenType.leftBrace)) {
      if (_peek().lexeme != 'as') {
        label = _advance().lexeme;
      }
    }
    String? alias;
    if (_isKeyword('as')) {
      _advance();
      // PlantUML accepts both `<keyword> alias as Identifier` and the
      // reversed `<keyword> alias as "Display"` form (where the quoted
      // string is the display label). In the latter case the identifier
      // already consumed above is the alias and the quoted string becomes
      // the label.
      if (_check(TokenType.stringLiteral)) {
        final displayed = _advance().lexeme;
        alias = label;
        label = displayed;
      } else {
        alias = _expect(TokenType.identifier).lexeme;
      }
    }
    // Optional stereotype `<<Stereo>>` and/or background `#color` on the
    // container header line, in any order — also tolerates ArchiMate-style
    // multi-stereotype headers `<<$sprite>><<behavior>> #color`.
    while (_check(TokenType.stereotype) || _check(TokenType.hashColor)) {
      _advance();
    }
    // PlantUML allows a trailing multi-line `[ ... ]` block as a free-form
    // description body on shape declarations. Consume as a no-op.
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    final contained = <String>[];
    final nested = <ComponentContainer>[];
    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_isKeyword('component')) {
          final node = _parseComponentDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('artifact')) {
          if (_typedNodeKeywordIsContainer()) {
            nested.add(
                _parseComponentContainer(addNode, relations: relOut));
          } else {
            final node = _parseArtifactDecl();
            addNode(node);
            contained.add(node.alias);
          }
        } else if (_isKeyword('interface')) {
          final node = _parseInterfaceDecl();
          addNode(node);
          contained.add(node.alias);
        } else if (_isPortKeyword()) {
          final kind = _portKindFor(_peek().lexeme);
          final node = _parsePortDecl(kind);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('database') &&
            !_typedNodeKeywordIsContainer()) {
          final node = _parseTypedNodeDecl(ComponentNodeKind.database);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('queue') && !_typedNodeKeywordIsContainer()) {
          final node = _parseTypedNodeDecl(ComponentNodeKind.queue);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('storage') &&
            !_typedNodeKeywordIsContainer()) {
          final node = _parseTypedNodeDecl(ComponentNodeKind.storage);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('database') &&
            _typedNodeKeywordIsContainer()) {
          nested.add(
              _parseComponentContainer(addNode, relations: relOut));
        } else if (_isKeyword('queue') && _typedNodeKeywordIsContainer()) {
          nested.add(
              _parseComponentContainer(addNode, relations: relOut));
        } else if (_isKeyword('storage') &&
            _typedNodeKeywordIsContainer()) {
          nested.add(
              _parseComponentContainer(addNode, relations: relOut));
        } else if (_check(TokenType.leftBracket) &&
            !_bracketIsRelationStart()) {
          final node = _parseBracketComponent();
          addNode(node);
          contained.add(node.alias);
        } else if (_check(TokenType.leftBracket) &&
            _bracketIsRelationStart()) {
          // `[Component] --> Target` line inside a container body — parse as
          // a cross-container relation. Don't claim either endpoint as a
          // member of this container; the relation parser auto-declares any
          // bracketed nodes at top scope.
          _parseComponentRelation(relOut, addNode);
        } else if (_check(TokenType.leftParen) &&
            _pos + 1 < _tokens.length &&
            _tokens[_pos + 1].type == TokenType.rightParen &&
            !_parenIsRelationStart()) {
          final node = _parseParenInterface();
          addNode(node);
          contained.add(node.alias);
        } else if (_check(TokenType.leftParen) &&
            _pos + 1 < _tokens.length &&
            _tokens[_pos + 1].type == TokenType.rightParen &&
            _parenIsRelationStart()) {
          _parseComponentRelation(relOut, addNode);
        } else if (_isComponentContainerKeyword()) {
          nested.add(
              _parseComponentContainer(addNode, relations: relOut));
        } else if (_check(TokenType.identifier) &&
            _peek().lexeme.startsWith('\$')) {
          // PlantUML preprocessor procedure / variable expansion at runtime
          // (`$service("Gateway", #LightBlue)`, `$tag`). The static parser
          // doesn't evaluate the preprocessor — accept the line as a no-op
          // so containers with macro-call children parse cleanly.
          _consumeRestOfLine();
        } else if (_check(TokenType.identifier)) {
          // Class-style relation inside a component package (e.g.
          // `Object <|-- ArrayList` or `Demo1 *- Demo2`). Component
          // diagrams routed here from a `package` parent may carry
          // class-diagram relations. Accept any identifier-starting
          // line as a generic component relation; if no arrow follows,
          // register it as a bare contained node.
          final save = _pos;
          final name = _advance().lexeme;
          if (_check(TokenType.arrow) || _check(TokenType.minusMinus)) {
            _pos = save;
            _parseComponentRelation(relOut, addNode);
          } else {
            addNode(ComponentNode(
              alias: name,
              label: name,
              kind: ComponentNodeKind.component,
            ));
            contained.add(name);
            _consumeRestOfLine();
          }
        } else {
          final t = _peek();
          throw ParserException(
              "Unexpected '${t.lexeme}' inside ${kwToken.lexeme} container",
              t.line,
              t.column);
        }
        _skipNewlines();
      }
      if (!_check(TokenType.rightBrace)) {
        throw ParserException("Expected '}' to close ${kwToken.lexeme}",
            kwToken.line, kwToken.column);
      }
      _advance();
    }
    return ComponentContainer(
      label: label,
      alias: alias,
      kind: kind,
      nodeAliases: List.unmodifiable(contained),
      nestedContainers: List.unmodifiable(nested),
    );
  }

  void _parseComponentRelation(
      List<ComponentRelation> out, void Function(ComponentNode) addNode) {
    final from = _readComponentRelationEnd();
    if (!_check(TokenType.arrow) && !_check(TokenType.minusMinus)) {
      // Bare identifier line — e.g. `$C2` referencing an existing component.
      // Accept as a node-reference no-op; auto-declare when not bracketed so
      // downstream layout still sees the alias.
      if (_check(TokenType.newline) ||
          _check(TokenType.eof) ||
          _check(TokenType.endUml)) {
        addNode(ComponentNode(
          alias: from.alias,
          label: from.alias,
          kind: ComponentNodeKind.component,
        ));
        return;
      }
      final t = _peek();
      throw ParserException(
          "Expected relationship arrow after '${from.alias}', got ${t.type}",
          t.line,
          t.column);
    }
    final arrowToken = _advance();
    final to = _readComponentRelationEnd();
    // Optional PlantUML inline-style suffix on the relation:
    // `--> bar1 #line:red;line.bold;text:red : label`. The lexer absorbs the
    // full `#color;line:X;line.X;text:X` run into a single hashColor token.
    // Visual styling on component relations is currently deferred — consume
    // the token so the line still parses.
    if (_check(TokenType.hashColor)) {
      _advance();
    }
    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        label = _advance().lexeme;
      }
    }
    final decoded = _decodeUseCaseArrow(arrowToken);
    final fromAlias =
        decoded.direction == MessageDirection.backward ? to.alias : from.alias;
    final toAlias =
        decoded.direction == MessageDirection.backward ? from.alias : to.alias;
    if (from.declared) {
      addNode(ComponentNode(
        alias: from.alias,
        label: from.alias,
        kind: ComponentNodeKind.component,
      ));
    }
    if (to.declared) {
      addNode(ComponentNode(
        alias: to.alias,
        label: to.alias,
        kind: ComponentNodeKind.component,
      ));
    }
    out.add(ComponentRelation(
      from: fromAlias,
      to: toAlias,
      lineStyle: decoded.lineStyle,
      head: decoded.head,
      direction: MessageDirection.forward,
      label: label,
    ));
  }

  _ComponentRelEnd _readComponentRelationEnd() {
    if (_check(TokenType.leftBracket)) {
      final name = _readBracketedName();
      return _ComponentRelEnd(name, declared: true);
    }
    // `() Name` — interface endpoint inline in a relation
    // (`[X] ..> () HTTP : use`). Consume the `()` glyph and read the
    // following identifier or string as the interface name.
    if (_check(TokenType.leftParen) &&
        _pos + 1 < _tokens.length &&
        _tokens[_pos + 1].type == TokenType.rightParen) {
      _advance();
      _advance();
      if (_check(TokenType.identifier)) {
        return _ComponentRelEnd(_advance().lexeme, declared: true);
      }
      if (_check(TokenType.stringLiteral)) {
        return _ComponentRelEnd(_advance().lexeme, declared: true);
      }
      final t = _peek();
      throw ParserException(
          'Expected interface name after \'()\', got ${t.type}',
          t.line,
          t.column);
    }
    if (_check(TokenType.identifier)) {
      return _ComponentRelEnd(_advance().lexeme, declared: false);
    }
    if (_check(TokenType.stringLiteral)) {
      return _ComponentRelEnd(_advance().lexeme, declared: false);
    }
    final t = _peek();
    throw ParserException(
        'Expected component name, got ${t.type}', t.line, t.column);
  }

  UseCaseDiagram _parseUseCaseDiagram() {
    final nodes = <UseCaseNode>[];
    final relations = <UseCaseRelation>[];
    final boundaries = <UseCaseBoundary>[];
    final notes = <UseCaseNote>[];
    final noteConnections = <UseCaseNoteConnection>[];
    final noteAliases = <String>{};
    final seenAliases = <String>{};
    var leftToRight = false;
    var attachedNoteCounter = 0;

    void addNode(UseCaseNode node) {
      if (seenAliases.add(node.alias)) {
        nodes.add(node);
        return;
      }
      // Already seen — only replace if the new declaration carries a real
      // label (different from the alias, signalling explicit declaration vs.
      // implicit auto-inference).
      if (node.label != node.alias) {
        final idx = nodes.indexWhere((n) => n.alias == node.alias);
        if (idx >= 0) nodes[idx] = node;
      }
    }

    void addNote(UseCaseNote note) {
      notes.add(note);
      noteAliases.add(note.alias);
    }

    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      if (_tryParseDirectionDirective(setLeftToRight: () {
        leftToRight = true;
      })) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeAllowmixing()) {
        _skipNewlines();
        continue;
      }
      if (_tryConsumeInlineJsonBlock()) {
        _skipNewlines();
        continue;
      }
      // Mixed-element declarations introduced via `allowmixing` inside a use
      // case diagram. The use-case AST doesn't model these element types
      // directly; we coerce them to actor-kind UseCaseNodes so the alias
      // appears in the node list and downstream relations resolve. Layout
      // currently treats them as actors. The set covers every PlantUML
      // component/deployment/use-case shape keyword that may legally appear
      // as a `<kind> <name>` declaration in a use case or mixed diagram.
      if (_isMixedElementKeyword()) {
        _consumeMixedTopLevelDecl(addNode);
        _skipNewlines();
        continue;
      }
      // `sprite $name [WxH/depth] { hex_grid }` — a sprite/icon definition.
      // Consumed as a no-op so sources that lead with a sprite still parse.
      if (_isKeyword('sprite')) {
        _skipSpriteBlock();
        _skipNewlines();
        continue;
      }
      if (_check(TokenType.leftParen) &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.rightParen) {
        // `() Interface` shorthand introduced by allowmixing.
        _advance();
        _advance();
        if (_check(TokenType.identifier)) {
          final alias = _advance().lexeme;
          addNode(UseCaseNode(
            alias: alias,
            label: alias,
            kind: UseCaseNodeKind.actor,
          ));
        }
        _skipNewlines();
        continue;
      }
      // `ignore newpage` and `newpage [<title>]` are accepted as no-ops in
      // use case diagrams so multi-page sources parse without error. Layout
      // does not currently honour page breaks for this diagram type.
      if (_isKeyword('ignore') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'newpage') {
        _advance();
        _advance();
        _collectLineRemainder();
        _skipNewlines();
        continue;
      }
      if (_isKeyword('newpage')) {
        _advance();
        _collectLineRemainder();
        _skipNewlines();
        continue;
      }
      if (_isKeyword('actor')) {
        addNode(_parseUseCaseNode(UseCaseNodeKind.actor));
      } else if (_isKeyword('usecase')) {
        addNode(_parseUseCaseNode(UseCaseNodeKind.useCase));
      } else if (_isKeyword('rectangle') || _isKeyword('package')) {
        boundaries.add(_parseRectangleBoundary(addNode,
            relations: relations,
            noteAliases: noteAliases,
            noteConnections: noteConnections));
      } else if (_isKeyword('note')) {
        _parseUseCaseNote(addNote, () => attachedNoteCounter++);
      } else if (_check(TokenType.colon)) {
        // `:Display name: [as Alias]` line at use-case scope declares an
        // actor inline — mirrors the sequence-diagram convenience syntax.
        // Two tokenizations of the leading `:Name:` appear depending on what
        // follows on the same line:
        //   - `:Display Name: as Alias`       -> colon, text("Display Name: as Alias")
        //   - `:Display Name: --> (Target)`   -> colon, text("Display Name"), colon
        // Detect both, declare the actor, and (if this is a relation line)
        // hand off to the relation parser with the resolved alias.
        final _ColonWrappedName decl;
        if (_pos + 2 < _tokens.length &&
            _tokens[_pos + 1].type == TokenType.text &&
            _tokens[_pos + 2].type == TokenType.colon) {
          _advance(); // open `:`
          final textTok = _advance();
          _advance(); // close `:`
          final displayName = textTok.lexeme.replaceAll(r'\n', '\n');
          decl = _ColonWrappedName(displayName, null);
        } else {
          decl = _consumeColonWrappedDisplayName();
        }
        final alias = decl.alias ?? _deriveAliasFromDisplayName(decl.displayName);
        // The stereotype may live either inside the trailing text token (when
        // the colon-actor and its `<< … >>` annotation share a line and the
        // lexer absorbed everything into one text run) or as a separate
        // [TokenType.stereotype] token consumed here. Accept whichever fired.
        final stereotype =
            decl.stereotype ?? _tryConsumeUseCaseStereotype();
        addNode(UseCaseNode(
          alias: alias,
          label: decl.displayName,
          kind: UseCaseNodeKind.actor,
          stereotype: stereotype,
        ));
        // If the colon-actor is the LEFT side of a relation, fall through to
        // the relation parser by re-anchoring through a synthetic source.
        if (_check(TokenType.arrow) || _check(TokenType.minusMinus)) {
          _parseUseCaseRelation(relations, addNode,
              noteAliases: noteAliases,
              noteConnections: noteConnections,
              leadingAlias: alias);
        }
      } else if (_check(TokenType.stringLiteral) &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'as') {
        // `"Display" as Alias` — implicit actor.
        // `"Display" as (Alias)` — implicit use case (paren alias = use case).
        final displayName = _advance().lexeme;
        _advance(); // consume `as`
        UseCaseNodeKind kind;
        String alias;
        if (_check(TokenType.leftParen)) {
          _advance();
          alias = _advance().lexeme;
          _expect(TokenType.rightParen);
          kind = UseCaseNodeKind.useCase;
        } else if (_check(TokenType.identifier)) {
          alias = _advance().lexeme;
          kind = UseCaseNodeKind.actor;
        } else {
          final t = _peek();
          throw ParserException(
              "Expected alias after 'as', got ${t.type}", t.line, t.column);
        }
        final stereotype = _tryConsumeUseCaseStereotype();
        addNode(UseCaseNode(
          alias: alias,
          label: displayName,
          kind: kind,
          stereotype: stereotype,
        ));
      } else if (_check(TokenType.leftParen)) {
        // `(Name)` at line start is a free-standing use-case ellipse. The
        // canonical form is `(Display Name)`; an optional trailing
        // `as Alias` or `as (Alias)` clause overrides the alias used to
        // reference this ellipse from later relations.
        final displayName = _consumeUseCaseEllipseName();
        // PlantUML "phantom"/hidden-node marker: an optional `/` immediately
        // after `(Name)` (e.g. `(Foo)/` or `(Foo)/ as (Alias)`). Consume as
        // a no-op so the rest of the declaration parses normally. Visual
        // hiding is currently deferred.
        if (_check(TokenType.slash)) {
          _advance();
        }
        String alias = displayName;
        if (_isKeyword('as')) {
          _advance();
          if (_check(TokenType.leftParen)) {
            alias = _consumeUseCaseEllipseName();
          } else if (_check(TokenType.identifier)) {
            alias = _advance().lexeme;
          } else {
            final t = _peek();
            throw ParserException(
                "Expected alias after 'as', got ${t.type}",
                t.line,
                t.column);
          }
        }
        final stereotype = _tryConsumeUseCaseStereotype();
        addNode(UseCaseNode(
          alias: alias,
          label: displayName,
          kind: UseCaseNodeKind.useCase,
          stereotype: stereotype,
        ));
        if (_check(TokenType.arrow) || _check(TokenType.minusMinus)) {
          _parseUseCaseRelation(relations, addNode,
              noteAliases: noteAliases,
              noteConnections: noteConnections,
              leadingAlias: alias);
        }
      } else if (_check(TokenType.identifier) &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.stereotype) {
        // `Identifier << Stereotype >>` at line start declares a bare actor
        // with a stereotype annotation. The lexer collapses `<< … >>` into a
        // single [TokenType.stereotype] token, so we can disambiguate this
        // from a relation purely by lookahead.
        final alias = _advance().lexeme;
        final stereotype = _tryConsumeUseCaseStereotype();
        addNode(UseCaseNode(
          alias: alias,
          label: alias,
          kind: UseCaseNodeKind.actor,
          stereotype: stereotype,
        ));
        if (_check(TokenType.arrow) || _check(TokenType.minusMinus)) {
          _parseUseCaseRelation(relations, addNode,
              noteAliases: noteAliases,
              noteConnections: noteConnections,
              leadingAlias: alias);
        }
      } else {
        _parseUseCaseRelation(relations, addNode,
            noteAliases: noteAliases,
            noteConnections: noteConnections);
      }
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    return UseCaseDiagram(
      nodes: List.unmodifiable(nodes),
      relations: List.unmodifiable(relations),
      boundaries: List.unmodifiable(boundaries),
      notes: List.unmodifiable(notes),
      noteConnections: List.unmodifiable(noteConnections),
      leftToRightDirection: leftToRight,
      decorations: _decorations.build(),
    );
  }

  /// Parses a `note ...` line within a use case diagram. Supports:
  ///
  /// - `note right of X : inline text`
  /// - `note right of (X) : inline text`
  /// - `note right of X` ... body ... `end note`
  /// - `note "free standing text" as N`
  ///
  /// The `position` keyword can be `right`, `left`, `top`, or `bottom`.
  /// Free-standing notes (with an `as N` alias) can later be referenced by
  /// dotted (`..`) connection lines.
  void _parseUseCaseNote(
    void Function(UseCaseNote) addNote,
    int Function() nextAttachedId,
  ) {
    _advance(); // `note`
    // Free-standing: `note "text" as Alias`.
    if (_check(TokenType.stringLiteral)) {
      final textTok = _advance();
      final text = textTok.lexeme.replaceAll(r'\n', '\n');
      if (!_isKeyword('as')) {
        final t = _peek();
        throw ParserException(
            "Expected 'as' after note text, got ${t.type}",
            t.line,
            t.column);
      }
      _advance();
      final aliasTok = _expect(TokenType.identifier);
      addNote(UseCaseNote(alias: aliasTok.lexeme, text: text));
      return;
    }
    // Positioned attached note.
    NotePosition position;
    if (_isKeyword('right')) {
      _advance();
      position = NotePosition.rightOf;
    } else if (_isKeyword('left')) {
      _advance();
      position = NotePosition.leftOf;
    } else if (_isKeyword('top') || _isKeyword('bottom')) {
      // We only model leftOf/rightOf/over today; map top/bottom to
      // rightOf as a graceful fallback so parsing succeeds and the note
      // is still rendered next to its target.
      _advance();
      position = NotePosition.rightOf;
    } else if (_isKeyword('over')) {
      _advance();
      position = NotePosition.over;
    } else {
      final t = _peek();
      throw ParserException(
          "Expected position keyword after 'note', got '${t.lexeme}'",
          t.line,
          t.column);
    }
    if (_isKeyword('of')) {
      _advance();
    }
    final String target;
    if (_check(TokenType.leftParen)) {
      target = _consumeUseCaseEllipseName();
    } else if (_check(TokenType.identifier)) {
      target = _advance().lexeme;
    } else {
      final t = _peek();
      throw ParserException(
          'Expected note target name, got ${t.type}', t.line, t.column);
    }
    final String text;
    if (_check(TokenType.colon)) {
      _advance();
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected note text, got ${t.type}', t.line, t.column);
      }
      text = _advance().lexeme.replaceAll(r'\n', '\n');
    } else if (_check(TokenType.newline)) {
      text = _consumeUseCaseMultilineNoteBody();
    } else {
      final t = _peek();
      throw ParserException(
          "Expected ':' or newline after note header, got ${t.type}",
          t.line,
          t.column);
    }
    final alias = '__usecase_note_${nextAttachedId()}__';
    addNote(UseCaseNote(
      alias: alias,
      text: text,
      position: position,
      attachedTo: target,
    ));
  }

  /// Consumes the body of a `note ... end note` block in a use case
  /// diagram. Body lines may be tokenized either as a single `text` token
  /// per line (when the lexer's note-body mode is active) or as a sequence
  /// of identifiers/punctuation — both are joined with the original spaces
  /// reconstructed.
  String _consumeUseCaseMultilineNoteBody() {
    _advance(); // consume the newline that opened the block
    final lines = <String>[];
    final currentLine = StringBuffer();
    int? currentLineNo;
    while (true) {
      if (_check(TokenType.eof) || _check(TokenType.endUml)) {
        final t = _peek();
        throw ParserException(
            "Expected 'end note' to close multi-line note",
            t.line,
            t.column);
      }
      if (_isKeyword('end') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          _tokens[_pos + 1].lexeme == 'note') {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine.toString());
        }
        _advance();
        _advance();
        return lines.join('\n');
      }
      if (_check(TokenType.newline)) {
        if (currentLine.isNotEmpty || lines.isNotEmpty) {
          lines.add(currentLine.toString());
          currentLine.clear();
        }
        currentLineNo = null;
        _advance();
        continue;
      }
      final t = _advance();
      if (currentLineNo != null && t.line != currentLineNo) {
        lines.add(currentLine.toString());
        currentLine.clear();
      }
      if (currentLine.isNotEmpty) currentLine.write(' ');
      currentLine.write(t.lexeme);
      currentLineNo = t.line;
    }
  }

  bool _tryParseDirectionDirective({required void Function() setLeftToRight}) {
    if (!_isKeyword('left') && !_isKeyword('top')) return false;
    final start = _pos;
    final first = _peek().lexeme;
    final isLeft = first == 'left';
    final expected = isLeft
        ? const ['left', 'to', 'right', 'direction']
        : const ['top', 'to', 'bottom', 'direction'];
    for (var i = 0; i < expected.length; i++) {
      final idx = start + i;
      if (idx >= _tokens.length) return false;
      final t = _tokens[idx];
      if (t.type != TokenType.identifier || t.lexeme != expected[i]) {
        return false;
      }
    }
    final after = start + expected.length;
    if (after < _tokens.length) {
      final t = _tokens[after];
      if (t.type != TokenType.newline &&
          t.type != TokenType.eof &&
          t.type != TokenType.endUml) {
        return false;
      }
    }
    for (var i = 0; i < expected.length; i++) {
      _advance();
    }
    if (isLeft) setLeftToRight();
    return true;
  }

  UseCaseNode _parseUseCaseNode(UseCaseNodeKind kind) {
    _advance();
    // PlantUML "phantom"/hidden-node marker: an optional `/` immediately
    // after the `usecase`/`actor` keyword (e.g. `usecase/ UC3`,
    // `actor/ Woman3`). Consume as a no-op so the rest of the declaration
    // parses normally. Visual hiding is currently deferred.
    if (_check(TokenType.slash)) {
      _advance();
    }
    String? displayName;
    final String alias;
    if (_check(TokenType.stringLiteral)) {
      // `usecase "Label" [as Alias]`.
      displayName = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        alias = _expect(TokenType.identifier).lexeme;
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.leftParen)) {
      // `usecase (Display Name) [as Alias|as (Alias)]` — parenthesized
      // display name following the keyword. Mirrors the bare `(Name)`
      // line-start form. The optional trailing `as` clause overrides the
      // alias used to reference this ellipse from later relations.
      displayName = _consumeUseCaseEllipseName();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.leftParen)) {
          alias = _consumeUseCaseEllipseName();
        } else if (_check(TokenType.identifier)) {
          alias = _advance().lexeme;
        } else {
          final t = _peek();
          throw ParserException(
              "Expected alias after 'as', got ${t.type}", t.line, t.column);
        }
      } else {
        alias = displayName;
      }
    } else if (_check(TokenType.identifier)) {
      final first = _advance().lexeme;
      if (_isKeyword('as')) {
        _advance();
        // `usecase Alias as <name>` — two shapes are valid here:
        //   1. `usecase UC1 as Login` (legacy)         -> identifier
        //   2. `usecase UC1 as "Multi\nline label"`    -> string literal
        // Shape (2) is the canonical PlantUML form for multi-line labels
        // and overrides the legacy shape: the FIRST token becomes the
        // alias and the quoted string becomes the display label. Shape (1)
        // is preserved by treating the first identifier as the label and
        // the second identifier as the alias.
        if (_check(TokenType.stringLiteral)) {
          alias = first;
          displayName = _advance().lexeme;
        } else {
          displayName = first;
          alias = _expect(TokenType.identifier).lexeme;
        }
      } else {
        alias = first;
      }
    } else if (_check(TokenType.colon)) {
      // `actor :Display Name: [as Alias]` — colon-wrapped display name
      // following the `actor`/`usecase` keyword. This shape is most useful
      // after a trailing `/` hidden-node marker (e.g.
      // `actor/ :Last actor: as Person1`) where the colon-wrapped name was
      // emitted mid-line by the greedy `:text...` lexer path.
      final decl = _consumeColonWrappedDisplayName();
      displayName = decl.displayName;
      alias = decl.alias ?? _deriveAliasFromDisplayName(decl.displayName);
    } else {
      final t = _peek();
      throw ParserException(
          'Expected use case name, got ${t.type}', t.line, t.column);
    }
    final label = displayName ?? alias;
    final spans = _parseUseCaseLabelSpans(label);
    final stereotype = _tryConsumeUseCaseStereotype();
    // Optional PlantUML inline-style suffix: `#<bg-color>[;line:<c>][;line.X][;text:<c>]`.
    // The lexer absorbs the full run into a single hashColor token; visual
    // styling is deferred — we just consume it so the parse succeeds.
    if (_check(TokenType.hashColor)) {
      _advance();
    }
    // PlantUML allows a trailing multi-line `[ ... ]` block as a free-form
    // description body on shape declarations (`usecase name [\n...\n]`).
    // Consume it as a no-op so the line parses.
    if (_check(TokenType.leftBracket) && _isMultiLineBracketBlock()) {
      _skipMultiLineBracketBlock();
    }
    return UseCaseNode(
      alias: alias,
      label: label,
      kind: kind,
      labelSpans: spans,
      stereotype: stereotype,
    );
  }

  /// Consumes an optional `<< Stereotype >>` token following a use-case node
  /// declaration. Returns the trimmed inner text (or `null` if absent /
  /// empty). The lexer already collapses `<< … >>` into a single
  /// [TokenType.stereotype] token whose lexeme is the trimmed inner text.
  String? _tryConsumeUseCaseStereotype() {
    if (!_check(TokenType.stereotype)) return null;
    final lex = _advance().lexeme;
    return lex.isEmpty ? null : lex;
  }

  /// Splits a use-case label into text + separator spans.
  ///
  /// PlantUML supports embedded section dividers inside the quoted label of
  /// a `usecase` shape:
  ///   `--`         on its own line  -> thin horizontal separator
  ///   `==`         on its own line  -> thick horizontal separator
  ///   `..text..`   on its own line  -> thin separator with centered text
  ///
  /// If the label contains none of these markers we return `null` and the
  /// layout falls back to rendering [label] verbatim. Otherwise we return a
  /// list of alternating [UseCaseLabelText] (joined adjacent lines) and
  /// [UseCaseLabelSeparatorSpan] entries.
  List<UseCaseLabelSpan>? _parseUseCaseLabelSpans(String label) {
    if (!label.contains('\n')) return null;
    final lines = label.split('\n');
    final spans = <UseCaseLabelSpan>[];
    final buf = StringBuffer();
    void flushText() {
      if (buf.isEmpty) return;
      spans.add(UseCaseLabelText(buf.toString()));
      buf.clear();
    }

    var sawSeparator = false;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed == '--') {
        flushText();
        spans.add(const UseCaseLabelSeparatorSpan(
            UseCaseLabelSeparator.thin));
        sawSeparator = true;
      } else if (trimmed == '==') {
        flushText();
        spans.add(const UseCaseLabelSeparatorSpan(
            UseCaseLabelSeparator.thick));
        sawSeparator = true;
      } else if (trimmed.length >= 4 &&
          trimmed.startsWith('..') &&
          trimmed.endsWith('..')) {
        flushText();
        final inner = trimmed.substring(2, trimmed.length - 2).trim();
        spans.add(UseCaseLabelSeparatorSpan(
            UseCaseLabelSeparator.labeled,
            text: inner.isEmpty ? null : inner));
        sawSeparator = true;
      } else {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(raw);
      }
    }
    flushText();
    if (!sawSeparator) return null;
    return List.unmodifiable(spans);
  }

  UseCaseBoundary _parseRectangleBoundary(void Function(UseCaseNode) addNode,
      {List<UseCaseRelation>? relations,
      Set<String>? noteAliases,
      List<UseCaseNoteConnection>? noteConnections}) {
    final rectToken = _advance();
    String? label;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
    } else if (_check(TokenType.identifier) && !_check(TokenType.leftBrace)) {
      if (_peek().lexeme != 'as') {
        label = _advance().lexeme;
      }
    }
    // Tolerate `<<Stereo>>` / `#color` / `as <alias>` on the rectangle
    // header in any order (e.g. `rectangle "X" <<$sprite>> {`,
    // `rectangle "X" <<$sprite>> as foo`). These don't yet drive layout but
    // accepting them keeps stereotyped boundaries parsing.
    for (var k = 0; k < 4; k++) {
      if (_check(TokenType.stereotype)) {
        _advance();
      } else if (_check(TokenType.hashColor)) {
        _advance();
      } else if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier) ||
            _check(TokenType.stringLiteral)) {
          _advance();
        } else {
          _expect(TokenType.identifier);
        }
      } else {
        break;
      }
    }
    final contained = <String>[];
    if (_check(TokenType.leftBrace)) {
      _advance();
      _skipNewlines();
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_isKeyword('usecase')) {
          final node = _parseUseCaseNode(UseCaseNodeKind.useCase);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('actor')) {
          final node = _parseUseCaseNode(UseCaseNodeKind.actor);
          addNode(node);
          contained.add(node.alias);
        } else if (_isKeyword('package') || _isKeyword('rectangle')) {
          // Nested package/rectangle: recurse and absorb its participants into
          // this outer container's contained list (flat membership).
          final inner = _parseRectangleBoundary(addNode,
              relations: relations,
              noteAliases: noteAliases,
              noteConnections: noteConnections);
          contained.addAll(inner.containedAliases);
        } else if (relations != null &&
            (_check(TokenType.leftParen) ||
                _check(TokenType.colon) ||
                _check(TokenType.identifier) ||
                _check(TokenType.stringLiteral))) {
          // Relations nested inside a rectangle (e.g. `customer -- (checkout)`
          // or `(help) .> (checkout) : extends`). These don't add membership
          // entries themselves, but the endpoints may implicitly declare nodes
          // that should still resolve cleanly against the surrounding diagram.
          _parseUseCaseRelation(relations, addNode,
              noteAliases: noteAliases,
              noteConnections: noteConnections);
        } else {
          final t = _peek();
          throw ParserException(
              "Only 'usecase' or 'actor' declarations are allowed inside a rectangle, got '${t.lexeme}'",
              t.line,
              t.column);
        }
        _skipNewlines();
      }
      if (!_check(TokenType.rightBrace)) {
        throw ParserException("Expected '}' to close rectangle", rectToken.line,
            rectToken.column);
      }
      _advance();
    }
    return UseCaseBoundary(
      label: label,
      containedAliases: List.unmodifiable(contained),
    );
  }

  void _parseUseCaseRelation(
      List<UseCaseRelation> out, void Function(UseCaseNode) addNode,
      {String? leadingAlias,
      _UseCaseEnd? leadingEnd,
      Set<String>? noteAliases,
      List<UseCaseNoteConnection>? noteConnections}) {
    // Recovery: if we entered without a leading endpoint but the current
    // token is already an arrow (e.g. PlantUML's `() name )-arrow- target`
    // form where the `()` interface shorthand was consumed as a node
    // declaration on the previous outer-loop iteration), swallow the line
    // as a no-op so parsing can continue.
    if (leadingEnd == null &&
        leadingAlias == null &&
        (_check(TokenType.arrow) || _check(TokenType.minusMinus))) {
      while (!_check(TokenType.newline) &&
          !_check(TokenType.endUml) &&
          !_check(TokenType.eof)) {
        _advance();
      }
      return;
    }
    final _UseCaseEnd fromEnd;
    if (leadingEnd != null) {
      fromEnd = leadingEnd;
    } else if (leadingAlias != null) {
      fromEnd = _UseCaseEnd(alias: leadingAlias, declaredKind: null);
    } else {
      fromEnd = _readUseCaseRelationEnd();
    }
    if (!_check(TokenType.arrow) && !_check(TokenType.minusMinus)) {
      // PlantUML accepts esoteric chained-arrow forms with intermediate
      // identifiers/strings between the source endpoint and the actual
      // arrow (e.g. `() component3 )-0-(0 "foo" [componentC]`). Skip over
      // intermediate non-arrow tokens up to a newline boundary until we
      // find an arrow; if none is found on this line, swallow the rest
      // of the line as a no-op recovery.
      while (!_check(TokenType.arrow) &&
          !_check(TokenType.minusMinus) &&
          !_check(TokenType.newline) &&
          !_check(TokenType.endUml) &&
          !_check(TokenType.eof)) {
        _advance();
      }
      if (!_check(TokenType.arrow) && !_check(TokenType.minusMinus)) {
        // No arrow found on this line — accept the leading endpoint as a
        // standalone node declaration so parsing can continue.
        addNode(UseCaseNode(
          alias: fromEnd.alias,
          label: fromEnd.label ?? fromEnd.alias,
          kind: fromEnd.declaredKind ?? UseCaseNodeKind.actor,
        ));
        return;
      }
    }
    final arrowToken = _advance();
    final toEnd = _readUseCaseRelationEnd();
    // Optional PlantUML inline-style suffix on the relation:
    // `--> (bar) #color;line:red;line.bold;text:red : label`.
    // The lexer absorbs the full run into a single hashColor token. Split it
    // on `;` and apply each clause to the relation so the line color, line
    // style (bold/dashed/dotted), and label text color reach the renderer.
    Color? inlineLineColor;
    Color? inlineTextColor;
    UseCaseLineStyle? inlineLineStyle;
    if (_check(TokenType.hashColor)) {
      final tok = _advance();
      final parsed = _parseUseCaseInlineStyle(tok.lexeme);
      inlineLineColor = parsed.lineColor;
      inlineTextColor = parsed.textColor;
      inlineLineStyle = parsed.lineStyle;
    }
    String? label;
    if (_check(TokenType.colon)) {
      _advance();
      if (_check(TokenType.text)) {
        // Relation labels follow PlantUML's `\n` -> newline convention so
        // multi-line edge captions like `This is\nyet another\nlabel`
        // render across multiple lines.
        label = _advance().lexeme.replaceAll(r'\n', '\n');
      }
    }
    final decoded = _decodeUseCaseArrow(arrowToken);
    final resolvedFromEnd =
        decoded.direction == MessageDirection.backward ? toEnd : fromEnd;
    final resolvedToEnd =
        decoded.direction == MessageDirection.backward ? fromEnd : toEnd;

    // A relation that touches a free-standing note alias is rendered as a
    // dotted connector line rather than a node-to-node relation. Routing it
    // to [noteConnections] also keeps the endpoint from being auto-classified
    // as an actor or use case.
    final fromIsNote =
        noteAliases != null && noteAliases.contains(resolvedFromEnd.alias);
    final toIsNote =
        noteAliases != null && noteAliases.contains(resolvedToEnd.alias);
    if (fromIsNote || toIsNote) {
      if (!fromIsNote) {
        addNode(UseCaseNode(
          alias: resolvedFromEnd.alias,
          label: resolvedFromEnd.label ?? resolvedFromEnd.alias,
          kind: resolvedFromEnd.declaredKind ?? UseCaseNodeKind.useCase,
        ));
      }
      if (!toIsNote) {
        addNode(UseCaseNode(
          alias: resolvedToEnd.alias,
          label: resolvedToEnd.label ?? resolvedToEnd.alias,
          kind: resolvedToEnd.declaredKind ?? UseCaseNodeKind.useCase,
        ));
      }
      noteConnections!.add(UseCaseNoteConnection(
        from: resolvedFromEnd.alias,
        to: resolvedToEnd.alias,
      ));
      return;
    }

    addNode(UseCaseNode(
      alias: resolvedFromEnd.alias,
      label: resolvedFromEnd.label ?? resolvedFromEnd.alias,
      kind: resolvedFromEnd.declaredKind ?? UseCaseNodeKind.actor,
    ));
    addNode(UseCaseNode(
      alias: resolvedToEnd.alias,
      label: resolvedToEnd.label ?? resolvedToEnd.alias,
      kind: resolvedToEnd.declaredKind ?? UseCaseNodeKind.useCase,
    ));
    final relFrom =
        decoded.reverse ? resolvedToEnd.alias : resolvedFromEnd.alias;
    final relTo =
        decoded.reverse ? resolvedFromEnd.alias : resolvedToEnd.alias;
    out.add(UseCaseRelation(
      from: relFrom,
      to: relTo,
      lineStyle: decoded.lineStyle,
      head: decoded.head,
      direction: MessageDirection.forward,
      label: label,
      lineColor: inlineLineColor,
      inlineLineStyle: inlineLineStyle,
      textColor: inlineTextColor,
    ));
    // Chained relations on a single line: `A --> B --> C` becomes
    // `A --> B` plus `B --> C`. Continue parsing from the toEnd as the new
    // fromEnd while the same logical line still carries an arrow.
    if (_check(TokenType.arrow) || _check(TokenType.minusMinus)) {
      _parseUseCaseRelation(out, addNode,
          leadingEnd: toEnd,
          noteAliases: noteAliases,
          noteConnections: noteConnections);
    }
  }

  /// Splits a PlantUML inline-style lexeme such as
  /// `#line:red;line.bold;text:red` or `#green;line.dashed;text:green` into
  /// the constituent line color, line style, and text color. Returns nulls
  /// for any clause that is absent or unrecognized.
  _UseCaseInlineStyle _parseUseCaseInlineStyle(String lexeme) {
    final body = lexeme.startsWith('#') ? lexeme.substring(1) : lexeme;
    Color? lineColor;
    Color? textColor;
    UseCaseLineStyle? lineStyle;
    final segments = body.split(';');
    for (var idx = 0; idx < segments.length; idx++) {
      final seg = segments[idx].trim();
      if (seg.isEmpty) continue;
      // `text:<color>` — label color.
      if (seg.startsWith('text:')) {
        textColor = text_colors.tryParseColor(seg.substring(5)) ?? textColor;
        continue;
      }
      // `line.bold|dashed|dotted` — line pattern.
      if (seg.startsWith('line.')) {
        switch (seg.substring(5)) {
          case 'bold':
            lineStyle = UseCaseLineStyle.bold;
            break;
          case 'dashed':
            lineStyle = UseCaseLineStyle.dashed;
            break;
          case 'dotted':
            lineStyle = UseCaseLineStyle.dotted;
            break;
        }
        continue;
      }
      // `line:<color>` — explicit line color.
      if (seg.startsWith('line:')) {
        lineColor = text_colors.tryParseColor(seg.substring(5)) ?? lineColor;
        continue;
      }
      // Bare `<color>` or `#<color>` — only the first segment is treated as a
      // head color. PlantUML uses this as the line color when no `line:`
      // clause is given.
      if (idx == 0) {
        final headSpec = seg.startsWith('#') ? seg : '#$seg';
        final parsed = text_colors.tryParseColor(headSpec);
        if (parsed != null) {
          lineColor ??= parsed;
        }
      }
    }
    return _UseCaseInlineStyle(
      lineColor: lineColor,
      textColor: textColor,
      lineStyle: lineStyle,
    );
  }

  /// Reads a single endpoint of a use-case relation. Accepts:
  /// - `Name` / `"Display"` — bare identifier, auto-classified by caller
  ///   (left side defaults to actor, right side defaults to use case).
  /// - `:Display Name:` — colon-wrapped actor declaration.
  /// - `(Name with spaces)` — parenthesized use-case ellipse.
  _UseCaseEnd _readUseCaseRelationEnd() {
    if (_check(TokenType.colon)) {
      // Two tokenizations are possible (see `_parseUseCaseDiagram`):
      //   - `:Display Name:`               -> colon, text("Display Name"), colon
      //   - `:Display Name: as Alias`      -> colon, text("Display Name: as Alias")
      // Both forms declare an actor on this end of the relation.
      final String displayName;
      if (_pos + 2 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.text &&
          _tokens[_pos + 2].type == TokenType.colon) {
        _advance();
        final textTok = _advance();
        _advance();
        displayName = textTok.lexeme.replaceAll(r'\n', '\n');
        final alias = _deriveAliasFromDisplayName(displayName);
        return _UseCaseEnd(
          alias: alias,
          label: displayName,
          declaredKind: UseCaseNodeKind.actor,
        );
      }
      final decl = _consumeColonWrappedDisplayName();
      final alias = decl.alias ?? _deriveAliasFromDisplayName(decl.displayName);
      return _UseCaseEnd(
        alias: alias,
        label: decl.displayName,
        declaredKind: UseCaseNodeKind.actor,
      );
    }
    if (_check(TokenType.leftParen)) {
      final alias = _consumeUseCaseEllipseName();
      return _UseCaseEnd(
        alias: alias,
        label: alias,
        declaredKind: UseCaseNodeKind.useCase,
      );
    }
    // `[name]` — bracketed component reference appearing in a use-case
    // relation context. Accept as a generic endpoint.
    if (_check(TokenType.leftBracket)) {
      _advance();
      final buf = StringBuffer();
      while (!_check(TokenType.rightBracket) &&
          !_check(TokenType.newline) &&
          !_check(TokenType.endUml) &&
          !_check(TokenType.eof)) {
        buf.write(_advance().lexeme);
      }
      if (_check(TokenType.rightBracket)) {
        _advance();
      }
      final alias = buf.toString().trim();
      return _UseCaseEnd(
        alias: alias,
        label: alias,
        declaredKind: null,
      );
    }
    if (_check(TokenType.identifier) || _check(TokenType.stringLiteral)) {
      final tok = _advance();
      final rawLex = tok.lexeme;
      // Quoted endpoint may carry a trailing `as <alias>` (PlantUML uses
      // this to give a display label its own identifier). Consume it so the
      // alias becomes the relation endpoint and the lexeme stays as the
      // display label.
      if (tok.type == TokenType.stringLiteral &&
          _check(TokenType.identifier) &&
          _peek().lexeme == 'as' &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier) {
        _advance();
        final aliasTok = _advance();
        return _UseCaseEnd(
          alias: aliasTok.lexeme,
          label: rawLex,
          declaredKind: null,
        );
      }
      // Identifier endpoint `Name(arg)` — accept a parenthesized call-style
      // suffix as part of the alias. Lets sources that use macro/procedure
      // call syntax as a node reference (e.g. activity-style `SALT(choose)`
      // routed through use-case dispatch) parse without error.
      //
      // When the call shape is a single bare identifier argument (e.g.
      // `SALT(choose)`), use the inner argument as the node alias *and*
      // display label. PlantUML's `!unquoted procedure SALT($x)` macro
      // expands to `"..." as $x`, so subsequent references to the bare
      // argument (e.g. `wait -right-> SALT(success)`) must resolve to the
      // same node. Falling back to the literal `SALT(choose)` lexeme would
      // split each call into its own disconnected node.
      if (tok.type == TokenType.identifier && _check(TokenType.leftParen)) {
        _advance();
        final argTokens = <Token>[];
        while (!_check(TokenType.rightParen) &&
            !_check(TokenType.newline) &&
            !_check(TokenType.endUml) &&
            !_check(TokenType.eof)) {
          argTokens.add(_advance());
        }
        if (_check(TokenType.rightParen)) {
          _advance();
        }
        if (argTokens.length == 1 &&
            (argTokens.first.type == TokenType.identifier ||
                argTokens.first.type == TokenType.text)) {
          final argName = argTokens.first.lexeme.trim();
          if (argName.isNotEmpty &&
              argName != '*' &&
              RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(argName)) {
            return _UseCaseEnd(
              alias: argName,
              label: argName,
              declaredKind: null,
            );
          }
        }
        final buf = StringBuffer(rawLex)..write('(');
        for (final t in argTokens) {
          buf.write(t.lexeme);
        }
        buf.write(')');
        return _UseCaseEnd(alias: buf.toString(), declaredKind: null);
      }
      return _UseCaseEnd(alias: rawLex, declaredKind: null);
    }
    final t = _peek();
    throw ParserException(
        'Expected use case or actor name, got ${t.type}', t.line, t.column);
  }

  /// Consumes `(Name with spaces)` and returns the inner name. The lexer
  /// already tokenizes the inside as a single `text` token (or omits it for
  /// `()`); we just stitch the pieces together.
  String _consumeUseCaseEllipseName() {
    _expect(TokenType.leftParen);
    String name = '';
    if (_check(TokenType.text)) {
      name = _advance().lexeme;
    } else if (_check(TokenType.identifier)) {
      // Defensive: if the lexer emitted an identifier instead of text inside
      // the parens, accept that too.
      name = _advance().lexeme;
    }
    _expect(TokenType.rightParen);
    // Convert escaped newlines (`\n`) to literal newlines so multi-line
    // ellipse labels render as multiple lines, mirroring the convention
    // used for colon-wrapped names, note bodies, and quoted labels.
    return name.replaceAll(r'\n', '\n');
  }

  _UseCaseArrow _decodeUseCaseArrow(Token token) {
    final lexeme = token.lexeme;
    final dashed = lexeme.contains('.');
    final hasLeftTriangle = lexeme.startsWith('<|');
    final hasRightTriangle = lexeme.endsWith('|>');
    final hasRightArrow = lexeme.endsWith('>') && !hasRightTriangle;
    final hasLeftArrow = lexeme.startsWith('<') && !hasLeftTriangle;
    if (hasLeftTriangle) {
      return _UseCaseArrow(
        dashed ? LineStyle.dashed : LineStyle.solid,
        ArrowHead.triangle,
        MessageDirection.forward,
        reverse: true,
      );
    }
    if (hasRightTriangle) {
      return _UseCaseArrow(
        dashed ? LineStyle.dashed : LineStyle.solid,
        ArrowHead.triangle,
        MessageDirection.forward,
      );
    }
    if (lexeme == '--' || lexeme == '..') {
      return _UseCaseArrow(
        dashed ? LineStyle.dashed : LineStyle.solid,
        null,
        MessageDirection.forward,
      );
    }
    if (hasLeftArrow) {
      return _UseCaseArrow(
        dashed ? LineStyle.dashed : LineStyle.solid,
        ArrowHead.open,
        MessageDirection.backward,
      );
    }
    if (hasRightArrow) {
      return _UseCaseArrow(
        dashed ? LineStyle.dashed : LineStyle.solid,
        ArrowHead.open,
        MessageDirection.forward,
      );
    }
    return _UseCaseArrow(
      dashed ? LineStyle.dashed : LineStyle.solid,
      null,
      MessageDirection.forward,
    );
  }

  bool _looksLikeTimingDiagram() {
    const laneKeywords = {
      'robust',
      'concise',
      'clock',
      'binary',
      'analog',
      // `rectangle` is NOT included here — it's ambiguous with use-case
      // diagram boundaries (`rectangle "Name" { ... }`). It is still parsed
      // as a timing lane when the source has already been routed to the
      // timing parser by another lane keyword.
    };
    var atLineStart = true;
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.endUml || t.type == TokenType.eof) break;
      if (t.type == TokenType.newline) {
        atLineStart = true;
        continue;
      }
      if (atLineStart && t.type == TokenType.atTime) {
        return true;
      }
      if (atLineStart &&
          t.type == TokenType.identifier &&
          laneKeywords.contains(t.lexeme)) {
        return true;
      }
      // `mode compact` is a timing-diagram directive that can appear before
      // any lane declarations.
      if (atLineStart &&
          t.type == TokenType.identifier &&
          t.lexeme == 'mode' &&
          k + 1 < _tokens.length &&
          _tokens[k + 1].type == TokenType.identifier &&
          (_tokens[k + 1].lexeme == 'compact' ||
              _tokens[k + 1].lexeme == 'tabular')) {
        return true;
      }
      atLineStart = false;
    }
    return false;
  }

  // Timing-diagram keywords whose lines are consumed-and-ignored at the
  // top level (visual support deferred). The form is generally
  // `<keyword> ...rest-of-line` and we tolerate any tokens up to the
  // next newline/end-of-input.
  static const _timingIgnoredLineKeywords = {
    'highlight',
    'hide',
    'scale',
    'manual',
    'use',
    'mode',
    // `note top of X : ...` / `note bottom of X : ...` / `note left/right of`.
    // The colon scanner already swallows the trailing message, so consuming
    // the remaining tokens of the line is sufficient.
    'note',
  };

  // Decoration-style keywords whose case-variants (e.g. `Title` vs `title`)
  // we tolerate inside `_parseTimingDiagram`. Lowercase forms are already
  // handled by `_tryParseDecoration`; this set lets us consume-and-ignore
  // the line when the source capitalizes the keyword. Visual rendering of
  // these directives inside timing diagrams is deferred.
  static const _timingCaseInsensitiveDecorationKeywords = {
    'title',
    'header',
    'footer',
    'caption',
    'legend',
  };

  TimingDiagram _parseTimingDiagram() {
    final lanes = <TimingLane>[];
    final events = <TimingEvent>[];
    var currentTime = 0;
    String? laneFocus;
    while (!_check(TokenType.endUml) && !_check(TokenType.eof)) {
      _skipNewlines();
      if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
      if (_tryParseDecoration()) {
        _skipNewlines();
        continue;
      }
      // Tolerate case-variant decoration keywords inside timing diagrams
      // (e.g. `Title ...`, `Header ...`). The strict `_tryParseDecoration`
      // path is lowercase-only; sources from the regression set occasionally
      // capitalize the keyword. Consume-and-ignore the rest of the line so
      // the timing parser stays robust. Visual rendering deferred.
      if (_check(TokenType.identifier) &&
          _timingCaseInsensitiveDecorationKeywords
              .contains(_peek().lexeme.toLowerCase())) {
        final kw = _peek().lexeme.toLowerCase();
        _consumeRestOfLine();
        // `legend` and `title` (block form) extend until `end <kw>`.
        if (kw == 'legend' || kw == 'title') {
          while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
            _skipNewlines();
            if (_check(TokenType.identifier) &&
                _peek().lexeme.toLowerCase() == 'end' &&
                _pos + 1 < _tokens.length &&
                _tokens[_pos + 1].type == TokenType.identifier &&
                _tokens[_pos + 1].lexeme.toLowerCase() == kw) {
              _advance();
              _advance();
              break;
            }
            if (_check(TokenType.endUml) || _check(TokenType.eof)) break;
            _consumeRestOfLine();
          }
        }
        _skipNewlines();
        continue;
      }
      // Optional `compact` modifier prefix on a lane declaration:
      // `compact robust "..." as X`. Consume-and-ignore the modifier so the
      // lane keyword that follows is parsed normally. Visual stacking is
      // deferred.
      if (_isKeyword('compact') &&
          _pos + 1 < _tokens.length &&
          _tokens[_pos + 1].type == TokenType.identifier &&
          const {'robust', 'concise', 'clock', 'binary', 'analog', 'rectangle'}
              .contains(_tokens[_pos + 1].lexeme)) {
        _advance();
      }
      if (_isKeyword('robust')) {
        lanes.add(_parseTimingLane(TimingLaneKind.robust));
      } else if (_isKeyword('concise')) {
        lanes.add(_parseTimingLane(TimingLaneKind.concise));
      } else if (_isKeyword('clock')) {
        lanes.add(_parseTimingLane(TimingLaneKind.clock));
      } else if (_isKeyword('binary')) {
        lanes.add(_parseTimingLane(TimingLaneKind.binary));
      } else if (_isKeyword('analog')) {
        lanes.add(_parseTimingLane(TimingLaneKind.analog));
      } else if (_isKeyword('rectangle')) {
        lanes.add(_parseTimingLane(TimingLaneKind.rectangle));
      } else if (_check(TokenType.identifier) &&
          _timingIgnoredLineKeywords.contains(_peek().lexeme)) {
        _consumeRestOfLine();
      } else if (_check(TokenType.atTime)) {
        final raw = _advance().lexeme;
        final parsed = int.tryParse(raw);
        final parsedDouble = parsed == null ? double.tryParse(raw) : null;
        if (parsed != null) {
          currentTime = parsed;
          laneFocus = null;
        } else if (parsedDouble != null) {
          currentTime = parsedDouble.toInt();
          laneFocus = null;
        } else if (raw.startsWith(':') ||
            raw.startsWith('-') ||
            raw.startsWith('+') ||
            _isAnchorArithmetic(raw)) {
          // Labeled / arithmetic / relative anchor. Best-effort: extract the
          // leading integer if any; otherwise hold the previous time. The
          // anchor name (without `:`) is tracked so subsequent `+N`/`-N`
          // lines can resolve. Visual rendering deferred.
          currentTime = _approxTimeFromAnchor(raw, currentTime);
          laneFocus = null;
        } else {
          // `@<laneName>` selects a lane as the focus for following
          // relative-time statements (e.g. `@WB\n0 is idle\n+200 is Proc.`).
          laneFocus = raw;
          currentTime = 0;
        }
        // Optional `as :label` suffix that names this anchor for later
        // reference (e.g. `@0 as :start`). Consume the rest of the line so
        // the loop's `_skipNewlines` advances past the trailing alias.
        if (_isKeyword('as')) {
          _consumeRestOfLine();
        }
        // Annotation arrow with no source lane prefix:
        // `@200 <-> @+150 : {150 ms}`. After the `@N` anchor is consumed
        // the rest of the line is an annotation between time-anchors. We
        // consume-and-ignore it; visual rendering deferred.
        if (_check(TokenType.arrow)) {
          _consumeRestOfLine();
        }
      } else {
        _parseTimingStatement(events, currentTime, laneFocus);
      }
      _skipNewlines();
    }
    _expect(TokenType.endUml);
    return TimingDiagram(
      lanes: List.unmodifiable(lanes),
      events: List.unmodifiable(events),
      decorations: _decorations.build(),
    );
  }

  static bool _isAnchorArithmetic(String raw) {
    return raw.contains('+') || raw.contains('-') ||
        raw.contains(':') || raw.contains('/') ||
        raw.contains('.') || raw.contains('*');
  }

  static int _approxTimeFromAnchor(String raw, int fallback) {
    final m = RegExp(r'^-?\d+(?:\.\d+)?').firstMatch(raw);
    if (m != null) {
      final s = m.group(0)!;
      final asInt = int.tryParse(s);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(s);
      if (asDouble != null) return asDouble.toInt();
    }
    return fallback;
  }

  TimingLane _parseTimingLane(TimingLaneKind kind) {
    final keywordToken = _advance();
    String label;
    String alias;
    if (_check(TokenType.stringLiteral)) {
      label = _advance().lexeme;
      // Optional `between A and B` clause for analog lanes — the values bound
      // the y-axis range. Consume-and-ignore for parser robustness; visual
      // axis scaling is deferred.
      _consumeOptionalAnalogBetween();
      if (_isKeyword('as')) {
        _advance();
        if (!_check(TokenType.identifier)) {
          final t = _peek();
          throw ParserException("Expected alias after 'as'", t.line, t.column);
        }
        alias = _advance().lexeme;
      } else {
        alias = label;
      }
    } else if (_check(TokenType.identifier)) {
      alias = _advance().lexeme;
      label = alias;
      _consumeOptionalAnalogBetween();
      if (_isKeyword('as')) {
        _advance();
        if (!_check(TokenType.identifier)) {
          final t = _peek();
          throw ParserException("Expected alias after 'as'", t.line, t.column);
        }
        alias = _advance().lexeme;
      }
    } else {
      throw ParserException(
          "Expected lane label after '${keywordToken.lexeme}'",
          keywordToken.line,
          keywordToken.column);
    }
    // Optional `<<stereotype>>` after the alias (e.g.
    // `binary "X" as IS2 <<blue>>`). The stereotype is a style-class reference
    // resolved by the `<style>` block; we consume-and-ignore for parser
    // robustness — visual styling is deferred.
    while (_check(TokenType.stereotype)) {
      _advance();
    }
    int? clockPeriod;
    if (kind == TimingLaneKind.clock && _isKeyword('with')) {
      _advance();
      if (!_isKeyword('period')) {
        final t = _peek();
        throw ParserException(
            "Expected 'period' after 'with'", t.line, t.column);
      }
      _advance();
      if (!_check(TokenType.identifier)) {
        final t = _peek();
        throw ParserException("Expected integer period", t.line, t.column);
      }
      final periodToken = _advance();
      clockPeriod = int.tryParse(periodToken.lexeme);
      if (clockPeriod == null) {
        throw ParserException(
            "Expected integer period, got '${periodToken.lexeme}'",
            periodToken.line,
            periodToken.column);
      }
      // Optional `pulse N` and/or `offset M` modifiers. Consume-and-ignore for
      // visual fidelity (rendering-side support deferred).
      while (_isKeyword('pulse') || _isKeyword('offset')) {
        _advance();
        if (_check(TokenType.identifier)) {
          _advance();
        }
      }
    }
    return TimingLane(
      alias: alias,
      label: label,
      kind: kind,
      clockPeriod: clockPeriod,
    );
  }

  void _parseTimingStatement(
      List<TimingEvent> out, int currentTime, String? laneFocus) {
    if (!_check(TokenType.identifier) && !_check(TokenType.stringLiteral)) {
      final t = _peek();
      throw ParserException(
          "Unexpected token '${t.lexeme}' in timing diagram", t.line, t.column);
    }
    final firstToken = _advance();
    final first = firstToken.lexeme;

    // Relative-time anchor at line start (e.g. `0 is idle`, `+200 is Proc.`,
    // `-100 is x`). Treated as a time directive followed by a lane-state
    // change. The "lane" is the most recent `@<lane>` focus.
    if (_isRelativeTimeAnchor(first)) {
      if (_isKeyword('is')) {
        _advance();
        final state = _readTimingStateValue();
        if (laneFocus != null) {
          out.add(StateChange(
            time: _approxTimeFromAnchor(first, currentTime),
            lane: laneFocus,
            state: state,
          ));
        }
        return;
      }
      // Bare numeric line without `is` is tolerated.
      _consumeRestOfLine();
      return;
    }

    if (_isKeyword('is')) {
      _advance();
      final state = _readTimingStateValue();
      // Tolerate trailing lane-modifier tokens (e.g. `VCC is 200 pixels height`)
      // by consuming the remainder of the line. The state name is captured;
      // the layout hint is deferred.
      _consumeRestOfLine();
      out.add(StateChange(time: currentTime, lane: first, state: state));
      return;
    }
    // `<lane> has v1,v2,...` declares the enumerated state values for a lane.
    // Consume-and-ignore for parser robustness (visual rendering deferred).
    if (_isKeyword('has')) {
      _advance();
      // Consume `value (, value)*` until newline/end-of-input.
      while (!_check(TokenType.newline) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        _advance();
      }
      return;
    }
    // `<lane> ticks num on multiple N` — analog axis tick decoration. Consume
    // the rest of the line. Visual rendering deferred.
    if (_isKeyword('ticks')) {
      _consumeRestOfLine();
      return;
    }
    // `<lane>@<time>` prefix on a cross-lane arrow / annotation
    // (e.g. `db@:write_beg-1 <-> @:write_end : setup time`,
    // `db@:write_beg-1 -> addr@:write_end+1 : hold`). For parser robustness
    // we consume the rest of the line — visual annotations are deferred.
    if (_check(TokenType.atTime)) {
      _consumeRestOfLine();
      return;
    }
    if (_check(TokenType.arrow)) {
      _advance();
      // Tolerate an optional target time-anchor before the lane identifier
      // (e.g. `<-> @:write_end`).
      if (_check(TokenType.atTime)) {
        _consumeRestOfLine();
        return;
      }
      if (!_check(TokenType.identifier) && !_check(TokenType.stringLiteral)) {
        final t = _peek();
        throw ParserException(
            "Expected target lane after arrow", t.line, t.column);
      }
      final to = _advance().lexeme;
      // Skip optional `@<time>` after the target lane.
      if (_check(TokenType.atTime)) {
        _advance();
      }
      String? label;
      if (_check(TokenType.colon)) {
        _advance();
        if (_check(TokenType.text)) {
          label = _advance().lexeme;
        }
      }
      out.add(TimingArrow(
        time: currentTime,
        from: first,
        to: to,
        label: label,
      ));
      return;
    }
    throw ParserException("Expected 'is' or arrow after '${firstToken.lexeme}'",
        firstToken.line, firstToken.column);
  }

  // Reads a state value after `is`. Supports plain identifiers/strings,
  // multi-value `{a,b}` lists, and the special `{hidden}` marker. Trailing
  // colon-delimited notes (`is Waiting : some note`) are absorbed by the
  // colon lexer as a text token, which is also accepted here.
  String _readTimingStateValue() {
    if (_check(TokenType.leftBrace)) {
      _advance();
      final buf = StringBuffer('{');
      var first = true;
      while (!_check(TokenType.rightBrace) &&
          !_check(TokenType.newline) &&
          !_check(TokenType.eof) &&
          !_check(TokenType.endUml)) {
        if (_check(TokenType.comma)) {
          buf.write(',');
          _advance();
          first = true;
          continue;
        }
        if (!first) buf.write(' ');
        buf.write(_advance().lexeme);
        first = false;
      }
      if (_check(TokenType.rightBrace)) _advance();
      buf.write('}');
      // Optional `#color` highlight after a multi-value state.
      if (_check(TokenType.hashColor)) _advance();
      // Absorb trailing `: note text` if present.
      if (_check(TokenType.colon)) {
        _advance();
        if (_check(TokenType.text)) _advance();
      }
      // `{-}` shorthand is equivalent to the `{hidden}` marker.
      final raw = buf.toString();
      if (raw == '{-}') return '{hidden}';
      return raw;
    }
    if (_check(TokenType.stringLiteral) || _check(TokenType.identifier)) {
      final state = _advance().lexeme;
      // Optional `#color` highlight after the state name.
      if (_check(TokenType.hashColor)) _advance();
      if (_check(TokenType.colon)) {
        _advance();
        if (_check(TokenType.text)) _advance();
      }
      return state;
    }
    if (_check(TokenType.text)) {
      return _advance().lexeme;
    }
    final t = _peek();
    throw ParserException(
        "Expected state name after 'is'", t.line, t.column);
  }

  static bool _isRelativeTimeAnchor(String s) {
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(0);
    if (c == 0x2B || c == 0x2D) {
      // `+` / `-` followed by digits.
      return s.length > 1 &&
          s.codeUnits.skip(1).every((u) => u >= 0x30 && u <= 0x39);
    }
    // Bare digits (possibly with trailing dot — but `0` etc.).
    return s.codeUnits.every((u) => u >= 0x30 && u <= 0x39);
  }

  MindmapDiagram _parseMindmapDiagram() {
    final root = _parseIndentedTree(
      endType: TokenType.endMindmap,
      diagramName: 'mindmap',
    );
    return MindmapDiagram(root: root, decorations: _decorations.build());
  }

  WbsDiagram _parseWbsDiagram() {
    final root = _parseIndentedTree(
      endType: TokenType.endWbs,
      diagramName: 'wbs',
    );
    return WbsDiagram(root: root, decorations: _decorations.build());
  }

  MindmapNode? _parseIndentedTree({
    required TokenType endType,
    required String diagramName,
  }) {
    final lines = <_MindmapLine>[];
    // Tracks whether we are inside a PlantUML `<style> ... </style>` block
    // that the WBS-body lexer captured as raw text lines (style blocks
    // appearing inside indented-tree bodies are not consumed by the global
    // `<style>` block handler — we consume-and-ignore them here so the
    // surrounding diagram still parses without error).
    var inStyleBlock = false;
    while (!_check(endType) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected $diagramName line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      final lower = t.lexeme.trim().toLowerCase();
      if (inStyleBlock) {
        if (lower.contains('</style>')) {
          inStyleBlock = false;
        }
        _skipNewlines();
        continue;
      }
      if (lower.startsWith('<style>')) {
        // Single-line `<style>...</style>` or multi-line opening tag.
        if (!lower.contains('</style>')) {
          inStyleBlock = true;
        }
        _skipNewlines();
        continue;
      }
      // PlantUML mindmap/wbs layout directives: `left to right direction`,
      // `right to left direction`, `top to bottom direction`,
      // `bottom to top direction`, each optionally followed by a
      // `left side` / `right side` positioning qualifier. Standalone
      // `left side` / `right side` directives (used between nodes to
      // assign sides for subsequent `**:..;` bodies) are also accepted.
      // All are consumed-and-ignored — visual layout is deferred.
      if (_isMindmapDirectionOrSideDirective(lower)) {
        _skipNewlines();
        continue;
      }
      // Cross-edges between aliased nodes (e.g. `t2 -> c1 <<foo>>` or
      // `t2 ..> c2 #blue`). PlantUML allows these as additional relations
      // inside WBS/mindmap bodies. We currently consume-and-ignore them.
      if (_isIndentedTreeEdgeLine(t.lexeme)) {
        _skipNewlines();
        continue;
      }
      final parsed = _parseMindmapLine(t.lexeme, t.line, t.column);
      if (parsed != null) {
        lines.add(parsed);
      }
      _skipNewlines();
    }
    if (_check(endType)) {
      _advance();
    }
    return _buildMindmapTree(lines, diagramName: diagramName);
  }

  /// Returns true when [raw] looks like an inter-node edge line of the form
  /// `id -> id`, `id ..> id`, `id --> id` etc. used inside WBS bodies to
  /// connect aliased nodes. The check is intentionally lenient: any line
  /// that does not start with a `+`, `-`, or `*` marker but does contain
  /// an arrow-like token is treated as a relation.
  bool _isIndentedTreeEdgeLine(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    final first = s[0];
    if (first == '+' || first == '-' || first == '*') return false;
    // Look for an arrow-shape: `->`, `..>`, `-->`, `<-`, `<..`, etc.
    return s.contains('->') ||
        s.contains('<-') ||
        s.contains('..>') ||
        s.contains('<..');
  }

  /// Returns true when [lowerTrimmed] (already lower-cased and trimmed) is a
  /// PlantUML mindmap/wbs layout directive line that should be consumed and
  /// ignored at the parser level. Accepts the four canonical direction
  /// directives (`left to right direction`, `right to left direction`,
  /// `top to bottom direction`, `bottom to top direction`), each optionally
  /// followed by a `left side` / `right side` positioning qualifier; plus
  /// standalone `left side` / `right side` lines (used to assign the side
  /// for subsequent `**:..;` body nodes).
  bool _isMindmapDirectionOrSideDirective(String lowerTrimmed) {
    if (lowerTrimmed.isEmpty) return false;
    if (lowerTrimmed == 'left side' || lowerTrimmed == 'right side') {
      return true;
    }
    const directions = [
      'left to right direction',
      'right to left direction',
      'top to bottom direction',
      'bottom to top direction',
    ];
    for (final d in directions) {
      if (lowerTrimmed == d) return true;
      if (lowerTrimmed == '$d left side') return true;
      if (lowerTrimmed == '$d right side') return true;
    }
    return false;
  }

  _MindmapLine? _parseMindmapLine(String raw, int line, int col) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    MindmapSide side = MindmapSide.auto;
    // WBS-style markers: lines whose leading run consists entirely of `+`
    // and/or `-` characters (e.g. `+`, `++`, `+++`, `++-`, `----`). Depth is
    // the total count of `+`/`-` characters; a trailing `-` (or all-`-` run)
    // flips the node to the left side, mirroring PlantUML WBS semantics. A
    // single trailing `_` after the run (e.g. `+_`, `++_`, `-_`) marks the
    // node as boxless — we currently consume-and-ignore the boxless flag
    // (visual rendering deferred).
    if (s.startsWith('+') || s.startsWith('-')) {
      var markerEnd = 0;
      while (markerEnd < s.length &&
          (s[markerEnd] == '+' || s[markerEnd] == '-')) {
        markerEnd++;
      }
      // Optional `_` boxless suffix immediately after the `+`/`-` run.
      var afterEnd = markerEnd;
      if (afterEnd < s.length && s[afterEnd] == '_') {
        afterEnd++;
      }
      // A WBS marker is followed by whitespace, `[`, `:`, or end-of-line;
      // otherwise fall through to the legacy mindmap parsing (which treats
      // `+`/`-` as a side prefix before a `*` depth run).
      final afterMarker =
          afterEnd >= s.length ? '' : s.substring(afterEnd, afterEnd + 1);
      final isWbsMarker = markerEnd >= 1 &&
          (afterEnd == s.length ||
              afterMarker == ' ' ||
              afterMarker == '\t' ||
              afterMarker == '[' ||
              afterMarker == ':');
      if (isWbsMarker) {
        final marker = s.substring(0, markerEnd);
        final depth = markerEnd;
        // Trailing `-` (e.g. `++-`) or all-`-` marker => left side.
        final lastChar = marker[marker.length - 1];
        side = lastChar == '-' ? MindmapSide.left : MindmapSide.right;
        s = s.substring(afterEnd).trimLeft();
        Color? color;
        if (s.startsWith('[#')) {
          final close = s.indexOf(']');
          if (close > 2) {
            final colorText = s.substring(2, close).trim();
            color = text_colors.tryParseColor('#$colorText');
            s = s.substring(close + 1);
          }
        }
        // Multi-line `:text;` content marker (e.g. `++:Body text;`).
        if (s.startsWith(':')) {
          s = s.substring(1);
          if (s.endsWith(';')) s = s.substring(0, s.length - 1);
        }
        final text = _stripTrailingStereotypeAndAlias(s.trim());
        return _MindmapLine(
          depth: depth,
          side: side,
          color: color,
          text: text,
          line: line,
          column: col,
        );
      }
    }
    if (s.startsWith('+')) {
      side = MindmapSide.right;
      s = s.substring(1);
    } else if (s.startsWith('-')) {
      side = MindmapSide.left;
      s = s.substring(1);
    }
    var depth = 0;
    while (depth < s.length && s[depth] == '*') {
      depth++;
    }
    if (depth == 0) {
      throw ParserException('Expected node line starting with *', line, col);
    }
    s = s.substring(depth);
    // Trailing marker suffix: `<` flips this node to the left side (e.g.
    // `***< New York`), `_` marks the node as boxless (currently consumed
    // and ignored). Both must be immediately after the `*` run.
    if (s.isNotEmpty && (s[0] == '<' || s[0] == '_')) {
      if (s[0] == '<') side = MindmapSide.left;
      s = s.substring(1);
    }
    Color? color;
    s = s.trimLeft();
    if (s.startsWith('[#')) {
      final close = s.indexOf(']');
      if (close > 2) {
        final colorText = s.substring(2, close).trim();
        color = text_colors.tryParseColor('#$colorText');
        s = s.substring(close + 1);
      }
    }
    // Multi-line `:text;` content marker (e.g. `**:Body text;`).
    s = s.trimLeft();
    if (s.startsWith(':')) {
      s = s.substring(1);
      if (s.endsWith(';')) s = s.substring(0, s.length - 1);
    }
    final text = _stripTrailingStereotypeAndAlias(s.trim());
    return _MindmapLine(
      depth: depth,
      side: side,
      color: color,
      text: text,
      line: line,
      column: col,
    );
  }

  /// Strips trailing `<<class>>` stereotypes and `as alias` clauses from a
  /// mindmap/wbs node label, and unquotes a leading `"..."` quoted name.
  /// Returns the visible node text. Stereotype/alias metadata is currently
  /// consumed-and-ignored (visual styling deferred).
  String _stripTrailingStereotypeAndAlias(String input) {
    var s = input.trim();
    // Repeatedly peel trailing `<<...>>` stereotypes.
    while (s.endsWith('>>')) {
      final open = s.lastIndexOf('<<');
      if (open < 0) break;
      s = s.substring(0, open).trim();
    }
    // Drop a trailing ` as <alias>` clause if present (only when the head
    // is a quoted string — avoids stripping legitimate prose containing
    // the word "as").
    if (s.startsWith('"')) {
      final closeQuote = s.indexOf('"', 1);
      if (closeQuote > 0) {
        final head = s.substring(1, closeQuote);
        final tail = s.substring(closeQuote + 1).trim();
        if (tail.isEmpty || tail.startsWith('as ') || tail == 'as') {
          s = head;
        }
      }
    }
    return s;
  }

  MindmapNode? _buildMindmapTree(
    List<_MindmapLine> lines, {
    String diagramName = 'mindmap',
  }) {
    if (lines.isEmpty) return null;
    final label = diagramName[0].toUpperCase() + diagramName.substring(1);
    // WBS and mindmap sources in the wild sometimes use bare `+`/`*` for every
    // level (relying on document order rather than marker depth to convey
    // hierarchy). When we encounter additional depth-1 nodes after the first,
    // treat them as children of the prior depth-1 root instead of throwing —
    // this matches PlantUML's lenient handling for both WBS and mindmap.
    final allowImpliedNesting = diagramName == 'wbs' || diagramName == 'mindmap';
    final stack = <_MindmapBuilder>[];
    _MindmapBuilder? rootBuilder;
    for (final l in lines) {
      final node = _MindmapBuilder(
        text: l.text,
        depth: l.depth,
        side: l.side,
        color: l.color,
      );
      if (l.depth == 1) {
        if (rootBuilder != null) {
          if (allowImpliedNesting) {
            // Attach to root as a child to keep parsing.
            rootBuilder.children.add(node);
            // Reset stack to (root, this) so subsequent deeper nodes can
            // nest under the latest depth-1 sibling.
            stack
              ..clear()
              ..add(rootBuilder)
              ..add(node);
            continue;
          }
          throw ParserException(
              '$label may have only one root node', l.line, l.column);
        }
        rootBuilder = node;
        stack
          ..clear()
          ..add(node);
        continue;
      }
      if (rootBuilder == null) {
        throw ParserException(
            '$label child appears before root', l.line, l.column);
      }
      while (stack.isNotEmpty && stack.last.depth >= l.depth) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        if (allowImpliedNesting) {
          // Re-seed from root when the stack drained (e.g. multiple
          // independent subtrees nested under a shared root).
          stack.add(rootBuilder);
        } else {
          throw ParserException(
              '$label node depth jumps from 0 to ${l.depth}',
              l.line,
              l.column);
        }
      }
      stack.last.children.add(node);
      stack.add(node);
    }
    return rootBuilder?.build();
  }

  /// True when the first significant line inside `@startuml ... @enduml`
  /// starts with the `json` keyword. Used to route sources like
  /// `@startuml\njson J { ... }\n@enduml` to the JSON diagram parser.
  bool _looksLikeInlineJsonDiagram() {
    for (var k = _pos; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type == TokenType.newline) continue;
      if (t.type == TokenType.endUml || t.type == TokenType.eof) return false;
      if (t.type == TokenType.identifier && t.lexeme == 'json') {
        return true;
      }
      return false;
    }
    return false;
  }

  /// Parses a top-level `json [display] [as alias] { ... }` block inside
  /// `@startuml ... @enduml` and returns a stub [DataDiagram].
  ///
  /// The current lexer is sequence-diagram-oriented: a `:` token greedily
  /// consumes the rest of the line as a text token, so the JSON body cannot
  /// be losslessly reconstructed from the token stream. As a first step we
  /// accept the block (brace-balanced consume) and return an empty
  /// DataDiagram so the diagram parses without error. Full visual rendering
  /// of inline JSON is deferred — sources that need the structured body
  /// should use the dedicated `@startjson` form.
  Diagram _parseInlineJsonAsDataDiagram() {
    _expectKeyword('json');
    if (_check(TokenType.stringLiteral)) {
      _advance();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) _advance();
      }
    } else if (_check(TokenType.identifier)) {
      _advance();
      if (_isKeyword('as')) {
        _advance();
        if (_check(TokenType.identifier)) _advance();
      }
    }
    _skipNewlines();
    // Consume everything up to (but not including) the closing `@enduml`.
    // Brace-counting isn't reliable for inline JSON because the existing
    // lexer eats the rest of a line after a `:` into a single text token,
    // which hides interior `{`/`}` from the brace counter. Greedy consume
    // is correct here because the inline JSON block is the only content
    // inside the `@startuml ... @enduml` wrapper (gated by
    // `_looksLikeInlineJsonDiagram`).
    while (!_check(TokenType.eof) && !_check(TokenType.endUml)) {
      _advance();
    }
    _expect(TokenType.endUml);
    return DataDiagram(
      root: const DataObject([]),
      format: DataFormat.json,
      decorations: _decorations.build(),
    );
  }

  DataDiagram _parseJsonDiagram() {
    final buf = StringBuffer();
    int? firstLine;
    int? firstCol;
    var inStyleBlock = false;
    while (!_check(TokenType.endJson) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected JSON body line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      final raw = t.lexeme;
      final trimmed = raw.trim();
      final trimmedLeft = raw.trimLeft();
      // Consume `<style> ... </style>` blocks as no-ops. PlantUML allows a
      // CSS-like style declaration inside `@startjson`/`@endjson`; rendering
      // is deferred so we just skip the block here.
      if (inStyleBlock) {
        if (trimmed.toLowerCase().contains('</style>')) {
          inStyleBlock = false;
        }
        continue;
      }
      final lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.startsWith('<style>') ||
          lowerTrimmed.startsWith('<style ')) {
        if (!lowerTrimmed.contains('</style>')) {
          inStyleBlock = true;
        }
        continue;
      }
      // `#highlight "path" [/ "key"] [<<class>>]` and other `#` directives
      // are accepted as no-ops; rendering of highlight is deferred.
      if (trimmedLeft.startsWith('#')) {
        continue;
      }
      firstLine ??= t.line;
      firstCol ??= t.column;
      buf.writeln(raw);
    }
    if (_check(TokenType.endJson)) {
      _advance();
    }
    final source = buf.toString().trim();
    if (source.isEmpty) {
      throw ParserException('Empty JSON body', firstLine ?? 1, firstCol ?? 1);
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ParserException(
          'Invalid JSON: ${e.message}', firstLine ?? 1, firstCol ?? 1);
    }
    return DataDiagram(
      root: _convertJsonValue(decoded, firstLine ?? 1, firstCol ?? 1),
      format: DataFormat.json,
      decorations: _decorations.build(),
    );
  }

  DataNode _convertJsonValue(dynamic value, int line, int col) {
    if (value == null) {
      return const DataScalar(value: 'null', kind: ScalarKind.null_);
    }
    if (value is bool) {
      return DataScalar(value: value.toString(), kind: ScalarKind.boolean);
    }
    if (value is num) {
      return DataScalar(value: value.toString(), kind: ScalarKind.number);
    }
    if (value is String) {
      return DataScalar(value: value, kind: ScalarKind.string);
    }
    if (value is List) {
      return DataArray(List<DataNode>.unmodifiable(
        value.map((e) => _convertJsonValue(e, line, col)),
      ));
    }
    if (value is Map) {
      final entries = <MapEntry<String, DataNode>>[];
      value.forEach((k, v) {
        entries.add(MapEntry(
          k.toString(),
          _convertJsonValue(v, line, col),
        ));
      });
      return DataObject(List.unmodifiable(entries));
    }
    throw ParserException(
        'Unsupported JSON value type: ${value.runtimeType}', line, col);
  }

  DataDiagram _parseYamlDiagram() {
    final lines = <_YamlSourceLine>[];
    var inStyleBlock = false;
    while (!_check(TokenType.endYaml) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected YAML body line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      final raw = t.lexeme;
      final trimmed = raw.trim();
      // Consume `<style> ... </style>` blocks as no-ops. PlantUML allows a
      // CSS-like style declaration inside `@startyaml`/`@endyaml`; rendering
      // is deferred so we just skip the block here.
      if (inStyleBlock) {
        if (trimmed.toLowerCase().contains('</style>')) {
          inStyleBlock = false;
        }
        continue;
      }
      final lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.startsWith('<style>') ||
          lowerTrimmed.startsWith('<style ')) {
        if (!lowerTrimmed.contains('</style>')) {
          inStyleBlock = true;
        }
        continue;
      }
      if (raw.trimLeft().startsWith('#')) {
        continue;
      }
      lines.add(_YamlSourceLine(raw: raw, line: t.line));
    }
    if (_check(TokenType.endYaml)) {
      _advance();
    }
    final firstLine = lines.isEmpty ? 1 : lines.first.line;
    _yamlAnchors = <String, DataNode>{};
    final root = _parseYamlValue(lines, 0, lines.length, -1, firstLine);
    _yamlAnchors = <String, DataNode>{};
    if (root == null) {
      throw ParserException('Empty YAML body', firstLine, 1);
    }
    return DataDiagram(
      root: root,
      format: DataFormat.yaml,
      decorations: _decorations.build(),
    );
  }

  Map<String, DataNode> _yamlAnchors = <String, DataNode>{};

  DataNode? _parseYamlValue(
    List<_YamlSourceLine> lines,
    int start,
    int end,
    int parentIndent,
    int errLine,
  ) {
    var first = start;
    while (first < end && lines[first].raw.trim().isEmpty) {
      first++;
    }
    if (first >= end) return null;
    final firstLine = lines[first];
    final firstIndent = _yamlIndent(firstLine.raw);
    if (firstIndent <= parentIndent) {
      throw ParserException(
          'YAML indent error', firstLine.line, firstIndent + 1);
    }
    final firstContent = firstLine.raw.substring(firstIndent);
    if (firstContent.startsWith('- ') || firstContent == '-') {
      return _parseYamlSequence(lines, first, end, firstIndent);
    }
    return _parseYamlMapping(lines, first, end, firstIndent);
  }

  DataArray _parseYamlSequence(
    List<_YamlSourceLine> lines,
    int start,
    int end,
    int indent,
  ) {
    final items = <DataNode>[];
    var i = start;
    while (i < end) {
      final line = lines[i];
      if (line.raw.trim().isEmpty) {
        i++;
        continue;
      }
      final lineIndent = _yamlIndent(line.raw);
      if (lineIndent < indent) break;
      if (lineIndent > indent) {
        throw ParserException(
            'YAML indent error in sequence', line.line, lineIndent + 1);
      }
      final content = line.raw.substring(indent);
      if (!content.startsWith('-')) break;
      final afterDash = content.length > 1 ? content.substring(1) : '';
      final trimmed = afterDash.trimLeft();
      var blockStart = i + 1;
      var blockEnd = blockStart;
      while (blockEnd < end) {
        final bl = lines[blockEnd];
        if (bl.raw.trim().isEmpty) {
          blockEnd++;
          continue;
        }
        if (_yamlIndent(bl.raw) <= indent) break;
        blockEnd++;
      }
      if (trimmed.isEmpty) {
        final nested =
            _parseYamlValue(lines, blockStart, blockEnd, indent, line.line);
        items
            .add(nested ?? const DataScalar(value: '', kind: ScalarKind.null_));
      } else {
        final colonIdx = _yamlFindMappingColon(trimmed);
        if (colonIdx >= 0) {
          final key = trimmed.substring(0, colonIdx).trim();
          final rest = trimmed.substring(colonIdx + 1).trim();
          final entries = <MapEntry<String, DataNode>>[];
          if (rest.isEmpty) {
            final nested =
                _parseYamlValue(lines, blockStart, blockEnd, indent, line.line);
            entries.add(MapEntry(
              key,
              nested ?? const DataScalar(value: '', kind: ScalarKind.null_),
            ));
          } else {
            entries.add(MapEntry(key, _yamlScalar(rest)));
          }
          _parseYamlMappingInto(
              entries, lines, blockStart, blockEnd, indent + 2);
          items.add(DataObject(List.unmodifiable(entries)));
        } else {
          items.add(_yamlScalar(trimmed));
        }
      }
      i = blockEnd;
    }
    return DataArray(List.unmodifiable(items));
  }

  DataObject _parseYamlMapping(
    List<_YamlSourceLine> lines,
    int start,
    int end,
    int indent,
  ) {
    final entries = <MapEntry<String, DataNode>>[];
    _parseYamlMappingInto(entries, lines, start, end, indent);
    return DataObject(List.unmodifiable(entries));
  }

  void _parseYamlMappingInto(
    List<MapEntry<String, DataNode>> entries,
    List<_YamlSourceLine> lines,
    int start,
    int end,
    int indent,
  ) {
    var i = start;
    while (i < end) {
      final line = lines[i];
      if (line.raw.trim().isEmpty) {
        i++;
        continue;
      }
      final lineIndent = _yamlIndent(line.raw);
      if (lineIndent < indent) break;
      if (lineIndent > indent) {
        throw ParserException('YAML indent error', line.line, lineIndent + 1);
      }
      final content = line.raw.substring(indent);
      if (content.startsWith('-')) break;
      final colonIdx = _yamlFindMappingColon(content);
      if (colonIdx < 0) {
        throw ParserException(
            'Expected YAML "key: value"', line.line, indent + 1);
      }
      final key = content.substring(0, colonIdx).trim();
      final rest = content.substring(colonIdx + 1).trim();
      var blockStart = i + 1;
      var blockEnd = blockStart;
      while (blockEnd < end) {
        final bl = lines[blockEnd];
        if (bl.raw.trim().isEmpty) {
          blockEnd++;
          continue;
        }
        if (_yamlIndent(bl.raw) <= indent) break;
        blockEnd++;
      }
      if (key == '<<') {
        if (rest.startsWith('*')) {
          final alias = rest.substring(1).trim();
          final ref = _yamlAnchors[alias];
          if (ref is DataObject) {
            for (final e in ref.entries) {
              entries.add(e);
            }
          }
        }
        i = blockEnd;
        continue;
      }
      String? anchorName;
      var restValue = rest;
      if (restValue.startsWith('&')) {
        var k = 1;
        while (k < restValue.length &&
            restValue[k] != ' ' &&
            restValue[k] != '\t') {
          k++;
        }
        anchorName = restValue.substring(1, k);
        restValue = restValue.substring(k).trim();
      }
      DataNode value;
      if (restValue.isEmpty) {
        final nested =
            _parseYamlValue(lines, blockStart, blockEnd, indent, line.line);
        value = nested ?? const DataScalar(value: '', kind: ScalarKind.null_);
      } else if (restValue.startsWith('*')) {
        final alias = restValue.substring(1).trim();
        final ref = _yamlAnchors[alias];
        value = ref ?? DataScalar(value: restValue, kind: ScalarKind.string);
      } else {
        value = _yamlScalar(restValue);
      }
      if (anchorName != null) {
        _yamlAnchors[anchorName] = value;
      }
      entries.add(MapEntry(key, value));
      i = blockEnd;
    }
  }

  int _yamlIndent(String s) {
    var n = 0;
    while (n < s.length && s[n] == ' ') {
      n++;
    }
    return n;
  }

  int _yamlFindMappingColon(String s) {
    var inSingle = false;
    var inDouble = false;
    for (var k = 0; k < s.length; k++) {
      final ch = s[k];
      if (ch == '"' && !inSingle) inDouble = !inDouble;
      if (ch == "'" && !inDouble) inSingle = !inSingle;
      if (inSingle || inDouble) continue;
      if (ch == ':') {
        if (k + 1 == s.length || s[k + 1] == ' ') return k;
      }
    }
    return -1;
  }

  DataScalar _yamlScalar(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const DataScalar(value: '', kind: ScalarKind.null_);
    }
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return DataScalar(
          value: s.substring(1, s.length - 1), kind: ScalarKind.string);
    }
    if (s.length >= 2 && s.startsWith("'") && s.endsWith("'")) {
      return DataScalar(
          value: s.substring(1, s.length - 1), kind: ScalarKind.string);
    }
    final lower = s.toLowerCase();
    if (lower == 'null' || lower == '~') {
      return const DataScalar(value: 'null', kind: ScalarKind.null_);
    }
    if (lower == 'true' || lower == 'false') {
      return DataScalar(value: lower, kind: ScalarKind.boolean);
    }
    if (num.tryParse(s) != null) {
      return DataScalar(value: s, kind: ScalarKind.number);
    }
    return DataScalar(value: s, kind: ScalarKind.string);
  }

  SaltDiagram _parseSaltDiagram() {
    final rawLines = <String>[];
    while (!_check(TokenType.endSalt) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected salt body line, got ${t.type}', t.line, t.column);
      }
      rawLines.add(_advance().lexeme);
    }
    if (_check(TokenType.endSalt)) {
      _advance();
    }
    final lines = <String>[];
    for (final raw in rawLines) {
      if (raw.trim().isNotEmpty) lines.add(raw);
    }
    if (lines.isNotEmpty && lines.first.trim() == '{') {
      lines.removeAt(0);
    }
    if (lines.isNotEmpty && lines.last.trim() == '}') {
      lines.removeLast();
    }
    final rows = <SaltRow>[];
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed == '--') {
        rows.add(const SaltRow(isDivider: true));
        continue;
      }
      final cellTexts = raw.split('|');
      final cells = <SaltCell>[];
      for (final ct in cellTexts) {
        cells.add(_parseSaltCell(ct.trim()));
      }
      rows.add(SaltRow(cells: List.unmodifiable(cells)));
    }
    return SaltDiagram(rows: List.unmodifiable(rows), decorations: _decorations.build());
  }

  GanttDiagram _parseGanttDiagram() {
    final rawLines = <_GanttSourceLine>[];
    while (!_check(TokenType.endGantt) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected gantt body line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      rawLines
          .add(_GanttSourceLine(raw: t.lexeme, line: t.line, column: t.column));
    }
    if (_check(TokenType.endGantt)) {
      _advance();
    }
    return _buildGanttDiagram(rawLines);
  }

  GanttDiagram _buildGanttDiagram(List<_GanttSourceLine> rawLines) {
    DateTime? projectStart;
    final builders = <_GanttItemBuilder>[];
    final tasks = <String, _GanttTaskBuilder>{};
    // Alias resolution: `[D]` -> `Prototype design`. Aliases declared via
    // `[Task] as [Alias] requires N days` (and friends) let later lines
    // reference the task by either name or alias.
    final aliasFor = <String, String>{};
    _GanttTaskBuilder taskFor(String key) {
      final resolved = aliasFor[key] ?? key;
      return tasks.putIfAbsent(
          resolved, () => _GanttTaskBuilder(name: resolved));
    }

    final projectRe =
        RegExp(r'^[Pp]roject\s+starts?\s+(\d{4}-\d{2}-\d{2})\s*$');
    // `Project starts the Nth of MonthName YYYY` — natural-language project
    // start. Consumes ordinal suffixes (`1st`, `2nd`, `3rd`, `Nth`) and
    // month names; parses to a real `DateTime` so downstream task placement
    // works as if the ISO form had been written.
    final projectNaturalRe = RegExp(
        r'^[Pp]roject\s+starts?\s+(?:on\s+)?the\s+(\d{1,2})(?:st|nd|rd|th)?\s+of\s+([A-Za-z]+)\s+(\d{4})\s*$');
    // `projectscale daily|weekly|monthly|yearly[ N]` / `printscale ...` /
    // `zoom N` — diagram-wide scale directives. Consumed-and-ignored at
    // build time since layout uses an implicit day-based scale.
    final scaleDirectiveRe = RegExp(
        r'^(?:project|print)scale\b.*$',
        caseSensitive: false);
    final zoomRe = RegExp(r'^zoom\s+\S+\s*$', caseSensitive: false);
    final sectionRe = RegExp(r'^--\s*(.*?)\s*--\s*$');
    final lastsRe = RegExp(
        r'^\[(.+?)\](?:\s+as\s+\[(.+?)\])?\s+lasts?\s+(\d+)\s+(day|days|week|weeks|month|months)\s*$');
    final lastsAndStartsRe = RegExp(
        r"^\[(.+?)\]\s+lasts?\s+(\d+)\s+(day|days|week|weeks|month|months)\s+and\s+starts?\s+at\s+\[(.+?)\]'s\s+(end|start)\s*$");
    final startsDateRe = RegExp(
        r'^\[(.+?)\]\s+starts?\s+(?:on\s+|at\s+)?(\d{4}-\d{2}-\d{2})\s*$');
    // `[Task] starts D+N` or `[Task] starts D-N` — relative day offset from
    // the project start.
    final startsRelativeRe = RegExp(
        r'^\[(.+?)\]\s+starts?\s+(?:on\s+|at\s+)?D\s*([+-])\s*(\d+)\s*$',
        caseSensitive: false);
    // `[Task] ends YYYY-MM-DD` — absolute end date.
    final endsDateRe = RegExp(
        r'^\[(.+?)\]\s+ends?\s+(?:on\s+|at\s+)?(\d{4}-\d{2}-\d{2})\s*$');
    // `[Task] ends D+N` — relative day offset from the project start.
    final endsRelativeRe = RegExp(
        r'^\[(.+?)\]\s+ends?\s+(?:on\s+|at\s+)?D\s*([+-])\s*(\d+)\s*$',
        caseSensitive: false);
    final startsAtRe =
        RegExp(r"^\[(.+?)\]\s+starts?\s+at\s+\[(.+?)\]'s\s+(end|start)\s*$");
    final happensRe = RegExp(
        r"^\[(.+?)\]\s+happens?\s+(?:on\s+|at\s+)?(?:\[(.+?)\]'s\s+(end|start)|(\d{4}-\d{2}-\d{2}))\s*$");
    final coloredRe = RegExp(r'^\[(.+?)\]\s+is\s+colored?\s+in\s+(\S+)\s*$');
    // `YYYY-MM-DD to YYYY-MM-DD are colored in Color` — date-range coloring
    // (consumed and tolerated; visual coloring of calendar ranges deferred).
    final dateRangeColoredRe = RegExp(
        r'^\d{4}-\d{2}-\d{2}\s+to\s+\d{4}-\d{2}-\d{2}\s+(?:are|is)\s+colored?\s+in\s+\S+\s*$',
        caseSensitive: false);
    // `[FROM]->[TO]` raw dependency arrow — equivalent to `[TO] starts at
    // [FROM]'s end` but written as a graph edge. The arrow body tolerates
    // any mix of dashes / dots; head must be `>`.
    final depArrowRe =
        RegExp(r'^\[(.+?)\]\s*[-.]+>\s*\[(.+?)\]\s*$');
    final closedDayRe = RegExp(
        r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\s+(?:are|is)\s+(closed|open)\s*$',
        caseSensitive: false);
    // `[Task] requires N days [on {Resource[:N%]}]` and the
    // `[Task] as [Alias] requires N days` alias-bind variant. Optional
    // `on {Resource}` / `on {Resource:N%}` resource assignment may appear
    // either BEFORE or AFTER the `requires` clause; both are consumed
    // (resource modelling is deferred). A trailing `then [Task2] requires
    // ... [on {R2}]` clause chains a follow-on task that starts at the
    // current task's end.
    final requiresRe = RegExp(
        r'^\[(.+?)\](?:\s+as\s+\[(.+?)\])?(?:\s+on\s+\{(.+?)\})?\s+requires?\s+(\d+)\s+(day|days|week|weeks|month|months)(?:\s+and\s+(\d+)\s+(day|days|week|weeks|month|months))?(?:\s+on\s+\{(.+?)\})?(?:\s+then\s+\[(.+?)\](?:\s+on\s+\{(.+?)\})?\s+requires?\s+(\d+)\s+(day|days|week|weeks|month|months)(?:\s+on\s+\{(.+?)\})?)?\s*$',
        caseSensitive: false);
    final thenLastsRe = RegExp(
        r'^then\s+\[(.+?)\]\s+lasts?\s+(\d+)\s+(day|days|week|weeks|month|months)\s*$',
        caseSensitive: false);

    // Expand compound `[Task] <clause> and <clause> [and <clause> ...]` lines
    // into multiple single-clause source lines so the per-clause dispatch
    // below can handle them uniformly. The first clause is left intact; each
    // follow-up clause is prefixed with the bracketed task ref (using the
    // alias when the first clause introduces one via `as [Alias]`) so it
    // matches the existing per-clause regexes. Forms already supported as
    // single combined patterns — `lasts N <unit> and starts at [X]'s end`
    // and `requires N <unit> and M <unit2>` — are left untouched.
    final taskHeadRe = RegExp(
        r'^\s*(\[(?:.+?)\])(?:\s+as\s+(\[(?:.+?)\]))?\s+');
    final expandedLines = <_GanttSourceLine>[];
    for (final src in rawLines) {
      final s0 = src.raw.trim();
      if (s0.isEmpty || !s0.toLowerCase().contains(' and ')) {
        expandedLines.add(src);
        continue;
      }
      // Skip lines already matched by combined-form regexes.
      if (lastsAndStartsRe.hasMatch(s0) || requiresRe.hasMatch(s0)) {
        expandedLines.add(src);
        continue;
      }
      final head = taskHeadRe.firstMatch(s0);
      if (head == null) {
        expandedLines.add(src);
        continue;
      }
      // Prefer the alias (if present) as the prefix for follow-up clauses
      // since color/duration/start lines may target the alias form.
      final refPrefix = (head.group(2) ?? head.group(1))!;
      // Case-insensitive split on whitespace-delimited `and`.
      final parts = s0.split(RegExp(r'\s+and\s+', caseSensitive: false));
      if (parts.length < 2) {
        expandedLines.add(src);
        continue;
      }
      expandedLines.add(_GanttSourceLine(
          raw: parts.first, line: src.line, column: src.column));
      for (var i = 1; i < parts.length; i++) {
        final clause = parts[i].trim();
        if (clause.isEmpty) continue;
        final synthesized =
            clause.startsWith('[') ? clause : '$refPrefix $clause';
        expandedLines.add(_GanttSourceLine(
            raw: synthesized, line: src.line, column: src.column));
      }
    }

    _GanttTaskBuilder? previousTask;
    for (final src in expandedLines) {
      final s = src.raw.trim();
      if (s.isEmpty) continue;
      if (s.toLowerCase().startsWith('title ') ||
          s.toLowerCase() == 'title') {
        continue;
      }
      if (closedDayRe.hasMatch(s)) {
        continue;
      }
      // `projectscale ...` / `printscale ...` / `zoom N` — purely visual
      // scale directives consumed as no-ops.
      if (scaleDirectiveRe.hasMatch(s) || zoomRe.hasMatch(s)) {
        continue;
      }
      // `YYYY-MM-DD to YYYY-MM-DD are colored in Color` — calendar-range
      // background coloring. Visual coloring deferred; line consumed.
      if (dateRangeColoredRe.hasMatch(s)) {
        continue;
      }
      final rqm = requiresRe.firstMatch(s);
      if (rqm != null) {
        final name = rqm.group(1)!.trim();
        final alias = rqm.group(2)?.trim();
        int unitToDays(int n, String unit) {
          final u = unit.toLowerCase();
          if (u.startsWith('week')) return n * 7;
          if (u.startsWith('month')) return n * 30;
          return n;
        }
        var days = unitToDays(int.parse(rqm.group(4)!), rqm.group(5)!);
        if (rqm.group(6) != null) {
          days += unitToDays(int.parse(rqm.group(6)!), rqm.group(7)!);
        }
        final builder = taskFor(name);
        builder.duration = Duration(days: days);
        if (alias != null && alias.isNotEmpty) {
          aliasFor[alias] = builder.name;
        }
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        // Optional `then [Task2] requires N <unit>` follow-on clause —
        // the chained task starts at the current task's end.
        final thenName = rqm.group(9);
        if (thenName != null) {
          final n2 = int.parse(rqm.group(11)!);
          final unit2 = rqm.group(12)!;
          final days2 = unitToDays(n2, unit2);
          final thenBuilder = taskFor(thenName.trim());
          thenBuilder.duration = Duration(days: days2);
          thenBuilder.startsAtRef = builder.name;
          thenBuilder.startsAtEnd = true;
          if (!builders.contains(thenBuilder)) builders.add(thenBuilder);
          previousTask = thenBuilder;
        }
        continue;
      }
      // `[FROM]->[TO]` raw dependency edge — model as `[TO] starts at
      // [FROM]'s end`.
      final dam = depArrowRe.firstMatch(s);
      if (dam != null) {
        final from = dam.group(1)!.trim();
        final to = dam.group(2)!.trim();
        final builder = taskFor(to);
        builder.startsAtRef = aliasFor[from] ?? from;
        builder.startsAtEnd = true;
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final tlm = thenLastsRe.firstMatch(s);
      if (tlm != null) {
        final name = tlm.group(1)!.trim();
        final n = int.parse(tlm.group(2)!);
        final unit = tlm.group(3)!.toLowerCase();
        final days = unit.startsWith('week')
            ? n * 7
            : unit.startsWith('month')
                ? n * 30
                : n;
        final builder =
            tasks.putIfAbsent(name, () => _GanttTaskBuilder(name: name));
        builder.duration = Duration(days: days);
        if (previousTask != null) {
          builder.startsAtRef = previousTask.name;
          builder.startsAtEnd = true;
        }
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final pm = projectRe.firstMatch(s);
      if (pm != null) {
        projectStart = DateTime.parse(pm.group(1)!);
        continue;
      }
      final pnm = projectNaturalRe.firstMatch(s);
      if (pnm != null) {
        const monthNames = {
          'january': 1, 'february': 2, 'march': 3, 'april': 4,
          'may': 5, 'june': 6, 'july': 7, 'august': 8,
          'september': 9, 'october': 10, 'november': 11, 'december': 12,
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
          'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9,
          'oct': 10, 'nov': 11, 'dec': 12,
        };
        final day = int.parse(pnm.group(1)!);
        final monthKey = pnm.group(2)!.toLowerCase();
        final year = int.parse(pnm.group(3)!);
        final month = monthNames[monthKey];
        if (month != null) {
          projectStart = DateTime(year, month, day);
        }
        continue;
      }
      final lasm = lastsAndStartsRe.firstMatch(s);
      if (lasm != null) {
        final name = lasm.group(1)!.trim();
        final n = int.parse(lasm.group(2)!);
        final unit = lasm.group(3)!.toLowerCase();
        final ref = lasm.group(4)!.trim();
        final endpoint = lasm.group(5)!.toLowerCase();
        final days = unit.startsWith('week')
            ? n * 7
            : unit.startsWith('month')
                ? n * 30
                : n;
        final builder = taskFor(name);
        builder.duration = Duration(days: days);
        builder.startsAtRef = aliasFor[ref] ?? ref;
        builder.startsAtEnd = endpoint == 'end';
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final sm = sectionRe.firstMatch(s);
      if (sm != null) {
        builders.add(_GanttSectionBuilder(sm.group(1)!.trim()));
        continue;
      }
      final lm = lastsRe.firstMatch(s);
      if (lm != null) {
        final name = lm.group(1)!.trim();
        final alias = lm.group(2)?.trim();
        final n = int.parse(lm.group(3)!);
        final unit = lm.group(4)!.toLowerCase();
        final days = unit.startsWith('week')
            ? n * 7
            : unit.startsWith('month')
                ? n * 30
                : n;
        final builder = taskFor(name);
        builder.duration = Duration(days: days);
        if (alias != null && alias.isNotEmpty) {
          aliasFor[alias] = builder.name;
        }
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final sdm = startsDateRe.firstMatch(s);
      if (sdm != null) {
        final name = sdm.group(1)!.trim();
        final date = DateTime.parse(sdm.group(2)!);
        final builder = taskFor(name);
        builder.explicitStart = date;
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final srm = startsRelativeRe.firstMatch(s);
      if (srm != null) {
        final name = srm.group(1)!.trim();
        final sign = srm.group(2)!;
        final n = int.parse(srm.group(3)!);
        final offset = sign == '-' ? -n : n;
        final builder = taskFor(name);
        builder.relativeStartDays = offset;
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final edm = endsDateRe.firstMatch(s);
      if (edm != null) {
        final name = edm.group(1)!.trim();
        final date = DateTime.parse(edm.group(2)!);
        final builder = taskFor(name);
        builder.explicitEnd = date;
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final erm = endsRelativeRe.firstMatch(s);
      if (erm != null) {
        final name = erm.group(1)!.trim();
        final sign = erm.group(2)!;
        final n = int.parse(erm.group(3)!);
        final offset = sign == '-' ? -n : n;
        final builder = taskFor(name);
        builder.relativeEndDays = offset;
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final sam = startsAtRe.firstMatch(s);
      if (sam != null) {
        final name = sam.group(1)!.trim();
        final ref = sam.group(2)!.trim();
        final endpoint = sam.group(3)!.toLowerCase();
        final builder = taskFor(name);
        builder.startsAtRef = aliasFor[ref] ?? ref;
        builder.startsAtEnd = endpoint == 'end';
        if (!builders.contains(builder)) builders.add(builder);
        previousTask = builder;
        continue;
      }
      final hm = happensRe.firstMatch(s);
      if (hm != null) {
        final name = hm.group(1)!.trim();
        final ref = hm.group(2);
        final endpoint = hm.group(3);
        final date = hm.group(4);
        final resolvedRef =
            ref == null ? null : (aliasFor[ref.trim()] ?? ref.trim());
        builders.add(_GanttMilestoneBuilder(
          name: name,
          ref: resolvedRef,
          atEnd: endpoint?.toLowerCase() == 'end',
          explicitDate: date != null ? DateTime.parse(date) : null,
        ));
        continue;
      }
      final cm = coloredRe.firstMatch(s);
      if (cm != null) {
        final name = cm.group(1)!.trim();
        final color = text_colors.tryParseColor(cm.group(2)!);
        final builder = tasks[aliasFor[name] ?? name];
        if (builder != null) builder.color = color;
        continue;
      }
      throw ParserException(
          'Unrecognized gantt line: "$s"', src.line, src.column);
    }

    projectStart ??=
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

    for (final b in builders) {
      if (b is _GanttTaskBuilder) {
        _resolveTaskStart(b, tasks, projectStart, <String>{});
      }
    }
    for (final b in builders) {
      if (b is _GanttMilestoneBuilder) {
        _resolveMilestoneDate(b, tasks, projectStart);
      }
    }

    final items = <GanttItem>[];
    for (final b in builders) {
      if (b is _GanttSectionBuilder) {
        items.add(GanttSection(b.title));
      } else if (b is _GanttTaskBuilder) {
        items.add(GanttTask(
          name: b.name,
          start: b.resolvedStart!,
          duration: b.duration ?? const Duration(days: 1),
          color: b.color,
        ));
      } else if (b is _GanttMilestoneBuilder) {
        items.add(GanttMilestone(name: b.name, date: b.resolvedDate!));
      }
    }
    return GanttDiagram(
      projectStart: projectStart,
      items: List.unmodifiable(items),
      decorations: _decorations.build(),
    );
  }

  DateTime _resolveTaskStart(
    _GanttTaskBuilder task,
    Map<String, _GanttTaskBuilder> tasks,
    DateTime projectStart,
    Set<String> visiting,
  ) {
    if (task.resolvedStart != null) return task.resolvedStart!;
    if (!visiting.add(task.name)) {
      throw ParserException(
          'Circular gantt reference involving "${task.name}"', 0, 0);
    }
    DateTime start;
    if (task.explicitStart != null) {
      start = task.explicitStart!;
    } else if (task.relativeStartDays != null) {
      start = projectStart.add(Duration(days: task.relativeStartDays!));
    } else if (task.startsAtRef != null) {
      final ref = tasks[task.startsAtRef!];
      if (ref == null) {
        throw ParserException(
            'Unknown gantt task reference "${task.startsAtRef}"', 0, 0);
      }
      final refStart = _resolveTaskStart(ref, tasks, projectStart, visiting);
      start = task.startsAtEnd
          ? refStart.add(ref.duration ?? const Duration(days: 1))
          : refStart;
    } else if (task.explicitEnd != null && task.duration != null) {
      // Derive start from the explicit end minus the duration.
      start = task.explicitEnd!.subtract(task.duration!);
    } else if (task.relativeEndDays != null && task.duration != null) {
      // Derive start from the relative end minus the duration.
      final end = projectStart.add(Duration(days: task.relativeEndDays!));
      start = end.subtract(task.duration!);
    } else if (task.explicitEnd != null) {
      // End-only spec: 1-day-long task ending on the given date.
      start = task.explicitEnd!;
    } else if (task.relativeEndDays != null) {
      start = projectStart.add(Duration(days: task.relativeEndDays!));
    } else {
      start = projectStart;
    }
    // When both end and duration are missing but only `ends D+N` was given
    // alongside `starts D+M`, derive the duration so the task has a length.
    if (task.duration == null) {
      if (task.explicitEnd != null) {
        final diff = task.explicitEnd!.difference(start).inDays;
        if (diff > 0) task.duration = Duration(days: diff);
      } else if (task.relativeEndDays != null) {
        final end = projectStart.add(Duration(days: task.relativeEndDays!));
        final diff = end.difference(start).inDays;
        if (diff > 0) task.duration = Duration(days: diff);
      }
    }
    visiting.remove(task.name);
    task.resolvedStart = start;
    return start;
  }

  void _resolveMilestoneDate(
    _GanttMilestoneBuilder m,
    Map<String, _GanttTaskBuilder> tasks,
    DateTime projectStart,
  ) {
    if (m.explicitDate != null) {
      m.resolvedDate = m.explicitDate;
      return;
    }
    if (m.ref != null) {
      final ref = tasks[m.ref!];
      if (ref == null) {
        throw ParserException('Unknown gantt task reference "${m.ref}"', 0, 0);
      }
      final refStart = _resolveTaskStart(ref, tasks, projectStart, <String>{});
      m.resolvedDate = m.atEnd
          ? refStart.add(ref.duration ?? const Duration(days: 1))
          : refStart;
      return;
    }
    m.resolvedDate = projectStart;
  }

  EbnfDiagram _parseEbnfDiagram() {
    final buf = StringBuffer();
    while (!_check(TokenType.endEbnf) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected EBNF body line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      final raw = t.lexeme;
      final trimmed = raw.trimLeft();
      if (trimmed.startsWith('#')) {
        continue;
      }
      if (trimmed.toLowerCase().startsWith('title ')) {
        continue;
      }
      buf.writeln(raw);
    }
    if (_check(TokenType.endEbnf)) {
      _advance();
    }
    final raw = buf.toString().trimRight();
    final parsed = EbnfBodyParser().parse(raw);
    return EbnfDiagram(
      text: parsed.remainder,
      rules: parsed.rules,
      decorations: _decorations.build(),
    );
  }

  NetworkDiagram _parseNetworkDiagram() {
    final rawLines = <_NwdiagSourceLine>[];
    while (!_check(TokenType.endNwdiag) && !_check(TokenType.eof)) {
      if (_check(TokenType.newline)) {
        _advance();
        continue;
      }
      if (!_check(TokenType.text)) {
        final t = _peek();
        throw ParserException(
            'Expected nwdiag body line, got ${t.type}', t.line, t.column);
      }
      final t = _advance();
      rawLines.add(
          _NwdiagSourceLine(raw: t.lexeme, line: t.line, column: t.column));
    }
    if (_check(TokenType.endNwdiag)) {
      _advance();
    }
    return _buildNetworkDiagram(rawLines);
  }

  NetworkDiagram _buildNetworkDiagram(List<_NwdiagSourceLine> rawLines) {
    final segments = <NetworkSegment>[];
    final networkOpenRe =
        RegExp(r'^network(?:\s+([A-Za-z0-9_]+))?\s*\{?\s*$');
    final groupOpenRe = RegExp(r'^group(?:\s+([A-Za-z0-9_]+))?\s*\{?\s*$');
    final nwdiagWrapperRe = RegExp(r'^nwdiag\s*\{?\s*$');
    final propertyRe =
        RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"\s*;?\s*$');
    final nodeWithAttrsRe = RegExp(r'^([A-Za-z0-9_]+)\s*\[(.*)\]\s*;?\s*$');
    final bareNodeRe = RegExp(r'^([A-Za-z0-9_]+)\s*;?\s*$');
    final addressAttrRe = RegExp(r'address\s*=\s*"([^"]*)"');

    // Context stack: 'root', 'wrapper', 'network', 'group'.
    final contextStack = <String>['root'];

    String? currentName;
    String? currentAddress;
    List<NetworkNode> currentNodes = [];
    var inSegment = false;

    void closeSegment() {
      if (!inSegment) return;
      segments.add(NetworkSegment(
        name: currentName!,
        address: currentAddress,
        nodes: List.unmodifiable(currentNodes),
      ));
      currentName = null;
      currentAddress = null;
      currentNodes = [];
      inSegment = false;
    }

    // Split a raw line on top-level statement separators, stripping `//`
    // comments. Returns a list of individual statements (no semicolons).
    List<String> normalize(String raw) {
      // Strip `//` line comment (outside quotes).
      final commentIdx = _findNwdiagCommentStart(raw);
      final stripped =
          commentIdx >= 0 ? raw.substring(0, commentIdx) : raw;
      final out = <String>[];
      final sb = StringBuffer();
      var inString = false;
      for (var k = 0; k < stripped.length; k++) {
        final ch = stripped[k];
        if (ch == '"') {
          inString = !inString;
          sb.write(ch);
          continue;
        }
        if (!inString && ch == ';') {
          final piece = sb.toString().trim();
          if (piece.isNotEmpty) out.add(piece);
          sb.clear();
          continue;
        }
        sb.write(ch);
      }
      final tail = sb.toString().trim();
      if (tail.isNotEmpty) out.add(tail);
      return out;
    }

    for (final src in rawLines) {
      for (final s in normalize(src.raw)) {
        if (s.isEmpty) continue;
        // Preprocessor directives (e.g. `!include <library/path>`) are
        // consumed and ignored at the nwdiag body level — sprite-library
        // resolution is not yet implemented.
        if (s.startsWith('!')) continue;
        if (s == '{') continue;
        if (s == '}') {
          final ctx = contextStack.isNotEmpty ? contextStack.last : 'root';
          if (ctx == 'network') {
            closeSegment();
          }
          if (contextStack.length > 1) {
            contextStack.removeLast();
          }
          continue;
        }
        // Wrapper: `nwdiag {`
        final wrapperMatch = nwdiagWrapperRe.firstMatch(s);
        if (wrapperMatch != null) {
          contextStack.add('wrapper');
          continue;
        }
        // Network opener: `network NAME {`
        final openMatch = networkOpenRe.firstMatch(s);
        if (openMatch != null && openMatch.group(1) != null) {
          // Implicitly close any prior network when we see a sibling network
          // declaration without an explicit `}` (common in the test suite).
          if (inSegment && contextStack.last == 'network') {
            closeSegment();
            contextStack.removeLast();
          }
          contextStack.add('network');
          currentName = openMatch.group(1);
          currentAddress = null;
          currentNodes = [];
          inSegment = true;
          continue;
        }
        // Group opener: `group [NAME] {` — consumed as no-op container.
        final groupMatch = groupOpenRe.firstMatch(s);
        if (groupMatch != null) {
          contextStack.add('group');
          continue;
        }
        // Property: `key = "value"`
        final propMatch = propertyRe.firstMatch(s);
        if (propMatch != null) {
          final key = propMatch.group(1)!;
          final value = propMatch.group(2)!;
          if (key == 'address' && inSegment &&
              contextStack.last == 'network') {
            currentAddress = value;
          }
          // Other properties (color, etc.) are accepted but not rendered.
          continue;
        }
        // Node with attrs: `name [address = ".1"]`
        // The attribute list may contain multiple comma-separated key=value
        // pairs (e.g. `address = "X, Y", description = "..."`). We extract
        // the `address` attribute when present and silently swallow any
        // other keys (such as `description`, `color`, `shape`) so the
        // verbatim source parses without throwing — sprite rendering and
        // node descriptions are not yet implemented.
        final nodeAttrs = nodeWithAttrsRe.firstMatch(s);
        if (nodeAttrs != null) {
          final name = nodeAttrs.group(1)!;
          final attrs = nodeAttrs.group(2)!;
          String? address;
          final addrMatch = addressAttrRe.firstMatch(attrs);
          if (addrMatch != null) {
            address = addrMatch.group(1);
          }
          if (inSegment) {
            currentNodes.add(NetworkNode(name: name, address: address));
          }
          continue;
        }
        // Bare node: `name`
        final bare = bareNodeRe.firstMatch(s);
        if (bare != null) {
          if (inSegment) {
            currentNodes.add(NetworkNode(name: bare.group(1)!));
          }
          // Bare node outside a network (e.g. inside a top-level group) is
          // accepted as a member reference without producing a segment node.
          continue;
        }
        // Unknown line — accept silently to keep parsing resilient.
      }
    }
    closeSegment();

    return NetworkDiagram(
      networks: List.unmodifiable(segments),
      decorations: _decorations.build(),
    );
  }

  // Find start index of a `//` line comment, ignoring quoted regions.
  int _findNwdiagCommentStart(String s) {
    var inString = false;
    for (var k = 0; k < s.length; k++) {
      final ch = s[k];
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (!inString && ch == '/' && k + 1 < s.length && s[k + 1] == '/') {
        return k;
      }
    }
    return -1;
  }

  SaltCell _parseSaltCell(String text) {
    if (text.isEmpty) return const SaltLabel('');
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      return SaltTextField(text.substring(1, text.length - 1));
    }
    final radio = RegExp(r'^\(\s*([xX ])\s*\)\s*(.*)$').firstMatch(text);
    if (radio != null) {
      final mark = radio.group(1)!;
      final label = radio.group(2)!.trim();
      return SaltRadio(selected: mark != ' ', label: label);
    }
    final checkbox = RegExp(r'^\[\s*([xX ])\s*\]\s*(.+)$').firstMatch(text);
    if (checkbox != null) {
      final mark = checkbox.group(1)!;
      final label = checkbox.group(2)!.trim();
      return SaltCheckbox(checked: mark.toLowerCase() == 'x', label: label);
    }
    if (text.startsWith('[') && text.endsWith(']') && text.length >= 2) {
      return SaltButton(text.substring(1, text.length - 1).trim());
    }
    return SaltLabel(text);
  }
}

class _YamlSourceLine {
  final String raw;
  final int line;
  const _YamlSourceLine({required this.raw, required this.line});
}

class _GanttSourceLine {
  final String raw;
  final int line;
  final int column;
  const _GanttSourceLine({
    required this.raw,
    required this.line,
    required this.column,
  });
}

class _NwdiagSourceLine {
  final String raw;
  final int line;
  final int column;
  const _NwdiagSourceLine({
    required this.raw,
    required this.line,
    required this.column,
  });
}

sealed class _GanttItemBuilder {
  const _GanttItemBuilder();
}

class _GanttTaskBuilder extends _GanttItemBuilder {
  final String name;
  DateTime? explicitStart;
  DateTime? explicitEnd;
  int? relativeStartDays;
  int? relativeEndDays;
  String? startsAtRef;
  bool startsAtEnd = false;
  Duration? duration;
  Color? color;
  DateTime? resolvedStart;

  _GanttTaskBuilder({required this.name});
}

class _GanttMilestoneBuilder extends _GanttItemBuilder {
  final String name;
  final String? ref;
  final bool atEnd;
  final DateTime? explicitDate;
  DateTime? resolvedDate;

  _GanttMilestoneBuilder({
    required this.name,
    this.ref,
    this.atEnd = true,
    this.explicitDate,
  });
}

class _GanttSectionBuilder extends _GanttItemBuilder {
  final String title;
  const _GanttSectionBuilder(this.title);
}

class _MindmapLine {
  final int depth;
  final MindmapSide side;
  final Color? color;
  final String text;
  final int line;
  final int column;

  const _MindmapLine({
    required this.depth,
    required this.side,
    required this.color,
    required this.text,
    required this.line,
    required this.column,
  });
}

class _MindmapBuilder {
  final String text;
  final int depth;
  final MindmapSide side;
  final Color? color;
  final List<_MindmapBuilder> children = [];

  _MindmapBuilder({
    required this.text,
    required this.depth,
    required this.side,
    required this.color,
  });

  MindmapNode build() {
    return MindmapNode(
      text: text,
      depth: depth,
      side: side,
      color: color,
      children: List.unmodifiable(children.map((c) => c.build())),
    );
  }
}

class _DecodedRelArrow {
  final RelationshipKind kind;
  final bool reverse;
  final CrowFoot? fromCrowFoot;
  final CrowFoot? toCrowFoot;
  const _DecodedRelArrow(
    this.kind, {
    required this.reverse,
    this.fromCrowFoot,
    this.toCrowFoot,
  });
}

class _UseCaseArrow {
  final LineStyle lineStyle;
  final ArrowHead? head;
  final MessageDirection direction;
  final bool reverse;
  const _UseCaseArrow(this.lineStyle, this.head, this.direction,
      {this.reverse = false});
}

/// One side of a use-case relation as resolved by [_readUseCaseRelationEnd].
///
/// [declaredKind] is non-null when the syntax unambiguously identifies the
/// node — `:Display:` is always an actor, `(Name)` is always a use case. A
/// bare identifier has [declaredKind] = null so the caller can default it
/// (left endpoint -> actor, right endpoint -> use case) without overriding
/// any earlier declaration of the same alias.
class _UseCaseEnd {
  final String alias;
  final String? label;
  final UseCaseNodeKind? declaredKind;
  const _UseCaseEnd({
    required this.alias,
    this.label,
    required this.declaredKind,
  });
}

/// Parsed result of a PlantUML inline-style suffix (`#color;line.bold;text:c`)
/// on a use-case relation. Any field is null when the corresponding clause is
/// absent or unrecognized.
class _UseCaseInlineStyle {
  final Color? lineColor;
  final Color? textColor;
  final UseCaseLineStyle? lineStyle;
  const _UseCaseInlineStyle({
    required this.lineColor,
    required this.textColor,
    required this.lineStyle,
  });
}

class _ComponentRelEnd {
  final String alias;
  final bool declared;
  const _ComponentRelEnd(this.alias, {required this.declared});
}

class _IfHeader {
  final String condition;
  final String? thenLabel;
  const _IfHeader({required this.condition, this.thenLabel});
}

class _AutonumberState {
  int current = 1;
  int increment = 1;
  String format = '%d';
  bool stopped = true;
  List<int>? levels;
  String? lastDisplayed;

  void reset() {
    current = 1;
    increment = 1;
    format = '%d';
    stopped = true;
    levels = null;
    lastDisplayed = null;
  }
}

/// Result of parsing a `:Display name: [as Alias]` block. The
/// [displayName] has already been normalized (literal `\n` markers turned
/// into newlines); [alias] is null when no `as` clause was present so the
/// caller can derive a default.
class _ColonWrappedName {
  final String displayName;
  final String? alias;
  final String? stereotype;
  const _ColonWrappedName(this.displayName, this.alias, {this.stereotype});
}

class _DiagramDecorationBuilder {
  String? title;
  String? caption;
  HeaderFooter? header;
  HeaderFooter? footer;
  Legend? legend;
  SkinParams skin = const SkinParams();

  DiagramDecorations build() {
    return DiagramDecorations(
      title: title,
      caption: caption,
      header: header,
      footer: footer,
      legend: legend,
      skin: skin,
    );
  }
}

class _DecodedArrow {
  final LineStyle lineStyle;
  final ArrowHead head;
  final MessageDirection direction;
  final bool hidden;
  final Color? color;
  // Sequence "found" / "lost" message markers. Non-null when the arrow's
  // SOURCE or TARGET endpoint is anonymous (`[->`, `?->`, `->]`, `->?` and
  // their dashed / reverse variants).
  final MessageExternal? leftExternal;
  final MessageExternal? rightExternal;
  // Tail-end decoration peeled from a leading `o` / `x` glyph in the arrow
  // lexeme (`o->`, `x->`, `o<->o`, `x<->x`, `x->o`). For bidirectional
  // arrows the same shape is mirrored on both ends; for forward/backward
  // arrows it sits at the non-triangle endpoint.
  final EndpointDecoration? tailDecoration;
  // PlantUML "transmission duration" annotation embedded in the arrow
  // (`->(N)` / `(N)<-`). When non-null, layout renders the arrow as a
  // diagonal line with the head endpoint offset below the tail endpoint by
  // an amount proportional to N.
  final int? duration;
  const _DecodedArrow(
    this.lineStyle,
    this.head,
    this.direction, {
    this.hidden = false,
    this.color,
    this.leftExternal,
    this.rightExternal,
    this.tailDecoration,
    this.duration,
  });
}
