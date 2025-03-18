import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/presentation/widgets/mention_suggestion_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';

class CommentInputWithMention extends StatefulWidget {
  final Function(String, String?, String?) onSubmit;
  final String? replyToUserName;
  final String? parentCommentId;
  final VoidCallback? onCancelReply;
  
  const CommentInputWithMention({
    Key? key,
    required this.onSubmit,
    this.replyToUserName,
    this.parentCommentId,
    this.onCancelReply,
  }) : super(key: key);
  
  @override
  _CommentInputWithMentionState createState() => _CommentInputWithMentionState();
}

class _CommentInputWithMentionState extends State<CommentInputWithMention> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  String? _mentionedUserId;
  String? _mentionedUserName;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    // 답글 모드인 경우 @username 자동 추가
    if (widget.replyToUserName != null) {
      _commentController.text = '@${widget.replyToUserName} ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    }
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }
  
  void _handleMentionSelected(String userId, String username) {
    setState(() {
      _mentionedUserId = userId;
      _mentionedUserName = username;
    });
  }
  
  void _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글을 작성하려면 로그인이 필요합니다')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 댓글 제출
      await widget.onSubmit(
        content,
        widget.parentCommentId ?? _mentionedUserId,
        widget.replyToUserName ?? _mentionedUserName,
      );
      
      // 입력 필드 초기화
      _commentController.clear();
      setState(() {
        _mentionedUserId = null;
        _mentionedUserName = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 작성 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Column(
      children: [
        // 답글 모드 표시
        if (widget.replyToUserName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.replyToUserName}님에게 답글 작성 중',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: widget.onCancelReply,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
        // 멘션 제안 표시
        if (userProvider.isLoggedIn)
          MentionSuggestionWidget(
            controller: _commentController,
            onMentionSelected: _handleMentionSelected,
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
                  focusNode: _commentFocusNode,
                  decoration: InputDecoration(
                    hintText: widget.replyToUserName != null 
                        ? '${widget.replyToUserName}님에게 답글 작성...'
                        : '댓글을 입력하세요',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  enabled: userProvider.isLoggedIn,
                ),
              ),
              const SizedBox(width: 8),
              _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: userProvider.isLoggedIn ? _submitComment : null,
                      color: AppColors.primary,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}