// lib/data/models/post.dart with RichContent support
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_application_1/data/models/rich_content.dart';

class Post {
  final String id;
  final String title;
  final String content; // 기존 호환성을 위해 String 타입 유지
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final int viewCount;
  final int commentCount;
  final List<String>? attachments;
  final String tag; // 태그 필드 추가
  final String? customTag; // 커스텀 태그 필드 추가
  final List<String> likedBy; // 좋아요한 사용자 ID 목록
  final List<String> dislikedBy; // 싫어요한 사용자 ID 목록

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
    this.tag = '자유', // 기본 태그는 '자유'
    this.customTag,
    this.likedBy = const [],
    this.dislikedBy = const [],
  });

  // 팩토리 메서드 추가: RichContent를 사용하는 버전
  factory Post.withRichContent({
    required String id,
    required String title,
    required RichContent richContent,
    required String authorId,
    required String authorName,
    String? authorProfileImage,
    required Timestamp createdAt,
    Timestamp? updatedAt,
    int viewCount = 0,
    int commentCount = 0,
    List<String>? attachments,
    String tag = '자유',
    String? customTag,
    List<String> likedBy = const [],
    List<String> dislikedBy = const [],
  }) {
    return Post(
      id: id,
      title: title,
      content: richContent.jsonContent,
      authorId: authorId,
      authorName: authorName,
      authorProfileImage: authorProfileImage,
      createdAt: createdAt,
      updatedAt: updatedAt,
      viewCount: viewCount,
      commentCount: commentCount,
      attachments: attachments,
      tag: tag,
      customTag: customTag,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
    );
  }

  // RichContent 객체로 변환하는 getter
  RichContent get richContent {
    // content가 유효한 JSON인지 확인
    if (RichContent.isValidJson(content)) {
      return RichContent(jsonContent: content);
    } else {
      // 유효하지 않으면 일반 텍스트로 변환
      return RichContent.fromPlainText(content);
    }
  }

  // 좋아요 및 싫어요 수 계산
  int get likeCount => likedBy.length;
  int get dislikeCount => dislikedBy.length;

  // 태그 표시 텍스트
  String get displayTag => tag == '기타' && customTag != null ? customTag! : tag;

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
      tag: map['tag'] ?? '자유',
      customTag: map['customTag'],
      likedBy: map['likedBy'] != null ? List<String>.from(map['likedBy']) : [],
      dislikedBy: map['dislikedBy'] != null ? List<String>.from(map['dislikedBy']) : [],
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
      'tag': tag,
      'customTag': customTag,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
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
    String? tag,
    String? customTag,
    List<String>? likedBy,
    List<String>? dislikedBy,
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
      tag: tag ?? this.tag,
      customTag: customTag ?? this.customTag,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
    );
  }

  // 작성일 문자열 (예: "2025년 3월 15일")
  String get dateString {
    final date = createdAt.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 사용자가 해당 게시글에 좋아요했는지 확인
  bool isLikedBy(String userId) {
    return likedBy.contains(userId);
  }

  // 사용자가 해당 게시글에 싫어요했는지 확인
  bool isDislikedBy(String userId) {
    return dislikedBy.contains(userId);
  }
}