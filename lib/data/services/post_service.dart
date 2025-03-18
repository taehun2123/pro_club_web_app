import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/post.dart';
import 'package:flutter_application_1/data/models/comment.dart';
import 'package:flutter_application_1/data/services/notification_service.dart';
import 'dart:io';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();
  
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
  
  // 게시글 추가 메서드 수정 - 멘션 기능 추가
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
    
    // 게시글 내용에서 @멘션 처리
    await _notificationService.processMentions(
      content: post.content,
      authorId: post.authorId,
      authorName: post.authorName,
      authorProfileImage: post.authorProfileImage,
      sourceId: docRef.id,
      sourceType: 'post',
    );
    
    return docRef.id;
  }
  
  // 게시글 수정 - 멘션 기능 추가
  Future<void> updatePost(
    Post post, 
    List<File>? newAttachments,
    List<String>? attachmentsToDelete,
    {List<Uint8List>? webAttachments}
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
    if ((newAttachments != null && newAttachments.isNotEmpty) || 
        (webAttachments != null && webAttachments.isNotEmpty)) {
      final newFileUrls = await uploadAttachments(
        newAttachments ?? [],
        post.id,
        webAttachments: webAttachments,
      );
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
    
    // 게시글 내용에서 @멘션 처리 (수정 시에도 추가된 멘션 처리)
    await _notificationService.processMentions(
      content: post.content,
      authorId: post.authorId,
      authorName: post.authorName,
      authorProfileImage: post.authorProfileImage,
      sourceId: post.id,
      sourceType: 'post',
    );
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
  
  // 댓글 추가 (멘션 및 알림 기능 추가)
  Future<String> addComment(Comment comment) async {
    // 댓글 추가
    final docRef = await _commentsRef(comment.postId).add(comment.toMap());
    
    // 게시글의 댓글 수 증가
    await _postsRef.doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
    
    // 게시글 정보 가져오기
    final post = await getPostById(comment.postId);
    
    if (post != null) {
      // 댓글 내용에서 @멘션 처리
      await _notificationService.processMentions(
        content: comment.content,
        authorId: comment.authorId,
        authorName: comment.authorName,
        authorProfileImage: comment.authorProfileImage,
        sourceId: comment.postId,
        sourceType: 'comment',
      );
      
      // 댓글 알림 생성
      if (comment.parentId == null) {
        // 일반 댓글인 경우 - 게시글 작성자에게 알림
        await _notificationService.createNewCommentNotification(
          postId: comment.postId,
          postAuthorId: post.authorId,
          postTitle: post.title,
          commentId: docRef.id,
          commentContent: comment.content,
          commentAuthorId: comment.authorId,
          commentAuthorName: comment.authorName,
          commentAuthorProfileImage: comment.authorProfileImage,
        );
      } else {
        // 대댓글인 경우 - 부모 댓글 작성자에게 알림
        final parentCommentDoc = await _commentsRef(comment.postId).doc(comment.parentId).get();
        
        if (parentCommentDoc.exists) {
          final parentComment = Comment.fromMap(
            parentCommentDoc.data() as Map<String, dynamic>,
            parentCommentDoc.id,
          );
          
          await _notificationService.createNewReplyNotification(
            postId: comment.postId,
            postTitle: post.title,
            parentCommentId: comment.parentId!,
            parentCommentAuthorId: parentComment.authorId,
            replyId: docRef.id,
            replyContent: comment.content,
            replyAuthorId: comment.authorId,
            replyAuthorName: comment.authorName,
            replyAuthorProfileImage: comment.authorProfileImage,
          );
        }
      }
    }
    
    return docRef.id;
  }
  
  // 댓글 수정
  Future<void> updateComment(Comment comment) async {
    await _commentsRef(comment.postId).doc(comment.id).update({
      'content': comment.content,
      'updatedAt': Timestamp.now(),
      'mentionedUserId': comment.mentionedUserId,
      'mentionedUserName': comment.mentionedUserName,
    });
    
    // 댓글 내용에서 @멘션 처리
    await _notificationService.processMentions(
      content: comment.content,
      authorId: comment.authorId,
      authorName: comment.authorName,
      authorProfileImage: comment.authorProfileImage,
      sourceId: comment.postId,
      sourceType: 'comment',
    );
  }
  
  // 댓글 삭제
  Future<void> deleteComment(String postId, String commentId) async {
    // 대댓글 여부 확인을 위해 댓글 정보 가져오기
    final commentDoc = await _commentsRef(postId).doc(commentId).get();
    
    if (commentDoc.exists) {
      final comment = Comment.fromMap(
        commentDoc.data() as Map<String, dynamic>,
        commentId,
      );
      
      // 삭제하려는 댓글이 부모 댓글인지 확인하고, 관련 대댓글도 함께 삭제
      if (comment.parentId == null) {
        // 부모 댓글인 경우, 이 댓글에 달린 모든 대댓글 조회
        final repliesSnapshot = await _commentsRef(postId)
            .where('parentId', isEqualTo: commentId)
            .get();
        
        final batch = _firestore.batch();
        
        // 모든 대댓글 삭제
        for (final replyDoc in repliesSnapshot.docs) {
          batch.delete(replyDoc.reference);
        }
        
        // 부모 댓글 삭제
        batch.delete(_commentsRef(postId).doc(commentId));
        
        // 게시글의 댓글 수 업데이트
        final decrementAmount = repliesSnapshot.docs.length + 1; // 대댓글 수 + 부모 댓글 1개
        batch.update(_postsRef.doc(postId), {
          'commentCount': FieldValue.increment(-decrementAmount),
        });
        
        // 트랜잭션 실행
        await batch.commit();
      } else {
        // 대댓글인 경우
        await _commentsRef(postId).doc(commentId).delete();
        
        // 게시글의 댓글 수 감소
        await _postsRef.doc(postId).update({
          'commentCount': FieldValue.increment(-1),
        });
      }
    } else {
      // 댓글이 존재하지 않는 경우 예외 처리
      throw Exception('댓글을 찾을 수 없습니다.');
    }
  }
  
  // 게시글의 모든 댓글 가져오기 (대댓글 포함)
  Future<List<Comment>> getCommentsByPostId(String postId) async {
    final querySnapshot = await _commentsRef(postId)
        .orderBy('createdAt')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 댓글 그룹화 (대댓글은 부모 댓글 아래에 정렬되도록)
  Future<Map<String, List<Comment>>> getGroupedCommentsByPostId(String postId) async {
    final allComments = await getCommentsByPostId(postId);
    
    // 결과 맵: 부모 댓글 ID -> [부모 댓글, 대댓글1, 대댓글2, ...]
    final Map<String, List<Comment>> groupedComments = {};
    
    // 부모 댓글 먼저 처리
    for (final comment in allComments.where((c) => c.parentId == null)) {
      groupedComments[comment.id] = [comment];
    }
    
    // 대댓글 처리
    for (final reply in allComments.where((c) => c.parentId != null)) {
      final parentId = reply.parentId!;
      if (groupedComments.containsKey(parentId)) {
        groupedComments[parentId]!.add(reply);
      } else {
        // 부모 댓글이 삭제된 경우, 루트 레벨에 표시
        groupedComments[reply.id] = [reply];
      }
    }
    
    return groupedComments;
  }
  
  // 특정 댓글에 대한 대댓글만 가져오기
  Future<List<Comment>> getRepliesByParentId(String postId, String parentId) async {
    final querySnapshot = await _commentsRef(postId)
        .where('parentId', isEqualTo: parentId)
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
        
        // 좋아요 수가 임계값을 넘으면 인기 게시글 알림 생성
        if (updatedLikedBy.length >= 5) { // 임계값은 필요에 따라 조정
          // 트랜잭션 종료 후 알림 발생
          Future.delayed(Duration.zero, () {
            _notificationService.createHotPostNotification(
              postId: post.id,
              postTitle: post.title,
              postAuthorId: post.authorId,
              postAuthorName: post.authorName,
            );
          });
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
        'likedBy': updatedLikedBy,
        'dislikedBy': updatedDislikedBy,
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