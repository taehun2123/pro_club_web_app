// lib/presentation/widgets/enhanced_rich_text_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/core/utils/image_utils.dart';
import 'package:flutter_application_1/data/services/storage_service.dart';
import 'package:flutter_application_1/data/models/rich_content.dart';

class EnhancedRichTextEditor extends StatefulWidget {
  final String initialContent;
  final Function(String) onContentChanged;
  final String storagePath; // 이미지 저장 경로 (예: 'posts/abc123')
  final bool readOnly;
  final double height;

  const EnhancedRichTextEditor({
    Key? key,
    this.initialContent = '',
    required this.onContentChanged,
    required this.storagePath,
    this.readOnly = false,
    this.height = 300,
  }) : super(key: key);

  @override
  _EnhancedRichTextEditorState createState() => _EnhancedRichTextEditorState();
}

class _EnhancedRichTextEditorState extends State<EnhancedRichTextEditor> {
  late QuillController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // 초기 내용 설정
    Document document;
    if (widget.initialContent.isNotEmpty) {
      try {
        // JSON 형식인지 확인
        document = Document.fromJson(json.decode(widget.initialContent));
      } catch (e) {
        // JSON이 아니면 일반 텍스트로 처리
        document = Document()..insert(0, widget.initialContent);
      }
    } else {
      document = Document();
    }

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    if (!widget.readOnly) {
      // 내용 변경 리스너 추가
      _controller.document.changes.listen((event) {
        // JSON으로 변환하여 부모 위젯에 전달
        final jsonData = jsonEncode(_controller.document.toDelta().toJson());
        widget.onContentChanged(jsonData);
      });
    }

