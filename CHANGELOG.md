# Changelog

## 0.11.0

### Added

- Sequence diagrams now support `hide unlinked`, `mainframe <label>`,
  nested participant boxes, inline actor declarations, participant
  stereotypes, `alt` / `else` tab and branch body colors, and
  PlantUML-style found / lost message endpoints (`?->`, `[->`, `->?`,
  `->]`).
- Sequence arrow support was expanded for all PlantUML head / tail
  decoration combinations, including leading `o` / `x` tail markers,
  bidirectional decorated arrows, edge-found / edge-lost variants, and
  transmission duration annotations such as `A ->(10) B` with
  `&`-synchronized messages.
- Use case diagrams now support colon-wrapped actors, parenthesized
  use cases, package / rectangle grouping, direction-hint arrows,
  generalization arrows, attached and free-standing notes, dotted note
  connectors, multi-line use-case labels with `--`, `==`, and
  `..Title..` separators, node stereotypes, and inline relation styling
  (`#color`, `line.bold`, `line.dashed`, `line.dotted`, `text:color`).
- JSON diagrams now accept `<style> ... </style>` blocks and
  `#highlight` directives as no-op styling metadata. Inline
  `json ... { ... }` blocks inside `@startuml` are recognized as JSON
  diagrams so mixed sources can parse instead of failing.
- Network diagrams now accept `nwdiag { ... }` wrappers, nested `group`
  blocks, semicolon-separated statements, comments, segment properties,
  anonymous top-level groups, and shared node names across networks.
- The example app now uses a structured sample catalog with sub-samples
  for sequence, use case, class, activity, component, state, object,
  deployment, timing, regex, network, wireframe, Archimate, Gantt,
  mindmap, WBS, EBNF, JSON, and YAML diagrams.
- Golden and parser coverage was expanded for the new sequence, use
  case, JSON, nwdiag, class-regression, and inline-markup cases.

### Changed

- The example app now shows selected diagram families as a scrollable
  list of editable sub-sample cards, each with its own live preview,
  instead of loading only one sample source at a time.

### Fixed

- Class diagram parsing now tolerates additional PlantUML forms reported
  in regression cases: colored / stereotyped package blocks, dotted
  package names, `scale ... width`, `set separator`, lollipop interface
  relations, direction-hint arrows, and association-class connectors.
- Sequence layout now excludes anonymous found / lost endpoints from the
  participant order, filters emptied boxes when `hide unlinked` is used,
  and keeps synchronized duration arrows from over-expanding or
  overlapping later events.

## 0.10.0

### Added

- Sequence diagrams now carry explicit note background colors through to
  layout, including `note ... #color` forms.
- Sequence activation bars now support `activate X #color`, preserving
  nested activation colors in the rendered bars.
- Sequence parsing now accepts additional note variants and endings such
  as `hnote`, `rnote`, `endnote`, `endrnote`, and `endhnote`.
- Sequence diagrams now support delay separators written as `|||` and
  labeled skip separators such as `... Some delay ...`.
- Sequence parsing now handles `return ...` as a dashed reply from the
  most recent forward message and consumes `autoactivate` directives so
  diagrams using PlantUML auto-activation syntax continue to render.
- Inline markup support was expanded with Creole / PlantUML-style
  monospace (`""text""`), `--strike--`, colored underline / strike /
  wavy underline tags, text backgrounds, `<font ...>` color / size
  attributes, and deterministic image placeholders.
- Sequence labels and notes now expand `<U+HHHH>` unicode escapes and
  `%autonumber%` placeholders.
- Sequence messages now accept a per-message `#color` after the target,
  in addition to arrow-embedded color syntax.
- Golden coverage was expanded for autoactivate / return, colored
  activations, delay separators, Creole markup, and advanced inline
  markup cases.

### Changed

- Autonumber labels now close any still-open inline markup tags before
  appending message text, preventing the autonumber format styling from
  leaking into the rest of the label.
- The example app editor now debounces preview rendering, preserves the
  cursor when loading samples / files, supports select-all shortcuts, and
  suppresses a known macOS keyboard state assertion.

### Fixed

- Sequence notes and labels that extend left of the first lifeline now
  shift the diagram right instead of being clipped off-canvas.
- Note body lexing now preserves inline separator / markup text inside
  labeled skip separators instead of re-tokenizing it.

## 0.9.0

### Added

- Class diagrams now use the shared `graph_layout` layered layout and
  orthogonal edge router. Directed relationships assign classes to
  layers, sibling ordering uses barycenter-style crossing reduction,
  offset edges route through dogleg segments, same-row edges can detour
  around intervening boxes, and parallel / reverse relationships are
  separated into lanes.
- Sequence diagrams now support `group` / `partition` blocks, richer
  participant declarations (`#color`, `order N`, and PlantUML-style
  multi-line `[ ... ]` labels with title / separator / code sections),
  quoted inline participants with `"Display" as Alias`, and `note left`
  / `note right` forms without an explicit `of X` target.
- Sequence `autonumber` handling now covers rest-of-line formats,
  PlantUML `0` / `#` placeholders, `stop` / `resume` semantics,
  multi-level counters such as `1.1.1`, and `inc <level>` updates.
- Sequence arrow parsing and rendering now covers additional PlantUML
  variants, including half arrows, circle / cross heads, bidirectional
  forms, and colored arrows.
- Class diagrams now accept implicit class declarations from
  relationships, additional declaration kinds (`circle`, `diamond`,
  `dataclass`, `metaclass`, `protocol`, `stereotype`, `struct`), the
  `()` / `<>` shorthand forms, and extended relationship head markers
  (`#`, `x`, `}`, `+`, `^` / `v`).
- The example app now includes a sample picker for multiple diagram
  types, an "Open PUML" file action, and a zoomable / pannable preview.
- Golden coverage was expanded for the new sequence, class, activity,
  state, and topology rendering cases.

### Changed

- The release workflow now runs `flutter test --exclude-tags golden`
  because golden output is platform-font dependent.
- Golden test helpers now set the requested surface size explicitly so
  large diagram goldens render at their intended dimensions.

### Fixed

- Sequence diagrams that use `partition` groups no longer get
  misrouted to the activity parser when sequence participant markers are
  present.
- Sequence group frames now span the actual rendered leftmost and
  rightmost lifelines even when participant ordering is changed.
- Self messages now reserve space for multi-line labels and can render
  backward self-message loops on the left side of the lifeline.
- Notes without an explicit target now anchor to the nearest suitable
  participant instead of requiring `note left/right of X`.

## 0.8.0

### Added

- EBNF diagrams now render as PlantUML-style railroad tracks: each
  rule becomes a labeled track with entry/exit dots, sequences are
  connected horizontally, alternations branch with rejoin points, and
  repetitions draw a U-loop back to the start. Previously EBNF bodies
  rendered as raw text dumps. New `EbnfParser` (recursive-descent
  tokenizer + parser) backs the AST, exposed via `EbnfRule` and a
  sealed `EbnfExpr` hierarchy.
- Component / deployment parser now honors the
  `left to right direction` and `top to bottom direction` directives
  (default remains `top to bottom`).

### Changed

- Component / deployment layout: top-level containers and free nodes
  are now placed in BFS-layered order driven by their relations
  (default top-to-bottom stacks each rank as a row; with
  `left to right direction` each rank becomes a column). Sibling
  containers inside a parent container (e.g. multiple subnets inside
  a VPC) lay out as a row by default so peer groupings render
  side-by-side; leaf node children of a container continue to stack
  vertically. Previously every top-level container went into a single
  horizontal row regardless of flow, and nested children always
  stacked vertically.
- Mindmap: a child without an explicit `+` / `-` side marker now
  defaults to the **right** side (matching PlantUML's default
  behavior). Previously auto-side children alternated left/right,
  which split simple roadmaps across both sides of the root.

### Fixed

