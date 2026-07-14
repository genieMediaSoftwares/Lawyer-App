import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/app_colors.dart';

class PremiumAudioPlayer extends StatefulWidget {
  final String source; // local file path or remote URL
  final VoidCallback? onDelete; // if provided, shows a delete button
  final VoidCallback? onReRecord; // if provided, shows a re-record button

  const PremiumAudioPlayer({
    super.key,
    required this.source,
    this.onDelete,
    this.onReRecord,
  });

  @override
  State<PremiumAudioPlayer> createState() => _PremiumAudioPlayerState();
}

class _PremiumAudioPlayerState extends State<PremiumAudioPlayer> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  static const List<double> _barHeights = [
    10, 18, 28, 14, 18, 36, 32, 16, 12, 24, 
    40, 26, 14, 20, 34, 38, 24, 18, 10, 22, 
    30, 36, 20, 14, 26, 32, 20, 16, 12, 8
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Listen to duration updates
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });

    // Listen to position updates
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });

    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _setSource();
  }

  Future<void> _setSource() async {
    try {
      if (widget.source.startsWith('http://') || widget.source.startsWith('https://')) {
        await _audioPlayer.setSource(UrlSource(widget.source));
      } else {
        await _audioPlayer.setSource(DeviceFileSource(widget.source));
      }
    } catch (e) {
      debugPrint("Error setting audio source: $e");
    }
  }

  @override
  void didUpdateWidget(covariant PremiumAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _setSource();
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Error toggling playback: $e");
    }
  }

  void _handleSeek(Offset localPosition, double width) {
    if (_duration.inMilliseconds == 0) return;
    final double fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    final int milliseconds = (fraction * _duration.inMilliseconds).toInt();
    _audioPlayer.seek(Duration(milliseconds: milliseconds));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.primary;

    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          // Play / Pause Button
          IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: goldColor,
              size: 32,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),

          // Custom Waveform
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  onTapDown: (details) => _handleSeek(details.localPosition, width),
                  onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition, width),
                  child: Container(
                    color: Colors.transparent, // Capture taps on empty spaces too
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_barHeights.length, (index) {
                        final double barHeight = _barHeights[index];
                        final double activeThreshold = index / _barHeights.length;
                        final bool isActive = progress >= activeThreshold;

                        return Container(
                          width: 3.5,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isActive ? goldColor : AppColors.mutedText.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),

          // Duration Tracker
          Text(
            "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: theme.textTheme.bodySmall?.fontSize ?? 11,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Re-record Button
          if (widget.onReRecord != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: widget.onReRecord,
              icon: Icon(
                Icons.refresh_rounded,
                color: goldColor,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],

          // Delete Button
          if (widget.onDelete != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
