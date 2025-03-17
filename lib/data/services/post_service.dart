import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/models/comment.dart';
import 'dart:io';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 컬렉션 참조
  CollectionReference get _postsRef => _firestore.collection('posts');
  CollectionReference _commentsRef(String postId) => 
      _firestore.collection('posts').doc(postId).collection('comments');
  
  // 모든 게시글 가져오기
  Future<List<Post>> getAllPosts({int? limit}) async {
    Query query = _postsRef.orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 특정 사용자의 게시글 가져오기
  Future<List<Post>> getUserPosts(String userId, {int? limit}) async {
    Query query = _postsRef
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 게시글 상세 가져오기
  Future<Post?> getPostById(String postId) async {
    final docSnapshot = await _postsRef.doc(postId).get();
    
    if (docSnapshot.exists) {
      return Post.fromMap(
        docSnapshot.data() as Map<String, dynamic>,
        docSnapshot.id,
      );
    }
    
    return null;
  }
  
  // 게시글 조회수 증가
  Future<void> incrementViewCount(String postId) async {
    await _postsRef.doc(postId).update({
      'viewCount': FieldValue.increment(1),
    });
  }
  
  Future<List<String>> uploadAttachments(
    List<File> files,
    String postId,
    {List<Uint8List>? webAttachments}
  ) async {
    final List<String> fileUrls = [];
    
    try {
      if (kIsWeb && webAttachments != null) {
        // 웹 환경
        for (int i = 0; i < webAttachments.length; i++) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final storageRef = _storage.ref().child('posts/$postId/$fileName');
          
          final uploadTask = storageRef.putData(
            webAttachments[i],
            SettableMetadata(contentType: 'image/jpeg'),
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
          final storageRef = _storage.ref().child('posts/$postId/$fileName');
          
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
  
  // 게시글 추가 메서드 수정
  Future<String> addPost(
    Post post,
    List<File>? attachments,
    {List<Uint8List>? webAttachments}
  ) async {
    // 게시글 문서 생성
    final docRef = await _postsRef.add({
      'title': post.title,
      'content': post.content,
      'authorId': post.authorId,
      'authorName': post.authorName,
      'authorProfileImage': post.authorProfileImage,
      'createdAt': post.createdAt,
      'viewCount': 0,
      'commentCount': 0,
      'attachments': [],
      'tag': post.tag,
      'customTag': post.customTag,
      'likedBy': [],
      'dislikedBy': [],
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
  
  // 게시글 수정
  Future<void> updatePost(
    Post post, 
    List<File>? newAttachments,
    List<String>? attachmentsToDelete,
  ) async {
    // 기존 첨부 파일 중 삭제할 파일 제외
    final updatedAttachments = List<String>.from(post.attachments ?? []);
    
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
    if (newAttachments != null && newAttachments.isNotEmpty) {
      final newFileUrls = await uploadAttachments(newAttachments, post.id);
      updatedAttachments.addAll(newFileUrls);
    }
    
    // 게시글 정보 업데이트
    await _postsRef.doc(post.id).update({
      'title': post.title,
      'content': post.content,
      'updatedAt': Timestamp.now(),
      'attachments': updatedAttachments,
      'tag': post.tag,
      'customTag': post.customTag,
    });
  }
  
  // 게시글 삭제
  Future<void> deletePost(String postId) async {
    // 게시글 정보 가져오기
    final post = await getPostById(postId);
    
    if (post != null && post.attachments != null) {
      // 게시글에 포함된 모든 첨부 파일 삭제
      for (final fileUrl in post.attachments!) {
        try {
          final ref = _storage.refFromURL(fileUrl);
          await ref.delete();
        } catch (e) {
          print('파일 삭제 실패: $e');
        }
      }
    }
    
    // 게시글의 모든 댓글 가져오기
    final commentsSnapshot = await _commentsRef(postId).get();
    
    // 트랜잭션으로 게시글과 댓글 모두 삭제
    final batch = _firestore.batch();
    
    // 모든 댓글 삭제
    for (final doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // 게시글 삭제
    batch.delete(_postsRef.doc(postId));
    
    // 트랜잭션 실행
    await batch.commit();
  }
  
  // 댓글 추가
  Future<String> addComment(Comment comment) async {
    // 댓글 추가
    final docRef = await _commentsRef(comment.postId).add(comment.toMap());
    
    // 게시글의 댓글 수 증가
    await _postsRef.doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }
  
  // 댓글 수정
  Future<void> updateComment(Comment comment) async {
    await _commentsRef(comment.postId).doc(comment.id).update({
      'content': comment.content,
      'updatedAt': Timestamp.now(),
    });
  }
  
  // 댓글 삭제
  Future<void> deleteComment(String postId, String commentId) async {
    await _commentsRef(postId).doc(commentId).delete();
    
    // 게시글의 댓글 수 감소
    await _postsRef.doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }
  
  // 게시글의 모든 댓글 가져오기
  Future<List<Comment>> getCommentsByPostId(String postId) async {
    final querySnapshot = await _commentsRef(postId)
        .orderBy('createdAt')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 게시글 검색
  Future<List<Post>> searchPosts(String query) async {
    // 제목에서 검색
    final titleQuerySnapshot = await _postsRef
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    
    // 내용에서 검색
    final contentQuerySnapshot = await _postsRef
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    
    // 중복 제거를 위한 맵
    final Map<String, Post> postsMap = {};
    
    // 제목 검색 결과 추가
    for (final doc in titleQuerySnapshot.docs) {
      final post = Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      postsMap[doc.id] = post;
    }
    
    // 내용 검색 결과 추가
    for (final doc in contentQuerySnapshot.docs) {
      final post = Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      postsMap[doc.id] = post;
    }
    
    // 결과를 리스트로 변환하고 날짜 기준 내림차순 정렬
    final posts = postsMap.values.toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return posts;
  }
  
  // 태그별 게시글 가져오기
  Future<List<Post>> getPostsByTag(String tag) async {
    Query query;
    
    if (tag == '전체') {
      // 모든 게시글
      query = _postsRef.orderBy('createdAt', descending: true);
    } else {
      // 특정 태그 게시글
      query = _postsRef
          .where('tag', isEqualTo: tag)
          .orderBy('createdAt', descending: true);
    }
    
    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 게시글 좋아요 토글
  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _postsRef.doc(postId);
    
    return _firestore.runTransaction((transaction) async {
      // 현재 게시글 정보 가져오기
      final docSnapshot = await transaction.get(postRef);
      final post = Post.fromMap(docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
      
      // 좋아요 및 싫어요 목록 복사
      List<String> updatedLikedBy = List<String>.from(post.likedBy);
      List<String> updatedDislikedBy = List<String>.from(post.dislikedBy);
      
      // 이미 좋아요를 눌렀다면 취소, 아니면 추가
      if (updatedLikedBy.contains(userId)) {
        updatedLikedBy.remove(userId);
      } else {
        updatedLikedBy.add(userId);
        
        // 싫어요를 이미 눌렀다면 싫어요 취소 (한 게시글에 좋아요와 싫어요 동시에 불가)
        if (updatedDislikedBy.contains(userId)) {
          updatedDislikedBy.remove(userId);
        }
      }
      
      // Firestore 업데이트
      transaction.update(postRef, {
        'likedBy': updatedLikedBy,
        'dislikedBy': updatedDislikedBy,
      });
    });
  }
  
  // 게시글 싫어요 토글
  Future<void> toggleDislike(String postId, String userId) async {
    final postRef = _postsRef.doc(postId);
    
    return _firestore.runTransaction((transaction) async {
      // 현재 게시글 정보 가져오기
      final docSnapshot = await transaction.get(postRef);
      final post = Post.fromMap(docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
      
      // 좋아요 및 싫어요 목록 복사
      List<String> updatedLikedBy = List<String>.from(post.likedBy);
      List<String> updatedDislikedBy = List<String>.from(post.dislikedBy);
      
      // 이미 싫어요를 눌렀다면 취소, 아니면 추가
      if (updatedDislikedBy.contains(userId)) {
        updatedDislikedBy.remove(userId);
      } else {
        updatedDislikedBy.add(userId);
        
        // 좋아요를 이미 눌렀다면 좋아요 취소 (한 게시글에 좋아요와 싫어요 동시에 불가)
        if (updatedLikedBy.contains(userId)) {
          updatedLikedBy.remove(userId);
        }
      }
      
      // Firestore 업데이트
      transaction.update(postRef, {
        'likedBy': updatedDislikedBy,
        'dislikedBy': updatedLikedBy,
      });
    });
  }
  
  // 핫 게시글 가져오기 (좋아요 많은 순)
  Future<List<Post>> getHotPosts({int limit = 10}) async {
    final querySnapshot = await _postsRef.get();
    
    // 모든 게시글 가져오기
    final posts = querySnapshot.docs
        .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    
    // 좋아요 수 기준으로 정렬
    posts.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    
    // 상위 N개 반환
    return posts.take(limit).toList();
  }
}