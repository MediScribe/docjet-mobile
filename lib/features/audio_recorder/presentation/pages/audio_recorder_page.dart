import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';

class AudioRecorderPage extends StatelessWidget {
  final AudioRecordState? appendTo;

  const AudioRecorderPage({super.key, this.appendTo});

  @override
  Widget build(BuildContext context) {
    context.read<AudioRecorderCubit>().checkPermission();
    return AudioRecorderView(appendTo: appendTo);
  }
}

class AudioRecorderView extends StatefulWidget {
  final AudioRecordState? appendTo;

  const AudioRecorderView({super.key, this.appendTo});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  bool _isNavigating = false;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _handleNavigation(BuildContext context) {
    if (!_isNavigating) {
      _isNavigating = true;

      // Force refresh the recordings list
      final cubit = context.read<AudioRecorderCubit>();
      cubit.loadRecordings();

      // Return true to indicate success
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        _handleNavigation(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.appendTo != null ? 'Append Recording' : 'Record Audio',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleNavigation(context),
          ),
        ),
        body: BlocConsumer<AudioRecorderCubit, AudioRecorderState>(
          listener: (context, state) {
            if (state is AudioRecorderError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is AudioRecorderPermissionDenied) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Microphone permission is required to record audio',
                  ),
                ),
              );
              _handleNavigation(context);
            } else if (state is AudioRecorderStopped) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _handleNavigation(context);
                }
              });
            }
          },
          builder: (context, state) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.appendTo != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Appending to recording from ${widget.appendTo!.createdAt.toString()}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  if (state is AudioRecorderRecording ||
                      state is AudioRecorderPaused)
                    Text(
                      _formatDuration(
                        state is AudioRecorderRecording
                            ? state.duration
                            : (state as AudioRecorderPaused).duration,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRecordButton(context, state),
                      if (state is AudioRecorderRecording ||
                          state is AudioRecorderPaused) ...[
                        const SizedBox(width: 16),
                        _buildPauseResumeButton(context, state),
                      ],
                    ],
                  ),
                  if (state is AudioRecorderStopped) ...[
                    const SizedBox(height: 32),
                    AudioPlayerWidget(
                      filePath: state.record.filePath,
                      onDelete: () {
                        context.read<AudioRecorderCubit>().deleteRecording(
                          state.record.filePath,
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordButton(BuildContext context, AudioRecorderState state) {
    final isRecording = state is AudioRecorderRecording;
    final isPaused = state is AudioRecorderPaused;

    return FloatingActionButton(
      heroTag: 'record_fab',
      onPressed: () {
        if (isRecording || isPaused) {
          context.read<AudioRecorderCubit>().stopRecording();
        } else {
          context.read<AudioRecorderCubit>().startRecording(
            appendTo: widget.appendTo,
          );
        }
      },
      backgroundColor: isRecording || isPaused ? Colors.red : null,
      child: Icon(isRecording || isPaused ? Icons.stop : Icons.mic),
    );
  }

  Widget _buildPauseResumeButton(
    BuildContext context,
    AudioRecorderState state,
  ) {
    final isRecording = state is AudioRecorderRecording;

    return FloatingActionButton(
      heroTag: 'pause_resume_fab',
      onPressed: () {
        if (isRecording) {
          context.read<AudioRecorderCubit>().pauseRecording();
        } else {
          context.read<AudioRecorderCubit>().resumeRecording();
        }
      },
      child: Icon(isRecording ? Icons.pause : Icons.play_arrow),
    );
  }
}
