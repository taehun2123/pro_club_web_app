// lib/presentation/screens/board/post_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/widgets/custom_button.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PostFormScreen extends StatefulWidget {
  final Post? post;

  const PostFormScreen({Key? key, this.post}) : super(key: key);

  @override
  _PostFormScreenState createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _customTagController = TextEditingController();
  final PostService _postService = PostService();
  final ImagePicker _imagePicker = ImagePicker();

  List<String> _existingAttachments = [];
  List<String> _attachmentsToDelete = [];
  List<File> _newAttachments = [];
  bool _isLoading = false;

  // 태그 관련 변수
  final List<String> _tagOptions = [
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
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _contentController.text = widget.post!.content;
      _existingAttachments = List<String>.from(widget.post!.attachments ?? []);

      // 태그 정보 초기화
      _selectedTag = widget.post!.tag;
      if (_selectedTag == '기타' && widget.post!.customTag != null) {
        _customTagController.text = widget.post!.customTag!;
        _showCustomTagField = true;
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _newAttachments.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 선택 중 오류가 발생했습니다: $e')));
    }
  }

  void _removeExistingAttachment(String fileUrl) {
    setState(() {
      _existingAttachments.remove(fileUrl);
      _attachmentsToDelete.add(fileUrl);
    });
  }

  void _removeNewAttachment(int index) {
    setState(() {
      _newAttachments.removeAt(index);
    });
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
                        // maxLength 대신 inputFormatters 사용 (만약 CustomTextField에서 지원한다면)
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

                    // 내용 입력
                    CustomTextField(
                      controller: _contentController,
                      label: '내용',
                      hintText: '내용을 입력하세요',
                      maxLines: 20, // 더 많은 줄 수 허용
                      keyboardType: TextInputType.multiline, // 다중 줄 키보드 타입 설정
                      textInputAction: TextInputAction.newline, // 엔터키를 줄바꿈으로 처리
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '내용을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 첨부 파일 섹션
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '첨부 파일',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('파일 추가'),
                          onPressed: _pickFile,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 기존 첨부 파일 목록
                    if (_existingAttachments.isNotEmpty) ...[
                      const Text(
                        '기존 첨부 파일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final fileUrl in _existingAttachments)
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(
                            fileUrl.split('/').last,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeExistingAttachment(fileUrl),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      const SizedBox(height: 16),
                    ],

                    // 새 첨부 파일 목록
                    if (_newAttachments.isNotEmpty) ...[
                      const Text(
                        '새 첨부 파일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _newAttachments.length; i++)
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(
                            _newAttachments[i].path.split('/').last,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeNewAttachment(i),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                    ],
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 상태를 확인할 수 없습니다.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final customTag =
          _selectedTag == '기타' ? _customTagController.text.trim() : null;

      if (widget.post == null) {
        // 새 게시글 작성
        final newPost = Post(
          id: '',
          title: title,
          content: content,
          authorId: user.id,
          authorName: user.name,
          authorProfileImage: user.profileImage,
          createdAt: Timestamp.now(),
          tag: _selectedTag, // 태그 추가
          customTag: customTag, // 커스텀 태그 추가
        );

        await _postService.addPost(newPost, _newAttachments);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글이 작성되었습니다.')));
        }
      } else {
        // 게시글 수정
        final updatedPost = widget.post!.copyWith(
          title: title,
          content: content,
          updatedAt: Timestamp.now(),
          tag: _selectedTag, // 태그 추가
          customTag: customTag, // 커스텀 태그 추가
        );

        await _postService.updatePost(
          updatedPost,
          _newAttachments,
          _attachmentsToDelete,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글이 수정되었습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '게시글 ${widget.post == null ? '작성' : '수정'} 중 오류가 발생했습니다: $e',
            ),
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
}
