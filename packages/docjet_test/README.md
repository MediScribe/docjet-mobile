# DocJet Test Utilities

Test utilities for DocJet Mobile.

## Features

### Logging Test Utilities

Tools for testing code that uses the DocJet logging system:

- Capturing log output during tests
- Temporarily changing log levels for tests
- Asserting the presence or absence of specific log messages
- Support for both class-based and string-based loggers

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
    
    // Run test with debug logging enabled for a Class
    await withDebugLogging(MyComponent, () async {
      // Test code that should produce logs
      myComponent.doSomething();
    });
    
    // Assert log content
    expectLogContains(output, Level.debug, 'Expected message');
    expectNoLogsAboveLevel(output, Level.warning);
  });
  
  test('logs appropriate debug messages with string logger', () async {
    // Create a test output to capture logs
    final output = captureLogOutput();
    
    // Run test with debug logging enabled for a string identifier
    await withDebugLogging("MyFeature.Logger", () async {
      // Test code that should produce logs
      featureLogger.doSomething();
    });
    
    // Assert log content
    expectLogContains(output, Level.debug, 'Expected message');
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
- `withDebugLogging(target, Function)` - Runs code with debug logging enabled
  - `target` can be a Type (class) or String identifier
- `withLogLevel(target, Level, Function)` - Runs code with specific log level
  - `target` can be a Type (class) or String identifier
- `expectLogContains(output, level, substring)` - Asserts log content
- `expectNoLogsAboveLevel(output, level)` - Asserts no high-level logs
- `expectNoLogsFrom(target, level, output, testFn)` - Asserts no logs from component
  - `target` can be a Type (class) or String identifier

### String-Based vs Class-Based Loggers

Both approaches are supported with identical APIs:

```dart
// Class-based logger (recommended for normal components)
final logger = LoggerFactory.getLogger(MyClass);
final tag = logTag(MyClass);

// String-based logger (useful for tests or cross-class modules)
final logger = LoggerFactory.getLogger("Feature.SubSystem");
final tag = logTag("Feature.SubSystem");
```

#### When to use String-Based Loggers:

- For test-only loggers
- For utility functions without a clear class
- For shared subsystems that span multiple classes
- To avoid creating dummy test classes

#### Important Implementation Note:

When a Type and String have the same name (e.g., `MyClass` vs `"MyClass"`), they will share the same log level. The last `setLogLevel` call will determine the level for both. This is because the implementation uses the string representation of Types for internal storage.

```dart
// This will set both loggers to Level.debug  
LoggerFactory.setLogLevel(MyClass, Level.warning);
LoggerFactory.setLogLevel("MyClass", Level.debug); // Last call wins

// Both will now return Level.debug
LoggerFactory.getCurrentLevel(MyClass);      // Level.debug
LoggerFactory.getCurrentLevel("MyClass");    // Level.debug
```

To avoid this behavior, use distinct names for string-based loggers that don't match class names. 