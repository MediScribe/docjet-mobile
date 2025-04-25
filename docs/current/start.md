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

### Feature Deep Dive: Authentication
*   [Authentication Architecture](./feature-auth-architecture.md)
*   [Authentication Implementation Details](./feature-auth-implementation.md)
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
*   **Description**: Outlines the Clean Architecture principles and layered structure (Presentation, Use Cases, Domain, Data, Core) of the DocJet Mobile application, including specific feature architecture links.

#### [Riverpod Guide](./architecture-riverpod-guide.md)
*   **Description**: Outlines the approach to using Riverpod with code generation (`@riverpod`) for state management, covering provider definition, generation, overrides (often with GetIt), and best practices.

#### [API Versioning](./architecture-api-versioning.md)
*   **Description**: Describes the centralized API versioning strategy using `ApiConfig` and environment variables, ensuring consistency across the app and mock server.

#### [Audio Playback & Reactive State](./architecture-audio-reactive-guide.md)
*   **Description**: Hard-won lessons and guidelines for handling audio playback complexities, reactive stream management (debouncing), state synchronization, and testing to avoid UI flickering and integration issues, based on past failures (`docs/old_system/audio_player_analysis.md`).

### Feature Deep Dive: Authentication
#### [Authentication Architecture](./feature-auth-architecture.md)
*   **Description**: Details the components (Services, Providers, Events, Interceptor, Validator) and flows (Login, Refresh, Offline, Logout) of the authentication system using diagrams and component descriptions.

#### [Authentication Implementation Details](./feature-auth-implementation.md)
*   **Description**: Provides a detailed TODO list and implementation status for enhancing the authentication system, covering exceptions, token validation, events, service interfaces, API client, interceptor, and presentation state.

#### [Authentication Testing Guide](./feature-auth-testing.md)
*   **Description**: Explains the testing strategy for authentication, covering unit, integration, and E2E tests (`test/e2e/auth_flow_test.dart`), including the E2E test architecture and key flows tested.

### Feature Deep Dive: Jobs
#### [Job Data Flow](./feature-job-dataflow.md)
*   **Description**: Details the offline-first, service-oriented data architecture for Jobs, including the dual-ID system, sync strategy (orchestrator/processor), local-first operations, error handling, and component breakdown.

#### [Job Presentation Layer](./feature-job-presentation.md)
*   **Description**: Describes the state management (Cubits, `JobState`), UI interaction patterns, and use case integration for the Job feature's presentation layer (list, details, actions).

### UI & Development Aids
#### [UI Screens Overview](./ui-screens-overview.md)
*   **Description**: Provides an overview of the mobile app's UI screens (Login, Home, Job List, Playground) with a navigation flow diagram, screen purposes, current states, and key widgets.

#### [Playground](./dev-ui-playground.md)
*   **Description**: Describes the UI Playground concept, a sandboxed screen (`job_list_playground.dart`) for rapidly iterating on UI components with mock data, separate from the main application flow. 