- State diagram: transitions whose endpoint is the `[*]` pseudo-state
  (initial or final) are now drawn. Previously the emit loop looked
  up the raw `[*]` key in the node table, which the layout had
  already split into distinct `[*]:initial` / `[*]:final` entries, so
  the arrow was silently dropped and the start/end dots floated
  disconnected.
- State diagram: a bidirectional pair of transitions between the same
  two states (e.g. `A --> B : submit` / `B --> A : request changes`)
  now renders as two parallel arrows offset perpendicular to the
  edge axis, so both labels remain readable. Previously both
  transitions drew along the same center-to-center axis and stacked
  their labels on top of each other.

## 0.7.9

### Fixed

- Preprocessor: `!theme NAME` is silently consumed (no actual theme
  loading) so sources that start with `!theme spacelab` no longer fall
  through as an unrecognized line.
- Preprocessor: `!$var = value` assignment-style syntax stores the
  value in the macro table under the `$`-prefixed key, so later
  references like `$var` (in content lines and `!if` expressions) and
  `defined($var)` resolve correctly. The trailing value's surrounding
  double quotes, if present, are stripped.
- Preprocessor: `!procedure $NAME($a, $b, ...)` … `!endprocedure`
  captures the body as a multi-line template with positional
  parameters and stores it in a separate procedure table. A content
  line that starts with `$NAME(args)` invocation is expanded in place:
  arguments substitute `$a`, `$b`, … throughout the body (quoted-string
  args are unquoted before substitution) and the resulting body lines
  are themselves macro-expanded.
- Preprocessor: unknown `!directive` lines (anything not in the
  recognized set) are silently consumed instead of leaking through to
  the lexer.
- Parser (component): `component "Name" as Alias #Color` now accepts
  and skips the trailing `#color` token, so procedure expansions like
  `component "Gateway" as Gateway #LightBlue` parse cleanly.

## 0.7.8

### Changed

- JSON / YAML data diagrams now render in PlantUML's canonical
  "linked tables" style: every `DataObject` and `DataArray` becomes
  its own standalone two-column table laid out left-to-right by
  depth. Where a parent's value is a nested object/array, the
  parent's value cell shows a small connector dot and a dashed
  line links it to the top of the child table. Previously every
  nested value rendered as a recursively indented sub-table inside
  the parent's value cell, which made deep documents balloon both
  horizontally and vertically. Existing `json_diagram.png` and
  `yaml_diagram.png` goldens are regenerated.

## 0.7.7

### Fixed

- Gantt diagram date axis labels no longer overlap. The tick step now
  enforces a minimum 78px gap between labels so date strings like
  `2026-05-25` (about 70px wide at fontSize 10) have room to render.
  Previously short timelines (≤14 days) emitted a label every day at
  14px spacing, producing illegible smudge text.

## 0.7.6

### Fixed

- Lexer: `!`-prefixed directives at the start of a line (e.g.
  `!pragma teoz true`, `!theme spacelab`, `!if`, `!else`, `!endif`,
  `!$var = value`) are now silently consumed instead of raising
  `LexerException("Unexpected '!'")`. The full body between
  `!procedure ... !endprocedure` (and `!function`/`!definelong`)
  is also skipped, so procedure definitions no longer pollute
  the token stream.
- Lexer: lines starting with `$` (procedure-call invocations such
  as `$service("Gateway", #LightBlue)`) are silently skipped at
  line start, matching the lenient handling of `!` directives.
