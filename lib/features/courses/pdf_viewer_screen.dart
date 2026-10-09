import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/services/s3_http_client.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String fileUrl;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.fileUrl,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  String? _resolvedUrl;
  String? _error;
  bool _loading = true;
  bool _downloading = false;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  /// Returns a directly-downloadable URL for the PDF.
  /// - S3 / external https URLs: use as-is.
  /// - Supabase storage paths: generate a signed URL.
  /// Resolves the raw fileUrl to a directly downloadable URL.
  /// - S3 (megas4.com) URLs  → presigned GET via edge function
  /// - Supabase storage URLs → Supabase signed URL
  /// - Relative paths        → Supabase signed URL
  /// - Other http URLs       → used as-is
  Future<String> _resolveUrl() async {
    final url = widget.fileUrl.trim();

    // Private S3 bucket — needs a presigned GET URL
    if (isS3Url(url)) {
      return getS3SignedUrl(url);
    }

    // Supabase storage URL — create a signed URL
    const bucket = 'course-resources';
    final markers = [
      '/storage/v1/object/public/$bucket/',
      '/storage/v1/object/sign/$bucket/',
    ];
    for (final m in markers) {
      final idx = url.indexOf(m);
      if (idx != -1) {
        final path = Uri.decodeComponent(
          url.substring(idx + m.length).split('?').first,
        );
        return await Supabase.instance.client.storage
            .from(bucket)
            .createSignedUrl(path, 3600);
      }
    }

    // Relative storage path
    if (!url.startsWith('http')) {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(url, 3600);
    }

    // Any other http URL — use directly
    return url;
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolvedUrl = await _resolveUrl();
      _resolvedUrl = resolvedUrl;

      final dir = await getTemporaryDirectory();
      final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filePath = '${dir.path}/$safeName.pdf';

      // Use S3-aware Dio that bypasses the self-signed cert on megas4.com
      await buildS3Dio().download(
        resolvedUrl,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf,*/*'},
        ),
      );

      if (mounted)
        setState(() {
          _localPath = filePath;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _saveToDownloads() async {
    if (_resolvedUrl == null) return;
    setState(() => _downloading = true);
    try {
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
      final filePath = '${dir.path}/$safeName.pdf';
      await buildS3Dio().download(
        _resolvedUrl!,
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $safeName.pdf'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${_currentPage + 1}/$_totalPages',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ),
          _downloading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Save PDF',
                  onPressed: (_loading || _error != null)
                      ? null
                      : _saveToDownloads,
                ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading PDF...',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load PDF',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _prepare,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : PDFView(
              filePath: _localPath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              fitPolicy: FitPolicy.BOTH,
              onRender: (pages) {
                if (mounted) setState(() => _totalPages = pages ?? 0);
              },
              onPageChanged: (page, _) {
                if (mounted) setState(() => _currentPage = page ?? 0);
              },
              onError: (e) {
                if (mounted) setState(() => _error = e.toString());
              },
            ),
    );
  }
}
