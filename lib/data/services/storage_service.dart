// lib/data/services/storage_service.dart
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/core/utils/image_utils.dart';
import 'package:flutter_application_1/data/models/rich_content.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 현재 사용자 ID 획득 (보안용)
  String? get _currentUserId => _auth.currentUser?.uid;
  
  // 이미지 업로드 메서드
  Future<Map<String, String>> uploadContentImage({
    required String path, // 예: posts/abc123
    required String filename,
    required Uint8List imageData,
    bool generateThumbnail = true,
  }) async {
    if (_currentUserId == null) {
      throw Exception('사용자 인증이 필요합니다');
    }
    
    // 메타데이터 설정
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedBy': _currentUserId!,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
    
    try {
      // 이미지 저장 경로
      final storageRef = _storage.ref().child('$path/$filename');
      
      // 이미지 업로드
      final uploadTask = storageRef.putData(imageData, metadata);
      
      // 업로드 완료 대기
      final snapshot = await uploadTask;
      
      // 다운로드 URL 획득
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      Map<String, String> result = {'imageUrl': downloadUrl};
      
      // 썸네일 생성 및 업로드 (선택적)
      if (generateThumbnail) {
        final thumbnailData = await ImageUtils.generateThumbnail(imageData);
        
        if (thumbnailData != null) {
          final thumbnailRef = _storage.ref().child('$path/thumbnails/$filename');
          final thumbnailTask = thumbnailRef.putData(thumbnailData, metadata);
          final thumbnailSnapshot = await thumbnailTask;
          final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
          
          result['thumbnailUrl'] = thumbnailUrl;
        }
      }
      
      return result;
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }
  
  // 이미지 삭제 메서드
  Future<void> deleteImage(String imageUrl) async {
    try {
      // 이미지 URL에서 파일 경로 추출
      final ref = _storage.refFromURL(imageUrl);
      
      // 파일 삭제
      await ref.delete();
      
      // 썸네일이 있다면 함께 삭제
      try {
        final String fullPath = ref.fullPath;
        final String filename = fullPath.split('/').last;
        final String directory = fullPath.substring(0, fullPath.lastIndexOf('/'));
        final String thumbnailPath = '$directory/thumbnails/$filename';
        
        final thumbnailRef = _storage.ref().child(thumbnailPath);
        await thumbnailRef.delete();
      } catch (e) {
        // 썸네일 삭제 실패는 무시
        print('썸네일 삭제 실패: $e');
      }
    } catch (e) {
      print('이미지 삭제 실패: $e');
      // 삭제 실패는 예외를 발생시키지 않고 로그만 남김
    }
  }
  
  // RichContent에서 모든 이미지 삭제
  Future<void> deleteAllContentImages(String richContentJson) async {
    final richContent = RichContent(jsonContent: richContentJson);
    final imageUrls = richContent.allImageUrls;
    
    // 모든 이미지 병렬 삭제
    await Future.wait(
      imageUrls.map((url) => deleteImage(url)),
    );
  }
}