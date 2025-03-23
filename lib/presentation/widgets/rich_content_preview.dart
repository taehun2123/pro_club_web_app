// lib/presentation/widgets/rich_content_preview.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/models/rich_content.dart';

class RichContentPreview extends StatelessWidget {
  final String jsonContent;
  final int maxLines;
  final TextStyle? style;
  
  const RichContentPreview({
    Key? key,
    required this.jsonContent,
    this.maxLines = 2,
    this.style,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final richContent = RichContent(jsonContent: jsonContent);
    final plainText = richContent.plainText;
    final hasImage = richContent.firstImageUrl != null;
    
    return Row(
      children: [
        // 텍스트 미리보기
        Expanded(
          child: Text(
            plainText,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style ?? TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        
        // 이미지가 있는 경우 아이콘 표시
        if (hasImage)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(
              Icons.image,
              size: 16,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }
}