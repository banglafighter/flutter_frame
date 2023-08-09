import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:fr_common/fr_common.dart';
import 'package:fr_core/fr_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'rapid_push_notify_callback.dart';
import 'package:fr_http/fr_http_export.dart' as http;

class RapidPushNotifyManager {
  static final RapidPushNotifyManager _pushNotifyManager = RapidPushNotifyManager._internal();

  factory RapidPushNotifyManager() {
    return _pushNotifyManager;
  }
  RapidPushNotifyManager._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  String? _groupKey;
  RapidPushNotifyCallback? _pushNotifyCallback;

  Future<void> init({String androidIcon = "push_notify_icon", String? groupKey, RapidPushNotifyCallback? pushNotifyCallback}) async {
    AndroidInitializationSettings initAndroidSettings = AndroidInitializationSettings(androidIcon);
    IOSInitializationSettings initIosSettings = IOSInitializationSettings(requestSoundPermission: true, requestBadgePermission: true, requestAlertPermission: true, onDidReceiveLocalNotification: iOSNotificationReceived);
    InitializationSettings initializationSettings = InitializationSettings(android: initAndroidSettings, iOS: initIosSettings);

    _groupKey = groupKey;
    _pushNotifyCallback = pushNotifyCallback;

    await _notificationsPlugin.initialize(initializationSettings, onSelectNotification: onSelectNotification);
  }

  void iOSNotificationReceived(int id, String? title, String? body, String? payload) {
    if(_pushNotifyCallback != null){
      _pushNotifyCallback!.iOSNotificationReceived(id, title, body, payload);
    }
  }

  void onSelectNotification(String? payload) {
    if(_pushNotifyCallback != null){
      _pushNotifyCallback!.onSelectNotification(payload);
    }
  }

  String getRandString({int len = 12}) {
    var random = Random.secure();
    var values = List<int>.generate(len, (i) =>  random.nextInt(255));
    return base64UrlEncode(values).replaceAll("==", "");
  }

  Future<String?> getLargeIconPath({String? largeIconUrl, String? largeIconPath}) async {
    if (largeIconPath != null) {
      return largeIconPath;
    }
    try {
      if (largeIconUrl != null) {
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/${getRandString()}.png';
        final http.Response response = await http.get(Uri.parse(largeIconUrl!));
        if (response.statusCode == 200) {
          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          return filePath;
        }
      }
    } on Exception {
      // Ignore
    }
    return null;
  }

  Future<NotificationDetails> _getNotifyDetails({
    String channelId = "android-notify",
    String channelName = "AndroidNotify",
    bool playSound = false,
    bool enableVibration = false,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    String? ticker = "ticker",
    Color? color,
    String? largeIconUrl,
    String? largeIconPath,
    StyleInformation? styleInformation,
    bool hideExpandedLargeIcon = false,
  }) async {

    largeIconPath = await getLargeIconPath(largeIconPath: largeIconPath, largeIconUrl: largeIconUrl);
    FilePathAndroidBitmap? androidBitmap;
    if (largeIconPath != null) {
      androidBitmap = FilePathAndroidBitmap(largeIconPath);
      styleInformation ??= BigPictureStyleInformation(androidBitmap, hideExpandedLargeIcon: hideExpandedLargeIcon);
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      playSound: playSound,
      enableVibration: enableVibration,
      importance: importance,
      priority: priority,
      ticker: ticker,
      color: color,
      groupKey: _groupKey,
      largeIcon: androidBitmap,
      styleInformation: styleInformation,
    );
    IOSNotificationDetails iOSDetails = IOSNotificationDetails();

    NotificationDetails notificationDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);
    return notificationDetails;
  }

  Future<void> notify(
    int id, {
    String? title,
    String? body,
    String? payload,
    String channelId = "android-notify",
    String channelName = "AndroidNotify",
    bool playSound = false,
    bool enableVibration = false,
    Importance importance = Importance.max,
    Priority priority = Priority.max,
    String? ticker = "ticker",
    Color? color,
    String? largeIconUrl,
    String? largeIconPath,
    StyleInformation? styleInformation,
    bool hideExpandedLargeIcon = false,
    RepeatInterval? repeatInterval,
    bool androidAllowWhileIdle = false,
  }) async {
    NotificationDetails details = await _getNotifyDetails(
      channelId: channelId,
      channelName: channelName,
      playSound: playSound,
      enableVibration: enableVibration,
      importance: importance,
      priority: priority,
      ticker: ticker,
      color: color,
      largeIconUrl: largeIconUrl,
      largeIconPath: largeIconPath,
      styleInformation: styleInformation,
      hideExpandedLargeIcon: hideExpandedLargeIcon,
    );
    if(repeatInterval != null){
      await _notificationsPlugin.periodicallyShow(id, title, body, repeatInterval, details, payload: payload, androidAllowWhileIdle: androidAllowWhileIdle);
    }else{
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
    }
  }

  void cancelAll() {
    _notificationsPlugin.cancelAll();
  }

  void cancel(int id, {String? tag}) {
    _notificationsPlugin.cancel(id, tag: tag);
  }

  static RapidPushNotifyManager get inst => RapidPushNotifyManager();
}