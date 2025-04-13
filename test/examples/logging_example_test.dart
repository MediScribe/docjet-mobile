/// LOGGING EXAMPLE TEST
///
/// This test runs the logging example to demonstrate
/// the output of the logging system.
///
/// Note: This test doesn't actually assert anything
/// beyond running the example - it's for demonstration
/// purposes only.

library;

import 'package:flutter_test/flutter_test.dart';
import '../../examples/logging_example.dart' as logging_example;

void main() {
  test('Run logging example and print output', () {
    // This test simply executes the main function of the example script.
    // The debugPrint statements within the example will be shown in the
    // test output console.
    logging_example.main();

    // We aren't asserting anything here, the goal is just to run the example
    // and see its output via the test runner.
    expect(true, isTrue); // Add a dummy assertion to make the test valid
  });
}
