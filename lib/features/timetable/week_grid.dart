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
    final counts = <String, int>{};
    final ordinals = <ClassSession, int>{};
    for (final session in sessions.toList()..sort(compareSessions)) {
      ordinals[session] = counts.update(
        session.courseKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final periods = visible.fold(13, (n, s) => math.max(n, s.end));
    const gutter = AppTokens.space6;
    const headerHeight = AppTokens.space6 + AppTokens.space4;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * .7;
        final rowHeight = math.max(
          1.0,
          (availableHeight - headerHeight) / periods,
        );
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
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.space1,
                        ),
                        child: Text(
                          '${'一二三四五六日'[day - 1]}\n${term.dateFor(week, day).month}/${term.dateFor(week, day).day}',
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(
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
                  top: headerHeight + (period - 1) * rowHeight,
                  height: rowHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$period\n${periodTime(period)}\n${periodTime(period, end: true)}',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        height: 1.1,
                        color: tokens.labelSecondary,
                      ),
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
                          padding: const EdgeInsets.all(AppTokens.space1 / 2),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: tokens
                                .courseColors(p.session.name)
                                .background,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusControl / 2,
                            ),
                            border: Border.all(
                              color: p.lanes > 1
                                  ? tokens.danger
                                  : tokens.courseColors(p.session.name).border,
                            ),
                          ),
                          child: _FittedSessionText(
                            session: p.session,
                            ordinal: ordinals[p.session]!,
                            conflict: p.lanes > 1,
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

/// Fit the complete content, including long locations and class identifiers,
/// into the actual slot. Measurement and painting share the same text scaler.
class _FittedSessionText extends StatelessWidget {
  const _FittedSessionText({
    required this.session,
    required this.ordinal,
    required this.conflict,
  });
  final ClassSession session;
  final int ordinal;
  final bool conflict;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    TextSpan content(double size) {
      final base = AppText.caption.copyWith(
        fontSize: size,
        height: 1.05,
        color: tokens.labelPrimary,
      );
      return TextSpan(
        style: base,
        children: [
          TextSpan(
            text: '${session.name}\n',
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text:
                '${[if (session.type.isNotEmpty) session.type, '第 $ordinal 次'].join(' · ')}\n',
          ),
          if (session.adjusted || conflict)
            TextSpan(
              text:
                  '${[if (session.adjusted) '调课', if (conflict) '时间冲突'].join(' · ')}\n',
              style: base.copyWith(
                color: conflict ? tokens.danger : tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (session.location.isNotEmpty)
            TextSpan(text: '${session.location}\n'),
          TextSpan(
            text:
                '${periodTime(session.start)}–${periodTime(session.end, end: true)}',
            style: base.copyWith(color: tokens.labelSecondary),
          ),
          if (session.teacher.isNotEmpty)
            TextSpan(text: '\n${session.teacher}'),
          if (session.group.isNotEmpty)
            TextSpan(
              text: '\n${session.group}',
              style: base.copyWith(color: tokens.labelSecondary),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        var low = 0.01;
        var high = AppText.caption.fontSize!;
        final painter = TextPainter(
          textDirection: direction,
          textScaler: scaler,
        );
        for (var i = 0; i < 16; i++) {
          final size = (low + high) / 2;
          painter.text = content(size);
          painter.layout(maxWidth: bounds.maxWidth);
          if (painter.height <= bounds.maxHeight &&
              painter.width <= bounds.maxWidth) {
            low = size;
          } else {
            high = size;
          }
        }
        painter.dispose();
        return RichText(
          text: content(low),
          textScaler: scaler,
          textDirection: direction,
        );
      },
    );
  }
}
