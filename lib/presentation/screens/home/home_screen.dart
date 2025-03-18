// lib/presentation/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/widgets/notification_icon.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/notice/notice_list_screen.dart';
import 'package:flutter_application_1/presentation/screens/calendar/calendar_screen.dart';
import 'package:flutter_application_1/presentation/screens/board/board_list_screen.dart';
import 'package:flutter_application_1/presentation/screens/board/post_detail_screen.dart';
import 'package:flutter_application_1/presentation/screens/gallery/gallery_screen.dart';
import 'package:flutter_application_1/presentation/screens/profile/profile_screen.dart';
import 'package:flutter_application_1/presentation/widgets/notice_card.dart';
import 'package:flutter_application_1/presentation/widgets/event_card.dart';
import 'package:flutter_application_1/presentation/widgets/gallery_preview.dart';
import 'package:flutter_application_1/data/services/notice_service.dart';
import 'package:flutter_application_1/data/services/event_service.dart';
import 'package:flutter_application_1/data/services/gallery_service.dart';
import 'package:flutter_application_1/data/services/post_service.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  
  const HomeScreen({
    Key? key, 
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  
  late int _currentIndex;

  final List<Widget> _screens = [
    const HomeTab(),
    const CalendarScreen(),
    const NoticeListScreen(),
    const BoardListScreen(),
    const GalleryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mediumGray,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '일정',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement_outlined),
            activeIcon: Icon(Icons.announcement),
            label: '공지사항',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: '게시판',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: '갤러리',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final NoticeService _noticeService = NoticeService();
  final EventService _eventService = EventService();
  final GalleryService _galleryService = GalleryService();
  final PostService _postService = PostService(); // 게시글 서비스 추가

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
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        actions: [
          const NotificationIcon(),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 환영 메시지
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, ${user.name}님',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '오늘도 PRO 동아리와 함께하세요!',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

              // 중요 공지사항
              const Text(
                '중요 공지사항',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder(
                future: _noticeService.getImportantNotices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
                  }

                  final notices = snapshot.data ?? [];

                  if (notices.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('중요 공지사항이 없습니다.')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notices.length > 3 ? 3 : notices.length,
                    itemBuilder: (context, index) {
                      return NoticeCard(notice: notices[index]);
                    },
                  );
                },
              ),

              // 모든 공지사항 보기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NoticeListScreen(),
                      ),
                    );
                  },
                  child: const Text('모든 공지사항 보기 >'),
                ),
              ),

              const SizedBox(height: 24),

              // 핫 게시글 섹션 추가
              Row(
                children: [
                  const Text(
                    '핫 게시글',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.red, size: 16),
                        SizedBox(width: 2),
                        Text(
                          'HOT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Post>>(
                future: _postService.getHotPosts(limit: 3),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
                  }

                  final posts = snapshot.data ?? [];

                  if (posts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('인기 게시글이 없습니다.')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final createdDate = DateFormat('yyyy.MM.dd').format(post.createdAt.toDate());
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(postId: post.id),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // 태그 표시
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
                                    // 좋아요 카운트 배지
                                    if (post.likeCount > 0) 
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
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
                                              size: 12,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              post.likeCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // 댓글 카운트 배지
                                    if (post.commentCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          post.commentCount.toString(),
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.content,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      post.authorName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      createdDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          post.viewCount.toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // 모든 게시글 보기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // 게시판 탭으로 이동
                    final parentContext = context;
                    Future.delayed(Duration.zero, () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(initialIndex: 3),
                        ),
                      );
                    });
                  },
                  child: const Text('모든 게시글 보기 >'),
                ),
              ),

              const SizedBox(height: 24),

              // 오늘의 일정
              const Text(
                '오늘의 일정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder(
                future: _eventService.getTodayEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
                  }

                  final events = snapshot.data ?? [];

                  if (events.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('오늘 예정된 일정이 없습니다.')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      return EventCard(event: events[index]);
                    },
                  );
                },
              ),

              // 캘린더 바로가기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // 캘린더 탭으로 이동
                    final parentContext = context;
                    Future.delayed(Duration.zero, () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(initialIndex: 1),
                        ),
                      );
                    });
                  },
                  child: const Text('캘린더 보기 >'),
                ),
              ),

              const SizedBox(height: 24),

              // 최근 갤러리
              const Text(
                '최근 갤러리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder(
                future: _galleryService.getRecentGalleries(limit: 6),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
                  }

                  final galleries = snapshot.data ?? [];

                  if (galleries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('갤러리 항목이 없습니다.')),
                    );
                  }

                  return GalleryPreview(galleries: galleries);
                },
              ),

              // 갤러리 바로가기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // 갤러리 탭으로 이동
                    final parentContext = context;
                    Future.delayed(Duration.zero, () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(initialIndex: 4),
                        ),
                      );
                    });
                  },
                  child: const Text('모든 갤러리 보기 >'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}