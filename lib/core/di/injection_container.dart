import 'package:get_it/get_it.dart';
import '../../features/audio_recorder/presentation/cubit/audio_recorder_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Cubits
  sl.registerFactory(() => AudioRecorderCubit());
}
