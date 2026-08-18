import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/live_providers.dart';
import 'data/models/live_class.dart';

// ── Chat message model ─────────────────────────────────────────────────────────

class _ChatMsg {
  final String id;
  final String userId;
  final String displayName;
  final bool isTeacher;
  final String message;
  final DateTime createdAt;

  const _ChatMsg({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.isTeacher,
    required this.message,
    required this.createdAt,
  });

  factory _ChatMsg.fromJson(Map<String, dynamic> j) => _ChatMsg(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        isTeacher: j['is_teacher'] as bool? ?? false,
        message: j['message'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Watches liveClassByIdProvider AND subscribes to Realtime so when the
/// teacher flips status → 'live', the UI upgrades automatically.
class LiveRoomScreen extends ConsumerStatefulWidget {
  final String classId;
  const LiveRoomScreen({super.key, required this.classId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _channel = client
        .channel('live_class_${widget.classId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_classes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.classId,
          ),
          callback: (payload) {
            // Any update (status change) — re-fetch the class
            if (mounted) {
              ref.invalidate(liveClassByIdProvider(widget.classId));
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveClassByIdProvider(widget.classId));

    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/live'),
          ),
          title: const Text('Live Class',
              style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Failed to load class',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(liveClassByIdProvider(widget.classId)),
              child: const Text('Retry'),
            ),
          ]),
        ),
      ),
      data: (lc) {
        if (lc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Live Class')),
            body: const Center(child: Text('Class not found')),
          );
        }
        return _LiveRoomBody(lc: lc);
      },
    );
  }
}

// ── Room body — decides between waiting room and Zoom join ────────────────────

class _LiveRoomBody extends StatelessWidget {
  final LiveClass lc;
  const _LiveRoomBody({required this.lc});

  @override
  Widget build(BuildContext context) {
    if (!lc.isLive) return _WaitingRoom(lc: lc);
    return _ZoomLiveRoom(lc: lc);
  }
}

// ── Waiting room ───────────────────────────────────────────────────────────────

class _WaitingRoom extends StatelessWidget {
  final LiveClass lc;
  const _WaitingRoom({required this.lc});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = lc.startsAt.toLocal().difference(now);
    final timeStr = diff.isNegative
        ? 'shortly'
        : diff.inMinutes < 60
            ? 'in ${diff.inMinutes} min'
            : diff.inHours < 24
                ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
                : 'on ${lc.startsAt.toLocal().day}/${lc.startsAt.toLocal().month}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF1A1035), Color(0xFF0A0A0F)],
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/live'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(lc.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PulseWidget(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.4),
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.sensors_rounded,
                                  color: Color(0xFF818CF8), size: 44),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text('Class is not live yet.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Text(
                            'This class starts $timeStr.\nYou\'ll be notified when the teacher goes live.',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13.5,
                                height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(children: [
                              _InfoTile(
                                  icon: Icons.menu_book_rounded,
                                  label: lc.subject),
                              const SizedBox(height: 10),
                              _InfoTile(
                                  icon: Icons.person_rounded,
                                  label: lc.educatorName),
                              const SizedBox(height: 10),
                              _InfoTile(
                                  icon: Icons.schedule_rounded,
                                  label: _fmtDateTime(lc.startsAt.toLocal())),
                            ]),
                          ),
                        ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/live'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Classes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$m';
  }
}

// ── Zoom live room ─────────────────────────────────────────────────────────────

class _ZoomLiveRoom extends StatefulWidget {
  final LiveClass lc;
  const _ZoomLiveRoom({required this.lc});

  @override
  State<_ZoomLiveRoom> createState() => _ZoomLiveRoomState();
}

