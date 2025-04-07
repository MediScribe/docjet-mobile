// Base file to generate mocks for audio playback service tests
import 'package:audioplayers/audioplayers.dart';
import 'package:mockito/annotations.dart';

// This annotation generates MockAudioPlayer which is used by other test files
@GenerateMocks([AudioPlayer])
void main() {
  // This file exists primarily to generate mocks, no tests are needed here
}
