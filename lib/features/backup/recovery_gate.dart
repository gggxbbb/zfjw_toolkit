import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/kit/kit.dart';
import 'providers.dart';

class BackupRecoveryGate extends ConsumerWidget {
  const BackupRecoveryGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(backupRecoveryProvider)
      .when(
        data: (_) => child,
        loading: () =>
            const AppGlassScaffold(body: Center(child: AppGlassProgress())),
        error: (error, _) => AppGlassScaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '数据恢复尚未完成',
                      style: AppText.title.copyWith(
                        color: AppTokens.of(context).danger,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Text(
                      '请重试后继续使用。原有恢复记录已保留。\n$error',
                      style: AppText.body.copyWith(
                        color: AppTokens.of(context).labelSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    AppGlassButton(
                      label: '重试恢复',
                      onTap: () => ref.invalidate(backupRecoveryProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
