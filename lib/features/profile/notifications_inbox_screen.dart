import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../skeleton_loading/notification_skeleton.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
}

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String type;
  final String? link;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.link,
    required this.isRead,
    required this.isArchived,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      body: j['body'] as String?,
      type: j['type'] as String? ?? 'system',
      link: j['link'] as String?,
      isRead: j['read_at'] != null,
      isArchived: j['archived_at'] != null,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    link: link,
    isRead: isRead ?? this.isRead,
    isArchived: isArchived,
    createdAt: createdAt,
  );
}

// ─────────────────────────────────────────────
// FILTERS — mirrors the web app's TYPE_FILTERS exactly (substring match
// against notifications.type, not exact equality).
// ─────────────────────────────────────────────
enum _Filter { all, unread, classes, courses }

const _kFilterLabels = {
  _Filter.all: 'All',
  _Filter.unread: 'Unread',
  _Filter.classes: 'Classes',
  _Filter.courses: 'Courses',
};

const _kFilterTypeMatch = {
  _Filter.classes: 'live_class',
  _Filter.courses: 'course',
};

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final _notificationsProvider =
    StateNotifierProvider.autoDispose<
      _NotifNotifier,
      AsyncValue<List<AppNotification>>
    >((ref) => _NotifNotifier());

class _NotifNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  _NotifNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await _db
          .from('notifications')
          .select(
            'id, title, body, type, link, read_at, archived_at, created_at',
          )
          .eq('user_id', userId)
          .isFilter('archived_at', null)
          .order('created_at', ascending: false)
          .limit(100);

      state = AsyncValue.data(
        (data as List).map((r) => AppNotification.fromJson(r)).toList(),
      );

      _channel?.unsubscribe();
      _channel = _db
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final n = AppNotification.fromJson(payload.newRecord);
              final current = state.value ?? [];
              state = AsyncValue.data([n, ...current]);
            },
          )
          .subscribe();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String id) async {
    _updateItem(id, (n) => n.copyWith(isRead: true));
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (_) {}
  }

  Future<void> archive(String id) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((n) => n.id != id).toList());
    try {
      await _db
          .from('notifications')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (_) {}
  }

  Future<void> refresh() => _load();

  void _updateItem(String id, AppNotification Function(AppNotification) fn) {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => n.id == id ? fn(n) : n).toList(),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final db = Supabase.instance.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return 0;
  final data = await db
      .from('notifications')
      .select('id')
      .eq('user_id', userId)
      .isFilter('read_at', null)
      .isFilter('archived_at', null);
  return (data as List).length;
});

