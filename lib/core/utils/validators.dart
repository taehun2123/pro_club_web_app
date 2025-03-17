// lib/core/utils/validators.dart

// 패키지 추가: flutter pub add email_validator
import 'package:email_validator/email_validator.dart';

class Validators {
  // 이메일 유효성 검사 (EmailValidator 패키지 사용)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    
    if (!EmailValidator.validate(value)) {
      return '유효한 이메일 형식이 아닙니다.';
    }
    
    return null;
  }

  // 비밀번호 유효성 검사
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    
    if (value.length < 6) {
      return '비밀번호는 최소 6자 이상이어야 합니다.';
    }
    
    return null;
  }

  // 이름 유효성 검사
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '이름을 입력해주세요.';
    }
    
    if (value.length < 2) {
      return '이름은 최소 2자 이상이어야 합니다.';
    }
    
    return null;
  }

  // 비밀번호 확인 유효성 검사
  static String? validatePasswordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '비밀번호 확인을 입력해주세요.';
    }
    
    if (value != password) {
      return '비밀번호가 일치하지 않습니다.';
    }
    
    return null;
  }

  // 필드 필수 입력 체크
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName을(를) 입력해주세요.';
    }
    
    return null;
  }
}