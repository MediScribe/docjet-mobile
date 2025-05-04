# Scripts

This directory contains utility scripts for the project.

## Table of Contents

- [attach_logs_to_sim.sh](#attach_logs_to_simsh)
- [debug_test.dart](#debug_testdart)
- [fix_format_analyze.sh](#fix_format_analyzesh)
- [format.sh](#formatsh)
- [list_failed_tests.dart](#list_failed_testsdart)
- [run_all_tests.sh](#run_all_testssh)
- [run_e2e_tests.sh](#run_e2e_testssh)
- [run_on_device_staging.sh](#run_on_device_stagingsh)
- [run_with_mock.sh](#run_with_mocksh)
- [toggle_mock_server.sh](#toggle_mock_serversh)

## Scripts Overview

### `attach_logs_to_sim.sh`

Attaches to a specific iOS simulator (hardcoded ID) to capture and display Flutter logs. It saves the logs to `offline_restart.log` in the current directory while simultaneously printing them to the terminal using `tee`.

**Usage:**

```bash
./scripts/attach_logs_to_sim.sh
```

**Note:** The simulator ID `325985CC-C12D-4BF9-BC82-59B7AB1ACB66` is hardcoded. You might need to update this if you use a different simulator.

### `debug_test.dart`

This is a sample test file designed to demonstrate how to use the logging helpers (`log_helpers.dart`) within tests. It includes examples of different log levels (`info`, `debug`, `warning`, `error`) and standard `print` statements. The test intentionally fails to show how logs appear for failing tests when using `./scripts/list_failed_tests.dart --debug`.

**Usage:**

This isn't a script to run directly, but rather a test file. Run it using the standard test runner, preferably `list_failed_tests.dart` to see the log output on failure:

```bash
./scripts/list_failed_tests.dart --debug scripts/debug_test.dart
```

### `fix_format_analyze.sh`

A convenience script that runs `dart fix --apply`, formats the code using `./scripts/format.sh`, and then runs `dart analyze`. It ensures the codebase adheres to automated fixes, formatting standards, and passes static analysis checks.

**Usage:**

```bash
./scripts/fix_format_analyze.sh
```

### `format.sh`

Formats all `.dart` files in the project using `dart format`. It intelligently excludes common generated file patterns (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`).

**Usage:**

```bash
./scripts/format.sh
```

### `list_failed_tests.dart`

`list_failed_tests.dart` is a utility script that runs tests and parses the output to display a clean, formatted list of failed tests.

**Features**

- Runs tests and displays a clean, formatted list of failed tests
- Can target specific test files or directories
- Handles multi-package monorepos by detecting package directories and running tests in the correct context
- Can show debug output and exception details for failed tests
- Maintains compatibility with Flutter dependencies

**Usage**

```bash
./scripts/list_failed_tests.dart [--debug] [--except] [test_target1 test_target2 ...]
```

**Testing**

**Important:** Due to dependency resolution differences between `dart test` and `flutter test`, the tests for this script should be run using one of the following methods:

1. Use the provided test runner script:
   ```bash
   ./test/scripts/run_list_failed_tests_tests.sh
   ```

2. Run the script itself to test itself (meta, right?):
   ```bash
   ./scripts/list_failed_tests.dart test/scripts/
   ```

3. Run individual test files:
   ```bash
   dart test test/scripts/package_directory_utils_test.dart
   dart test test/scripts/test_event_processor_test.dart
   # etc.
   ```

**Why not use `dart test test/scripts/`?**

When running `dart test` directly on the script tests, you may encounter failures even though the script works correctly. This is because:

1. The script itself uses `flutter test --machine` under the hood, which loads Flutter dependencies
2. Some test utilities in this repo depend on Flutter packages
3. When run with `dart test`, these Flutter dependencies aren't available
4. When run with our script or individually, the tests pass because the environment is set up correctly

This is actually proof that our script is doing its job correctly - it provides the proper environment for running tests in a mixed Dart/Flutter monorepo!

### `run_all_tests.sh`

Executes a comprehensive test suite including unit tests, mock API server tests, and end-to-end (E2E) tests. It also attempts to start the app with the mock server (`run_with_mock.sh`) and performs a brief stability check.

**Sequence:**
1. Runs unit tests via `list_failed_tests.dart`.
2. Runs mock API server tests via `list_failed_tests.dart mock_api_server`.
3. Runs E2E tests via `run_e2e_tests.sh`.
4. Starts the app with the mock server in the background (`run_with_mock.sh`).
5. Checks if the app started and remains stable for a few seconds.
6. Kills the app process.

**Usage:**

```bash
./scripts/run_all_tests.sh
```

**Note:** Exits immediately if any test phase fails.

### `run_e2e_tests.sh`

Runs the Flutter integration tests (`integration_test/app_test.dart`). It first starts the mock API server (`mock_api_server/bin/server.dart`) in the background, waits for it to become available, runs the tests using `flutter test`, and then shuts down the mock server.

**Usage:**

```bash
./scripts/run_e2e_tests.sh
```

**Requires:** `secrets.test.json` file for test configuration.

### `run_on_device_staging.sh`

Runs the Flutter app on a specific physical device (hardcoded ID) using staging secrets. It checks for the existence of `secrets.staging.json` and then uses `flutter run` with the `--dart-define-from-file` flag to load the secrets and `-d` to target the specified device.

**Usage:**

```bash
./scripts/run_on_device_staging.sh
```

**Requires:** `secrets.staging.json` in the project root.
**Note:** The device ID `00008140-00062C6401D3001C` is hardcoded. You will need to change this to your device's ID.

### `run_with_mock.sh`

Starts the mock API server (`mock_api_server/bin/server.dart`) in the background, waits for it to become ready, and then runs the Flutter app using the development entry point (`lib/main_dev.dart`). This entry point typically configures the app to use the mock server URL. The script ensures the mock server is shut down cleanly when the script exits or is interrupted (e.g., via Ctrl+C).

**Usage:**

```bash
./scripts/run_with_mock.sh
```

**Note:** This script runs `flutter run` interactively in the foreground after starting the mock server.

### `toggle_mock_server.sh`

Provides an interactive menu to manage the mock API server (`mock_api_server/bin/server.dart`). It allows starting, stopping, toggling, and checking the status of the mock server.

**Features:**
- Checks for required dependencies (`lsof`, `dart`).
- Identifies if the process on the configured port (`8080` by default) is the expected mock server.
- Prompts for confirmation before killing an unknown process using the port.
- Waits for the server to start and provides feedback.

**Usage:**

```bash
./scripts/toggle_mock_server.sh
``` 