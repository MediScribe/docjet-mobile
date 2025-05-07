/// Defines Shelf middleware functions for the mock API server,
/// including a debug middleware for logging request/response details
/// and an authentication middleware for API key validation.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io'; // For HttpStatus
import 'package:shelf/shelf.dart';
import 'package:mock_api_server/src/core/constants.dart'; // For versionedApiPath, expectedApiKey
import 'package:mock_api_server/src/config.dart'; // For verboseLoggingEnabled

// Debug middleware to log request details
Middleware debugMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (verboseLoggingEnabled) {
        print('=== DEBUG: Incoming Request ===');
        print('Method: ${request.method}, URL: ${request.url}');
        print('Headers: ${request.headers}');
      }

      // Add special debug for multipart content type
      if (verboseLoggingEnabled &&
          request.headers['content-type'] != null &&
          request.headers['content-type']!
              .toLowerCase()
              .contains('multipart/form-data')) {
        print('MULTIPART REQUEST DETECTED:');
        print('Full Content-Type: ${request.headers['content-type']}');
      }

      // Create a copy of the request for logging so we don't consume the body
      String? bodyContent;
      Request requestForHandler;

      // For non-multipart requests, try to read and log the body
      if (request.headers['content-type'] != null &&
          !request.headers['content-type']!.startsWith('multipart/form-data')) {
        try {
          bodyContent = await request.readAsString();
          if (verboseLoggingEnabled) print('Body: $bodyContent');

          // Create a new request with the same body since we consumed it
          requestForHandler = Request(
            request.method,
            request.requestedUri,
            body: bodyContent,
            headers: Map.from(request.headers),
            context: Map.from(request.context),
            encoding: request.encoding,
            onHijack: request.hijack,
          );
        } catch (e) {
          if (verboseLoggingEnabled) print('Could not read body: $e');
          requestForHandler = request;
        }
      } else if (request.headers['content-type'] != null &&
          request.headers['content-type']!.startsWith('multipart/form-data')) {
        if (verboseLoggingEnabled) {
          print(
              'Body: [multipart form data detected - not displaying raw body]');
        }
        requestForHandler = request;
      } else {
        requestForHandler = request;
      }

      Response response;
      try {
        // Call the next handler with our possibly modified request
        response = await innerHandler(requestForHandler);
      } catch (e) {
        if (verboseLoggingEnabled) {
          print('=== DEBUG: Handler Error ===');
          print('Error: $e');
          print('=============================');
        }
        rethrow; // Re-throw so shelf can handle it
      }

      if (verboseLoggingEnabled) {
        print('=== DEBUG: Outgoing Response ===');
        print('Status: ${response.statusCode}');
        print('Headers: ${response.headers}');
      }

      // Log error responses but don't try to read the body
      if (verboseLoggingEnabled && response.statusCode >= 400) {
        print('Error response status: ${response.statusCode}');
      }

      if (verboseLoggingEnabled) print('=============================');
      return response;
    };
  };
}

// Middleware for handling authorization (both API key and potentially JWT later)
// Apply API Key check globally here, simplifying the pipeline
Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.requestedUri.path;

      // Skip API key check for health and ALL debug endpoints
      if (path == '/$versionedApiPath/health' ||
          path.startsWith('/$versionedApiPath/debug/')) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG AUTH MIDDLEWARE: Skipping auth for health or debug endpoint: $path');
        }
        return innerHandler(request);
      }

      // All other endpoints require authentication
      if (verboseLoggingEnabled) {
        print('DEBUG AUTH MIDDLEWARE: Checking API key for path: $path');
      }

      final apiKey = request.headers['x-api-key'];
      if (apiKey != expectedApiKey) {
        if (verboseLoggingEnabled) {
          print(
              'DEBUG AUTH MIDDLEWARE: API Key validation FAILED. Expected \'$expectedApiKey\', got \'$apiKey\'');
        }
        return Response(
          HttpStatus.unauthorized, // Use HttpStatus constant
          body: jsonEncode({'error': 'Missing or invalid X-API-Key header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (verboseLoggingEnabled) {
        print(
            'DEBUG AUTH MIDDLEWARE: API Key validation PASSED for path: $path');
      }

      // If we are here, API key is valid for non-debug/health endpoints
      return innerHandler(request);
    };
  };
}
