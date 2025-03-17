// lib/utils/image_utils.dart

class ImageUtils {
  // Firebase Storage URL 처리 함수
  static String getProxiedImageUrl(String originalUrl) {
    // 빈 URL 처리
    if (originalUrl.isEmpty) return '';
    
    try {
      // URL 파싱
      final uri = Uri.parse(originalUrl);
      
      // Firebase Storage URL 확인
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        // 기본 URL 구조에서 버킷과 객체 경로 추출
        final pathParts = uri.path.split('/o/');
        if (pathParts.length > 1) {
          // 객체 경로 디코딩
          final objectPath = Uri.decodeComponent(pathParts[1]);
          
          // 프로젝트 ID 확인 (URL에서 추출)
          final bucketName = uri.path.contains('proclub-cdd37') 
              ? 'proclub-cdd37' 
              : 'your-firebase-project-id';
          
          // 토큰 없는 간단한 URL 구조로 반환
          return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$objectPath?alt=media';
        }
      }
      
      // 이미 정상 URL이면 그대로 반환
      return originalUrl;
    } catch (e) {
      print('URL 처리 오류: $e, 원본 URL: $originalUrl');
      return originalUrl;
    }
  }
}