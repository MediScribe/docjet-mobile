# UI Cupertino Conversion Plan

This document tracks the progress of converting UI components to use Cupertino widgets for a native iOS look and feel. Android adaptiveness will be handled later.

**Target Platform:** iOS (using Cupertino widgets)

## Components to Convert/Check:

- [X] `lib/features/jobs/presentation/pages/job_list_page.dart`
    - Convert `Scaffold` -> `CupertinoPageScaffold`
    - Convert `AppBar` -> `CupertinoNavigationBar`
    - Convert `CircularProgressIndicator` -> `CupertinoActivityIndicator`
    - Update `ListView.builder` if needed (checked, OK)
    - Add `SafeArea`
    - Add debug button for playground navigation (Done in this step).
- [X] `lib/features/jobs/presentation/pages/job_list_playground.dart`
    - Convert base structure to `CupertinoPageScaffold`, etc.
    - Convert `AppBar`/`IconButton` -> `CupertinoNavigationBar`/`CupertinoButton`
    - Convert `ElevatedButton` -> `CupertinoButton`
    - Remove `FloatingActionButton`
    - Add `SafeArea`
    - Ensure mock data setup is compatible (checked, OK).
- [X] `lib/features/jobs/presentation/widgets/job_list_item.dart`
    - Check `ListTile` usage (Kept for now, visually acceptable).
    - Change `Icon` usage to `CupertinoIcons` (Done).
    - Check `Text` usage (Checked, OK).
    - Update imports (Done).
    - Review overall iOS look & feel (Addressed via icons).
- [X] **Navigation**
    - Use `CupertinoPageRoute` when navigating *to* the playground from `JobListPage` (Done).

## Workflow:

1.  Refactor one component at a time.
2.  Run `dart analyze` after changes.
3.  Visually verify on an iOS simulator/device.
4.  Update this checklist. 