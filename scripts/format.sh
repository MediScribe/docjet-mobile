#!/usr/bin/env bash

# Format Dart files excluding generated files
find . -name "*.dart" \
    -not -path "./.git/*" \
    -not -path "./.dart_tool/*" \
    -not -name "*.g.dart" \
    -not -name "*.freezed.dart" \
    -not -name "*.mocks.dart" \
    -print0 | xargs -0 dart format
