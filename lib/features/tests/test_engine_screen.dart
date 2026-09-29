import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';
import 'data/question_image_resolver.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);

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
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// MATH-AWARE TEXT RENDERER
// Handles plain text, LaTeX ($...$), and text
// that has been mixed with HTML tags.
// ─────────────────────────────────────────────
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  const MathText(this.text, {super.key, this.style, this.maxLines});

  // Strip HTML tags and decode HTML entities (handles single and double encoding).
  static String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&le;', '≤')
      .replaceAll('&ge;', '≥')
      .replaceAll('&ne;', '≠')
      .replaceAll('&alpha;', 'α')
      .replaceAll('&beta;', 'β')
      .replaceAll('&gamma;', 'γ')
      .replaceAll('&delta;', 'δ')
      .replaceAll('&lambda;', 'λ')
      .replaceAll('&mu;', 'μ')
      .replaceAll('&pi;', 'π')
      .replaceAll('&sigma;', 'σ')
      .replaceAll('&omega;', 'ω')
      .replaceAll('&rarr;', '→')
      .replaceAll('&larr;', '←')
      .replaceAll('&harr;', '↔')
      .replaceAll('&plusmn;', '±')
      .replaceAll('&times;', '×')
      .replaceAll('&divide;', '÷')
      .replaceAll('&deg;', '°')
      .replaceAll('&sup2;', '²')
      .replaceAll('&sup3;', '³')
      .replaceAll('&frac12;', '½')
      .replaceAll('&frac14;', '¼');

  static String _stripHtml(String raw) {
    var s = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p\s*/?>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<strong\s*/?>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</strong>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<em\s*/?>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</em>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode entities — run twice to handle double-encoded strings like &amp;lt;
    s = _decodeEntities(s);
    s = _decodeEntities(s);
    return s.trim();
  }

  // Normalise all LaTeX delimiter styles to $...$ so the splitter works uniformly.
  static String _normalizeMath(String s) {
    // \[...\]  → $...$
    s = s.replaceAllMapped(
      RegExp(r'\\\[([\s\S]*?)\\\]'),
      (m) => '\$${m.group(1)}\$',
    );
    // \(...\)  → $...$
    s = s.replaceAllMapped(
      RegExp(r'\\\(([\s\S]*?)\\\)'),
      (m) => '\$${m.group(1)}\$',
    );
    // Bare LaTeX segments with no delimiters: consecutive tokens that contain
    // backslash-commands (\text, \frac, \Lambda, etc.) are merged and wrapped
    // in $...$. Pure-prose words are left as TextSpan.
    // Strategy: split each line into runs of "math tokens" vs "prose tokens"
    // and wrap math runs in $...$, leaving prose untouched.
    final latexToken = RegExp(r'\\[a-zA-Z]');
    final lines = s.split('\n');
    final result = lines
        .map((line) {
          if (line.contains('\$')) return line; // already delimited
          if (!latexToken.hasMatch(line)) return line; // pure prose
          // Tokenise on whitespace, group consecutive math tokens, wrap them.
          final tokens = line.split(RegExp(r'(?<=\S)(?=\s)|(?<=\s)(?=\S)'));
          final buf = StringBuffer();
          bool inMath = false;
          for (final tok in tokens) {
            final isMath = latexToken.hasMatch(tok);
            if (isMath && !inMath) {
              buf.write('\$');
              inMath = true;
            }
            if (!isMath && inMath) {
              buf.write('\$');
              inMath = false;
            }
            buf.write(tok);
          }
          if (inMath) buf.write('\$');
          return buf.toString();
        })
        .join('\n');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    // Strip HTML, then normalise LaTeX delimiters before splitting on $.
    final cleaned = _normalizeMath(_stripHtml(text));
    final parts = cleaned.split(RegExp(r'\$'));
    if (parts.length == 1)
      return Text(cleaned, style: base, maxLines: maxLines);

    final spans = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      if (i.isOdd) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              part,
              textStyle: base,
              onErrorFallback: (e) => Text(part, style: base),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: part, style: base));
      }
    }

    return RichText(
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      text: TextSpan(children: spans, style: base),
    );
  }
}

// ─────────────────────────────────────────────
// MATCH PAIR — one row in a match-the-column question
// ─────────────────────────────────────────────
class MatchPair {
  final String key; // e.g. "A", "B"
  final String value; // e.g. "CH₄"
  const MatchPair({required this.key, required this.value});
}

// ─────────────────────────────────────────────
// OPTION ITEM — text + optional image URL
// ─────────────────────────────────────────────
class OptionItem {
  final String text; // plain text, HTML tags stripped
  final String? imageUrl; // extracted <img src> if present

  const OptionItem({required this.text, this.imageUrl});

  static final _imgRe = RegExp(
    '<img[^>]+src=["\']([^"\']+)["\']',
    caseSensitive: false,
  );
  static final _tagRe = RegExp('<[^>]+>');

  factory OptionItem.fromRaw(String raw) {
    final imgMatch = _imgRe.firstMatch(raw);
    final imageUrl = imgMatch?.group(1);
    var text = raw.replaceAll(_imgRe, '').replaceAll(_tagRe, '').trim();
    // Decode HTML entities (run twice for double-encoded strings)
    text = MathText._decodeEntities(text);
    text = MathText._decodeEntities(text);
    return OptionItem(text: text, imageUrl: imageUrl);
  }
}

// ─────────────────────────────────────────────
// QUESTION MODEL
// ─────────────────────────────────────────────
class TestQuestion {
  final String id;
  final String text;
  final List<String> imageUrls; // extracted <img> src values from question text
  final List<OptionItem> options;
  final int correctIndex;
  final String correctAnswerText; // for integer/fill-in questions
  final String subject;
  final String? explanation;
  final bool hasHtml;
  final String
  questionType; // 'mcq', 'integer', 'fill_in_the_blank', 'match_column', etc.
  final List<MatchPair> matchCol1;
  final List<MatchPair> matchCol2;
  final double marksCorrect;
  final double marksWrong;
  final bool isBonus;

  bool get isMatchType =>
      questionType == 'match_column' || questionType == 'match';

  bool get isIntegerType =>
      !isMatchType &&
      (questionType == 'integer' ||
          questionType == 'fill_in_the_blank' ||
          questionType == 'numerical' ||
          options.isEmpty);

