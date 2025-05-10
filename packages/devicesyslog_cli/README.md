# Device Syslog CLI Tool

A bulletproof iOS device log viewer that makes debugging real devices painless. This tool wraps Apple's `idevicesyslog` with filtering, colorization, and log saving capabilities.

## What This Tool Does

**Problem:** Getting logs from real iOS devices is a pain in the ass. Apple's `idevicesyslog` dumps everything at once, with no filtering or nice output. It's like trying to find a needle in a text-based hurricane.

**Solution:** Our wrapper gives you:
- Easy command-line interface with clear options
- Filtering by bundle ID to see only YOUR app's logs
- Colorized output to spot warnings and errors
- Automatic saving of logs to files (with timestamps)
- Wi-Fi device support for cord-free debugging

## Quick Start (TL;DR)

```bash
# Connect your device, then (replace <path> with your checkout root):
cd <path>/docjet-mobile
./tools/devicesyslog --bundle-id com.docjet.mobile --save
```

## Prerequisites

1. Install Apple's device tools (one time only):
   ```bash
   brew install libimobiledevice
   ```

2. Pair your device:
   ```bash
   # Connect your iPhone/iPad with USB cable
   idevicepair pair
   # Tap "Trust" on your device when prompted
   idevicepair validate
   ```

## Basic Usage

The compiled binary is in `tools/devicesyslog` - you can run it directly:

```bash
# Get help
./tools/devicesyslog --help

# Basic usage (shows ALL device logs - noisy!)
./tools/devicesyslog

# Show only DocJet app logs
./tools/devicesyslog --bundle-id com.docjet.mobile

# Save DocJet logs to a file (in logs/device/YYYY-MM-DD_HH-MM-SS.log)
./tools/devicesyslog --bundle-id com.docjet.mobile --save
```

## Common Commands

```bash
# Show DocJet logs and save them
./tools/devicesyslog --bundle-id com.docjet.mobile --save

# Connect to device over Wi-Fi (requires Wi-Fi Sync enabled)
./tools/devicesyslog --wifi --bundle-id com.docjet.mobile

# Custom output directory 
./tools/devicesyslog --bundle-id com.docjet.mobile --save --output-dir ~/Desktop/logs

# Working with multiple devices (specify UDID)
./tools/devicesyslog --udid 00001111-AABB22CC33DD --bundle-id com.docjet.mobile
```

## Troubleshooting

### "No Device Found"

```bash
# Make sure device is connected via USB and unlocked
idevicepair pair
# Tap "Trust" on your device!
idevicepair validate
```

### Device Not Connecting over Wi-Fi

1. First connect via USB and establish trust
2. Enable Wi-Fi sync in Finder/iTunes
3. Try running the bypass command:
   ```bash
   iproxy 62078 62078 <your-device-udid>
   ```
4. In a new terminal window:
   ```bash
   ./tools/devicesyslog --wifi --udid <your-device-udid>
   ```

### Finding Your Device UDID

```bash
idevice_id -l
```

### Kill a Hanging Process

If the tool gets stuck, press Ctrl+C. If that doesn't work:
```bash
pkill -f "idevicesyslog"
```

## Tips

* **iOS Console Logs**: Many Flutter errors appear as `stderr` messages in iOS logs, look for `[Flutter]` prefix
* **Error Messages**: Fatal crashes often show near the end of the log with `Terminating app due to uncaught exception`
* **Saving Best Practice**: Always use `--save` during testing so you have logs to review if the app crashes
* **Disk Space**: Log files accumulate in the `logs/device/` directory; clean out old ones occasionally

## Advanced: Running Directly from Dart (Developers Only)

```bash
cd packages/devicesyslog_cli
dart run bin/devicesyslog.dart --bundle-id com.docjet.mobile
```

## Flag Reference

| Flag | Description |
|------|-------------|
| `--help` | Show this help message |
| `--bundle-id <id>` | Filter logs to show only for this bundle ID (e.g., com.docjet.mobile) |
| `--save` | Save logs to a timestamped file |
| `--output-dir <path>` | Specify custom output directory (default: logs/device/) |
| `--wifi` | Connect to device over Wi-Fi (requires Wi-Fi Sync enabled) |
| `--udid <id>` | Specify device UDID when multiple devices are connected |
| `--utc` | Use UTC timestamps instead of local time |
| `--json` | Output in JSON format instead of text (not yet fully implemented) |
