import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../../ui/kit/kit.dart';
import 'dialogs.dart';
import 'model.dart';

/// 对一周内同一天的重叠区间分组、分配并排列，不按课程名折叠。
List<({ClassSession session, int lane, int lanes})> layoutDay(
  List<ClassSession> sessions,
) {
  final sorted = sessions.toList()..sort(compareSessions);
  final result = <({ClassSession session, int lane, int lanes})>[];
  var group = <ClassSession>[];
  var end = 0;
  void flush() {
    final laneEnds = <int>[];
    final placed = <({ClassSession session, int lane})>[];
    for (final s in group) {
      var lane = laneEnds.indexWhere((e) => e < s.start);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(s.end);
      } else {
        laneEnds[lane] = s.end;
      }
      placed.add((session: s, lane: lane));
    }
    result.addAll(
      placed.map(
        (p) => (session: p.session, lane: p.lane, lanes: laneEnds.length),
      ),
    );
    group = [];
  }

  for (final s in sorted) {
    if (group.isNotEmpty && s.start > end) {
      flush();
      end = 0;
    }
    group.add(s);
    end = math.max(end, s.end);
  }
  flush();
  return result;
}

class TimetableWeekGrid extends StatelessWidget {
  const TimetableWeekGrid({
    super.key,
    required this.term,
    required this.week,
    required this.sessions,
    this.today,
  });
  final TimetableTerm term;
  final int week;
  final List<ClassSession> sessions;
  final DateTime? today;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final current = today ?? DateTime.now();
    final visible = sessions.where((s) => s.week == week).toList();
    final periods = visible.fold(13, (n, s) => math.max(n, s.end));
    const rowHeight = 78.0;
    const gutter = 42.0;
    const headerHeight = 48.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - gutter) / 7;
        return SizedBox(
          height: headerHeight + periods * rowHeight,
          child: Stack(
            children: [
              for (var day = 1; day <= 7; day++) ...[
                Positioned(
                  left: gutter + (day - 1) * dayWidth,
                  top: 0,
                  width: dayWidth,
                  height: headerHeight + periods * rowHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          dateLabel(term.dateFor(week, day)) ==
                              dateLabel(current)
                          ? tokens.accentSubtle
                          : null,
                      border: Border(
                        left: BorderSide(color: tokens.separator, width: .5),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${'一二三四五六日'[day - 1]}\n${term.dateFor(week, day).month}/${term.dateFor(week, day).day}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.labelPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              for (var period = 1; period <= periods; period++) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: headerHeight + (period - 1) * rowHeight,
                  child: Container(height: .5, color: tokens.separator),
                ),
                Positioned(
                  left: 0,
                  width: gutter - 2,
                  top: headerHeight + (period - 1) * rowHeight + 6,
                  child: Text(
                    '$period\n${periodTime(period)}\n${periodTime(period, end: true)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.6,
                      color: tokens.labelSecondary,
                    ),
                  ),
                ),
              ],
              for (var day = 1; day <= 7; day++)
                for (final p in layoutDay(
                  visible.where((s) => s.day == day).toList(),
                ))
                  Positioned(
                    left:
                        gutter +
                        (day - 1) * dayWidth +
                        p.lane * dayWidth / p.lanes +
                        1,
                    top: headerHeight + (p.session.start - 1) * rowHeight + 2,
                    width: math.max(1, dayWidth / p.lanes - 2),
                    height:
                        (p.session.end - p.session.start + 1) * rowHeight - 4,
                    child: Semantics(
                      button: true,
                      label:
                          '${p.session.name} ${p.session.when}${p.lanes > 1 ? ' 时间冲突' : ''}',
                      child: GestureDetector(
                        onTap: () =>
                            showSessionDetails(context, p.session, term),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: tokens.accent.withAlpha(32),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: p.lanes > 1
                                  ? tokens.danger
                                  : tokens.accent.withAlpha(100),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.session.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.labelPrimary,
                                  ),
                                ),
                                if (p.session.type.isNotEmpty)
                                  _Tag(p.session.type),
                                if (p.session.adjusted) const _Tag('调课'),
                                if (p.lanes > 1) const _Tag('时间冲突'),
                                if (p.session.location.isNotEmpty)
                                  Text(
                                    p.session.location,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: tokens.labelSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: AppTokens.of(context).accentSubtle,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: AppTokens.of(context).labelPrimary,
        ),
      ),
    ),
  );
}
