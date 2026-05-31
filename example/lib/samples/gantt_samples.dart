import 'sample_models.dart';

const ganttSubSamples = <SubSample>[
  SubSample(
    name: 'Workload',
    source: r'''
@startgantt
[Prototype design] requires 15 days
[Test prototype] requires 10 days
-- All example --
[Task 1 (1 day)] requires 1 day
[T2 (5 days)] requires 5 days
[T3 (1 week)] requires 1 week
[T4 (1 week and 4 days)] requires 1 week and 4 days
[T5 (2 weeks)] requires 2 weeks
@endgantt
''',
  ),
  SubSample(
    name: 'Start (absolute date)',
    source: r'''
@startgantt
Project starts 2020-07-01
[Prototype design] requires 15 days
[Test prototype] requires 10 days
[Prototype design] starts 2020-07-01
[Test prototype] starts 2020-07-16
@endgantt
''',
  ),
  SubSample(
    name: 'Start (relative)',
    source: r'''
@startgantt
[Prototype design] requires 15 days
[Test prototype] requires 10 days
[Prototype design] starts D+0
[Test prototype] starts D+15
@endgantt
''',
  ),
  SubSample(
    name: 'End (absolute date)',
    source: r'''
@startgantt
Project starts 2020-07-01
[Prototype design] requires 15 days
[Test prototype] requires 10 days
[Prototype design] ends 2020-07-15
[Test prototype] ends 2020-07-25
@endgantt
''',
  ),
  SubSample(
    name: 'End (relative)',
    source: r'''
@startgantt
[Prototype design] requires 15 days
[Test prototype] requires 10 days
[Prototype design] ends D+14
[Test prototype] ends D+24
@endgantt
''',
  ),
  SubSample(
    name: 'Start/End (absolute date)',
    source: r'''
@startgantt
Project starts 2020-07-01
[Prototype design] starts 2020-07-01
[Test prototype] starts 2020-07-16
[Prototype design] ends 2020-07-15
[Test prototype] ends 2020-07-25
@endgantt
''',
  ),
  SubSample(
    name: 'Start/End (relative)',
    source: r'''
@startgantt
[Prototype design] starts D+0
[Test prototype] starts D+15
[Prototype design] ends D+14
[Test prototype] ends D+24
@endgantt
''',
  ),
  SubSample(
    name: 'One-line declaration (with and conjunction)',
    source: r'''
@startgantt
Project starts 2020-07-01
[Prototype design] starts 2020-07-01 and ends 2020-07-15
[Test prototype] starts 2020-07-16 and requires 10 days
@endgantt
''',
  ),
  SubSample(
    name: 'Adding constraints',
    source: r'''
@startgantt
[Prototype design] requires 15 days
[Test prototype] requires 10 days
[Test prototype] starts at [Prototype design]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Adding constraints (multiple)',
    source: r'''
@startgantt
[Prototype design] requires 10 days
[Code prototype] requires 10 days
[Write tests] requires 5 days
[Code prototype] starts at [Prototype design]'s end
[Write tests] starts at [Code prototype]'s start
@endgantt
''',
  ),
  SubSample(
    name: 'Short names or alias',
    source: r'''
@startgantt
[Prototype design] as [D] requires 15 days
[Test prototype] as [T] requires 10 days
[T] starts at [D]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Tasks with same name',
    source: r'''
@startgantt
Project starts 2020-11-08
[Task 7 days] as [T7] starts at 2020-11-09
[T7] ends at 2020-11-15
[Task 7 days] as [T7bis] starts at 2020-11-09
[T7bis] ends at 2020-11-15
@endgantt
''',
  ),
  SubSample(
    name: 'Tasks with same name (colored)',
    source: r'''
@startgantt
[SameTaskName] as [T1] lasts 7 days and is colored in pink
[SameTaskName] as [T2] lasts 3 days and is colored in orange
[T1] -> [T2]
@endgantt
''',
  ),
  SubSample(
    name: 'Customize colors',
    source: r'''
@startgantt
[Prototype design] requires 13 days
[Test prototype] requires 4 days
[Test prototype] starts at [Prototype design]'s end
[Prototype design] is colored in Fuchsia/FireBrick
[Test prototype] is colored in GreenYellow/Green
@endgantt
''',
  ),
  SubSample(
    name: 'Adding completion percentage',
    source: r'''
@startgantt
[foo] requires 21 days
[foo] is 40% completed
[bar] requires 30 days and is 10% complete
@endgantt
''',
  ),
  SubSample(
    name: 'Change colour of completion (by style)',
    source: r'''
@startgantt
<style>
ganttDiagram {
  task {
    BackGroundColor GreenYellow
    LineColor Green
    unstarted {
      BackGroundColor Fuchsia
      LineColor FireBrick
    }
  }
}
</style>
[Prototype design] requires 7 days
[Test prototype 0] requires 4 days
[Test prototype 10] requires 4 days
[Test prototype 20] requires 4 days
[Test prototype 30] requires 4 days
[Test prototype 40] requires 4 days
[Test prototype 50] requires 4 days
[Test prototype 60] requires 4 days
[Test prototype 70] requires 4 days
[Test prototype 80] requires 4 days
[Test prototype 90] requires 4 days
[Test prototype 100] requires 4 days
[Test prototype 0] starts at [Prototype design]'s end
[Test prototype 10] starts at [Prototype design]'s end
[Test prototype 20] starts at [Prototype design]'s end
[Test prototype 30] starts at [Prototype design]'s end
[Test prototype 40] starts at [Prototype design]'s end
[Test prototype 50] starts at [Prototype design]'s end
[Test prototype 60] starts at [Prototype design]'s end
[Test prototype 70] starts at [Prototype design]'s end
[Test prototype 80] starts at [Prototype design]'s end
[Test prototype 90] starts at [Prototype design]'s end
[Test prototype 100] starts at [Prototype design]'s end
[Test prototype 0] is 0% complete
[Test prototype 10] is 10% complete
[Test prototype 20] is 20% complete
[Test prototype 30] is 30% complete
[Test prototype 40] is 40% complete
[Test prototype 50] is 50% complete
[Test prototype 60] is 60% complete
[Test prototype 70] is 70% complete
[Test prototype 80] is 80% complete
[Test prototype 90] is 90% complete
[Test prototype 100] is 100% complete
@endgantt
''',
  ),
  SubSample(
    name: 'Change colour of undone part of Task (by style)',
    source: r'''
@startgantt
<style>
ganttDiagram {
  task {
    BackGroundColor GreenYellow
    LineColor Green
  }
  undone {
    BackGroundColor red
  }
}
</style>
[foo] lasts 21 days
[foo] is 40% completed
[bar] lasts 30 days and is 10% complete
@endgantt
''',
  ),
  SubSample(
    name: 'Relative milestone (use of constraints)',
    source: r'''
@startgantt
[Test prototype] requires 10 days
[Prototype completed] happens at [Test prototype]'s end
[Setup assembly line] requires 12 days
[Setup assembly line] starts at [Test prototype]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Absolute milestone (fixed date)',
    source: r'''
@startgantt
Project starts 2020-07-01
[Test prototype] requires 10 days
[Prototype completed] happens 2020-07-10
[Setup assembly line] requires 12 days
[Setup assembly line] starts at [Test prototype]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Milestone of maximum end of tasks',
    source: r'''
@startgantt
[Task1] requires 4 days
[Task1.1] starts at [Task1]'s end and requires 4 days
[Task1.2] starts at [Task1]'s end and requires 7 days
[Task2] requires 5 days
[Task2.1] starts at [Task2]'s end and requires 4 days
[MaxTaskEnd] happens at [Task1.1]'s end
[MaxTaskEnd] happens at [Task1.2]'s end
[MaxTaskEnd] happens at [Task2.1]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Hyperlinks',
    source: r'''
@startgantt
[task1] requires 10 days
[task1] links to [[http://plantuml.com]]
@endgantt
''',
  ),
  SubSample(
    name: 'Calendar',
    source: r'''
@startgantt
Project starts the 20th of september 2017
[Prototype design] as [TASK1] requires 13 days
[TASK1] is colored in Lavender/LightBlue
@endgantt
''',
  ),
  SubSample(
    name: 'Coloring days',
    source: r'''
@startgantt
Project starts the 2020/09/01
2020/09/07 is colored in salmon
2020/09/13 to 2020/09/16 are colored in lightblue
[Prototype design] as [TASK1] requires 22 days
[TASK1] is colored in Lavender/LightBlue
[Prototype completed] happens at [TASK1]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Daily scale (by default)',
    source: r'''
@startgantt
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Weekly scale',
    source: r'''
@startgantt
printscale weekly
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Weekly scale (large)',
    source: r'''
@startgantt
printscale weekly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Monthly scale',
    source: r'''
@startgantt
projectscale monthly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Quarterly scale',
    source: r'''
@startgantt
projectscale quarterly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Quarterly scale (large)',
    source: r'''
@startgantt
projectscale quarterly
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Yearly scale',
    source: r'''
@startgantt
projectscale yearly
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Without date range',
    source: r'''
@startgantt
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 8 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 3 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'With date range',
    source: r'''
@startgantt
Print between 2021-01-12 and 2021-01-22
Saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 8 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 3 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on daily (without zoom)',
    source: r'''
@startgantt
printscale daily
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 8 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 3 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on daily (with zoom)',
    source: r'''
@startgantt
printscale daily zoom 2
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 8 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 3 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on weekly (without zoom)',
    source: r'''
@startgantt
printscale weekly
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on weekly (with zoom)',
    source: r'''
@startgantt
printscale weekly zoom 4
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on monthly (without zoom)',
    source: r'''
@startgantt
projectscale monthly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on monthly (with zoom)',
    source: r'''
@startgantt
projectscale monthly zoom 3
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on quarterly (without zoom)',
    source: r'''
@startgantt
projectscale quarterly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on quarterly (with zoom)',
    source: r'''
@startgantt
projectscale quarterly zoom 7
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on yearly (without zoom)',
    source: r'''
@startgantt
projectscale yearly
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Zoom on yearly (with zoom)',
    source: r'''
@startgantt
projectscale yearly zoom 2
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'With Weeknumbers (by default)',
    source: r'''
@startgantt
printscale weekly
Project starts the 6th of July 2020
[Task1] on {Alice} requires 2 weeks
[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'With Weeknumbers (starting from 1)',
    source: r'''
@startgantt
printscale weekly with week numbering from 1
Project starts the 6th of July 2020
[Task1] on {Alice} requires 2 weeks
[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'With specific Weeknumbers (starting from 11)',
    source: r'''
@startgantt
printscale weekly with week numbering from 11
Project starts the 6th of July 2020
[Task1] on {Alice} requires 2 weeks
[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'With specific Weeknumbers (starting from -3)',
    source: r'''
@startgantt
printscale weekly with week numbering from -3
Project starts the 6th of July 2020
[Task1] on {Alice} requires 2 weeks
[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'With Calendar Date',
    source: r'''
@startgantt
printscale weekly with calendar date
Project starts the 6th of July 2020
[Task1] on {Alice} requires 2 weeks
[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'Change first day of week',
    source: r'''
@startgantt
printscale weekly
weeks starts on Sunday and must have at least 4 days
friday are closed
saturday are closed
Project starts the 1st of january 2025
[Prototype design end] as [TASK1] requires 19 days
[Testing] requires 14 days
[TASK1]->[Testing]
@endgantt
''',
  ),
  SubSample(
    name: 'Close day',
    source: r'''
@startgantt
project starts the 2018/04/09
saturday are closed
sunday are closed
2018/05/01 is closed
2018/04/17 to 2018/04/19 is closed
[Prototype design] requires 14 days
[Test prototype] requires 4 days
[Test prototype] starts at [Prototype design]'s end
[Prototype design] is colored in Fuchsia/FireBrick
[Test prototype] is colored in GreenYellow/Green
@endgantt
''',
  ),
  SubSample(
    name: 'Close day with re-opened day',
    source: r'''
@startgantt
2020-07-07 to 2020-07-17 is closed
2020-07-13 is open
Project starts the 2020-07-01
[Prototype design] requires 10 days
Then [Test prototype] requires 10 days
@endgantt
''',
  ),
  SubSample(
    name: 'Week as 21 days (no closed days)',
    source: r'''
@startgantt
Project starts 2021-03-29
[Review 01] happens at 2021-03-29
[Review 02 - 3 weeks] happens on 3 weeks after [Review 01]'s end
[Review 02 - 21 days] happens on 21 days after [Review 01]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Week with closed days',
    source: r'''
@startgantt
Project starts 2021-03-29
saturday are closed
sunday are closed
[Review 01] happens at 2021-03-29
[Review 02 - 3 weeks] happens on 3 weeks after [Review 01]'s end
[Review 02 - 21 days] happens on 21 days after [Review 01]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Working days',
    source: r'''
@startgantt
saturday are closed
sunday are closed
2022-07-04 to 2022-07-15 is closed
Project starts 2022-06-27
[task1] starts at 2022-06-27 and requires 1 week
[task2] starts 2 working days after [task1]'s end and requires 3 days
@endgantt
''',
  ),
  SubSample(
    name: 'Simplified task succession (then)',
    source: r'''
@startgantt
[Prototype design] requires 14 days then [Test prototype] requires 4 days then [Deploy prototype] requires 6 days
@endgantt
''',
  ),
  SubSample(
    name: 'Simplified task succession (arrows)',
    source: r'''
@startgantt
[Prototype design] requires 14 days
[Build prototype] requires 4 days
[Prepare test] requires 6 days
[Prototype design] -> [Build prototype]
[Prototype design] -> [Prepare test]
@endgantt
''',
  ),
  SubSample(
    name: 'Working with resources',
    source: r'''
@startgantt
[Task1] on {Alice} requires 10 days
[Task2] on {Bob:50%} requires 2 days then [Task3] on {Alice:25%} requires 1 days
@endgantt
''',
  ),
  SubSample(
    name: 'Working with multiple resources',
    source: r'''
@startgantt
[Task1] on {Alice} {Bob} requires 20 days
@endgantt
''',
  ),
  SubSample(
    name: 'Resource off days',
    source: r'''
@startgantt
project starts on 2020-06-19
[Task1] on {Alice} requires 10 days
{Alice} is off on 2020-06-24 to 2020-06-26
@endgantt
''',
  ),
  SubSample(
    name: 'Without any hiding (by default)',
    source: r'''
@startgantt
[Task1] on {Alice} requires 10 days
[Task2] on {Bob:50%} requires 2 days then [Task3] on {Alice:25%} requires 1 days then [Task4] on {Alice:25%} {Bob} requires 1 days
@endgantt
''',
  ),
  SubSample(
    name: 'Hide resources names',
    source: r'''
@startgantt
hide resources names
[Task1] on {Alice} requires 10 days
[Task2] on {Bob:50%} requires 2 days then [Task3] on {Alice:25%} requires 1 days then [Task4] on {Alice:25%} {Bob} requires 1 days
@endgantt
''',
  ),
  SubSample(
    name: 'Hide resources footbox',
    source: r'''
@startgantt
hide resources footbox
[Task1] on {Alice} requires 10 days
[Task2] on {Bob:50%} requires 2 days then [Task3] on {Alice:25%} requires 1 days then [Task4] on {Alice:25%} {Bob} requires 1 days
@endgantt
''',
  ),
  SubSample(
    name: 'Hide resources names and footbox',
    source: r'''
@startgantt
hide resources names
hide resources footbox
[Task1] on {Alice} requires 10 days
[Task2] on {Bob:50%} requires 2 days then [Task3] on {Alice:25%} requires 1 days then [Task4] on {Alice:25%} {Bob} requires 1 days
@endgantt
''',
  ),
  SubSample(
    name: 'Horizontal Separator',
    source: r'''
@startgantt
[Task1] requires 10 days then [Task2] requires 4 days
-- Phase Two --
then [Task3] requires 5 days then [Task4] requires 6 days
@endgantt
''',
  ),
  SubSample(
    name: 'Vertical Separator',
    source: r'''
@startgantt
[task1] requires 1 week
[task2] starts 20 days after [task1]'s end and requires 3 days
Separator just at [task1]'s end
Separator just 2 days after [task1]'s end
Separator just at [task2]'s start
Separator just 2 days before [task2]'s start
@endgantt
''',
  ),
  SubSample(
    name: 'Complex example',
    source: r'''
@startgantt
[Prototype design] requires 13 days and is colored in Lavender/LightBlue
[Test prototype] requires 9 days and is colored in Coral/Green and starts 3 days after [Prototype design]'s end
[Write tests] requires 5 days and ends at [Prototype design]'s end
[Hire tests writers] requires 6 days and ends at [Write tests]'s start
[Init and write tests report] is colored in Coral/Green
[Init and write tests report] starts 1 day before [Test prototype]'s start and ends at [Test prototype]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Comments',
    source: r'''
@startgantt
' This is a comment
[T1] requires 3 days
/' this comment is on several lines '/
[T2] starts at [T1]'s end and requires 1 day
@endgantt
''',
  ),
  SubSample(
    name: 'Without style (by default)',
    source: r'''
@startgantt
[Task1] requires 20 days
note bottom
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[Task2] requires 4 days
[Task1] -> [Task2]
-- Separator title --
[M1] happens on 5 days after [Task1]'s end
-- end --
@endgantt
''',
  ),
  SubSample(
    name: 'With style',
    source: r'''
@startgantt
<style>
ganttDiagram {
  task {
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
    BackGroundColor GreenYellow
    LineColor blue
  }
  milestone {
    FontColor blue
    FontSize 25
    FontStyle italic
    BackGroundColor yellow
    LineColor red
  }
  note {
    FontColor DarkGreen
    FontSize 10
    LineColor OrangeRed
  }
  arrow {
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
    BackGroundColor GreenYellow
    LineColor blue
  }
  separator {
    LineColor red
    BackGroundColor green
    FontSize 16
    FontStyle bold
    FontColor purple
  }
}
</style>
[Task1] requires 20 days
note bottom
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[Task2] requires 4 days
[Task1] -> [Task2]
-- Separator title --
[M1] happens on 5 days after [Task1]'s end
-- end --
@endgantt
''',
  ),
  SubSample(
    name: 'With style (full example)',
    source: r'''
@startgantt
<style>
ganttDiagram {
  task {
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
    BackGroundColor GreenYellow
    LineColor blue
  }
  milestone {
    FontColor blue
    FontSize 25
    FontStyle italic
    BackGroundColor yellow
    LineColor red
  }
  note {
    FontColor DarkGreen
    FontSize 10
    LineColor OrangeRed
  }
  arrow {
    FontName Helvetica
    FontColor red
    FontSize 18
    FontStyle bold
    BackGroundColor GreenYellow
    LineColor blue
    LineStyle 8.0;13.0
    LineThickness 3.0
  }
  separator {
    BackgroundColor lightGreen
    LineStyle 8.0;3.0
    LineColor red
    LineThickness 1.0
    FontSize 16
    FontStyle bold
    FontColor purple
    Margin 5
    Padding 20
  }
  timeline {
    BackgroundColor Bisque
  }
  closed {
    BackgroundColor pink
    FontColor red
  }
}
</style>
Project starts the 2020-12-01
[Task1] requires 10 days
sunday are closed
note bottom
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[Task2] requires 20 days
[Task2] starts 10 days after [Task1]'s end
-- Separator title --
[M1] happens on 5 days after [Task1]'s end
<style>
separator {
  LineColor black
  Margin 0
  Padding 0
}
</style>
-- end --
@endgantt
''',
  ),
  SubSample(
    name: 'Clean style',
    source: r'''
@startgantt
<style>
ganttDiagram {
  timeline {
    LineColor transparent
    FontColor transparent
  }
}
</style>
hide footbox
[Test prototype] requires 7 days
[Prototype completed] happens at [Test prototype]'s end
[Setup assembly line] requires 9 days
[Setup assembly line] starts at [Test prototype]'s end
then [Setup] requires 5 days
[T2] requires 2 days and starts at [Test prototype]'s end
then [T3] requires 3 days
-- end task --
then [T4] requires 2 days
@endgantt
''',
  ),
  SubSample(
    name: 'Clean style (with closed days)',
    source: r'''
@startgantt
<style>
ganttDiagram {
  timeline {
    LineColor transparent
    FontColor transparent
  }
  closed {
    FontColor transparent
  }
}
</style>
hide footbox
project starts the 2018/04/09
saturday are closed
sunday are closed
2018/05/01 is closed
2018/04/17 to 2018/04/19 is closed
[Prototype design] requires 9 days
[Test prototype] requires 5 days
[Test prototype] starts at [Prototype design]'s end
[Prototype design] is colored in Fuchsia/FireBrick
[Test prototype] is colored in GreenYellow/Green
@endgantt
''',
  ),
  SubSample(
    name: 'Add notes',
    source: r'''
@startgantt
[task01] requires 15 days
note bottom
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[task01] -> [task02]
@endgantt
''',
  ),
  SubSample(
    name: 'Add notes (with overlap)',
    source: r'''
@startgantt
[task01] requires 15 days
note bottom
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[task01] -> [task02]
[task03] requires 5 days
@endgantt
''',
  ),
  SubSample(
    name: 'Add notes (multiple sections)',
    source: r'''
@startgantt
-- test01 --
[task01] requires 4 days
note bottom
  'note left
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
[task02] requires 8 days
[task01] -> [task02]
note bottom
  'note left
  memo1 ...
  memo2 ...
  explanations1 ...
  explanations2 ...
end note
-- test02 --
[task03] as [t3] requires 7 days
[t3] -> [t4]
@endgantt
''',
  ),
  SubSample(
    name: 'Add notes (same row)',
    source: r'''
@startgantt
Project starts 2020-09-01
[taskA] starts 2020-09-01 and requires 3 days
[taskB] starts 2020-09-10 and requires 3 days
[taskB] displays on same row as [taskA]
[task01] starts 2020-09-05 and requires 4 days
then [task02] requires 8 days
note bottom
  note for task02
  more notes
end note
then [task03] requires 7 days
note bottom
  note for task03
  more notes
end note
-- separator --
[taskC] starts 2020-09-02 and requires 5 days
[taskD] starts 2020-09-09 and requires 5 days
[taskD] displays on same row as [taskC]
[task 10] starts 2020-09-05 and requires 5 days
then [task 11] requires 5 days
note bottom
  note for task11
  more notes
end note
@endgantt
''',
  ),
  SubSample(
    name: 'Pause tasks',
    source: r'''
@startgantt
Project starts the 5th of december 2018
saturday are closed
sunday are closed
2018/12/29 is opened
[Prototype design] requires 17 days
[Prototype design] pauses on 2018/12/13
[Prototype design] pauses on 2018/12/14
[Prototype design] pauses on monday
[Test prototype] starts at [Prototype design]'s end and requires 2 weeks
@endgantt
''',
  ),
  SubSample(
    name: 'Change link colors',
    source: r'''
@startgantt
[T1] requires 4 days
[T2] requires 4 days and starts 3 days after [T1]'s end with blue dotted link
[T3] requires 4 days and starts 3 days after [T2]'s end with green bold link
[T4] requires 4 days and starts 3 days after [T3]'s end with green dashed link
@endgantt
''',
  ),
  SubSample(
    name: 'Change link colors (by style)',
    source: r'''
@startgantt
<style>
ganttDiagram {
  arrow {
    LineColor blue
  }
}
</style>
[Prototype design] requires 7 days
[Build prototype] requires 4 days
[Prepare test] requires 6 days
[Prototype design] -[#FF00FF]-> [Build prototype]
[Prototype design] -[dotted]-> [Prepare test]
Then [Run test] requires 4 days
@endgantt
''',
  ),
  SubSample(
    name: 'Tasks or Milestones on the same line',
    source: r'''
@startgantt
[Prototype design] requires 13 days
[Test prototype] requires 4 days and 1 week
[Test prototype] starts 1 week and 2 days after [Prototype design]'s end
[Test prototype] displays on same row as [Prototype design]
[r1] happens on 5 days after [Prototype design]'s end
[r2] happens on 5 days after [r1]'s end
[r3] happens on 5 days after [r2]'s end
[r2] displays on same row as [r1]
[r3] displays on same row as [r1]
@endgantt
''',
  ),
  SubSample(
    name: 'Highlight today',
    source: r'''
@startgantt
Project starts the 20th of september 2018
sunday are close
2018/09/21 to 2018/09/23 are colored in salmon
2018/09/21 to 2018/09/30 are named [Vacation in the Bahamas]
today is 30 days after start and is colored in #AAF
[Foo] happens 40 days after start
[Dummy] requires 10 days and starts 10 days after start
@endgantt
''',
  ),
  SubSample(
    name: 'Task between two milestones',
    source: r'''
@startgantt
project starts on 2020-07-01
[P_start] happens 2020-07-03
[P_end] happens 2020-07-13
[Prototype design] occurs from [P_start] to [P_end]
@endgantt
''',
  ),
  SubSample(
    name: 'Add title, header, footer, caption or legend',
    source: r'''
@startgantt
header some header
footer some footer
title My title
[Prototype design] requires 13 days
legend
  The legend
end legend
caption This is caption
@endgantt
''',
  ),
  SubSample(
    name: 'Add color on legend',
    source: r'''
@startgantt
[Kick off] requires 1 days and is colored in blue
then [Prototype design] requires 5 days
[Test prototype] requires 4 days
[Test prototype] starts at [Prototype design]'s end
[Prototype design] is colored in Green
[Test prototype] is colored in gray
legend
  Legend:
  |= Color |= Task Type |
  |<#gray> | Planned |
  |<#Green>| In progress |
  |<#blue> | Done |
end legend
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (daily, no start)',
    source: r'''
@startgantt
hide footbox
title Foot Box removed
[Prototype design] requires 15 days
[Test prototype] requires 10 days
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (daily)',
    source: r'''
@startgantt
Project starts the 20th of september 2017
[Prototype design] as [TASK1] requires 13 days
[TASK1] is colored in Lavender/LightBlue
hide footbox
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (weekly)',
    source: r'''
@startgantt
hide footbox
printscale weekly
saturday are closed
sunday are closed
Project starts the 1st of january 2021
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (monthly)',
    source: r'''
@startgantt
hide footbox
projectscale monthly
Project starts the 20th of september 2020
[Prototype design] as [TASK1] requires 130 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 20 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are named [End's committee]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (quarterly)',
    source: r'''
@startgantt
hide footbox
projectscale quarterly
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Removing Foot Boxes (yearly)',
    source: r'''
@startgantt
hide footbox
projectscale yearly
Project starts the 1st of october 2020
[Prototype design] as [TASK1] requires 700 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 200 days
[TASK1]->[Testing]
2021-01-18 to 2021-03-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Language English (default)',
    source: r'''
@startgantt
saturday are closed
sunday are closed
Project starts 2021-01-01
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Language Deutsch (de)',
    source: r'''
@startgantt
language de
saturday are closed
sunday are closed
Project starts 2021-01-01
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Language Japanese (ja)',
    source: r'''
@startgantt
language ja
saturday are closed
sunday are closed
Project starts 2021-01-01
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Language Chinese (zh)',
    source: r'''
@startgantt
language zh
saturday are closed
sunday are closed
Project starts 2021-01-01
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Language Korean (ko)',
    source: r'''
@startgantt
language ko
saturday are closed
sunday are closed
Project starts 2021-01-01
[Prototype design end] as [TASK1] requires 19 days
[TASK1] is colored in Lavender/LightBlue
[Testing] requires 14 days
[TASK1]->[Testing]
2021-01-18 to 2021-01-22 are colored in salmon
@endgantt
''',
  ),
  SubSample(
    name: 'Delete Tasks or Milestones',
    source: r'''
@startgantt
[Prototype design] requires 1 weeks
[Prototype completed] starts at [Prototype design]'s end and requires 4 days
[End Prototype completed] happens at [Prototype completed]'s end
[Test prototype] starts at [Prototype completed]'s end and requires 5 days
[End Test prototype] happens at [Test prototype]'s end
[Prototype completed] is deleted
[End Prototype completed] is deleted
@endgantt
''',
  ),
  SubSample(
    name: 'Start project before or after today',
    source: r'''
@startgantt
title Today is %date("YYYY-MM-dd")
!$now = %now()
!$past = %date("YYYY-MM-dd", $now - 14*24*3600)
Project starts $past
today is colored in pink
[foo] requires 10 days
[bar] requires 5 days and starts %date("YYYY-MM-dd", $now + 4*24*3600)
[Tomorrow] happens %date("YYYY-MM-dd", $now + 1*24*3600)
@endgantt
''',
  ),
  SubSample(
    name: 'Labels near elements (default)',
    source: r'''
@startgantt
[Task1] requires 1 days
then [Task2_long_long_long] as [T2] requires 2 days
-- Phase Two --
then [Task3] as [T3] requires 2 days
[Task4] as [T4] requires 1 day
[Task5] as [T5] requires 2 days
[T2] -> [T4]
[T2] -> [T5]
[Task6_long_long_long] as [T6] requires 4 days
[T3] -> [T6]
[T5] -> [T6]
[End] happens 1 day after [T6]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Label on first column (left aligned)',
    source: r'''
@startgantt
Label on first column and left aligned
[Task1] requires 1 days
then [Task2_long_long_long] as [T2] requires 2 days
-- Phase Two --
then [Task3] as [T3] requires 2 days
[Task4] as [T4] requires 1 day
[Task5] as [T5] requires 2 days
[T2] -> [T4]
[T2] -> [T5]
[Task6_long_long_long] as [T6] requires 4 days
[T3] -> [T6]
[T5] -> [T6]
[End] happens 1 day after [T6]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Label on first column (right aligned)',
    source: r'''
@startgantt
Label on first column and right aligned
[Task1] requires 1 days
then [Task2_long_long_long] as [T2] requires 2 days
-- Phase Two --
then [Task3] as [T3] requires 2 days
[Task4] as [T4] requires 1 day
[Task5] as [T5] requires 2 days
[T2] -> [T4]
[T2] -> [T5]
[Task6_long_long_long] as [T6] requires 4 days
[T3] -> [T6]
[T5] -> [T6]
[End] happens 1 day after [T6]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Label on last column (left aligned)',
    source: r'''
@startgantt
Label on last column and left aligned
[Task1] requires 1 days
then [Task2_long_long_long] as [T2] requires 2 days
-- Phase Two --
then [Task3] as [T3] requires 2 days
[Task4] as [T4] requires 1 day
[Task5] as [T5] requires 2 days
[T2] -> [T4]
[T2] -> [T5]
[Task6_long_long_long] as [T6] requires 4 days
[T3] -> [T6]
[T5] -> [T6]
[End] happens 1 day after [T6]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Label on last column (right aligned)',
    source: r'''
@startgantt
Label on last column and right aligned
[Task1] requires 1 days
then [Task2_long_long_long] as [T2] requires 2 days
-- Phase Two --
then [Task3] as [T3] requires 2 days
[Task4] as [T4] requires 1 day
[Task5] as [T5] requires 2 days
[T2] -> [T4]
[T2] -> [T5]
[Task6_long_long_long] as [T6] requires 4 days
[T3] -> [T6]
[T5] -> [T6]
[End] happens 1 day after [T6]'s end
@endgantt
''',
  ),
  SubSample(
    name: 'Definition of a month (30 days)',
    source: r'''
@startgantt
[A] lasts 2 days
[B] lasts 2 weeks
[C] lasts 1 month
@endgantt
''',
  ),
];
