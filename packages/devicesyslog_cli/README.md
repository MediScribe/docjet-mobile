# Device Syslog CLI

A Dart wrapper around `idevicesyslog` for streaming, filtering, and capturing iOS device logs.

## Installation

```bash
# From the repo root
cd packages/devicesyslog_cli
dart pub get
```

## Usage

```bash
# Run directly
dart run bin/devicesyslog.dart --help

# Or once activated/compiled:
devicesyslog --wifi --save
```

## Key Features

- Stream colorized device logs with automatic DocJet bundle ID filtering
- Save logs to timestamped files
- Support for USB and Wi-Fi connections
- Optional JSON output format
