Concatenating Multiple Audio Files in Flutter (iOS & Android)

Using FFmpegKit for Robust Audio Concatenation

One of the most reliable solutions is to use FFmpeg via the FFmpegKit Flutter plugin. FFmpeg is a battle-tested media tool that can concatenate audio files with ease. The Flutter plugin bundles FFmpeg binaries and exposes a Dart API. We recommend the ffmpeg_kit_flutter_audio package variant, which includes audio codecs (AAC, MP3, etc.) under LGPL license (no GPL components) ￼ ￼. This means it can be used in closed-source apps (LGPL allows commercial use without open-sourcing your code). FFmpegKit runs the processing in the background, so it won’t block the UI thread.

Maintenance and licensing: FFmpegKit was actively maintained up to version 6.0.3 but was officially retired in Jan 2025 ￼. The last release is stable, and you can still use it (the plugin is LGPL-3.0 licensed). Just be aware there may be no further updates, though its FFmpeg core is mature for audio tasks.

Concatenating with FFmpeg: FFmpeg supports two approaches to concat audio: (1) re-encode and join via the concat filter, or (2) stream copy via the concat demuxer (which avoids re-encoding if files have identical format). The concat filter method is straightforward and works even if formats differ (FFmpeg will re-encode the output). For example, to join two audio files:

ffmpeg -i audio1.mp3 -i audio2.mp3 -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" output.mp3

This FFmpeg command uses the concat filter to merge two audio streams ￼. In Flutter, you can run the same command with FFmpegKit. Alternatively, if your recordings share the exact same codec/format (likely true for on-device recordings), you can use the concat demuxer for a lossless join: create a text file listing the files and run -f concat -safe 0 -i list.txt -c copy output.m4a ￼. The -c copy option copies audio frames without re-encoding, making it very fast and preserving quality. This method is strict about files having matching codecs/sample rates ￼.

FFmpegKit Example – Concatenating two files: Below is a Dart snippet using ffmpeg_kit_flutter_audio to concatenate two .m4a files. It uses FFmpeg’s concat filter for generality (re-encoding the output to AAC):

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit_flutter_audio.dart';

Future<void> concatTwoAudioFiles(String filePath1, String filePath2, String outputPath) async {
  // FFmpeg command to concat two audio files
  final cmd = [
    '-i', filePath1,
    '-i', filePath2,
    '-filter_complex', '[0:a][1:a]concat=n=2:v=0:a=1[out]',
    '-map', '[out]',
    '-c:a', 'aac', '-b:a', '192k', // encode output with AAC at 192kbps
    outputPath
  ].join(' ');
  
  FFmpegSession session = await FFmpegKit.executeAsync(cmd);
  final returnCode = await session.getReturnCode();
  if (ReturnCode.isSuccess(returnCode)) {
    print('Audio files concatenated successfully.');
  } else {
    print('FFmpeg concat failed with code $returnCode');
  }
}

In this code, FFmpegKit.executeAsync runs the command asynchronously. You would call concatTwoAudioFiles(file1.path, file2.path, combined.path) and then play the combined.m4a output. (If all source files are guaranteed AAC/.m4a with same format, you could instead build a concat list and use -c copy for better performance.) The output file will be playable immediately after this operation completes.

Setup instructions: To integrate FFmpegKit, add the plugin to your pubspec with the desired variant. For example, in pubspec.yaml:

dependencies:
  ffmpeg_kit_flutter_audio: ^6.0.3  # audio-only FFmpegKit (LGPL)

Then run flutter pub get. The plugin bundles the native FFmpeg binaries for iOS and Android, so no additional platform setup is needed. Ensure you import the correct package name (e.g. ffmpeg_kit_flutter_audio as shown). Also, remember to include the FFmpegKit LGPL license in your app’s notices (as required by LGPL). Other than that, no special permissions beyond file read/write (already handled) are required – the heavy lifting is done in native code.

Why FFmpegKit? It provides a robust, cross-platform solution with one unified Dart API. FFmpeg is very reliable at handling various audio codecs and file quirks (it will handle codec/format differences gracefully by re-encoding if needed) ￼. Performance is good – written in C/C++, it can concatenate audio faster than real-time in most cases. The operation runs off the UI thread (FFmpegKit uses background threads), satisfying the performance requirement. And by using the well-maintained (albeit now LTS) plugin, you avoid writing and debugging custom platform code, which improves maintainability of your project. The ffmpeg_kit_flutter_audio package is under LGPL, which is a permissive license compatible with App Store/Play Store distribution (unlike GPL, which would require you to open source your app) ￼. Overall, FFmpegKit hits a good balance of reliability and ease-of-use.

