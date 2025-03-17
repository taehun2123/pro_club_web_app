// lib/presentation/screens/gallery/gallery_detail_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/data/models/gallery.dart';
import 'package:flutter_application_1/data/services/gallery_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/gallery/gallery_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

class GalleryDetailScreen extends StatefulWidget {
  final String galleryId;

  const GalleryDetailScreen({Key? key, required this.galleryId})
    : super(key: key);

  @override
  _GalleryDetailScreenState createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  final GalleryService _galleryService = GalleryService();

  Gallery? _gallery;
  bool _isLoading = true;
  bool _isDeleting = false;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // URL 정리 함수
  // 이미지 URL 정리 함수 수정
String _cleanUrl(String url) {
  try {
    // 이미 '%2F'가 포함된 URL은 그대로 사용
    if (url.contains('%2F') && url.contains('?alt=media')) {
      return url;
    }
    
    // '/'가 포함된 URL은 '%2F'로 변환
    if (url.contains('/galleries/')) {
      // 경로 추출
      final parts = url.split('/galleries/');
      if (parts.length > 1) {
        final basePath = parts[0];
        String objectPath = 'galleries/' + parts[1];
        
        // 쿼리 파라미터 제거
        if (objectPath.contains('?')) {
          objectPath = objectPath.split('?')[0];
        }
        
        // 슬래시를 %2F로 변환
        objectPath = objectPath.replaceAll('/', '%2F');
        
        // 새 URL 생성
        return '$basePath/o/$objectPath?alt=media';
      }
    }
    
    return url;
  } catch (e) {
    print('URL 변환 오류: $e');
    return url;
  }
}

  Future<void> _loadGallery() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 조회수 증가
      await _galleryService.incrementViewCount(widget.galleryId);

      // 갤러리 데이터 로드
      final gallery = await _galleryService.getGalleryById(widget.galleryId);

      if (mounted) {
        setState(() {
          _gallery = gallery;
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
        ).showSnackBar(SnackBar(content: Text('갤러리 로드 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _deleteGallery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('갤러리 삭제'),
            content: const Text('이 갤러리를 삭제하시겠습니까? 모든 이미지가 삭제됩니다.'),
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
        setState(() {
          _isDeleting = true;
        });

        await _galleryService.deleteGallery(widget.galleryId);

        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('갤러리가 삭제되었습니다.')));
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('갤러리 삭제 중 오류가 발생했습니다: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final isAuthor =
        _gallery != null && user != null && _gallery!.authorId == user.id;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_gallery?.title ?? '갤러리'),
        actions: [
          if (isAuthor || isAdmin)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
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
                      builder:
                          (context) => GalleryFormScreen(gallery: _gallery),
                    ),
                  ).then((_) {
                    _loadGallery();
                  });
                } else if (value == 'delete') {
                  _deleteGallery();
                }
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _isDeleting
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '갤러리 삭제 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
              : _gallery == null
              ? const Center(
                child: Text(
                  '갤러리를 찾을 수 없습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : _gallery!.images.isEmpty
              ? const Center(
                child: Text(
                  '이미지가 없습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : Stack(
                children: [
                  // 이미지 갤러리
                  PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      String imageUrl = _gallery!.images[index];

                      // URL 정리 (토큰 제거 및 올바른 형식으로 변환)
                      imageUrl = _cleanUrl(imageUrl);

                      return PhotoViewGalleryPageOptions(
                        imageProvider: NetworkImage(imageUrl),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 2,
                        errorBuilder: (context, error, stackTrace) {
                          print('이미지 로드 에러: $error, URL: $imageUrl');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  '이미지를 불러올 수 없습니다',
                                  style: TextStyle(color: Colors.white),
                                ),
                                if (kIsWeb) ...[
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final url = Uri.parse(imageUrl);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: Text('새 탭에서 열기'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: _gallery!.images.length,
                    loadingBuilder:
                        (context, event) => Center(
                          child: CircularProgressIndicator(
                            value:
                                event == null
                                    ? 0
                                    : event.cumulativeBytesLoaded /
                                        (event.expectedTotalBytes ?? 1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    pageController: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),

                  // 하단 정보 패널
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _gallery!.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_gallery!.description.isNotEmpty)
                            Text(
                              _gallery!.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                _gallery!.authorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy.MM.dd',
                                ).format(_gallery!.createdAt.toDate()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_currentIndex + 1} / ${_gallery!.images.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
