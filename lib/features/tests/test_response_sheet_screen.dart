import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
import '../../skeleton_loading/test_response_sheet_skeleton.dart';
import 'data/question_image_resolver.dart';
import 'test_engine_screen.dart' show MathText;
import 'test_result_screen.dart' show DS;

// ─────────────────────────────────────────────
// RESPONSE SHEET QUESTION MODEL
// ─────────────────────────────────────────────
enum ResponseStatus { correct, wrong, unattempted, bonus }

class ResponseQuestion {
  final String id;
  final int position;
  final String subject;
  final String questionType;
  final String questionText; // <img> tags already stripped
  final List<String> imageUrls; // resolved, ready-to-render image URLs
  final List<Map<String, dynamic>> options;
  final dynamic selected;
  final dynamic correctAnswer;
  final bool isBonus;
  final bool
  attempted; // from attempt metadata — trustworthy regardless of release state
  final bool
  isCorrect; // from attempt metadata — trustworthy regardless of release state
  final double marks;
  final double maxMarks;
  final String? explanation;

  const ResponseQuestion({
    required this.id,
    required this.position,
    required this.subject,
    required this.questionType,
    required this.questionText,
    required this.imageUrls,
    required this.options,
    this.selected,
    this.correctAnswer,
    required this.isBonus,
    required this.attempted,
    required this.isCorrect,
    required this.marks,
    required this.maxMarks,
    this.explanation,
  });

  ResponseStatus get status {
    if (isBonus) return ResponseStatus.bonus;
    if (!attempted) return ResponseStatus.unattempted;
    return isCorrect ? ResponseStatus.correct : ResponseStatus.wrong;
  }

  static Future<ResponseQuestion> fromJson(
    Map<String, dynamic> j,
    Map<String, dynamic>? meta,
  ) async {
    final rawOpts = j['options'];
    final opts = <Map<String, dynamic>>[];
    if (rawOpts is List) {
      for (final e in rawOpts) {
        if (e is Map) {
          opts.add(e.cast<String, dynamic>());
        } else {
          opts.add({'text': e.toString()});
        }
      }
    }

    var text = j['question_text'] as String? ?? '';
    var imageUrls = extractImgUrls(text);
    if (imageUrls.isNotEmpty) {
      text = stripImgTags(text);
    } else {
      final dedicated = j['question_image_url'] as String?;
      if (dedicated != null && dedicated.isNotEmpty) imageUrls = [dedicated];
    }
    imageUrls = await Future.wait(imageUrls.map(resolveQuestionImageUrl));

    return ResponseQuestion(
      id: j['id'] as String,
      position: (j['position'] as num?)?.toInt() ?? 0,
      subject: j['subject'] as String? ?? 'General',
      questionType: j['question_type'] as String? ?? 'mcq-single',
      questionText: text,
      imageUrls: imageUrls,
      options: opts,
      selected: j['selected'],
      correctAnswer:
          (j['question_type'] == 'numerical' || j['question_type'] == 'integer')
          ? (j['numerical_answer'] ?? j['correct_answer'])
          : j['correct_answer'],
      isBonus: j['is_bonus'] as bool? ?? meta?['is_bonus'] as bool? ?? false,
      attempted: meta?['attempted'] as bool? ?? (j['selected'] != null),
      isCorrect: meta?['is_correct'] as bool? ?? false,
      marks: (meta?['marks'] as num?)?.toDouble() ?? 0,
      maxMarks:
          (j['marks_correct'] as num?)?.toDouble() ??
          (meta?['max_marks'] as num?)?.toDouble() ??
          4,
      explanation: j['explanation'] as String?,
    );
  }
}

// ─────────────────────────────────────────────
// TEST RESPONSE SHEET SCREEN
// ─────────────────────────────────────────────
class TestResponseSheetScreen extends StatefulWidget {
  final String attemptId;
  const TestResponseSheetScreen({super.key, required this.attemptId});

  @override
  State<TestResponseSheetScreen> createState() =>
      _TestResponseSheetScreenState();
}

