// lib/presentation/screens/board/post_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/models/comment.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/board/post_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();

  Post? _post;
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isCommentLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 게시글 조회수 증가
      await _postService.incrementViewCount(widget.postId);
      
      // 게시글 및 댓글 로드
      final post = await _postService.getPostById(widget.postId);
      final comments = await _postService.getCommentsByPostId(widget.postId);
      
      if (mounted) {
        setState(() {
          _post = post;
          _comments = comments;
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

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하시겠습니까?'),
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
        await _postService.deletePost(widget.postId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  Future<void> _addComment() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글을 작성하려면 로그인이 필요합니다.')),
      );
      return;
    }

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) {
      return;
    }

    setState(() {
      _isCommentLoading = true;
    });

    try {
      final comment = Comment(
        id: '',
        postId: widget.postId,
        content: commentText,
        authorId: user.id,
        authorName: user.name,
        authorProfileImage: user.profileImage,
        createdAt: Timestamp.now(),
      );

      await _postService.addComment(comment);
      _commentController.clear();
      
      // 댓글 다시 로드
      final comments = await _postService.getCommentsByPostId(widget.postId);
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _isCommentLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCommentLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
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
        await _postService.deleteComment(widget.postId, comment.id);
        
        // 댓글 다시 로드
        final comments = await _postService.getCommentsByPostId(widget.postId);
        
        if (mounted) {
          setState(() {
            _comments = comments;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('댓글이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('댓글 삭제 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  void _openAttachment(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final isAuthor = _post != null && user != null && _post!.authorId == user.id;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          if (isAuthor || isAdmin)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                if (isAuthor)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('수정'),
                  ),
                if (isAuthor || isAdmin)
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
                      builder: (context) => PostFormScreen(post: _post),
                    ),
                  ).then((_) {
                    _loadPost();
                  });
                } else if (value == 'delete') {
                  _deletePost();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(
                  child: Text(
                    '게시글을 찾을 수 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // 게시글 내용
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            Text(
                              _post!.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // 작성자 및 날짜
                            Row(
                              children: [
                                Text(
                                  _post!.authorName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  DateFormat('yyyy.MM.dd HH:mm').format(_post!.createdAt.toDate()),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            
                            // 조회수
                            Row(
                              children: [
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _post!.viewCount.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            
                            const Divider(height: 32),
                            
                            // 내용
                            Text(
                              _post!.content,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            
                            // 첨부 파일
                            if (_post!.attachments != null && _post!.attachments!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                '첨부 파일',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final attachment in _post!.attachments!)
                                ListTile(
                                  leading: const Icon(Icons.attachment),
                                  title: Text(
                                    attachment.split('/').last,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onTap: () => _openAttachment(attachment),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                            ],
                            
                            const SizedBox(height: 32),
                            
                            // 댓글 제목
                            Row(
                              children: [
                                const Text(
                                  '댓글',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _comments.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // 댓글 목록
                            if (_comments.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    '댓글이 없습니다.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (final comment in _comments)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // 프로필 이미지
                                          if (comment.authorProfileImage != null)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: CachedNetworkImage(
                                                imageUrl: comment.authorProfileImage!,
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: Colors.grey[300],
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          
                                          // 작성자 및 날짜
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  comment.authorName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('yyyy.MM.dd HH:mm').format(comment.createdAt.toDate()),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // 삭제 버튼
                                          if (user != null && (user.id == comment.authorId || isAdmin))
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18),
                                              onPressed: () => _deleteComment(comment),
                                              color: Colors.grey[600],
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                      
                                      // 댓글 내용
                                      Padding(
                                        padding: const EdgeInsets.only(left: 40, top: 8),
                                        child: Text(
                                          comment.content,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 댓글 입력창
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                hintText: '댓글을 입력하세요',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              enabled: userProvider.isLoggedIn,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isCommentLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: userProvider.isLoggedIn ? _addComment : null,
                                  color: AppColors.primary,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
