// lib/presentation/providers/notification_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter_application_1/data/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  String? _userId;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _userId != null;
  
  // 초기화
  Future<void> initialize(String userId) async {
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // FCM 초기화 및 알림 권한 요청
      await _notificationService.initialize(userId);
      
      // 구독 스트림 설정 (별도 메서드로 분리)
      _subscribeToNotifications();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('알림 초기화 오류: $_error');
      notifyListeners();
    }
  }
  
  // 알림 스트림 구독
  void _subscribeToNotifications() {
    if (_userId == null) return;
    
    // 알림 목록 스트림 구독
    _notificationService.getNotificationsStream(_userId!).listen(
      (updatedNotifications) {
        _notifications = updatedNotifications;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        print('알림 스트림 오류: $_error');
        notifyListeners();
      },
    );
    
    // 읽지 않은 알림 개수 스트림 구독
    _notificationService.getUnreadNotificationCount(_userId!).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (error) {
        print('읽지 않은 알림 개수 스트림 오류: $error');
      },
    );
  }
  
  // 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    
    try {
      await _notificationService.markAsRead(notificationId);
      // 스트림이 자동으로 업데이트되므로 별도 상태 업데이트 불필요
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    
    try {
      await _notificationService.markAllAsRead(_userId!);
      // 스트림이 자동으로 업데이트되므로 별도 상태 업데이트 불필요
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      // 스트림이 자동으로 업데이트되므로 별도 상태 업데이트 불필요
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // 모든 알림 삭제
  Future<void> deleteAllNotifications() async {
    if (_userId == null) return;
    
    try {
      await _notificationService.deleteAllNotifications(_userId!);
      // 스트림이 자동으로 업데이트되므로 별도 상태 업데이트 불필요
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // 사용자 검색 (멘션용)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      return await _notificationService.searchUsersByNickname(query);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
  
  // 서비스 워커 상태 확인 (디버깅용, 웹 전용)
  Future<bool> checkServiceWorkerStatus() async {
    if (!kIsWeb) return false;
    return await _notificationService.checkServiceWorkerStatus();
  }
  
  // 로그아웃 시 FCM 토큰 제거
  Future<void> unregisterFCMToken() async {
    if (_userId == null) return;
    
    try {
      await _notificationService.unregisterFCMToken(_userId!);
    } catch (e) {
      print('FCM 토큰 제거 오류: $e');
    }
  }
}