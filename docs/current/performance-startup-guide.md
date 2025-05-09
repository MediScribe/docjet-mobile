# Startup Performance Guide

This guide documents in detail how to measure, analyse **and automatically guard** the DocJet Mobile startup performance.

---

## 1. Key Metrics

| Metric (JSON key) | Description | CI Threshold |
|-------------------|-------------|--------------|
| `timeToFirstFrameMicros` | Time from engine launch until the first UI frame is rasterised. Converted to ms by `/1000`. **Primary KPI.** | ≤ 300 ms |
| `engineEnterTimestampMicros` | Total cold-start time from process spawn until the Flutter engine initialises. | ≤ 2 000 ms |

The metrics are produced by `flutter run --trace-startup` as part of `build/start_up_info.json`.

---

## 2. Manual Measurement (local dev)

1. Pick a device / simulator. **Prefer the slowest one** you regularly use (e.g. Android emulator `Pixel_4`, or a mid-tier physical handset).

```bash
# Cold-start with timeline capture
flutter run --trace-startup -d <device-id>

# Grab the artefacts
mkdir -p perf/current
cp build/start_up_info.json perf/current/startup.json
cp build/start_up_timeline.json perf/current/startup_timeline.json
```

2. Compare against the baseline committed in `perf/baseline/`:

```bash
ci/check_startup_regression.sh perf/current/startup.json perf/baseline/startup.json
```

The script exits non-zero when **ΔTTFM > 100 ms**.

> ⚠️  **iOS gotcha** – Passing `--trace-to-file <path>` with a directory causes a sandbox write crash (see Cycle 5 crash log). Just omit the flag; copy the default files afterwards.

---

## 3. Continuous Integration Guard

The workflow `.github/workflows/startup-perf.yml` runs on each PR and on `main`:

1. Boot an Android emulator (`Pixel_4`, API 33) in **profile** mode for realistic numbers.
2. Execute:

```bash
flutter run --profile --trace-startup -d emulator-5554 \
  --trace-to-file build/start_up_timeline.json < /dev/null
```

3. Upload `start_up_info.json` & timeline as artefacts.
4. Run the regression script:

```bash
ci/check_startup_regression.sh start_up_info.json perf/baseline/startup.json
```

5. Workflow fails if:
   * ΔTTFM > 100 ms, **or**
   * `engineEnterTimestampMicros` > 2 000 ms.

### 3.1 Binary Size Check (optional)

Pass two extra parameters to also guard APK/IPA size:

```bash
ci/check_startup_regression.sh \
  start_up_info.json perf/baseline/startup.json \
  build/app/outputs/flutter-apk/app-release.apk \
  perf/baseline/apk_size.txt
```

The script fails when **size growth > 1 %**.

---

## 4. Script Anatomy – `ci/check_startup_regression.sh`

```bash
Usage: ci/check_startup_regression.sh <current_json> <baseline_json> [current_apk] [baseline_apk_size_file]
```

Internals (simplified):

```bash
current=$(jq '.timeToFirstFrameMicros' "$current_json")
baseline=$(jq '.timeToFirstFrameMicros' "$baseline_json")
if (( (current-baseline)/1000 > 100 )); then exit 1; fi
# Optional size diff …
```

The script prints ✅ / ❌ summaries and is used **locally and by CI**. Keep it executable (`chmod +x`).

---

## 5. Updating the Baseline

1. Land a change that legitimately improves performance.
2. Re-measure on the reference device.
3. Replace files under `perf/baseline/` and, if applicable, `perf/baseline/apk_size.txt`.
4. Update thresholds in the workflow if necessary.

---

## 6. Troubleshooting

* **Sim crash with `SIGSEGV` inside `TimelineEventPerfettoFileRecorder`** – You attempted to write the timeline file to a path not accessible by the sandbox. Use the default output location.
* **CI emulator fails to launch** – Increase the GitHub action's timeout or change the device profile.
* **`jq` not found** – Install via `brew install jq` (macOS) or `apt-get install jq` (CI Linux).

---

Happy profiling. Remember: *"I'm not renting space to uncertainty."* – Dollar Bill 