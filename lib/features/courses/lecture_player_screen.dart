import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/colors.dart';
import '../../data/mock_data.dart';

class LecturePlayerScreen extends StatefulWidget {
  final String lectureId;
  const LecturePlayerScreen({super.key, required this.lectureId});
  @override
  State<LecturePlayerScreen> createState() => _LecturePlayerScreenState();
}

class _LecturePlayerScreenState extends State<LecturePlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  late final MockLecture _lecture;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lecture = MockData.lectures.firstWhere(
      (l) => l.id == widget.lectureId,
      orElse: () => MockData.lectures.first,
    );
    _init();
  }

  Future<void> _init() async {
    try {
      _video = VideoPlayerController.networkUrl(Uri.parse(_lecture.videoUrl));
      await _video!.initialize();
      _chewie = ChewieController(
        videoPlayerController: _video!,
        autoPlay: false,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: AppColors.border,
          backgroundColor: Colors.black26,
        ),
      );
      setState(() => _ready = true);
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lecture.title, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : _ready && _chewie != null
                  ? Chewie(controller: _chewie!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.muted,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Chapters'),
                      Tab(text: 'Notes'),
                      Tab(text: 'Doubts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            for (final l in MockData.lectures)
                              ListTile(
                                leading: Icon(
                                  l.id == _lecture.id
                                      ? Icons.play_circle
                                      : Icons.play_circle_outline,
                                  color: l.id == _lecture.id
                                      ? AppColors.primary
                                      : AppColors.muted,
                                ),
                                title: Text(l.title),
                                subtitle: Text('${l.durationMin} min'),
                              ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Your notes will appear here.'),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Ask a doubt — AI solver coming soon.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked complete'))),
        icon: const Icon(Icons.check),
        label: const Text('Mark complete'),
      ),
    );
  }
}
