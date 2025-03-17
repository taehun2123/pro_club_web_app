// lib/presentation/screens/notice/notice_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/notice.dart';
import 'package:flutter_application_1/data/services/notice_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/notice/notice_form_screen.dart';
import 'package:flutter_application_1/presentation/screens/notice/notice_detail_screen.dart';
import 'package:flutter_application_1/presentation/widgets/notice_card.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({Key? key}) : super(key: key);

  @override
  _NoticeListScreenState createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final NoticeService _noticeService = NoticeService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Notice>? _notices;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notices = await _noticeService.getAllNotices();
      if (mounted) {
        setState(() {
          _notices = notices;
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

  Future<void> _searchNotices(String query) async {
    if (query.isEmpty) {
      return _loadNotices();
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final notices = await _noticeService.searchNotices(query);
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공지사항 검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '검색어를 입력하세요',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                style: const TextStyle(color: AppColors.darkGray),
                onSubmitted: (value) {
                  _searchNotices(value);
                },
              )
            : const Text('공지사항'),
        actions: [
          // 검색 버튼
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _loadNotices();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _isSearching
            ? () => _searchNotices(_searchQuery)
            : _loadNotices,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notices == null || _notices!.isEmpty
                ? Center(
                    child: Text(
                      _isSearching
                          ? '검색 결과가 없습니다.'
                          : '공지사항이 없습니다.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notices!.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoticeDetailScreen(
                                noticeId: _notices![index].id,
                              ),
                            ),
                          ).then((_) {
                            // 공지사항 화면에서 돌아오면 목록 새로고침
                            _isSearching
                                ? _searchNotices(_searchQuery)
                                : _loadNotices();
                          });
                        },
                        child: NoticeCard(notice: _notices![index]),
                      );
                    },
                  ),
      ),
      floatingActionButton: userProvider.isAdmin
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NoticeFormScreen(),
                  ),
                ).then((_) {
                  // 글쓰기 화면에서 돌아오면 목록 새로고침
                  _loadNotices();
                });
              },
            )
          : null,
    );
  }
}
