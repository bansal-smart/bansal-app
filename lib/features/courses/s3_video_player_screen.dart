import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/services/s3_http_client.dart';

class S3VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const S3VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<S3VideoPlayerScreen> createState() => _S3VideoPlayerScreenState();
}

class _S3VideoPlayerScreenState extends State<S3VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  String? _error;

  // true only while we're fetching the signed URL (usually < 1s)
  bool _signing = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    setState(() {
      _signing = true;
      _error = null;
      _chewieCtrl = null;
      _videoCtrl = null;
    });

    try {
      // ── Step 1: get presigned URL (fast edge-function call ~100–300 ms) ──
      String streamUrl = widget.videoUrl;
      if (isS3Url(widget.videoUrl)) {
        streamUrl = await getS3SignedUrl(widget.videoUrl);
      }

      // ── Step 2: create controller and hand to Chewie BEFORE initialize() ─
      // Chewie shows its own buffering indicator while initialize() runs,
      // so the user sees the player shell instantly rather than a blank screen.
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {
          'Accept': 'video/mp4,video/*,*/*',
        },
      );

      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        // Chewie shows its own spinner while the controller is not yet initialized
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF193F8F),
          handleColor: const Color(0xFF193F8F),
          bufferedColor: const Color(0xFFFFD5B0),
          backgroundColor: Colors.white24,
        ),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        errorBuilder: (ctx, msg) => _ErrorPanel(
          message: msg,
          onRetry: _initPlayer,
        ),
      );

      if (!mounted) {
        chewie.dispose();
        ctrl.dispose();
        return;
      }

      // Show the player shell immediately — Chewie handles the buffering state
      setState(() {
        _videoCtrl = ctrl;
        _chewieCtrl = chewie;
        _signing = false;
      });

      // Initialize in the background — once done, rebuild so AspectRatio
      // uses the video's real dimensions instead of the 16:9 placeholder.
      ctrl.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        if (mounted) setState(() => _error = e.toString());
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _signing = false; });
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ───────────────────────────────────────────────────
            Container(
              color: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // ── Player area — constrained to never overflow the screen ────
            LayoutBuilder(builder: (context, constraints) {
              final videoReady = _videoCtrl != null &&
                  _videoCtrl!.value.isInitialized &&
                  _videoCtrl!.value.size.width > 0;
              final ratio = videoReady
                  ? _videoCtrl!.value.aspectRatio
                  : 16 / 9;

              final screenHeight = MediaQuery.of(context).size.height;
              final maxPlayerHeight = screenHeight * 0.55;
              final naturalHeight = constraints.maxWidth / ratio;
              final playerHeight = naturalHeight.clamp(0.0, maxPlayerHeight);

              return SizedBox(
                width: constraints.maxWidth,
                height: playerHeight,
                child: _signing
                    ? _buildSigningLoader()
                    : _error != null
                        ? _ErrorPanel(message: _error!, onRetry: _initPlayer)
                        : Chewie(controller: _chewieCtrl!),
              );
            }),

            // ── Info panel ───────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSigningLoader() {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF193F8F),
              strokeWidth: 2.5,
            ),
            SizedBox(height: 14),
            Text(
              'Opening video…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable error panel (also used by Chewie's errorBuilder) ───────────────
class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Could not load video',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF193F8F)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
