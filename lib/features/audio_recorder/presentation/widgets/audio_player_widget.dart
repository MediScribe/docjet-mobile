import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback onDelete;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.onDelete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Subscriptions for listeners
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    try {
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
        state,
      ) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      });

      _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
        setState(() {
          _duration = duration;
        });
      });

      _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
        setState(() {
          _position = position;
        });
      });

      // Set a longer timeout for source initialization
      await _audioPlayer
          .setSource(DeviceFileSource(widget.filePath))
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
              throw TimeoutException(
                'Failed to load audio file',
                const Duration(seconds: 60),
              );
            },
          );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      debugPrint('Error setting up audio player: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    // Cancel subscriptions before disposing the player
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return _buildPlayerControls(context);
  }

  // --- START: UI Builder Helper Methods ---

  Widget _buildLoadingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Failed to load audio',
              style: TextStyle(color: Colors.red),
            ),
            IconButton(
              onPressed: widget.onDelete, // Still allow delete on error
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () async {
                    // Capture context before the async operation
                    final capturedContext = context;
                    try {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        await _audioPlayer.play(
                          DeviceFileSource(widget.filePath),
                        );
                      }
                    } catch (e) {
                      // Check capturedContext.mounted before using it
                      if (!capturedContext.mounted) return;
                      ScaffoldMessenger.of(capturedContext).showSnackBar(
                        SnackBar(content: Text('Error playing audio: $e')),
                      );
                    }
                  },
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 32,
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble().clamp(
                      0,
                      double.infinity,
                    ),
                    value: _position.inSeconds.toDouble().clamp(
                      0,
                      _duration.inSeconds.toDouble(),
                    ),
                    onChanged: (value) async {
                      // Capture context before the async operation
                      final capturedContext = context;
                      try {
                        await _audioPlayer.seek(
                          Duration(seconds: value.toInt()),
                        );
                      } catch (e) {
                        // Check capturedContext.mounted before using it
                        if (!capturedContext.mounted) return;
                        ScaffoldMessenger.of(capturedContext).showSnackBar(
                          SnackBar(content: Text('Error seeking audio: $e')),
                        );
                      }
                    },
                  ),
                ),
                Text(_formatDuration(_position)),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- END: UI Builder Helper Methods ---
}
