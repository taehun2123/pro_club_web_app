// lib/core/utils/image_utils.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class ImageUtils {
  // 이미지를 선택하고 압축하는 메서드
static Future<Map<String, dynamic>?> pickAndOptimizeImage({
  required ImageSource source,
  int maxWidth = 1920,
  int maxHeight = 1080,
  int quality = 85,
}) async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: quality, // ImagePicker의 기본 압축 사용
    );
    
    if (pickedFile == null) {
      return null;
    }
    
    final String originalFilename = path.basename(pickedFile.path);
    final String extension = path.extension(originalFilename).toLowerCase();
    final uuid = const Uuid().v4();
    final String filename = '$uuid$extension';
    
    // 압축 로직 우회하고 직접 파일 데이터 읽기
    final Uint8List fileData = await pickedFile.readAsBytes();
    
    return {
      'filename': filename,
      'data': fileData,
      'mimeType': extension == '.png' ? 'image/png' : 'image/jpeg',
    };
  } catch (e, stack) {
    print('이미지 처리 오류: $e');
    print('스택 트레이스: $stack');
    return null;
  }
}
  
  // 썸네일 생성
  static Future<Uint8List?> generateThumbnail(Uint8List imageData, {
    int width = 300,
    int height = 300,
    int quality = 70,
  }) async {
    try {
      return await FlutterImageCompress.compressWithList(
        imageData,
        minWidth: width,
        minHeight: height,
        quality: quality,
      );
    } catch (e) {
      print('썸네일 생성 오류: $e');
      return null;
    }
  }
  
  // Firebase Storage URL 정리 (쿼리 파라미터 제거)
  static String cleanFirebaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // 토큰 파라미터가 있는 경우 제거
      if (uri.queryParameters.containsKey('token')) {
        final newParams = Map<String, String>.from(uri.queryParameters)
          ..remove('token');
        
        return uri.replace(queryParameters: newParams).toString();
      }
      
      return url;
    } catch (e) {
      return url;
    }
  }
  
  // 이미지 URL이 유효한지 확인
  static Future<bool> isImageUrlValid(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}