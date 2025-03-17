// lib/data/services/auth_service.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/data/models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 인증된 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 사용자 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google로 로그인
Future<UserCredential> signInWithGoogle() async {
  try {
    // Google 로그인 흐름 시작
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Google 로그인이 취소되었습니다.',
      );
    }

    // Google 인증 정보 가져오기
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Google 인증 정보로 Firebase에 로그인
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  } catch (e) {
    rethrow;
  }
}

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Firestore에 사용자 정보 생성
  Future<void> _createUserInFirestore(
    String uid, 
    String email, 
    String name, 
    String? profileImage,
  ) async {
    final appUser = AppUser(
      id: uid,
      email: email,
      name: name,
      profileImage: profileImage,
      role: 'member', // 기본 역할은 일반 회원
      createdAt: Timestamp.now(),
    );

    await _firestore.collection('users').doc(uid).set(appUser.toMap());
  }

// 초기 사용자 레코드 생성
Future<void> createInitialUserRecord(User firebaseUser) async {
  // 이미 존재하는지 확인
  final docSnapshot = await _firestore.collection('users').doc(firebaseUser.uid).get();
  
  if (!docSnapshot.exists) {
    // 기본 정보로 신규 사용자 생성
    final appUser = AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      profileImage: firebaseUser.photoURL,
      role: 'member',
      createdAt: Timestamp.now(),
      profileCompleted: false,
    );
    
    await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toMap());
  }
}

Future<void> updateUserAdditionalInfo({
  required String name,
  required String studentId,
  required String phone,
  required String nickname,
  required int age,
}) async {
  if (currentUser == null) {
    throw Exception('로그인된 사용자가 없습니다.');
  }
  
  final updateData = {
    'name': name,
    'studentId': studentId,
    'phone': phone,
    'nickname': nickname,
    'age': age,
    'profileCompleted': true, // 프로필 완료 플래그
  };
  
  await _firestore.collection('users').doc(currentUser!.uid).update(updateData);
}

  // 관리자로 승격 (관리자만 호출 가능)
// auth_service.dart 파일의 promoteToAdmin 메서드 수정
Future<void> promoteToAdmin(String userId) async {
  // 현재 사용자가 관리자인지 확인
  final currentUserData = await getCurrentUserData();
  if (currentUserData == null || !currentUserData.isAdmin) {
    throw Exception('관리자 권한이 없습니다.');
  }
  
  await _firestore.collection('users').doc(userId).update({
    'role': 'admin',
  });
  
  // 현재 사용자인 경우 UserProvider 새로고침
  if (userId == currentUser?.uid) {
    // 여기서는 직접 UserProvider에 접근할 수 없으므로, 이 메서드를 호출한 곳에서 
    // userProvider.refreshUser(authService)를 호출해야 합니다.
    return;
  }
}
// 일반 회원으로 강등 (관리자만 호출 가능)
Future<void> demoteToMember(String userId) async {
  // 현재 사용자가 관리자인지 확인
  final currentUserData = await getCurrentUserData();
  if (currentUserData == null || !currentUserData.isAdmin) {
    throw Exception('관리자 권한이 없습니다.');
  }
  
  await _firestore.collection('users').doc(userId).update({
    'role': 'member',
  });
}

// 모든 사용자 가져오기 (관리자용)
Future<List<AppUser>> getAllUsers() async {
  // 현재 사용자가 관리자인지 확인
  final currentUserData = await getCurrentUserData();
  if (currentUserData == null || !currentUserData.isAdmin) {
    throw Exception('관리자 권한이 없습니다.');
  }
  
  final querySnapshot = await _firestore.collection('users').get();
  return querySnapshot.docs
      .map((doc) => AppUser.fromMap(doc.data()))
      .toList();
}

  // Firestore에서 현재 사용자 정보 가져오기
  Future<AppUser?> getCurrentUserData() async {
    if (currentUser == null) return null;

    final docSnapshot = await _firestore.collection('users').doc(currentUser!.uid).get();
    
    if (docSnapshot.exists) {
      return AppUser.fromMap(docSnapshot.data()!);
    }
    
    return null;
  }

  // 사용자 역할 확인
  Future<String> getUserRole() async {
    if (currentUser == null) {
      return 'guest';
    }

    final userData = await getCurrentUserData();
    return userData?.role ?? 'member';
  }

  // 사용자가 관리자인지 확인
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

// 기존 updateUserProfile 메서드 수정
Future<void> updateUserProfile({
  String? name,
  String? profileImage,
  File? imageFile,
  Uint8List? webImageData,
}) async {
  if (currentUser == null) {
    throw Exception('로그인된 사용자가 없습니다.');
  }

  String? imageUrl;
  
  // 이미지 업로드 처리
  if (imageFile != null || webImageData != null) {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
    UploadTask uploadTask;
    if (kIsWeb && webImageData != null) {
      // 웹 환경
      uploadTask = storageRef.putData(
        webImageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else if (imageFile != null) {
      // 모바일 환경
      uploadTask = storageRef.putFile(imageFile);
    } else {
      throw Exception('업로드할 이미지가 없습니다.');
    }
    
    final snapshot = await uploadTask.whenComplete(() {});
    imageUrl = await snapshot.ref.getDownloadURL();
  }

  // Firestore 업데이트
  final updateData = <String, dynamic>{};
  
  if (name != null) {
    updateData['name'] = name;
  }
  
  if (imageUrl != null) {
    updateData['profileImage'] = imageUrl;
  } else if (profileImage != null) {
    updateData['profileImage'] = profileImage;
  }

  if (updateData.isNotEmpty) {
    await _firestore.collection('users').doc(currentUser!.uid).update(updateData);
  }
}
}