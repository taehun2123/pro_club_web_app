// lib/data/models/notice.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final bool important;
  final List<String>? attachments; // 첨부 파일 URL 목록 추가

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.important = false,
    this.attachments,
  });

  factory Notice.fromMap(Map<String, dynamic> map, String docId) {
    return Notice(
      id: docId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'],
      important: map['important'] ?? false,
      attachments:
          map['attachments'] != null
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'important': important,
      'attachments': attachments,
    };
  }

  // 공지사항 객체 복사본 생성 (필드 업데이트 시 사용)
  Notice copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? important,
    List<String>? attachments, // 첨부 파일 목록 추가
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      important: important ?? this.important,
      attachments: attachments ?? this.attachments,
    );
  }
}
