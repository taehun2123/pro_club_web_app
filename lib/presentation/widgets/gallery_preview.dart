import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/gallery.dart';
import 'package:flutter_application_1/presentation/screens/gallery/gallery_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GalleryPreview extends StatelessWidget {
  final List<Gallery> galleries;

  const GalleryPreview({
    Key? key,
    required this.galleries,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: galleries.length > 4 ? 4 : galleries.length,
      itemBuilder: (context, index) {
        final gallery = galleries[index];
        return GalleryPreviewItem(gallery: gallery);
      },
    );
  }
}

class GalleryPreviewItem extends StatelessWidget {
  final Gallery gallery;

  const GalleryPreviewItem({
    Key? key,
    required this.gallery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryDetailScreen(galleryId: gallery.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 이미지
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: gallery.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: gallery.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.grey,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.photo_library,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
              ),
            ),
            
            // 갤러리 정보
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gallery.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gallery.dateString,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}