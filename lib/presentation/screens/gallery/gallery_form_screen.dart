// lib/presentation/screens/gallery/gallery_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/gallery.dart';
import 'package:flutter_application_1/data/services/gallery_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/widgets/custom_button.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data'; // Uint8List 사용을 위해

class GalleryFormScreen extends StatefulWidget {
  final Gallery? gallery;

  const GalleryFormScreen({Key? key, this.gallery}) : super(key: key);

  @override
  _GalleryFormScreenState createState() => _GalleryFormScreenState();
}

class _GalleryFormScreenState extends State<GalleryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GalleryService _galleryService = GalleryService();
  final ImagePicker _imagePicker = ImagePicker();
  List<Uint8List> webImageData = []; // 웹에서 사용할 이미지 데이터
  List<String> _existingImages = [];
  List<String> _imagesToDelete = [];
  List<File> _newImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.gallery != null) {
      _titleController.text = widget.gallery!.title;
      _descriptionController.text = widget.gallery!.description;
      _existingImages = List<String>.from(widget.gallery!.images);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 이미지 선택 메서드 수정
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        if (kIsWeb) {
          // 웹 환경 - 비동기 처리를 setState() 바깥으로 이동
          List<Uint8List> newWebImageData = [];
          List<File> newImagesList = [];

          for (final pickedFile in pickedFiles) {
            final bytes = await pickedFile.readAsBytes();
            newWebImageData.add(bytes);
            newImagesList.add(
              File('dummy-${DateTime.now().millisecondsSinceEpoch}'),
            );
          }

          setState(() {
            webImageData.addAll(newWebImageData);
            _newImages.addAll(newImagesList);
          });
        } else {
          // 모바일 환경
          setState(() {
            for (final pickedFile in pickedFiles) {
              _newImages.add(File(pickedFile.path));
            }
          });
        }
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')));
    }
  }

  void _removeExistingImage(String imageUrl) {
    setState(() {
      _existingImages.remove(imageUrl);
      _imagesToDelete.add(imageUrl);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      if (kIsWeb && index < webImageData.length) {
        webImageData.removeAt(index);
      }
      _newImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 이미지가 없는 경우 경고
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('최소 1개 이상의 이미지를 추가해야 합니다.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      if (widget.gallery == null) {
        // 새 갤러리 작성
        final newGallery = Gallery(
          id: '',
          title: title,
          description: description,
          authorId: user.id,
          authorName: user.name,
          images: [],
          createdAt: Timestamp.now(),
          viewCount: 0,
        );

        await _galleryService.addGallery(
          newGallery,
          _newImages,
          webImageDataList: kIsWeb ? webImageData : null,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('갤러리가 추가되었습니다.')));
        }
      } else {
        // 갤러리 수정
        final updatedGallery = widget.gallery!.copyWith(
          title: title,
          description: description,
        );

        await _galleryService.updateGallery(
          updatedGallery,
          _newImages,
          _imagesToDelete,
          webImageDataList: kIsWeb ? webImageData : null,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('갤러리가 수정되었습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '갤러리 ${widget.gallery == null ? '추가' : '수정'} 중 오류가 발생했습니다: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 새 이미지 표시 위젯
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.gallery == null ? '갤러리 추가' : '갤러리 수정')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 입력
                    CustomTextField(
                      controller: _titleController,
                      label: '제목',
                      hintText: '갤러리 제목을 입력하세요',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '제목을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 설명 입력
                    CustomTextField(
                      controller: _descriptionController,
                      label: '설명',
                      hintText: '갤러리에 대한 설명을 입력하세요',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // 이미지 추가 버튼
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('이미지 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 기존 이미지 목록
                    if (_existingImages.isNotEmpty) ...[
                      const Text(
                        '기존 이미지',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _existingImages.length,
                        itemBuilder: (context, index) {
                          final imageUrl = _existingImages[index];
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => 
                                      Container(
                                        color: Colors.grey[300],
                                        child: Icon(Icons.error, color: Colors.red),
                                      ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(imageUrl),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 새 이미지 목록
                    if (_newImages.isNotEmpty) ...[
                      const Text(
                        '새 이미지',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _newImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                    ? (index < webImageData.length
                                      ? Image.memory(
                                          webImageData[index],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : Container(color: Colors.grey[200]))
                                    : Image.file(
                                        _newImages[index],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeNewImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 저장 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: widget.gallery == null ? '갤러리 추가' : '갤러리 수정',
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}