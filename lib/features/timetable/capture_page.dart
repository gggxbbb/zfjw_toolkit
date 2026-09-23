import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../capture/timetable_capture.dart';
import '../capture/web_capture_page.dart';
import 'dialogs.dart';
import 'diff.dart';
import 'model.dart';
import 'parser.dart';
import 'providers.dart';

class TimetableCapturePage extends ConsumerStatefulWidget {
  const TimetableCapturePage({super.key});
  @override
  ConsumerState<TimetableCapturePage> createState() =>
      _TimetableCapturePageState();
}

class _TimetableCapturePageState extends ConsumerState<TimetableCapturePage> {
  TimetableCapture? pending;
  TimetableTerm? existing;
  List<SessionChange> changes = [];
  DateTime? monday;
  int weeks = 1;
  bool unchanged = false;

  @override
  Widget build(BuildContext context) => WebCapturePage(
    title: '采集课表',
    manualCapture: true,
    instruction: '登录后打开个人课表查询，选好学期并查询，再点击“采集当前学期”',
    targetPageStatus: '选好学期并查询，加载完成后点击“采集当前学期”',
    handlerName: timetableHandler,
    matchesPage: (url) =>
        Uri.tryParse(url ?? '')?.path.endsWith('/$timetablePageMarker') ??
        false,
    script: timetableCaptureScript,
    onPayload: (payload, _) async {
      try {
        final capture = parseTimetablePayload(payload);
        final repo = ref.read(timetableRepositoryProvider);
        final terms = await repo.terms();
        final versions = await repo.history(capture.term);
        pending = capture;
        existing = terms.where((t) => t.id == capture.term).firstOrNull;
        monday = existing?.monday;
        weeks = (existing?.weeks ?? capture.lastWeek).clamp(
          capture.lastWeek,
          60,
        );
        changes = diffTimetable(
          versions.firstOrNull?.sessions ?? [],
          capture.sessions,
        );
        unchanged = versions.isNotEmpty && changes.isEmpty;
        return WebCaptureResult.review(
          '读取完成',
          overview: [capture.label, '${capture.sessions.length} 次课'],
          commit: () async {
            if (unchanged) {
              await repo.checked(capture.term);
            } else {
              await repo.accept(capture, monday!, weeks);
            }
            ref.invalidate(timetableTermsProvider);
            ref.invalidate(timetableHistoryProvider(capture.term));
          },
        );
      } on FormatException catch (e) {
        return WebCaptureResult.failure('课表未更新\n${e.message}');
      } catch (e) {
        return WebCaptureResult.failure('无法读取课表：$e');
      }
    },
    review: (context, result) async {
      final capture = pending!;
      if (unchanged) {
        await showTimetableMessage(context, '课表无变化', '本次不新增快照，只更新最后检查时间。');
        return CaptureReviewAction.accept;
      }
      if (monday == null) {
        final settings = await editTermSettings(
          context,
          weeks: weeks,
          minimumWeeks: capture.lastWeek,
        );
        if (settings == null || !context.mounted) {
          return CaptureReviewAction.retry;
        }
        monday = settings.$1;
        weeks = settings.$2;
      }
      if (!context.mounted) return CaptureReviewAction.retry;
      final accepted = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => TimetableDiffPage(
            changes: changes,
            confirm: true,
            subtitle:
                '${capture.label} · ${capture.sessions.length} 次课${existing == null ? ' · 首次采集' : ''}',
          ),
        ),
      );
      return accepted == true
          ? CaptureReviewAction.accept
          : CaptureReviewAction.retry;
    },
    onSuccess: () => Navigator.pop(context, pending?.term),
  );
}
