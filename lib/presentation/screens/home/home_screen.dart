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
import 'package:flutter/foundation.dart' show kIsWeb;

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 각 화면은 별도의 위젯으로 분리
  late final List<Widget> _screens;

  // 화면 제목 목록
  final List<String> _screenTitles = [
    '홈',
    '일정',
    '공지사항',
    '게시판',
    '갤러리',
  ];

  // 화면 아이콘 목록
  final List<IconData> _screenIcons = [
    Icons.home,
    Icons.calendar_today,
    Icons.announcement,
    Icons.forum,
    Icons.photo_library,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserData();
    
    // 화면 초기화 - HomeTab은 패딩이 있는 버전과 없는 버전을 따로 설정
    _screens = [
      const HomeTabWithPadding(), // 패딩이 적용된 홈 탭
      const CalendarScreen(),
      const NoticeListScreen(),
      const BoardListScreen(),
      const GalleryScreen(),
    ];
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
    // 화면 너비에 따라 웹 또는 모바일 레이아웃 결정
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebLayout = kIsWeb && screenWidth > 768; // 태블릿/데스크탑 크기

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // 웹 레이아웃에서만 드로워 토글 버튼 표시
        leading: isWebLayout
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              )
            : null,
        centerTitle: true, // 제목 중앙 정렬
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0), // 로고 상하 여백 추가
          child: Image.asset(
            'assets/images/proxgoorm.png',
            width: 200,
            height: 120,
            fit: BoxFit.contain, // 로고 비율 유지
          ),
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
          const SizedBox(width: 8), // 오른쪽 여백 추가
        ],
      ),
      // 웹 레이아웃용 드로워 메뉴
      drawer: isWebLayout
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/proxgoorm.png',
                          width: 200,
                          height: 110,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // 메뉴 항목들
                  for (int i = 0; i < _screenTitles.length; i++)
                    ListTile(
                      leading: Icon(
                        _screenIcons[i],
                        color: _currentIndex == i ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        _screenTitles[i],
                        style: TextStyle(
                          fontWeight: _currentIndex == i ? FontWeight.bold : FontWeight.normal,
                          color: _currentIndex == i ? AppColors.primary : Colors.black,
                        ),
                      ),
                      selected: _currentIndex == i,
                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                      onTap: () {
                        setState(() {
                          _currentIndex = i;
                        });
                        Navigator.pop(context); // 드로워 닫기
                      },
                    ),
                  const Divider(),
                  // 추가 메뉴 항목
                  // 로그아웃 메뉴
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      if (userProvider.isLoggedIn) {
                        return ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                          onTap: () async {
                            Navigator.pop(context);
                            await _authService.signOut();
                            if (!mounted) return;
                            userProvider.clearUser();
                            // 로그아웃 후 처리 로직
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        bottom: true, // 하단 SafeArea 활성화
        // 홈 화면(첫 번째 탭)에만 추가 패딩 없음, 나머지 스크린은 그대로 표시
        child: Column(
          children: [
            // 메인 콘텐츠 영역
            Expanded(
              child: _screens[_currentIndex],
            ),
            // 하단 여백 - 하단 네비게이션 바의 높이만큼 추가
            SizedBox(height: isWebLayout ? 0 : 16), // 모바일 레이아웃에서만 추가 여백 설정
          ],
        ),
      ),
      // 모바일 레이아웃에서만 하단 네비게이션 바 표시
      bottomNavigationBar: isWebLayout
          ? null
          : Container(
              margin: const EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 16, // 하단 여백 추가
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // 둥근 모서리 추가
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), // 내부 콘텐츠도 둥근 모서리 적용
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.mediumGray,
                  backgroundColor: Colors.white,
                  elevation: 15,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: _screenTitles[0],
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.calendar_today_outlined),
                      activeIcon: const Icon(Icons.calendar_today),
                      label: _screenTitles[1],
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.announcement_outlined),
                      activeIcon: const Icon(Icons.announcement),
                      label: _screenTitles[2],
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.forum_outlined),
                      activeIcon: const Icon(Icons.forum),
                      label: _screenTitles[3],
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.photo_library_outlined),
                      activeIcon: const Icon(Icons.photo_library),
                      label: _screenTitles[4],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 패딩이 적용된 홈 탭 - 기존 HomeTab 위젯에서 패딩만 추가
class HomeTabWithPadding extends StatelessWidget {
  const HomeTabWithPadding({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWebLayout = kIsWeb && MediaQuery.of(context).size.width > 768;
    
    // 패딩을 적용한 HomeTab - 웹과 모바일에 각각 다른 패딩 적용
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWebLayout ? 24.0 : 16.0, // 웹에서는 더 넓은 좌우 패딩
        vertical: isWebLayout ? 16.0 : 8.0, // 웹에서는 더 넓은 상하 패딩
      ),
      child: const HomeTab(), // 기존 HomeTab 사용
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
    final isWebLayout = kIsWeb && MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: Colors.transparent, // 배경을 투명하게 설정
      // AppBar 제거 - 메인 HomeScreen에 통합됨
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(12), // 카드 모서리 더 둥글게
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12), // 잉크 효과도 모서리 맞춤
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(postId: post.id),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14), // 내부 패딩 증가
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
                    if (isWebLayout) {
                      // 웹 레이아웃에서는 부모 HomeScreen의 _currentIndex를 변경
                      final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                      if (parentState != null) {
                        parentState.setState(() {
                          parentState._currentIndex = 3; // 게시판 인덱스
                        });
                      }
                    } else {
                      // 모바일 레이아웃에서는 기존 방식대로
                      final parentContext = context;
                      Future.delayed(Duration.zero, () {
                        Navigator.of(parentContext).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(initialIndex: 3),
                          ),
                        );
                      });
                    }
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
                    if (isWebLayout) {
                      // 웹 레이아웃에서는 부모 HomeScreen의 _currentIndex를 변경
                      final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                      if (parentState != null) {
                        parentState.setState(() {
                          parentState._currentIndex = 1; // 캘린더 인덱스
                        });
                      }
                    } else {
                      // 모바일 레이아웃에서는 기존 방식대로
                      final parentContext = context;
                      Future.delayed(Duration.zero, () {
                        Navigator.of(parentContext).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(initialIndex: 1),
                          ),
                        );
                      });
                    }
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
                    if (isWebLayout) {
                      // 웹 레이아웃에서는 부모 HomeScreen의 _currentIndex를 변경
                      final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                      if (parentState != null) {
                        parentState.setState(() {
                          parentState._currentIndex = 4; // 갤러리 인덱스
                        });
                      }
                    } else {
                      // 모바일 레이아웃에서는 기존 방식대로
                      final parentContext = context;
                      Future.delayed(Duration.zero, () {
                        Navigator.of(parentContext).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(initialIndex: 4),
                          ),
                        );
                      });
                    }
                  },
                  child: const Text('모든 갤러리 보기 >'),
                ),
              ),

              // 하단 여백 추가 - 모바일 레이아웃에서만 필요
              const SizedBox(height: 20), // 약간 줄임 - 전체 패딩이 상위 위젯에 추가됨
            ],
          ),
        ),
      ),
    );
  }
}