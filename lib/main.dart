import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart' as di;
import 'core/di/injection_container.dart';
import 'features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'features/audio_recorder/presentation/pages/audio_recorder_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AudioListCubit>(
          create: (_) => sl<AudioListCubit>()..loadAudioRecordings(),
        ),
        BlocProvider<AudioRecordingCubit>(
          create: (_) => sl<AudioRecordingCubit>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio Recorder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioRecorderListPage(),
    );
  }
}
