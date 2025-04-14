import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// Example component that uses logging
class TestComponent {
  final Logger logger = LoggerFactory.getLogger(TestComponent);

  void doSomething() {
    logger.d('Debug message from component');
    logger.i('Info message from component');
  }

  void doSomethingBad() {
    logger.e('Error message from component');
  }
}

void main() {
  group('LoggerFactory', () {
    // Before each test, clear logs
    setUp(() {
      LoggerFactory.clearLogs();
    });

    test('captures logs from components', () {
      // Create component (with its own logger)
      final component = TestComponent();

      // Run the component
      component.doSomething();

      // We need to check the actual log format
      debugPrint('LOG EVENT LINES:');
      for (var event in LoggerFactory.getAllLogs()) {
        debugPrint('Lines: ${event.lines}');
      }

      // Verify logs were captured
      expect(
        LoggerFactory.getAllLogs().isNotEmpty,
        isTrue,
        reason: 'Should have captured logs',
      );

      // The actual message is inside the lines property of the event
      expect(
        LoggerFactory.getAllLogs().any(
          (event) => event.lines.any(
            (line) => line.contains('Info message from component'),
          ),
        ),
        isTrue,
        reason: 'Should find info message in logs',
      );
    });

    test('filters logs by level', () {
      // Set level to INFO (should hide DEBUG logs)
      LoggerFactory.setLogLevel(TestComponent, Level.info);

      // Create component and run it
      final component = TestComponent();
      component.doSomething();

      // Query for all logs
      final allLogs = LoggerFactory.getAllLogs();
      debugPrint('FILTER TEST - All logs: ${allLogs.length}');

      // DEBUG should be filtered out
      expect(
        allLogs.any(
          (event) => event.lines.any(
            (line) => line.contains('Debug message from component'),
          ),
        ),
        isFalse,
        reason: 'Should not see debug message',
      );

      // INFO should be present
      expect(
        allLogs.any(
          (event) => event.lines.any(
            (line) => line.contains('Info message from component'),
          ),
        ),
        isTrue,
        reason: 'Should see info message',
      );
    });

    test('can clear logs between tests', () {
      // Generate some logs
      final component = TestComponent();
      component.doSomething();

      // Verify logs exist
      expect(LoggerFactory.getAllLogs().isNotEmpty, isTrue);

      // Clear logs
      LoggerFactory.clearLogs();

      // Verify logs are gone
      expect(LoggerFactory.getAllLogs().isEmpty, isTrue);
    });
  });
}
