import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/course.dart';
import 'courses_providers.dart';

// ─────────────────────────────────────────────
// FAVOURITES — persisted in SharedPreferences
// ─────────────────────────────────────────────

class FavouritesNotifier extends StateNotifier<Set<String>> {
  static const _key = 'bansal-favourite-courses';

  FavouritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    state = ids.toSet();
  }

  Future<void> toggle(String courseId) async {
    final next = Set<String>.from(state);
    if (next.contains(courseId)) {
      next.remove(courseId);
    } else {
      next.add(courseId);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }

  bool isFavourite(String courseId) => state.contains(courseId);
}

final favouritesProvider =
    StateNotifierProvider<FavouritesNotifier, Set<String>>(
      (_) => FavouritesNotifier(),
    );

// Provides the full Course objects for all favourited IDs.
// Falls back to an empty list if any fetch fails.
final favouriteCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final ids = ref.watch(favouritesProvider);
  if (ids.isEmpty) return [];
  final futures = ids.map((id) => ref.watch(courseDetailProvider(id).future));
  final results = await Future.wait(futures, eagerError: false);
  return results;
});
