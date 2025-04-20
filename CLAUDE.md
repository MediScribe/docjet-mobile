# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands
- `flutter pub get` - Install dependencies
- `flutter pub run build_runner build` - Generate code (mocks, JSON serializers)
- `flutter pub run build_runner build --delete-conflicting-outputs` - Force code generation
- `flutter analyze` - Run static analysis
- `flutter test` - Run all tests
- `flutter test test/path/to/test_file.dart` - Run specific test file
- `flutter test test/path/to/test_file.dart --name="test name"` - Run specific test
- `flutter pub run build_runner watch` - Watch for code changes and generate code

## Code Style Guidelines
- Use camelCase for variables/functions, PascalCase for classes
- Organize imports logically: dart, flutter, packages, then project imports
- Error handling: use Either<Failure, T> for repositories, throw exceptions in data sources
- Generate mocks for tests with @GenerateMocks annotations
- Follow clean architecture: separate data, domain, and presentation layers
- Use logger with LoggerFactory.getLogger(Class) for consistent logging
- Models: use freezed/copyWith for immutability and domain objects
- Tests: use descriptive test names that explain the scenario and expected outcome