Concatenating Multiple Audio Files in Flutter (iOS & Android)

**WARNING: `ffmpeg_kit_flutter_audio` is RETIRED and UNSUPPORTED!**

While FFmpeg is a powerful tool, the primary Flutter wrapper, `ffmpeg_kit_flutter_audio`, was officially retired in Jan 2025 and is **no longer maintained or supported** ￼. Using it carries significant risk of future incompatibility or unpatched security issues. **Proceed with extreme caution.** This document outlines options, including the retired FFmpegKit, but emphasizes the need for alternative solutions.

Using FFmpegKit (Retired) for Robust Audio Concatenation

One previously reliable solution was FFmpeg via the FFmpegKit Flutter plugin. FFmpeg is battle-tested, but the **plugin itself is dead**. We recommend the `ffmpeg_kit_flutter_audio` package variant if you *must* use it, as it includes audio codecs (AAC, MP3, etc.) under LGPL license (no GPL components). This means it *could* be used in closed-source apps (LGPL allows commercial use), but **you are relying on unsupported code**.

**Maintenance and licensing risk:** As stated, FFmpegKit was retired in Jan 2025 ￼. The last release (6.0.3) might be stable *now*, but future OS updates (iOS/Android) **could break it without warning or recourse**. The LGPL-3.0 license requires attribution.

Concatenating with FFmpeg: FFmpeg supports two approaches to concat audio: (1) re-encode and join via the concat filter, or (2) stream copy via the concat demuxer (which avoids re-encoding if files have identical format). The concat filter method is straightforward and works even if formats differ (FFmpeg will re-encode the output). For example, to join two audio files:

ffmpeg -i audio1.mp3 -i audio2.mp3 -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" output.mp3

This FFmpeg command uses the concat filter to merge two audio streams ￼. In Flutter, you can run the same command with FFmpegKit. Alternatively, if your recordings share the exact same codec/format (likely true for on-device recordings), you can use the concat demuxer for a lossless join: create a text file listing the files and run -f concat -safe 0 -i list.txt -c copy output.m4a ￼. The -c copy option copies audio frames without re-encoding, making it very fast and preserving quality. This method is strict about files having matching codecs/sample rates ￼.

FFmpegKit Example – Concatenating two files (USING RETIRED/UNSUPPORTED PLUGIN):

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit_flutter_audio.dart'; // WARNING: UNSUPPORTED PACKAGE

