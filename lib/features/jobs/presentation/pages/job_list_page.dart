import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/record_button.dart';
import 'package:flutter/material.dart';

// Renamed from TranscriptionsPage
class JobListPage extends StatelessWidget {
  const JobListPage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListPage);
  // Create standard log tag
  static final String _tag = logTag(JobListPage);

  @override
  Widget build(BuildContext context) {
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
              child: RecordButton(
                onTap: () {
                  _logger.i('$_tag Record button tapped!');
                  // TODO: Implement recording logic
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
