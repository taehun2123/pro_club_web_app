import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/widgets/comment_input_with_mention.dart';
import 'package:flutter_application_1/presentation/widgets/mention_highlight_text.dart';
import 'package:flutter_application_1/presentation/widgets/user_profile_popup.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/models/comment.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/board/post_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  Post? _post;
  Map<String, List<Comment>> _groupedComments = {};
  bool _isLoading = true;
  bool _isLikeLoading = false;

  // 댓글 입력 관련 상태
  String? _replyToCommentId;
  String? _replyToUserName;
  String? _mentionedUserId;
  String? _mentionedUserName;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
      final groupedComments = await _postService.getGroupedCommentsByPostId(
        widget.postId,
      );

      if (mounted) {
        setState(() {
          _post = post;
          _groupedComments = groupedComments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('게시글 로드 중 오류가 발생했습니다: $e')));
      }
    }
  }

  // _handleCommentSubmit 메서드 추가
  Future<void> _handleCommentSubmit(
    String content,
    String? parentCommentId,
    String? mentionedUserName,
  ) async {
    if (_post == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 작성하려면 로그인이 필요합니다.')));
      return;
    }

    setState(() {});

    try {
      // 멘션된 사용자 ID 가져오기
      String? mentionedUserId;
      if (mentionedUserName != null) {
        // 닉네임으로 사용자 검색
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('nickname', isEqualTo: mentionedUserName)
                .limit(1)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          mentionedUserId = querySnapshot.docs.first.id;
        }
      }

      // 댓글 또는 답글 생성
      final comment = Comment(
        id: '',
        postId: widget.postId,
        content: content,
        authorId: user.id,
        authorName: user.name,
        authorProfileImage: user.profileImage,
        createdAt: Timestamp.now(),
        parentId: parentCommentId, // 답글인 경우 부모 댓글 ID 설정
        mentionedUserId: mentionedUserId, // 멘션된 사용자 ID 설정
        mentionedUserName: mentionedUserName, // 멘션된 사용자 이름 설정
      );

      await _postService.addComment(comment);

      // 답글 모드 초기화
      _cancelReplyMode();

      // 댓글 및 게시글 다시 로드
      final groupedComments = await _postService.getGroupedCommentsByPostId(
        widget.postId,
      );
      final updatedPost = await _postService.getPostById(widget.postId);

      if (mounted) {
        setState(() {
          _groupedComments = groupedComments;
          _post = updatedPost;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 작성 중 오류가 발생했습니다: $e')));
      }
    }
  }

  // 좋아요 토글 기능
  Future<void> _toggleLike() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null || _post == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('좋아요를 하려면 로그인이 필요합니다')));
      return;
    }

    // 이미 처리 중인 경우 중복 요청 방지
    if (_isLikeLoading) return;

    setState(() {
      _isLikeLoading = true;
    });

    try {
      await _postService.toggleLike(_post!.id, user.id);
      // 게시글 다시 로드하여 좋아요 상태 갱신
      final updatedPost = await _postService.getPostById(_post!.id);

      if (mounted && updatedPost != null) {
        setState(() {
          _post = updatedPost;
          _isLikeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다: $e')));
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  // 태그 색상 가져오기
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
      default:
        return Colors.grey;
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다: $e')));
        }
      }
    }
  }

  // 답글 모드 설정 - 특정 댓글에 답글 달기
  void _setReplyMode(Comment parentComment) {
    setState(() {
      _replyToCommentId = parentComment.id;
      _replyToUserName = parentComment.authorName;
      _mentionedUserId = parentComment.authorId;
      _mentionedUserName = parentComment.authorName;

      // 댓글 입력창에 @사용자명 자동 추가
      _commentController.text = '@${parentComment.authorName} ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });

    // 댓글 입력창 포커스
    _commentFocusNode.requestFocus();
  }

  // 답글 모드 취소
  void _cancelReplyMode() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
      _mentionedUserId = null;
      _mentionedUserName = null;
      _commentController.clear();
    });
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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

        // 댓글 및 게시글 다시 로드
        final groupedComments = await _postService.getGroupedCommentsByPostId(
          widget.postId,
        );
        final updatedPost = await _postService.getPostById(widget.postId);

        if (mounted) {
          setState(() {
            _groupedComments = groupedComments;
            _post = updatedPost;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('댓글이 삭제되었습니다.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('댓글 삭제 중 오류가 발생했습니다: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일을 열 수 없습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final isAuthor =
        _post != null && user != null && _post!.authorId == user.id;
    final isAdmin = user?.isAdmin ?? false;

    // 좋아요 상태 확인
    final bool isLiked =
        user != null && _post != null ? _post!.isLikedBy(user.id) : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          if (isAuthor || isAdmin)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder:
                  (context) => [
                    if (isAuthor)
                      const PopupMenuItem(value: 'edit', child: Text('수정')),
                    if (isAuthor || isAdmin)
                      const PopupMenuItem(value: 'delete', child: Text('삭제')),
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _post == null
              ? const Center(
                child: Text(
                  '게시글을 찾을 수 없습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                          // 태그 표시
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getTagColor(_post!.tag).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _post!.displayTag,
                              style: TextStyle(
                                color: _getTagColor(_post!.tag),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

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
                              Expanded(
                                child: FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(_post!.authorId)
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
                                      authorId: _post!.authorId,
                                      authorName: _post!.authorName,
                                      authorNickname: nickname,
                                      authorProfileImage:
                                          _post!.authorProfileImage,
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
                              Text(
                                DateFormat(
                                  'yyyy.MM.dd HH:mm',
                                ).format(_post!.createdAt.toDate()),
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
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),

                          // 첨부 파일
                          if (_post!.attachments != null &&
                              _post!.attachments!.isNotEmpty) ...[
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

                          const SizedBox(height: 24),

                          // 좋아요 버튼
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _isLikeLoading ? null : _toggleLike,
                              icon: Icon(
                                isLiked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                color:
                                    isLiked
                                        ? AppColors.primary
                                        : Colors.grey[600],
                                size: 20,
                              ),
                              label: Text(
                                '좋아요 ${_post!.likeCount}',
                                style: TextStyle(
                                  color:
                                      isLiked
                                          ? AppColors.primary
                                          : Colors.grey[600],
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color:
                                      isLiked
                                          ? AppColors.primary
                                          : Colors.grey[300]!,
                                ),
                                backgroundColor:
                                    isLiked
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.transparent,
                              ),
                            ),
                          ),

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
                                _post!.commentCount.toString(),
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
                          if (_groupedComments.isEmpty)
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  _groupedComments.entries.map((entry) {
                                    final comments = entry.value;
                                    if (comments.isEmpty)
                                      return const SizedBox.shrink();

                                    // 부모 댓글
                                    final parentComment = comments[0];

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 부모 댓글 위젯
                                        _buildCommentItem(
                                          parentComment,
                                          isParent: true,
                                        ),

                                        // 대댓글이 있는 경우
                                        if (comments.length > 1)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 40,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children:
                                                  comments
                                                      .sublist(1)
                                                      .map(
                                                        (comment) =>
                                                            _buildCommentItem(
                                                              comment,
                                                              isParent: false,
                                                            ),
                                                      )
                                                      .toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 8), // 댓글 그룹 간 간격
                                      ],
                                    );
                                  }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 댓글 입력창
                  CommentInputWithMention(
                    onSubmit: _handleCommentSubmit,
                    replyToUserName: _replyToUserName,
                    parentCommentId: _replyToCommentId,
                    onCancelReply: _cancelReplyMode,
                  ),
                ],
              ),
    );
  }

  // 댓글 항목 위젯
  Widget _buildCommentItem(Comment comment, {required bool isParent}) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final isAuthor = user != null && user.id == comment.authorId;
    final isAdmin = user?.isAdmin ?? false;

    final createdDate = DateFormat(
      'yyyy.MM.dd HH:mm',
    ).format(comment.createdAt.toDate());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 정보 표시 (AuthorInfoWidget 사용)
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(comment.authorId)
                          .get(),
                  builder: (context, snapshot) {
                    // 닉네임 정보 가져오기
                    String? nickname;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      nickname = userData['nickname'] as String?;
                    }

                    return AuthorInfoWidget(
                      authorId: comment.authorId,
                      authorName: comment.authorName,
                      authorNickname: nickname,
                      authorProfileImage: comment.authorProfileImage,
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
              Text(
                createdDate,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),

              // 답글/삭제 버튼
              Row(
                children: [
                  if (isParent && userProvider.isLoggedIn)
                    TextButton(
                      onPressed: () => _setReplyMode(comment),
                      child: const Text(
                        '답글',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isAuthor || isAdmin)
                    TextButton(
                      onPressed: () => _deleteComment(comment),
                      child: const Text(
                        '삭제',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 댓글 내용
          // 댓글 내용 - 여기를 MentionHighlightText 위젯으로 교체
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: MentionHighlightText(
              text: comment.content,
              defaultStyle: const TextStyle(fontSize: 14, height: 1.4),
              mentionStyle: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
