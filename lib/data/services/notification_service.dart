import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // 컬렉션 참조
  CollectionReference get _notificationsRef => _firestore.collection('notifications');
  CollectionReference get _usersRef => _firestore.collection('users');
  
  // FCM 토큰 등록 (모바일 푸시 알림용)
  Future<void> registerFCMToken(String userId) async {
    // 웹에서는 처리하지 않음
    if (kIsWeb) return;
    
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _usersRef.doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    } catch (e) {
      print('FCM 토큰 등록 오류: $e');
    }
  }
  
  // FCM 토큰 삭제 (로그아웃 시)
  Future<void> unregisterFCMToken(String userId) async {
    if (kIsWeb) return;
    
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _usersRef.doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      print('FCM 토큰 삭제 오류: $e');
    }
  }
  
  // 사용자별 알림 목록 조회
  Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
  
  // 사용자의 읽지 않은 알림 개수 조회
  Stream<int> getUnreadNotificationCount(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // 알림 추가
  Future<String> addNotification(AppNotification notification) async {
    try {
      final docRef = await _notificationsRef.add(notification.toMap());
      
      // 사용자의 FCM 토큰 조회 (모바일 푸시 알림용)
      if (!kIsWeb) {
        final userDoc = await _usersRef.doc(notification.userId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        
        if (userData != null && userData['fcmTokens'] != null) {
          final List<dynamic> tokens = userData['fcmTokens'] ?? [];
          
          // FCM 서버 키를 사용하여 푸시 알림 전송 (백엔드에서 처리하는 것이 보안상 더 좋음)
          // 여기서는 생략하고 주석으로만 표시
          // 실제로는 Cloud Functions를 사용하여 구현하는 것이 좋음
        }
      }
      
      return docRef.id;
    } catch (e) {
      print('알림 추가 오류: $e');
      throw e;
    }
  }
  
  // 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('알림 읽음 처리 오류: $e');
      throw e;
    }
  }
  
  // 모든 알림 읽음 처리
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('모든 알림 읽음 처리 오류: $e');
      throw e;
    }
  }
  
  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (e) {
      print('알림 삭제 오류: $e');
      throw e;
    }
  }
  
  // 특정 사용자의 모든 알림 삭제
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('모든 알림 삭제 오류: $e');
      throw e;
    }
  }
  
  // @멘션 알림 생성
  Future<void> createMentionNotification({
    required String mentionedUserId,
    required String mentionerName,
    required String mentionerId,
    String? mentionerProfileImage,
    required String sourceId,
    required String sourceType, // 'post' or 'comment'
    required String content,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: mentionedUserId,
      title: '$mentionerName님이 회원님을 언급했습니다',
      content: content.length > 100 ? '${content.substring(0, 97)}...' : content,
      type: NotificationType.mention,
      sourceId: sourceId,
      senderId: mentionerId,
      senderName: mentionerName,
      senderProfileImage: mentionerProfileImage,
      createdAt: Timestamp.now(),
    );
    
    await addNotification(notification);
  }
  
  // 새 공지사항 알림 생성 (모든 사용자에게)
  Future<void> createNewNoticeNotification({
    required String noticeId,
    required String noticeTitle,
    required String authorName,
  }) async {
    try {
      // 모든 사용자 조회
      final usersSnapshot = await _usersRef.get();
      
      final List<AppNotification> notifications = [];
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        
        notifications.add(AppNotification(
          id: '',
          userId: userId,
          title: '새 공지사항',
          content: noticeTitle,
          type: NotificationType.newNotice,
          sourceId: noticeId,
          senderId: null,
          senderName: authorName,
          createdAt: Timestamp.now(),
        ));
      }
      
      // 배치 처리
      final batch = _firestore.batch();
      
      for (final notification in notifications) {
        final newNotificationDoc = _notificationsRef.doc();
        batch.set(newNotificationDoc, notification.toMap());
      }
      
      await batch.commit();
    } catch (e) {
      print('공지사항 알림 생성 오류: $e');
      throw e;
    }
  }
  
  // 새 댓글 알림 생성
  Future<void> createNewCommentNotification({
    required String postId,
    required String postAuthorId,
    required String postTitle,
    required String commentId,
    required String commentContent,
    required String commentAuthorId,
    required String commentAuthorName,
    String? commentAuthorProfileImage,
  }) async {
    // 자신의 글에 자신이 댓글을 달면 알림을 보내지 않음
    if (postAuthorId == commentAuthorId) return;
    
    final notification = AppNotification(
      id: '',
      userId: postAuthorId,
      title: '$commentAuthorName님이 회원님의 글에 댓글을 남겼습니다',
      content: commentContent.length > 100 ? '${commentContent.substring(0, 97)}...' : commentContent,
      type: NotificationType.newComment,
      sourceId: postId,
      senderId: commentAuthorId,
      senderName: commentAuthorName,
      senderProfileImage: commentAuthorProfileImage,
      createdAt: Timestamp.now(),
    );
    
    await addNotification(notification);
  }
  
  // 새 대댓글 알림 생성
  Future<void> createNewReplyNotification({
    required String postId,
    required String postTitle,
    required String parentCommentId,
    required String parentCommentAuthorId,
    required String replyId,
    required String replyContent,
    required String replyAuthorId,
    required String replyAuthorName,
    String? replyAuthorProfileImage,
  }) async {
    // 자신의 댓글에 자신이 대댓글을 달면 알림을 보내지 않음
    if (parentCommentAuthorId == replyAuthorId) return;
    
    final notification = AppNotification(
      id: '',
      userId: parentCommentAuthorId,
      title: '$replyAuthorName님이 회원님의 댓글에 답글을 남겼습니다',
      content: replyContent.length > 100 ? '${replyContent.substring(0, 97)}...' : replyContent,
      type: NotificationType.newReply,
      sourceId: postId,
      senderId: replyAuthorId,
      senderName: replyAuthorName,
      senderProfileImage: replyAuthorProfileImage,
      createdAt: Timestamp.now(),
    );
    
    await addNotification(notification);
  }
  
  // 인기 게시글 알림 생성 (설정에 따라 선택적으로 받는 사용자에게)
  Future<void> createHotPostNotification({
    required String postId,
    required String postTitle,
    required String postAuthorId,
    required String postAuthorName,
  }) async {
    try {
      // 알림 수신 설정이 켜져 있는 사용자만 조회 (설정 필드 추가 필요)
      final usersSnapshot = await _usersRef
          .where('hotPostNotification', isEqualTo: true)
          .get();
      
      final List<AppNotification> notifications = [];
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        
        // 게시글 작성자에게는 알림을 보내지 않음
        if (userId == postAuthorId) continue;
        
        notifications.add(AppNotification(
          id: '',
          userId: userId,
          title: '인기 게시글',
          content: postTitle,
          type: NotificationType.hotPost,
          sourceId: postId,
          senderId: postAuthorId,
          senderName: postAuthorName,
          createdAt: Timestamp.now(),
        ));
      }
      
      // 배치 처리
      final batch = _firestore.batch();
      
      for (final notification in notifications) {
        final newNotificationDoc = _notificationsRef.doc();
        batch.set(newNotificationDoc, notification.toMap());
      }
      
      await batch.commit();
    } catch (e) {
      print('인기 게시글 알림 생성 오류: $e');
      throw e;
    }
  }
  
  // 사용자 멘션 처리 (게시글/댓글 텍스트에서 @username 형식으로 언급된 사용자를 찾아 알림 발송)
  Future<void> processMentions({
    required String content,
    required String authorId,
    required String authorName,
    String? authorProfileImage,
    required String sourceId, // 게시글 또는 댓글 ID
    required String sourceType, // 'post' 또는 'comment'
  }) async {
    // @username 형식의 멘션 패턴 찾기
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);
    
    if (matches.isEmpty) return;
    
    // 멘션된 사용자 목록 (중복 제거)
    final Set<String> mentionedUsernames = {};
    
    for (final match in matches) {
      final username = match.group(1);
      if (username != null && username.isNotEmpty) {
        mentionedUsernames.add(username);
      }
    }
    
    for (final username in mentionedUsernames) {
      try {
        // 사용자 검색 (nickname 필드로 검색)
        final querySnapshot = await _usersRef
            .where('nickname', isEqualTo: username)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;
          final userId = userDoc.id;
          
          // 자기 자신을 멘션한 경우 알림을 보내지 않음
          if (userId == authorId) continue;
          
          // 알림 생성
          await createMentionNotification(
            mentionedUserId: userId,
            mentionerName: authorName,
            mentionerId: authorId,
            mentionerProfileImage: authorProfileImage,
            sourceId: sourceId,
            sourceType: sourceType,
            content: content,
          );
        }
      } catch (e) {
        print('멘션 처리 오류 (사용자: $username): $e');
        // 개별 오류는 무시하고 계속 진행
      }
    }
  }
}