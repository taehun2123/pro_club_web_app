// lib/data/models/rich_content.dart
import 'dart:convert';

class RichContent {
  final String jsonContent; // Quill Delta JSON 문자열

  RichContent({required this.jsonContent});

  // 일반 텍스트 추출
  String get plainText {
    try {
      final List<dynamic> contentJson = json.decode(jsonContent);
      StringBuffer plainText = StringBuffer();
      
      for (var item in contentJson) {
        if (item is Map && item.containsKey('insert') && item['insert'] is String) {
          plainText.write(item['insert']);
        }
      }
      return plainText.toString();
    } catch (e) {
      return jsonContent; // 변환 실패시 원문 반환
    }
  }
  
  // 첫 번째 이미지 URL 추출 (미리보기용)
  String? get firstImageUrl {
    try {
      final List<dynamic> contentJson = json.decode(jsonContent);
      for (var item in contentJson) {
        if (item is Map && 
            item.containsKey('insert') && 
            item['insert'] is Map &&
            item['insert'].containsKey('image')) {
          return item['insert']['image'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 모든 이미지 URL 추출 (삭제 처리용)
  List<String> get allImageUrls {
    final List<String> urls = [];
    try {
      final List<dynamic> contentJson = json.decode(jsonContent);
      for (var item in contentJson) {
        if (item is Map && 
            item.containsKey('insert') && 
            item['insert'] is Map &&
            item['insert'].containsKey('image')) {
          urls.add(item['insert']['image']);
        }
      }
    } catch (e) {
      // 오류 무시
    }
    return urls;
  }
  
  // 빈 콘텐츠 생성
  factory RichContent.empty() {
    return RichContent(jsonContent: '[{"insert":"\\n"}]');
  }
  
  // 일반 텍스트를 리치 콘텐츠로 변환 (이전 데이터 호환용)
  factory RichContent.fromPlainText(String text) {
    final delta = [{"insert": text}];
    return RichContent(jsonContent: json.encode(delta));
  }
  
  // JSON 문자열이 유효한지 확인
  static bool isValidJson(String jsonString) {
    try {
      json.decode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }
}