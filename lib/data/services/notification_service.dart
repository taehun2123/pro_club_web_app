import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // 컬렉션 참조
  CollectionReference get _notificationsRef =>
      _firestore.collection('notifications');
  CollectionReference get _usersRef => _firestore.collection('users');

  // FCM 토큰 등록 (웹 및 모바일 푸시 알림용)
  Future<void> registerFCMToken(String userId) async {
    try {
      // FCM 권한 요청
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 토큰 가져오기 (웹에서는 VAPID 키 필요)
        String? token;
        if (kIsWeb) {
          // 웹에서 토큰 가져오기 (VAPID 키 필요)
          final vapidKey = dotenv.env['VAPID_KEY'];
          token = await _messaging.getToken(
            vapidKey: vapidKey, // Firebase 콘솔에서 생성한 웹 푸시 인증서 키
          );
          print('웹 FCM 토큰: $token');
        } else {
          // 모바일에서 토큰 가져오기
          token = await _messaging.getToken();
          print('모바일 FCM 토큰: $token');
        }

        if (token != null) {
          // 기존 토큰 목록 확인
          final userDoc = await _usersRef.doc(userId).get();
          final userData = userDoc.data() as Map<String, dynamic>?;

          if (userData != null) {
            List<String> existingTokens = [];
            if (userData.containsKey('fcmTokens') &&
                userData['fcmTokens'] is List) {
              existingTokens = List<String>.from(userData['fcmTokens']);
            }

            // 중복 토큰 방지
            if (!existingTokens.contains(token)) {
              await _usersRef.doc(userId).update({
                'fcmTokens': FieldValue.arrayUnion([token]),
              });
              print('FCM 토큰 등록 성공: $token');
            }
          } else {
            // 사용자 문서가 없는 경우
            await _usersRef.doc(userId).set({
              'fcmTokens': [token],
            }, SetOptions(merge: true));
          }

          // 웹에서는 토픽 구독 추가
          if (kIsWeb) {
            await _messaging.subscribeToTopic('all_notices');
            print('웹 알림 토픽 구독 성공: all_notices');
          }
        }
      } else {
        print('FCM 권한 거부됨: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('FCM 토큰 등록 오류: $e');
    }
  }


  // FCM 토큰 삭제 (로그아웃 시)
  Future<void> unregisterFCMToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _usersRef.doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });

        // 토픽 구독 해제 (웹)
        if (kIsWeb) {
          await _messaging.unsubscribeFromTopic('all_notices');
        }

        // 토큰 삭제
        await _messaging.deleteToken();
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
        .map((snapshot) {
          try {
            return snapshot.docs
                .map(
                  (doc) => AppNotification.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();
          } catch (e) {
            print('알림 처리 오류: $e');
            return [];
          }
        });
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
      final querySnapshot =
          await _notificationsRef
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
      final querySnapshot =
          await _notificationsRef.where('userId', isEqualTo: userId).get();

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
  // 멘션 알림 생성 메서드 수정 - FCM 웹 푸시 알림 추가
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
      content:
          content.length > 100 ? '${content.substring(0, 97)}...' : content,
      type: NotificationType.mention,
      sourceId: sourceId,
      senderId: mentionerId,
      senderName: mentionerName,
      senderProfileImage: mentionerProfileImage,
      createdAt: Timestamp.now(),
    );

    final docRef = await addNotification(notification);
    // Cloud Functions가 알림 문서 생성을 감지하여 푸시 알림을 보냅니다
    print('멘션 알림 생성 완료 (ID: $docRef). Cloud Functions에서 푸시 알림 처리 예정');
  }

  // 새 공지사항 알림 생성 메서드 수정 - FCM 웹 푸시 추가
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

        notifications.add(
          AppNotification(
            id: '',
            userId: userId,
            title: '새 공지사항',
            content: noticeTitle,
            type: NotificationType.newNotice,
            sourceId: noticeId,
            senderId: null,
            senderName: authorName,
            createdAt: Timestamp.now(),
          ),
        );
      }

      // 배치 처리
      final batch = _firestore.batch();

      for (final notification in notifications) {
        final newNotificationDoc = _notificationsRef.doc();
        batch.set(newNotificationDoc, notification.toMap());
      }

      await batch.commit();
      
      // 여기서 직접 FCM을 호출하지 않습니다.
      // Cloud Functions에서 자동으로 처리되도록 합니다.
      print('새 공지사항 알림 생성 완료. Cloud Functions에서 푸시 알림 처리 예정');
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
      content:
          commentContent.length > 100
              ? '${commentContent.substring(0, 97)}...'
              : commentContent,
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
      content:
          replyContent.length > 100
              ? '${replyContent.substring(0, 97)}...'
              : replyContent,
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
      final usersSnapshot =
          await _usersRef.where('hotPostNotification', isEqualTo: true).get();

      final List<AppNotification> notifications = [];

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        // 게시글 작성자에게는 알림을 보내지 않음
        if (userId == postAuthorId) continue;

        notifications.add(
          AppNotification(
            id: '',
            userId: userId,
            title: '인기 게시글',
            content: postTitle,
            type: NotificationType.hotPost,
            sourceId: postId,
            senderId: postAuthorId,
            senderName: postAuthorName,
            createdAt: Timestamp.now(),
          ),
        );
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
  required String sourceId,
  required String sourceType,
}) async {
  print('멘션 처리 시작: $content');
  
  // @username 형식의 멘션 패턴 찾기 (기본 패턴)
  final mentionPattern = RegExp(r'@([^\s@]+)');
  final matches = mentionPattern.allMatches(content);
  
  if (matches.isEmpty) {
    print('멘션 없음');
    return;
  }
  
  // 멘션된 사용자 목록 (중복 제거)
  final Set<String> mentionedUsernames = {};
  
  for (final match in matches) {
    final username = match.group(1);
    if (username != null && username.isNotEmpty) {
      mentionedUsernames.add(username);
      print('멘션된 사용자: $username');
    }
  }
  
  for (final username in mentionedUsernames) {
    try {
      // 수정된 부분: nickname의 시작 부분이 일치하는 사용자 검색
      print('사용자 검색: $username');
      
      // 먼저 정확히 일치하는 사용자 검색
      var querySnapshot = await _usersRef
          .where('nickname', isEqualTo: username)
          .limit(1)
          .get();
      
      // 정확히 일치하는 사용자가 없으면 시작 부분이 일치하는 사용자 검색
      if (querySnapshot.docs.isEmpty) {
        // 시작 부분이 일치하는 사용자 검색 (Firebase는 startsWith를 직접 지원하지 않음)
        final endOfRange = username + '\uf8ff'; // Unicode 상한값
        querySnapshot = await _usersRef
            .where('nickname', isGreaterThanOrEqualTo: username)
            .where('nickname', isLessThan: endOfRange)
            .limit(1)
            .get();
      }
      
      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userId = userDoc.id;
        final foundNickname = (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '';
        print('사용자 발견: $userId, $foundNickname');
        
        // 자기 자신을 멘션한 경우 알림을 보내지 않음
        if (userId == authorId) {
          print('자신을 멘션함, 알림 생성 안함');
          continue;
        }
        
        // 알림 생성
        print('알림 생성 시작: 멘션 알림');
        final notification = AppNotification(
          id: '',
          userId: userId,
          title: '$authorName님이 회원님을 언급했습니다',
          content: content.length > 100 ? '${content.substring(0, 97)}...' : content,
          type: NotificationType.mention,
          sourceId: sourceId,
          senderId: authorId,
          senderName: authorName,
          senderProfileImage: authorProfileImage,
          createdAt: Timestamp.now(),
        );
        
        final docRef = await _notificationsRef.add(notification.toMap());
        print('알림 생성 완료: ${docRef.id}');
      } else {
        print('사용자를 찾을 수 없음: $username');
      }
    } catch (e) {
      print('멘션 처리 오류 (사용자: $username): $e');
    }
  }
}

  // lib/data/services/notification_service.dart 파일에 추가할 메서드

  // 사용자 검색 (멘션용) - 닉네임, 이름, 프로필 정보 포함
  // 한글 검색을 지원하는 searchUsersByNickname 메서드
  Future<List<Map<String, dynamic>>> searchUsersByNickname(String query) async {
    try {
      if (query.isEmpty) {
        // 모든 사용자를 가져오되 제한된 수만 (최근 가입순)
        final querySnapshot =
            await _usersRef
                .orderBy('createdAt', descending: true)
                .limit(15)
                .get();

        return querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'nickname': data['nickname'] ?? '',
            'profileImage': data['profileImage'],
          };
        }).toList();
      }

      // Firebase Text Search는 한글 부분 일치 검색을 직접 지원하지 않으므로
      // 모든 사용자를 가져와서 클라이언트에서 필터링하는 방식 사용
      // (실제 프로덕션 환경에서는 Full-Text 검색 서비스 사용 권장)
      final querySnapshot =
          await _usersRef
              .orderBy('nickname')
              .limit(50) // 성능을 위해 개수 제한
              .get();

      final nameQuerySnapshot =
          await _usersRef
              .orderBy('name')
              .limit(50) // 성능을 위해 개수 제한
              .get();

      // 결과 합치기 (중복 제거)
      final Map<String, Map<String, dynamic>> results = {};

      // 가져온 모든 사용자에 대해 로컬에서 부분 일치 필터링
      void processResults(QuerySnapshot snapshot, String field) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final fieldValue = (data[field] ?? '').toString().toLowerCase();
          final lowerQuery = query.toLowerCase();

          // 부분 일치 검색
          if (fieldValue.contains(lowerQuery)) {
            if (!results.containsKey(doc.id)) {
              results[doc.id] = {
                'id': doc.id,
                'name': data['name'] ?? '',
                'nickname': data['nickname'] ?? '',
                'profileImage': data['profileImage'],
                'matchScore': fieldValue.indexOf(
                  lowerQuery,
                ), // 일치 점수 (낮을수록 더 정확한 일치)
              };
            }
          }
        }
      }

      // 닉네임과 이름으로 검색
      processResults(querySnapshot, 'nickname');
      processResults(nameQuerySnapshot, 'name');

      // 결과를 일치 점수 기준으로 정렬하여 반환
      final sortedResults =
          results.values.toList()..sort(
            (a, b) =>
                (a['matchScore'] as int).compareTo(b['matchScore'] as int),
          );

      // 최대 10개만 반환
      return sortedResults.take(10).map((item) {
        // matchScore는 제외하고 반환
        final Map<String, dynamic> result = {...item};
        result.remove('matchScore');
        return result;
      }).toList();
    } catch (e) {
      print('사용자 검색 오류: $e');
      return [];
    }
  }
}
