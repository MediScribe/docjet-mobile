# DocJet Mobile UI Screens

This document provides an overview of all the screens and significant UI components in the DocJet Mobile application.

## Screen Navigation Flow

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    %% Main App Entry Point
    MainApp[App Entry<br>main.dart] --> AuthCheck{Is User<br>Authenticated?}
    
    %% Authentication Flow
    AuthCheck -->|No| LoginScreen(LoginScreen)
    AuthCheck -->|Yes| HomeScreen(HomeScreen)
    
    %% Normal Navigation Paths
    HomeScreen -->|"Logout (via AuthNotifier)"| LoginScreen
    HomeScreen -->|Future Nav| JobListPage(JobListPage)
    
    %% Jobs Feature Navigation
    JobListPage -->|"Debug Mode<br>Only"| JobListPlayground(JobListPlayground)
    JobListPage -->|"Future: Tap on Job"| JobDetailPage("JobDetailPage<br>(Not Yet Implemented)")
    
    %% Planned Future Navigation (WIP)
    HomeScreen -.->|Future Nav (WIP)| TranscriptionsPage(TranscriptionsPage)
    
    %% Future Navigation
    HomeScreen -.->|"Future"| SettingsPage("SettingsPage<br>(Not Yet Implemented)")
```

## Authentication Screens

### LoginScreen
- **Path**: `lib/features/auth/presentation/screens/login_screen.dart`
- **Purpose**: Allows users to authenticate by entering their credentials
- **Current State**: Placeholder implementation that displays "Login Screen Placeholder"
- **Key Features**:
  - Displays an offline indicator when in offline mode
  - Will be expanded to include email/password fields and login button

## Main Application Screens

### HomeScreen
- **Path**: `lib/features/home/presentation/screens/home_screen.dart`
- **Purpose**: Main screen shown after authentication, serves as an entry point to app features
- **Current State**: Placeholder implementation showing user ID
- **Key Features**:
  - Displays the authenticated user's ID
  - Contains a logout button in the app bar
  - TODO: Will incorporate navigation to `JobListPage` and other features, including the planned `TranscriptionsPage`.

### TranscriptionsPage [WIP]
- **Path**: `lib/features/home/presentation/pages/transcriptions_page.dart`
- **Purpose**: [Future] Intended to show a list of transcriptions (replacing the simpler `JobListPage` eventually or co-existing).
- **Current State**: Skeleton implementation exists but is not currently integrated into the main navigation flow.
- **Key Features**:
  - Contains placeholder UI elements.
  - Includes a `RecordButton` for initiating new recordings (future functionality).
  - UI Components intended for this page are being developed and tested in the `JobListPlayground`.

## Jobs Feature Screens

### JobListPage
- **Path**: `lib/features/jobs/presentation/pages/job_list_page.dart`
- **Purpose**: Displays a list of jobs (simpler view, potentially temporary before `TranscriptionsPage` is fully implemented).
- **Current State**: Fully implemented with BLoC pattern.
- **Key Features**:
  - Shows loading indicators during data fetching
  - Displays a list of JobListItem widgets for each job
  - Shows appropriate error messages when needed
  - Displays "No jobs yet" message when the list is empty

### JobListPlayground
- **Path**: `lib/features/jobs/presentation/pages/job_list_playground.dart`
- **Purpose**: Development sandbox for rapidly iterating on UI components (like `JobListItem`, `RecordButton`) intended for the `TranscriptionsPage`.
- **Current State**: Fully implemented with experimental features and mock data.
- **Key Features**:
  - Shows the job list with mock data
  - Contains buttons for testing job creation
  - Accessible via a debug button in JobListPage (only in debug builds)

## Navigation and Routing

The application uses a simple routing approach:

1. **Initial Route**: Determined in `main.dart` based on authentication state
   - If authenticated: Shows `HomeScreen`
   - If not authenticated: Shows `LoginScreen`

2. **Manual Navigation**:
   - From `JobListPage` to `JobListPlayground` using `Navigator.push` with `CupertinoPageRoute`

3. **Future Navigation Needs**:
   - Navigation from `HomeScreen` to `JobListPage` 
   - Detailed job view navigation from `JobListPage`
   - Navigation to settings or profile screens

## UI Widgets

### Record Buttons
- `lib/features/home/presentation/widgets/record_button.dart` - Intended for use in the future `TranscriptionsPage`.
- `lib/features/jobs/presentation/widgets/record_button.dart` - Used in `JobListPlayground` for testing/iteration (potentially reusable).

### JobListItem
- **Path**: `lib/features/jobs/presentation/widgets/job_list_item.dart`
- **Purpose**: Renders a single job item in the list
- **Key Features**:
  - Displays job title, sync status, and date
  - Shows warning icon for jobs with file issues
  - Uses Cupertino styling for consistent iOS-like appearance 