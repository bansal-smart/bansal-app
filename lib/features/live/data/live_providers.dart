import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/live_class.dart';

const _liveSelect =
    'id, title, subject, educator_name, educator_avatar, '
    'starts_at, ends_at, meeting_url, status, description, recording_url, course_id, slug';

/// All non-cancelled live classes, visible to every logged-in student —
/// mirrors the web app's useLiveClasses hook, which applies no
/// course/enrollment scoping.
final accessibleLiveClassesProvider =
    FutureProvider.autoDispose<List<LiveClass>>((ref) async {
      final client = Supabase.instance.client;

      // Auto-refresh the list on any live_classes change, same as web's
      // postgres_changes subscription invalidating its query cache.
      final channel = client
          .channel('live_classes_list')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_classes',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() => client.removeChannel(channel));

      final data = await client
          .from('live_classes')
          .select(_liveSelect)
          .not('status', 'eq', 'cancelled')
          .order('starts_at');

      return (data as List)
          .map((r) => LiveClass.fromJson(r as Map<String, dynamic>))
          .toList();
    });

// Kept for callers that don't need the realtime subscription.
final liveClassesProvider = FutureProvider.autoDispose<List<LiveClass>>((
  ref,
) async {
  final data = await Supabase.instance.client
      .from('live_classes')
      .select(_liveSelect)
      .not('status', 'eq', 'cancelled')
      .order('starts_at');
  return (data as List)
      .map((r) => LiveClass.fromJson(r as Map<String, dynamic>))
      .toList();
});

// Single live class by id — used by the room screen
final liveClassByIdProvider = FutureProvider.autoDispose
    .family<LiveClass?, String>((ref, id) async {
      final data = await Supabase.instance.client
          .from('live_classes')
          .select(_liveSelect)
          .eq('id', id)
          .single();
      return LiveClass.fromJson(data);
    });
