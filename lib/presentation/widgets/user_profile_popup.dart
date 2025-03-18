import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/app_user.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'dart:math' as math;
import 'package:flutter_application_1/presentation/screens/board/post_detail_screen.dart'; // math 패키지 추가

/// 사용자 프로필 팝업 위젯
/// 게시글이나 댓글에서 사용자 프로필을 클릭했을 때 표시됨
class UserProfilePopup extends StatelessWidget {
  final String userId;
  
  const UserProfilePopup({
    Key? key,
    required this.userId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return const Center(child: Text('사용자 정보를 불러올 수 없습니다.'));
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('사용자를 찾을 수 없습니다.'));
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final user = AppUser.fromMap(userData);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            // double.min 대신 math.min 사용
            width: math.min(MediaQuery.of(context).size.width * 0.8, 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 프로필 이미지
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user.profileImage != null
                      ? CachedNetworkImageProvider(user.profileImage!)
                      : null,
                  child: user.profileImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                
                // 이름 및 닉네임
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.nickname != null && user.nickname!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '(@${user.nickname})',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                
                // 역할 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isAdmin 
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.isAdmin ? '관리자' : '회원',
                    style: TextStyle(
                      fontSize: 14,
                      color: user.isAdmin ? AppColors.primary : Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 추가 정보
                if (user.studentId != null) _buildInfoRow(Icons.school, user.studentId!),
                if (user.email.isNotEmpty) _buildInfoRow(Icons.email, user.email),
                if (user.age != null) _buildInfoRow(Icons.cake, '${user.age}세'),
                
                const SizedBox(height: 20),
                
                // 사용자 게시글 목록
                FutureBuilder<List<dynamic>>(
                  future: _getUserPosts(userId),
                  builder: (context, postsSnapshot) {
                    if (postsSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    
                    if (!postsSnapshot.hasData || postsSnapshot.data!.isEmpty) {
                      return const Text('작성한 게시글이 없습니다.', style: TextStyle(color: Colors.grey));
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '최근 작성 게시글',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...postsSnapshot.data!.take(3).map((post) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              post.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${post.dateString} · 조회 ${post.viewCount}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              // 게시글 화면으로 이동
                              Navigator.pop(context); // 팝업 닫기
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(postId: post.id),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // 닫기 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mediumGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<List<dynamic>> _getUserPosts(String userId) async {
    final PostService postService = PostService();
    return postService.getUserPosts(userId, limit: 3);
  }
}

/// 게시글이나 댓글의 작성자 정보 표시를 위한 위젯
/// 프로필 이미지, 이름, 닉네임을 함께 표시하고 클릭 시 프로필 팝업 표시
class AuthorInfoWidget extends StatelessWidget {
  final String authorId;
  final String authorName;
  final String? authorNickname;
  final String? authorProfileImage;
  final double avatarRadius;
  final TextStyle? nameStyle;
  final TextStyle? nicknameStyle;
  
  const AuthorInfoWidget({
    Key? key,
    required this.authorId,
    required this.authorName,
    this.authorNickname,
    this.authorProfileImage,
    this.avatarRadius = 16,
    this.nameStyle,
    this.nicknameStyle,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // 프로필 팝업 표시
        showDialog(
          context: context,
          builder: (context) => UserProfilePopup(userId: authorId),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 프로필 이미지
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.grey[200],
              backgroundImage: authorProfileImage != null
                  ? CachedNetworkImageProvider(authorProfileImage!)
                  : null,
              child: authorProfileImage == null
                  ? Icon(Icons.person, size: avatarRadius, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            
            // 이름과 닉네임
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  authorName,
                  style: nameStyle ?? const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (authorNickname != null && authorNickname!.isNotEmpty)
                  Text(
                    '@$authorNickname',
                    style: nicknameStyle ?? TextStyle(
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
  }
}