class _ZoomLiveRoomState extends State<_ZoomLiveRoom> {
  bool _zoomOpen = false;
  bool _chatOpen = false;
  final List<_ChatMsg> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  RealtimeChannel? _chatChannel;
  bool _sending = false;
  String? _myDisplayName;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _joinRoom();
  }

  /// Marks the student as an attendee of this class before loading chat —
  /// the live_class_messages SELECT RLS policy requires a matching
  /// live_class_attendance row to exist, mirroring the web app's room page.
  Future<void> _joinRoom() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await client.from('live_class_attendance').upsert(
          {
            'class_id': widget.lc.id,
            'user_id': uid,
            'status': 'joined',
            'joined_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'class_id,user_id',
        );
      } catch (_) {
        // Non-fatal — chat will simply stay empty under RLS if this fails.
      }
    }
    _subscribeChat();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await client
        .from('profiles')
        .select('full_name')
        .eq('user_id', uid)
        .maybeSingle();
    if (mounted) {
      setState(() => _myDisplayName =
          (row?['full_name'] as String?)?.trim().isNotEmpty == true
              ? row!['full_name'] as String
              : client.auth.currentUser?.email ?? 'Student');
    }
  }

  void _subscribeChat() {
    final client = Supabase.instance.client;
    client
        .from('live_class_messages')
        .select()
        .eq('class_id', widget.lc.id)
        .order('created_at')
        .limit(100)
        .then((data) {
      if (!mounted) return;
      setState(() {
        _messages.addAll(
            (data as List).map((r) => _ChatMsg.fromJson(r as Map<String, dynamic>)));
      });
      _scrollToBottom();
    });

    _chatChannel = client
        .channel('chat_${widget.lc.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_class_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'class_id',
            value: widget.lc.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final msg = _ChatMsg.fromJson(payload.newRecord);
            setState(() => _messages.add(msg));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _sending = true);
    _chatCtrl.clear();
    try {
      await client.from('live_class_messages').insert({
        'class_id': widget.lc.id,
        'user_id': uid,
        'display_name': _myDisplayName ?? 'Student',
        'is_teacher': false,
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openZoom() {
    final url = widget.lc.resolvedMeetingUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meeting link set yet. Please wait for the teacher.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _zoomOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final inSubPanel = _zoomOpen || _chatOpen;
    return PopScope(
      // When in a sub-panel, intercept back and close the panel instead of popping the route
      canPop: !inSubPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inSubPanel) {
          setState(() {
            _zoomOpen = false;
            _chatOpen = false;
          });
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: _zoomOpen
              ? _buildZoomWebView(context)
              : _chatOpen
                  ? _buildChatPanel(context)
                  : _buildMainView(context),
        ),
      ),
    );
  }

  Widget _buildZoomWebView(BuildContext context) {
    final url = widget.lc.resolvedMeetingUrl!;
    // Convert zoom.us/j/ID?pwd=X → zoom.us/wc/join/ID?pwd=X (web client, stays in app)
    final webUrl = url.replaceFirst(
      RegExp(r'zoom\.us/j/'),
      'zoom.us/wc/join/',
    );

    return SafeArea(
      child: Column(children: [
        // Top bar
        Container(
          color: const Color(0xFF111827),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _zoomOpen = false),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(widget.lc.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.white, size: 6),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
        ),
        // WebView
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(webUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildMainView(BuildContext context) {
    final hasLink = widget.lc.resolvedMeetingUrl != null;
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A1035), Color(0xFF0A0A0F)],
          ),
        ),
      ),
      SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/live'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(widget.lc.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.white, size: 6),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2D8CFF).withValues(alpha: 0.15),
                        border: Border.all(
                            color: const Color(0xFF2D8CFF).withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: Color(0xFF2D8CFF), size: 44),
                    ),
                    const SizedBox(height: 28),
                    const Text('Class is Live!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      hasLink
                          ? 'Tap the button below to join the live class.'
                          : 'Waiting for the teacher to share the meeting link…',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13.5,
                          height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(children: [
                        _InfoTile(
                            icon: Icons.menu_book_rounded,
                            label: widget.lc.subject),
                        const SizedBox(height: 10),
                        _InfoTile(
                            icon: Icons.person_rounded,
                            label: widget.lc.educatorName),
                        const SizedBox(height: 10),
                        _InfoTile(
                            icon: Icons.schedule_rounded,
                            label: _fmtDateTime(widget.lc.startsAt.toLocal())),
                      ]),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: hasLink ? _openZoom : null,
                        icon: const Icon(Icons.videocam_rounded, size: 22),
                        label: const Text(
                          'Join Live Class',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D8CFF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white38,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _chatOpen = true);
                    _scrollToBottom();
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(_messages.isNotEmpty
                      ? 'Chat (${_messages.length})'
                      : 'Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/live'),
                icon: const Icon(Icons.call_end_rounded, size: 18),
                label: const Text('Leave'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildChatPanel(BuildContext context) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => setState(() => _chatOpen = false),
      child: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => setState(() => _chatOpen = false),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text('Live Chat',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: Colors.white, size: 6),
                SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text('No messages yet.\nBe the first to say hi!',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center))
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    return _ChatBubble(msg: msg, isMe: msg.userId == myUid);
                  },
                ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$m';
  }
}

// ── Info tile ──────────────────────────────────────────────────────────────────

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool isMe;
  const _ChatBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: msg.isTeacher
                  ? const Color(0xFF6366F1)
                  : Colors.white.withValues(alpha: 0.15),
              child: Text(
                msg.displayName.isNotEmpty
                    ? msg.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(msg.displayName,
                          style: TextStyle(
                              color: msg.isTeacher
                                  ? const Color(0xFF818CF8)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      if (msg.isTeacher) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Teacher',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF6366F1)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(msg.message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info tile ──────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ]);
}


// ── Pulse animation ────────────────────────────────────────────────────────────

class _PulseWidget extends StatefulWidget {
  final Widget child;
  const _PulseWidget({required this.child});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
