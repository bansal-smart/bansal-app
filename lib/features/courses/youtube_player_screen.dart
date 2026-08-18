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
  }

  @override
  void dispose() {
    _controller.dispose();
    _setPortrait();
    super.dispose();
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
        body: _isFullScreen
            ? _buildFullScreen()
            : _buildNormal(),
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
            showVideoProgressIndicator: true,
            progressIndicatorColor: const Color(0xFF193F8F),
            progressColors: const ProgressBarColors(
              playedColor: Color(0xFF193F8F),
              handleColor: Color(0xFF193F8F),
              bufferedColor: Color(0xFFFFD5B0),
              backgroundColor: Colors.black26,
            ),
            topActions: const [SizedBox.shrink()],
            bottomActions: [
              const CurrentPosition(),
              const ProgressBar(isExpanded: true),
              const RemainingDuration(),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit_rounded,
                    color: Colors.white, size: 24),
                onPressed: _exitFullScreen,
              ),
            ],
          ),
        ),
        // Exit button top-left (backup)
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
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
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF193F8F),
                  progressColors: const ProgressBarColors(
                    playedColor: Color(0xFF193F8F),
                    handleColor: Color(0xFF193F8F),
                    bufferedColor: Color(0xFFFFD5B0),
                    backgroundColor: Colors.black26,
                  ),
                  topActions: const [SizedBox.shrink()],
                  bottomActions: [
                    const CurrentPosition(),
                    const ProgressBar(isExpanded: true),
                    const RemainingDuration(),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 24),
                      onPressed: _enterFullScreen,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
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
            ),
            // Player
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF193F8F),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFF193F8F),
                handleColor: Color(0xFF193F8F),
                bufferedColor: Color(0xFFFFD5B0),
                backgroundColor: Colors.black26,
              ),
              topActions: const [SizedBox.shrink()],
              bottomActions: [
                const CurrentPosition(),
                const ProgressBar(isExpanded: true),
                const RemainingDuration(),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 24),
                  onPressed: _enterFullScreen,
                ),
              ],
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
                            Icon(Icons.fullscreen_rounded,
                                color: Color(0xFF193F8F), size: 18),
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
