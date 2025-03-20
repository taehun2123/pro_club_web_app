// lib/presentation/screens/notice/notice_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/notice.dart';
import 'package:flutter_application_1/data/services/notice_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/widgets/custom_button.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';
import 'package:file_picker/file_picker.dart'; // 파일 선택 패키지 추가 필요
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'dart:io';

class NoticeFormScreen extends StatefulWidget {
  final Notice? notice;

  const NoticeFormScreen({Key? key, this.notice}) : super(key: key);

  @override
  _NoticeFormScreenState createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final NoticeService _noticeService = NoticeService();

  bool _isImportant = false;
  bool _isLoading = false;

  // 첨부 파일 관련 변수 추가
  List<String> _existingAttachments = [];
  List<String> _attachmentsToDelete = [];
  List<File> _newAttachments = [];
  List<PlatformFile> _webAttachmentFiles = [];
  List<Uint8List> _webAttachmentData = [];

  @override
  void initState() {
    super.initState();
    if (widget.notice != null) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;
      _isImportant = widget.notice!.important;
      _existingAttachments = List<String>.from(
        widget.notice!.attachments ?? [],
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 파일 선택 메서드 추가
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: kIsWeb, // 웹에서 바이너리 데이터 가져오기
      );

      if (result != null) {
        if (kIsWeb) {
          // 웹 환경
          setState(() {
            for (var file in result.files) {
              if (file.bytes != null) {
                _webAttachmentFiles.add(file);
                _webAttachmentData.add(file.bytes!);
              }
            }
          });
        } else {
          // 모바일 환경
          setState(() {
            for (var file in result.files) {
              if (file.path != null) {
                _newAttachments.add(File(file.path!));
              }
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 선택 중 오류가 발생했습니다: $e')));
    }
  }

  // 기존 첨부 파일 삭제
  void _removeExistingAttachment(String fileUrl) {
    setState(() {
      _existingAttachments.remove(fileUrl);
      _attachmentsToDelete.add(fileUrl);
    });
  }

  // 새 첨부 파일 삭제
  void _removeNewAttachment(int index) {
    setState(() {
      if (kIsWeb) {
        _webAttachmentFiles.removeAt(index);
        _webAttachmentData.removeAt(index);
      } else {
        _newAttachments.removeAt(index);
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      if (widget.notice == null) {
        // 새 공지사항 작성
        final newNotice = Notice(
          id: '',
          title: title,
          content: content,
          authorId: user.id,
          authorName: user.name,
          createdAt: Timestamp.now(),
          important: _isImportant,
          attachments: [],
        );

        await _noticeService.addNotice(
          newNotice,
          _newAttachments,
          webAttachments: kIsWeb ? _webAttachmentData : null,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('공지사항이 작성되었습니다.')));
        }
      } else {
        // 공지사항 수정
        final updatedNotice = Notice(
          id: widget.notice!.id,
          title: title,
          content: content,
          authorId: widget.notice!.authorId,
          authorName: widget.notice!.authorName,
          createdAt: widget.notice!.createdAt,
          updatedAt: Timestamp.now(),
          important: _isImportant,
          attachments: _existingAttachments,
        );

        await _noticeService.updateNotice(
          updatedNotice,
          _newAttachments,
          _attachmentsToDelete,
          webAttachments: kIsWeb ? _webAttachmentData : null,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('공지사항이 수정되었습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '공지사항 ${widget.notice == null ? '작성' : '수정'} 중 오류가 발생했습니다: $e',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notice == null ? '공지사항 작성' : '공지사항 수정'),
      ),
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
                    // 중요 공지사항 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value: _isImportant,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _isImportant = value;
                              });
                            }
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Text(
                          '중요 공지사항',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
                          onPressed: _pickFiles,
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
                        _buildAttachmentItem(
                          fileUrl.split('/').last,
                          onDelete: () => _removeExistingAttachment(fileUrl),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // 새 첨부 파일 목록
                    if (kIsWeb
                        ? _webAttachmentFiles.isNotEmpty
                        : _newAttachments.isNotEmpty) ...[
                      const Text(
                        '새 첨부 파일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (kIsWeb)
                        for (int i = 0; i < _webAttachmentFiles.length; i++)
                          _buildAttachmentItem(
                            _webAttachmentFiles[i].name,
                            onDelete: () => _removeNewAttachment(i),
                          ),
                      if (!kIsWeb)
                        for (int i = 0; i < _newAttachments.length; i++)
                          _buildAttachmentItem(
                            _newAttachments[i].path.split('/').last,
                            onDelete: () => _removeNewAttachment(i),
                          ),
                    ],
                  ],
                ),
              ),
            ),

            // 저장 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: widget.notice == null ? '작성 완료' : '수정 완료',
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 첨부 파일 아이템 위젯
  Widget _buildAttachmentItem(
    String fileName, {
    required VoidCallback onDelete,
  }) {
    return ListTile(
      leading: Icon(_getFileIcon(fileName), color: _getFileIconColor(fileName)),
      title: Text(fileName, style: const TextStyle(fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
        color: Colors.red,
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  // 파일 확장자에 따른 아이콘 선택
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'apk':
        return Icons.android;
      case 'ipa':
      case 'ios':
        return Icons.apple;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  // 파일 확장자에 따른 아이콘 색상
  Color _getFileIconColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'apk':
        return Colors.green;
      case 'ipa':
      case 'ios':
        return Colors.grey;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
