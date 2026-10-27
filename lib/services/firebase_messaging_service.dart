import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static FlutterLocalNotificationsPlugin? _localNotifications;

  // Initialize Firebase Messaging
  static Future<void> initialize() async {
    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM permission granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('FCM provisional permission granted');
    } else {
      debugPrint('FCM permission denied');
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _saveFCMToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((_) => _saveFCMToken());

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message if app was terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // Initialize local notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'petguardian_messages',
      'PetGuardian Mesajlar',
      description: 'Yeni mesaj bildirimleri',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Save FCM token to Firestore
  static Future<void> _saveFCMToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token == null) return;

      User? user = _auth.currentUser;
      if (user == null) return;

      // Save to SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      // Save to the owner-only subcollection. The security rules forbid
      // writing `fcmToken` onto the profile itself (any signed-in user can
      // read a profile, and a leaked token lets a third party address push
      // notifications to this device).
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('fcm')
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Remove any token left on the profile by older builds.
      await _firestore.collection('users').doc(user.uid).set(
        {'fcmToken': FieldValue.delete()},
        SetOptions(merge: true),
      );

      debugPrint('FCM token saved: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');

    // Show local notification
    await _showLocalNotification(message);
  }

  // Handle background messages (top-level function calls this)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message received: ${message.messageId}');
    // Background handling is limited, but we can log or store data
  }

  // Handle notification tap (app in background/terminated)
  static void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    // Navigation will be handled by the app's routing
    // Data is available in message.data
  }

  // Handle local notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications!.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'petguardian_messages',
            'PetGuardian Mesajlar',
            channelDescription: 'Yeni mesaj bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  // Send FCM notification to specific user (client-side placeholder).
  //
  // A client can never send FCM directly: that requires the server key, and
  // reading another user's push token is blocked by the security rules (it
  // now lives in the owner-only `private/fcm` document). Delivery must be
  // implemented as a Cloud Function triggered by the Firestore write; this
  // method only logs the intent so the call sites keep compiling.
  static Future<void> sendNotificationToUser({
    required String targetUserUID,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    debugPrint(
      'FCM push queued for Cloud Function delivery: to=$targetUserUID, '
      'title=$title, body=$body',
    );
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  // Delete FCM token (on logout)
  static Future<void> deleteFCMToken() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // The token now lives in the owner-only subcollection; delete the
        // document and clean up the legacy profile field in one pass.
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('private')
            .doc('fcm')
            .delete();
        await _firestore.collection('users').doc(user.uid).set(
          {'fcmToken': FieldValue.delete()},
          SetOptions(merge: true),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}