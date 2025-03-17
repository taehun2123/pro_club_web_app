import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final int viewCount;
  final int commentCount;
  final List<String>? attachments;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.commentCount = 0,
    this.attachments,
  });

  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    return Post(
      id: docId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorProfileImage: map['authorProfileImage'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'],
      viewCount: map['viewCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      attachments: map['attachments'] != null
          ? List<String>.from(map['attachments'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImage': authorProfileImage,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'viewCount': viewCount,
      'commentCount': commentCount,
      'attachments': attachments,
    };
  }

  // 객체 복사본 생성 (필드 업데이트 시 사용)
  Post copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    int? viewCount,
    int? commentCount,
    List<String>? attachments,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      attachments: attachments ?? this.attachments,
    );
  }

  // 작성일 문자열 (예: "2025년 3월 15일")
  String get dateString {
    final date = createdAt.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}