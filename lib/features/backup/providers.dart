import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/feature_flags/feature_flags.dart';
import '../gpa/state/gpa_providers.dart';
import '../settings/state/gpa_goals.dart';
import '../target/state/plan_providers.dart';
import '../timetable/providers.dart';
import 'backup_service.dart';
import 'document_gateway.dart';

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider), LocalBackupPreferences()),
);
final documentGatewayProvider = Provider<DocumentGateway>(
  (ref) => SystemDocumentGateway(),
);
final backupRecoveryProvider = FutureProvider<void>(
  (ref) => ref.watch(backupServiceProvider).recover(),
);

void refreshRestoredData(WidgetRef ref) {
  ref.invalidate(latestSnapshotProvider);
  ref.invalidate(recordOverridesProvider);
  ref.invalidate(teachingPlanProvider);
  ref.invalidate(planOverridesProvider);
  ref.invalidate(gpaGoalsProvider);
  ref.invalidate(featureFlagsProvider);
  ref.invalidate(timetableTermsProvider);
  ref.invalidate(timetableHistoryProvider);
}
