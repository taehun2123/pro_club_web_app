import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application_1/data/models/gallery.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data'; // Uint8List 사용을 위해

class GalleryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _bucketName = 'proclub-cdd37'; // 버킷 이름 상수화

  // 컬렉션 참조
  CollectionReference get _galleriesRef => _firestore.collection('galleries');

  // 모든 갤러리 가져오기
  Future<List<Gallery>> getAllGalleries({int? limit}) async {
    try {
      Query query = _galleriesRef.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => Gallery.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('갤러리 목록 조회 오류: $e');
      throw e;
    }
  }

  // 최근 갤러리 가져오기
  Future<List<Gallery>> getRecentGalleries({int limit = 10}) async {
    try {
      final querySnapshot =
          await _galleriesRef
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map(
            (doc) => Gallery.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('최근 갤러리 조회 오류: $e');
      throw e;
    }
  }

  // 갤러리 상세 가져오기
  Future<Gallery?> getGalleryById(String galleryId) async {
    try {
      final docSnapshot = await _galleriesRef.doc(galleryId).get();

      if (docSnapshot.exists) {
        return Gallery.fromMap(
          docSnapshot.data() as Map<String, dynamic>,
          docSnapshot.id,
        );
      }

      return null;
    } catch (e) {
      print('갤러리 상세 조회 오류: $e');
      throw e;
    }
  }

  // 갤러리 조회수 증가
  Future<void> incrementViewCount(String galleryId) async {
    try {
      await _galleriesRef.doc(galleryId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('조회수 증가 오류: $e');
      // 조회수 증가는 실패해도 앱 사용에 영향을 주지 않으므로 예외를 던지지 않음
    }
  }

  // Firebase Storage URL 생성 함수
String _formatStorageUrl(String path) {
  // 버킷 이름은 'proclub-cdd37'로 보입니다 (gs:// 경로에서 추출)
  const String bucketName = 'proclub-cdd37.firebasestorage.app';
  
  // Path 인코딩 (슬래시를 유지하려면 아래와 같이 처리)
  String encodedPath = path.split('/')
      .map((segment) => Uri.encodeComponent(segment))
      .join('%2F');
  
  // 최종 URL 생성
  return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$encodedPath?alt=media';
}

  // URL에서 Storage 경로 추출
  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      
      if (path.contains('/o/')) {
        final segments = path.split('/o/');
        if (segments.length > 1) {
          return Uri.decodeComponent(segments[1]);
        }
      }
      return null;
    } catch (e) {
      print('URL 경로 추출 오류: $e');
      return null;
    }
  }

  // 이미지 업로드
  Future<List<String>> uploadImages(
    List<File> imageFiles,
    String galleryId,
    {List<Uint8List>? webImageDataList}
  ) async {
    final List<String> imageUrls = [];
    
    try {
      // 웹 환경과 모바일 환경에 따라 다르게 처리
      if (kIsWeb && webImageDataList != null) {
        // 웹 환경
        for (int i = 0; i < webImageDataList.length; i++) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_$i.jpg';
          final path = 'galleries/$galleryId/$fileName';
          final storageRef = _storage.ref().child(path);
          
          // 메타데이터 설정
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded': DateTime.now().toIso8601String(),
              'galleryId': galleryId
            }
          );
          
          // 업로드
          final uploadTask = storageRef.putData(webImageDataList[i], metadata);
          
          // 업로드 진행 상황 로깅
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print('업로드 진행률: ${progress.toStringAsFixed(1)}%');
          });
          
          await uploadTask.whenComplete(() => print('이미지 $i 업로드 완료'));
          
          // 직접 URL 생성 (토큰 제거)
          final url = _formatStorageUrl(path);
          print('생성된 이미지 URL: $url');
          imageUrls.add(url);
        }
      } else {
        // 모바일 환경
        for (int i = 0; i < imageFiles.length; i++) {
          final file = imageFiles[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_$i.jpg';
          final path = 'galleries/$galleryId/$fileName';
          final storageRef = _storage.ref().child(path);
          
          // 메타데이터 설정
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded': DateTime.now().toIso8601String(),
              'galleryId': galleryId
            }
          );
          
          final uploadTask = storageRef.putFile(file, metadata);
          
          // 업로드 진행 상황 로깅
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print('업로드 진행률: ${progress.toStringAsFixed(1)}%');
          });
          
          await uploadTask.whenComplete(() => print('이미지 $i 업로드 완료'));
          
          // 직접 URL 생성
          final url = _formatStorageUrl(path);
          print('생성된 이미지 URL: $url');
          imageUrls.add(url);
        }
      }
    } catch (e) {
      print('이미지 업로드 오류: $e');
      throw e;
    }
    
    return imageUrls;
  }

  // 갤러리 추가
  Future<String> addGallery(
    Gallery gallery,
    List<File> imageFiles, {
    List<Uint8List>? webImageDataList,
  }) async {
    try {
      // 먼저 갤러리 문서 생성
      final docRef = await _galleriesRef.add({
        'title': gallery.title,
        'description': gallery.description,
        'authorId': gallery.authorId,
        'authorName': gallery.authorName,
        'images': [],
        'createdAt': gallery.createdAt,
        'viewCount': 0,
      });

      // 이미지 업로드 (웹/모바일 분기처리)
      final imageUrls = await uploadImages(
        imageFiles,
        docRef.id,
        webImageDataList: webImageDataList,
      );

      // 이미지 URL 업데이트
      await docRef.update({'images': imageUrls});

      return docRef.id;
    } catch (e) {
      print('갤러리 추가 오류: $e');
      throw e;
    }
  }

  // 갤러리 수정
  Future<void> updateGallery(
    Gallery gallery,
    List<File>? newImageFiles,
    List<String>? imagesToDelete, {
    List<Uint8List>? webImageDataList,
  }) async {
    try {
      // 기존 이미지 중 삭제할 이미지 제외
      final updatedImages = List<String>.from(gallery.images);

      if (imagesToDelete != null && imagesToDelete.isNotEmpty) {
        for (final imageUrl in imagesToDelete) {
          updatedImages.remove(imageUrl);

          // Storage에서 이미지 삭제
          try {
            final path = _extractPathFromUrl(imageUrl);
            if (path != null) {
              final ref = _storage.ref().child(path);
              await ref.delete();
              print('이미지 삭제 성공: $path');
            } else {
              print('이미지 경로 추출 실패: $imageUrl');
            }
          } catch (e) {
            print('이미지 삭제 실패: $e');
            // 개별 이미지 삭제 실패는 무시하고 계속 진행
          }
        }
      }

      // 새 이미지 업로드
      if ((newImageFiles != null && newImageFiles.isNotEmpty) || 
          (webImageDataList != null && webImageDataList.isNotEmpty)) {
        final newImageUrls = await uploadImages(
          newImageFiles ?? [],
          gallery.id,
          webImageDataList: webImageDataList,
        );
        updatedImages.addAll(newImageUrls);
      }

      // 갤러리 정보 업데이트
      await _galleriesRef.doc(gallery.id).update({
        'title': gallery.title,
        'description': gallery.description,
        'images': updatedImages,
      });
    } catch (e) {
      print('갤러리 수정 오류: $e');
      throw e;
    }
  }

  // 갤러리 삭제
  Future<void> deleteGallery(String galleryId) async {
    try {
      // 갤러리 정보 가져오기
      final gallery = await getGalleryById(galleryId);
      
      if (gallery != null) {
        // 갤러리에 포함된 모든 이미지 삭제
        for (final imageUrl in gallery.images) {
          try {
            final path = _extractPathFromUrl(imageUrl);
            if (path != null) {
              final ref = _storage.ref().child(path);
              await ref.delete();
              print('이미지 삭제 성공: $path');
            } else {
              print('삭제할 수 없는 URL 형식: $imageUrl');
            }
          } catch (e) {
            print('이미지 삭제 실패: $e, URL: $imageUrl');
            // 개별 이미지 삭제 실패 시 계속 진행
          }
        }
      }
      
      // 갤러리 문서 삭제
      await _galleriesRef.doc(galleryId).delete();
      print('갤러리 문서 삭제 성공: $galleryId');
    } catch (e) {
      print('갤러리 삭제 중 오류 발생: $e');
      throw e;
    }
  }

  // 갤러리 검색
  Future<List<Gallery>> searchGalleries(String query) async {
    try {
      if (query.trim().isEmpty) {
        return await getRecentGalleries();
      }

      // 제목에서 검색
      final titleQuerySnapshot =
          await _galleriesRef
              .where('title', isGreaterThanOrEqualTo: query)
              .where('title', isLessThanOrEqualTo: query + '\uf8ff')
              .get();

      // 설명에서 검색
      final descQuerySnapshot =
          await _galleriesRef
              .where('description', isGreaterThanOrEqualTo: query)
              .where('description', isLessThanOrEqualTo: query + '\uf8ff')
              .get();

      // 중복 제거를 위한 맵
      final Map<String, Gallery> galleriesMap = {};

      // 제목 검색 결과 추가
      for (final doc in titleQuerySnapshot.docs) {
        final gallery = Gallery.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        galleriesMap[doc.id] = gallery;
      }

      // 설명 검색 결과 추가
      for (final doc in descQuerySnapshot.docs) {
        final gallery = Gallery.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        galleriesMap[doc.id] = gallery;
      }

      // 결과를 리스트로 변환하고 날짜 기준 내림차순 정렬
      final galleries = galleriesMap.values.toList();
      galleries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return galleries;
    } catch (e) {
      print('갤러리 검색 오류: $e');
      throw e;
    }
  }
}