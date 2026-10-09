import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/landing_hero_banner.dart';

const _bannerSelect = 'id, image_url, alt, link, sort_order';

/// Uses the same table as the website's hero carousel so both surfaces stay
/// in sync. Database changes refresh this provider while the home screen is
/// open; pull-to-refresh is supported as a fallback as well.
final landingHeroBannersProvider =
    FutureProvider.autoDispose<List<LandingHeroBanner>>((ref) async {
      final client = Supabase.instance.client;

      final channel = client
          .channel('app_landing_hero_banners')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'landing_hero_banners',
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() => client.removeChannel(channel));

      final data = await client
          .from('landing_hero_banners')
          .select(_bannerSelect)
          .eq('is_active', true)
          .order('sort_order')
          .order('created_at');

      return (data as List<dynamic>)
          .map((row) => LandingHeroBanner.fromJson(row as Map<String, dynamic>))
          .where((banner) => banner.imageUrl.trim().isNotEmpty)
          .toList(growable: false);
    });
