import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  mention,      // @멘션 알림
  newNotice,    // 새 공지사항
  newComment,   // 내 글에 새 댓글
  newReply,     // 내 댓글에 새 대댓글
  hotPost,      // 인기(핫) 게시글
  adminMessage, // 관리자 메시지
}

class AppNotification {
  final String id;
  final String userId;        // 알림을 받을 사용자 ID
  final String title;         // 알림 제목
  final String content;       // 알림 내용
  final NotificationType type; // 알림 유형
  final String? sourceId;     // 관련 글/댓글/공지사항 ID
  final String? senderId;     // 알림을 발생시킨 사용자 ID (멘션, 댓글의 경우)
  final String? senderName;   // 알림을 발생시킨 사용자 이름
  final String? senderProfileImage; // 발신자 프로필 이미지
  final Timestamp createdAt;  // 생성 시간
  final bool isRead;          // 읽음 여부

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.type,
    this.sourceId,
    this.senderId,
    this.senderName,
    this.senderProfileImage,
    required this.createdAt,
    this.isRead = false,
  });

  // Firestore 맵에서 객체 생성
  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    return AppNotification(
      id: docId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.adminMessage,
      ),
      sourceId: map['sourceId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderProfileImage: map['senderProfileImage'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  // 객체를 Firestore 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
      'sourceId': sourceId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileImage': senderProfileImage,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  // 읽음 상태를 변경한 새 객체 생성
  AppNotification copyWithRead({bool read = true}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      content: content,
      type: type,
      sourceId: sourceId,
      senderId: senderId,
      senderName: senderName,
      senderProfileImage: senderProfileImage,
      createdAt: createdAt,
      isRead: read,
    );
  }
}