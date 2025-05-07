import 'package:shelf_router/shelf_router.dart';

// Temporary imports for handlers from server.dart
// These will be updated in later cycles when handlers are moved.
import '../../bin/server.dart'
    show
        healthHandler,
        loginHandler,
        refreshHandler,
        getUserMeHandler,
        createJobHandler,
        listJobsHandler,
        getJobByIdHandler,
        getJobDocumentsHandler,
        updateJobHandler,
        deleteJobHandler;

// Import handlers from debug_handlers.dart (already in its correct location)
import 'package:mock_api_server/src/debug_handlers.dart';

// Import constants (versionedApiPath)
import '../core/constants.dart';

// Define the router with versioned endpoints
final router = Router() // Renamed from _router to router (public)
  // Health check (prefixed)
  ..get('/$versionedApiPath/health', healthHandler)

  // Authentication endpoints (prefixed)
  ..post('/$versionedApiPath/auth/login', loginHandler)
  ..post('/$versionedApiPath/auth/refresh-session', refreshHandler)

  // User profile endpoints (prefixed)
  ..get('/$versionedApiPath/users/me', getUserMeHandler)

  // Job endpoints (prefixed)
  ..post('/$versionedApiPath/jobs', createJobHandler)
  ..get('/$versionedApiPath/jobs', listJobsHandler)
  ..get('/$versionedApiPath/jobs/<jobId>', getJobByIdHandler)
  ..get('/$versionedApiPath/jobs/<jobId>/documents', getJobDocumentsHandler)
  ..patch('/$versionedApiPath/jobs/<jobId>', updateJobHandler)
  ..delete('/$versionedApiPath/jobs/<jobId>', deleteJobHandler)

  // Debug endpoints for job progression (Use handlers from debug_handlers.dart)
  ..post('/$versionedApiPath/debug/jobs/start', startJobProgressionHandler)
  ..post('/$versionedApiPath/debug/jobs/stop', stopJobProgressionHandler)
  ..post('/$versionedApiPath/debug/jobs/reset', resetJobProgressionHandler)

  // Debug endpoint for listing all jobs - requires standard API key auth
  ..get('/$versionedApiPath/debug/jobs/list', listAllJobsHandler);
