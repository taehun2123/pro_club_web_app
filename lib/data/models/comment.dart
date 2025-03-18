import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  
  // 대댓글(답글) 관련 필드 추가
  final String? parentId;     // 부모 댓글 ID (대댓글인 경우에만 값 있음)
  final String? mentionedUserId; // 멘션된 사용자 ID (댓글에서 @멘션한 경우)
  final String? mentionedUserName; // 멘션된 사용자 이름

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
    this.mentionedUserId,
    this.mentionedUserName,
  });

  factory Comment.fromMap(Map<String, dynamic> map, String docId) {
    return Comment(
      id: docId,
      postId: map['postId'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorProfileImage: map['authorProfileImage'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'],
      parentId: map['parentId'],
      mentionedUserId: map['mentionedUserId'],
      mentionedUserName: map['mentionedUserName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImage': authorProfileImage,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'parentId': parentId,
      'mentionedUserId': mentionedUserId,
      'mentionedUserName': mentionedUserName,
    };
  }

  // 객체 복사본 생성 (필드 업데이트 시 사용)
  Comment copyWith({
    String? id,
    String? postId,
    String? content,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? parentId,
    String? mentionedUserId,
    String? mentionedUserName,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: parentId ?? this.parentId,
      mentionedUserId: mentionedUserId ?? this.mentionedUserId,
      mentionedUserName: mentionedUserName ?? this.mentionedUserName,
    );
  }

  // 작성일 문자열 (예: "2025년 3월 15일 14:30")
  String get dateString {
    final date = createdAt.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  // 대댓글 여부
  bool get isReply => parentId != null;
}