import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved.dart';
import 'data/account_repository.dart';

final savedListsProvider =
    FutureProvider.autoDispose<List<SavedList>>((ref) async {
  return ref.watch(accountRepositoryProvider).savedLists();
});
