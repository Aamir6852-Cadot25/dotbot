import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class Notifier {
  Future<void> show(String title, String body);
}

class RecordingNotifier implements Notifier {
  final shown = <(String, String)>[];
  @override
  Future<void> show(String title, String body) async => shown.add((title, body));
}

class LocalNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _id = 0;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'Dotbot',
          appUserModelId: 'dev.dotbot.app',
          guid: '6f1c1f0e-7a52-4a0c-9b1e-3d1f6f7d2a10',
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<void> show(String title, String body) async {
    await init();
    await _plugin.show(
      id: _id++ % 100000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('mentor', 'Mentor',
            importance: Importance.defaultImportance,
            styleInformation: BigTextStyleInformation('')),
      ),
    );
  }
}
