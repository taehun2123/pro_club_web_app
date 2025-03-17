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