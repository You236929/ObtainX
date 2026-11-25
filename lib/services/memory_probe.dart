// Startup memory probe (opt-in).
//
// ObtainX's resident set after launch has been reported around 350 MB on
// Android, which is high for a Flutter app of this size. Guessing which
// allocation owns that number is unproductive, so this probe samples the
// process at fixed points after the first frame and writes the samples to the
// in-app log, where they can be read back with "Export logs" or logcat.
//
// It is compiled out unless the build passes
//   --dart-define=OBTAINX_MEMORY_PROBE=true
// so release builds keep their normal behaviour.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:obtainium/providers/logs_provider.dart';

/// Whether this build samples memory after startup.
const bool memoryProbeEnabled = bool.fromEnvironment('OBTAINX_MEMORY_PROBE');

/// Set by [main] so the samples can report how much app data is loaded.
typedef MemoryProbeContext = ({int appCount, int folderCount});

/// Samples at these offsets after the first frame. The first sample is the
/// post-first-frame baseline, the later ones show what the initial app load,
/// icon decoding and first painted list add on top.
const List<Duration> memoryProbeOffsets = [
  Duration.zero,
  Duration(seconds: 3),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// Runs [onSample] for each offset in [memoryProbeOffsets]. No-op unless
/// [memoryProbeEnabled]; call it once, after the first frame is scheduled.
Future<void> scheduleMemoryProbe(
  MemoryProbeContext Function() context, {
  Future<void> Function(String message)? sink,
}) async {
  if (!memoryProbeEnabled) return;
  final DateTime start = DateTime.now();
  for (final Duration offset in memoryProbeOffsets) {
    final Duration wait = offset - DateTime.now().difference(start);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    final String line = memorySampleLine(context(), offset);
    debugPrint(line);
    unawaited((sink ?? LogsProvider().add)(line));
  }
}

/// One readable sample: resident set, peak resident set, decoded-image cache
/// and how much app data is in memory.
@visibleForTesting
String memorySampleLine(MemoryProbeContext context, Duration offset) {
  final int rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
  final int maxRssMb = ProcessInfo.maxRss ~/ (1024 * 1024);
  final ImageCache cache = PaintingBinding.instance.imageCache;
  final int cacheMb = cache.currentSizeBytes ~/ (1024 * 1024);
  return 'memory probe +${offset.inSeconds}s: '
      'rss=${rssMb}MB peak=${maxRssMb}MB '
      'imageCache=${cacheMb}MB (${cache.liveImageCount} live, '
      '${cache.currentSize} entries, limit ${cache.maximumSize}, '
      '${cache.maximumSizeBytes ~/ (1024 * 1024)}MB) '
      'apps=${context.appCount} folders=${context.folderCount}';
}
