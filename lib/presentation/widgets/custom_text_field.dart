// lib/presentation/widgets/custom_text_field.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction; // 추가된 속성
  final String? Function(String?)? validator;
  final int maxLines;
  final Function(String)? onChanged;
  final bool enableInteractiveSelection; // 추가된 속성
  
  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction, // 기본값 없이 옵션으로 설정
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.enableInteractiveSelection = true, // 기본적으로 활성화
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffix: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction, // 텍스트 입력 액션 설정
          validator: validator,
          maxLines: maxLines,
          onChanged: onChanged,
          enableInteractiveSelection: enableInteractiveSelection, // 텍스트 선택 기능 제어
          // 모바일에서 텍스트 선택 및 커서 이동 문제 해결을 위한 추가 설정
          toolbarOptions: const ToolbarOptions(
            copy: true,
            cut: true,
            paste: true,
            selectAll: true,
          ),
          // 추가 스타일 설정
          style: const TextStyle(
            height: 1.5, // 줄 간격 설정
          ),
        ),
      ],
    );
  }
}