  const TestQuestion({
    required this.id,
    required this.text,
    required this.imageUrls,
    required this.options,
    required this.correctIndex,
    required this.correctAnswerText,
    required this.subject,
    required this.hasHtml,
    required this.questionType,
    this.explanation,
    this.matchCol1 = const [],
    this.matchCol2 = const [],
    this.marksCorrect = 4,
    this.marksWrong = -1,
    this.isBonus = false,
  });

  static Future<TestQuestion> fromJson(Map<String, dynamic> j) async {
    final rawOpts = j['options'];
    List<OptionItem> opts = [];
    List<MatchPair> matchCol1 = [];
    List<MatchPair> matchCol2 = [];

    if (rawOpts is Map) {
      // match_column: {"col1": [{key, value}...], "col2": [{key, value}...]}
      String decodeVal(String raw) {
        var s = raw.replaceAll(RegExp(r'<[^>]+>'), '');
        s = MathText._decodeEntities(s);
        s = MathText._decodeEntities(s); // double-encoded
        return s.trim();
      }

      List<MatchPair> parsePairs(dynamic list) {
        if (list is! List) return [];
        return list.map((e) {
          if (e is Map) {
            return MatchPair(
              key: decodeVal((e['key'] ?? '').toString()),
              value: decodeVal((e['value'] ?? '').toString()),
            );
          }
          return MatchPair(key: '', value: decodeVal(e.toString()));
        }).toList();
      }

      matchCol1 = parsePairs(rawOpts['col1']);
      matchCol2 = parsePairs(rawOpts['col2']);
    } else if (rawOpts is List && rawOpts.isNotEmpty) {
      // option_images is a parallel jsonb array/map keyed by option index/id.
      final rawOptImages = j['option_images'];
      String? imageAt(int i, dynamic idKey) {
        if (rawOptImages is List && i < rawOptImages.length) {
          final v = rawOptImages[i];
          return v is String && v.isNotEmpty ? v : null;
        }
        if (rawOptImages is Map) {
          final v =
              rawOptImages[idKey?.toString()] ?? rawOptImages[i.toString()];
          return v is String && v.isNotEmpty ? v : null;
        }
        return null;
      }

      opts = rawOpts.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        if (e is Map) {
          final raw = (e['text'] ?? e['value'] ?? '').toString();
          // Prefer a dedicated image key over extracting from HTML,
          // falling back to the parallel option_images column.
          final directImage =
              (e['image'] ?? e['image_url'] ?? e['imageUrl'] ?? '') as String;
          final resolvedImage = directImage.isNotEmpty
              ? directImage
              : imageAt(i, e['id']);
          if (resolvedImage != null && resolvedImage.isNotEmpty) {
            final parsed = OptionItem.fromRaw(raw);
            return OptionItem(text: parsed.text, imageUrl: resolvedImage);
          }
          return OptionItem.fromRaw(raw);
        }
        final resolvedImage = imageAt(i, null);
        final parsed = OptionItem.fromRaw(e.toString());
        return resolvedImage != null && resolvedImage.isNotEmpty
            ? OptionItem(text: parsed.text, imageUrl: resolvedImage)
            : parsed;
      }).toList();
    }

    String text = j['question_text'] as String? ?? '';
    final hasHtml = text.contains('<') && text.contains('>');

    // Extract all <img src="..."> URLs before any text manipulation
    final imgRegex = RegExp(
      '<img[^>]+src=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final imageUrls = imgRegex
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toList();

    // Strip <img> tags so flutter_html doesn't fail on them;
    // we render images explicitly via CachedNetworkImage.
    if (imageUrls.isNotEmpty) {
      text = text.replaceAll(RegExp('<img[^>]*/?>', caseSensitive: false), '');
    }

    // Fall back to the dedicated question_image_url column if no <img> was
    // embedded in question_text.
    final dedicatedImageUrl = j['question_image_url'] as String?;
    if (imageUrls.isEmpty &&
        dedicatedImageUrl != null &&
        dedicatedImageUrl.isNotEmpty) {
      imageUrls.add(dedicatedImageUrl);
    }

    if (opts.isEmpty && hasHtml) {
      final optRegex = RegExp(
        r'<br\s*/?>\s*<strong>\(\d+\)\s*</strong>\s*<strong>(.*?)</strong>',
        caseSensitive: false,
      );
      final matches = optRegex.allMatches(text);
      if (matches.isNotEmpty) {
        opts = matches.map((m) => OptionItem.fromRaw(m.group(1)!)).toList();
        final firstOptIdx = text.indexOf(RegExp(r'<br\s*/?>\s*<strong>\(1\)'));
        if (firstOptIdx > 0) text = text.substring(0, firstOptIdx).trim();
      }
    }

    final raw = j['correct_answer'];
    int correctIndex = 0;
    String correctAnswerText = '';
    if (raw is int) {
      correctIndex = raw;
      correctAnswerText = raw.toString();
    } else if (raw is String) {
      correctAnswerText = raw.trim();
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        correctIndex = asInt;
      } else {
        final idx = opts.indexWhere((o) => o.text == raw.trim());
        correctIndex = idx >= 0 ? idx : 0;
      }
    } else if (raw is Map) {
      final idx = raw['index'] ?? raw['correct_index'];
      if (idx is int) correctIndex = idx;
      correctAnswerText = correctIndex.toString();
    }

    final questionType =
        (j['question_type'] as String?)?.toLowerCase().trim() ?? 'mcq';

    // Re-sign any question-images storage URLs that may be stale/expired.
    final resolvedImageUrls = await Future.wait(
      imageUrls.map(resolveQuestionImageUrl),
    );
    final resolvedOpts = await Future.wait(
      opts.map((o) async {
        if (o.imageUrl == null || o.imageUrl!.isEmpty) return o;
        return OptionItem(
          text: o.text,
          imageUrl: await resolveQuestionImageUrl(o.imageUrl!),
        );
      }),
    );

    return TestQuestion(
      id: j['id'] as String,
      text: text,
      imageUrls: resolvedImageUrls,
      options: resolvedOpts,
      correctIndex: correctIndex,
      correctAnswerText: correctAnswerText,
      subject: j['subject'] as String? ?? '',
      explanation: j['explanation'] as String?,
      hasHtml: hasHtml,
      questionType: questionType,
      matchCol1: matchCol1,
      matchCol2: matchCol2,
      marksCorrect: _toDouble(j['marks_correct'], fallback: 4),
      marksWrong: _toDouble(j['marks_wrong'], fallback: -1),
      isBonus: j['is_bonus'] as bool? ?? false,
    );
  }

  static double _toDouble(dynamic v, {required double fallback}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}

