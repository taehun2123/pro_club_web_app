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
class NoticeFormScreen extends StatefulWidget {
  final Notice? notice;

  const NoticeFormScreen({
    Key? key,
    this.notice,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    if (widget.notice != null) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;
      _isImportant = widget.notice!.important;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
        );
        
        await _noticeService.addNotice(newNotice);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 작성되었습니다.')),
          );
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
        );
        
        await _noticeService.updateNotice(updatedNotice);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 수정되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공지사항 ${widget.notice == null ? '작성' : '수정'} 중 오류가 발생했습니다: $e')),
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
                      maxLines: 15,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '내용을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
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
}