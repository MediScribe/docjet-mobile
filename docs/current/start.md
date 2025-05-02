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
*   [UI Theming System](./feature-ui-theming.md)
*   [Offline Detection System](./feature-offline-detection.md)

### Feature Deep Dive: Authentication
*   [Authentication Architecture](./feature-auth-architecture.md)
*   [Authentication Testing Guide](./feature-auth-testing.md)

### Feature Deep Dive: Jobs
*   [Job Data Flow](./feature-job-dataflow.md)
*   [Job Presentation Layer](./feature-job-presentation.md)

### UI & Development Aids
*   [UI Screens Overview](./ui-screens-overview.md)
*   [Playground](./dev-ui-playground.md)

### Refactoring Efforts (Completed)
*   [Offline Profile Cache TODO](./refactoring/offline-profile-cache-todo.md)
*   [Job Data & Auth Alignment](./refactoring/job_data_auth_alignment_done.md)
*   [API Client DI Refactor](./refactoring/api_client_di_refactor_done.md)
*   [Auth Issues TODO](./refactoring/auth-issues-todo_done.md)
*   [Feature Auth Implementation](./refactoring/feature-auth-implementation_done.md)
*   [Explicit DI Revisited](./refactoring/explicit-di-revisited_done.md)

### TODOs
*   [iOS Password AutoFill Setup](./todos/ios-autofill-setup-todo.md)

### Research
*   [Sync Frameworks](./research/sync_framworks.md)

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
*   **Description**: Outlines the approach to using Riverpod with code generation (`@riverpod`) for state management, covering provider definition, generation, the override pattern using GetIt for dependency injection, and best practices.

#### [API Versioning](./architecture-api-versioning.md)
*   **Description**: Describes the centralized API versioning strategy using `ApiConfig` and environment variables, ensuring consistency across the app and mock server.

#### [Audio Playback & Reactive State](./architecture-audio-reactive-guide.md)
*   **Description**: Hard-won lessons and guidelines for handling audio playback complexities, reactive stream management (debouncing), state synchronization, and testing to avoid UI flickering and integration issues, based on past failures (`docs/old_system/audio_player_analysis.md`).

#### [UI Theming System](./feature-ui-theming.md)
*   **Description**: Documents the application's theming architecture based on Flutter's `ThemeExtension` mechanism, detailing `AppColorTokens`, `app_theme.dart`, semantic color usage, light/dark theme support, and how to add new theme tokens.

#### [Offline Detection System](./feature-offline-detection.md)
*   **Description**: Details the system for detecting network connectivity changes, integrating with the authentication state (`AuthNotifier`), and propagating `OfflineDetected` / `OnlineRestored` events via the `AuthEventBus` for components like the Job sync service to react accordingly.

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
*   **Description**: Provides an overview of the mobile app's UI screens (Login, Home, Job List, Playground) with navigation flow diagrams, screen purposes, comprehensive offline behavior, and the global OfflineBanner and TransientErrorBanner components that provide consistent UI across the app.

#### [Playground](./dev-ui-playground.md)
*   **Description**: Describes the UI Playground concept, a sandboxed screen (`job_list_playground.dart`) for rapidly iterating on UI components with mock data, separate from the main application flow.

### TODOs
#### [iOS Password AutoFill Setup](./todos/ios-autofill-setup-todo.md)
*   **Description**: Detailed guide for configuring iOS Password AutoFill functionality, including Associated Domains setup, Apple Developer Portal configuration, and required server-side implementation of the apple-app-site-association file.

### Refactoring Efforts (Completed)
#### [Offline Profile Cache TODO](./refactoring/offline-profile-cache-todo.md)
*   **Description**: Tracks the tasks and status for refactoring the offline profile caching mechanism. *(Note: This is likely a task list, not conceptual documentation)*

#### [Job Data & Auth Alignment](./refactoring/job_data_auth_alignment_done.md)
*   **Description**: Documents the completed refactoring effort to align Job data handling with authentication state and events. *(Note: Completed refactoring log)*

#### [API Client DI Refactor](./refactoring/api_client_di_refactor_done.md)
*   **Description**: Details the completed refactoring of the API client's dependency injection setup. *(Note: Completed refactoring log)*

#### [Auth Issues TODO](./refactoring/auth-issues-todo_done.md)
*   **Description**: Tracks the resolution of various authentication-related issues. *(Note: This is likely a task list, not conceptual documentation)*

#### [Feature Auth Implementation](./refactoring/feature-auth-implementation_done.md)
*   **Description**: Log of the implementation details and steps taken during the initial build or major refactor of the authentication feature. *(Note: Completed implementation/refactoring log)*

#### [Explicit DI Revisited](./refactoring/explicit-di-revisited_done.md)
*   **Description**: Documents the completed migration towards a more explicit dependency injection pattern throughout the application. *(Note: Completed refactoring log)*

### Research
#### [Sync Frameworks](./research/sync_framworks.md)
*   **Description**: Contains research notes and comparisons of different synchronization frameworks considered for the project.

## Project Documentation

The `docs/` directory contains detailed documentation on various aspects of the project:

*   **`docs/current/`**: Contains the most up-to-date guides for active development.
    *   `logging_guide.md`: Comprehensive details on the logging system and testing patterns.
    *   `setup-environment-config.md`: **Crucial guide** explaining how to configure the app for different environments (local dev, staging, prod) using runtime DI and `--dart-define`.
    *   `explicit-di-revisited_done.md`: Detailed plan and status for the migration to explicit dependency injection (Now under `refactoring/`).
    *   `architecture-api-versioning.md`: Explanation of the centralized API versioning strategy.
    *   `setup-mock-server.md`: Information specifically about setting up and running the mock API server.
    *   Various feature-specific documents.
*   **`docs/adr/`**: Architecture Decision Records, documenting significant technical choices.
*   **`docs/features/`**: Feature-specific documentation such as the UI theming system and implementation details.

Key guides to read first:
- `setup-environment-config.md`: Understand how to run the app locally vs. for release.
- `architecture-overview.md`: Understand the app's structure, including offline capabilities.
- `feature-offline-detection.md`: Understand how connectivity changes are handled.
- `feature-auth-architecture.md`: Grasp the authentication flow and offline caching.
- `feature-job-dataflow.md`: Learn about the offline-first job data handling.

For details on running the app with the mock server, testing integration, and common troubleshooting steps, refer primarily to `setup-environment-config.md` and `setup-mock-server.md`. 