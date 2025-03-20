// 언급된 텍스트를 감지하고 스타일을 적용하는 위젯
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/widgets/user_profile_popup.dart';

class MentionHighlightText extends StatelessWidget {
  final String text;
  final TextStyle defaultStyle;
  final TextStyle mentionStyle;
  
  const MentionHighlightText({
    Key? key,
    required this.text,
    required this.defaultStyle,
    required this.mentionStyle,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 언급 패턴 정규식 (@다음에 공백이 아닌 문자열)
    final mentionRegex = RegExp(r'@(\S+)');
    
    // 텍스트 스팬 리스트
    List<TextSpan> textSpans = [];
    
    // 마지막 매치 위치
    int lastIndex = 0;
    
    // 매치된 모든 언급 찾기
    for (final match in mentionRegex.allMatches(text)) {
      // 언급 이전 텍스트 추가
      if (match.start > lastIndex) {
        textSpans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }
      
      // 언급 텍스트 (클릭 가능한 스팬으로)
      final mention = match.group(0); // @username 전체
      final username = match.group(1); // username 부분만
      
      if (mention != null && username != null) {
        textSpans.add(
          TextSpan(
            text: mention,
            style: mentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // 사용자 이름으로 Firestore에서 사용자 ID 검색
                _findUserIdByName(context, username);
              },
          ),
        );
      }
      
      lastIndex = match.end;
    }
    
    // 마지막 매치 이후의 텍스트 추가
    if (lastIndex < text.length) {
      textSpans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }
    
    return RichText(
      text: TextSpan(children: textSpans),
    );
  }
  
  // 사용자 이름으로 사용자 ID 찾기
  Future<void> _findUserIdByName(BuildContext context, String username) async {
    try {
      // 닉네임으로 사용자 검색
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: username)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final userId = querySnapshot.docs.first.id;
        
        // 프로필 팝업 표시
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => UserProfilePopup(userId: userId),
          );
        }
      } else {
        // 닉네임이 없으면 이름으로 검색
        final nameQuerySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: username)
            .limit(1)
            .get();
            
        if (nameQuerySnapshot.docs.isNotEmpty && context.mounted) {
          final userId = nameQuerySnapshot.docs.first.id;
          showDialog(
            context: context,
            builder: (context) => UserProfilePopup(userId: userId),
          );
        }
      }
    } catch (e) {
      print('사용자 검색 오류: $e');
    }
  }
}