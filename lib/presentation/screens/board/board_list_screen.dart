// lib/presentation/screens/board/board_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/board/post_detail_screen.dart';
import 'package:flutter_application_1/presentation/screens/board/post_form_screen.dart';
import 'package:intl/intl.dart';

class BoardListScreen extends StatefulWidget {
  const BoardListScreen({Key? key}) : super(key: key);

  @override
  _BoardListScreenState createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  final PostService _postService = PostService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Post>? _posts;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  
  // 태그 필터링 관련 변수
  final List<String> _tagOptions = ['전체', '구름톤','스터디', '프로젝트', '자유', '질의응답', '활동', '자격증', '기타'];
  String _selectedTagFilter = '전체';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Post> posts;
      
      if (_selectedTagFilter == '전체') {
        posts = await _postService.getAllPosts();
      } else {
        posts = await _postService.getPostsByTag(_selectedTagFilter);
      }
      
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글 로드 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      return _loadPosts();
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final posts = await _postService.searchPosts(query);
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글 검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  // 태그 색상 가져오기
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
                  _searchPosts(value);
                },
              )
            : const Text('자유게시판'),
        actions: [
          // 검색 버튼
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _loadPosts();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 태그 필터 선택 영역
          if (!_isSearching) 
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tagOptions.length,
                itemBuilder: (context, index) {
                  final tag = _tagOptions[index];
                  final isSelected = _selectedTagFilter == tag;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      selectedColor: tag == '전체' 
                          ? AppColors.primary.withOpacity(0.7)
                          : _getTagColor(tag).withOpacity(0.7),
                      backgroundColor: Colors.grey[200],
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTagFilter = tag;
                          });
                          // 태그 변경 시 게시글 새로 로드
                          _loadPosts();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            
          // 게시글 목록
          Expanded(
            child: RefreshIndicator(
              onRefresh: _isSearching
                  ? () => _searchPosts(_searchQuery)
                  : _loadPosts,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts == null || _posts!.isEmpty
                      ? Center(
                          child: Text(
                            _isSearching
                                ? '검색 결과가 없습니다.'
                                : _selectedTagFilter == '전체'
                                    ? '게시글이 없습니다.'
                                    : '[$_selectedTagFilter] 태그의 게시글이 없습니다.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _posts!.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final post = _posts![index];
                            final createdDate = DateFormat('yyyy.MM.dd').format(post.createdAt.toDate());
                            
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(postId: post.id),
                                  ),
                                ).then((_) {
                                  // 게시글 화면에서 돌아오면 목록 새로고침
                                  _isSearching
                                      ? _searchPosts(_searchQuery)
                                      : _loadPosts();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 태그 표시 추가
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getTagColor(post.tag).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            post.displayTag,
                                            style: TextStyle(
                                              color: _getTagColor(post.tag),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        if (post.likeCount > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.favorite,
                                                  size: 10,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  post.likeCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    
                                    // 제목과 댓글 수
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            post.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (post.commentCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              post.commentCount.toString(),
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    
                                    // 게시글 내용 미리보기
                                    Text(
                                      post.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // 작성자, 날짜, 조회수
                                    Row(
                                      children: [
                                        Text(
                                          post.authorName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          ' · ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          createdDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.viewCount.toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: userProvider.isLoggedIn
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PostFormScreen(),
                  ),
                ).then((_) {
                  // 글쓰기 화면에서 돌아오면 목록 새로고침
                  _loadPosts();
                });
              },
            )
          : null,
    );
  }
}