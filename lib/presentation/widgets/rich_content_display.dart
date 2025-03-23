// lib/presentation/widgets/rich_content_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class RichContentDisplay extends StatelessWidget {
  final String content;

  const RichContentDisplay({
    Key? key,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 빈 내용일 경우 빈 컨테이너 반환
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    late Document document;
    try {
      // JSON 형식인지 확인
      document = Document.fromJson(json.decode(content));
    } catch (e) {
      // JSON이 아니면 일반 텍스트로 표시
      return Text(
        content,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
    }

    // QuillController 생성 - readOnly를 true로 설정
    final QuillController controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    
    // 컨트롤러를 읽기 전용으로 설정
    controller.readOnly=true;

    // 읽기 전용 에디터로 표시
    return QuillEditor(
      controller: controller,
      focusNode: FocusNode(),
      scrollController: ScrollController(),
      config: QuillEditorConfig(
        autoFocus: false,
        scrollable: false,
        expands: false,
        padding: EdgeInsets.zero,
        showCursor: false,
        enableInteractiveSelection: true,
        // 링크 처리를 위한 설정
        onLaunchUrl: (url) {
          launchUrl(Uri.parse(url));
        },
      
        embedBuilders: [
          // 이미지 임베드 빌더 등록
          _CustomImageEmbedBuilder(),
        ],
      ),
    );
  }
}

// 커스텀 이미지 임베드 빌더
class _CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node as Embed;
    final imageUrl = node.value.data;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return const SizedBox(
                height: 200,
                width: double.infinity,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 150,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.error, color: Colors.red),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}