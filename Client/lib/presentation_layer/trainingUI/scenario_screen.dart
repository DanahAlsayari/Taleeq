
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:client/models/scenario_model.dart';

class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({
    super.key,
    required this.attemptId,
    required this.scenario,
  });

  final String attemptId;
  final ScenarioModel scenario;

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  late final VideoPlayerController _videoController;

  bool _conversationShouldStart = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.scenario.videoUrl),
    )..initialize().then((_) {
        if (!mounted) return;

        setState(() {});
        _videoController.play();
      });

    _videoController.addListener(_checkConversationStart);
  }

  void _checkConversationStart() {
    if (_conversationShouldStart ||
        !_videoController.value.isInitialized) {
      return;
    }

    final currentSeconds =
        _videoController.value.position.inSeconds;

    if (currentSeconds >=
        widget.scenario.conversationStartTime) {
      _conversationShouldStart = true;
      _videoController.pause();

      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_checkConversationStart);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      body: SafeArea(
        child: Column(
          children: [
            // Scenario Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              color: const Color(0xFFF7F3EA),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.scenario.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),

            // Scenario Video
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _videoController.value.isInitialized
                    ? VideoPlayer(_videoController)
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
