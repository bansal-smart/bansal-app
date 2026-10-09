import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/live_class.dart';

class LiveClassesRepository {
  final SupabaseClient _client;

  LiveClassesRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  Future<List<LiveClass>> fetchAll() async {
    try {
      final data = await _client
          .from('live_classes')
          .select(
            'id, title, subject, educator_name, educator_avatar, '
            'starts_at, ends_at, meeting_url, status, description, recording_url',
          )
          .not('status', 'eq', 'cancelled')
          .order('starts_at');
      return (data as List<dynamic>)
          .map((row) => LiveClass.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
