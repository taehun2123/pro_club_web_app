// lib/data/services/notice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_1/data/models/notice.dart';
import 'dart:io';
import 'dart:typed_data'; // Uint8List 사용을 위해

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 컬렉션 참조
  CollectionReference get _noticesRef => _firestore.collection('notices');
  
  // 모든 공지사항 가져오기
  Future<List<Notice>> getAllNotices({int? limit}) async {
    Query query = _noticesRef.orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => Notice.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 중요 공지사항만 가져오기
  Future<List<Notice>> getImportantNotices({int? limit}) async {
    Query query = _noticesRef
        .where('important', isEqualTo: true)
        .orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => Notice.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 공지사항 상세 가져오기
  Future<Notice?> getNoticeById(String noticeId) async {
    final docSnapshot = await _noticesRef.doc(noticeId).get();
    
    if (docSnapshot.exists) {
      return Notice.fromMap(
        docSnapshot.data() as Map<String, dynamic>,
        docSnapshot.id,
      );
    }
    
    return null;
  }
  
  // 파일 업로드 메서드 추가
  Future<List<String>> uploadAttachments(
    List<File> files,
    String noticeId,
    {List<Uint8List>? webAttachments}
  ) async {
    final List<String> fileUrls = [];
    
    try {
      if (kIsWeb && webAttachments != null) {
        // 웹 환경
        for (int i = 0; i < webAttachments.length; i++) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.apk'; // 파일 확장자 자동 지정 필요
          final storageRef = _storage.ref().child('notices/$noticeId/$fileName');
          
          final uploadTask = storageRef.putData(
            webAttachments[i],
            SettableMetadata(contentType: 'application/octet-stream'), // 바이너리 데이터 타입
          );
          
          final snapshot = await uploadTask.whenComplete(() {});
          final downloadUrl = await snapshot.ref.getDownloadURL();
          fileUrls.add(downloadUrl);
        }
      } else {
        // 모바일 환경
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.${file.path.split('.').last}';
          final storageRef = _storage.ref().child('notices/$noticeId/$fileName');
          
          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask.whenComplete(() {});
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          fileUrls.add(downloadUrl);
        }
      }
    } catch (e) {
      print('첨부 파일 업로드 오류: $e');
    }
    
    return fileUrls;
  }
  
  // 공지사항 추가 (수정: 첨부 파일 처리 추가)
  Future<String> addNotice(
    Notice notice,
    List<File>? attachments,
    {List<Uint8List>? webAttachments}
  ) async {
    // 공지사항 문서 생성
    final docRef = await _noticesRef.add({
      'title': notice.title,
      'content': notice.content,
      'authorId': notice.authorId,
      'authorName': notice.authorName,
      'createdAt': notice.createdAt,
      'important': notice.important,
      'attachments': [],
    });
    
    // 첨부 파일 업로드
    if ((attachments != null && attachments.isNotEmpty) ||
        (webAttachments != null && webAttachments.isNotEmpty)) {
      final attachmentUrls = await uploadAttachments(
        attachments ?? [],
        docRef.id,
        webAttachments: webAttachments,
      );
      
      // 첨부 파일 URL 업데이트
      await docRef.update({
        'attachments': attachmentUrls,
      });
    }
    
    return docRef.id;
  }
  
  // 공지사항 수정 (수정: 첨부 파일 처리 추가)
  Future<void> updateNotice(
    Notice notice,
    List<File>? newAttachments,
    List<String>? attachmentsToDelete,
    {List<Uint8List>? webAttachments}
  ) async {
    // 기존 첨부 파일 중 삭제할 파일 제외
    final updatedAttachments = List<String>.from(notice.attachments ?? []);
    
    if (attachmentsToDelete != null && attachmentsToDelete.isNotEmpty) {
      for (final fileUrl in attachmentsToDelete) {
        updatedAttachments.remove(fileUrl);
        
        // Storage에서 파일 삭제
        try {
          final ref = _storage.refFromURL(fileUrl);
          await ref.delete();
        } catch (e) {
          print('파일 삭제 실패: $e');
        }
      }
    }
    
    // 새 첨부 파일 업로드
    if ((newAttachments != null && newAttachments.isNotEmpty) || 
        (webAttachments != null && webAttachments.isNotEmpty)) {
      final newFileUrls = await uploadAttachments(
        newAttachments ?? [],
        notice.id,
        webAttachments: webAttachments,
      );
      updatedAttachments.addAll(newFileUrls);
    }
    
    // 공지사항 정보 업데이트
    await _noticesRef.doc(notice.id).update({
      'title': notice.title,
      'content': notice.content,
      'updatedAt': Timestamp.now(),
      'important': notice.important,
      'attachments': updatedAttachments,
    });
  }
  
  // 공지사항 삭제 (수정: 첨부 파일 삭제 추가)
  Future<void> deleteNotice(String noticeId) async {
    try {
      // 공지사항 정보 가져오기
      final notice = await getNoticeById(noticeId);
      
      if (notice != null && notice.attachments != null) {
        // 공지사항에 포함된 모든 첨부 파일 삭제
        for (final fileUrl in notice.attachments!) {
          try {
            final ref = _storage.refFromURL(fileUrl);
            await ref.delete();
          } catch (e) {
            print('파일 삭제 실패: $e');
          }
        }
      }
      
      // 공지사항 문서 삭제
      await _noticesRef.doc(noticeId).delete();
    } catch (e) {
      print('공지사항 삭제 중 오류: $e');
      throw e;
    }
  }
  
  // 공지사항 검색
  Future<List<Notice>> searchNotices(String query) async {
    // 제목에서 검색
    final titleQuerySnapshot = await _noticesRef
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    
    // 내용에서 검색
    final contentQuerySnapshot = await _noticesRef
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    
    // 중복 제거를 위한 맵
    final Map<String, Notice> noticesMap = {};
    
    // 제목 검색 결과 추가
    for (final doc in titleQuerySnapshot.docs) {
      final notice = Notice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      noticesMap[doc.id] = notice;
    }
    
    // 내용 검색 결과 추가
    for (final doc in contentQuerySnapshot.docs) {
      final notice = Notice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      noticesMap[doc.id] = notice;
    }
    
    // 결과를 리스트로 변환하고 날짜 기준 내림차순 정렬
    final notices = noticesMap.values.toList();
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return notices;
  }
}