import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const YoutubePlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  bool _loadingQualities = false;
  List<String> _qualities = const [];
  String _selectedQuality = 'auto';

  static const _qualityLabels = <String, String>{
    'highres': 'Best available',
    'hd2160': '2160p',
    'hd1440': '1440p',
    'hd1080': '1080p',
    'hd720': '720p',
    'large': '480p',
    'medium': '360p',
    'small': '240p',
    'tiny': '144p',
    'auto': 'Auto',
  };

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl) ?? '';
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
    _controller.addListener(_loadQualitiesWhenPlaying);
  }

  @override
  void dispose() {
    _controller.removeListener(_loadQualitiesWhenPlaying);
    _controller.dispose();
    _setPortrait();
    super.dispose();
  }

  void _loadQualitiesWhenPlaying() {
    if (_controller.value.isReady &&
        _controller.value.isPlaying &&
        _qualities.isEmpty &&
        !_loadingQualities) {
      _loadAvailableQualities();
    }
  }

  Future<void> _loadAvailableQualities() async {
    final webView = _controller.value.webViewController;
    if (webView == null || _loadingQualities) return;
    _loadingQualities = true;
    try {
      final raw = await webView.evaluateJavascript(
        source: 'player.getAvailableQualityLevels()',
      );
      final dynamic decoded = raw is String && raw.startsWith('[')
          ? jsonDecode(raw)
          : raw;
      final levels = decoded is List
          ? decoded.whereType<String>().toList()
          : <String>[];
      if (mounted && levels.isNotEmpty) {
        setState(() => _qualities = levels);
      }
    } catch (_) {
      // YouTube may not report levels until playback has buffered enough.
    } finally {
      _loadingQualities = false;
    }
  }

  void _seekBy(int seconds) {
    final duration = _controller.metadata.duration;
    final current = _controller.value.position;
    final targetSeconds = (current.inSeconds + seconds).clamp(
      0,
      duration.inSeconds,
    );
    _controller.seekTo(Duration(seconds: targetSeconds));
  }

  Future<void> _changeQuality(String quality) async {
    final webView = _controller.value.webViewController;
    if (webView == null) return;
    await webView.evaluateJavascript(
      source: 'player.setPlaybackQuality(${jsonEncode(quality)})',
    );
    if (mounted) setState(() => _selectedQuality = quality);
  }

  List<Widget> _playerActions({
    required VoidCallback onFullScreen,
    required bool isFullScreen,
  }) {
    final qualityItems = ['auto', ..._qualities.where((q) => q != 'auto')];
    return [
      PlayPauseButton(controller: _controller),
      _SeekButton(
        icon: Icons.replay_10_rounded,
        tooltip: 'Back 10 seconds',
        onPressed: () => _seekBy(-10),
      ),
      _SeekButton(
        icon: Icons.forward_10_rounded,
        tooltip: 'Forward 10 seconds',
        onPressed: () => _seekBy(10),
      ),
      const ProgressBar(isExpanded: true),
      const RemainingDuration(),
      PlaybackSpeedButton(
        controller: _controller,
        icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 21),
      ),
      PopupMenuButton<String>(
        tooltip: 'Video quality',
        onSelected: _changeQuality,
        initialValue: _selectedQuality,
        itemBuilder: (context) => qualityItems
            .map(
              (quality) => CheckedPopupMenuItem<String>(
                value: quality,
                checked: quality == _selectedQuality,
                child: Text(_qualityLabels[quality] ?? quality),
              ),
            )
            .toList(),
        icon: const Icon(Icons.hd_rounded, color: Colors.white, size: 22),
      ),
      IconButton(
        tooltip: isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
        icon: Icon(
          isFullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
          size: 24,
        ),
        onPressed: onFullScreen,
      ),
    ];
  }

  void _setPortrait() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _enterFullScreen() {
    setState(() => _isFullScreen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setLandscape());
  }

  void _exitFullScreen() {
    _setPortrait();
    // Wait for orientation to settle before updating layout
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isFullScreen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullScreen) _exitFullScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isFullScreen ? _buildFullScreen() : _buildNormal(),
      ),
    );
  }

  // ── Fullscreen — player fills entire rotated screen ──────────────────────
  Widget _buildFullScreen() {
    return Stack(
      children: [
        // Player fills the whole screen
        Positioned.fill(
          child: YoutubePlayer(
            controller: _controller,
            onReady: _loadAvailableQualities,
            showVideoProgressIndicator: true,
            progressIndicatorColor: const Color(0xFF193F8F),
            progressColors: const ProgressBarColors(
              playedColor: Color(0xFF193F8F),
              handleColor: Color(0xFF193F8F),
              bufferedColor: Color(0xFFFFD5B0),
              backgroundColor: Colors.black26,
            ),
            topActions: const [SizedBox.shrink()],
            bottomActions: _playerActions(
              onFullScreen: _exitFullScreen,
              isFullScreen: true,
            ),
          ),
        ),
        // Exit button top-left (backup)
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 4,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _exitFullScreen,
          ),
        ),
      ],
    );
  }

  // ── Normal portrait layout ────────────────────────────────────────────────
  Widget _buildNormal() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        if (isLandscape) {
          // In landscape without fullscreen: player fills width, no info panel
          return Stack(
            children: [
              Positioned.fill(
                child: YoutubePlayer(
                  controller: _controller,
                  onReady: _loadAvailableQualities,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF193F8F),
                  progressColors: const ProgressBarColors(
                    playedColor: Color(0xFF193F8F),
                    handleColor: Color(0xFF193F8F),
                    bufferedColor: Color(0xFFFFD5B0),
                    backgroundColor: Colors.black26,
                  ),
                  topActions: const [SizedBox.shrink()],
                  bottomActions: _playerActions(
                    onFullScreen: _enterFullScreen,
                    isFullScreen: false,
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          );
        }

        // Portrait layout
        return Column(
          children: [
            // AppBar row
            SafeArea(
              bottom: false,
              child: Container(
                color: Colors.black,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
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
            ),
            // Player
            YoutubePlayer(
              controller: _controller,
              onReady: _loadAvailableQualities,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF193F8F),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFF193F8F),
                handleColor: Color(0xFF193F8F),
                bufferedColor: Color(0xFFFFD5B0),
                backgroundColor: Colors.black26,
              ),
              topActions: const [SizedBox.shrink()],
              bottomActions: _playerActions(
                onFullScreen: _enterFullScreen,
                isFullScreen: false,
              ),
            ),
            // Info panel
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF1E293B)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _enterFullScreen,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              color: Color(0xFF193F8F),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tap to watch in fullscreen',
                              style: TextStyle(
                                color: Color(0xFF193F8F),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SeekButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
    icon: Icon(icon, color: Colors.white, size: 21),
    onPressed: onPressed,
  );
}