class _TestResponseSheetScreenState extends State<TestResponseSheetScreen> {
  bool _loading = true;
  String? _error;
  bool _released = false;
  double _score = 0;
  List<ResponseQuestion> _questions = [];
  String _filter = 'all'; // all | correct | wrong | unattempted
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.client.rpc(
        'get_attempt_response_sheet',
        params: {'_attempt_id': widget.attemptId},
      );
      final j = (data as Map).cast<String, dynamic>();
      final released = j['released'] as bool? ?? false;
      final metadata = (j['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
      final metaQuestions =
          (metadata['questions'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          const [];
      final metaById = <String, Map<String, dynamic>>{};
      for (final m in metaQuestions) {
        final id = m['question_id']?.toString();
        if (id != null && id.isNotEmpty) metaById[id] = m;
      }

      final qs = await Future.wait(
        (j['questions'] as List? ?? []).map((e) {
          final row = (e as Map).cast<String, dynamic>();
          return ResponseQuestion.fromJson(row, metaById[row['id']]);
        }),
      );
      qs.sort((a, b) => a.position.compareTo(b.position));

      if (!mounted) return;
      setState(() {
        _released = released;
        _score = (j['score'] as num?)?.toDouble() ?? 0;
        _questions = qs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppException.from(e).userMessage;
        _loading = false;
      });
    }
  }

  List<ResponseQuestion> get _filtered {
    if (_filter == 'all') return _questions;
    return _questions.where((q) {
      return switch (_filter) {
        'correct' => q.status == ResponseStatus.correct,
        'wrong' => q.status == ResponseStatus.wrong,
        'unattempted' => q.status == ResponseStatus.unattempted,
        _ => true,
      };
    }).toList();
  }

  Future<void> _downloadPdf() async {
    if (_downloading || _questions.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final doc = pw.Document();
      String clean(String value) => value
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      String answer(dynamic value) {
        if (value == null) return '-';
        if (value is List) return value.map(answer).join(', ');
        if (value is Map)
          return value.entries
              .map((e) => '${e.key}->${answer(e.value)}')
              .join(', ');
        return value.toString();
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Text(
              'BANSAL CLASSES - RESPONSE SHEET',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Score: ${_score.toStringAsFixed(1)}  |  Questions: ${_questions.length}',
            ),
            pw.SizedBox(height: 14),
            for (final q in _questions) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Q${q.position + 1}  ${clean(q.subject)}  |  ${q.status.name.toUpperCase()}  |  ${q.marks.toStringAsFixed(1)}/${q.maxMarks.toStringAsFixed(1)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      clean(q.questionText),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    if (q.options.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      for (var i = 0; i < q.options.length; i++)
                        pw.Text(
                          '${String.fromCharCode(65 + i)}. ${clean((q.options[i]['text'] ?? q.options[i]['value'] ?? '').toString())}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Selected answer: ${clean(answer(q.selected))}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    if (_released)
                      pw.Text(
                        'Correct answer: ${clean(answer(q.correctAnswer))}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    if (_released &&
                        q.explanation != null &&
                        q.explanation!.isNotEmpty)
                      pw.Text(
                        'Explanation: ${clean(q.explanation!)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          ],
        ),
      );
      final bytes = await doc.save();
      await FileSaver.instance.saveAs(
        name: 'Bansal_Response_Sheet_${widget.attemptId}',
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not download response sheet: ${AppException.from(e).userMessage}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correct = _questions
        .where((q) => q.status == ResponseStatus.correct)
        .length;
    final wrong = _questions
        .where((q) => q.status == ResponseStatus.wrong)
        .length;
    final unattempted = _questions
        .where((q) => q.status == ResponseStatus.unattempted)
        .length;

    return Scaffold(
      backgroundColor: DS.background,
      appBar: AppBar(
        backgroundColor: DS.surface,
        elevation: 0,
        surfaceTintColor: DS.surface,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/tests'),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: DS.textPrimary,
            size: 22,
          ),
        ),
        title: const Text(
          'Back to result',
          style: TextStyle(
            color: DS.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _loading || _questions.isEmpty || _downloading
                ? null
                : _downloadPdf,
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, color: DS.primary),
          ),
          const SizedBox(width: DS.s8),
        ],
      ),
      body: _loading
          ? const TestResponseSheetSkeleton()
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(DS.s32),
                child: Text(
                  _error!,
                  style: const TextStyle(color: DS.textSecondary),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s16,
                    DS.s12,
                    DS.s16,
                    DS.s12,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${_questions.length})',
                          selected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: DS.s8),
                        _FilterChip(
                          label: 'Correct ($correct)',
                          selected: _filter == 'correct',
                          color: DS.success,
                          onTap: () => setState(() => _filter = 'correct'),
                        ),
                        const SizedBox(width: DS.s8),
                        _FilterChip(
                          label: 'Wrong ($wrong)',
                          selected: _filter == 'wrong',
                          color: DS.error,
                          onTap: () => setState(() => _filter = 'wrong'),
                        ),
                        const SizedBox(width: DS.s8),
                        _FilterChip(
                          label: 'Unattempted ($unattempted)',
                          selected: _filter == 'unattempted',
                          color: DS.muted,
                          onTap: () => setState(() => _filter = 'unattempted'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s16,
                      0,
                      DS.s16,
                      DS.s32,
                    ),
                    children: [
                      _HeaderCard(
                        questionCount: _questions.length,
                        score: _score,
                        released: _released,
                      ),
                      const SizedBox(height: DS.s14),
                      for (final q in _filtered) ...[
                        _ResponseCard(question: q, released: _released),
                        const SizedBox(height: DS.s12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER CARD — title + question count/score/release note
// ─────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final int questionCount;
  final double score;
  final bool released;

  const _HeaderCard({
    required this.questionCount,
    required this.score,
    required this.released,
  });

  @override
  Widget build(BuildContext context) {
    final scoreLabel = score.truncateToDouble() == score
        ? score.toStringAsFixed(0)
        : score.toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Response Sheet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s6),
          Text(
            '$questionCount questions · Score $scoreLabel'
            '${released ? '' : ' · Correct answers will appear after the result release window'}',
            style: const TextStyle(
              fontSize: 12.5,
              color: DS.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? DS.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s14,
          vertical: DS.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : DS.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? c : DS.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? c : DS.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ResponseCard extends StatefulWidget {
  final ResponseQuestion question;
  final bool released;

  const _ResponseCard({required this.question, required this.released});

  @override
  State<_ResponseCard> createState() => _ResponseCardState();
}

class _ResponseCardState extends State<_ResponseCard> {
  bool _expanded = false;

  Set<int> _indices(dynamic value) {
    if (value is Map && value.containsKey('value'))
      return _indices(value['value']);
    if (value is List) {
      return value
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet();
    }
    final one = int.tryParse(value?.toString() ?? '');
    return one == null ? <int>{} : {one};
  }

  String _answerText(dynamic value) {
    if (value == null) return '—';
    if (value is List) return value.map(_answerText).join(', ');
    if (value is Map) {
      return value.entries
          .map((e) => '${e.key} → ${_answerText(e.value)}')
          .join(', ');
    }
    return value.toString();
  }

  (IconData, Color, Color, String) _statusMeta(ResponseStatus s) {
    return switch (s) {
      ResponseStatus.correct => (
        Icons.check_circle_rounded,
        DS.success,
        DS.successSurface,
        'Correct',
      ),
      ResponseStatus.wrong => (
        Icons.cancel_rounded,
        DS.error,
        DS.errorSurface,
        'Wrong',
      ),
      ResponseStatus.unattempted => (
        Icons.remove_circle_outline_rounded,
        DS.muted,
        DS.surfaceVariant,
        'Unattempted',
      ),
      ResponseStatus.bonus => (
        Icons.stars_rounded,
        DS.indigo,
        DS.indigoLight,
        'Bonus',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final status = q.status;
    final (icon, color, bg, label) = _statusMeta(status);
    final correctIndices = _indices(q.correctAnswer);
    final selectedIndices = _indices(q.selected);
    final marksLabel = q.attempted
        ? '${q.marks >= 0 ? '+' : ''}${q.marks.toStringAsFixed(0)} / ${q.maxMarks.toStringAsFixed(0)}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border),
      ),
      padding: const EdgeInsets.all(DS.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Q${q.position + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DS.primary,
                  ),
                ),
              ),
              const SizedBox(width: DS.s8),
              Text(
                q.subject,
                style: const TextStyle(fontSize: 11, color: DS.textSecondary),
              ),
              const SizedBox(width: DS.s6),
              Text(
                q.questionType.toUpperCase().replaceAll('-', ' '),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: DS.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (marksLabel != null) ...[
                Text(
                  marksLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: DS.s8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: DS.s4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s10),
          MathText(
            q.questionText,
            style: const TextStyle(
              fontSize: 13.5,
              color: DS.textPrimary,
              height: 1.5,
            ),
          ),
          if (q.imageUrls.isNotEmpty) ...[
            const SizedBox(height: DS.s8),
            for (final url in q.imageUrls)
              Padding(
                padding: const EdgeInsets.only(bottom: DS.s8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Container(
                      height: 120,
                      color: DS.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DS.primary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: DS.surfaceVariant,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: DS.textSecondary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: DS.s10),
          for (int i = 0; i < q.options.length; i++)
            _OptionRow(
              index: i,
              text: (q.options[i]['text'] ?? '').toString(),
              isSelected: selectedIndices.contains(i),
              isCorrect: correctIndices.contains(i),
              showCorrectness: widget.released,
            ),
          if (q.options.isEmpty) ...[
            _AnswerBox(label: 'Your answer', value: _answerText(q.selected)),
            if (widget.released) ...[
              const SizedBox(height: DS.s8),
              _AnswerBox(
                label: 'Correct answer',
                value: _answerText(q.correctAnswer),
                correct: true,
              ),
            ],
          ],
          if (widget.released &&
              q.explanation != null &&
              q.explanation!.isNotEmpty) ...[
            const SizedBox(height: DS.s10),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: DS.primary,
                  ),
                  const SizedBox(width: DS.s4),
                  const Text(
                    'Solution / Explanation',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: DS.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: DS.s8),
                child: MathText(
                  q.explanation!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DS.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  final String label;
  final String value;
  final bool correct;

  const _AnswerBox({
    required this.label,
    required this.value,
    this.correct = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(DS.s10),
    decoration: BoxDecoration(
      color: correct ? DS.successSurface : DS.surfaceVariant,
      borderRadius: BorderRadius.circular(DS.radiusSm),
      border: Border.all(color: correct ? DS.success : DS.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: correct ? DS.success : DS.textSecondary,
          ),
        ),
        const SizedBox(height: DS.s4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: DS.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────
  // OPTION ROW — always shows the student's pick; reveals correctness only
  // once results are released (mirrors web's "Your pick" badge behavior).
  // ─────────────────────────────────────────────
}

class _OptionRow extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool showCorrectness;

  const _OptionRow({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.showCorrectness,
  });

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';

    Color border = DS.border;
    Color bg = DS.surface;
    Color fg = DS.textPrimary;

    if (showCorrectness && isCorrect) {
      border = DS.success;
      bg = DS.successSurface;
      fg = DS.success;
    } else if (isSelected && showCorrectness && !isCorrect) {
      border = DS.error;
      bg = DS.errorSurface;
      fg = DS.error;
    } else if (isSelected) {
      border = DS.primary;
      bg = DS.primaryLight;
      fg = DS.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s8),
      child: Container(
        padding: const EdgeInsets.all(DS.s10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DS.radiusSm),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          children: [
            Text(
              '$letter.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fg,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: DS.s8),
            Expanded(
              child: MathText(
                text,
                style: TextStyle(fontSize: 12.5, color: fg),
              ),
            ),
            if (isSelected) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'YOUR PICK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ] else if (showCorrectness && isCorrect)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: DS.success,
              ),
          ],
        ),
      ),
    );
  }
}