// ─────────────────────────────────────────────
// NOTIFICATIONS INBOX SCREEN
// ─────────────────────────────────────────────
class NotificationsInboxScreen extends ConsumerStatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  ConsumerState<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState
    extends ConsumerState<NotificationsInboxScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_notificationsProvider);
    final notifier = ref.read(_notificationsProvider.notifier);
    final all = async.value ?? [];
    final unreadCount = all.where((n) => !n.isRead).length;

    final visible = switch (_filter) {
      _Filter.all => all,
      _Filter.unread => all.where((n) => !n.isRead).toList(),
      _Filter.classes || _Filter.courses =>
        all
            .where(
              (n) => n.type.toLowerCase().contains(_kFilterTypeMatch[_filter]!),
            )
            .toList(),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
              _Header(
                unreadCount: unreadCount,
                onMarkAll: unreadCount > 0
                    ? () {
                        HapticFeedback.mediumImpact();
                        notifier.markAllRead();
                      }
                    : null,
              ),
              const SizedBox(height: DS.s12),
              _FilterChips(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: DS.s12),
              Expanded(
                child: async.when(
                  loading: () => const NotificationSkeleton(),
                  error: (e, _) => _ErrorState(onRetry: notifier.refresh),
                  data: (_) => _NotifList(items: visible, notifier: notifier),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOP BAR — matches the shell's shared app bar (logo left, bell/back right)
// ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s10),
      child: Row(
        children: [
          Expanded(
            child: Image.asset(
              'assets/images/bansal-logo.webp',
              height: 34,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(color: DS.border, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: DS.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER — "Notifications" + "N unread" / "All caught up" + Mark all read
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onMarkAll;
  const _Header({required this.unreadCount, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DS.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount > 0 ? '$unreadCount unread' : 'All caught up',
                  style: const TextStyle(fontSize: 13, color: DS.textSecondary),
                ),
              ],
            ),
          ),
          if (onMarkAll != null)
            GestureDetector(
              onTap: onMarkAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s8,
                ),
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, size: 14, color: DS.primary),
                    SizedBox(width: DS.s4),
                    Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DS.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILTER CHIPS — All / Unread / Classes / Courses
// ─────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: DS.s16),
        scrollDirection: Axis.horizontal,
        itemCount: _Filter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: DS.s8),
        itemBuilder: (_, i) {
          final f = _Filter.values[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(f);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: DS.s16),
              decoration: BoxDecoration(
                color: isSelected ? DS.primary : DS.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? DS.primary : DS.border,
                  width: 1.2,
                ),
              ),
              child: Text(
                _kFilterLabels[f]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : DS.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION LIST (with date grouping)
// ─────────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<AppNotification> items;
  final _NotifNotifier notifier;

  const _NotifList({required this.items, required this.notifier});

  // Group notifications by date label
  Map<String, List<AppNotification>> _grouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final key = d == today
          ? 'Today'
          : d == yesterday
          ? 'Yesterday'
          : _fmtDate(n.createdAt);
      groups.putIfAbsent(key, () => []).add(n);
    }
    return groups;
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: DS.primary,
        onRefresh: () async => notifier.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
          children: const [_EmptyState()],
        ),
      );
    }

    final grouped = _grouped();
    final keys = grouped.keys.toList();

    return RefreshIndicator(
      color: DS.primary,
      onRefresh: () async => notifier.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(DS.s16, 0, DS.s16, DS.s32),
        itemCount: keys.fold<int>(0, (s, k) => s + 1 + grouped[k]!.length),
        itemBuilder: (_, idx) {
          int flat = 0;
          for (final key in keys) {
            if (idx == flat) {
              return _DateGroupLabel(label: key);
            }
            flat++;
            final groupItems = grouped[key]!;
            for (int i = 0; i < groupItems.length; i++) {
              if (idx == flat) {
                return _NotifCard(
                  notification: groupItems[i],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (!groupItems[i].isRead) {
                      notifier.markRead(groupItems[i].id);
                    }
                    final link = groupItems[i].link;
                    if (link != null && link.isNotEmpty) {
                      context.push(link);
                    }
                  },
                  onArchive: () {
                    HapticFeedback.mediumImpact();
                    notifier.archive(groupItems[i].id);
                  },
                );
              }
              flat++;
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE GROUP LABEL
// ─────────────────────────────────────────────
class _DateGroupLabel extends StatelessWidget {
  final String label;
  const _DateGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s8, top: DS.s16),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: DS.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const _NotifCard({
    required this.notification,
    required this.onTap,
    required this.onArchive,
  });

  // Icon logic mirrors the web app's iconForType():
  // "live" -> Calendar-ish, "payment"/"course" -> CreditCard-ish, else book.
  IconData get _icon {
    final t = notification.type.toLowerCase();
    if (t.contains('live')) return Icons.calendar_today_rounded;
    if (t.contains('payment') || t.contains('order')) {
      return Icons.credit_card_rounded;
    }
    if (t.contains('course')) return Icons.menu_book_rounded;
    if (t.contains('test')) return Icons.assignment_rounded;
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(DS.s14),
          decoration: BoxDecoration(
            color: isUnread ? DS.primary.withValues(alpha: 0.04) : DS.surface,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: Border.all(color: DS.border, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isUnread ? DS.primary : DS.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 16,
                  color: isUnread ? Colors.white : DS.textSecondary,
                ),
              ),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: DS.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (notification.body != null &&
                        notification.body!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body!,
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: DS.s6),
                    Text(
                      _timeOfDay(notification.createdAt),
                      style: const TextStyle(color: DS.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onArchive,
                child: const Padding(
                  padding: EdgeInsets.only(left: DS.s8),
                  child: Icon(
                    Icons.archive_outlined,
                    size: 18,
                    color: DS.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeOfDay(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'AM' : 'PM';
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE — bell icon + "No notifications", matching the reference
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DS.s32 * 2),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: DS.textHint,
          ),
          const SizedBox(height: DS.s8),
          const Text(
            'No notifications',
            style: TextStyle(fontSize: 13.5, color: DS.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 32,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Could not load notifications.\nPlease check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
