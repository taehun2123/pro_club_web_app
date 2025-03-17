// lib/data/services/notice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/models/notice.dart';

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
  
  // 공지사항 추가
  Future<String> addNotice(Notice notice) async {
    final docRef = await _noticesRef.add(notice.toMap());
    return docRef.id;
  }
  
  // 공지사항 수정
  Future<void> updateNotice(Notice notice) async {
    await _noticesRef.doc(notice.id).update(notice.toMap());
  }
  
  // 공지사항 삭제
  Future<void> deleteNotice(String noticeId) async {
    await _noticesRef.doc(noticeId).delete();
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