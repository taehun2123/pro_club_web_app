// lib/data/services/fcm_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FCM 초기화 및 권한 요청
  Future<void> initialize(String userId) async {
    await dotenv.load(fileName: ".env"); // .env 파일 로드
    // 웹 환경에서만 VAPID 키 사용
    if (kIsWeb) {
      // 권한 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('푸시 알림 권한 허용됨');
        final apiKey = dotenv.env['VAPID_KEY'];

        // 웹 푸시를 위한 VAPID 키 (Firebase 콘솔에서 생성)
        String? token = await _messaging.getToken(
          vapidKey: apiKey, // Firebase 콘솔에서 생성된 웹 푸시 인증서 키
        );

        if (token != null) {
          print('FCM 토큰: $token');
          // 토큰을 Firestore에 저장
          await _saveTokenToDatabase(userId, token);
        }
      } else {
        print('푸시 알림 권한 거부됨');
      }
    } else {
      // 모바일 환경에서는 기존 코드 사용
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM 토큰: $token');
        await _saveTokenToDatabase(userId, token);
      }
    }

    // 포그라운드 메시지 핸들러 설정
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 메시지 수신: ${message.notification?.title}');
      // 앱이 열려 있을 때 알림 처리는 Flutter 앱에서 직접 처리
      // (필요하면 여기에 로컬 알림 표시 로직 추가)
    });

    // 백그라운드에서 알림 클릭 시 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('알림 클릭됨: ${message.notification?.title}');
      // 알림 클릭 처리 (특정 화면으로 이동 등)
    });

    // 앱이 종료된 상태에서 알림 클릭은 main.dart에서 처리해야 함
  }

  // 토큰을 Firestore에 저장
  Future<void> _saveTokenToDatabase(String userId, String token) async {
    try {
      // 중복 방지를 위해 토큰 존재 여부 확인 후 추가
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      print('토큰 저장 오류: $e');
    }
  }

  // 토픽 구독 (공지사항 등 전체 알림용)
  Future<void> subscribeToTopics() async {
    // 웹 환경이 아닌 경우에만 토픽 구독 실행
    if (!kIsWeb) {
      try {
        // 모바일 환경에서만 토픽 구독 실행
        await FirebaseMessaging.instance.subscribeToTopic("all_notices");
        print('토픽 구독 성공: all_notices');
      } catch (e) {
        print('토픽 구독 오류: $e');
      }
    } else {
      // 웹 환경에서는 토픽 대신 개별 디바이스 토큰 관리
      print('웹 환경에서는 토픽 구독이 지원되지 않습니다. 대신 개별 FCM 토큰을 사용합니다.');

      // 웹에서는 사용자 문서에 토큰을 저장하는 방식으로 구현
      // 이미 AuthService._updateFCMToken()에서 처리되고 있음
    }
  }

  // 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('토픽 구독 해제: $topic');
  }
}
