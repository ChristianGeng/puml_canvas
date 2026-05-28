import 'sample_models.dart';

const regexSubSamples = <SubSample>[
  SubSample(
    name: 'Fundamentals of Regular Expressions',
    source: '''
@startregex
title litteralText
abc
@endregex
''',
  ),
  SubSample(
    name: 'Shorthand Character Classes',
    source: '''
@startregex
title shorthandCharacterClasses
\\d\\w\\s
@endregex
''',
  ),
  SubSample(
    name: 'Literal Character Sequences',
    source: '''
@startregex
title litteralCharacterSequence
\\Qfoo\\E
@endregex
''',
  ),
  SubSample(
    name: 'Character Ranges',
    source: '''
@startregex
title range
[0-9]
@endregex
''',
  ),
  SubSample(
    name: 'Any Character',
    source: '''
@startregex
title anyCharacter
.
@endregex
''',
  ),
  SubSample(
    name: 'Special Escapes',
    source: '''
@startregex
title specialEscapes
\\t\\r\\n\\a\\e\\f
@endregex
''',
  ),
  SubSample(
    name: 'Without Descriptive Name',
    source: '''
@startregex
!option useDescriptiveNames false
\\d?\\D+\\w*\\W{1,2}|\\s.\\S
@endregex
''',
  ),
  SubSample(
    name: 'With Descriptive Name (English)',
    source: '''
@startregex
!option language en
!option useDescriptiveNames true
\\d?\\D+\\w*\\W{1,2}|\\s.\\S
@endregex
''',
  ),
  SubSample(
    name: 'With Descriptive Name (Deutsch)',
    source: '''
@startregex
!option language de
!option useDescriptiveNames true
\\d?\\D+\\w*\\W{1,2}|\\s.\\S
@endregex
''',
  ),
  SubSample(
    name: 'With Descriptive Name (Japanese)',
    source: '''
@startregex
!option language ja
!option useDescriptiveNames true
\\d?\\D+\\w*\\W{1,2}|\\s.\\S
@endregex
''',
  ),
  SubSample(
    name: 'Octal and Unicode Escapes',
    source: '''
@startregex
title octalEscapes
\\0377\\337
@endregex
''',
  ),
  SubSample(
    name: 'Unicode Escapes',
    source: '''
@startregex
title unicodeEscapes
\\uFFFF\\x{FFFF}
@endregex
''',
  ),
  SubSample(
    name: 'Optional Repetition',
    source: '''
@startregex
title optional
ab?
@endregex
''',
  ),
  SubSample(
    name: 'Required Repetition',
    source: '''
@startregex
title requiredRepetition
ab+
@endregex
''',
  ),
  SubSample(
    name: 'Zero or More Repetitions',
    source: '''
@startregex
title optionalRepetition
ab*
@endregex
''',
  ),
  SubSample(
    name: 'Specified Range of Repetitions',
    source: '''
@startregex
title rangeRepetition
ab{1,2}
@endregex
''',
  ),
  SubSample(
    name: 'Minimum Number of Repetitions',
    source: '''
@startregex
title minimumRepetition
ab{1}c{1,}
@endregex
''',
  ),
  SubSample(
    name: 'Repetition Equivalence',
    source: '''
@startregex
title repetitionEquivalance a{0,1}b{1,} is the same as a?b+
@endregex
''',
  ),
  SubSample(
    name: 'Alternation',
    source: '''
@startregex
title alternation
a|b
@endregex
''',
  ),
  SubSample(
    name: 'Unicode Categories',
    source: '''
@startregex
title unicodeCategories
letter \\p{L}\\p{Letter}
lower \\p{Ll}\\p{Lowercase_letter}
@endregex
''',
  ),
  SubSample(
    name: 'Unicode Scripts',
    source: '''
@startregex
title unicodeScripts
latin \\p{Latin}
@endregex
''',
  ),
  SubSample(
    name: 'Unicode Blocks',
    source: '''
@startregex
title unicodeBlocks
\\p{InGeometric_Shapes}
@endregex
''',
  ),
];
