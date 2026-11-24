/// Android-only stand-in for `flutter_charset_detector_web`.
///
/// ObtainX ships Android only, so the web implementation of
/// `flutter_charset_detector` is never compiled into the app. The real package
/// brings `flutter_web_plugins` and a bundled jschardet asset that have no use
/// here, so `pubspec.yaml` overrides it with this local package: the federated
/// plugin graph stays valid, but nothing web-specific is pulled into the build.
///
/// If the app ever targets web, this throws instead of silently returning
/// wrong text; switch back to the published `flutter_charset_detector_web`.
library;

import 'dart:typed_data';

import 'package:flutter_charset_detector_platform_interface/decoding_result.dart';
import 'package:flutter_charset_detector_platform_interface/flutter_charset_detector_platform_interface.dart';

/// Constant message shared by the unimplemented methods.
const String _unsupportedMessage =
    'flutter_charset_detector_web is stubbed out in this build '
    '(ObtainX targets Android only).';

/// Throwing stand-in for the web implementation of [CharsetDetectorPlatform].
///
/// It is never registered as a platform instance on Android; the override
/// exists so the web side of the federated plugin resolves without the real
/// package.
class CharsetDetectorWeb extends CharsetDetectorPlatform {
  @override
  Future<DecodingResult> autoDecode(Uint8List bytes) =>
      throw UnsupportedError(_unsupportedMessage);

  @override
  Future<String> detect(Uint8List bytes) =>
      throw UnsupportedError(_unsupportedMessage);
}
