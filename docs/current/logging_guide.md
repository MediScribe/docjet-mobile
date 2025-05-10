# DocJet Mobile Logging Guide

This guide documents best practices for logging and debugging in the DocJet Mobile application.

## Table of Contents

- [Logging in the App](#logging-in-the-app)
  - [Log Levels](#log-levels)
  - [Best Practices](#best-practices)
- [iOS Device Logging](#ios-device-logging)
  - [Setting Up Device Access](#setting-up-device-access)
  - [Using the DeviceSyslog Tool](#using-the-devicesyslog-tool)
  - [Common Scenarios](#common-scenarios)
  - [Troubleshooting](#troubleshooting)
- [Flutter Debugging](#flutter-debugging)

## Logging in the App

The DocJet Mobile app uses a centralized logging system via `LoggerFactory` in `@core/utils/log_helpers.dart`.

### Log Levels

- `verbose`: Extremely detailed information (development only)
- `debug`: Debugging information (development only)
- `info`: General operational events 
- `warning`: Non-critical issues that might need attention
- `error`: Errors that affected functionality
- `wtf`: Critical failures that require immediate investigation

### Best Practices

- Use the appropriate log level for the message
- Include context in log messages
- Use structured logging when possible
- Avoid excessive logging in hot paths
- Use `logMethodCall()` for entry points to key functions
- Don't log PII (personally identifiable information)

```dart
// Import the logger
import '@core/utils/log_helpers.dart';

// Get a logger with a tag
final _logger = LoggerFactory.getLogger('JobRepository');

// Use the logger
void processJob(Job job) {
  _logger.i('Processing job: ${job.id}');
  try {
    // ... job processing logic
    _logger.d('Job details processed with ${job.items.length} items');
  } catch (e, st) {
    _logger.e('Failed to process job', error: e, stackTrace: st);
  }
}
```

## iOS Device Logging

### Setting Up Device Access

Before you can view logs from an iOS device, you need to:

1. Install the required tools:
   ```bash
   brew install libimobiledevice usbmuxd
   ```

2. Connect your iOS device via USB and establish trust:
   ```bash
   idevicepair pair
   ```
   (Tap "Trust" on your device when prompted)
   
   Then verify the pairing:
   ```bash
   idevicepair validate
   ```

### Using the DeviceSyslog Tool

The DocJet repo includes a powerful tool called `devicesyslog` for easy iOS log viewing.

#### Basic Usage

From the project root, run:

```bash
# From the project root:
./scripts/devicesyslog.sh
```

This is the **recommended way** to view logs during development. By default:
- Only shows logs from the Flutter app ("Runner" process)
- Only shows Flutter print/logger lines (containing "flutter:")

#### Advanced Options

```bash
# View all device logs (no filtering)
./scripts/devicesyslog.sh --all

# Filter to a specific process
./scripts/devicesyslog.sh --process SpringBoard

# Connect over WiFi instead of USB
./scripts/devicesyslog.sh --wifi

# Save logs to a file
./scripts/devicesyslog.sh --save
```

#### Custom Builds

If you modify the devicesyslog CLI code, rebuild it with:

```bash
./scripts/build_devicesyslog.sh
```

### Common Scenarios

#### Profile Mode Logging

For profile or release builds, logging is disabled by default. To see logs:

1. Run the app in **profile mode** with debug logging:
   ```bash
   ./scripts/run_with_staging.sh --profile -l debug
   ```

2. View the logs:
   ```bash
   ./scripts/devicesyslog.sh
   ```

#### Connecting Over WiFi

1. First establish trust via USB
2. Enable WiFi Sync in Finder/iTunes for your device
3. Disconnect the USB cable
4. Run:
   ```bash
   ./scripts/devicesyslog.sh --wifi
   ```

If you have connection issues, try the iproxy workaround:
```bash
# In terminal 1, run proxy and keep running:
iproxy 62078 62078 <your-device-udid>

# In terminal 2:
./scripts/devicesyslog.sh --wifi
```

### Troubleshooting

#### "No Device Found"

Make sure:
1. Your device is connected and unlocked
2. You've established trust (see "Setting Up Device Access")
3. The device is recognized:
   ```bash
   idevice_id -l
   ```
   This should list your device UDID

#### Too Much Output

If you're seeing too many logs:

1. Use default filters (just run `./scripts/devicesyslog.sh` without flags)
2. If you need a more specific filter:
   ```bash
   # Only show crash logs
   ./scripts/devicesyslog.sh --all | grep "crash" | cat
   ```

#### Logs Not Appearing for Debug/Dev Builds

For development builds:
- Logs should appear by default with no special configuration

For release builds:
- Use `--profile -l debug` as mentioned above to enable logging

## Flutter Debugging

For general Flutter debugging:

1. Use hot restart (⌘R) to reload with prints visible
2. Use `debugPrint` for temporary debugging (it's removed in release builds)
3. For UI issues, use Flutter DevTools widget inspector
4. Remember that our app logs through `LoggerFactory` are visible in device logs 