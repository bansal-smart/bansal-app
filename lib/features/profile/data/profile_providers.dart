import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user_profile.dart';
import '../../auth/data/repositories/user_repository.dart';
import 'profile_stats_repository.dart';

class School {
  final String id;
  final String name;
  const School({required this.id, required this.name});
}

final schoolsProvider = FutureProvider.autoDispose<List<School>>((ref) async {
  final client = SupabaseService.client;
  final data = await client
      .from('schools')
      .select('id, name')
      .eq('is_active', true)
      .order('name');
  return (data as List)
      .map((e) => School(id: e['id'] as String, name: e['name'] as String))
      .toList();
});

// NOT autoDispose — stays alive so invalidation from edit-profile
// propagates to every screen watching it simultaneously.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(authStateProvider);
  final user = ref.watch(authRepositoryProvider).currentUser();
  if (user == null) return null;

  final repo = UserRepository();
  return repo.fetchUserProfile(user.id);
});

final profileStatsRepositoryProvider = Provider<ProfileStatsRepository>(
  (_) => ProfileStatsRepository(),
);

final profileStatsProvider = FutureProvider.autoDispose<ProfileStats>((ref) {
  return ref.watch(profileStatsRepositoryProvider).fetchStats();
});

final recentActivityProvider = FutureProvider.autoDispose<List<ActivityItem>>((
  ref,
) {
  return ref.watch(profileStatsRepositoryProvider).fetchRecentActivity();
});
