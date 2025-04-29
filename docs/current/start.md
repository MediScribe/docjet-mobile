# Documentation Index

This document serves as the central index for the project documentation.

## Table of Contents

### Overall Specification
*   [Specification](./project-specification.md)

### Setup & Configuration
*   [Environment Configuration](./setup-environment-config.md)
*   [Mock Server Integration](./setup-mock-server.md)

### Architecture & Core Concepts
*   [Overall Architecture](./architecture-overview.md)
*   [Riverpod Guide](./architecture-riverpod-guide.md)
*   [API Versioning](./architecture-api-versioning.md)
*   [Audio Playback & Reactive State](./architecture-audio-reactive-guide.md)
*   [UI Theming System](../features/feature-ui-theming.md)

### Feature Deep Dive: Authentication
*   [Authentication Architecture](./feature-auth-architecture.md)
*   [Authentication Testing Guide](./feature-auth-testing.md)

### Feature Deep Dive: Jobs
*   [Job Data Flow](./feature-job-dataflow.md)
*   [Job Presentation Layer](./feature-job-presentation.md)

### UI & Development Aids
*   [UI Screens Overview](./ui-screens-overview.md)
*   [Playground](./dev-ui-playground.md)

---

## Document Descriptions

### Overall Specification
#### [Specification](./project-specification.md)
*   **Description**: Details the overall system specification for the DocJet platform, including purpose, components (mobile, web, API, AI), mobile app UX/UI, data structures, API endpoints, and the end-to-end workflow.

### Setup & Configuration
#### [Environment Configuration](./setup-environment-config.md)
*   **Description**: Guide on setting environment variables (`API_KEY`, `API_DOMAIN`) via `secrets.json` or `--dart-define`, including mock server setup (`run_with_mock.sh`) and URL construction logic.

#### [Mock Server Integration](./setup-mock-server.md)
*   **Description**: Explains how to use the mock API server for development and testing, covering setup (like `run_with_mock.sh`), configuration (`secrets.test.json`), testing integration, and common troubleshooting steps.

### Architecture & Core Concepts
#### [Overall Architecture](./architecture-overview.md)
*   **Description**: Outlines the Clean Architecture principles and layered structure (Presentation, Use Cases, Domain, Data, Core) of the DocJet Mobile application, including specific feature architectures, offline profile caching system, and the centralized theming system for consistent UI.

#### [Riverpod Guide](./architecture-riverpod-guide.md)
*   **Description**: Outlines the approach to using Riverpod with code generation (`@riverpod`) for state management, covering provider definition, generation, overrides (often with GetIt), and best practices.

#### [API Versioning](./architecture-api-versioning.md)
*   **Description**: Describes the centralized API versioning strategy using `ApiConfig` and environment variables, ensuring consistency across the app and mock server.

#### [Audio Playback & Reactive State](./architecture-audio-reactive-guide.md)
*   **Description**: Hard-won lessons and guidelines for handling audio playback complexities, reactive stream management (debouncing), state synchronization, and testing to avoid UI flickering and integration issues, based on past failures (`docs/old_system/audio_player_analysis.md`).

#### [UI Theming System](../features/feature-ui-theming.md)
*   **Description**: Documents the application's theming architecture based on Flutter's ThemeExtension mechanism, including semantic color tokens (like `dangerBg`, `offlineBg`, `primaryActionBg`), light/dark theme support, and theme-aware components that automatically adapt to system settings.

### Feature Deep Dive: Authentication
#### [Authentication Architecture](./feature-auth-architecture.md)
*   **Description**: Details the components (Services, Providers, Events, Interceptor, Validator, Profile Cache) and flows (Login, Refresh, Offline, Logout) of the authentication system, including offline profile caching with SharedPreferences and connectivity event handling via AuthEventBus.

#### [Authentication Testing Guide](./feature-auth-testing.md)
*   **Description**: Explains the testing strategy for authentication, covering unit, integration, and E2E tests (`test/e2e/auth_flow_test.dart`), including the E2E test architecture and key flows tested.

### Feature Deep Dive: Jobs
#### [Job Data Flow](./feature-job-dataflow.md)
*   **Description**: Details the offline-first, service-oriented data architecture for Jobs, including the dual-ID system, sync strategy (orchestrator/processor), local-first operations, error handling, and integration with auth connectivity events (`offlineDetected`/`onlineRestored`).

#### [Job Presentation Layer](./feature-job-presentation.md)
*   **Description**: Describes the state management (Cubits, `JobState`), UI interaction patterns, offline-aware components, and use case integration for the Job feature's presentation layer, including how components observe the authNotifierProvider to adapt to offline states.

### UI & Development Aids
#### [UI Screens Overview](./ui-screens-overview.md)
*   **Description**: Provides an overview of the mobile app's UI screens (Login, Home, Job List, Playground) with navigation flow diagrams, screen purposes, comprehensive offline behavior, and the global OfflineBanner and AppShell components that provide consistent UI across the app.

#### [Playground](./dev-ui-playground.md)
*   **Description**: Describes the UI Playground concept, a sandboxed screen (`job_list_playground.dart`) for rapidly iterating on UI components with mock data, separate from the main application flow.

## Project Documentation

The `docs/` directory contains detailed documentation on various aspects of the project:

*   **`docs/current/`**: Contains the most up-to-date guides for active development.
    *   `logging_guide.md`: Comprehensive details on the logging system and testing patterns.
    *   `setup-environment-config.md`: **Crucial guide** explaining how to configure the app for different environments (local dev, staging, prod) using runtime DI and `--dart-define`.
    *   `explicit-di-revisited.md`: Detailed plan and status for the migration to explicit dependency injection.
    *   `architecture-api-versioning.md`: Explanation of the centralized API versioning strategy.
    *   `setup-mock-server.md`: Information specifically about setting up and running the mock API server.
    *   Various feature-specific documents.
*   **`docs/adr/`**: Architecture Decision Records, documenting significant technical choices.
*   **`docs/features/`**: Feature-specific documentation such as the UI theming system and implementation details.

Key guides to read first:
- `setup-environment-config.md`: Understand how to run the app locally vs. for release.
- `logging_guide.md`: Learn how to use the logging system effectively.
- `explicit-di-revisited.md`: Grasp the dependency injection patterns.
- `architecture-overview.md`: Understand the app's structure, including offline capabilities.

For details on running the app with the mock server, testing integration, and common troubleshooting steps, refer primarily to `setup-environment-config.md` and `setup-mock-server.md`. 