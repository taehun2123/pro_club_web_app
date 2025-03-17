import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/utils/image_utils.dart';

class Gallery {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final List<String> images;
  final Timestamp createdAt;
  final int viewCount;

  Gallery({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.images,
    required this.createdAt,
    this.viewCount = 0,
  });

  factory Gallery.fromMap(Map<String, dynamic> map, String docId) {
    return Gallery(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      viewCount: map['viewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'authorId': authorId,
      'authorName': authorName,
      'images': images,
      'createdAt': createdAt,
      'viewCount': viewCount,
    };
  }

  // 갤러리 객체 복사본 생성 (필드 업데이트 시 사용)
  Gallery copyWith({
    String? id,
    String? title,
    String? description,
    String? authorId,
    String? authorName,
    List<String>? images,
    Timestamp? createdAt,
    int? viewCount,
  }) {
    return Gallery(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
    );
  }

// Gallery 클래스에 추가
String getCleanImageUrl(String url) {
  try {
    if (url.isEmpty) return '';
    
    // 이미 깨끗한 URL 형식이면 그대로 반환
    if (!url.contains('?')) return url;
    
    // URL 파싱 및 쿼리 파라미터 제거
    final uri = Uri.parse(url);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path
    ).toString();
  } catch (e) {
    print('URL 처리 오류: $e');
    return url;
  }
}

String get thumbnailUrl {
  if (images.isEmpty) return '';
  
  // 같은 방식으로 URL 변환
  final url = images[0];
  try {
    final uri = Uri.parse(url);
    final path = uri.path;
    
    if (path.contains('/o/')) {
      final segments = path.split('/o/');
      if (segments.length > 1) {
        String objectPath = Uri.decodeComponent(segments[1]);
        objectPath = objectPath.split('/').join('%2F');
        
        const bucketName = 'proclub-cdd37.firebasestorage.app';
        return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$objectPath?alt=media';
      }
    }
  } catch (e) {
    print('썸네일 URL 변환 오류: $e');
  }
  
  return url;
}

  // 작성일 문자열 (예: "2025년 3월 15일")
  String get dateString {
    final date = createdAt.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}
