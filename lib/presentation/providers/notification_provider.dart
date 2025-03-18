import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter_application_1/data/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  
  // 스트림 구독
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _unreadCountSubscription;
  
  // Getters
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  
  // 초기화 (사용자 로그인 시 호출)
  void initialize(String userId) {
    _disposeSubscriptions();
    
    // FCM 토큰 등록 (모바일 푸시 알림용)
    if (!kIsWeb) {
      _notificationService.registerFCMToken(userId);
    }
    
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
  }
  
  // 정리 (사용자 로그아웃 시 호출) - 메서드 이름 변경
  void clearNotifications(String userId) {
    _disposeSubscriptions();
    
    // FCM 토큰 삭제
    if (!kIsWeb) {
      _notificationService.unregisterFCMToken(userId);
    }
    
    _notifications = [];
    _unreadCount = 0;
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
      // 실시간 스트림으로 이미 업데이트되므로 별도로 상태 업데이트 필요 없음
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
      // 실시간 스트림으로 이미 업데이트되므로 별도로 상태 업데이트 필요 없음
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