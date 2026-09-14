import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/supabase_service.dart';

// ─────────────────────────────────────────────
// Brand colors — mirrors the web app's generateAdminStyleReportPdf.ts
// ─────────────────────────────────────────────
final _navy = PdfColor.fromInt(0xFF1E293B);
final _orange = PdfColor.fromInt(0xFFF97316);
final _green = PdfColor.fromInt(0xFF10B981);
final _red = PdfColor.fromInt(0xFFEF4444);
final _amber = PdfColor.fromInt(0xFFF59E0B);
final _gray = PdfColor.fromInt(0xFF6B7280);
final _lightGray = PdfColor.fromInt(0xFFF3F4F6);

class ScorecardQuestion {
  final int position;
  final String subject;
  final String yourAnswer;
  final String correctAnswer;
  final String result; // Correct | Wrong | Partial | Bonus | Unattempted
  final double marks;

  const ScorecardQuestion({
    required this.position,
    required this.subject,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.result,
    required this.marks,
  });
}

class ScorecardComparison {
  final double classAvg;
  final double topper;
  const ScorecardComparison({required this.classAvg, required this.topper});
}

class ScorecardInput {
  final String studentName;
  final String rollNumber;
  final String batch;
  final String testTitle;
  final String examPattern;
  final double totalMarks;
  final String dateLabel;
  final List<String> subjects;
  final Map<String, double> subjectScores;
  final double totalScore;
  final double percentage;
  final int correctCount;
  final int wrongCount;
  final int unattemptedCount;
  final String rankLabel;
  final ScorecardComparison? comparison;
  final List<ScorecardQuestion> questions;

  const ScorecardInput({
    required this.studentName,
    required this.rollNumber,
    required this.batch,
    required this.testTitle,
    required this.examPattern,
    required this.totalMarks,
    required this.dateLabel,
    required this.subjects,
    required this.subjectScores,
    required this.totalScore,
    required this.percentage,
    required this.correctCount,
    required this.wrongCount,
    required this.unattemptedCount,
    required this.rankLabel,
    this.comparison,
    required this.questions,
  });
}

