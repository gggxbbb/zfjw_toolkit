import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/feature_flags/feature_flags.dart';
import '../../ui/kit/kit.dart';

class FeatureFlagsCard extends ConsumerWidget {
  const FeatureFlagsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    return AppGlassGroupedCard(
      title: '功能开关',
      child: flags.when(
        loading: () => const AppGlassProgress(),
        error: (_, _) => Column(
          children: [
            Text(
              '无法读取功能开关',
              style: AppText.body.copyWith(color: AppTokens.of(context).danger),
            ),
            AppGlassButton(
              label: '重试',
              onTap: () => ref.invalidate(featureFlagsProvider),
            ),
          ],
        ),
        data: (values) => Column(
          children: [
            for (final flag in FeatureFlag.values) ...[
              if (flag != FeatureFlag.values.first)
                const SizedBox(height: AppTokens.space4),
              _FlagRow(key: ValueKey(flag), flag: flag, enabled: values[flag]!),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlagRow extends ConsumerStatefulWidget {
  const _FlagRow({super.key, required this.flag, required this.enabled});
  final FeatureFlag flag;
  final bool enabled;
  @override
  ConsumerState<_FlagRow> createState() => _FlagRowState();
}

class _FlagRowState extends ConsumerState<_FlagRow> {
  bool saving = false;
  String? error;

  Future<void> save(bool value) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(featureFlagsProvider.notifier)
          .setEnabled(widget.flag, value);
    } catch (_) {
      if (mounted) setState(() => error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.flag.label,
                style: AppText.body.copyWith(color: tokens.labelPrimary),
              ),
              const SizedBox(height: AppTokens.space1),
              Text(
                widget.flag.description,
                style: AppText.footnote.copyWith(color: tokens.labelSecondary),
              ),
              if (error != null)
                Text(
                  error!,
                  style: AppText.footnote.copyWith(color: tokens.danger),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.space3),
        Semantics(
          label: widget.flag.label,
          child: AppGlassSwitch(
            value: widget.enabled,
            onChanged: saving ? null : save,
          ),
        ),
      ],
    );
  }
}
