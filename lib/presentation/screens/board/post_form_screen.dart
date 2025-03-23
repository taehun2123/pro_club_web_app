// lib/presentation/screens/board/post_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/models/rich_content.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/data/services/storage_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/widgets/custom_button.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';
import 'package:flutter_application_1/presentation/widgets/enhanced_rich_text_editor.dart';
import 'package:uuid/uuid.dart';

class PostFormScreen extends StatefulWidget {
  final Post? post;

  const PostFormScreen({Key? key, this.post}) : super(key: key);

  @override
  _PostFormScreenState createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _customTagController = TextEditingController();
  final PostService _postService = PostService();
  final StorageService _storageService = StorageService();
  
  String _quillContent = '';
  String _storagePath = ''; // 이미지 저장 경로
  bool _isLoading = false;

  // 태그 관련 변수
  final List<String> _tagOptions = [
    '구름톤',
    '스터디',
    '프로젝트',
    '자유',
    '질의응답',
    '활동',
    '자격증',
    '기타',
  ];
  String _selectedTag = '자유';
  bool _showCustomTagField = false;

  @override
  void initState() {
    super.initState();
    
    // 제목 초기화
    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _quillContent = widget.post!.content;
      _storagePath = 'posts/${widget.post!.id}';
      
      // 태그 정보 초기화
      _selectedTag = widget.post!.tag;
      if (_selectedTag == '기타' && widget.post!.customTag != null) {
        _customTagController.text = widget.post!.customTag!;
        _showCustomTagField = true;
      }
    } else {
      // 새 게시글인 경우 임시 ID 생성
      final tempId = const Uuid().v4();
      _storagePath = 'posts/$tempId';
      _quillContent = RichContent.empty().jsonContent;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  // 태그 선택 처리
  void _updateTagSelection(String tag) {
    setState(() {
      _selectedTag = tag;
      _showCustomTagField = (tag == '기타');
      if (!_showCustomTagField) {
        _customTagController.clear();
      }
    });
  }

  // 태그별 색상 반환
  Color _getTagColor(String tag) {
    switch (tag) {
      case '구름톤':
        return Colors.lightBlueAccent;
      case '스터디':
        return Colors.blue;
      case '프로젝트':
        return Colors.green;
      case '자유':
        return Colors.purple;
      case '질의응답':
        return Colors.orange;
      case '활동':
        return Colors.pink;
      case '자격증':
        return Colors.teal;
      case '기타':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_quillContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      if (user == null) {
        throw Exception('로그인 상태를 확인할 수 없습니다.');
      }

      final title = _titleController.text.trim();
      final customTag = _selectedTag == '기타' ? _customTagController.text.trim() : null;
      final richContent = RichContent(jsonContent: _quillContent);
      
      if (widget.post == null) {
        // 새 게시글 작성
        final newPost = Post.withRichContent(
          id: '', // Firestore에서 자동 생성
          title: title,
          richContent: richContent,
          authorId: user.id,
          authorName: user.name,
          authorProfileImage: user.profileImage,
          createdAt: Timestamp.now(),
          tag: _selectedTag,
          customTag: customTag,
        );
        
        final postId = await _postService.addPost(newPost, []);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 작성되었습니다.')),
          );
        }
      } else {
        // 게시글 수정
        // 기존 이미지와 새 콘텐츠의 이미지 비교하여 삭제된 이미지 처리
        final oldContent = widget.post!.richContent;
        final oldImageUrls = oldContent.allImageUrls;
        final newImageUrls = richContent.allImageUrls;
        
        // 삭제된 이미지 찾기
        final removedImages = oldImageUrls.where(
          (url) => !newImageUrls.contains(url)
        ).toList();
        
        // 삭제된 이미지들 Storage에서 제거
        for (final imageUrl in removedImages) {
          await _storageService.deleteImage(imageUrl);
        }
        
        // 게시글 업데이트
        final updatedPost = widget.post!.copyWith(
          title: title,
          content: _quillContent,
          updatedAt: Timestamp.now(),
          tag: _selectedTag,
          customTag: customTag,
        );
        
        await _postService.updatePost(updatedPost, [], []);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 수정되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('게시글 ${widget.post == null ? '작성' : '수정'} 중 오류가 발생했습니다: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.post == null ? '새 게시글' : '게시글 수정')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 태그 선택 섹션
                    const Text(
                      '태그 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _tagOptions.map((tag) {
                            final isSelected = _selectedTag == tag;
                            return ChoiceChip(
                              label: Text(tag),
                              selected: isSelected,
                              selectedColor: _getTagColor(tag).withOpacity(0.7),
                              backgroundColor: Colors.grey[200],
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  _updateTagSelection(tag);
                                }
                              },
                            );
                          }).toList(),
                    ),

                    // 커스텀 태그 입력 필드
                    if (_showCustomTagField) ...[
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _customTagController,
                        label: '커스텀 태그',
                        hintText: '태그 이름을 직접 입력하세요',
                        validator: (value) {
                          if (_selectedTag == '기타' &&
                              (value == null || value.isEmpty)) {
                            return '커스텀 태그를 입력해주세요.';
                          }
                          if (value != null && value.length > 10) {
                            return '태그는 10자 이내로 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 제목 입력
                    CustomTextField(
                      controller: _titleController,
                      label: '제목',
                      hintText: '제목을 입력하세요',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '제목을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 내용 입력 - 리치 텍스트 에디터 사용
                    const Text(
                      '내용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400, // 에디터 높이 조정
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: EnhancedRichTextEditor(
                        initialContent: _quillContent,
                        onContentChanged: (content) {
                          _quillContent = content;
                        },
                        storagePath: _storagePath,
                        height: 400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 작성/수정 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: widget.post == null ? '작성 완료' : '수정 완료',
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}