    // 선택 범위가 변경될 때마다 UI 업데이트
    _controller.addListener(() {
      setState(() {
        // 툴바의 토글 버튼 상태 업데이트를 위한 setState
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 선택 영역에 특정 속성이 적용되어 있는지 확인
  bool _isAttributeActive(Attribute attribute) {
    return _controller.getSelectionStyle().attributes.containsKey(attribute.key);
  }

  // 속성 토글 - 이미 적용되어 있으면 해제, 아니면 적용
  void _toggleAttribute(Attribute attribute) {
    final isActive = _isAttributeActive(attribute);
    // isActive가 true면 해당 속성 제거, false면 적용
    _controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  // 블록 스타일 적용 여부 확인 (목록, 인용 등)
  bool _isBlockAttributeActive(Attribute attribute) {
    return _controller.getSelectionStyle().attributes.containsKey(attribute.key);
  }

  // 블록 스타일 토글
  void _toggleBlockAttribute(Attribute attribute) {
    final isActive = _isBlockAttributeActive(attribute);
    _controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        _uploadProgress = 0.0;
      });

      // 이미지 선택 다이얼로그 표시
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이미지 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      );

      if (source == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 이미지 선택 및 최적화
      final imageResult = await ImageUtils.pickAndOptimizeImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        quality: 85,
      );

      if (imageResult == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 진행률 업데이트 (시작)
      setState(() {
        _uploadProgress = 0.3; // 이미지 처리 완료
      });

      // Firebase Storage에 업로드
      final uploadResult = await _storageService.uploadContentImage(
        path: widget.storagePath,
        filename: imageResult['filename'],
        imageData: imageResult['data'],
        generateThumbnail: true,
      );

      // 진행률 업데이트 (완료)
      setState(() {
        _uploadProgress = 1.0;
      });

      // 에디터에 이미지 삽입
      final imageUrl = ImageUtils.cleanFirebaseUrl(uploadResult['imageUrl']!);
      _controller.document.insert(
        _controller.selection.extentOffset,
        BlockEmbed.image(imageUrl),
      );
    } catch (e) {
      // 오류 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      // 로딩 상태 해제
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // 링크 추가 다이얼로그 표시
  void _showLinkDialog() {
    String url = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('링크 삽입'),
          content: TextField(
            onChanged: (value) {
              url = value;
            },
            decoration: const InputDecoration(
              hintText: 'https://example.com',
              labelText: 'URL',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  final index = _controller.selection.baseOffset;
                  final length = _controller.selection.extentOffset - index;

                  // 선택된 텍스트가 있으면 그 텍스트에 링크 적용
                  // 없으면 URL을 텍스트로 삽입
                  if (length > 0) {
                    // 이미 링크가 적용되어 있는지 확인
                    final hasLink = _controller.getSelectionStyle().attributes.containsKey(Attribute.link.key);
                    
                    if (hasLink) {
                      // 링크가 이미 있으면 새 링크로 변경
                      _controller.formatSelection(Attribute.clone(Attribute.link, null)); // 기존 링크 제거
                      _controller.formatSelection(LinkAttribute(url)); // 새 링크 추가
                    } else {
                      // 링크가 없으면 새로 추가
                      _controller.formatSelection(LinkAttribute(url));
                    }
                  } else {
                    // 선택된 텍스트가 없으면 URL을 삽입하고 링크 적용
                    _controller.replaceText(index, 0, url, null);
                    _controller.formatText(index, url.length, LinkAttribute(url));
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 텍스트의 스타일 정보
    final selectionStyle = _controller.getSelectionStyle();
    
    // 기본 및 활성화 색상 정의
    final Color defaultColor = Colors.grey[700]!;
    final Color activeColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        // 툴바 (읽기 모드가 아닐 때만 표시)
        if (!widget.readOnly)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 실행취소/다시실행
                  IconButton(
                    icon: Icon(Icons.undo, color: defaultColor),
                    tooltip: '실행 취소',
                    onPressed: () => _controller.undo(),
                  ),
                  IconButton(
                    icon: Icon(Icons.redo, color: defaultColor),
                    tooltip: '다시 실행',
                    onPressed: () => _controller.redo(),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  
                  // 텍스트 스타일 버튼
                  IconButton(
                    icon: Icon(
                      Icons.format_bold,
                      color: _isAttributeActive(Attribute.bold) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '굵게',
                    onPressed: () => _toggleAttribute(Attribute.bold),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_italic,
                      color: _isAttributeActive(Attribute.italic) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '기울임',
                    onPressed: () => _toggleAttribute(Attribute.italic),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_underline,
                      color: _isAttributeActive(Attribute.underline) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '밑줄',
                    onPressed: () => _toggleAttribute(Attribute.underline),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_strikethrough,
                      color: _isAttributeActive(Attribute.strikeThrough) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '취소선',
                    onPressed: () => _toggleAttribute(Attribute.strikeThrough),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  
                  // 목록 스타일 버튼
                  IconButton(
                    icon: Icon(
                      Icons.format_list_bulleted,
                      color: _isBlockAttributeActive(Attribute.ul) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '글머리 기호',
                    onPressed: () => _toggleBlockAttribute(Attribute.ul),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_list_numbered,
                      color: _isBlockAttributeActive(Attribute.ol) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '번호 매기기',
                    onPressed: () => _toggleBlockAttribute(Attribute.ol),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  
                  // 인용 스타일
                  IconButton(
                    icon: Icon(
                      Icons.format_quote,
                      color: _isBlockAttributeActive(Attribute.blockQuote) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '인용',
                    onPressed: () => _toggleBlockAttribute(Attribute.blockQuote),
                  ),
                  
                  // 링크 버튼
                  IconButton(
                    icon: Icon(
                      Icons.link,
                      color: _isAttributeActive(Attribute.link) 
                        ? activeColor 
                        : defaultColor,
                    ),
                    tooltip: '링크',
                    onPressed: _showLinkDialog,
                  ),
                  
                  // 이미지 버튼
                  IconButton(
                    icon: Icon(Icons.image, color: defaultColor),
                    tooltip: '이미지 삽입',
                    onPressed: _isLoading ? null : _pickAndUploadImage,
                  ),
                ],
              ),
            ),
          ),

        // 에디터
        Expanded(
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    placeholder: '내용을 입력하세요...',
                    autoFocus: false,
                    padding: const EdgeInsets.all(0),
                    scrollable: true,
                    expands: false,
                    embedBuilders: [
                      // 이미지 임베드 빌더 커스터마이징
                      _CustomImageEmbedBuilder(),
                    ],
                  ),
                ),

                // 업로드 중 로딩 표시
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '이미지 업로드 중...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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

    return _ImageEmbedWidget(
      imageUrl: imageUrl,
      controller: embedContext.controller,
      node: node,
      readOnly: embedContext.readOnly,
    );
  }
}

// 향상된 이미지 임베드 위젯
class _ImageEmbedWidget extends StatefulWidget {
  final String imageUrl;
  final QuillController controller;
  final Embed node;
  final bool readOnly;

  const _ImageEmbedWidget({
    required this.imageUrl,
    required this.controller,
    required this.node,
    required this.readOnly,
  });

  @override
  _ImageEmbedWidgetState createState() => _ImageEmbedWidgetState();
}

class _ImageEmbedWidgetState extends State<_ImageEmbedWidget> {
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _checkImageValidity();
  }

  Future<void> _checkImageValidity() async {
    final isValid = await ImageUtils.isImageUrlValid(widget.imageUrl);
    if (!isValid && mounted) {
      setState(() {
        _isValid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValid) {
      return Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.grey, size: 36),
            const SizedBox(height: 8),
            const Text('이미지를 불러올 수 없습니다', style: TextStyle(color: Colors.grey)),
            if (!widget.readOnly)
              TextButton(
                onPressed: () {
                  // 이미지 삭제
                  final index = widget.controller.document
                      .toDelta()
                      .toList()
                      .indexWhere(
                        (item) =>
                            item.key == 'insert' &&
                            item.value is Map &&
                            item.value['image'] == widget.imageUrl,
                      );
                  if (index != -1) {
                    widget.controller.document.delete(index, 1);
                  }
                },
                child: const Text('이미지 삭제'),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        children: [
          // 이미지
          FadeInImage.assetNetwork(
            placeholder: 'assets/images/image_placeholder.png', // 플레이스홀더 이미지 필요
            image: widget.imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            imageErrorBuilder: (context, error, stackTrace) {
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

          // 읽기 전용이 아니면 삭제 버튼 표시
          if (!widget.readOnly)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () async {
                    // 이미지 삭제 확인 다이얼로그
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('이미지 삭제'),
                        content: const Text('이 이미지를 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // Firebase Storage에서도 삭제 시도
                      try {
                        final StorageService storageService = StorageService();
                        await storageService.deleteImage(widget.imageUrl);
                      } catch (e) {
                        print('스토리지 이미지 삭제 실패: $e');
                      }

                      // 문서에서 이미지 삭제
                      final index = widget.controller.document
                          .toDelta()
                          .toList()
                          .indexWhere(
                            (item) =>
                                item.key == 'insert' &&
                                item.value is Map &&
                                item.value['image'] == widget.imageUrl,
                          );
                      if (index != -1) {
                        widget.controller.document.delete(index, 1);
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}