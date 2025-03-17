// lib/presentation/screens/gallery/gallery_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/gallery.dart';
import 'package:flutter_application_1/data/services/gallery_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/gallery/gallery_form_screen.dart';
import 'package:flutter_application_1/presentation/screens/gallery/gallery_detail_screen.dart';
import 'package:intl/intl.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();

  List<Gallery>? _galleries;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  // URL 정리 함수 - Firebase Storage URL 문제 해결
  String _cleanUrl(String url) {
    try {
      if (url.isEmpty) return url;

      // 이미 %2F로 인코딩 되어있으면 그대로 사용
      if (url.contains('%2F') && url.contains('?alt=media')) {
        return url;
      }

      // /galleries/ 형식의 URL 처리
      if (url.contains('/galleries/')) {
        // 경로 추출
        final parts = url.split('/galleries/');
        if (parts.length > 1) {
          String objectPath = 'galleries/' + parts[1];

          // 쿼리 파라미터 제거
          if (objectPath.contains('?')) {
            objectPath = objectPath.split('?')[0];
          }

          // 슬래시를 %2F로 변환
          objectPath = objectPath.replaceAll('/', '%2F');

          // 버킷 이름
          const bucketName = 'proclub-cdd37.firebasestorage.app';

          // 새 URL 생성
          return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$objectPath?alt=media';
        }
      }

      return url;
    } catch (e) {
      print('URL 정리 중 오류 발생: $e');
      return url;
    }
  }

  Future<void> _loadGalleries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final galleries = await _galleryService.getAllGalleries();

      if (mounted) {
        setState(() {
          _galleries = galleries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('갤러리 로드 오류: $e');

      if (mounted) {
        setState(() {
          _errorMessage = '갤러리를 불러오는 중 오류가 발생했습니다';
          _isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('갤러리 로드 중 오류가 발생했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('갤러리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGalleries,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadGalleries, child: _buildContent()),
      floatingActionButton:
          isLoggedIn
              ? FloatingActionButton(
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_photo_alternate),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GalleryFormScreen(),
                    ),
                  ).then((_) {
                    _loadGalleries();
                  });
                },
              )
              : null,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadGalleries,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_galleries == null || _galleries!.isEmpty) {
      return const Center(
        child: Text(
          '갤러리 항목이 없습니다.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8), // 패딩 줄임
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 한 행에 5개 아이템 표시
        childAspectRatio: 0.65, // 세로로 더 길게 조정
        crossAxisSpacing: 6, // 여백 더 줄임
        mainAxisSpacing: 6, // 여백 더 줄임
      ),
      itemCount: _galleries!.length,
      itemBuilder: (context, index) {
        final gallery = _galleries![index];
        return _GalleryItem(
          gallery: gallery,
          cleanUrl: _cleanUrl,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => GalleryDetailScreen(galleryId: gallery.id),
              ),
            ).then((_) {
              _loadGalleries();
            });
          },
        );
      },
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final Gallery gallery;
  final VoidCallback onTap;
  final String Function(String) cleanUrl;

  const _GalleryItem({
    Key? key,
    required this.gallery,
    required this.onTap,
    required this.cleanUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdDate = DateFormat(
      'yyyy.MM.dd',
    ).format(gallery.createdAt.toDate());
    final thumbnailUrl = cleanUrl(gallery.thumbnailUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // 더 작게 줄임
      elevation: 1, // 그림자 줄임
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 이미지
            Expanded(
              child:
                  thumbnailUrl.isNotEmpty
                      ? _buildThumbnailImage(thumbnailUrl)
                      : _buildEmptyThumbnail(),
            ),

            // 제목 및 정보 - 간결하게 수정
            Padding(
              padding: const EdgeInsets.all(4), // 더 작은 패딩 적용
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gallery.title,
                    style: const TextStyle(
                      fontSize: 10, // 더 작은 글자 크기
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // 4에서 2로 줄임
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gallery.authorName,
                          style: TextStyle(
                            fontSize: 8, // 더 작은 글자 크기로 변경
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        createdDate,
                        style: TextStyle(fontSize: 8, color: Colors.grey[600]), // 더 작은 글자 크기
                      ),
                    ],
                  ),
                  const SizedBox(height: 2), // 4에서 2로 줄임
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 8, // 더 작은 아이콘 크기
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2), // 4에서 2로 줄임
                      Text(
                        '${gallery.images.length}장',
                        style: TextStyle(fontSize: 8, color: Colors.grey[600]), // 더 작은 글자 크기
                      ),
                      const Spacer(),
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 8, // 더 작은 아이콘 크기
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2), // 간격 줄임
                      Text(
                        gallery.viewCount.toString(),
                        style: TextStyle(fontSize: 8, color: Colors.grey[600]), // 더 작은 글자 크기
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildThumbnailImage(String url) {
    return Hero(
      tag: 'gallery_${gallery.id}_thumbnail',
      child: Container(
        color: Colors.grey[200],
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withOpacity(0.5),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('이미지 로드 실패: $error - URL: $url');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red[300], size: 20),
                  SizedBox(height: 2),
                  Text(
                    '이미지 오류',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyThumbnail() {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.photo_library, color: Colors.grey, size: 24),
      ),
    );
  }
}
