import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gpa/state/gpa_providers.dart';
import 'model.dart';
import 'repository.dart';

final timetableRepositoryProvider = Provider<TimetableRepository>(
  (ref) => TimetableRepository(ref.watch(databaseProvider)),
);
final timetableTermsProvider = FutureProvider<List<TimetableTerm>>(
  (ref) => ref.watch(timetableRepositoryProvider).terms(),
);
final timetableHistoryProvider =
    FutureProvider.family<List<TimetableSnapshot>, String>(
      (ref, term) => ref.watch(timetableRepositoryProvider).history(term),
    );
