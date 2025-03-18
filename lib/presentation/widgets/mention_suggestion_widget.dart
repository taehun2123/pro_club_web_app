import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/services/notification_service.dart';

class MentionSuggestionWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String userId, String nickname) onMentionSelected;
  
  const MentionSuggestionWidget({
    Key? key,
    required this.controller,
    required this.onMentionSelected,
  }) : super(key: key);
  
  @override
  _MentionSuggestionWidgetState createState() => _MentionSuggestionWidgetState();
}

class _MentionSuggestionWidgetState extends State<MentionSuggestionWidget> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  String _currentMentionQuery = '';
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
  
  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    
    if (selection.baseOffset < 0 || selection.baseOffset > text.length) {
      setState(() {
        _showSuggestions = false;
      });
      return;
    }
    
    // 커서 위치 이전 텍스트
    final beforeCursor = text.substring(0, selection.baseOffset);
    
    // @에서 시작하는 멘션 찾기 - 영어, 한글, 숫자 등 모든 문자 지원
    // r'@([^\s@]+)$' 패턴은 '@' 다음에 공백이나 '@'가 아닌 모든 문자를 찾음
    final mentionMatch = RegExp(r'@([^\s@]*)$').firstMatch(beforeCursor);
    
    if (mentionMatch != null) {
      final query = mentionMatch.group(1) ?? '';
      
      if (query != _currentMentionQuery) {
        _currentMentionQuery = query;
        _searchUsers(query);
      }
      
      setState(() {
        _showSuggestions = true;
      });
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }
  
  Future<void> _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final suggestions = await _notificationService.searchUsersByNickname(query);
      
      setState(() {
        _userSuggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      print('사용자 검색 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _selectUser(Map<String, dynamic> user) {
    try {
      final text = widget.controller.text;
      
      // 선택이 유효한지 확인
      if (!widget.controller.selection.isValid || 
          widget.controller.selection.baseOffset > text.length) {
        // 유효하지 않은 선택 처리
        print('유효하지 않은 커서 위치');
        return;
      }
      
      final selection = widget.controller.selection;
      
      // 현재 @부터 커서까지 찾기
      final beforeCursor = text.substring(0, selection.baseOffset);
      final afterCursor = text.substring(selection.baseOffset);
      
      // 한글 포함 멘션 패턴 찾기
      final mentionMatch = RegExp(r'@[^\s@]*$').firstMatch(beforeCursor);
      
      if (mentionMatch != null) {
        final start = mentionMatch.start;
        final nickname = user['nickname'] ?? user['name'];
        
        if (start >= 0 && start <= beforeCursor.length) {
          // 텍스트 업데이트
          final newText = beforeCursor.substring(0, start) + '@$nickname ' + afterCursor;
          
          // 커서 위치 계산 - 안전 처리 추가
          final newPosition = (start + nickname.length + 2) // @ + 닉네임 + 공백
                              .clamp(0, newText.length) // 텍스트 길이 범위 내로 제한
                              .toInt(); // int로 변환
          
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newPosition),
          );
          
          // 멘션 선택 콜백 호출
          widget.onMentionSelected(user['id'], nickname);
          
          setState(() {
            _showSuggestions = false;
          });
        }
      }
    } catch (e) {
      print('멘션 선택 오류: $e');
      // 오류 처리 - 기본 텍스트 유지
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_showSuggestions) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          : _userSuggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('검색 결과가 없습니다.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _userSuggestions.length,
                  itemBuilder: (context, index) {
                    final user = _userSuggestions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profileImage'] != null
                            ? CachedNetworkImageProvider(user['profileImage'])
                            : null,
                        child: user['profileImage'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user['nickname'] ?? user['name']),
                      subtitle: user['nickname'] != null && user['name'] != null
                          ? Text(user['name'])
                          : null,
                      dense: true,
                      onTap: () => _selectUser(user),
                    );
                  },
                ),
    );
  }
}