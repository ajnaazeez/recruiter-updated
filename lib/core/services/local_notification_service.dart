import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import '../../router.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS, configure the settings
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final context = rootNavigatorKey.currentContext;
          if (context != null) {
            String targetPath = response.payload!;
            Map<String, dynamic> extras = {};
            if (targetPath.startsWith('{')) {
              try {
                final data = jsonDecode(targetPath);
                targetPath = data['path'];
                extras = data['extra'] ?? {};
              } catch (e) {
                // Ignore json parse error
              }
            }
            context.push(targetPath, extra: extras);
          }
        }
      },
    );

    // Setup FCM Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        String? payload;
        final data = message.data;
        if (data['type'] == 'chat' && data['chatId'] != null) {
          payload = jsonEncode({
            'path': '/chat/${data['chatId']}',
            'extra': {
              'otherUserId': data['otherUserId'] ?? '',
              'candidateName': data['senderName'] ?? 'Candidate',
            }
          });
        }

        _flutterLocalNotificationsPlugin.show(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: message.notification?.title ?? 'Notification',
          body: message.notification?.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'push_channel_id',
              'Push Notifications',
              channelDescription: 'Remote push notifications from Firebase',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: payload, // Used when tapped on foreground FCM notification
        );
      }
    });

    // Handle OS-level background notifications clicked
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'chat' && data['chatId'] != null) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
           context.push('/chat/${data['chatId']}', extra: {
              'otherUserId': data['otherUserId'] ?? '',
              'candidateName': data['senderName'] ?? 'Candidate',
           });
        }
      }
    });

    // Handle application opened from OS-level notification when the app was fully killed
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      if (data['type'] == 'chat' && data['chatId'] != null) {
        // Wait briefly for router to mount, or rely on splash screen
        Future.delayed(const Duration(milliseconds: 500), () {
          final context = rootNavigatorKey.currentContext;
          if (context != null) {
             context.push('/chat/${data['chatId']}', extra: {
                'otherUserId': data['otherUserId'] ?? '',
                'candidateName': data['senderName'] ?? 'Candidate',
             });
          }
        });
      }
    }
  }

  static Future<void> requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // FCM Permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'message_channel_id',
      'Chats & Messages',
      channelDescription: 'Notifications for incoming candidate messages',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Message',
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> showApplicationNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'application_channel_id',
      'Job Applications',
      channelDescription: 'Notifications for new job applications',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'New Application',
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}

