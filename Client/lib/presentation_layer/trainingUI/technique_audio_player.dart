import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class TechniqueAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const TechniqueAudioPlayer({super.key, required this.audioUrl});

  @override
  State<TechniqueAudioPlayer> createState() => _TechniqueAudioPlayerState();
}

class _TechniqueAudioPlayerState extends State<TechniqueAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _isLoading = true;
  String? _error;

  static const Color primary = Color(0xFF1F5F5A);
  static const Color background = Color(0xFFEAF4F1);

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _player.setUrl(widget.audioUrl);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر تحميل المثال الصوتي';
      });
    }
  }

  @override
  void didUpdateWidget(covariant TechniqueAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audioUrl != widget.audioUrl) {
      _player.stop();
      setState(() {
        _isLoading = true;
        _error = null;
      });
      _loadAudio();
    }
  }

  Future<void> _togglePlayback(PlayerState? state) async {
    try {
      if (state?.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.play();
      } else if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تشغيل المثال الصوتي';
      });
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, stateSnapshot) {
          final playerState = stateSnapshot.data;
          final isPlaying = playerState?.playing ?? false;
          final isCompleted =
              playerState?.processingState == ProcessingState.completed;

          final isBuffering =
              playerState?.processingState == ProcessingState.buffering ||
              playerState?.processingState == ProcessingState.loading;

          final duration = _player.duration ?? Duration.zero;
          final totalMs = duration.inMilliseconds;

          return StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;

              final currentMs = position.inMilliseconds.clamp(
                0,
                totalMs > 0 ? totalMs : 1,
              );

              return Row(
                children: [
                  IconButton(
                    onPressed: _isLoading || isBuffering
                        ? null
                        : () => _togglePlayback(playerState),
                    icon: _isLoading || isBuffering
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primary,
                            ),
                          )
                        : Transform.flip(
                            flipX: false,
                            child: Icon(
                              isPlaying && !isCompleted
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              size: 36,
                              color: primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'استمع لطريقة النطق',
                          style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: primary,
                            inactiveTrackColor: const Color(0xFFC4DCD6),
                            thumbColor: primary,
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: currentMs.toDouble(),
                            min: 0,
                            max: totalMs > 0 ? totalMs.toDouble() : 1,
                            onChanged: totalMs > 0
                                ? (value) {
                                    _player.seek(
                                      Duration(milliseconds: value.round()),
                                    );
                                  }
                                : null,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatTime(position)),
                            Text(_formatTime(duration)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.volume_up_outlined,
                    color: primary,
                    size: 21,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
