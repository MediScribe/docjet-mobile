# Documentation Index

This document serves as the central index for the project documentation.

## Table of Contents

### Overall Specification
*   [Specification (`OLD: spec.md` -> `NEW: project-specification.md`)](./project-specification.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

### Setup & Configuration
*   [Environment Configuration (`OLD: environment_config.md` -> `NEW: setup-environment-config.md`)](./setup-environment-config.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Mock Server Integration (`OLD: mock_server_integration.md` -> `NEW: setup-mock-server.md`)](./setup-mock-server.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

### Architecture & Core Concepts
*   [Overall Architecture (`OLD: architecture.md` -> `NEW: architecture-overview.md`)](./architecture-overview.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Riverpod Guide (`OLD: riverpod_guide.md` -> `NEW: architecture-riverpod-guide.md`)](./architecture-riverpod-guide.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [API Versioning (`OLD: api_versioning.md` -> `NEW: architecture-api-versioning.md`)](./architecture-api-versioning.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

### Feature Deep Dive: Authentication
*   [Authentication Architecture (`OLD: auth_architecture.md` -> `NEW: feature-auth-architecture.md`)](./feature-auth-architecture.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Authentication Implementation Details (`OLD: auth_impl.md` -> `NEW: feature-auth-implementation.md`)](./feature-auth-implementation.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Authentication Testing Guide (`OLD: auth_testing_guide.md` -> `NEW: feature-auth-testing.md`)](./feature-auth-testing.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

### Feature Deep Dive: Jobs
*   [Job Data Flow (`OLD: job_dataflow.md` -> `NEW: feature-job-dataflow.md`)](./feature-job-dataflow.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Job Presentation Layer (`OLD: job_presentation_layer.md` -> `NEW: feature-job-presentation.md`)](./feature-job-presentation.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

### UI & Development Aids
*   [UI Screens Overview (`OLD: ui_screens.md` -> `NEW: ui-screens-overview.md`)](./ui-screens-overview.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   [Playground (`OLD: playground.md` -> `NEW: dev-ui-playground.md`)](./dev-ui-playground.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs

---

## Document Descriptions

### Overall Specification
#### [Specification (`OLD: spec.md` -> `NEW: project-specification.md`)](./project-specification.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Details the overall system specification for the DocJet platform, including purpose, components (mobile, web, API, AI), mobile app UX/UI, data structures, API endpoints, and the end-to-end workflow.

### Setup & Configuration
#### [Environment Configuration (`OLD: environment_config.md` -> `NEW: setup-environment-config.md`)](./setup-environment-config.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Guide on setting environment variables (`API_KEY`, `API_DOMAIN`) via `secrets.json` or `--dart-define`, including mock server setup (`run_with_mock.sh`) and URL construction logic.

#### [Mock Server Integration (`OLD: mock_server_integration.md` -> `NEW: setup-mock-server.md`)](./setup-mock-server.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Explains how to use the mock API server for development and testing, covering setup (like `run_with_mock.sh`), configuration (`secrets.test.json`), testing integration, and common troubleshooting steps.

### Architecture & Core Concepts
#### [Overall Architecture (`OLD: architecture.md` -> `NEW: architecture-overview.md`)](./architecture-overview.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Outlines the Clean Architecture principles and layered structure (Presentation, Use Cases, Domain, Data, Core) of the DocJet Mobile application, including specific feature architecture links.

#### [Riverpod Guide (`OLD: riverpod_guide.md` -> `NEW: architecture-riverpod-guide.md`)](./architecture-riverpod-guide.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Outlines the approach to using Riverpod with code generation (`@riverpod`) for state management, covering provider definition, generation, overrides (often with GetIt), and best practices.

#### [API Versioning (`OLD: api_versioning.md` -> `NEW: architecture-api-versioning.md`)](./architecture-api-versioning.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Describes the centralized API versioning strategy using `ApiConfig` and environment variables, ensuring consistency across the app and mock server.

### Feature Deep Dive: Authentication
#### [Authentication Architecture (`OLD: auth_architecture.md` -> `NEW: feature-auth-architecture.md`)](./feature-auth-architecture.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Details the components (Services, Providers, Events, Interceptor, Validator) and flows (Login, Refresh, Offline, Logout) of the authentication system using diagrams and component descriptions.

#### [Authentication Implementation Details (`OLD: auth_impl.md` -> `NEW: feature-auth-implementation.md`)](./feature-auth-implementation.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Provides a detailed TODO list and implementation status for enhancing the authentication system, covering exceptions, token validation, events, service interfaces, API client, interceptor, and presentation state.

#### [Authentication Testing Guide (`OLD: auth_testing_guide.md` -> `NEW: feature-auth-testing.md`)](./feature-auth-testing.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Explains the testing strategy for authentication, covering unit, integration, and E2E tests (`test/e2e/auth_flow_test.dart`), including the E2E test architecture and key flows tested.

### Feature Deep Dive: Jobs
#### [Job Data Flow (`OLD: job_dataflow.md` -> `NEW: feature-job-dataflow.md`)](./feature-job-dataflow.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Details the offline-first, service-oriented data architecture for Jobs, including the dual-ID system, sync strategy (orchestrator/processor), local-first operations, error handling, and component breakdown.

#### [Job Presentation Layer (`OLD: job_presentation_layer.md` -> `NEW: feature-job-presentation.md`)](./feature-job-presentation.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Describes the state management (Cubits, `JobState`), UI interaction patterns, and use case integration for the Job feature's presentation layer (list, details, actions).

### UI & Development Aids
#### [UI Screens Overview (`OLD: ui_screens.md` -> `NEW: ui-screens-overview.md`)](./ui-screens-overview.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Provides an overview of the mobile app's UI screens (Login, Home, Job List, Playground) with a navigation flow diagram, screen purposes, current states, and key widgets.

#### [Playground (`OLD: playground.md` -> `NEW: dev-ui-playground.md`)](./dev-ui-playground.md)
    *   [x] Find refs
    *   [x] Rename file
    *   [x] Fix refs
*   **Description**: Describes the UI Playground concept, a sandboxed screen (`job_list_playground.dart`) for rapidly iterating on UI components with mock data, separate from the main application flow. 