import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:obtainium/http/response_bytes.dart';

/// Connection and repository-response ownership for one update operation.
/// A new operation always starts fresh; parallel app checks share in-flight work.
class SourceRequestSession {
  static final Object _zoneKey = Object();
  final Map<bool, HttpClient> _clients = {};
  final Map<String, Future<http.Response>> _repositoryResponses = {};
  // Site-level batch prefetch (see AppSource.prefetchBatchUpdate): one request
  // answers several apps, and the per-app requests then take their answer here
  // instead of hitting the network again.
  final Map<String, http.Response> _prefetchedResponses = {};
  bool _closed = false;

  static SourceRequestSession? get current {
    final session = Zone.current[_zoneKey] as SourceRequestSession?;
    return session?._closed == false ? session : null;
  }

  static Future<T> run<T>(Future<T> Function() action) async {
    if (current != null) return action();
    final session = SourceRequestSession();
    try {
      return await runZoned(action, zoneValues: {_zoneKey: session});
    } finally {
      session._closed = true;
      session._repositoryResponses.clear();
      session._prefetchedResponses.clear();
      for (final client in session._clients.values) {
        client.close();
      }
      session._clients.clear();
    }
  }

  HttpClient clientFor(bool allowInsecure) {
    return _clients.putIfAbsent(allowInsecure, () {
      final client = HttpClient()
        ..maxConnectionsPerHost = 8
        ..connectionTimeout = sourceConnectionTimeout;
      if (allowInsecure) {
        client.badCertificateCallback = (_, _, _) => true;
      }
      return client;
    });
  }

  /// Keeps [response] for [url] so the next GET of that URL in this session
  /// resolves from memory. [url] is the request URL after the source's
  /// prefetch modifier, i.e. the key [takePrefetchedResponse] is asked for.
  void prefetchResponse(String url, http.Response response) {
    if (_closed) return;
    _prefetchedResponses[url] = response;
  }

  /// The prefetched answer for [url], consumed so a later request of the same
  /// URL (a second check in the same session) is not served stale data.
  http.Response? takePrefetchedResponse(String url) =>
      _prefetchedResponses.remove(url);

  Future<http.Response> repositoryResponse(
    String key,
    Future<http.Response> Function() load,
  ) async {
    final pending = _repositoryResponses.putIfAbsent(key, load);
    try {
      final response = await pending;
      // A missing index stays missing for this operation, so the next app from
      // the same repo skips that URL shape; other failures are retried.
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.notFound &&
          response.statusCode != HttpStatus.gone &&
          identical(_repositoryResponses[key], pending)) {
        unawaited(_repositoryResponses.remove(key));
      }
      return response;
    } catch (_) {
      if (identical(_repositoryResponses[key], pending)) {
        unawaited(_repositoryResponses.remove(key));
      }
      rethrow;
    }
  }
}
