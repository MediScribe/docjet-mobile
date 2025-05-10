// This file will contain state variables for debug features.
import 'dart:async';

/// Stores active progression timers, keyed by job ID.
final Map<String, Timer> jobProgressionTimers = {};

/// The defined sequence of job statuses for progression.
const List<String> jobStatusProgression = [
  // 'created', // REMOVED: Server receives jobs starting at 'submitted'
  'submitted',
  'transcribing',
  'transcribed',
  'generating',
  'generated',
  'completed',
];
