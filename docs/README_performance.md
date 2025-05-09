# Startup Performance Monitoring

This doc is a **quick-start cheat-sheet**. For the full deep-dive rationale and CI details, see [`docs/current/performance-startup-guide.md`](./current/performance-startup-guide.md).

It explains how to measure and guard startup performance numbers.

## Local measurement (Cycle 0 & 5)

```
flutter run --trace-startup -d <device-id>
# artifacts are written to: build/start_up_info.json & build/start_up_timeline.json
mkdir -p perf/current
cp build/start_up_info.json perf/current/startup.json
cp build/start_up_timeline.json perf/current/startup_timeline.json
```

Key metrics:
* **timeToFirstFrameMicros** – primary KPI (convert to ms by / 1000)
* **engineEnterTimestampMicros** – cold-start budget (limit ≤ 2000 ms on CI)

Compare against baseline with:

```
ci/check_startup_regression.sh perf/current/startup.json perf/baseline/startup.json
```

## CI guard

`.github/workflows/startup-perf.yml` boots the app on an Android emulator in profile
mode, captures the same JSON files and then executes
`ci/check_startup_regression.sh`. The script fails the build when:

* ΔTTFM > 100 ms, or
* APK/IPA size grows by > 1 % (optional, supply paths)

Artifacts (`start_up_info.json`, `start_up_timeline.json`) are uploaded for manual
inspection after each run.

## Troubleshooting

* **Xcode sim crash** – remove `--trace-to-file <path>`; the directory doesn't
  exist inside the iOS sandbox and the engine will seg-fault. Just rely on the
  default output path and copy it afterwards.
* **Emulator fails to boot on CI** – bump API level or use a different
  device profile in the workflow. 