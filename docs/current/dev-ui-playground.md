# UI Playground Concept

This document explains the purpose and usage of the UI Playground feature for rapid UI iteration.

## Purpose

The primary goal of the UI Playground is to provide a sandboxed environment where developers can quickly experiment with UI components and layouts without affecting the main application flow or requiring complex state setup. It allows for:

-   **Rapid Visual Iteration:** Trying out different widget arrangements, styles, and interactions with immediate visual feedback.
-   **Decoupling UI Experiments:** Keeping experimental UI code separate from production-ready code.
-   **Testing Edge Cases:** Easily feeding components with various mock data representing different states (e.g., long text, error states, different data values).
-   **Avoiding Test Overhead for Experiments:** UI experiments in the playground typically don't require dedicated widget tests, saving time during the exploratory phase.

## Key Components

-   **Playground Screen:** A dedicated screen (`lib/features/jobs/presentation/pages/job_list_playground.dart`) that hosts the UI components under development.
-   **Mock Data:** The playground screen uses hardcoded mock data (`JobViewModel` instances inside `_JobListPlaygroundState`) to simulate various scenarios.
-   **UI Variant Controls:** Buttons or other controls within the playground allow switching between different experimental layouts or component states (e.g., 'List View' vs 'Grid View' buttons).
-   **Debug Access Trigger:** A non-production mechanism (e.g., a swipe gesture) on the *real* screen (`lib/features/jobs/presentation/pages/job_list_page.dart`) to navigate to the playground.

## Setup TODO

-   [X] Create the core playground screen (`lib/features/jobs/presentation/pages/job_list_playground.dart`).
-   [X] Populate the playground with representative mock data.
-   [X] Add basic UI variant controls (e.g., buttons) to the playground.
-   [X] Refactor playground screen to use Cupertino widgets (`CupertinoPageScaffold`, etc.).
-   [X] Add a debug **button** to the production screen (`lib/features/jobs/presentation/pages/job_list_page.dart`) to trigger navigation.
-   [X] Implement navigation from the production screen to the playground screen using `CupertinoPageRoute`.
-   [X] Fix `ListTile` error by wrapping it in a `Material` widget within `JobListItem` (`lib/features/jobs/presentation/widgets/job_list_item.dart`).

## Workflow

1.  Use the debug gesture on the relevant production screen (e.g., Job List) to open the playground.
2.  Use the controls within the playground to switch between UI variants or test different data.
3.  Modify the code within `job_list_playground.dart` and/or the specific widgets (like `lib/features/jobs/presentation/widgets/job_list_item.dart`) being tested.
4.  Use hot reload/restart to see changes instantly.
5.  Once a design is finalized, transfer the necessary code changes from the playground/widgets back into the production widgets/pages.
6.  Ensure the final production code is covered by appropriate tests (ViewModel tests, Cubit tests, potentially Golden tests for stable UI). 