Note: As FFmpegKit is no longer receiving updates ￼, keep an eye on its GitHub for any community forks or fixes. Version 6.0.3 is stable, but future OS updates could require tweaks. In practice, for audio concatenation (a basic feature), it should remain functional for the foreseeable future.

Alternative Flutter Packages (File-Based Merging)

If you prefer not to use a full FFmpeg wrapper, there are smaller plugins that focus on audio editing. Two notable ones are sound_edit and audio_kit:
	•	sound_edit – A plugin that lets you combine audio files regardless of extension and even trim audio ￼. It is implemented with platform code (using Swift, Kotlin, C++ under the hood) and licensed under BSD-3-Clause ￼. This package was last updated in 2023 and supports Android, iOS, and even web. It provides a high-level API to merge clips (and possibly adjust playback speed). While the license is permissive and it avoids you writing FFmpeg commands, be aware it’s a relatively obscure plugin (low download count) – so maintenance and community support are limited.
	•	audio_kit – A newer plugin (MIT licensed) that supports audio trimming, merging, and mixing ￼ ￼. Internally, it actually uses FFmpeg as well (according to its description) to perform the operations. So it’s somewhat a lighter wrapper around FFmpeg functionality. Like sound_edit, this plugin isn’t widely used or actively developed (as of now). It might save you from writing FFmpeg commands directly, but you inherit the dependency on FFmpeg binaries (and its large size) without the reassurance of a large community.

In summary, these Flutter-first plugins exist and can handle the task with a few function calls. However, robustness might be a concern – since they are not as battle-tested, you’d want to thoroughly test with your audio formats. They also likely perform the work on background threads (using native code), so performance should be fine. But given their limited adoption, maintainability is a question mark (you might need to dive into their source if something goes wrong). If you choose one, review its issue tracker for any known bugs around audio formats.

Native Platform APIs via Platform Channels

If no plugin meets your needs, you can implement audio concatenation natively on each platform using platform channels. Both iOS and Android provide media APIs to concatenate tracks, though the implementations differ in complexity:
	•	iOS (AVFoundation): Apple’s AVFoundation framework makes this fairly straightforward. You can use AVMutableComposition to build a single audio track from multiple source files, then export it with AVAssetExportSession. For example, you would create an AVMutableCompositionTrack for audio, then for each input file:
	1.	Load the file into an AVURLAsset and retrieve its audio track.
	2.	Append the track into your composition at the end of the previous segment (using insertTimeRange) ￼.
	3.	After adding all segments, initialize an AVAssetExportSession with the composition. Use an output file type like M4A (AAC) and possibly AVAssetExportPresetPassthrough as the preset.
	4.	Call exportAsynchronously to write out the combined file in the background, then handle the completion callback.
This approach is robust and uses the device’s native encoders/decoders. If the source files are already in an AAC/M4A format, AVFoundation can often “passthrough” or at least avoid recompression. (In practice, using the Passthrough preset for audio compositions will attempt to not re-encode if possible.) Even if it does re-encode, it will use Apple’s optimized AAC encoder. The result is an .m4a file that is immediately playable. Error handling (e.g. file not found or codec issues) can be managed via the export session status and error properties. Maintainability is good long-term – AVFoundation is well-documented and stable. The downside is you need to write Objective-C/Swift code in a plugin or method channel, which adds to your codebase.
	•	Android (MediaMuxer/MediaCodec): On Android, you have a couple of options:
	•	If all audio files are recorded with the exact same format (e.g., all are AAC in an MP4/M4A container with the same sampling rate and channels), you can concatenate them at the MP4 container level using MediaMuxer. The idea is to use MediaExtractor to read the AAC frames from each source file and write them sequentially to a new output file via MediaMuxer. You would:
	1.	Initialize a MediaMuxer to create a new MP4/M4A file.
	2.	For the first input file, use MediaExtractor to get the audio track format and add that track to the MediaMuxer (muxer.addTrack(format)). Start the muxer.
	3.	Loop through the samples of the first file (Extractor readSampleData), write them to the muxer via writeSampleData. Keep track of the presentation time of the last sample.
	4.	For the second file, repeat reading its samples, but offset the timestamps by the duration of the first file before writing to muxer ￼ ￼.
	5.	After processing all files, call muxer.stop() and muxer.release() to finalize the file.
