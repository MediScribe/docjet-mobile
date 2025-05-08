import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/widgets/buttons/circular_action_button.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

// Renamed from MyHomePage
class TranscriptionsPage extends StatelessWidget {
  const TranscriptionsPage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(TranscriptionsPage);
  // Create standard log tag
  static final String _tag = logTag(TranscriptionsPage);

  @override
  Widget build(BuildContext context) {
    final appColors = getAppColors(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Transcriptions')),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: 5,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text('Transcription Item ${index + 1}'),
                subtitle: const Text('Lorem ipsum dolor sit amet...'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _logger.i('$_tag Tapped on item ${index + 1}');
                  // TODO: Implement navigation or action for tapping item
                },
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: CircularActionButton(
                onTap: () {
                  _logger.i('$_tag Record button tapped!');
                  // TODO: Implement recording logic
                },
                tooltip: 'Start new recording',
                buttonColor: appColors.primaryActionBg,
                child: Icon(Icons.mic, color: appColors.primaryActionFg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
