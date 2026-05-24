# puml_canvas

A native [PlantUML](https://plantuml.com/)-compatible diagram renderer for
Flutter. Parses a subset of the PlantUML language directly in Dart and paints
the result onto a `CustomPaint` canvas — **no server, no WebView, no
JavaScript bridge**.

> `puml_canvas` is an independent reimplementation that accepts PlantUML's
> textual syntax. It is **not affiliated with, sponsored by, or endorsed by the
> PlantUML project**. "PlantUML" is a trademark of its respective owner; the
> name is used here only to describe input syntax compatibility.

## Features

- Pure-Dart pipeline: `source → lexer → parser → AST → layout → scene → renderer → widget`.
- Sequence diagrams: messages (solid/dashed), self-messages, notes
  (`left of` / `right of` / `over`), `activate`/`deactivate` bars, and
  group blocks (`alt` / `opt` / `loop` / `par`) with nesting and `else` branches.
- Runs offline on every Flutter target: mobile, desktop, web.
- Test-friendly: a `TextMeasurer` abstraction lets layout be unit-tested
  without a Flutter binding; rendering is verified with golden tests.

## Getting started

Add `puml_canvas` to your `pubspec.yaml`:

```yaml
dependencies:
  puml_canvas:
    git:
      url: https://github.com/battlecook/puml_canvas.git
```

(Once published to pub.dev the dependency line will be `puml_canvas: ^x.y.z`.)

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:puml_canvas/puml_canvas.dart';

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return const PumlView(source: '''
@startuml
participant "Web Client" as W
participant "API Server" as S
participant Database as DB

W -> S : POST /login
activate S
S -> DB : SELECT user
activate DB
DB --> S : row
deactivate DB
alt valid credentials
  S --> W : 200 OK
else invalid
  S --> W : 401 Unauthorized
end
deactivate S
@enduml
''');
  }
}
```

Wrap the widget with `InteractiveViewer` to get pan/zoom for free.

See [`example/lib/main.dart`](example/lib/main.dart) for a live editor that
re-renders on every keystroke.

## Supported PlantUML syntax

Sequence diagrams, (as of 0.4.0) class diagrams, use case diagrams,
activity diagrams, state diagrams, component diagrams, timing
diagrams, mindmaps, work breakdown structure (WBS) diagrams,
JSON / YAML data diagrams, Salt wireframes, Gantt diagrams, and
network (nwdiag) diagrams. Mindmaps use a dedicated
`@startmindmap` / `@endmindmap` boundary, WBS diagrams use
`@startwbs` / `@endwbs`, JSON diagrams use `@startjson` /
`@endjson`, YAML diagrams use `@startyaml` / `@endyaml`, Salt
uses `@startsalt` / `@endsalt`, Gantt uses `@startgantt` /
`@endgantt`, and network diagrams use `@startnwdiag` /
`@endnwdiag`; everything else uses the shared `@startuml` /
`@enduml` boundary. Within an `@startuml` body
the parser auto-detects the diagram type: if it sees timing markers
(`robust` / `concise` / `clock` keyword or an `@<number>` time cursor)
it parses as a timing diagram;
else if it sees activity markers (`start` / `stop` / `if (` /
`while (` / `repeat` / `fork` / `partition` / a `:Action;` line) it
parses as an activity diagram; else if it sees `usecase` or
`rectangle` keywords it parses as a use case diagram; else if it sees
the `state` keyword or the `[*]` pseudo-state literal it parses as a
state diagram; else if it sees the `component` keyword, a container
keyword (`package` / `node` / `cloud` / `frame`), a bracketed
`[Name]` shorthand, or the `()` interface shorthand it parses as a
component diagram; else if it sees `class` / `interface` / `enum` /
`abstract` / `annotation` / `exception` keywords, an `entity` keyword
followed by a `{` body, or a class-only arrow form like `<|--`, `*--`,
`..>`, or a crow's foot arrow like `||--o{`, it parses as a class /
ER diagram; otherwise the source is interpreted as a sequence diagram.

### Sequence diagrams

Within that scope:

| Feature           | Syntax                                                 |
| ----------------- | ------------------------------------------------------ |
| Diagram boundary  | `@startuml` / `@enduml`                                |
| Message arrows    | see [Arrow variants](#arrow-variants) below            |
| Self-message      | `A -> A : label`                                       |
| Participant decl. | `participant Alice` / `participant "Name" as Alias`    |
| Note (side)       | `note left of A : text` / `note right of A : text`     |
| Note (over)       | `note over A : text` / `note over A, B : text`         |
| Note (multi-line) | `note left of A` … `end note` (also `right of` / `over`) |
| Reference box     | `ref over A : text` / `ref over A, B : text`           |
| Activation        | `activate A` / `deactivate A`                          |
| Lifecycle         | `create A` / `create participant "Name" as A` / `destroy A` |
| Inline lifecycle  | `A -> B ++` / `B --> A --` / `A -> C **` / `C -> A !!` |
| Alternatives      | `alt label` … `else other` … `end`                     |
| Optional          | `opt label` … `end`                                    |
| Loop              | `loop label` … `end`                                   |
| Parallel          | `par label` … `else label` … `end`                     |
| Participant box   | `box "Label" [#color]` … participant decls … `end box` |
| Separator (title) | `== Title ==`                                          |
| Separator (delay) | `\|\|n\|\|` (n pixels of vertical gap, with a small zigzag) |
| Separator (skip)  | `...` (drawn as centered `...`)                        |
| Separator (dash)  | `--` (dashed horizontal line across all lifelines)     |
| Autonumber        | `autonumber` / `autonumber 10` / `autonumber 10 5` / `autonumber "[%03d]"` / `autonumber stop` / `autonumber resume [n]` |
| Title             | `title My Title` / `title` … `end title`               |
| Header            | `header text` / `header left text` / `header` … `end header` (also `center` / `right`) |
| Footer            | `footer text` / `footer right text` / `footer` … `end footer` (also `center` / `left`) |
| Caption           | `caption My Caption` / `caption` … `end caption`       |
| Legend            | `legend` … `endlegend` (also `end legend`); optional `left` / `right` / `center` modifier (default `left`) |
| Page break        | `newpage` / `newpage Per-page Title`                   |
| Comment           | `' line comment` / `/' multi-line comment '/`          |

### Arrow variants

| Syntax  | Arrowhead style              | Line style |
| ------- | ---------------------------- | ---------- |
| `->`    | filled triangle              | solid      |
| `-->`   | filled triangle              | dashed     |
| `->>`   | open V                       | solid      |
| `-->>`  | open V                       | dashed     |
| `->o`   | small filled circle          | solid      |
| `-->o`  | small filled circle          | dashed     |
| `->x`   | × (cross)                    | solid      |
| `-->x`  | × (cross)                    | dashed     |
| `<-`    | filled triangle, head at `from` | solid   |
| `<--`   | filled triangle, head at `from` | dashed  |
| `<<-`   | open V, head at `from`       | solid      |
| `<<--`  | open V, head at `from`       | dashed     |

### Lifecycle and inline activation

Append a two-character marker right after the target identifier (before the
optional `:` label) to attach a lifecycle hint to a message:

| Suffix | Applies to | Effect                                                            |
| ------ | ---------- | ----------------------------------------------------------------- |
| `++`   | target     | Activate the target after this message (push an activation bar).  |
| `--`   | source     | Deactivate the source after this message (pop an activation bar). |
| `**`   | target     | Create the target lifeline at this message (top box drops down).  |
| `!!`   | target     | Destroy the target after this message (lifeline ends with an X).  |

Examples:

```
A -> B ++ : request
B --> A -- : reply
A -> C ** : new
C -> A !! : crash
```

Each suffix decomposes at parse time into a `Message` plus a follow-up
`Activate` / `Deactivate` / `Create` / `Destroy` event, so it composes with
existing `activate` / `deactivate` blocks. Suffixes are only accepted
immediately after the target identifier; other positions raise a
`ParserException`.

### Autonumber

`autonumber` prepends a running sequence number to every subsequent message's
label. Variants:

```
autonumber                       ' start=1, increment=1, format="%d"
autonumber 10                    ' start=10, increment=1
autonumber 10 5                  ' start=10, increment=5
autonumber 10 5 "<b>[%03d]</b>"  ' with a format string
autonumber "%03d"                ' format only; resets start=1, increment=1
autonumber stop                  ' pause numbering of subsequent messages
autonumber resume                ' resume from the current value
autonumber resume 100            ' resume from 100
```

Supported format placeholders: `%d` (plain integer) and `%0Nd` for `N` in 1–9
(zero-padded integer of width `N`). Any other characters in the format string
are kept as-is around the number. If the format string contains no `%d`-like
placeholder, the whole string is treated as a literal prefix and the number is
appended after a space (e.g. `autonumber "step"` produces `step 1`, `step 2`,
…). Messages parsed before any `autonumber` directive are left unnumbered.

### Arrow modifiers

Any arrow can carry a single bracketed modifier between its dashes:

| Modifier         | Effect                                                       |
| ---------------- | ------------------------------------------------------------ |
| `[hidden]`       | Reserves vertical space but draws no line (e.g. `-[hidden]->`). |
| `[#RRGGBB]`      | Strokes the arrow with the given hex color (also `#RGB` / `#AARRGGBB`). |
| `[#name]`        | Named color (`red`, `blue`, `lightgray`, `darkgreen`, …; case-insensitive). |

The modifier composes with any head/style variant — `--[#blue]->>` is a
dashed open-V arrow drawn in blue, `<-[#red]-` is a solid red backward
arrow, and so on.

### Page breaks (`newpage`)

`newpage` splits a single sequence into multiple logical pages within one
source. Each page shares the diagram's participants, header, footer, legend,
caption, and (diagram-level) title. An optional per-page title can be
supplied directly after the keyword (`newpage Section Two`).

This renderer treats `newpage` as a **visual marker only**: pages are stacked
vertically inside the same diagram surface, separated by a thick horizontal
divider line (and the optional title above the line). Lifelines, activation
stacks, and actor boxes are not re-printed between pages — they continue
through the divider. This is a simplification of PlantUML's paginated PDF
output but renders cleanly in a single scrollable widget.

Anything outside this table is not yet implemented.

### Text formatting

Most text-bearing positions — message labels, note bodies, participant display
names, group/box labels, and the title / caption / header / footer / legend
regions — accept a small subset of PlantUML's inline HTML and Markdown
formatting:

| Markup                          | Effect          |
| ------------------------------- | --------------- |
| `<b>bold</b>` / `**bold**`      | bold            |
| `<i>italic</i>` / `//italic//`  | italic          |
| `<u>under</u>` / `__under__`    | underlined      |
| `<s>strike</s>` / `~~strike~~`  | strikethrough   |
| `<color:red>x</color>`          | named color     |
| `<color:#FF8800>x</color>`      | hex color (`#RGB`, `#RRGGBB`, `#AARRGGBB`) |
| `<size:14>bigger</size>`        | font size in px |
| `<br>` / `\n`                   | line break      |

Tags nest, and unknown tags pass through as literal text so plain strings
containing angle brackets keep their original characters. Color names accept
the same set as arrow `[#color]` modifiers (case-insensitive).

### Styling (`skinparam`)

A small subset of PlantUML's `skinparam` directive is supported for tweaking
colors and font size on a per-diagram basis. Both the inline form and the
block form (with optional prefix) are accepted:

```
skinparam backgroundColor #FFF8E7
skinparam defaultFontSize 14

skinparam sequence {
  ArrowColor #003366
  LifeLineBackgroundColor #888888
}
```

Inside a block form, the prefix and the inner key are concatenated, so
`skinparam sequence { ArrowColor #Red }` is equivalent to
`skinparam sequenceArrowColor #Red`. Keys are matched case-insensitively;
unknown keys are silently ignored. Color values accept the same named or hex
forms as arrow `[#color]` modifiers; `defaultFontSize` accepts an integer.

| Key                                | Type  | Effect                                              |
| ---------------------------------- | ----- | --------------------------------------------------- |
| `backgroundColor`                  | color | Diagram canvas fill                                 |
| `defaultFontSize`                  | int   | Base font size for labels / notes / text regions    |
| `sequenceArrowColor`               | color | Default message arrow stroke (no explicit `[#color]`) |
| `sequenceLifeLineBackgroundColor`  | color | Lifeline stroke color                               |
| `participantBackgroundColor`       | color | Actor box fill                                      |
| `participantBorderColor`           | color | Actor box stroke                                    |
| `noteBackgroundColor`              | color | Note fill                                           |
| `noteBorderColor`                  | color | Note stroke                                         |

### Class diagrams

Both diagram types share the `@startuml` / `@enduml` boundary. Within a
class diagram, the following syntax is supported:

| Feature                | Syntax                                                    |
| ---------------------- | --------------------------------------------------------- |
| Regular class          | `class Foo` (optionally followed by `{ ... }`)            |
| Abstract class         | `abstract class Foo` or `abstract Foo`                    |
| Interface              | `interface Foo`                                           |
| Enum                   | `enum Color { RED  GREEN  BLUE }`                         |
| Annotation             | `annotation Foo`                                          |
| Exception              | `exception Foo`                                           |
| Field                  | `+name: Type` (visibility prefix optional)                |
| Method                 | `+method()` or `+method(arg: T): Ret`                     |
| Static modifier        | `{static} +counter: int`                                  |
| Abstract modifier      | `{abstract} +area(): double`                              |
| Section divider        | `--`, `..`, or `==` on its own line inside `{}`           |
| Enum value             | bare identifier on its own line inside an `enum` body     |

Visibility characters render in distinct colors: `+` green (public), `-` red
(private), `#` orange (protected), `~` purple (package-private). `{static}`
underlines the member; `{abstract}` italicizes it.

#### Relationship arrows

| Syntax                | Meaning                  | Visual                                |
| --------------------- | ------------------------ | ------------------------------------- |
| `A <|-- B`            | B inherits from A        | solid line, hollow triangle at A      |
| `A <|.. B`            | B implements A           | dashed line, hollow triangle at A     |
| `A *-- B`             | composition              | solid line, filled diamond at A       |
| `A o-- B`             | aggregation              | solid line, hollow diamond at A       |
| `A --> B`             | directed association     | solid line, open V at B               |
| `A -- B`              | association              | solid line, no head                   |
| `A ..> B`             | dependency               | dashed line, open V at B              |
| `A .. B`              | link                     | dashed line, no head                  |

The reversed forms (`A --|> B`, `A --* B`, `A <-- B`, `A <|.. B`, etc.) are
also accepted and swap the endpoints internally so the head always renders
on the correct side.

Optional multiplicities go in quotes next to the corresponding end, and an
optional label follows after `:`:

```
A "1" *-- "*" B : has
```

#### Layout

Class diagrams use a simple grid + BFS layered layout: each class becomes a
yellow box; rows are filled by BFS level starting from classes with no
incoming inheritance edge. Rows are centered horizontally, edges are drawn
as straight lines between the nearest box edges. There is no edge routing,
so dense diagrams may have crossing lines. A future release may swap in a
Sugiyama-style layered layout.

### Use case diagrams

Use case diagrams describe actors interacting with a system's use cases.
A boundary `rectangle` groups related use cases:

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Actor                | `actor User` / `actor "Admin User" as Admin`        |
| Use case             | `usecase Login` / `usecase "Place Order" as UC1`    |
| System boundary      | `rectangle "System" { ... usecase decls ... }`      |
| Anonymous boundary   | `rectangle { ... }`                                 |
| Relationship         | `User --> UC1` / `User -- UC1`                      |
| Include / extend     | `UC1 ..> UC2 : <<include>>`                         |

Actors are rendered as stick figures (reusing the sequence-diagram actor
glyph). Use cases are rendered as ellipses with their label centered
inside. Boundary rectangles enclose their contained use cases with the
optional label printed at the top-left. Relationship arrows reuse the
sequence-style arrow syntax (`->`, `-->`, `..>`, `--`, `..`) and accept a
trailing `:` label which is commonly an `<<include>>` or `<<extend>>`
stereotype.

The layout strategy stacks actors vertically on the left, places use
cases inside their boundary rectangles in a grid in the middle, and lays
out any free-standing use cases below those boundaries. Edges connect
the actor rectangle edge to the use case ellipse boundary.

### Activity diagrams

Activity diagrams describe a control flow as a sequence of actions joined by
decisions, loops, and parallel branches. The parser dispatches to an
`ActivityDiagram` when it sees a `start` / `stop` line, an `if (` / `while (`
header, a `repeat` / `fork` / `partition` keyword, or a `:Action;` line.

| Feature             | Syntax                                                |
| ------------------- | ----------------------------------------------------- |
| Start node          | `start`                                               |
| Stop node           | `stop`                                                |
| End node            | `end`                                                 |
| Action              | `:Process Order;`                                     |
| If / else           | `if (cond) then (yes)` … `else (no)` … `endif`        |
| Else if             | `elseif (cond) then (label)`                          |
| While loop          | `while (cond) is (yes)` … `endwhile (no)`             |
| Repeat loop         | `repeat` … `repeat while (cond)`                      |
| Fork                | `fork` … `fork again` … `end fork`                    |
| Partition           | `partition Name { ... }`                              |

Actions are rendered as rounded rectangles, decisions as diamonds, start as a
filled circle and stop / end as a ringed circle, fork synchronization points
as thick horizontal bars, and partitions as a labeled rectangle around their
body.

The v1 layout is intentionally simple: every node is placed on a single
vertical spine. `if` / `elseif` / `else` branches are stacked below the
decision diamond and merged at a small diamond at the bottom rather than
flowing side-by-side; `fork` branches stack vertically between two
synchronization bars instead of running in parallel columns. Dense diagrams
may therefore look taller than the reference PlantUML output. A future
release may add side-by-side column routing for branches and forks.

Connectors, floating notes, swim-lane styling, detached arrows, and the
legacy `(*) -> A` syntax are not yet supported.

### State diagrams

State diagrams describe a finite-state machine as a graph of named states
joined by transitions. The parser dispatches to a `StateDiagram` when it
sees the `state` keyword or the `[*]` pseudo-state literal anywhere in
the body.

| Feature             | Syntax                                                |
| ------------------- | ----------------------------------------------------- |
| Pseudo-state        | `[*]` (initial when source, final when target)        |
| Bare state          | `Idle` (used as the source or target of a transition) |
| Explicit state      | `state Idle`                                          |
| Aliased state       | `state "Display Name" as Alias`                       |
| Transition          | `A --> B` / `A --> B : label`                         |
| Composite state     | `state Outer { ... nested states and transitions ... }` |
| Concurrent regions  | inside a composite body, `--` on its own line splits   |
|                     | the body into independent concurrent regions          |

Leaf states render as yellow rounded rectangles. Composite states render
as a rounded rectangle with a label band at the top, a divider line under
the label, and the nested state graph laid out inside. Concurrent regions
inside a composite are stacked vertically and separated by a dashed
horizontal divider; each region gets its own sub-layout. The `[*]`
pseudo-state renders as a small filled circle when used as the source of
a transition (initial state) and as a ringed circle when used as the
target (final state). Sibling states are placed by the same grid + BFS
layered layout used for class diagrams; transitions are drawn as straight
lines between the nearest box edges with an open-V arrow head at the
target end.

### Component diagrams

Component diagrams describe components, interfaces, and the containers
that group them. The parser dispatches to a `ComponentDiagram` when it
sees the `component` keyword, a container keyword (`package` / `node` /
`cloud` / `frame`), the bracketed `[Name]` shorthand, or the `()`
interface shorthand at the start of a line. The discriminator runs
between state and class so `component` (and the bracket / paren
shorthands) win over the class dispatcher.

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Component            | `component Web` / `component "Web Server" as Web`   |
| Component (shorthand)| `[Auth Service]` / `[Cache Service] as Cache`       |
| Interface            | `interface "HTTP API" as HTTP`                      |
| Interface (shorthand)| `() "REST" as REST`                                 |
| Package container    | `package "Backend" { ... }`                         |
| Node container       | `node "Server 1" { ... }`                           |
| Cloud container      | `cloud "AWS" { ... }`                               |
| Frame container      | `frame "Foo" { ... }`                               |
| Anonymous container  | `package { ... }`                                   |
| Nested containers    | `package "Outer" { node "Inner" { ... } }`          |
| Relationship         | `Web --> HTTP` / `[A] -- [B]`                       |
| Dependency           | `[A] ..> [B] : <<uses>>`                            |

Components render as light-blue rectangles with a small `<<component>>`
stereotype above the name. Interfaces render as small ringed circles
(lollipops) with the label below. Containers are stacked left-to-right at
the top level; nested containers are inlined within their parent.
Package containers draw a labeled tab in the top-left; node containers
add a small 3D shading on the top-right corner; cloud containers use a
rounded box; frame containers draw a labeled notch in the top-left.
Relationship arrows reuse the use-case style (`->`, `-->`, `..>`, `--`,
`..`) and may carry a trailing `: label`. Both endpoints accept either
an alias (`Web`) or the bracketed shorthand (`[Auth Service]`).

### Deployment diagrams

Deployment diagrams are a thin extension of component diagrams: they
reuse the same `@startuml` / `@enduml` boundary, the same `node` /
`cloud` / `package` / `frame` containers, the same `component` and
interface shorthands, and the same relationship arrow syntax. The only
addition is the `artifact` keyword:

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Artifact             | `artifact Foo` / `artifact "config.yml" as Config`  |

Artifacts render as a small white rectangle with a folded top-right
corner (the document shape), distinct from the light-blue component
rectangles. Anything that works in a component diagram also works in a
deployment diagram, so an `artifact` can live at the top level, inside
a `node` container, or anywhere else a component would be accepted.

### Timing diagrams

Timing diagrams show how a small set of participants ("lanes") change
state over time. The parser dispatches to a `TimingDiagram` when it
sees the `robust` / `concise` / `clock` keywords or an `@<number>`
time cursor.

| Feature             | Syntax                                                  |
| ------------------- | ------------------------------------------------------- |
| Robust lane         | `robust "Web Browser" as WB`                            |
| Concise lane        | `concise "User"` (alias defaults to the label)          |
| Clock lane          | `clock "Clock" with period 50` (parsed, not rendered)   |
| Time cursor         | `@100` (integer time; sets the cursor for following events) |
| State change        | `<alias> is <StateName>` (persists until changed)       |
| Arrow annotation    | `<alias> -> <alias> : label` (vertical arrow at cursor) |

Each lane gets one horizontal band stacked vertically; a time axis
with tick marks runs across the top above the lanes. Robust lanes
render each state as a horizontal bar; the bar's vertical position
is chosen from the alphabetically-sorted set of states seen on that
lane (highest-letter state at the bottom, lowest at the top), with a
vertical edge drawn at each transition. Concise lanes render as a
single horizontal line with the state name printed above each
segment and a small vertical tick at each transition. Arrows between
lanes render as a vertical `SceneLine` with a filled arrowhead at
the target lane, drawn at the X coordinate of the cursor time.

Time coordinates map proportionally onto the X axis: the smallest
time used pins to the left edge of the plot area and the largest to
the right, with intermediate times placed by linear interpolation.
The plot width is sized so each adjacent pair of times has at least
a 60 px gap. Clock lanes are accepted by the parser (so a source
that uses `clock` still routes correctly) but render as an empty
labeled lane in v1; highlighted time ranges are not yet supported.

### ER diagrams

Entity-relationship diagrams reuse the class-diagram infrastructure: the
parser recognizes the `entity` keyword as a class-kind header (when followed
by a `{ ... }` body or used with crow's foot relationship arrows) and
dispatches to the same `ClassLayout`. Entity headers render with an
`<<entity>>` stereotype label above the name.

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Entity               | `entity Customer { ... }`                           |
| Required field       | `* name : varchar` (leading `*`)                    |
| Field stereotype     | `* id : int <<PK>>` / `* customer_id : int <<FK>>`  |
| Section divider      | `--` / `..` / `==` (key fields / data fields split) |
| One-to-one           | `A ||--|| B`                                        |
| One-to-zero-or-one   | `A ||--o| B`                                        |
| One-to-zero-or-many  | `A ||--o{ B`                                        |
| One-to-one-or-many   | `A ||--|{ B`                                        |
| Zero-or-many-to-one  | `A }o--|| B`                                        |

Crow's foot relationship arrows encode cardinality on each endpoint with two
characters: `||` (exactly one), `o|` (zero or one), `o{` (zero or many), and
`|{` (one or many) on the right side; their mirrored forms `||`, `|o`,
`}o`, `}|` apply on the left side. The body between the endpoints accepts
the standard `--` (solid) and `..` (dashed) line styles. Each endpoint
renders as a dedicated crow's foot mark: a perpendicular tick for "one", a
small white circle for the "zero" part, and a three-pronged crow for the
"many" part.

### Object diagrams

Object diagrams reuse the class-diagram infrastructure: the parser recognizes
`object` and `map` headers (in addition to the class keywords) and dispatches
to the same `ClassLayout`. Object and map headers are rendered with an
underlined name per the UML convention for instances; `map` adds a `<<map>>`
stereotype label above the name.

| Feature             | Syntax                                          |
| ------------------- | ----------------------------------------------- |
| Object              | `object alice` (optionally followed by `{ ... }`) |
| Typed instance      | `object alice : Person`                         |
| Object attribute    | `name = "Alice"` (inside an `object` body)      |
| Map                 | `map config { ... }`                            |
| Map entry           | `host => "localhost"` (inside a `map` body)     |
| Object relationship | reuses class relationship arrows (`-->`, `--`, etc.) |

Attribute values are stored verbatim; surrounding double quotes are
stripped. Section dividers (`--`, `..`, `==`) are accepted inside object /
map bodies just like in class bodies.

### Mindmaps

Mindmaps use a dedicated `@startmindmap` / `@endmindmap` boundary and
describe a tree by indenting each node with leading `*` characters
(one `*` per depth level):

```
@startmindmap
* Root
** Branch A
*** Leaf A1
*** Leaf A2
** Branch B
@endmindmap
```

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Diagram boundary     | `@startmindmap` / `@endmindmap`                     |
| Root node            | `* Text` (exactly one per diagram)                  |
| Child node           | `** Text`, `*** Text`, … (one `*` per depth level)  |
| Force right side     | `+** Text` (top-level child placed on the right)    |
| Force left side      | `-** Text` (top-level child placed on the left)     |
| Colored node         | `**[#color] Text` (named or hex; same set as arrows) |

Top-level children of the root with no explicit side prefix are
auto-balanced left/right by alternating: the first auto child goes
right, the second left, the third right, and so on. Each descendant
inherits its top-level ancestor's side. The root renders as a
yellow rounded rectangle and child nodes as white rounded rectangles;
parent-to-child connectors are drawn as straight gray lines between
the parent's outer edge and the child's inner edge.

Multi-line text boxes (`**: text;` form) are not yet supported.

### WBS

WBS (work breakdown structure) diagrams use a dedicated `@startwbs` /
`@endwbs` boundary and reuse the mindmap's indented-tree syntax, but
render as a top-down hierarchical tree instead of a horizontal radial
mindmap:

```
@startwbs
* Business Plan
** Goals
*** Increase sales
*** Reduce costs
** Risks
*** Market risk
*** Operational risk
** Schedule
@endwbs
```

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Diagram boundary     | `@startwbs` / `@endwbs`                             |
| Root node            | `* Text` (exactly one per diagram)                  |
| Child node           | `** Text`, `*** Text`, … (one `*` per depth level)  |
| Colored node         | `**[#color] Text` (named or hex; same set as arrows) |

The root renders at the top center as a yellow rounded rectangle;
each subsequent depth level is placed in a row below the previous
level. Each parent is centered horizontally above its children's
subtree, and child subtrees are laid out left-to-right with a small
horizontal gap so siblings never overlap. Parent-to-child connectors
are drawn as gray lines from the parent's bottom to the child's top:
straight vertical when the child sits directly under the parent, or
as a three-segment manhattan path (down, across, down) when the
child's X differs from the parent's. The `+` / `-` side prefixes and
multi-line text boxes are not yet supported.

### JSON / YAML data diagrams

Data diagrams visualize a JSON or YAML value as a nested key/value
table. JSON diagrams use `@startjson` / `@endjson` and YAML
diagrams use `@startyaml` / `@endyaml`. The body between the
boundary markers is parsed as a single literal JSON or YAML
document; malformed input raises `ParserException`.

```
@startjson
{
  "name": "Alice",
  "age": 30,
  "tags": ["admin", "user"],
  "address": {
    "city": "Seoul",
    "zip": "12345"
  }
}
@endjson
```

```
@startyaml
name: Alice
age: 30
tags:
  - admin
  - user
address:
  city: Seoul
  zip: "12345"
@endyaml
```

Each object renders as a vertical table: the left column holds the
key (or the integer index for arrays, suffixed with `:`), and the
right column holds the value. Nested objects and arrays render as
sub-tables in the right column. Scalar values are color-coded by
type — strings green, numbers blue, booleans purple, and `null`
italic gray — and string values are rendered in double quotes.
JSON parsing uses `dart:convert`'s `jsonDecode`; YAML parsing uses
a small built-in subset parser (mappings, block sequences, and
scalars only — no anchors, flow style, multi-line strings, or
explicit tags). Insertion order of object keys is preserved so the
rendered table matches the source order.

### Gantt diagrams

Gantt diagrams describe a project schedule as a sequence of dated
tasks, milestones, and section dividers. They use a dedicated
`@startgantt` / `@endgantt` boundary; each body line is one
declaration parsed in source order:

```
@startgantt
Project starts 2026-01-01
[Design] lasts 10 days
[Prototype] lasts 14 days
[Prototype] starts at [Design]'s end
[Implementation] lasts 21 days
[Implementation] starts at [Prototype]'s end
[Testing] lasts 7 days
[Testing] starts at [Implementation]'s end
-- Milestone --
[Release] happens at [Testing]'s end
@endgantt
```

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Diagram boundary     | `@startgantt` / `@endgantt`                         |
| Project start        | `Project starts YYYY-MM-DD`                         |
| Task duration        | `[Name] lasts N days` (also `weeks` / `months`)     |
| Task explicit start  | `[Name] starts YYYY-MM-DD`                          |
| Task chained start   | `[Name] starts at [Other]'s end` (also `'s start`)  |
| Milestone            | `[Name] happens at [Other]'s end`                   |
| Section divider      | `-- Title --`                                       |

Durations in `weeks` are stored as `N * 7` days and `months` as
`N * 30` days. Dates use `DateTime.parse`'s ISO format
(`YYYY-MM-DD`). Cross-references are resolved in a two-pass walk:
each task's absolute start is computed by following its
`starts at [X]'s end|start` chain back to either an explicit date
or the project start; milestones are resolved against the
already-resolved task starts.

Each task renders as a horizontal blue `SceneBox` bar; the bar's
X position is the task's start date mapped linearly onto the
time axis and its width is the duration scaled at 14 px per day.
Milestones render as a small `SceneDiamond` at the milestone
date. Section dividers render as a full-width `SceneLine` with
the section title in bold above the line. A simple date axis
runs across the top with ticks at every day / week / month
depending on total span. Task / milestone / section names are
printed in a left-hand label column. Color modifiers
(`[Name] is colored in red`), dependency arrows between tasks,
pauses, and weekend-off scheduling are not yet supported.

### Network diagrams

Network (nwdiag-style) diagrams describe a set of network segments
with attached nodes. They use a dedicated `@startnwdiag` /
`@endnwdiag` boundary; each segment is opened with
`network NAME { ... }` and each node line attaches a node to the
current segment:

```
@startnwdiag
network dmz {
  address = "210.0.0.0/24"
  web01 [address = "210.0.0.1"]
  web02 [address = "210.0.0.2"]
}
network internal {
  address = "172.0.0.0/24"
  web01 [address = "172.0.0.1"]
  db01 [address = "172.0.0.100"]
}
@endnwdiag
```

| Feature              | Syntax                                              |
| -------------------- | --------------------------------------------------- |
| Diagram boundary     | `@startnwdiag` / `@endnwdiag`                       |
| Network segment      | `network NAME { ... }`                              |
| Segment address      | `address = "x.y.z.w/nn"` (inside a segment body)    |
| Node                 | `nodeName [address = "x.y.z.w"]` or bare `nodeName` |

PlantUML also embeds the same syntax inside `@startuml` using a
`nwdiag { ... }` wrapper block; that embedded form is not
supported in v1 — use the dedicated `@startnwdiag` /
`@endnwdiag` boundary instead.

Each network renders as a horizontal blue bus bar with the
network name (and optional address, in a small gray font) in a
left-hand label column. Each node renders below the bar as a
small white `SceneBox` with the node name centered (and the
node address printed in a smaller line below if present);
nodes are evenly distributed along the bus width and each is
joined to the bar by a vertical `SceneLine`. Multiple segments
stack vertically with a fixed gap between rows.

For v1 simplicity, a node that appears in multiple networks
(same `nodeName` re-used across `network` blocks) is rendered
once per segment as an independent node — i.e. it appears
duplicated rather than as a single shared node vertically
spanning all of its networks. "Shared node spanning" is a v2
enhancement.

### Salt wireframes

Salt diagrams describe lightweight UI mockups using a tabular widget
syntax. They use a dedicated `@startsalt` / `@endsalt` boundary; the
body is wrapped in `{` `}` and each subsequent line is one row of
cells separated by `|`:

```
@startsalt
{
  Name | "Alice"
  Age  | "30"
  [Submit] | [Cancel]
  (X) Option 1
  ( ) Option 2
  [X] Checked
  [ ] Unchecked
  --
  Done
}
@endsalt
```

| Widget                | Syntax                       | Rendered as                              |
| --------------------- | ---------------------------- | ---------------------------------------- |
| Label                 | `Name`                       | plain `SceneText`                        |
| Button                | `[Submit]`                   | gray `SceneRoundedBox` with the label    |
| Text field            | `"Alice"`                    | white `SceneRoundedBox` with italic text |
| Radio (selected)      | `(X) Option`                 | filled `SceneCircle` + label             |
| Radio (unselected)    | `( ) Option`                 | ring `SceneCircle` + label               |
| Checkbox (checked)    | `[X] Done`                   | small `SceneBox` with a check mark + label |
| Checkbox (unchecked)  | `[ ] Done`                   | small empty `SceneBox` + label           |
| Cell separator        | `\|`                         | splits a row into grid cells             |
| Row divider           | `--`                         | full-width `SceneLine`                   |

Column widths and row heights are auto-sized: column `j` width is the
max measured cell width in column `j` across all non-divider rows; row
`i` height is the max measured cell height in row `i`. The whole grid
is wrapped in an outer `SceneBox` with padding. Tabs (`T1 T2 T3`),
dropdowns (`^Dropdown^`), trees (`+`), and menus are not yet
supported.

### Preprocessor

Before lexing, the source string is run through a small PlantUML-style
preprocessor that handles macro substitution, conditional inclusion,
and file includes. Sources that don't use any `!` directives pass
through verbatim.

| Directive                          | Effect                                                  |
| ---------------------------------- | ------------------------------------------------------- |
| `!define NAME value`               | Define a simple text macro; later occurrences of `NAME` expand to `value`. |
| `!define NAME(a,b) body`           | Function-like macro; `NAME(x,y)` expands to `body` with `a` / `b` replaced by `x` / `y`. |
| `!undef NAME`                      | Remove a previously defined macro.                      |
| `!if expr` … `!elseif expr` … `!else` … `!endif` | Conditional inclusion; nests freely.       |
| `!include path`                    | Inline the contents of `path` (resolved via the host's `FileLoader`). |
| `!include path!sub_id`             | Include only the named subsection of `path`.            |
| `!includesub path!sub_id`          | Same as `!include path!sub_id`.                         |
| `!startsub id` / `!endsub`         | Capture content into a named bin reusable by `!includesub`. |
| `!pragma key value`                | Reserved for engine settings; ignored.                  |

Expressions inside `!if` / `!elseif` support identifier lookup (a macro
name evaluates to its body, or to the empty string when undefined),
integer and double-quoted string literals, the comparison operators
`==`, `!=`, `<`, `>`, `<=`, `>=`, the logical operators `&&`, `||`,
`!`, parenthesized sub-expressions, and the built-in `defined(NAME)`
predicate. A bare expression is truthy when non-zero / non-empty.

Macro expansion is only applied to content lines, and skips text inside
double-quoted strings so quoted labels are never munged.

`!include` resolves paths through a pluggable `FileLoader`:

```dart
typedef FileLoader = String Function(String path);
```

In Flutter UI code, pass one through `PumlView(fileLoader: ...)`. The
default is `null`, which leaves `!include` / `!includesub` unsupported
(any attempt raises `PreprocessorException`) — fine for inline sources.
The following directives are reserved but not yet implemented:
`!function`, `!procedure`, `!return`, `!include_many`.

## Architecture

The pipeline is split into independent modules under `lib/src/`:

```
source ─▶ preprocessor ─▶ lexer ─▶ parser ─▶ ast ─▶ layout ─▶ scene ─▶ render ─▶ widget
```

- **`preprocessor`** — handles `!define` / `!if` / `!include` / `!startsub`
  before the lexer ever runs. Pure Dart, no Flutter, no `dart:io`.
- **`lexer`** — tokenizes the PUML source. Pure Dart, no Flutter.
- **`parser`** — recursive-descent parse into a typed AST. Pure Dart.
- **`ast`** — sealed `Diagram` / `SequenceEvent` hierarchy.
- **`layout`** — assigns positions and sizes via a pluggable `TextMeasurer`.
  Pure Dart given a measurer; ships with a Flutter `TextPainter`-based one.
- **`scene`** — geometry-only shape list (`SceneBox`, `SceneLine`,
  `SceneNote`, `SceneText`).
- **`render`** — paints the scene onto a Flutter `Canvas`.
- **`widget`** — `PumlView` ties it all together inside `CustomPaint`.

Each module has dedicated unit tests under `test/`. Renderer regressions are
caught by macOS-platform golden tests in `test/golden/`.

## Roadmap

- [x] Class diagrams (basic grid + BFS layout; Sugiyama-style routing still TBD)
- [x] Use case diagrams (actors + ellipses + boundary rectangles)
- [x] Activity diagrams (start/stop, action, if/while/repeat/fork, partition; v1 vertical-spine layout)
- [x] State diagrams (pseudo-states, transitions, composite states, concurrent regions)
- [x] Component diagrams (components, interfaces, package/node/cloud/frame containers, nesting)
- [x] Timing diagrams (robust + concise lanes, `@time` cursor, state changes, arrow annotations)
- [ ] PNG/SVG export

## Development

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags golden     # fast unit/widget tests
flutter test --tags golden             # macOS-only render goldens
flutter test --tags golden --update-goldens  # regenerate baselines
```

Goldens are generated on macOS; rendering differences across platforms mean
they're tagged and excluded from the default test run. Regenerate them on the
same OS as the CI golden-check job to avoid spurious diffs.

## License

MIT — see [LICENSE](LICENSE).