This method does no re-encoding – it’s effectively like stitching the raw streams together. It’s very fast and preserves quality. However, it will only work if the codec configuration of all inputs is identical (same codec, sample rate, channel count) ￼. If there’s any mismatch, the muxer may throw an error or produce a corrupt file. In practice, recordings from the same app/device settings are usually consistent, so this can work. (You should still verify the outputs for any slight gaps or metadata issues.)
	•	If the above method is too fragile (or if formats differ), a safer route is to decode and re-encode:
	1.	Use MediaExtractor and MediaCodec to decode each audio file to raw PCM audio data.
	2.	Feed that PCM data into a single MediaCodec encoder (e.g., an AAC encoder) continuously for all segments, so it produces one contiguous audio stream.
	3.	Package the encoded output with MediaMuxer into an M4A file.
This approach handles any input format (since you’re decoding) and produces a uniform output. But it’s more complex to implement – you must manage audio buffers, end-of-stream signals for each segment, and ensure timing continuity. It’s also heavier on CPU since you’re decoding and encoding potentially large audio data (still likely fine for reasonable clip lengths).

Implementing either Android solution means writing a fair amount of Java/Kotlin code in a platform channel. You must also handle errors (e.g., if an extractor fails to read or a codec error occurs). The process is asynchronous – MediaCodec and MediaMuxer operate on background threads, so you’d invoke the method on the platform side and await a callback in Flutter. The complexity is significantly higher than using FFmpeg or a ready-made plugin, but it avoids adding large external libraries. On the licensing front, using Android’s framework APIs has no licensing requirements.

Complexity & Trade-offs: The native approach gives you full control and zero extra binary dependencies (just use platform SDKs). It’s a solid choice if you need to minimize app size or avoid LGPL/GPL entirely. However, from a maintainability perspective, you now have two codebases (Swift and Kotlin) to maintain alongside Flutter. Any future bug fixes or platform-specific issues will be on you to debug. The development time is also much longer. In contrast, using a well-known library like FFmpeg abstracts all this – for example, FFmpeg’s concat demuxer essentially does the same as the MediaMuxer approach (and its concat filter does the decode/re-encode approach internally). FFmpeg has already handled the edge cases, whereas with DIY native code you’ll need to be careful with things like audio format mismatches, EOS handling, and file I/O.

Recommendation and Conclusion

Considering the options, the best balance of reliability, performance, and maintainability is to use FFmpegKit (ffmpeg_kit_flutter_audio) for concatenating audio files. This solution is robust to varying codecs, runs asynchronously in native code, and has a straightforward Dart API. It leverages FFmpeg’s decades of development to handle errors and oddities gracefully (meeting the robustness requirement) ￼ ￼. Performance is excellent for multiple-file concatenation – especially if you can use stream copy, but even re-encoding is usually very fast for audio. Maintainability is decent: you only maintain high-level Dart code while relying on a well-tested native library. The plugin’s LGPL license is compatible with permissive licensing preferences (no copyleft contagion to your code) and avoids GPL issues by excluding GPL components ￼.

The trade-offs are that FFmpegKit increases your app’s binary size (the audio-only build is smaller than full FFmpeg, but expect tens of MB added). Also, with FFmpegKit now in LTS mode, you should plan for the possibility of needing an alternative in the far future if a breaking OS change occurs. That said, for the present and near future, FFmpegKit 6.0.3 is stable and fulfills this use-case well.

We prefer FFmpegKit over the smaller plugins because of its proven track record – it’s more likely to handle edge cases (e.g. a slightly corrupt file or a rare codec) gracefully, whereas a niche plugin might hit an issue. We also prefer it over writing native code because of the significant development and maintenance overhead of custom platform implementations. Unless your app has a hard constraint on binary size or you have no tolerance for using a retired library, FFmpegKit is the most performant and maintainable choice in practice.

In summary, use FFmpegKit (audio variant) to concatenate your on-device recorded audio files. It will let you merge files repeatedly with minimal code, and the output will be immediately playable. Should you later decide to remove the dependency, you can then consider implementing the native approach – but starting with FFmpegKit will give you a quick, reliable solution now. ￼ ￼

Integration Steps Recap:
	1.	Add ffmpeg_kit_flutter_audio to pubspec and run flutter pub get. (This includes all native code – no extra setup on Xcode/Android Studio aside from enabling file permissions, which you’ve handled).
	2.	Use FFmpegKit.executeAsync() with a concat command (as shown in the snippet) to merge your list of audio files. Construct the command either with multiple -i inputs and the concat filter, or by generating a concat list file for FFmpeg.
	3.	Wait for the FFmpeg session to complete (check the return code for success). The resulting file can be found at the output path you provided and played via any audio player.
	4.	(Optional) If file sizes or licensing still concern you, you can evaluate the native approach later. But for most apps, FFmpegKit’s benefits outweigh its downsides for this functionality.