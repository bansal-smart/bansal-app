import 'dart:math' as math;
import 'package:flutter/material.dart';

// Google brand colours
const _kBlue = Color(0xFF4285F4);
const _kRed = Color(0xFFEA4335);
const _kYellow = Color(0xFFFBBC05);
const _kGreen = Color(0xFF34A853);

/// Shows a bottom sheet styled like Google's account-chooser.
/// Returns the trimmed email the user entered, or null if dismissed.
Future<String?> showGoogleEmailSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GoogleEmailSheet(),
  );
}

class _GoogleEmailSheet extends StatefulWidget {
  const _GoogleEmailSheet();

  @override
  State<_GoogleEmailSheet> createState() => _GoogleEmailSheetState();
}

class _GoogleEmailSheetState extends State<_GoogleEmailSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _ctrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Google "G" logo ──
            SizedBox(
              width: 40,
              height: 40,
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            const SizedBox(height: 16),

            // ── Title ──
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202124),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your Gmail address to continue',
              style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Email field ──
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF202124),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Email address',
                hintText: 'you@gmail.com',
                labelStyle: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 14,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFFBDC1C6),
                  fontSize: 14,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 20,
                    color: Color(0xFF5F6368),
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                errorText: _error,
                errorStyle: const TextStyle(
                  color: Color(0xFFEA4335),
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFDADCE0),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBlue, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kRed, width: 1.2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kRed, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Buttons row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5F6368),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

// ── Google "G" logo painter ──
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16;

    final colors = [_kBlue, _kRed, _kYellow, _kGreen];
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - paint.strokeWidth / 2),
        (math.pi / 2) * i - math.pi / 2,
        math.pi / 2 - 0.08,
        false,
        paint,
      );
    }
    final barPaint = Paint()
      ..color = _kBlue
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - size.width * 0.08, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
