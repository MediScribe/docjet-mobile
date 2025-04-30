# Feature: Offline Detection via NetworkInfoImpl

This document explains how DocJet Mobile detects **offline** and **online** states and propagates them across the application.

It covers:

* Component responsibilities & interactions (Component Diagram)
* Runtime event propagation (Flow Chart)
* Frame-by-frame signal exchange (Sequence Diagram)
* Behavioural contracts & corner-cases
* Developer notes & testing pointers

---

## 1. Component Diagram

```mermaid
flowchart TD
  subgraph "Device / Platform"
    CP[Connectivity\n(connectivity_plus)]
  end

  subgraph "Core Services"
    NI[NetworkInfoImpl] -->|implements| IF[NetworkInfo]
    NI -->|fires events| EB[AuthEventBus]
  end

  subgraph "App State Layer"
    EB -->|streams events| AN[AuthNotifier]
  end

  subgraph "UI Layer"
    AN -->|provides state| APP[AppShell]
    APP --> OB[OfflineBanner]
  end

  style NI fill:#f9f,stroke:#333,stroke-width:2px
  style AN fill:#ccf,stroke:#333,stroke-width:2px
```

**Legend**

* **Connectivity_plus** – exposes low-level network changes as a `Stream<List<ConnectivityResult>>`.
* **NetworkInfoImpl** – single source of truth for connectivity, maps raw plugin data to `bool` and fires `AuthEvent.offlineDetected` / `AuthEvent.onlineRestored`.
* **AuthEventBus** – lightweight, broadcast-only stream for auth-related events.
* **AuthNotifier** – Riverpod `Notifier` that updates `AuthState.isOffline` whenever it receives the above events.
* **AppShell / OfflineBanner** – renders the purple banner when `isOffline == true`.

---

## 2. Runtime Flow Chart

```mermaid
graph LR
  A[Network change detected by connectivity_plus] --> B{Any result != none?}
  B -- Yes --> C[NetworkInfoImpl maps to online]
  C --> D[LastKnown != Online?]
  D -- Yes --> E[Fire AuthEvent.onlineRestored]\n& Emit true on stream
  D -- No --> F[Ignore – no state change]
  B -- No --> G[NetworkInfoImpl maps to offline]
  G --> H[LastKnown != Offline?]
  H -- Yes --> I[Fire AuthEvent.offlineDetected]\n& Emit false on stream
  H -- No --> F
```

Key notes:

* Initial status is *NOT* broadcast – avoids spurious events during bootstrap.
* Distinct-until-changed logic guarantees **no duplicate events**.
* Error conditions (e.g. plugin throws) propagate as `addError` on the public stream and are logged with `Logger.f()`.

---

## 3. Sequence Diagram

```mermaid
sequenceDiagram
  participant CP as connectivity_plus
  participant NI as NetworkInfoImpl
  participant EB as AuthEventBus
  participant AN as AuthNotifier
  participant UI as AppShell / OfflineBanner

  Note over CP: Wi-Fi toggled OFF
  CP-->>NI: onConnectivityChanged([none])
  NI->>NI: status = false
  alt state changed (online ➜ offline)
    NI-->>EB: AuthEvent.offlineDetected
    EB-->>AN: offlineDetected
    AN->>AN: _setOffline(true)
    AN-->>UI: state.update(isOffline=true)
    UI->>UI: show OfflineBanner
  end

  Note over CP: Wi-Fi toggled ON
  CP-->>NI: onConnectivityChanged([wifi])
  NI->>NI: status = true
  alt state changed (offline ➜ online)
    NI-->>EB: AuthEvent.onlineRestored
    EB-->>AN: onlineRestored
    AN->>AN: _setOffline(false)
    AN->>AN: schedule profile refresh (1s debounce)
    AN-->>UI: state.update(isOffline=false)
    UI->>UI: hide OfflineBanner
  end
```

---

## 4. Behavioural Contracts

1. **Single Source of Truth** – Only `NetworkInfoImpl` translates raw connectivity into semantic events. All other layers consume these events.
2. **No Bootstrap Noise** – The implementation *does not* emit an event for the very first connectivity check, preventing false banners during cold-start in tunnels/airplanes.
3. **Debounced Profile Refresh** – After `onlineRestored` the `AuthNotifier` waits 1 second before hitting the API to avoid stampeding herds when regaining network.
4. **App-Level Disposal** – `CoreModule` registers a `dispose` callback that tears down the `NetworkInfoImpl` singleton. You *must* call `GetIt.reset()` in integration tests to avoid bleed-over.
5. **Logger Hygiene** – Hardcore `Logger.f()` traces are left in for deep debugging but only compile in debug builds. `kDebugMode` gating prevents shipping verbose logs.

---

## 5. Corner-Cases & FAQs

| Scenario | Expected Behaviour |
|----------|-------------------|
| Plugin throws error | Error propagated via `onConnectivityChanged.addError`. `isConnected` fails fast with `rethrow` in debug mode, `false` in release. |
| Airplane mode entered before DI finished | Initial check runs _after_ DI so the first event still carries correct state. |
| Multiple listeners to `onConnectivityChanged` | Allowed – controller is broadcast. |
| State already offline, plugin still sends `[none]` | Ignored – distinct value filter.|

---

## 6. Developer Checklist

* Unit tests live in `test/core/platform/network_info_impl_test.dart` & `auth_notifier_test.dart` – run them with `./scripts/list_failed_tests.dart`.  
* For smoke tests use the manual scripts documented in `implement-connectivity-service.md` Cycle 4.
* When refactoring, **never** let another component fire `offlineDetected` / `onlineRestored`. Duplicate events break state determinism.
* Keep **AuthNotifier** a *pure* consumer; all detection logic belongs to **NetworkInfoImpl**.

> "I'm not renting space to uncertainty." — **Dollar Bill** 

---

## 7. Testing Caveats (Simulator vs Real Device)

Apple's `NWPathMonitor` (used by `connectivity_plus`) can get **stuck** on the macOS / iOS *simulator* after Wi-Fi toggles:

1. off → emits `[none]` (OK)  
2. on  → emits `[wifi]` *then immediately* `[none]`  
3. **never** sends the final `[wifi]` ➜ any state machine that relies on it will stay **offline forever**.

Real hardware delivers the final `wifi` event and the app comes back online.

### Hard-Bob Rule
ALWAYS verify connectivity logic on a real iPhone / iPad before filing a bug.

### Temporary Probe
`NetworkInfoImpl` contains a **debug-only probe** that logs every raw event with a timestamp:

```dart
void _debugRawEvent(List<ConnectivityResult> r) {
  // TODO(HARD-BOB): Delete before shipping
  if (!kDebugMode) return;
  final s = DateTime.now().toIso8601String();
  _logger.f('[TMP-RAW] $s -> $r');
}
```

Use it to capture the bounce in the simulator; remove the method and its call before releasing.

--- 