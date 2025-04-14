/// Example of a component with proper logging implementation
///
/// This class demonstrates:
/// - Setting up a class-specific logger
/// - Using the logger consistently with appropriate levels
/// - Controlling its default log level
/// - Using log tags correctly

import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Example component that processes tasks
class TaskProcessor {
  // Get a logger for this component
  static final Logger _logger = LoggerFactory.getLogger(TaskProcessor);

  // Tag for consistent log messages
  static final String _tag = logTag(TaskProcessor);

  /// Process a task
  /// Returns true if processing was successful
  bool process(String task) {
    _logger.d('$_tag Starting to process task: $task');

    if (task.isEmpty) {
      _logger.w('$_tag Cannot process empty task');
      return false;
    }

    if (task == 'invalid task') {
      _logger.e('$_tag Failed to process task: $task');
      return false;
    }

    _logger.i('$_tag Successfully processed task: $task');
    return true;
  }
}

/// Simple result class for the task processor
class TaskResult {
  final bool success;
  final String taskId;
  final String message;

  TaskResult({
    required this.success,
    required this.taskId,
    required this.message,
  });
}