- Lexer: `&` at the start of a line (PlantUML teoz "in parallel
  with previous" continuation) is consumed silently so the rest
  of the line parses as a normal sequence message.
- Lexer: bidirectional arrows `<->`, `<-->`, etc. are now
  recognized as `arrow` tokens.
- Lexer: new `@startebnf`/`@endebnf` and `@startregex`/`@endregex`
  diagram boundaries. The body is captured as raw text and
  rendered as a monospace code listing.
- Parser (timing): added `binary` lane kind, rendered as a
  two-state robust lane. `highlight ...` and `hide ...` lines are
  silently skipped.
- Parser (state): `hide`/`show` directives are silently consumed
  in both top-level and nested state bodies. `state H <<history>>`
  declarations now parse — the trailing stereotype is accepted
  after the state name.
- Parser (gantt): `title ...` is accepted as a no-op decoration.
  `<weekday> are closed` and `[Task] requires N people` lines are
  silently skipped. New compound forms parse:
  `[Task] lasts N days and starts at [Other]'s end` and
  `then [Task] lasts N days` (chains to the previous task's end).
- Parser (json): `#highlight` / `#`-prefixed directive lines in
  the JSON body are stripped before `jsonDecode`, so the
  highlight annotation no longer breaks the parse.
- Parser (yaml): `#highlight` lines are stripped. YAML anchors
  (`key: &name value`), references (`key: *name`), and merge keys
  (`<<: *name`) are now supported. Anchored values are captured
  and inlined when referenced; merge keys expand the referenced
  object's entries into the current mapping.
- Parser (sequence): `return ...`, `break ...`, and teoz timing
  markers like `{name}` at the start of a line (including the
  bidirectional `{start} <-> {end}` SLA-window form) are silently
  consumed so the surrounding diagram still parses.
- Parser (component): top-level `note <pos> of X ... end note`
  blocks and `hide`/`show` directives are silently skipped so
  deployment-style diagrams with annotation notes parse cleanly.
- AST: new `EbnfDiagram` with a `text` field; rendered by the new
  `EbnfLayout` as a bordered monospace code block. `TimingLaneKind`
  gains a `binary` variant.
- Colors: expanded the named-color table with `lightyellow`,
  `lightpink`, `lightcyan`, `salmon`, `gold`, `silver`, `cyan`,
  `magenta`, and other CSS standard names so `#LightYellow`,
  `#Salmon`, `#Gold`, etc. parse without "Unknown color" errors.

## 0.7.5

### Fixed

- Lexer: a `-` inside identifier-like words (e.g. `Multi-region`,
  `omni-viewer.app`, `us-east-1`) no longer raises
  `LexerException("Unexpected '-'")`. Identifier scanning now
  greedily consumes `-` when it sits between two
  letter/digit/underscore characters, so identifiers may contain
  internal hyphens. Arrow scanning (`->`, `-->`, `-[#color]->`,
  `<-`, etc.) is unaffected because arrows always start at a
  position that is not inside an identifier.
- Lexer: backslash escape sequences inside `"..."` string literals
  are now interpreted. `\n` becomes an actual newline, `\"`
  becomes a literal double quote, and `\\` becomes a single
  backslash. This matches PlantUML's behaviour and makes labels
  like `"CDN Edge\n{global}"` render as two lines.
- Parser: use-case diagram dispatch (`usecase` / `rectangle`)
  now requires the keyword to appear at the start of a line, so
  `skinparam componentStyle rectangle` no longer accidentally
  routes the diagram to the use-case parser.
- Component / deployment diagrams: added a new `storage` node
  keyword. `storage "Object Store" as S3` parses as a
  `ComponentNode` with `ComponentNodeKind.storage` and renders
  as a `<<storage>>`-stereotyped box; `storage "Bucket" { ... }`
  parses as a `ComponentContainer` with `ContainerKind.storage`
  (and nests inside other containers like `node`).
- Component / deployment diagrams: nested-container parsing now
  also accepts `database`/`queue`/`storage` container forms
  inside another container body, so deeply nested deployment
  topologies like `frame { node { node { node { ... } } } }`
  parse without throwing.

## 0.7.4

### Fixed

- Component diagrams: `database "X" as DB` and `queue "Q" as QQ`
  standalone node declarations now render as cylinder / queue-pipe
  shapes via `SceneSymbol` instead of being miscategorized as
  generic `<<component>>` boxes. Two new
  `ComponentNodeKind.database` and `ComponentNodeKind.queue`
  values are emitted by the parser. The container forms
  (`database X { ... }` / `queue X { ... }`) still parse as
  containers via lookahead for `{`.
- Component diagrams: relations whose endpoint is the alias of a
  container (e.g. `cloud "Payment Gateway" as PG` followed by
  `[Payment Adapter] --> PG`) now resolve to the container's
  rect, so the arrow is actually emitted instead of being silently
  dropped. `ComponentContainer.alias` is now persisted on the AST.
- Component diagrams: relation arrows now route as three-segment
  Manhattan paths instead of straight diagonals, and detour
  sideways when the straight path would pass through another
  node's rect. This fixes the case where an arrow between two
  nodes in the same container visually cut through a third
  intervening node (e.g. `Order Service --> Inventory Service`
  passing through `Payment Adapter`).

## 0.7.3

### Added

- Class diagram header stereotype: `class Foo <<Aggregate>>` and
  `interface Repository<T>` style declarations now parse and render
  with the stereotype text shown in a small italic font above the
  class name (the same area used by the synthetic `<<interface>>` /
  `<<enum>>` etc. labels). A new `String? stereotype` field is
  available on `ClassDecl`.
- Generic type parameters on class / interface / record headers:
  `class AggregateRoot<ID>` and nested forms such as
  `interface Repository<T extends AggregateRoot<ID>, ID>` are
  accepted; the generics text is appended to the displayed header
  name as `Name<...>` and stored on a new `String? generics` field.
  Generics on relationship endpoints (e.g. `Repository<T> <|.. R`)
  are accepted and dropped.
- `record` class kind. `record Money { amount: BigDecimal }` parses
  as a `ClassDecl` with `ClassKind.record_` and renders with a
  `<<record>>` stereotype label.
- Free-floating notes in class diagrams: `note "text" as N1`
  declares a `FreeNote` attached to alias `N1`; subsequent
  `N1 .. SomeClass` lines connect the note to the class with a
  dashed line. Multi-line `note <pos> of Class ... end note`
  blocks now also work inside class diagrams and are stored as
  `FreeNote` entries with `attachedTo` set. Notes render as
  yellow `SceneNote` shapes placed below the class grid.
- `package "label" <<Stereotype>> { ... }` wrapper blocks are
  accepted at the top level of a class diagram; the wrapper is
  unmodeled and its body classes / relationships are flattened
  into the surrounding diagram.
- `hide empty members` / `hide circle` / `hide ...` directives at
  the top of a class diagram are silently consumed.

### Fixed

- Lexer no longer throws `Unexpected '<'` for the angle bracket
  forms used in class diagrams. `<<...>>` (followed by anything
  other than `-`) is now a `TokenType.stereotype` token and a
  single `<...>` (with balanced nested angle brackets) is a
  `TokenType.generics` token. The existing arrow forms (`<-`,
  `<--`, `<<-`, `<<--`, `<|--`, `<|..`) are preserved.

## 0.7.2

### Fixed

- Activity diagram now accepts `detach`, `break`, and `kill` terminator
  keywords (previously the parser rejected them as `Unexpected token in
  activity diagram`).
- Activity diagram `while` and `repeat while` loops now accept the
  PlantUML `is (label)` (yes-edge) and `not (label)` (no-edge / repeat
  exit) modifiers, e.g. `repeat while (cond) is (yes) not (no)`. Labels
  render as small italic text next to the corresponding loop arrows.

## 0.7.1

### Fixed

- Activity diagram tail arrows no longer cross through other branches'
  content boxes. The Manhattan tail's horizontal segment now sits just
  above the merge diamond (below all branches' content) instead of at
  the source-to-merge midpoint, which previously caused short branches
  to draw their tail through deeper sibling branches.
- Class / object / ER diagram BFS levelling now counts every directed
  relationship (composition, aggregation, association arrows,
  dependency, realization) toward a class's indegree, not just
  inheritance. Diagrams that use only associations (no inheritance) now
  lay out top-down by relationship direction instead of collapsing
  every class into a single row.

## 0.7.0

### Changed

- Activity diagram `if` / `elseif` / `else` and `fork` blocks now route
  their branches side-by-side instead of stacking them vertically on the
  spine. Each branch occupies its own column laid out horizontally
  (column width derived recursively from a `_measureSubtree` walk so
  nested decisions expand their enclosing column), with three-segment
  Manhattan connector arrows from the decision diamond (or top fork
  bar) down into each column and matching tail arrows up into the
  merge diamond (or bottom fork bar) below. The `yes` / `no` /
  user-supplied condition labels render next to the horizontal segment
  of each connector. `while` and `repeat` blocks keep their existing
  vertical layout.

## 0.6.0

### Added

- Universal directive support. The six top-of-diagram directives
  `title`, `header`, `footer`, `caption`, `legend`, and `skinparam`
  are now accepted by every keyword-dispatched diagram type
  (sequence, class, use case, activity, state, component, timing) —
  not just sequence diagrams. Previously the non-sequence parsers
  threw `ParserException` when a source started with `title Foo`,
  which blocked the common PlantUML convention of "first line is the
  diagram title." Decorations are stored on a new `DiagramDecorations`
  holder accessible via `diagram.decorations` on every `Diagram`
  subclass; rendering uses a new `wrapWithDecorations` helper so
  every layout draws the header/title above and
  legend/caption/footer below its inner content.
- Use-case-diagram `left to right direction` and
  `top to bottom direction` layout-orientation hints are now parsed.
  `left to right direction` sets `UseCaseDiagram.leftToRightDirection`
  to `true`; `top to bottom direction` is parsed and ignored (the
  existing layout already places actors on the left and use cases
  on the right). Unknown variants are not consumed.
- Component diagrams now recognize the `database` node keyword (as
  a synonym for `component`) so deployment-style sources that
  declare `database "Orders DB" as ODB` parse without throwing.

### Changed

- `SequenceDiagram` no longer exposes the individual `title`,
  `caption`, `header`, `footer`, `legend`, and `skin` constructor
  parameters and fields. They live on the new `decorations` field
  (a `DiagramDecorations` instance) instead. Callers constructing
  `SequenceDiagram` instances directly should migrate from
  `SequenceDiagram(title: 'X', ...)` to
  `SequenceDiagram(decorations: DiagramDecorations(title: 'X'), ...)`.

## 0.5.0

### Added

- PlantUML preprocessor support. A new pure-Dart `Preprocessor` runs
  as a string-to-string transformation BEFORE the existing
  `Lexer` → `Parser` pipeline, so the diagram parser never sees
  preprocessor directives. Supported directives: `!define MACRO value`
  (simple text substitution); `!define MACRO(a,b) body` (function-like
  macro with positional substitution); `!undef MACRO` (remove a macro);
  `!if expr` / `!elseif expr` / `!else` / `!endif` (conditional
  inclusion with arbitrary nesting); `!include path` (inline another
  file's content, recursively preprocessed in the same context);
  `!startsub id` / `!endsub` (capture a named subsection of a file);
  `!includesub path!sub_id` (also `!include path!sub_id`) — include only
  a named subsection; `!pragma key value` (parsed and ignored, reserved
  for engine settings). Macro substitution scans content lines for known
  macro names and replaces them, but skips text inside double-quoted
  string literals (`"..."`) so quoted labels are never munged.
  `!function` / `!procedure` / `!return` / `!include_many` are reserved
  but skipped in v1. The `!if` expression language supports identifier
  lookup (a macro name evaluates to its body, or empty string if
  undefined), integer and double-quoted string literals, comparison
  operators `==` / `!=` / `<` / `>` / `<=` / `>=` (numeric when both
  sides are integers, lexicographic otherwise), logical `&&` / `||` /
  `!`, parenthesized sub-expressions, and a built-in `defined(NAME)`
  predicate. Bare expressions are truthy when non-zero / non-empty.
  Adds a `FileLoader` typedef (`String Function(String path)`) for
  resolving `!include` paths to text; `!include` raises
  `PreprocessorException` when the loader is null, when the loader
  throws, or when a circular include chain is detected. Other failure
  modes (unterminated `!if`, `!endif` without a matching `!if`,
  `!elseif` after `!else`, unterminated `!startsub`, unknown
  `!includesub` id, malformed expression) also raise
  `PreprocessorException` carrying the offending line number.
- `PumlView.fileLoader` parameter that plumbs a `FileLoader` through to
  the preprocessor so widget callers can opt in to `!include` /
  `!includesub` support without bundling `dart:io` (the default is null,
  which leaves `!include` unsupported but is fine for the common case of
  inline-only sources). The widget's `build` now calls
  `Preprocessor(fileLoader: fileLoader).preprocess(source)` before the
  lexer; sources with no `!` directives pass through verbatim so
  existing diagrams are byte-identical.

## 0.4.0

### Added

- Network (nwdiag) diagrams. Network diagrams use a dedicated
  `@startnwdiag` / `@endnwdiag` boundary and describe a set of
  horizontal network segments with attached nodes. Adds two new
  lexer tokens (`startNwdiag` / `endNwdiag`); the body is captured
  via the existing raw-line `inDataBody` mode so each user line is
  preserved verbatim as a `text` token (the parser does all of the
  heavy lifting on the captured strings, so PlantUML tokens like
  `[`, `]`, `{`, `}`, and `=` inside an nwdiag line are not
  mistaken for arrows / class dividers / string literals by the
  shared lexer). Adds a `NetworkDiagram` AST subclass with a
  `List<NetworkSegment> networks` field; each `NetworkSegment`
  carries a name, an optional segment-level address, and a list of
  `NetworkNode` (name plus optional address). The parser routes
  `@startnwdiag` to `_parseNetworkDiagram`, which walks the
  captured lines and dispatches each through a small set of
  regexes — `network NAME {`, `address = "..."`,
  `nodeName [attr = "value"]`, and a bare `nodeName` form — opening
  a new segment on `network NAME {`, closing it on `}`, and
  collecting node lines into the currently-open segment. A new
  `NetworkLayout` renders each segment as a horizontal blue
  `SceneBox` bus bar with the network name (and optional address
  in a smaller gray line below) printed in a left-hand label
  column, distributes the segment's nodes evenly along the bus
  width as small white `SceneBox` rectangles, prints each node's
  name centered inside (and the node address in a smaller line
  below if present), and joins each node to the bus with a
  vertical `SceneLine`. Multiple segments stack vertically with
  a fixed gap between rows. For v1 simplicity, a node that
  appears in multiple networks is rendered once per segment as
  an independent node (it appears duplicated rather than as a
  single shared node vertically spanning all of its networks);
  "shared node spanning" is a v2 enhancement. The embedded
  `@startuml` + `nwdiag { ... }` form that PlantUML also accepts
  is not supported in v1 — use the dedicated `@startnwdiag` /
  `@endnwdiag` boundary instead.
- Gantt diagrams. Gantt uses a dedicated `@startgantt` /
  `@endgantt` boundary and describes a project schedule as a
  sequence of dated tasks, point-in-time milestones, and section
  dividers. Adds two new lexer tokens (`startGantt` / `endGantt`);
  the body is captured via the existing raw-line `inDataBody`
  mode so each user line is preserved verbatim as a `text` token
  (the parser does all of the heavy lifting on the captured
  strings, so PlantUML tokens like `[`, `]`, `--`, and `'s`
  inside a Gantt line are not mistaken for arrows / class
  dividers / string literals by the shared lexer). Adds a
  `GanttDiagram` AST subclass with `projectStart: DateTime` and
  a sealed `GanttItem` hierarchy (`GanttTask` carrying name +
  start + duration + optional color, `GanttMilestone` carrying
  name + date, `GanttSection` carrying a title). The parser
  routes `@startgantt` to `_parseGanttDiagram`, which dispatches
  each captured line through a small set of regexes —
  `Project starts YYYY-MM-DD`, `[Name] lasts N day|days|week|
  weeks|month|months`, `[Name] starts YYYY-MM-DD`,
  `[Name] starts at [Other]'s end|start`, `[Name] happens at
  [Other]'s end|start | YYYY-MM-DD`, and `-- Title --` — and
  builds an intermediate task / milestone / section list. A
  second walk resolves each task's absolute start by following
  its `starts at [X]'s end|start` chain back to either an
  explicit ISO date or the project start (with a `visiting` set
  to detect circular references); milestones are then resolved
  against the already-resolved task starts. `weeks` are stored
  as `N * 7` days and `months` as `N * 30` days. A new
  `GanttLayout` computes the overall date range (min start to
  max end), maps days to X with a fixed 14 px-per-day scale,
  stacks one row per item vertically with task / milestone /
  section names in a left-hand label column, and emits each
  task as a blue `SceneBox` bar with a darker blue stroke, each
  milestone as a small amber `SceneDiamond`, each section as a
  bold-titled `SceneLine` across the full plot width, and a
  thin top axis with date-labeled ticks (one per day / week /
  month depending on span). Color modifiers
  (`[Name] is colored in red`) are accepted by the parser and
  applied to the task fill; dependency arrows between tasks,
  pauses, and weekends-off scheduling are not yet supported.
- Salt wireframe diagrams. Salt uses a dedicated `@startsalt` /
  `@endsalt` boundary and describes a UI mockup as a grid of
  widgets wrapped in `{` `}`; each newline is a row and `|`
  separates cells within a row. Adds two new lexer tokens
  `startSalt` / `endSalt`; the body is captured via the existing
  raw-line `inDataBody` mode so each user line is preserved
  verbatim as a `text` token (the parser splits cells itself, so
  PlantUML tokens like `[`, `(`, and `--` inside a cell are not
  mistaken for arrows or class dividers). The parser routes
  `@startsalt` to `_parseSaltDiagram`, strips the opening `{` and
  closing `}` lines, and parses each remaining row: a line of `--`
  becomes a divider `SaltRow`; otherwise the line is split on `|`
  and each cell is classified with a small regex / prefix-match
  heuristic into one of `SaltLabel`, `SaltButton` (`[Label]`),
  `SaltTextField` (`"text"`), `SaltRadio` (`(X) Label` /
  `( ) Label`), or `SaltCheckbox` (`[X] Label` / `[ ] Label`).
  Cell detection is whitespace-tolerant. A new `SaltLayout` sizes
  the grid as a table — column `j` width is the max measured cell
  width in column `j` across all rows, row `i` height is the max
  measured cell height in row `i` — and emits each cell as the
  appropriate scene shape inside an outer `SceneBox` with padding:
  buttons render as a gray `SceneRoundedBox`, text fields as a
  white `SceneRoundedBox` with italic `SceneText`, radios as a
  filled-or-ring `SceneCircle` plus label, checkboxes as a small
  `SceneBox` (with a two-segment check-mark `SceneLine` pair when
  checked) plus label, and dividers as a full-width `SceneLine`
  across the inner content area. Tabs, dropdowns, trees, and
  advanced widgets are not yet supported.
- JSON and YAML data diagrams. JSON diagrams use a dedicated
  `@startjson` / `@endjson` boundary; YAML diagrams use
  `@startyaml` / `@endyaml`. Adds four new lexer tokens
  (`startJson` / `endJson` / `startYaml` / `endYaml`) and a new
  `inDataBody` raw-line capture mode in the lexer that preserves
  each body line verbatim (including leading whitespace, which YAML
  parsing depends on) and emits it as a `text` token until the
  matching end directive. Adds a `DataDiagram` AST subclass with a
  `DataNode root` (sealed: `DataObject`, `DataArray`, `DataScalar`)
  and a `format: DataFormat.{json, yaml}` field; `DataObject`
  preserves insertion order by using `List<MapEntry<String,
  DataNode>>` rather than a regular `Map`. The parser routes
  `@startjson` to `_parseJsonDiagram` (which concatenates the body
  text tokens and feeds them to `dart:convert`'s `jsonDecode`,
  then walks the resulting `Map` / `List` / primitives into the
  `DataNode` tree; `Map` is a `LinkedHashMap` so key order is
  preserved) and `@startyaml` to `_parseYamlDiagram`. YAML uses a
  small built-in subset parser (mappings, block sequences, and
  scalars only — no anchors, flow style, multi-line strings, or
  explicit tags) so the package adds no new pub.dev dependencies.
  Malformed input on either path raises `ParserException` carrying
  the original line / column. A new `DataLayout` renders each
  object / array as a vertical `SceneBox` table: the left column
  holds the key (or array index suffixed with `:`) on a light gray
  background and the right column holds the value. Nested objects
  and arrays render as sub-tables placed inside the value cell so
  the layout nests recursively. Scalar values render as
  `SceneText` with type-based coloring (strings green, numbers
  blue, booleans purple, `null` italic gray); string values are
  rendered in double quotes for unambiguity. Row dividers are
  drawn with `SceneLine`.
- WBS (work breakdown structure) diagrams. Uses a dedicated `@startwbs` /
  `@endwbs` boundary and reuses the mindmap's indented-tree syntax
  (one `*` per depth level) but renders as a top-down hierarchical tree
  instead of a horizontal radial mindmap. Adds two new lexer tokens
  `startWbs` / `endWbs`; the existing `inMindmapBody` raw-line capture
  was generalized to `inIndentedTreeBody` and parameterized by an end
  keyword so both `@endmindmap` and `@endwbs` reuse the same scanner.
  The parser routes `@startwbs` to `_parseWbsDiagram` which delegates
  to a shared `_parseIndentedTree` helper (factored out of the
  existing mindmap path); both diagrams reuse `MindmapNode` since the
  tree data is identical. Adds a `WbsDiagram` AST subclass with an
  optional `MindmapNode root`. A new `WbsLayout` walks the tree and
  computes each subtree width as `max(own node width, sum of
  children's subtree widths + horizontalGap × gaps)`, then places the
  root at the top with horizontal center equal to its subtree's
  center; each child level is offset down by the parent's height plus
  a vertical gap, and each child is placed inside its allocated
  subtree band so its center sits above its own children. Nodes
  render as `SceneRoundedBox` (root yellow, leaves white) and
  parent-to-child connectors render as `SceneLine` segments: a single
  vertical line when the child is directly below the parent, or a
  three-segment manhattan path (down, across, down) when their X
  coordinates differ.
- Mindmap diagrams. Mindmaps use a dedicated `@startmindmap` /
  `@endmindmap` boundary (distinct from the shared `@startuml` /
  `@enduml` used by every other diagram kind) and describe a tree
  by indenting each node with leading `*` characters (one per depth
  level). Adds two new lexer tokens `startMindmap` / `endMindmap`
  (per-kind boundary tokens rather than a generalized
  `directiveStart` / `directiveEnd` pair, to keep the lexer simple
  and avoid touching the ~50 `startUml` / `endUml` references in
  existing code paths; future per-kind boundaries should follow the
  same pattern). A new lexer `inMindmapBody` mode (similar to the
  existing multi-line note / legend / class body modes) captures
  every line between `@startmindmap` and `@endmindmap` as a single
  raw `text` token so the parser can split the line itself without
  the `*` characters being mistaken for arrows or stars. The parser
  routes to `_parseMindmapDiagram` whenever the first directive is
  `@startmindmap`; this dispatch runs before the existing
  `@startuml` body auto-detection and does not interact with it.
  Adds a `MindmapDiagram` AST subclass with an optional `MindmapNode
  root` and a `MindmapNode` (`text`, `depth`, `side: MindmapSide
  .{auto, left, right}`, optional `color`, and a `children` list).
  Each input line is parsed as `[+|-]\**+ [[#color]] text`: the
  leading `+` forces the node to the right side, `-` forces it left,
  the run of `*` characters sets the tree depth, and an optional
  `[#color]` modifier (named or hex, same set as arrow `[#color]`)
  fills the node's box. Tree assembly uses a stack-of-ancestors
  algorithm so a deeper line attaches to the most recent shallower
  line; depth jumps and multiple root nodes raise
  `ParserException`. A new `MindmapLayout` walks the tree and
  produces a horizontal radial layout: the root sits in the middle
  as a yellow `SceneRoundedBox`, top-level children with no
  explicit side prefix are auto-balanced by alternating right/left
  (first auto child goes right, second left, third right, …) while
  explicit `+` / `-` prefixes pin the child to that side; each
  descendant inherits its top-level ancestor's side. On each side
  the layout reserves a slot per depth (`depth × horizontalGap`
  from the root) and vertically stacks subtrees so siblings never
  overlap, centering each subtree on its allocated band. Child
  nodes render as white `SceneRoundedBox` shapes (or the requested
  `[#color]` fill); each parent-to-child connector is a straight
  `SceneLine` from the parent's outer edge to the child's inner
  edge, drawn in gray. The multi-line text box form (`**: text;`)
  is not yet supported.
- ER (entity-relationship) diagrams. Implemented as a thin extension of
  the class diagram infrastructure rather than a new `Diagram` subclass:
  adds an `entity_` variant to `ClassKind`, a `required` flag and a
  `stereotype` field on `Field`, and a `CrowFoot` enum (`one`,
  `zeroOrOne`, `zeroOrMany`, `oneOrMany`) plus `fromCrowFoot` /
  `toCrowFoot` fields on `Relationship`. The parser recognizes `entity
  Name { ... }` headers (the `entity` keyword routes to the class
  diagram only when followed by a `{` body so the existing sequence
  `entity` participant keyword still works), parses field lines with a
  leading `*` as required and a trailing `<<PK>>` / `<<FK>>` form as
  the field's stereotype, and decodes crow's foot relationship arrows
  whose endpoints are `||` / `o|` / `o{` / `|{` on the right side and
  their mirrored forms `||` / `|o` / `}o` / `}|` on the left side, with
  either `--` (solid) or `..` (dashed) bodies. A new `_scanCrowFootArrow`
  pre-pass runs from the lexer's `|` and `}` entry points before the
  existing `doublePipe` / `rightBrace` handlers so crow's foot arrows
  lex as a single `arrow` token while the `||50||` sequence separator
  and standalone braces continue to lex unchanged. `ClassLayout`
  renders entity headers with an `<<entity>>` stereotype label and,
  when a relationship carries `fromCrowFoot` / `toCrowFoot`, omits the
  regular arrow head and emits a new `SceneCrowFoot` scene shape at
  each marked endpoint (position, angle along the line, and kind);
  the renderer paints the crow's foot as a perpendicular tick for
  "one", a small white circle for the "zero" part, and a three-pronged
  crow for the "many" part.
- Timing diagrams. The parser dispatches to a `TimingDiagram` when it
  sees the `robust` / `concise` / `clock` lane keywords or an
  `@<number>` time cursor at the start of a line. The discriminator
  runs ahead of activity so timing wins when these markers are
  present. Adds a `TimingDiagram` AST subclass with `TimingLane`
  (`alias`, `label`, `kind: TimingLaneKind.{robust, concise, clock}`,
  optional `clockPeriod`) and a sealed `TimingEvent` hierarchy with
  `StateChange` (`time`, `lane`, `state`) and `TimingArrow` (`time`,
  `from`, `to`, optional `label`). Supported syntax: `robust "Label"
  as Alias` / `concise "Label"` / `clock "Label" with period N` lane
  declarations, `@<integer>` time-cursor markers that set the parser's
  current time, `<alias> is <StateName>` state assignments (states
  persist until changed), and `<alias> -> <alias> : label` arrow
  annotations between lanes at the current time. A new `atTime` lexer
  token recognizes `@` followed by digits and emits the numeric
  lexeme; `@startuml` / `@enduml` continue to lex as before because
  the digit-prefix check fires first. A new `TimingLayout` renders a
  horizontal time axis with tick marks at every used time across the
  top, stacks lanes vertically below, and maps time to X
  proportionally (smallest time pinned to the plot's left edge,
  largest to the right, intermediates by linear interpolation; each
  adjacent pair gets at least a 60 px gap). Robust lanes draw each
  state as a horizontal `SceneLine` segment whose Y position is
  chosen from the alphabetically-sorted set of states seen on the
  lane, with a vertical `SceneLine` edge at each transition and the
  state name printed above each segment. Concise lanes draw a single
  horizontal line with the state name above each segment and a small
  vertical tick at each transition. Arrows render as a vertical
  `SceneLine` with a filled arrow head at the target lane. Clock
  lanes parse and reserve space but render as an empty labeled band
  in v1; highlighted time ranges are not yet supported.
- Deployment diagrams. Implemented as a thin extension of component
  diagrams rather than a new `Diagram` subclass:
  `_looksLikeComponentDiagram` now also recognizes the `artifact`
  keyword at the start of a line so a source that only uses `artifact`
  and `node` still routes to the component parser. Adds an `artifact`
  variant to `ComponentNodeKind` (now `{component, interface,
  artifact}`) and an `_parseArtifactDecl` that accepts the same
  `artifact Name` and `artifact "Display" as Alias` forms as
  `component`, both at the top level and inside container bodies.
  `ComponentLayout` renders artifact nodes as a small white `SceneNote`
  (~80×40, with the document-style folded top-right corner), distinct
  from the light-blue component rectangles.
- Component diagrams. The parser dispatches to a `ComponentDiagram` when
  it sees the `component` keyword, a container keyword (`package` /
  `node` / `cloud` / `frame`), a bracketed `[Name]` shorthand, or the
  `()` interface shorthand at the start of a line. The discriminator
  runs between state and class so the dispatch order is activity > use
  case > state > component > class > sequence (component wins over class
  because `interface` is valid in both, but component-specific markers
  must be present for component to fire). Adds a `ComponentDiagram` AST
  subclass with `ComponentNode` (`alias`, `label`, `kind:
  ComponentNodeKind.{component, interface}`), `ComponentContainer`
  (optional `label`, `kind: ContainerKind.{package, node, cloud,
  frame}`, `nodeAliases`, and `nestedContainers` for arbitrarily nested
  containers), and `ComponentRelation` (reuses the use-case-style
  `LineStyle` / `ArrowHead` / `MessageDirection` arrow encoding).
  Supported syntax: `component Name` / `component "Display" as Alias`
  declarations, the bracket shorthand `[Name]` and `[Name] as Alias`
  (which supports multi-word names by joining all tokens up to the
  closing `]`), `interface Name` / `interface "Display" as Alias`
  declarations, the lollipop shorthand `() "Name" as Alias`,
  `package` / `node` / `cloud` / `frame` containers (with an optional
  quoted label, optional `as Alias`, and a `{ ... }` body that may hold
  component / interface declarations, bracket and paren shorthands, and
  arbitrarily nested containers), and relationships using the standard
  arrow forms (`->`, `-->`, `..>`, `--`, `..`) with optional `: label`
  and endpoints that can be aliases or bracketed shorthands. A new
  `ComponentLayout` lays out top-level containers left-to-right in a
  single row, then stacks any free-standing nodes below; inside each
  container child nodes and nested containers are stacked vertically.
  Components render as light-blue `SceneBox` rectangles with the
  `<<component>>` stereotype above the name; interfaces render as a
  small `SceneCircle` lollipop with the label below. Package containers
  draw a labeled tab in the top-left corner; node containers add two
  small `SceneLine` shading strokes plus a top edge to suggest a 3D box;
  cloud containers use a `SceneRoundedBox`; frame containers draw a
  labeled notch in the top-left corner. Relationship arrows render as
  `SceneLine` between the rectangle edges (or the circle perimeter for
  interface endpoints) with an open-V arrow head at the target end.
- State diagrams. The parser dispatches to a `StateDiagram` when it sees
  the `state` keyword or the `[*]` pseudo-state literal anywhere in the
  body. The discriminator runs between use case and class, so the
  dispatch order is activity > use case > state > class > sequence (state
  wins over class because both can have `{ ... }` bodies). Adds a
  `StateDiagram` AST subclass with `StateDecl` (`name`, optional
  `displayName`, `nestedStates`, `nestedTransitions`, and
  `concurrentRegions: List<List<StateDecl>>` — empty `nestedStates` and
  empty `concurrentRegions` indicates a leaf state) and `StateTransition`
  (`from`, `to`, optional `label`); pseudo-states are encoded as the
  literal `'[*]'` string in transition endpoints. Supported syntax:
  `[*] --> X` initial transitions, `X --> [*]` final transitions, bare
  `X --> Y : label` transitions, `state Name` declarations, `state
  "Display" as Alias` alias form, `state Outer { ... }` composite states
  with nested states and transitions, and concurrent regions inside a
  composite body separated by a `--` on its own line (which the parser
  special-cases as a region divider). Adds new lexer tokens `leftBracket`
  (`[`) and `rightBracket` (`]`); a standalone `*` immediately after a
  `[` is emitted as an identifier so `[*]` lexes as `leftBracket`,
  identifier `*`, `rightBracket` and the parser folds the three tokens
  back into the pseudo-state literal. A new `StateLayout` lays out
  sibling states using the same grid + BFS layered scheme as
  `ClassLayout`; leaf states render as `SceneRoundedBox` (yellow fill,
  rounded corners). Composite states render as a `SceneRoundedBox` with
  a header band, a horizontal divider line, and the nested sub-layout
  emitted inside the body region (child shapes are translated into the
  outer state's coordinate space). Concurrent regions inside a composite
  are stacked vertically and separated by a dashed `SceneLine`. The
  `[*]` pseudo-state renders as a `SceneCircle`: filled when it appears
  as the source of a transition (initial) and ringed when it appears as
  the target (final). Transitions render as `SceneLine` with an open-V
  arrow head at the target end.
- Activity diagrams (new syntax). The parser dispatches to an
  `ActivityDiagram` when it sees activity markers at the start of a line:
  `start` / `stop`, `if (` / `while (` headers, `repeat` / `fork` /
  `partition` keywords, or a `:Action;` line. The discriminator runs
  before the use case and class checks so activity wins when these
  markers are present. Adds an `ActivityDiagram` AST subclass with a
  sealed `ActivityNode` hierarchy: `StartNode`, `StopNode`, `EndNode`,
  `Action` (rounded action box with optional inline note), `IfBlock`
  (one or more `IfBranch { condition, thenLabel, body }` entries plus
  an optional `elseBody` / `elseLabel`; `elseif` is modeled as
  additional `IfBranch` entries), `WhileBlock`
  (`condition`, `isLabel`, `endLabel`, `body`), `RepeatBlock`
  (`body`, `whileCondition`), `ForkBlock`
  (`branches: List<List<ActivityNode>>`), and `Partition`
  (`name`, `body`). Inline action text is captured by stripping the
  trailing `;` from the rest-of-line text token the colon handler
  already emits. New lexer tokens `leftParen` / `rightParen` for `(` /
  `)`; when the lexer sees a `(` it emits the open paren, captures the
  content up to the matching `)` as a single trimmed `text` token, then
  emits the close paren — this lets condition / label expressions
  contain arbitrary characters (e.g. `if (in stock?)`).
  A new `ActivityLayout` lays out nodes top-to-bottom on a single
  vertical spine. Start / stop / end render as `SceneCircle` (filled
  or ringed); actions render as `SceneRoundedBox`; decisions render as
  `SceneDiamond`; fork synchronization points render as thick
  `SceneBox` bars; partitions render as a thin labeled box around their
  body. For v1, `if` / `elseif` / `else` branches and `fork` branches
  are stacked vertically rather than laid out side-by-side — dense
  diagrams will be taller than the reference PlantUML output. Adds
  three new scene shapes (`SceneDiamond`, `SceneCircle`,
  `SceneRoundedBox`) plumbed through the renderer.
- Use case diagrams. The parser dispatches to a `UseCaseDiagram` when it
  sees `usecase` or `rectangle` keywords (checked before the class-diagram
  discriminator so use case wins over class). Adds a `UseCaseDiagram` AST
  subclass with `UseCaseNode` (actor or use case), `UseCaseRelation`
  (reusing `LineStyle`, `ArrowHead`, and `MessageDirection`), and
  `UseCaseBoundary` (a rectangle wrapper with optional label and a list
  of contained aliases). Supported syntax: `actor Name` /
  `actor "Display" as Alias`, `usecase Name` /
  `usecase "Display" as Alias`, `rectangle "Label" { ... }` (label
  optional) for system-boundary rectangles around contained use cases,
  and relationship lines that reuse the sequence-style arrow forms
  (`->`, `-->`, `..>`, `--`, `..`) plus an optional `:` label
  (commonly `<<include>>` or `<<extend>>` stereotypes). A new
  `UseCaseLayout` arranges actors vertically along the left edge, places
  use cases inside their boundary rectangles in a grid in the middle,
  and stacks any free-standing use cases below. Adds a new `SceneEllipse`
  shape (the renderer draws it via `canvas.drawOval` for both fill and
  stroke), so use cases render as oval shapes with their label centered
  inside; actors reuse the existing `SceneSymbol` actor glyph.
- Class diagrams. The parser now dispatches between sequence and class
  diagrams based on body content: sources containing `class`, `interface`,
  `enum`, `abstract`, `annotation`, or `exception` keywords (or arrows like
  `<|--`, `*--`, `..>`) are parsed as a class diagram; everything else falls
  through to the existing sequence diagram path unchanged. Adds a
  `ClassDiagram` AST subclass alongside `SequenceDiagram`, with `ClassDecl`,
  `ClassMember` (sealed: `Field`, `Method`, `EnumValue`, `MemberDivider`),
  `Relationship`, and supporting enums (`ClassKind`, `Visibility`,
  `DividerKind`, `RelationshipKind`).
- Type declarations: `class Foo`, `abstract class Foo` (also `abstract Foo`),
  `interface Foo`, `enum Foo`, `annotation Foo`, `exception Foo`. Each
  optionally takes a `{ ... }` body. Inside the body, lines are interpreted
  as members: `+name: Type` field, `+method()` / `+method(): Type` method,
  visibility chars `+` `-` `#` `~` for public / private / protected /
  package-private (rendered in green / red / orange / purple), `{static}` /
  `{abstract}` modifiers (underline / italic), `--` / `..` / `==` section
  dividers, and bare identifiers for enum values.
- Eight relationship kinds with the standard PlantUML arrows: inheritance
  (`<|--` / `--|>`), realization (`<|..` / `..|>`), composition (`*--` /
  `--*`), aggregation (`o--` / `--o`), directed association (`-->` / `<--`),
  association (`--`), dependency (`..>` / `<..`), and link (`..`). Reversed
  forms swap the AST endpoints so layout always renders the head on the
  same side. Relationships accept optional multiplicities (`A "1" *-- "*" B`)
  and a colon-prefixed label (`: has`).
- `ClassLayout` implementing a simple grid + BFS layered layout: each class
  becomes a yellow box with a header band (name + optional stereotype like
  `<<interface>>`) above a member list; classes are placed in rows by BFS
  level starting from roots with no incoming inheritance edges; rows are
  centered horizontally. Relationships render as straight lines between box
  edges with kind-appropriate heads. Documented limitation: edges may cross
  for dense graphs since no edge routing is performed.
- Three new `ArrowHead` variants on the scene shape: `triangle` (hollow
  triangle, used for inheritance / realization), `filledDiamond`, and
  `hollowDiamond` (composition / aggregation). The renderer draws each with
  a fill + stroke pair so heads remain visible on any background.
- Lexer support for class diagram arrow forms (`<|--`, `<|..`, `--|>`,
  `..|>`, `*--`, `--*`, `o--`, `--o`, `..>`, `<..`, `..`, plus reversed and
  bracketed-modifier variants) and a class-body mode that captures member
  lines as `text` tokens between `{` and `}`. Sequence diagram arrows
  (`->`, `->o`, `->x`, `-->`, etc.) are unchanged.
- Object diagrams via the same `ClassDiagram` AST. New `object` and `map`
  header keywords reuse the class-diagram dispatcher and `ClassLayout`. An
  `object` body holds attribute assignments (`name = value`); a `map` body
  holds key/value pairs (`key => value`). Adds `ClassKind.object_`,
  `ClassKind.map_`, a new `Attribute` `ClassMember` subclass
  (`name`, `value`, `isMap`), and a `ClassDecl.instanceOf` field for typed
  instances (`object alice : Person`). Object / map headers render with an
  underlined name per UML instance convention; `map` adds a `<<map>>`
  stereotype label above the name. Relationships between objects reuse the
  existing class relationship arrows. Surrounding double quotes around an
  attribute value are stripped at parse time. Adds `TokenType.equals` (`=`)
  and `TokenType.mapArrow` (`=>`) for future use; current body parsing reads
  whole lines as `text` tokens (consistent with class bodies). The `==`
  token continues to lex as `doubleEquals` via longest-match.

## 0.3.0

### Added

- Basic `skinparam` support for customizing diagram visuals. Both the inline
  form (`skinparam backgroundColor #White`) and the block form
  (`skinparam sequence { ArrowColor #Red ... }`) are accepted; in the block
  form the optional prefix is concatenated with each inner key before
  matching. Keys are case-insensitive and unknown keys are silently ignored.
  Supported keys: `backgroundColor`, `defaultFontSize`, `sequenceArrowColor`,
  `sequenceLifeLineBackgroundColor`, `participantBackgroundColor`,
  `participantBorderColor`, `noteBackgroundColor`, `noteBorderColor`. Adds a
  `SkinParams` AST class and `SequenceDiagram.skin` field; layout reads the
  skin to override the corresponding default colors and to scale the label /
  note / header / footer / caption / legend font size. The diagram background
  is plumbed through a new `Scene.background` field that the renderer fills
  before painting any shape. Adds new `leftBrace` / `rightBrace` token types
  for `{` and `}`.
- Multi-line comments `/' ... '/`. Anything between the opening `/'` and the
  closing `'/` is skipped by the lexer, including newlines. The existing
  single-line `'` comment behavior is unchanged. An unterminated `/'` (no
  closing `'/` before EOF) raises `LexerException` pointing at the opening
  position.
- Inline HTML / Markdown formatting in label text. The renderer and text
  measurer now parse a small markup subset before painting or measuring:
  `<b>` / `**bold**`, `<i>` / `//italic//`, `<u>` / `__under__`,
  `<s>` / `~~strike~~`, `<color:name>` and `<color:#RRGGBB>` (named or hex,
  same set as arrow `[#color]` modifiers), `<size:N>`, and `<br>` / `\n` for
  line breaks. Markup nests; unknown tags pass through as literal text so
  pre-existing label strings render unchanged. Applies to message labels,
  note bodies, participant display names, group/box labels, and the
  title / caption / header / footer / legend regions. Adds
  `lib/src/text/inline_markup.dart` (`parseInlineMarkup`) and extracts the
  shared color parser into `lib/src/text/colors.dart` (`tryParseColor`,
  `namedColors`); both are re-exported from the package barrel.
- `newpage` directive for splitting a single sequence into multiple logical
  pages within one source. Each page shares participants and diagram-level
  decorations (header / footer / legend / title / caption). An optional
  per-page title may follow the keyword (`newpage Page Two Title`). Rendered
  as a thick horizontal divider line across the diagram width with the
  optional title centered above it; lifelines and activation stacks continue
  uninterrupted across the divider (a deliberate simplification of PlantUML's
  paginated PDF output). Adds a `NewPage` sequence-event subclass.
- `legend` … `endlegend` (also `end legend`) directive that draws a small
  bordered box of multi-line text below the diagram body and above any caption
  or footer. An optional alignment modifier (`left` / `right` / `center`,
  default `left`) positions the box horizontally within the diagram width;
  body text is left-aligned inside the box. Duplicate `legend` throws
  `ParserException`. Adds a `Legend` AST class and `SequenceDiagram.legend`
  field. The lexer captures legend body lines as raw `text` tokens, mirroring
  multi-line note handling, so the body may contain punctuation freely.
- `title`, `header`, `footer`, and `caption` directives that decorate a
  sequence diagram with surrounding text regions. Each supports a single-line
  form (`title My Title`) and a multi-line form terminated with
  `end title` / `end header` / `end footer` / `end caption`. `header` and
  `footer` accept an optional alignment modifier (`center` / `left` / `right`,
  default `center`). Title renders centered above the diagram in bold; header
  and footer render small and gray at the very top and bottom with the chosen
  alignment; caption renders centered below the diagram in italic. Duplicate
  declarations throw `ParserException`. Adds `SequenceDiagram.title`,
  `SequenceDiagram.caption`, `SequenceDiagram.header`, `SequenceDiagram.footer`
  fields and a new `HeaderFooter` AST class.
- `autonumber` directive for sequence diagrams. Prepends a running sequence
  number to every subsequent `Message` label. Supports the variants
  `autonumber`, `autonumber <start>`, `autonumber <start> <increment>`, and an
  optional trailing format string (e.g. `autonumber 10 5 "[%03d]"`).
  `autonumber stop` pauses numbering; `autonumber resume [n]` resumes from the
  remembered (or explicitly given) value. Format placeholders supported are
  `%d` and `%0Nd` for `N` in 1–9; a format string with no `%d`-like marker is
  used as a literal prefix with the number appended after a space. Numbering
  is applied at parse time by rewriting `Message.label`; no AST or layout
  changes are needed.
- Sequence-diagram separator lines:
  - `== Title ==` draws a solid horizontal rule with the title centered in a
    rounded grey label box that interrupts the line.
  - `||n||` (digits between two `||` markers) reserves `n` pixels of vertical
    space (clamped to 20–200) and draws a small two-bar zigzag mark on each
    lifeline.
  - `...` draws a centered `...` skip indicator.
  - `--` on its own line draws a dashed horizontal rule across all lifelines.
    The deactivate-source suffix `--` on messages (`B --> A --`) is
    unaffected — separators only fire when `--` is the leading token on a line.
  Adds a `Separator` AST type and `SeparatorKind` enum.
- New lexer tokens `doubleEquals` (`==`), `doublePipe` (`||`), and `dotDotDot`
  (`...`). The `==` and `||…||` scanners also emit the in-between label (text)
  / digit (text) as a normal `text` token so the parser can pick it up.

- `box "Label" [#color]` … `end box` groups participants visually inside a
  tinted, labeled rectangle around their top actor boxes. Multiple boxes are
  allowed and appear side-by-side; participants declared at top level (outside
  any box) remain unboxed. Nested boxes and events inside a box are rejected
  with a `ParserException`. Adds a `ParticipantBox` AST type, a
  `SequenceDiagram.boxes` field, and a `SequenceDiagram.boxOf(alias)` helper.
  Inner participants are also appended to `SequenceDiagram.participants` so
  existing code paths that scan participants continue to see them.
- New lexer `TokenType.hashColor` for standalone `#colorname` / `#RRGGBB`
  modifiers (e.g. the optional color on a `box` declaration). Arrow modifiers
  continue to embed their color inside the arrow lexeme as before.
- Multi-line notes: `note left of A` / `note right of A` / `note over A` (and
  `note over A, B`) followed by any number of body lines and terminated by
  `end note`. Each body line is trimmed and joined with `\n` to become the
  note's text. The single-line `note … : text` form is unchanged.
- `ref over A : text` (and `ref over A, B, … : text`) reference box, rendered
  as a rectangle spanning the named participants with a small `ref` tab at the
  top-left. Adds a `RefBox` sequence-event subclass.
- Standalone `create` and `destroy` keyword statements:
  - `create A` emits a `Create` event for an existing/implicit alias.
  - `create participant "Name" as A` (or any actor kind: `actor`, `boundary`,
    `control`, `entity`, `database`, `collections`, `queue`) declares the
    participant and emits a `Create` event in one statement.
  - `destroy A` emits a `Destroy` event terminating the lifeline with an X.
- Inline lifecycle / activation suffixes on messages:
  - `A -> B ++` activates the target.
  - `B --> A --` deactivates the source.
  - `A -> C **` creates the target lifeline at the message Y (top actor
    box drops down rather than being pinned to the diagram top).
  - `C -> A !!` destroys the target — its lifeline ends with an X mark and
    its bottom actor box is omitted.
- New `ActivationSuffix` enum on `Message` and new `Create` / `Destroy`
  sequence-event subclasses; the parser decomposes a suffixed message into a
  `Message` plus the appropriate follow-up event.
- New lexer tokens `plusPlus` (`++`), `minusMinus` (`--`), `starStar` (`**`),
  and `bangBang` (`!!`). The arrow scanner runs first so dashed arrows
  (`-->`, `--[#color]->`, `<--`) continue to lex as a single arrow lexeme;
  a standalone `--` is only emitted when no arrow form matches.

## 0.2.0

### Added

- Full PlantUML arrow-variant grammar: `->`, `-->`, `->>`, `-->>`, `->o`,
  `-->o`, `->x`, `-->x`, plus reversed forms `<-`, `<--`, `<<-`, `<<--`.
  Each form chooses an independent (line style, arrow head, direction).
- New `ArrowHead` enum (`filled`, `open`, `openCircle`, `cross`),
  `LineStyle` enum (`solid`, `dashed`), and `MessageDirection` enum
  (`forward`, `backward`) on `Message`.
- Arrow modifiers `-[hidden]->` (reserves layout space but draws nothing)
  and `-[#color]->` (named or hex stroke color). Compose with every existing
  arrow head/style/direction. Adds `Message.hidden: bool` and
  `Message.color: Color?` fields.

### Changed

- `Message.style: MessageStyle` was split into `Message.lineStyle: LineStyle`,
  `Message.head: ArrowHead`, and `Message.direction: MessageDirection`.
- `SceneLine.arrowHead: bool` is now `SceneLine.head: ArrowHead?` (null = no
  head) with a `headAtFrom: bool` flag indicating which end carries it.
- The default head for `->` is now a filled triangle (matching PlantUML).
  The previous open-V shape is selected with `->>` / `-->>`.
- Lexer now emits a single `TokenType.arrow` for every arrow form; the parser
  inspects the lexeme to decode (`lineStyle`, `head`, `direction`).
  `TokenType.dashedArrow` was removed.

## 0.1.0

Initial unreleased snapshot. Sequence diagrams render natively without a
PlantUML server.

### Added

- `PumlView` widget that lexes, parses, lays out, and paints a PlantUML source
  string in pure Dart.
- Sequence diagram support:
  - Solid (`->`) and dashed (`-->`) messages with optional labels.
  - Self-messages (`A -> A`) rendered as a stepped loop.
  - `participant` declarations with quoted display names and aliases.
  - `note left of` / `note right of` / `note over` (single- and
    multi-participant), drawn as folded-corner yellow boxes.
  - `activate` / `deactivate` rendered as stacked activation bars on lifelines.
  - `alt` / `else` / `opt` / `loop` / `par` group blocks with nesting,
    transparent outer frame, label tab, and dashed `else` dividers.
- Pluggable `TextMeasurer` for headless layout testing.
- Golden-test infrastructure (`test/golden/`, macOS-generated baselines).
- Example app with a live editor and `InteractiveViewer` preview.
