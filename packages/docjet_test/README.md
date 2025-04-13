# DocJet Test Utilities

Test utilities for DocJet Mobile.

## Features

### Logging Test Utilities

Tools for testing code that uses the DocJet logging system:

- Capturing log output during tests
- Temporarily changing log levels for tests
- Asserting the presence or absence of specific log messages

## Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  docjet_test:
    path: packages/docjet_test
```

## Usage

### Logging Test Utilities

```dart
import 'package:docjet_test/docjet_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logs appropriate debug messages', () async {
    // Create a test output to capture logs
    final output = captureLogOutput();
    
    // Run test with debug logging enabled
    await withDebugLogging(MyComponent, () async {
      // Test code that should produce logs
      myComponent.doSomething();
    });
    
    // Assert log content
    expectLogContains(output, Level.debug, 'Expected message');
    expectNoLogsAboveLevel(output, Level.warning);
  });
  
  test('logs nothing when disabled', () async {
    final output = captureLogOutput();
    
    // Run with a specific log level
    await withLogLevel(MyComponent, Level.error, () async {
      myComponent.doSomething();
    });
    
    // Assert no logs below error level
    expectNoLogsFrom(MyComponent, Level.debug, output, () async {
      myComponent.doSomethingElse();
    });
  });
}
```

### Available Utilities

- `captureLogOutput()` - Creates a test log output
- `resetLogLevels()` - Resets all log levels to default
- `withDebugLogging(Type, Function)` - Runs code with debug logging enabled
- `withLogLevel(Type, Level, Function)` - Runs code with specific log level
- `expectLogContains(output, level, substring)` - Asserts log content
- `expectNoLogsAboveLevel(output, level)` - Asserts no high-level logs
- `expectNoLogsFrom(type, level, output, testFn)` - Asserts no logs from component 