/// Fetches everything needed for the scorecard PDF: student/batch profile,
/// test meta, and the full per-question response sheet — mirroring the web
/// app's buildScorecardInput().
Future<ScorecardInput> buildScorecardInput(String attemptId) async {
  final client = SupabaseService.client;

  final attempt = await client
      .from('test_attempts')
      .select(
        'id, user_id, test_id, test_name, score, submitted_at, attempted_at, metadata',
      )
      .eq('id', attemptId)
      .single();

  final userId = attempt['user_id'] as String;
  final testId = attempt['test_id'] as String;
  final metadata = (attempt['metadata'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic>? profileRow;
  try {
    profileRow = await client
        .from('profiles')
        .select(
          'full_name, roll_number, batch_label, batch_id, course_batches(name)',
        )
        .eq('user_id', userId)
        .maybeSingle();
  } catch (_) {
    profileRow = await client
        .from('profiles')
        .select('full_name, roll_number, batch_label, batch_id')
        .eq('user_id', userId)
        .maybeSingle();
  }

  final batchRaw = profileRow?['course_batches'];
  final batchMap = batchRaw is Map
      ? batchRaw.cast<String, dynamic>()
      : (batchRaw is List && batchRaw.isNotEmpty)
      ? (batchRaw.first as Map).cast<String, dynamic>()
      : null;

  final testRow = await client
      .from('tests')
      .select('title, exam_pattern, total_marks')
      .eq('id', testId)
      .single();

  final sheetData = await client.rpc(
    'get_attempt_response_sheet',
    params: {'_attempt_id': attemptId},
  );
  final sheet = (sheetData as Map).cast<String, dynamic>();
  final released = sheet['released'] as bool? ?? false;
  Map<String, dynamic>? rank;
  try {
    final rankData = await client.rpc(
      'get_test_rank',
      params: {'_attempt_id': attemptId},
    );
    rank = (rankData as Map?)?.cast<String, dynamic>();
  } catch (_) {
    rank = null;
  }

  final metaQuestions =
      (metadata['questions'] as List?)
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList() ??
      const [];
  final metaByQuestionId = <String, Map<String, dynamic>>{};
  for (final q in metaQuestions) {
    final id = q['question_id']?.toString();
    if (id != null && id.isNotEmpty) metaByQuestionId[id] = q;
  }

  final subjectScores = <String, double>{};
  final questions = <ScorecardQuestion>[];

  final sheetQuestions =
      (sheet['questions'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList()
        ..sort(
          (a, b) => ((a['position'] as num?) ?? 0).compareTo(
            (b['position'] as num?) ?? 0,
          ),
        );

  for (final q in sheetQuestions) {
    final id = q['id'] as String;
    final subject = q['subject'] as String? ?? 'General';
    final meta = metaByQuestionId[id];
    final attempted = meta?['attempted'] as bool? ?? false;
    final isCorrect = meta?['is_correct'] as bool? ?? false;
    final isBonus =
        q['is_bonus'] as bool? ?? meta?['is_bonus'] as bool? ?? false;
    final marks = (meta?['marks'] as num?)?.toDouble() ?? 0;

    subjectScores[subject] = (subjectScores[subject] ?? 0) + marks;

    final options = (q['options'] as List? ?? const <dynamic>[]).toList();

    String labelFor(int? idx) {
      if (idx == null || idx < 0 || idx >= options.length) return '—';
      final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
      final letter = idx < letters.length ? letters[idx] : '${idx + 1}';
      final option = options[idx];
      final text = option is Map
          ? (option['text'] ?? option['value'] ?? '').toString()
          : option.toString();
      return text.isEmpty ? letter : '$letter. $text';
    }

    String formatAnswer(dynamic value) {
      if (value == null) return '—';
      if (value is num && value.toInt() == value)
        return labelFor(value.toInt());
      if (value is List) return value.map(formatAnswer).join(', ');
      if (value is Map) {
        return value.entries
            .map((e) => '${e.key}→${formatAnswer(e.value)}')
            .join(', ');
      }
      final numeric = int.tryParse(value.toString());
      return numeric != null && options.isNotEmpty
          ? labelFor(numeric)
          : value.toString();
    }

    final selected = q['selected'];
    final correctValue =
        (q['question_type'] == 'numerical' || q['question_type'] == 'integer')
        ? (q['numerical_answer'] ?? q['correct_answer'])
        : q['correct_answer'];

    final result = isBonus
        ? 'Bonus'
        : !attempted
        ? 'Unattempted'
        : isCorrect
        ? 'Correct'
        : 'Wrong';

    questions.add(
      ScorecardQuestion(
        position: ((q['position'] as num?) ?? 0).toInt() + 1,
        subject: subject,
        yourAnswer: attempted ? formatAnswer(selected) : '—',
        correctAnswer: released ? formatAnswer(correctValue) : '—',
        result: result,
        marks: marks,
      ),
    );
  }

  final totalScore = (attempt['score'] as num?)?.toDouble() ?? 0;
  final totalMarks = (testRow['total_marks'] as num?)?.toDouble() ?? 0;
  final percentage = totalMarks == 0 ? 0.0 : (totalScore / totalMarks) * 100;

  final excluded = rank?['excluded'] as bool? ?? false;
  final avgScore = (rank?['average_score'] as num?)?.toDouble();
  final topperScore = (rank?['topper_score'] as num?)?.toDouble();
  final comparison =
      (released && !excluded && avgScore != null && topperScore != null)
      ? ScorecardComparison(classAvg: avgScore, topper: topperScore)
      : null;

  final rankValue = rank?['rank'];
  final rankLabel = rankValue != null ? '#$rankValue' : '—';

  final submittedRaw = attempt['submitted_at'] ?? attempt['attempted_at'];
  final submittedAt = submittedRaw != null
      ? DateTime.tryParse(submittedRaw as String)
      : null;

  final correctCount = questions.where((q) => q.result == 'Correct').length;
  final wrongCount = questions.where((q) => q.result == 'Wrong').length;
  final unattemptedCount = questions
      .where((q) => q.result == 'Unattempted')
      .length;

  return ScorecardInput(
    studentName: profileRow?['full_name'] as String? ?? 'Student',
    rollNumber: profileRow?['roll_number'] as String? ?? '—',
    batch:
        batchMap?['name'] as String? ??
        profileRow?['batch_label'] as String? ??
        '—',
    testTitle:
        testRow['title'] as String? ??
        attempt['test_name'] as String? ??
        'Test',
    examPattern: (testRow['exam_pattern'] as String? ?? '')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .toUpperCase(),
    totalMarks: totalMarks,
    dateLabel: submittedAt != null
        ? DateFormat('dd/MM/yyyy').format(submittedAt.toLocal())
        : '—',
    subjects: subjectScores.keys.toList()..sort(),
    subjectScores: subjectScores,
    totalScore: totalScore,
    percentage: percentage,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unattemptedCount: unattemptedCount,
    rankLabel: rankLabel,
    comparison: comparison,
    questions: questions,
  );
}

/// Builds a printable PDF scorecard and opens the system share sheet so the
/// user can save it to Downloads, Drive, or send it — mirroring the web
/// app's admin-style report (student info, subject scores, comparison
/// chart, question-by-question breakdown).
Future<void> generateAndShareScorecard(ScorecardInput input) async {
  final doc = pw.Document();
  Uint8List? logoBytes;
  try {
    final data = await rootBundle.load('assets/icon/app-icon.png');
    logoBytes = data.buffer.asUint8List();
  } catch (_) {
    logoBytes = null;
  }
  final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  final tableHeaderStyle = pw.TextStyle(
    color: PdfColors.white,
    fontWeight: pw.FontWeight.bold,
    fontSize: 9,
  );
  final cellStyle = const pw.TextStyle(fontSize: 9);

  pw.Widget buildHeader() {
    return pw.Column(
      children: [
        if (logo != null)
          pw.Opacity(
            opacity: 0.06,
            child: pw.Image(logo, width: 220, height: 220),
          ),
        pw.Text(
          'BANSAL CLASSES PVT. LTD.',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${input.testTitle} — Student Report',
          style: pw.TextStyle(
            fontSize: 11,
            color: _orange,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget buildFooter(pw.Context ctx) {
    return pw.Text(
      'Generated ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} · Page ${ctx.pageNumber}/${ctx.pagesCount}',
      style: pw.TextStyle(fontSize: 8, color: _gray),
      textAlign: pw.TextAlign.center,
    );
  }

  pw.Widget studentInfoTable() {
    final rows = [
      ('Student', input.studentName),
      ('Roll No', input.rollNumber),
      ('Batch', input.batch),
      ('Date', input.dateLabel),
      ('Pattern', input.examPattern),
      ('Max Marks', input.totalMarks.toStringAsFixed(0)),
    ];
    return pw.Table(
      columnWidths: {0: const pw.FixedColumnWidth(110)},
      children: rows
          .map(
            (r) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    r.$1,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  pw.Widget subjectScoreTable() {
    final headerDecoration = pw.BoxDecoration(color: _navy);
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: headerDecoration,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Subject / Metric', style: tableHeaderStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Marks', style: tableHeaderStyle),
          ),
        ],
      ),
      for (final subj in input.subjects)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(subj, style: cellStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                (input.subjectScores[subj] ?? 0).toStringAsFixed(1),
                style: cellStyle,
              ),
            ),
          ],
        ),
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _lightGray),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              'TOTAL',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              input.totalScore.toStringAsFixed(1),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('PERCENTAGE', style: cellStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              '${input.percentage.toStringAsFixed(2)}%',
              style: cellStyle,
            ),
          ),
        ],
      ),
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('CORRECT / WRONG / UNATTEMPTED', style: cellStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              '${input.correctCount} / ${input.wrongCount} / ${input.unattemptedCount}',
              style: cellStyle,
            ),
          ),
        ],
      ),
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('RANK', style: cellStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(input.rankLabel, style: cellStyle),
          ),
        ],
      ),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows,
    );
  }

  pw.Widget? comparisonChart() {
    final c = input.comparison;
    if (c == null) return null;
    final maxVal = [
      c.classAvg,
      c.topper,
      input.totalScore,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    pw.Widget bar(String label, double value, PdfColor color) {
      final heightFraction = maxVal == 0 ? 0.0 : (value / maxVal);
      return pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            value.toStringAsFixed(1),
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            width: 36,
            height: 80 * heightFraction.clamp(0.02, 1.0),
            color: color,
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'You vs Class (anonymous)',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            bar('You', input.totalScore, _orange),
            bar('Class Avg', c.classAvg, _navy),
            bar('Topper', c.topper, _green),
          ],
        ),
      ],
    );
  }

  PdfColor resultColor(String result) => switch (result) {
    'Correct' => _green,
    'Wrong' => _red,
    'Partial' || 'Bonus' => _amber,
    _ => _gray,
  };

  pw.Widget? questionTable() {
    if (input.questions.isEmpty) return null;
    final headerDecoration = pw.BoxDecoration(color: _navy);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FixedColumnWidth(56),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(3),
        4: pw.FixedColumnWidth(48),
        5: pw.FixedColumnWidth(36),
      },
      children: [
        pw.TableRow(
          decoration: headerDecoration,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Q#', style: tableHeaderStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Subject', style: tableHeaderStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Your Answer', style: tableHeaderStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Correct Answer', style: tableHeaderStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Result', style: tableHeaderStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Marks', style: tableHeaderStyle),
            ),
          ],
        ),
        for (final q in input.questions)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text('${q.position}', style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(q.subject, style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(q.yourAnswer, style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(q.correctAnswer, style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  q.result,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: resultColor(q.result),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  q.marks.toStringAsFixed(0),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: q.marks > 0 ? _green : (q.marks < 0 ? _red : _gray),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (ctx) =>
          ctx.pageNumber == 1 ? buildHeader() : pw.SizedBox.shrink(),
      footer: buildFooter,
      build: (ctx) => [
        studentInfoTable(),
        pw.SizedBox(height: 16),
        subjectScoreTable(),
        if (comparisonChart() != null) ...[
          pw.SizedBox(height: 20),
          comparisonChart()!,
        ],
      ],
    ),
  );

  final qTable = questionTable();
  if (qTable != null) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: buildFooter,
        build: (ctx) => [
          pw.Text(
            'Question-by-question breakdown',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          qTable,
        ],
      ),
    );
  }

  final bytes = await doc.save();
  final safeName = input.studentName.replaceAll(RegExp(r'\s+'), '_');
  final safeTest = input.testTitle.replaceAll(RegExp(r'\s+'), '_');
  final fileName = '${safeName}_$safeTest';

  // saveAs() opens Android's native "Save As" dialog (Storage Access
  // Framework) so the user picks Downloads (or anywhere) and the file is
  // written there directly. saveFile() would instead silently drop it in
  // the app's private storage, which isn't visible in the Files app.
  await FileSaver.instance.saveAs(
    name: fileName,
    bytes: bytes,
    ext: 'pdf',
    mimeType: MimeType.pdf,
  );
}