Future<void> concatTwoAudioFiles(String filePath1, String filePath2, String outputPath) async {
  // WARNING: This uses a retired, unsupported package.
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

Setup instructions (FOR RETIRED PLUGIN):
To integrate FFmpegKit, add the plugin to your pubspec with the desired variant. For example, in pubspec.yaml:

dependencies:
  ffmpeg_kit_flutter_audio: ^6.0.3  # audio-only FFmpegKit (LGPL)

Then run flutter pub get. The plugin bundles the native FFmpeg binaries for iOS and Android, so no additional platform setup is needed. Ensure you import the correct package name (e.g. ffmpeg_kit_flutter_audio as shown). Also, remember to include the FFmpegKit LGPL license in your app's notices (as required by LGPL). Other than that, no special permissions beyond file read/write (already handled) are required – the heavy lifting is done in native code.

Why FFmpegKit (*WAS* Recommended):
It *provided* a robust, cross-platform solution with one unified Dart API. FFmpeg is very reliable at handling various audio codecs and file quirks (it will handle codec/format differences gracefully by re-encoding if needed) ￼. Performance *was* good – written in C/C++, it can concatenate audio faster than real-time in most cases. The operation runs off the UI thread (FFmpegKit uses background threads), satisfying the performance requirement. And by using the well-maintained (albeit now LTS) plugin, you avoid writing and debugging custom platform code, which improves maintainability of your project. The plugin's LGPL license *was* compatible with App Store/Play Store distribution (unlike GPL, which would require you to open source your app) ￼. Overall, FFmpegKit hits a good balance of reliability and ease-of-use.

**Current Reality:** Due to the lack of support, the risks likely outweigh the benefits for new development unless you accept the maintenance burden and potential for future breakage.

Note: As FFmpegKit is no longer receiving updates ￼, keep an eye on its GitHub for any community forks or fixes. Version 6.0.3 is stable, but future OS updates could require tweaks. In practice, for audio concatenation (a basic feature), it should remain functional for the foreseeable future.

Alternative Flutter Packages (File-Based Merging)

If you prefer not to use a full FFmpeg wrapper, there are smaller plugins that focus on audio editing. Two notable ones are sound_edit and audio_kit:
	•	sound_edit – A plugin that lets you combine audio files regardless of extension and even trim audio ￼. It is implemented with platform code (using Swift, Kotlin, C++ under the hood) and licensed under BSD-3-Clause ￼. This package was last updated in 2023 and supports Android, iOS, and even web. It provides a high-level API to merge clips (and possibly adjust playback speed). While the license is permissive and it avoids you writing FFmpeg commands, be aware it's a relatively obscure plugin (low download count) – so maintenance and community support are limited.
	•	audio_kit – A newer plugin (MIT licensed) that supports audio trimming, merging, and mixing ￼ ￼. Internally, it actually uses FFmpeg as well (according to its description) to perform the operations. So it's somewhat a lighter wrapper around FFmpeg functionality. Like sound_edit, this plugin isn't widely used or actively developed (as of now). It might save you from writing FFmpeg commands directly, but you inherit the dependency on FFmpeg binaries (and its large size) without the reassurance of a large community.

In summary, these Flutter-first plugins exist and can handle the task with a few function calls. However, robustness might be a concern – since they are not as battle-tested, you'd want to thoroughly test with your audio formats. They also likely perform the work on background threads (using native code), so performance should be fine. But given their limited adoption, maintainability is a question mark (you might need to dive into their source if something goes wrong). If you choose one, review its issue tracker for any known bugs around audio formats.

Native Platform APIs via Platform Channels (The Robust But Hard Way)

Given the lack of supported, high-level plugins, implementing audio concatenation natively on each platform using platform channels becomes a **more compelling, albeit complex, long-term solution.**

If no plugin meets your needs, you can implement audio concatenation natively on each platform using platform channels. Both iOS and Android provide media APIs to concatenate tracks, though the implementations differ in complexity:
	•	iOS (AVFoundation): Apple's AVFoundation framework makes this fairly straightforward. You can use AVMutableComposition to build a single audio track from multiple source files, then export it with AVAssetExportSession. For example, you would create an AVMutableCompositionTrack for audio, then for each input file:
	1.	Load the file into an AVURLAsset and retrieve its audio track.
	2.	Append the track into your composition at the end of the previous segment (using insertTimeRange) ￼.
	3.	After adding all segments, initialize an AVAssetExportSession with the composition. Use an output file type like M4A (AAC) and possibly AVAssetExportPresetPassthrough as the preset.
	4.	Call exportAsynchronously to write out the combined file in the background, then handle the completion callback.
This approach is robust and uses the device's native encoders/decoders. If the source files are already in an AAC/M4A format, AVFoundation can often "passthrough" or at least avoid recompression. (In practice, using the Passthrough preset for audio compositions will attempt to not re-encode if possible.) Even if it does re-encode, it will use Apple's optimized AAC encoder. The result is an .m4a file that is immediately playable. Error handling (e.g. file not found or codec issues) can be managed via the export session status and error properties. Maintainability is good long-term – AVFoundation is well-documented and stable. The downside is you need to write Objective-C/Swift code in a plugin or method channel, which adds to your codebase.
	•	Android (MediaMuxer/MediaCodec): On Android, you have a couple of options:
	•	If all audio files are recorded with the exact same format (e.g., all are AAC in an MP4/M4A container with the same sampling rate and channels), you can concatenate them at the MP4 container level using MediaMuxer. The idea is to use MediaExtractor to read the AAC frames from each source file and write them sequentially to a new output file via MediaMuxer. You would:
	1.	Initialize a MediaMuxer to create a new MP4/M4A file.
	2.	For the first input file, use MediaExtractor to get the audio track format and add that track to the MediaMuxer (muxer.addTrack(format)). Start the muxer.
	3.	Loop through the samples of the first file (Extractor readSampleData), write them to the muxer via writeSampleData. Keep track of the presentation time of the last sample.
	4.	For the second file, repeat reading its samples, but offset the timestamps by the duration of the first file before writing to muxer ￼ ￼.
	5.	After processing all files, call muxer.stop() and muxer.release() to finalize the file.
This method does no re-encoding – it's effectively like stitching the raw streams together. It's very fast and preserves quality. However, it will only work if the codec configuration of all inputs is identical (same codec, sample rate, channel count) ￼. If there's any mismatch, the muxer may throw an error or produce a corrupt file. In practice, recordings from the same app/device settings are usually consistent, so this can work. (You should still verify the outputs for any slight gaps or metadata issues.)
	•	If the above method is too fragile (or if formats differ), a safer route is to decode and re-encode:
	1.	Use MediaExtractor and MediaCodec to decode each audio file to raw PCM audio data.
	2.	Feed that PCM data into a single MediaCodec encoder (e.g., an AAC encoder) continuously for all segments, so it produces one contiguous audio stream.
	3.	Package the encoded output with MediaMuxer into an M4A file.
This approach handles any input format (since you're decoding) and produces a uniform output. But it's more complex to implement – you must manage audio buffers, end-of-stream signals for each segment, and ensure timing continuity. It's also heavier on CPU since you're decoding and encoding potentially large audio data (still likely fine for reasonable clip lengths).

Implementing either Android solution means writing a fair amount of Java/Kotlin code in a platform channel. You must also handle errors (e.g., if an extractor fails to read or a codec error occurs). The process is asynchronous – MediaCodec and MediaMuxer operate on background threads, so you'd invoke the method on the platform side and await a callback in Flutter. The complexity is significantly higher than using FFmpeg or a ready-made plugin, but it avoids adding large external libraries. On the licensing front, using Android's framework APIs has no licensing requirements.

Complexity & Trade-offs:
The native approach gives you full control and avoids reliance on unsupported third-party code. It's the **most future-proof option** if you need guaranteed long-term maintainability. However, the development time and complexity are **significantly higher**, requiring native iOS (Swift/Objective-C) and Android (Kotlin/Java) expertise.

Recommendation and Conclusion (Updated)

**The landscape has shifted.** With `ffmpeg_kit_flutter_audio` retired, there is **no clear, easy, and reliably maintained Flutter package** for robust audio concatenation.

Your options are:
1.  **Native Implementation (Recommended for Long-Term):** Bite the bullet and implement the concatenation logic natively using `AVFoundation` (iOS) and `MediaMuxer/MediaCodec` (Android) via platform channels. This offers the most control, avoids external dependencies, and is the most maintainable *if* you have the native development resources. **This is the technically superior, most robust path forward, despite the effort.**
2.  **Use Retired `ffmpeg_kit_flutter_audio` (High Risk):** Use version 6.0.3, accepting that it's unsupported, may break with future OS updates, and requires LGPL compliance. Only consider this if you need a solution *now* and accept the risks and potential need to migrate later.
3.  **Investigate Niche Plugins (`sound_edit`, `audio_kit`, etc.):** Evaluate lesser-known plugins. Thoroughly test their capabilities, robustness, and check their maintenance status/issue trackers. This *might* provide a simpler solution than native code but carries risks due to limited adoption and potential abandonment.

**Given the lack of a specialist and the risks of the retired package, the most pragmatic approach for *this specific project right now* might be to build the Dart infrastructure cleanly (as we have done with `AudioConcatenationService`) and defer the *actual* implementation (likely native) until resources are available. If a quick, risky solution is absolutely needed, the retired FFmpegKit is an option, but proceed with eyes wide open.**

Integration Steps Recap:
	1.	Add ffmpeg_kit_flutter_audio to pubspec and run flutter pub get. (This includes all native code – no extra setup on Xcode/Android Studio aside from enabling file permissions, which you've handled).
	2.	Use FFmpegKit.executeAsync() with a concat command (as shown in the snippet) to merge your list of audio files. Construct the command either with multiple -i inputs and the concat filter, or by generating a concat list file for FFmpeg.
	3.	Wait for the FFmpeg session to complete (check the return code for success). The resulting file can be found at the output path you provided and played via any audio player.
	4.	(Optional) If file sizes or licensing still concern you, you can evaluate the native approach later. But for most apps, FFmpegKit's benefits outweigh its downsides for this functionality.