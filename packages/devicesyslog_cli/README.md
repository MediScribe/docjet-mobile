# iOS Device Log Viewer

[![Tests](https://github.com/docjet/docjet-mobile/actions/workflows/test_devicesyslog.yml/badge.svg)](https://github.com/docjet/docjet-mobile/actions/workflows/test_devicesyslog.yml)

**Problem:** Getting logs from real iOS devices is a pain due to complex tooling and massive output volumes.

**Solution:** Our wrapper gives you:
- Easy command-line interface with clear options
- Filtering by process name or bundle ID to see only YOUR app's logs
- Flutter-only filter to see just your app's print/logger statements
- Colorized output to spot warnings and errors
- Automatic saving of logs to files (with timestamps)
- Wi-Fi device support for cord-free debugging

## Quick Start (TL;DR)

```bash
# Connect your device, then (from project root):
./scripts/devicesyslog.sh
# That's it! By default we filter to Runner process and Flutter lines!

# Want everything? All device logs without filtering:
./scripts/devicesyslog.sh --all
```

## Prerequisites

1. Install dependencies:
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

## Common Commands

```bash
# Show only DocJet app's Flutter logs (DEFAULT)
./scripts/devicesyslog.sh

# Show all logs from "Runner" process (includes native/system calls)
./scripts/devicesyslog.sh --process Runner

# See ALL device logs without filtering (debug system issues)
./scripts/devicesyslog.sh --all

# Save DocJet logs to a file (in logs/device/YYYY-MM-DD_HH-MM-SS.log)
./scripts/devicesyslog.sh --save

# Connect over Wi-Fi (requires Wi-Fi Sync enabled)
./scripts/devicesyslog.sh --wifi
```

## Rebuilding the Binary

If you make changes to the CLI code, rebuild the binary with:

```bash
./scripts/build_devicesyslog.sh
```

## Profile vs Release Mode

For development builds to show logs in release mode:
```bash
# Run in profile mode with debug log level
./scripts/run_with_staging.sh --profile -l debug
```

## Troubleshooting

### Wi-Fi Connectivity Issues

If you're having trouble connecting to the device over Wi-Fi:

1. First connect via USB and establish trust
2. Enable Wi-Fi Sync in Finder/iTunes
3. In one terminal, start a proxy:
   ```bash
   iproxy 62078 62078
   ```
4. In a new terminal window:
   ```bash
   ./scripts/devicesyslog.sh --wifi
   ```

### Finding Your Device UDID

```bash
idevice_id -l
```

### If The Tool Gets Stuck

If the tool gets stuck, press Ctrl+C. If that doesn't work:
```bash
pkill -f "idevicesyslog"
```

## Developer Notes

* **How Filtering Works**: The `--flutter-only` flag adds `--match flutter:` to filter only Flutter print logs
* **Process vs Bundle ID**: 
  - Use `--process Runner` to see all Flutter app process logs
  - Use `--bundle-id ai.docjet.mobile` to filter syslog lines with that bundle ID string

## Flag Reference

| Flag | Description |
|------|-------------|
| `--help` | Show this help message |
| `--bundle-id <id>` | Filter logs to show only messages containing this bundle ID |
| `--process <n>` | Filter logs to specific process name (default: "Runner" for Flutter) |
| `--flutter-only` | Show only Flutter print/logger lines (DEFAULT) |
| `--all` | Disable all filters - show all device logs |
| `--save` | Save logs to a timestamped file |
| `--output-dir <path>` | Specify custom output directory (default: logs/device/) |
| `--wifi` | Connect to device over Wi-Fi (requires Wi-Fi Sync enabled) |
| `--utc` | Show UTC timestamps for saved file name and pass through to idevicesyslog |
| `--json` | Request idevicesyslog to output JSON format |
