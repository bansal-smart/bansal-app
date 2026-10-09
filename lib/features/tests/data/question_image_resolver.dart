import '../../../core/services/supabase_service.dart';

// ─────────────────────────────────────────────
// QUESTION-IMAGES URL RESOLVER
// Signed URLs embedded in question_text/options can go stale (re-signed
// against a different project, or simply expired). Re-mint a fresh signed
// URL from the storage path before rendering, same pattern as
// pdf_viewer_screen.dart's _resolveUrl for course-resources.
// ─────────────────────────────────────────────
const questionImagesBucket = 'question-images';

Future<String> resolveQuestionImageUrl(String url) async {
  final markers = [
    '/storage/v1/object/public/$questionImagesBucket/',
    '/storage/v1/object/sign/$questionImagesBucket/',
  ];
  for (final m in markers) {
    final idx = url.indexOf(m);
    if (idx != -1) {
      final path = Uri.decodeComponent(
        url.substring(idx + m.length).split('?').first,
      );
      try {
        return await SupabaseService.client.storage
            .from(questionImagesBucket)
            .createSignedUrl(path, 3600);
      } catch (_) {
        return url; // fall back to the original URL if re-signing fails
      }
    }
  }
  return url;
}

/// Extracts every `<img src="...">` URL embedded in HTML `text`, mirroring
/// the extraction logic used when parsing question_text for the test engine.
List<String> extractImgUrls(String text) {
  final imgRegex = RegExp(
    '<img[^>]+src=["\']([^"\']+)["\']',
    caseSensitive: false,
  );
  return imgRegex.allMatches(text).map((m) => m.group(1)!).toList();
}

/// Strips `<img>` tags from HTML `text` so a plain-text renderer doesn't
/// choke on them — call after [extractImgUrls] so nothing is lost.
String stripImgTags(String text) =>
    text.replaceAll(RegExp('<img[^>]*/?>', caseSensitive: false), '');