// ─────────────────────────────────────────────
// TEST ENGINE SCREEN
// ─────────────────────────────────────────────
class TestEngineScreen extends StatefulWidget {
  final String testId;
  const TestEngineScreen({super.key, required this.testId});

  @override
  State<TestEngineScreen> createState() => _TestEngineScreenState();
}

class _TestEngineScreenState extends State<TestEngineScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _db = SupabaseService.client;

  bool _loading = true;
  String? _error;
  String _testTitle = '';
  int _durationSeconds = 30 * 60;
  List<TestQuestion> _questions = [];
  // int? for MCQ (option index), String for integer/fill-in, null = unanswered
  Map<String, dynamic> _answers = {};
  // Text controllers for integer/fill-in questions, keyed by question id
  final Map<String, TextEditingController> _intCtrls = {};
  final Set<String> _marked = {};
  int _index = 0;
  int _remaining = 0;
  bool _saving = false;
  bool _submitting = false;
  String? _attemptId;
  DateTime? _startedAt;
  final Set<String> _visited = {};
  Timer? _timer;

  // ── Window-switch anti-cheating ──
  // Backgrounding the app (task switcher, home button, another app taking
  // focus) counts as a violation. 1st and 2nd show a warning; the 3rd
  // auto-submits — mirrors the web app's visibilitychange-based logic.
  static const _maxTabSwitches = 3;
  int _tabSwitches = 0;
  bool _autoSubmitBlocked = false;
  DateTime? _lastViolationAt;
  bool _started = false;

  // Animation for timer urgency
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadTest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseCtrl.dispose();
    for (final c in _intCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || _submitting || _autoSubmitBlocked) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _registerTabSwitchViolation();
    }
  }

  void _registerTabSwitchViolation() {
    final now = DateTime.now();
    if (_lastViolationAt != null &&
        now.difference(_lastViolationAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastViolationAt = now;
    final next = _tabSwitches + 1;

    if (next >= _maxTabSwitches) {
      _autoSubmitBlocked = true;
      if (mounted) setState(() => _tabSwitches = next);
      _submit(auto: true, reason: 'window_switch');
      return;
    }

    if (mounted) {
      setState(() => _tabSwitches = next);
      _showTabSwitchWarning(next);
    }
  }

  void _showTabSwitchWarning(int count) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TabSwitchWarningDialog(
        violationCount: count,
        maxViolations: _maxTabSwitches,
      ),
    );
  }

  Future<void> _loadTest() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) {
        throw StateError('Please sign in before starting a test.');
      }
      final testData = await _db
          .from('tests')
          .select('title, duration_minutes, starts_at, ends_at')
          .eq('id', widget.testId)
          .single();

      _testTitle = testData['title'] as String? ?? 'Test';
      _durationSeconds = ((testData['duration_minutes'] as int?) ?? 30) * 60;

      final qData = await _db
          .from('test_questions')
          .select(
            'id, question_text, question_image_url, options, option_images, '
            'correct_answer, subject, explanation, question_type, '
            'marks_correct, marks_wrong, is_bonus',
          )
          .eq('test_id', widget.testId)
          .order('position', ascending: true);

      _questions = await Future.wait(
        (qData as List).map(
          (r) => TestQuestion.fromJson(r as Map<String, dynamic>),
        ),
      );

      if (_questions.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No questions found for this test.';
        });
        return;
      }

      _answers = {for (final q in _questions) q.id: null};
      for (final q in _questions) {
        if (q.isIntegerType) {
          final ctrl = TextEditingController();
          ctrl.addListener(() {
            final val = ctrl.text.trim();
            if (mounted) {
              setState(() => _answers[q.id] = val.isEmpty ? null : val);
            }
          });
          _intCtrls[q.id] = ctrl;
        } else if (q.isMatchType) {
          // Pre-populate with null selections for each col1 row
          _answers[q.id] = <String, String?>{
            for (final p in q.matchCol1) p.key: null,
          };
        }
      }

      // Use the same guarded attempt lifecycle as the CBT web client. A test
      // is started once, resumed by id, and that exact row is later submitted.
      final inProgress = await _db
          .from('test_attempts')
          .select('id, started_at, answers, question_statuses')
          .eq('user_id', userId)
          .eq('test_id', widget.testId)
          .eq('status', 'in_progress')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (inProgress != null) {
        _attemptId = inProgress['id'] as String;
        _startedAt = DateTime.tryParse(
          inProgress['started_at'] as String? ?? '',
        );
        _restoreProgress(inProgress);
      } else {
        final completed = await _db
            .from('test_attempts')
            .select('id')
            .eq('user_id', userId)
            .eq('test_id', widget.testId)
            .inFilter('status', const ['submitted', 'auto_submitted'])
            .order('submitted_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (completed != null) {
          final allowed = await _db.rpc(
            'can_reattempt_test',
            params: {'_user_id': userId, '_test_id': widget.testId},
          );
          if (allowed != true) {
            if (!mounted) return;
            context.pushReplacement('/test-result/${completed['id']}');
            return;
          }
        }

        final now = DateTime.now();
        final startsAt = DateTime.tryParse(
          testData['starts_at'] as String? ?? '',
        );
        final endsAt = DateTime.tryParse(testData['ends_at'] as String? ?? '');
        if (startsAt != null &&
            now.isBefore(startsAt.subtract(const Duration(minutes: 1)))) {
          throw StateError('This test has not opened yet.');
        }
        if (endsAt != null && now.isAfter(endsAt)) {
          throw StateError('This test window has closed.');
        }

        final created = await _db
            .from('test_attempts')
            .insert({
              'user_id': userId,
              'test_id': widget.testId,
              'test_name': _testTitle,
              'status': 'in_progress',
              'started_at': now.toIso8601String(),
              'answers': <String, dynamic>{},
              'question_statuses': <String, dynamic>{},
            })
            .select('id, started_at')
            .single();
        _attemptId = created['id'] as String;
        _startedAt =
            DateTime.tryParse(created['started_at'] as String? ?? '') ?? now;
      }

      final hardEnd = DateTime.tryParse(testData['ends_at'] as String? ?? '');
      if (inProgress != null &&
          hardEnd != null &&
          DateTime.now().isAfter(hardEnd)) {
        _remaining = 0;
        _started = true;
        if (mounted) setState(() => _loading = false);
        await _submit(auto: true, reason: 'test_window_closed');
        return;
      }

      _remaining =
          (_durationSeconds -
                  (_startedAt == null
                      ? 0
                      : DateTime.now().difference(_startedAt!).inSeconds))
              .clamp(0, _durationSeconds);
      _visited.add(_questions.first.id);

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) {
          t.cancel();
          _submit();
        }
        if (_remaining % 30 == 0) _autosave();
      });

      _started = true;
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load test: $e';
      });
    }
  }

  Future<void> _autosave() async {
    if (mounted) setState(() => _saving = true);
    try {
      final attemptId = _attemptId;
      if (attemptId == null) return;
      await _db
          .from('test_attempts')
          .update({
            'answers': _answersPayload,
            'question_statuses': _questionStatuses,
            'time_spent_seconds': _durationSeconds - _remaining,
            'metadata': {'tab_switches': _tabSwitches},
          })
          .eq('id', attemptId)
          .eq('status', 'in_progress');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> get _answersPayload => {
    for (final q in _questions)
      if (_hasAnswer(q)) q.id: {'selected': _answers[q.id]},
  };

  Map<String, dynamic> get _questionStatuses => {
    for (final q in _questions)
      q.id: _marked.contains(q.id)
          ? 'marked'
          : _hasAnswer(q)
          ? 'answered'
          : _visited.contains(q.id)
          ? 'not-answered'
          : 'not-visited',
  };

  void _restoreProgress(Map<String, dynamic> row) {
    final saved = (row['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final q in _questions) {
      final raw = saved[q.id];
      final selected = raw is Map ? raw['selected'] : raw;
      if (selected == null) continue;
      _answers[q.id] = selected;
      if (q.isIntegerType) _intCtrls[q.id]?.text = selected.toString();
    }
    final statuses =
        (row['question_statuses'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in statuses.entries) {
      if (entry.value == 'marked' || entry.value == 'answered-marked') {
        _marked.add(entry.key);
      }
      if (entry.value != 'not-visited') _visited.add(entry.key);
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _index = index;
      _visited.add(_questions[index].id);
    });
  }

  String _fmt(int s) {
    if (s < 0) s = 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '${m.toString().padLeft(2, '0')}:$ss';
  }

  // ── Derived stats ──
  int get _answeredCount {
    int count = 0;
    for (final q in _questions) {
      final ans = _answers[q.id];
      if (q.isMatchType) {
        // Answered when every col1 row has a selection
        if (ans is Map && ans.values.every((v) => v != null)) count++;
      } else if (ans != null) {
        count++;
      }
    }
    return count;
  }

  bool _hasAnswer(TestQuestion q) {
    final ans = _answers[q.id];
    if (q.isMatchType) {
      return ans is Map && ans.isNotEmpty && ans.values.every((v) => v != null);
    }
    if (ans is String) return ans.trim().isNotEmpty;
    return ans != null;
  }

  int get _markedCount => _marked.length;

  bool _isCorrect(TestQuestion q) {
    final ans = _answers[q.id];
    if (ans == null) return false;
    if (q.isMatchType) {
      // We don't auto-grade match questions — mark as answered but not graded
      return false;
    }
    if (q.isIntegerType) {
      return ans.toString().trim() == q.correctAnswerText.trim();
    }
    return ans == q.correctIndex;
  }

  Future<void> _submit({bool auto = false, String? reason}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final userId = _db.auth.currentUser?.id;
    final attemptId = _attemptId;
    if (userId == null || attemptId == null) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This attempt could not be identified. Please try again.',
            ),
          ),
        );
      }
      return;
    }

    // Per-question marks, matching the web app's metadata.questions shape —
    // used by the result page's rank/leaderboard/response-sheet RPCs.
    double scoredMarks = 0;
    int correctCount = 0;
    int attemptedCount = 0;
    final subjectTotals = <String, double>{};
    final answersPayload = <String, dynamic>{};
    final questionMetas = <Map<String, dynamic>>[];

    for (final q in _questions) {
      final ans = _answers[q.id];
      final attempted = q.isMatchType
          ? (ans is Map && ans.values.every((v) => v != null))
          : ans != null;
      final correct = attempted && _isCorrect(q);
      final marks = !attempted
          ? 0.0
          : q.isMatchType
          ? 0.0 // not auto-graded
          : (correct ? q.marksCorrect : q.marksWrong);

      scoredMarks += marks;
      if (correct) correctCount++;
      if (attempted) attemptedCount++;
      subjectTotals[q.subject] =
          (subjectTotals[q.subject] ?? 0) + q.marksCorrect;

      if (attempted) {
        answersPayload[q.id] = {'selected': ans};
      }

      questionMetas.add({
        'question_id': q.id,
        'subject': q.subject,
        'position': _questions.indexOf(q),
        'attempted': attempted,
        'is_correct': correct,
        'is_bonus': q.isBonus,
        'marks': marks,
        'max_marks': q.marksCorrect,
      });
    }

    try {
      final record = {
        'score': scoredMarks,
        'correct_answers': correctCount,
        'total_questions': _questions.length,
        'time_spent_seconds': _durationSeconds - _remaining,
        'attempted_at': DateTime.now().toIso8601String(),
        'submitted_at': DateTime.now().toIso8601String(),
        'answers': answersPayload,
        'question_statuses': _questionStatuses,
        'status': auto ? 'auto_submitted' : 'submitted',
        'metadata': {
          'total': _questions.length,
          'correct': correctCount,
          'attempted': attemptedCount,
          'subjects': subjectTotals,
          'questions': questionMetas,
          'tab_switches': _tabSwitches,
          if (auto && reason != null) 'auto_submitted_reason': reason,
        },
      };
      await _db
          .from('test_attempts')
          .update(record)
          .eq('id', attemptId)
          .eq('user_id', userId);
      // Server-side evaluation is authoritative and supports all configured
      // question types/partial marking. The local totals above are fallback
      // metadata only and are replaced by this RPC where available.
      await _db.rpc('submit_test_attempt', params: {'_attempt_id': attemptId});

      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await _db
          .from('study_sessions')
          .upsert(
            {'user_id': userId, 'session_date': date},
            onConflict: 'user_id,session_date',
            ignoreDuplicates: true,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _remaining--);
        if (_remaining <= 0) t.cancel();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${e.toString()}')),
      );
      return;
    }

    if (!mounted) return;

    // For an exit, the student already confirmed via _LeaveDialog, so no
    // second "auto-submitted" popup is shown — just leave the test screen.
    if (auto && reason != 'exited_test') {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AutoSubmittedDialog(),
      );
      if (!mounted) return;
    }

    if (reason == 'exited_test') {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    context.pushReplacement('/test-result/$attemptId');
  }

  void _confirmLeave() async {
    HapticFeedback.mediumImpact();
    final ok =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _LeaveDialog(),
        ) ??
        false;
    if (!ok || !mounted) return;
    // Exiting forfeits the attempt: it is auto-submitted with whatever was
    // answered so far, so the student cannot re-enter it later.
    await _submit(auto: true, reason: 'exited_test');
  }

  void _confirmSubmit() async {
    HapticFeedback.mediumImpact();
    final unanswered = _questions.length - _answeredCount;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => _SubmitDialog(
            answered: _answeredCount,
            total: _questions.length,
            unanswered: unanswered,
            marked: _markedCount,
          ),
        ) ??
        false;
    if (ok) _submit();
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingScaffold(title: _testTitle);
    if (_error != null) return _ErrorScaffold(message: _error!);

    final q = _questions[_index];
    final subjects = _questions
        .map(
          (question) => question.subject.trim().isEmpty
              ? 'General'
              : question.subject.trim(),
        )
        .toSet()
        .toList();
    final timerRed = _remaining < 60;
    final progress = (_index + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: DS.background,

        // ── App Bar ──
        appBar: _TestAppBar(
          title: _testTitle,
          index: _index,
          total: _questions.length,
          remaining: _remaining,
          timerRed: timerRed,
          saving: _saving,
          pulseAnim: _pulseAnim,
          onClose: _confirmLeave,
          fmtTime: _fmt,
          submitting: _submitting,
          onSubmit: _confirmSubmit,
        ),

        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Progress bar ──
              _ProgressSection(
                progress: progress,
                saving: _saving,
                answeredCount: _answeredCount,
                total: _questions.length,
                markedCount: _markedCount,
              ),

              if (subjects.length > 1)
                _SubjectNavigation(
                  subjects: subjects,
                  activeSubject: q.subject.trim().isEmpty
                      ? 'General'
                      : q.subject.trim(),
                  onSelected: (subject) {
                    final first = _questions.indexWhere(
                      (question) =>
                          (question.subject.trim().isEmpty
                              ? 'General'
                              : question.subject.trim()) ==
                          subject,
                    );
                    if (first >= 0) _goToQuestion(first);
                  },
                ),

              // ── Question content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s16,
                    DS.s16,
                    DS.s16,
                    DS.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question header card
                      _QuestionHeader(
                        index: _index,
                        total: _questions.length,
                        subject: q.subject,
                        marksCorrect: q.marksCorrect,
                        marksWrong: q.marksWrong,
                        marked: _marked.contains(q.id),
                        onToggleMark: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _marked.contains(q.id)
                                ? _marked.remove(q.id)
                                : _marked.add(q.id),
                          );
                        },
                      ),

                      const SizedBox(height: DS.s16),

                      // Question text card
                      _QuestionTextCard(question: q),

                      const SizedBox(height: DS.s16),

                      // Options / integer input / match-the-column
                      if (q.isMatchType)
                        _MatchColumnWidget(
                          question: q,
                          selections:
                              (_answers[q.id] as Map?)
                                  ?.cast<String, String?>() ??
                              {},
                          onChanged: (col1Key, col2Key) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              final current = Map<String, String?>.from(
                                (_answers[q.id] as Map?)
                                        ?.cast<String, String?>() ??
                                    {},
                              );
                              current[col1Key] = col2Key;
                              _answers[q.id] = current;
                            });
                          },
                        )
                      else if (q.isIntegerType && _intCtrls[q.id] != null)
                        _IntegerAnswerField(controller: _intCtrls[q.id]!)
                      else
                        _OptionGrid(
                          options: q.options,
                          selectedIndex: _answers[q.id] as int?,
                          onSelect: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _answers[q.id] = i);
                          },
                        ),

                      const SizedBox(height: DS.s16),
                    ],
                  ),
                ),
              ),

              // ── Bottom navigation ──
              _BottomNav(
                index: _index,
                total: _questions.length,
                isMarked: _marked.contains(q.id),
                submitting: _submitting,
                onMark: () {
                  HapticFeedback.selectionClick();
                  setState(
                    () => _marked.contains(q.id)
                        ? _marked.remove(q.id)
                        : _marked.add(q.id),
                  );
                },
                onPalette: _showPalette,
                onPrev: _index > 0 ? () => _goToQuestion(_index - 1) : null,
                onNext: () {
                  if (_index < _questions.length - 1) {
                    _goToQuestion(_index + 1);
                  } else {
                    _confirmSubmit();
                  }
                },
                isLast: _index == _questions.length - 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusXl)),
      ),
      builder: (_) => _PaletteSheet(
        questions: _questions,
        answers: _answers,
        marked: _marked,
        visited: _visited,
        currentIdx: _index,
        onTap: (i) {
          _goToQuestion(i);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST APP BAR
// ─────────────────────────────────────────────
class _TestAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int index, total, remaining;
  final bool timerRed, saving, submitting;
  final Animation<double> pulseAnim;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final String Function(int) fmtTime;

  const _TestAppBar({
    required this.title,
    required this.index,
    required this.total,
    required this.remaining,
    required this.timerRed,
    required this.saving,
    required this.pulseAnim,
    required this.onClose,
    required this.fmtTime,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s8,
            vertical: DS.s10,
          ),
          child: Row(
            children: [
              // Close
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DS.errorSurface,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    border: Border.all(
                      color: DS.error.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: DS.error,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: DS.s10),

              // Title + Q counter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DS.textPrimary,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Question ${index + 1} of $total',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Saving indicator
              if (saving) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: DS.primary,
                  ),
                ),
                const SizedBox(width: DS.s8),
              ],

              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DS.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: DS.error.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: DS.s10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: DS.s6),

              // Timer
              ScaleTransition(
                scale: timerRed ? pulseAnim : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s12,
                    vertical: DS.s8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: timerRed
                          ? [const Color(0xFFFF6B6B), DS.error]
                          : [const Color(0xFF2B5BB8), DS.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: (timerRed ? DS.error : DS.primary).withOpacity(
                          0.28,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: DS.s4),
                      Text(
                        fmtTime(remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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
// PROGRESS SECTION
// ─────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final double progress;
  final bool saving;
  final int answeredCount, total, markedCount;

  const _ProgressSection({
    required this.progress,
    required this.saving,
    required this.answeredCount,
    required this.total,
    required this.markedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Autosave indicator
        if (saving)
          Container(
            height: 2,
            child: const LinearProgressIndicator(
              color: DS.success,
              backgroundColor: DS.border,
            ),
          ),

        // Main progress bar
        Stack(
          children: [
            Container(height: 6, color: DS.border),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2B5BB8), DS.primary],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s16,
            vertical: DS.s8,
          ),
          child: Row(
            children: [
              _ProgressStat(
                color: DS.success,
                icon: Icons.check_circle_outline_rounded,
                label: '$answeredCount answered',
              ),
              const SizedBox(width: DS.s16),
              _ProgressStat(
                color: DS.textHint,
                icon: Icons.radio_button_unchecked_rounded,
                label: '${total - answeredCount} remaining',
              ),
              if (markedCount > 0) ...[
                const SizedBox(width: DS.s16),
                _ProgressStat(
                  color: DS.warning,
                  icon: Icons.bookmark_rounded,
                  label: '$markedCount marked',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _ProgressStat({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: DS.s4),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _SubjectNavigation extends StatelessWidget {
  final List<String> subjects;
  final String activeSubject;
  final ValueChanged<String> onSelected;

  const _SubjectNavigation({
    required this.subjects,
    required this.activeSubject,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: DS.surface,
    padding: const EdgeInsets.fromLTRB(DS.s12, DS.s4, DS.s12, DS.s8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: subjects.map((subject) {
          final active = subject == activeSubject;
          return Padding(
            padding: const EdgeInsets.only(right: DS.s8),
            child: ChoiceChip(
              selected: active,
              label: Text(subject),
              onSelected: (_) => onSelected(subject),
              showCheckmark: false,
              selectedColor: DS.primary,
              backgroundColor: DS.surfaceVariant,
              side: BorderSide(color: active ? DS.primary : DS.border),
              labelStyle: TextStyle(
                color: active ? Colors.white : DS.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// QUESTION HEADER
// ─────────────────────────────────────────────
class _QuestionHeader extends StatelessWidget {
  final int index, total;
  final String subject;
  final double marksCorrect, marksWrong;
  final bool marked;
  final VoidCallback onToggleMark;

  const _QuestionHeader({
    required this.index,
    required this.total,
    required this.subject,
    required this.marksCorrect,
    required this.marksWrong,
    required this.marked,
    required this.onToggleMark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Q number badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s10,
            vertical: DS.s6,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B5BB8), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Text(
            'Q ${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: DS.s8),

        // Subject chip
        if (subject.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s8,
              vertical: DS.s6,
            ),
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DS.primary.withOpacity(0.20), width: 1),
            ),
            child: Text(
              subject,
              style: const TextStyle(
                color: DS.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        const SizedBox(width: DS.s6),
        Text(
          marksWrong < 0
              ? '+${marksCorrect.toStringAsFixed(marksCorrect % 1 == 0 ? 0 : 1)} / ${marksWrong.toStringAsFixed(marksWrong % 1 == 0 ? 0 : 1)}'
              : '+${marksCorrect.toStringAsFixed(marksCorrect % 1 == 0 ? 0 : 1)}',
          style: TextStyle(
            color: marksWrong < 0 ? DS.error : DS.success,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),

        const Spacer(),

        // Mark for review
        GestureDetector(
          onTap: onToggleMark,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s10,
              vertical: DS.s6,
            ),
            decoration: BoxDecoration(
              color: marked ? DS.warningSurface : DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusSm),
              border: Border.all(
                color: marked ? DS.warning.withOpacity(0.40) : DS.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  marked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 13,
                  color: marked ? DS.warning : DS.textSecondary,
                ),
                const SizedBox(width: DS.s4),
                Text(
                  marked ? 'Marked' : 'Mark',
                  style: TextStyle(
                    color: marked ? DS.warning : DS.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// QUESTION TEXT CARD
// ─────────────────────────────────────────────
class _QuestionTextCard extends StatelessWidget {
  final TestQuestion question;
  const _QuestionTextCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question text ──
          // MathText handles HTML stripping + LaTeX rendering for all cases.
          MathText(
            question.text,
            style: const TextStyle(
              color: DS.textPrimary,
              fontSize: 15.5,
              height: 1.6,
            ),
          ),

          // ── Images (extracted from <img> tags) ──
          if (question.imageUrls.isNotEmpty) ...[
            const SizedBox(height: DS.s12),
            ...question.imageUrls.map(
              (url) => Padding(
                padding: const EdgeInsets.only(bottom: DS.s8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      height: 160,
                      color: DS.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DS.primary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: DS.surfaceVariant,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: DS.textSecondary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INTEGER / FILL-IN ANSWER FIELD
// ─────────────────────────────────────────────
class _IntegerAnswerField extends StatelessWidget {
  final TextEditingController controller;
  const _IntegerAnswerField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Answer',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DS.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: DS.s8),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: DS.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Enter numeric answer…',
            hintStyle: const TextStyle(
              color: DS.textHint,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: DS.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
              borderSide: const BorderSide(color: DS.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
              borderSide: const BorderSide(color: DS.primary, width: 2),
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, _) => v.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: DS.textSecondary,
                        size: 18,
                      ),
                      onPressed: controller.clear,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: DS.s8),
        const Text(
          'Type a number. Decimals and negatives are allowed.',
          style: TextStyle(fontSize: 11.5, color: DS.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// MATCH-THE-COLUMN WIDGET
// ─────────────────────────────────────────────
class _MatchColumnWidget extends StatelessWidget {
  final TestQuestion question;
  final Map<String, String?> selections; // col1 key → selected col2 key
  final void Function(String col1Key, String? col2Key) onChanged;

  const _MatchColumnWidget({
    required this.question,
    required this.selections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final col2Keys = question.matchCol2.map((p) => p.key).toList();

    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          Container(
            color: DS.surfaceVariant,
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s10,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'COLUMN I',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DS.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: DS.s8),
                SizedBox(
                  width: 130,
                  child: Text(
                    'COLUMN II',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DS.primary,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: DS.border),

          // One row per col1 item
          ...question.matchCol1.asMap().entries.map((entry) {
            final idx = entry.key;
            final pair = entry.value;
            final selected = selections[pair.key];
            final isLast = idx == question.matchCol1.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s16,
                    vertical: DS.s10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Col1 label badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DS.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: DS.primary, width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            pair.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: DS.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.s10),
                      // Col1 value
                      Expanded(
                        flex: 5,
                        child: MathText(
                          pair.value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: DS.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.s8),
                      // Dropdown for col2 selection
                      Container(
                        width: 130,
                        height: 38,
                        decoration: BoxDecoration(
                          color: selected != null
                              ? DS.primaryLight
                              : DS.surfaceVariant,
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          border: Border.all(
                            color: selected != null ? DS.primary : DS.border,
                            width: selected != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selected,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: DS.textSecondary,
                              size: 18,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s8,
                            ),
                            hint: Text(
                              '— select —',
                              style: TextStyle(
                                fontSize: 12,
                                color: DS.textHint,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DS.primaryDark,
                            ),
                            dropdownColor: DS.surface,
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                            items: col2Keys.map((k) {
                              final label = question.matchCol2
                                  .firstWhere((p) => p.key == k)
                                  .key;
                              return DropdownMenuItem(
                                value: k,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (val) => onChanged(pair.key, val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: DS.border),
              ],
            );
          }),

          // Col2 reference list at the bottom
          const Divider(height: 1, color: DS.border),
          Container(
            color: DS.surfaceVariant,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s10,
            ),
            child: Wrap(
              spacing: DS.s16,
              runSpacing: DS.s6,
              children: question.matchCol2.map((p) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: DS.indigoLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: DS.indigo, width: 1.0),
                      ),
                      child: Center(
                        child: Text(
                          p.key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: DS.indigo,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DS.s6),
                    MathText(
                      p.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: DS.textPrimary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OPTION GRID — 2 columns, one option in front of another
// ─────────────────────────────────────────────
class _OptionGrid extends StatelessWidget {
  final List<OptionItem> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _OptionGrid({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DS.s10,
        mainAxisSpacing: DS.s10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (_, i) => _OptionTile(
        index: i,
        option: options[i],
        selected: selectedIndex == i,
        onTap: () => onSelect(i),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final OptionItem option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: selected ? DS.primaryLight : DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: selected ? DS.primary : DS.border,
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DS.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Letter badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF2B5BB8), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected ? null : DS.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? DS.primary : DS.border,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: selected ? Colors.white : DS.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(width: DS.s12),

            // Option content (text + optional image)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.text.isNotEmpty)
                    MathText(
                      option.text,
                      maxLines: 3,
                      style: TextStyle(
                        color: selected ? DS.primaryDark : DS.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  if (option.imageUrl != null) ...[
                    if (option.text.isNotEmpty) const SizedBox(height: DS.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      child: CachedNetworkImage(
                        imageUrl: option.imageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => Container(
                          height: 80,
                          color: DS.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DS.primary,
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: DS.textSecondary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Selected indicator
            if (selected) ...[
              const SizedBox(width: DS.s8),
              const Icon(
                Icons.check_circle_rounded,
                color: DS.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM NAVIGATION
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int index, total;
  final bool isMarked, submitting, isLast;
  final VoidCallback onMark;
  final VoidCallback onPalette;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _BottomNav({
    required this.index,
    required this.total,
    required this.isMarked,
    required this.submitting,
    required this.isLast,
    required this.onMark,
    required this.onPalette,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DS.s12,
        DS.s10,
        DS.s12,
        DS.s10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Palette button
          _NavIconBtn(
            icon: Icons.apps_rounded,
            onTap: onPalette,
            tooltip: 'Question palette',
          ),
          const SizedBox(width: DS.s8),

          // Prev button
          if (onPrev != null) ...[
            _NavIconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onPrev!,
              tooltip: 'Previous',
              size: 15,
            ),
            const SizedBox(width: DS.s8),
          ],

          const Spacer(),

          // Next / Submit
          SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: submitting
                    ? null
                    : isLast
                    ? const LinearGradient(
                        colors: [DS.success, Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF2B5BB8), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: submitting ? DS.border : null,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                boxShadow: submitting
                    ? []
                    : [
                        BoxShadow(
                          color: (isLast ? DS.success : DS.primary).withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: submitting ? null : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: DS.s20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Submit' : 'Save & Next',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: DS.s6),
                          Icon(
                            isLast
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  const _NavIconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DS.surfaceVariant,
            borderRadius: BorderRadius.circular(DS.radiusSm),
            border: Border.all(color: DS.border, width: 1),
          ),
          child: Icon(icon, size: size, color: DS.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUESTION PALETTE SHEET
// ─────────────────────────────────────────────
class _PaletteSheet extends StatelessWidget {
  final List<TestQuestion> questions;
  final Map<String, dynamic> answers;
  final Set<String> marked;
  final Set<String> visited;
  final int currentIdx;
  final void Function(int) onTap;

  const _PaletteSheet({
    required this.questions,
    required this.answers,
    required this.marked,
    required this.visited,
    required this.currentIdx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s24, DS.s20, DS.s24, DS.s28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DS.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: DS.s16),

          // Title
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  color: DS.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: DS.s12),
              const Text(
                'Question Palette',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DS.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${questions.length} total',
                style: const TextStyle(color: DS.textSecondary, fontSize: 12.5),
              ),
            ],
          ),

          const SizedBox(height: DS.s20),

          // Subject-wise grids
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _subjectGroups.entries.map((group) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DS.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.key,
                          style: const TextStyle(
                            color: DS.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DS.s8),
                        Wrap(
                          spacing: DS.s8,
                          runSpacing: DS.s8,
                          children: group.value.map((i) {
                            final q = questions[i];
                            final rawAnswer = answers[q.id];
                            final answered = q.isMatchType
                                ? rawAnswer is Map &&
                                      rawAnswer.isNotEmpty &&
                                      rawAnswer.values.every((v) => v != null)
                                : rawAnswer is String
                                ? rawAnswer.trim().isNotEmpty
                                : rawAnswer != null;
                            final isMarked = marked.contains(q.id);
                            final isCurrent = i == currentIdx;
                            final wasVisited = visited.contains(q.id);

                            Color bg, textC;
                            if (isCurrent) {
                              bg = DS.primary;
                              textC = Colors.white;
                            } else if (isMarked) {
                              bg = DS.warning;
                              textC = Colors.white;
                            } else if (answered) {
                              bg = DS.success;
                              textC = Colors.white;
                            } else if (wasVisited) {
                              bg = DS.errorSurface;
                              textC = DS.error;
                            } else {
                              bg = DS.surfaceVariant;
                              textC = DS.textSecondary;
                            }

                            return GestureDetector(
                              onTap: () => onTap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusSm,
                                  ),
                                  border: Border.all(
                                    color: isCurrent
                                        ? DS.primaryDark
                                        : isMarked
                                        ? DS.warning.withValues(alpha: 0.50)
                                        : answered
                                        ? DS.success.withValues(alpha: 0.40)
                                        : DS.border,
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: DS.primary.withValues(
                                              alpha: 0.30,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: textC,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: DS.s16),
          const Divider(color: DS.border, height: 1),
          const SizedBox(height: DS.s14),

          // Legend
          Wrap(
            spacing: DS.s16,
            runSpacing: DS.s8,
            children: const [
              _PaletteLegend(color: DS.primary, label: 'Current'),
              _PaletteLegend(color: DS.success, label: 'Answered'),
              _PaletteLegend(color: DS.warning, label: 'Marked'),
              _PaletteLegend(
                color: DS.errorSurface,
                label: 'Not answered',
                textColor: DS.error,
              ),
              _PaletteLegend(
                color: DS.surfaceVariant,
                label: 'Not visited',
                textColor: DS.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, List<int>> get _subjectGroups {
    final groups = <String, List<int>>{};
    for (var i = 0; i < questions.length; i++) {
      final subject = questions[i].subject.trim().isEmpty
          ? 'General'
          : questions[i].subject.trim();
      groups.putIfAbsent(subject, () => []).add(i);
    }
    return groups;
  }
}

class _PaletteLegend extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _PaletteLegend({
    required this.color,
    required this.label,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DS.s4),
          border: Border.all(color: DS.border, width: 1),
        ),
      ),
      const SizedBox(width: DS.s6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: DS.textSecondary),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// LEAVE DIALOG
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// TAB-SWITCH WARNING DIALOG — shown on violations 1 and 2
// ─────────────────────────────────────────────
class _TabSwitchWarningDialog extends StatelessWidget {
  final int violationCount;
  final int maxViolations;

  const _TabSwitchWarningDialog({
    required this.violationCount,
    required this.maxViolations,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = maxViolations - violationCount;
    final isFinal = remaining <= 1;

    final title = isFinal
        ? 'Final Warning — 1 chance left'
        : 'Warning $violationCount of $maxViolations — Window Switch Detected';
    final body = isFinal
        ? 'You have switched windows twice. The next switch will auto-submit your test immediately.'
        : 'You switched away from the test window. You have $remaining more chance${remaining == 1 ? '' : 's'} before your test is auto-submitted.';

    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DS.errorSurface,
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: DS.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DS.s14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s14),
            Text(
              body,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s10),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: DS.textSecondary),
                children: [
                  const TextSpan(text: 'Violations: '),
                  TextSpan(
                    text: '$violationCount',
                    style: const TextStyle(
                      color: DS.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' / $maxViolations'),
                ],
              ),
            ),
            const SizedBox(height: DS.s20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: DS.s14),
                  elevation: 0,
                ),
                child: const Text(
                  'I UNDERSTAND, CONTINUE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AUTO-SUBMITTED DIALOG — shown on the 3rd violation
// ─────────────────────────────────────────────
class _AutoSubmittedDialog extends StatelessWidget {
  const _AutoSubmittedDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(Icons.block_rounded, color: DS.error, size: 30),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Test auto-submitted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'You switched the test window 3 times. As per the exam policy, '
              'your test has been submitted automatically. The Bansal team '
              'will review your attempt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: DS.s14),
                  elevation: 0,
                ),
                child: const Text(
                  'Exit Test',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: DS.error,
                size: 30,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Leave Test?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Your test will be submitted immediately with your current '
              'answers. You will not be able to re-enter or resume this '
              'test once you leave.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DS.textPrimary,
                      side: const BorderSide(color: DS.border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s12),
                    ),
                    child: const Text(
                      'Stay',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DS.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Submit & Leave',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUBMIT CONFIRMATION DIALOG
// ─────────────────────────────────────────────
class _SubmitDialog extends StatelessWidget {
  final int answered, total, unanswered, marked;

  const _SubmitDialog({
    required this.answered,
    required this.total,
    required this.unanswered,
    required this.marked,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B5BB8), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Submit Test?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s16),

            // Summary
            Container(
              padding: const EdgeInsets.all(DS.s14),
              decoration: BoxDecoration(
                color: DS.background,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.check_circle_outline_rounded,
                    color: DS.success,
                    label: 'Answered',
                    value: '$answered / $total',
                  ),
                  const SizedBox(height: DS.s8),
                  _SummaryRow(
                    icon: Icons.radio_button_unchecked_rounded,
                    color: DS.error,
                    label: 'Unanswered',
                    value: '$unanswered',
                  ),
                  if (marked > 0) ...[
                    const SizedBox(height: DS.s8),
                    _SummaryRow(
                      icon: Icons.bookmark_rounded,
                      color: DS.warning,
                      label: 'Marked for review',
                      value: '$marked',
                    ),
                  ],
                ],
              ),
            ),

            if (unanswered > 0) ...[
              const SizedBox(height: DS.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s12,
                  vertical: DS.s10,
                ),
                decoration: BoxDecoration(
                  color: DS.warningSurface,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(color: DS.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: DS.warning,
                      size: 15,
                    ),
                    const SizedBox(width: DS.s8),
                    Expanded(
                      child: Text(
                        '$unanswered question${unanswered == 1 ? '' : 's'} left unanswered.',
                        style: const TextStyle(
                          color: DS.textPrimary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: DS.s24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DS.textPrimary,
                      side: const BorderSide(color: DS.border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s12),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2B5BB8), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: DS.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: DS.s12),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: DS.s8),
      Text(
        label,
        style: const TextStyle(color: DS.textSecondary, fontSize: 13),
      ),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// LOADING SCAFFOLD
// ─────────────────────────────────────────────
class _LoadingScaffold extends StatelessWidget {
  final String title;
  const _LoadingScaffold({required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DS.background,
    appBar: AppBar(
      backgroundColor: DS.surface,
      elevation: 0,
      title: Text(
        title.isEmpty ? 'Loading…' : title,
        style: const TextStyle(
          color: DS.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: const Center(
      child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
    ),
  );
}

// ─────────────────────────────────────────────
// ERROR SCAFFOLD
// ─────────────────────────────────────────────
class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DS.background,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'Failed to Load Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              message,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s24),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DS.textPrimary,
                side: const BorderSide(color: DS.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s20,
                  vertical: DS.s12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
