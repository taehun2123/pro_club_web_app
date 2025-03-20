// lib/presentation/providers/notification_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter_application_1/data/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isInitialized = false; // 초기화 상태 추적

  // 스트림 구독
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _unreadCountSubscription;

  // Getters
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // 초기화 (사용자 로그인 시 호출)

  Future<void> initialize(String userId) async {
    if (_isInitialized && _notificationsSubscription != null) {
      // 이미 초기화된 경우 중복 초기화 방지
      return;
    }

    _disposeSubscriptions();
    _isLoading = true;
    notifyListeners();

    try {
      // FCM 토큰 등록 (웹 및 모바일 푸시 알림용)
      await _notificationService.registerFCMToken(userId);

      // 알림 목록 구독
      _notificationsSubscription = _notificationService
          .getNotificationsStream(userId)
          .listen((notifications) {
            _notifications = notifications;
            notifyListeners();
          });

      // 읽지 않은 알림 개수 구독
      _unreadCountSubscription = _notificationService
          .getUnreadNotificationCount(userId)
          .listen((count) {
            _unreadCount = count;
            notifyListeners();
          });

      _isInitialized = true;
    } catch (e) {
      print('알림 초기화 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 정리 (사용자 로그아웃 시 호출)
  Future<void> clearNotifications(String userId) async {
    _disposeSubscriptions();

    // FCM 토큰 삭제
    if (!kIsWeb) {
      try {
        await _notificationService.unregisterFCMToken(userId);
      } catch (e) {
        print('FCM 토큰 삭제 오류: $e');
      }
    }

    _notifications = [];
    _unreadCount = 0;
    _isInitialized = false;
    notifyListeners();
  }

  void _disposeSubscriptions() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _notificationsSubscription = null;
    _unreadCountSubscription = null;
  }

  // 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      // 로컬 상태 업데이트 (스트림 업데이트를 기다리지 않고 즉시 반영)
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final updatedNotification = _notifications[index].copyWithRead();
        _notifications[index] = updatedNotification;
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      print('알림 읽음 처리 오류: $e');
      rethrow;
    }
  }

  // 모든 알림 읽음 처리
  Future<void> markAllAsRead(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _notificationService.markAllAsRead(userId);

      // 로컬 상태 업데이트
      _notifications = _notifications.map((n) => n.copyWithRead()).toList();
      _unreadCount = 0;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('모든 알림 읽음 처리 오류: $e');
      rethrow;
    }
  }

  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);

      // 로컬 상태 업데이트
      final wasUnread = _notifications.any(
        (n) => n.id == notificationId && !n.isRead,
      );
      _notifications.removeWhere((n) => n.id == notificationId);
      if (wasUnread) {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
      notifyListeners();
    } catch (e) {
      print('알림 삭제 오류: $e');
      rethrow;
    }
  }

  // 모든 알림 삭제
  Future<void> deleteAllNotifications(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _notificationService.deleteAllNotifications(userId);

      // 로컬 상태 업데이트
      _notifications = [];
      _unreadCount = 0;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('모든 알림 삭제 오류: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposeSubscriptions();
    super.dispose();
  }
}
