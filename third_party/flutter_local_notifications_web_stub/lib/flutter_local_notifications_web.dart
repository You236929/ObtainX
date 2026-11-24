/// Android-only stand-in for `flutter_local_notifications_web`.
///
/// ObtainX ships Android only, so the web implementation of
/// `flutter_local_notifications` never runs. The published package pulls the
/// `web` interop package and JS notification glue that have no use here, so
/// `pubspec.yaml` overrides it with this local package.
///
/// This is not a pure federated implementation: `flutter_local_notifications`
/// imports this library directly and re-exports it from its own public entry
/// point, so the web-only types and the plugin class it references have to
/// exist here. The API below mirrors the part of the published package the
/// Android build can see; every method is inert, because nothing reaches the
/// web path on Android.
library;

import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:timezone/timezone.dart' as tz;

/// Web-specific initialization settings.
///
/// Type only: the Android build never constructs it.
class WebInitializationSettings {
  /// A const constructor, matching the upstream signature.
  const WebInitializationSettings();
}

/// Text direction of a web notification.
enum WebNotificationDirection {
  /// Adopt the browser's setting.
  auto('auto'),

  /// Left to right.
  leftToRight('ltr'),

  /// Right to left.
  rightToLeft('rtl');

  const WebNotificationDirection(this.jsValue);

  /// A string value to pass to JavaScript functions.
  final String jsValue;
}

/// A means for a user to interact with a web notification.
class WebNotificationAction {
  /// A const constructor, matching the upstream signature.
  const WebNotificationAction({
    required this.action,
    required this.title,
    this.icon,
  });

  /// A developer-facing string representing this action.
  final String action;

  /// A user-facing string to be shown next to this action.
  final String title;

  /// An optional icon to display next to the action.
  final Uri? icon;
}

/// Web-specific notification details.
///
/// Field names match the upstream class so `NotificationDetails.web` keeps
/// compiling; nothing reads the values on Android.
class WebNotificationDetails {
  /// A const constructor, matching the upstream signature.
  const WebNotificationDetails({
    this.actions = const <WebNotificationAction>[],
    this.direction = WebNotificationDirection.auto,
    this.badgeUrl,
    this.iconUrl,
    this.lang,
    this.requireInteraction = false,
    this.isSilent = false,
    this.imageUrl,
    this.renotify = false,
    this.timestamp,
  });

  /// Actions sent with the notification.
  final List<WebNotificationAction> actions;

  /// Text direction of the notification.
  final WebNotificationDirection direction;

  /// URL of a monochrome icon shown next to the title.
  final Uri? badgeUrl;

  /// URL of an image shown as the app icon.
  final Uri? iconUrl;

  /// URL of an image shown in the notification.
  final Uri? imageUrl;

  /// BCP 47 language tag of the notification content.
  final String? lang;

  /// Whether the notification stays visible until dismissed.
  final bool requireInteraction;

  /// Whether the notification is silent.
  final bool isSilent;

  /// Whether the user is notified when this notification is replaced.
  final bool renotify;

  /// Timestamp of the event that caused this notification.
  final DateTime? timestamp;
}

/// Permission status for web notifications.
enum WebNotificationPermission {
  /// The user explicitly allowed notifications.
  granted('granted'),

  /// The user explicitly blocked notifications.
  denied('denied'),

  /// The user has not decided yet.
  defaultPermissions('default');

  const WebNotificationPermission(this.name);

  /// The string representation of the permission.
  final String name;
}

/// Inert stand-in for the web plugin.
///
/// The class has to exist because `flutter_local_notifications` refers to it in
/// `resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()`;
/// on Android that branch is never taken, so the methods do nothing instead of
/// touching any JS API.
class WebFlutterLocalNotificationsPlugin
    extends FlutterLocalNotificationsPlatform {
  /// Whether the browser supports the Notification API. Always false here.
  static bool get isSupported => false;

  /// Initializes the plugin; no-op off web.
  Future<bool?> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async => null;

  /// Requests notification permission; no-op off web.
  Future<bool?> requestNotificationsPermission() async => false;

  /// Current permission status; always denied off web.
  WebNotificationPermission get permissionStatus =>
      WebNotificationPermission.denied;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WebNotificationDetails? notificationDetails,
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    WebNotificationDetails? notificationDetails,
  }) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancelAllPendingNotifications() async {}
}
