# UI Playground System

This document explains the purpose and usage of the UI Playground system for rapid UI iteration.

## Purpose

The primary goal of the UI Playground system is to provide sandboxed environments where developers can quickly experiment with UI components and layouts without affecting the main application flow or requiring complex state setup. It allows for:

-   **Rapid Visual Iteration:** Trying out different widget arrangements, styles, and interactions with immediate visual feedback.
-   **Decoupling UI Experiments:** Keeping experimental UI code separate from production-ready code.
-   **Testing Edge Cases:** Easily feeding components with various mock data representing different states (e.g., long text, error states, different data values).
-   **Avoiding Test Overhead for Experiments:** UI experiments in the playground typically don't require dedicated widget tests, saving time during the exploratory phase.

## Playground System Architecture

The playground system consists of:

1. **Central Navigation Hub** (`lib/features/playground/playground_home.dart`): The main entry point providing access to all playground screens.
2. **Feature-Specific Playgrounds**: Individual playground screens focused on specific features or components:
   - **Job List Playground** (`lib/features/jobs/presentation/pages/job_list_playground.dart`): For experimenting with job list UI components
   - **Notification System Playground** (`lib/features/playground/notifier_playground.dart`): For testing the app-wide notification system
   - (Additional feature playgrounds can be added as needed)

## Available Playgrounds

### Job List Playground

- **Purpose**: Test job list UI components and interactions
- **Key Features**:
  - Mock job data visualization
  - Job creation with Lorem Ipsum content
  - Manual sync triggering
  - Offline state simulation (via auth state)
  - Audio recording and playback via RecorderModal
  - File persistence with secure path management

### Notification System Playground

- **Purpose**: Test the general transient notification system
- **Key Features**:
  - Trigger notifications of all types (info, success, warning, error)
  - Test auto-dismiss and manual dismiss behaviors
  - Experiment with rapid sequential notifications

## File Storage in Playground

Files created during playground testing are stored in the application's document directory using the same structure as production:

- **Audio Recordings**: Stored in `<app_documents>/audio/` directory
- **Test Files**: Although persisted to disk, these files are not synced to the server until explicitly triggered
- **Cleanup**: Files created in the playground *are* real files consuming device storage and should be cleaned up periodically during development

## Setup Status

-   [X] Create the core playground screen hub (`lib/features/playground/playground_home.dart`).
-   [X] Create the job list playground (`lib/features/jobs/presentation/pages/job_list_playground.dart`).
-   [X] Create the notification system playground (`lib/features/playground/notifier_playground.dart`).
-   [X] Populate playgrounds with representative mock data and interaction options.
-   [X] Add debug access to the playground system from main application flow.

## Workflow

1. Access the playground system via the designated debug trigger in the app.
2. From the playground home, select the specific playground area relevant to your development needs.
3. Modify the code within the specific playground files and related components.
4. Use hot reload/restart to see changes instantly.
5. Once a design is finalized, transfer the necessary code changes from the playground components back into the production code.
6. Ensure the final production code is covered by appropriate tests (ViewModel tests, Cubit/Notifier tests, widget tests).

## Adding New Playgrounds

To add a new playground screen:

1. Create a new playground file in an appropriate location (usually within the feature it's testing).
2. Implement the UI experimentation components with appropriate mock data.
3. Add the new playground to the `PlaygroundHome` screen's navigation options.
4. Update this documentation to include the new playground details. 