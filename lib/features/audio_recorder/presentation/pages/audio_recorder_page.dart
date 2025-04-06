import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart'; // Import sl
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';

class AudioRecorderPage extends StatelessWidget {
  final AudioRecord? appendTo;

  const AudioRecorderPage({super.key, this.appendTo});

  @override
  Widget build(BuildContext context) {
    return AudioRecorderView(appendTo: appendTo);
  }
}

class AudioRecorderView extends StatefulWidget {
  final AudioRecord? appendTo;

  const AudioRecorderView({super.key, this.appendTo});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  bool _isNavigating = false;
  late final AudioRecorderCubit _cubit; // Declare Cubit instance

  @override
  void initState() {
    super.initState();
    _cubit = sl<AudioRecorderCubit>(); // Create new instance
    debugPrint(
      '[AudioRecorderPage] initState: Created new Cubit. Calling checkPermission...',
    );
    _cubit.checkPermission(); // Check permission for this page
  }

  @override
  void dispose() {
    debugPrint('[AudioRecorderPage] dispose: Closing cubit.');
    _cubit.close(); // Dispose the cubit
    super.dispose();
  }

  // Method to show the permission request bottom sheet
  void _showPermissionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Microphone Permission Required',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs access to your microphone to record audio. Please grant permission in the app settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  child: const Text('Open App Settings'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop(); // Close the sheet
                    _cubit.openSettings();
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _handleNavigation(BuildContext context) {
    if (!_isNavigating) {
      _isNavigating = true;

      // Return true to indicate success
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provide the local cubit instance
    return BlocProvider.value(
      value: _cubit,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            // Use the local _cubit instance
            _handleNavigation(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.appendTo != null ? 'Append Recording' : 'Record Audio',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              // Use the local _cubit instance
              onPressed: () => _handleNavigation(context),
            ),
          ),
          body: BlocConsumer<AudioRecorderCubit, AudioRecorderState>(
            listener: (context, state) {
              debugPrint(
                '[AudioRecorderPage] Listener received state: ${state.runtimeType}',
              );
              if (state is AudioRecorderError) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              } else if (state is AudioRecorderPermissionDenied) {
                // === MODIFICATION START ===
                // // Temporarily show a simple SnackBar instead of the sheet
                // print(
                //   '[AudioRecorderPage] Received AudioRecorderPermissionDenied. Showing SnackBar.',
                // );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(
                //     content: Text('Microphone Permission Permanently Denied.'),
                //     duration: Duration(seconds: 5),
                //   ),
                // );
                // === ORIGINAL CODE REINSTATED ===
                // Show the bottom sheet instead of just a snackbar
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // print('[AudioRecorderPage] PostFrameCallback: Showing permission sheet.'); // Optional: Keep print for debug if needed
                  if (mounted) {
                    // Ensure widget is still in the tree
                    _showPermissionSheet(context);
                  }
                });
                // === MODIFICATION END ===
              } else if (state is AudioRecorderStopped) {
                // --- MODIFICATION START ---
                debugPrint(
                  '[AudioRecorderPage] Received AudioRecorderStopped. Navigating back.',
                );
                // No need for delay, just navigate back immediately
                // Ensure we don't double-navigate
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _handleNavigation(context);
                  }
                });
                // --- MODIFICATION END ---
              }
            },
            builder: (context, state) {
              debugPrint(
                '[AudioRecorderPage] Builder received state: ${state.runtimeType}',
              );
              // Main content area widget determination
              Widget mainContent;
              if (state is AudioRecorderInitial ||
                  state is AudioRecorderLoading) {
                mainContent = _buildLoadingUI();
              } else if (state is AudioRecorderReady) {
                mainContent = _buildReadyUI(context, state);
              } else if (state is AudioRecorderRecording ||
                  state is AudioRecorderPaused) {
                mainContent = _buildRecordingPausedUI(context, state);
              } else if (state is AudioRecorderStopped) {
                // --- MODIFICATION START ---
                // mainContent = _buildStoppedUI(context, state); // REMOVED CALL
                // Instead, show loading briefly while navigating back
                debugPrint(
                  '[AudioRecorderPage] Builder received AudioRecorderStopped. Showing loading.',
                );
                mainContent =
                    _buildLoadingUI(); // Show loading indicator briefly
                // The listener will handle navigation
                // --- MODIFICATION END ---
              } else {
                // Fallback for any unexpected state (e.g., permission denied handled by listener, Error state shows SnackBar)
                debugPrint(
                  '[AudioRecorderPage] Builder received unhandled state: ${state.runtimeType}. Showing empty box.',
                );
                mainContent = const SizedBox.shrink(); // Or some placeholder
              }

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
                    const SizedBox(height: 16), // Consistent spacing
                    // --- Main Content Area based on State ---
                    mainContent, // Use the determined widget
                    // Note: AudioRecorderPermissionDenied is handled by the bottom sheet listener
                  ],
                ),
              );
            },
          ),
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
          _cubit.stopRecording();
        } else {
          _cubit.startRecording(appendTo: widget.appendTo);
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
    // Handles both Recording and Paused states
    final isRecording = state is AudioRecorderRecording;

    return FloatingActionButton(
      heroTag: 'pause_resume_fab',
      onPressed: () {
        if (isRecording) {
          _cubit.pauseRecording();
        } else {
          _cubit.resumeRecording();
        }
      },
      child: Icon(isRecording ? Icons.pause : Icons.play_arrow),
    );
  }

  // --- START: New UI Builder Methods ---

  Widget _buildLoadingUI() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Processing...'), // More generic message
      ],
    );
  }

  Widget _buildReadyUI(BuildContext context, AudioRecorderReady state) {
    return _buildRecordButton(context, state); // Just the record button
  }

  Widget _buildRecordingPausedUI(
    BuildContext context,
    AudioRecorderState state, // Accept base state
  ) {
    Duration currentDuration = Duration.zero;
    String? currentPath;

    if (state is AudioRecorderRecording) {
      currentDuration = state.duration;
      currentPath = state.filePath;
    } else if (state is AudioRecorderPaused) {
      currentDuration = state.duration;
      currentPath = state.filePath;
    }

    // Basic null check for safety, though path should exist in these states
    final displayPath = currentPath?.split('/').last ?? 'Recording...';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatDuration(currentDuration),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          displayPath,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRecordButton(context, state), // Stop button
            const SizedBox(width: 24),
            _buildPauseResumeButton(context, state), // Pause/Resume
          ],
        ),
      ],
    );
  }

  // --- END: New UI Builder Methods ---
}
