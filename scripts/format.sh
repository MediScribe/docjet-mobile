#!/bin/bash

# Format Dart files excluding generated files
find . -name "*.dart" -not -path "*.g.dart" -not -path "*.freezed.dart" -not -path "*.mocks.dart" | xargs dart format