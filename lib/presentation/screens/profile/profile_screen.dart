// lib/presentation/screens/profile/profile_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/auth/login_screen.dart';
import 'package:flutter_application_1/presentation/screens/board/post_detail_screen.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 사용자 데이터 새로고침
  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        userProvider.setUser(userData);
      }
    } catch (e) {
      print('사용자 데이터 로드 실패: $e');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('로그아웃 하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (!mounted) return;

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.clearUser();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      XFile? pickedFile;

      if (kIsWeb) {
        // 웹 환경에서는 다른 방식 사용
        pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);

        if (pickedFile == null) return;

        setState(() {
          _isLoading = true;
        });

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final user = userProvider.user;

        if (user == null) {
          throw Exception('사용자 정보를 찾을 수 없습니다.');
        }

        // 웹에서는 파일 데이터 직접 읽기
        final bytes = await pickedFile.readAsBytes();

        // 웹 전용 파라미터 전달
        await _authService.updateUserProfile(webImageData: bytes);
      } else {
        // 모바일 환경
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );

        if (pickedFile == null) return;

        setState(() {
          _isLoading = true;
        });

        // 모바일용 파일 객체 전달
        await _authService.updateUserProfile(imageFile: File(pickedFile.path));
      }

      // 사용자 정보 새로고침
      await _loadUserData();

      // UI 갱신
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필 이미지가 업데이트되었습니다.')));
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('프로필 이미지 업데이트 중 오류가 발생했습니다: $e')));
    }
  }

  // 별명(닉네임) 수정 다이얼로그를 표시하는 함수
  void _showEditNicknameDialog() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user == null) return;
    
    final TextEditingController nicknameController = TextEditingController();
    nicknameController.text = user.nickname ?? '';
    
    showDialog(
      context: context,
      builder: (context) => EditNicknameDialog(
        initialNickname: user.nickname ?? '',
        nicknameController: nicknameController,
      ),
    ).then((updated) {
      if (updated == true) {
        // 닉네임 업데이트 후 사용자 정보 새로고침
        _loadUserData();
      }
    });
  }

  // 별명(닉네임) 표시 및 수정 버튼
  Widget _buildNicknameSection() {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          user.nickname != null && user.nickname!.isNotEmpty
              ? '@${user.nickname}'
              : '별명 없음',
          style: TextStyle(
            fontSize: 16,
            color: user.nickname != null && user.nickname!.isNotEmpty
                ? AppColors.primary
                : Colors.grey,
            fontStyle: user.nickname != null && user.nickname!.isNotEmpty
                ? FontStyle.normal
                : FontStyle.italic,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 16),
          onPressed: _showEditNicknameDialog,
          color: AppColors.primary,
          padding: const EdgeInsets.only(left: 4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: Column(
        children: [
          // 프로필 정보
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 프로필 이미지
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _updateProfileImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            user.profileImage != null
                                ? CachedNetworkImageProvider(user.profileImage!)
                                : null,
                        child:
                            user.profileImage == null
                                ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                                : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 사용자 이름
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                
                // 별명 표시 및 수정 버튼
                _buildNicknameSection(),
                const SizedBox(height: 8),

                // 이메일
                Text(
                  user.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),

                // 회원 유형
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        user.isAdmin
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.isAdmin ? '관리자' : '일반 회원',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          user.isAdmin ? AppColors.primary : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 탭바
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.primary,
            tabs: const [Tab(text: '내가 쓴 글'), Tab(text: '활동 내역')],
          ),

          // 탭바 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 내가 쓴 글
                _MyPostsTab(userId: user.id),

                // 활동 내역
                const Center(child: Text('준비 중입니다.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 별명(닉네임) 수정 다이얼로그 위젯
class EditNicknameDialog extends StatefulWidget {
  final String initialNickname;
  final TextEditingController nicknameController;
  
  const EditNicknameDialog({
    Key? key,
    required this.initialNickname,
    required this.nicknameController,
  }) : super(key: key);
  
  @override
  _EditNicknameDialogState createState() => _EditNicknameDialogState();
}

class _EditNicknameDialogState extends State<EditNicknameDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('별명 변경'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '새로운 별명을 입력하세요.\n별명은 멘션(@)에 사용됩니다.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: widget.nicknameController,
              label: '별명',
              hintText: '별명을 입력하세요',
              validator: _validateNickname,
              onChanged: (value) {
                // 입력값이 변경되면 오류 메시지 초기화
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        _isLoading
            ? Container(
                margin: const EdgeInsets.only(left: 8, right: 8),
                width: 24,
                height: 24,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: _updateNickname,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('저장'),
              ),
      ],
    );
  }
  
  String? _validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return null; // 빈 값은 허용 (별명 제거)
    }
    
    if (value.length < 2) {
      return '별명은 2자 이상이어야 합니다';
    }
    
    if (value.length > 20) {
      return '별명은 20자 이하여야 합니다';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9가-힣\s]+$').hasMatch(value)) {
      return '별명은 한글, 영문, 숫자, 공백만 사용할 수 있습니다';
    }
    
    return null;
  }
  
  Future<void> _updateNickname() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      final newNickname = widget.nicknameController.text.trim();
      
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }
      
      // 기존 닉네임과 동일한 경우 변경 없이 종료
      if (newNickname == widget.initialNickname) {
        Navigator.pop(context, false);
        return;
      }
      
      // 닉네임 중복 확인 (빈 값이 아닌 경우에만)
      if (newNickname.isNotEmpty) {
        final nicknameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('nickname', isEqualTo: newNickname)
            .get();
            
        if (nicknameQuery.docs.isNotEmpty) {
          // 이미 사용 중인 닉네임
          setState(() {
            _isLoading = false;
            _errorMessage = '이미 사용 중인 별명입니다';
          });
          return;
        }
      }
      
      // 닉네임 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'nickname': newNickname,
          });
      
      // UserProvider 업데이트
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser(authService);
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '별명 변경 중 오류가 발생했습니다: $e';
      });
    }
  }
}

class _MyPostsTab extends StatefulWidget {
  final String userId;

  const _MyPostsTab({Key? key, required this.userId}) : super(key: key);

  @override
  __MyPostsTabState createState() => __MyPostsTabState();
}

class __MyPostsTabState extends State<_MyPostsTab> {
  final PostService _postService = PostService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _postService.getUserPosts(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('데이터 로드 중 오류가 발생했습니다: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(child: Text('작성한 게시글이 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final post = posts[index];
            final createdDate = DateFormat(
              'yyyy.MM.dd',
            ).format(post.createdAt.toDate());

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(postId: post.id),
                  ),
                ).then((_) {
                  setState(() {}); // 돌아오면 새로고침
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      post.content,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
        );
      },
    );
  }
}