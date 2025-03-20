// lib/presentation/screens/notice/notice_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/widgets/user_profile_popup.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/notice.dart';
import 'package:flutter_application_1/data/services/notice_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/notice/notice_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // URL 실행을 위한 패키지 추가 필요

class NoticeDetailScreen extends StatefulWidget {
  final String noticeId;

  const NoticeDetailScreen({
    Key? key,
    required this.noticeId,
  }) : super(key: key);

  @override
  _NoticeDetailScreenState createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  final NoticeService _noticeService = NoticeService();
  
  Notice? _notice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotice();
  }

  Future<void> _loadNotice() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notice = await _noticeService.getNoticeById(widget.noticeId);
      
      if (mounted) {
        setState(() {
          _notice = notice;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공지사항 로드 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: const Text('이 공지사항을 삭제하시겠습니까?'),
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

    if (confirmed == true) {
      try {
        await _noticeService.deleteNotice(widget.noticeId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('공지사항 삭제 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }
  
  // 첨부 파일 열기
  Future<void> _openAttachment(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일을 열 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 열기 중 오류가 발생했습니다: $e')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isAdmin = userProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          if (isAdmin)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('수정'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticeFormScreen(notice: _notice),
                    ),
                  ).then((_) {
                    _loadNotice();
                  });
                } else if (value == 'delete') {
                  _deleteNotice();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notice == null
              ? const Center(
                  child: Text(
                    '공지사항을 찾을 수 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 중요 표시
                      if (_notice!.important)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '중요 공지사항',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // 제목
                      Text(
                        _notice!.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 작성자 및 날짜
                      Row(
                        children: [
                              Expanded(
                                child: FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(_notice!.authorId)
                                          .get(),
                                  builder: (context, snapshot) {
                                    // 닉네임 정보 가져오기
                                    String? nickname;
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final userData =
                                          snapshot.data!.data()
                                              as Map<String, dynamic>;
                                      nickname =
                                          userData['nickname'] as String?;
                                    }

                                    return AuthorInfoWidget(
                                      authorId: _notice!.authorId,
                                      authorName: _notice!.authorName,
                                      authorNickname: nickname,
                                      avatarRadius: 14,
                                      nameStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      nicknameStyle: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm').format(_notice!.createdAt.toDate()),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          
                          // 수정됨 표시
                          if (_notice!.updatedAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(수정됨)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const Divider(height: 32),
                      
                      // 내용
                      Text(
                        _notice!.content,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      
                      // 첨부 파일 섹션 추가
                      if (_notice!.attachments != null && _notice!.attachments!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          '첨부 파일',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final attachmentUrl in _notice!.attachments!)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                _getFileIcon(attachmentUrl.split('/').last),
                                color: _getFileIconColor(attachmentUrl.split('/').last),
                                size: 36,
                              ),
                              title: Text(
                                attachmentUrl.split('/').last,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: _getFileTypeText(attachmentUrl.split('/').last),
                              trailing: IconButton(
                                icon: const Icon(Icons.download),
                                color: AppColors.primary,
                                onPressed: () => _openAttachment(attachmentUrl),
                              ),
                              onTap: () => _openAttachment(attachmentUrl),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
  
  // 파일 유형 설명 위젯
  Widget _getFileTypeText(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    String description;
    
    switch (extension) {
      case 'apk':
        description = 'Android 앱 설치 파일';
        break;
      case 'ipa':
        description = 'iOS 앱 설치 파일';
        break;
      case 'pdf':
        description = 'PDF 문서';
        break;
      case 'doc':
      case 'docx':
        description = 'Word 문서';
        break;
      case 'xls':
      case 'xlsx':
        description = 'Excel 스프레드시트';
        break;
      case 'ppt':
      case 'pptx':
        description = 'PowerPoint 프레젠테이션';
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        description = '이미지 파일';
        break;
      default:
        description = '파일';
        break;
    }
    
    return Text(description);
  }
}