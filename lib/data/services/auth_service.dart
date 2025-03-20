// lib/data/services/auth_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/data/models/app_user.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GoogleSignIn _googleSignIn;
  
  // 생성자에서 GoogleSignIn 초기화
  AuthService() {
    if (kIsWeb) {
      final clientId = dotenv.env['CLIENT_ID'];
      if (clientId == null || clientId.isEmpty) {
        print('경고: CLIENT_ID가 설정되지 않았습니다.');
        // 웹에서는 실제로 GoogleSignIn을 사용하지 않으므로, 초기화만 해둠
        _googleSignIn = GoogleSignIn();
      } else {
        print('Google Sign-In 초기화: 웹 환경, 클라이언트 ID: ${clientId.substring(0, min(10, clientId.length))}...');
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: ['email', 'profile'],
        );
      }
    } else {
      // 모바일 환경에서는 클라이언트 ID 불필요
      _googleSignIn = GoogleSignIn();
    }
  }

  // min 함수 구현 (String 길이 체크용)
  int min(int a, int b) => a < b ? a : b;

  // 현재 인증된 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 사용자 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google로 로그인
  Future<UserCredential> signInWithGoogle() async {
    try {
      // 웹 환경인 경우 - Firebase Auth의 팝업 방식 사용
      if (kIsWeb) {
        try {
          // 웹에서는 Firebase Auth의 GoogleAuthProvider 사용 (권장 방식)
          GoogleAuthProvider authProvider = GoogleAuthProvider();
          authProvider.addScope('email');
          authProvider.addScope('profile');

          // 팝업으로 로그인
          final UserCredential userCredential = await _auth.signInWithPopup(
            authProvider,
          );

          // 사용자 정보 Firestore에 저장/업데이트
          if (userCredential.user != null) {
            await createInitialUserRecord(userCredential.user!);
            await _updateFCMToken();
          }

          return userCredential;
        } catch (e) {
          print('Firebase 팝업 로그인 실패: $e');
          // 대체 방식으로 리디렉션 로그인 시도
          final provider = GoogleAuthProvider();
          await _auth.signInWithRedirect(provider);
          // 이 이후의 코드는 리디렉션 후 실행되지 않음
          throw Exception('리디렉션 로그인 중...');
        }
      }
      // 모바일 환경인 경우 - 기존 방식 유지
      else {
        // Google 로그인 흐름 시작
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'google-sign-in-cancelled',
            message: 'Google 로그인이 취소되었습니다.',
          );
        }

        // Google 인증 정보 가져오기
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Google 인증 정보로 Firebase에 로그인
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        // 사용자 정보 Firestore에 저장/업데이트
        if (userCredential.user != null) {
          await createInitialUserRecord(userCredential.user!);
          await _updateFCMToken();
        }

        return userCredential;
      }
    } catch (e) {
      print('Google 로그인 오류: $e');
      rethrow;
    }
  }

  // FCM 토큰 업데이트
  Future<void> _updateFCMToken() async {
    if (currentUser == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      String? token;

      // 웹 환경에서는 VAPID 키가 필요
      if (kIsWeb) {
        // 환경 변수 이름 수정 (VAP_ID -> VAPID_KEY)
        final vapidKey = dotenv.env['VAPID_KEY'];
        if (vapidKey == null || vapidKey.isEmpty) {
          print('VAPID_KEY가 설정되지 않았습니다.');
          return;
        }

        print('VAPID 키 사용: ${vapidKey.substring(0, min(5, vapidKey.length))}...');

        try {
          token = await messaging.getToken(vapidKey: vapidKey);
          print('FCM 토큰 발급 성공');
        } catch (e) {
          print('FCM 토큰 발급 오류: $e');
          rethrow;
        }
      } else {
        token = await messaging.getToken();
      }

      if (token != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
        print('FCM 토큰 저장 성공: ${token.substring(0, min(10, token.length))}...');
      }
    } catch (e) {
      print('FCM 토큰 업데이트 실패: $e');
    }
  }

  // FCM 토큰 제거 (로그아웃 시 호출) - VAPID_KEY 변수명 수정
  Future<void> _removeFCMToken() async {
    if (currentUser == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      String? token;

      if (kIsWeb) {
        // VAP_ID -> VAPID_KEY로 수정
        final vapidKey = dotenv.env['VAPID_KEY'];
        if (vapidKey == null || vapidKey.isEmpty) {
          print('VAPID_KEY가 설정되지 않았습니다.');
          return;
        }
        
        token = await messaging.getToken(vapidKey: vapidKey);
      } else {
        token = await messaging.getToken();
      }

      if (token != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
        print('FCM 토큰 제거 성공');
      }
    } catch (e) {
      print('FCM 토큰 제거 실패: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      // FCM 토큰 제거
      await _removeFCMToken();

      // Google 로그아웃 (웹에서는 불필요할 수 있음)
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }

      // Firebase 로그아웃
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 실패: $e');
      rethrow;
    }
  }

  // 초기 사용자 레코드 생성
  Future<void> createInitialUserRecord(User firebaseUser) async {
    // 이미 존재하는지 확인
    final docSnapshot =
        await _firestore.collection('users').doc(firebaseUser.uid).get();

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
        fcmTokens: [], // FCM 토큰 배열 추가
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(appUser.toMap());
    }
  }

  // 사용자 추가 정보 업데이트
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

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .update(updateData);
  }

  // 관리자로 승격 (관리자만 호출 가능)
  Future<void> promoteToAdmin(String userId) async {
    // 현재 사용자가 관리자인지 확인
    final currentUserData = await getCurrentUserData();
    if (currentUserData == null || !currentUserData.isAdmin) {
      throw Exception('관리자 권한이 없습니다.');
    }

    await _firestore.collection('users').doc(userId).update({'role': 'admin'});

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

    await _firestore.collection('users').doc(userId).update({'role': 'member'});
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

    final docSnapshot =
        await _firestore.collection('users').doc(currentUser!.uid).get();

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

  // 프로필 업데이트
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
          .child(
            '${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

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
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(updateData);
    }
  }

  // 웹 환경에서 FCM 설정 초기화
  Future<void> initWebFCM() async {
    if (!kIsWeb) return;

    try {
      // Firebase Messaging 인스턴스
      final messaging = FirebaseMessaging.instance;

      // 권한 요청
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('FCM 알림 권한 상태: ${settings.authorizationStatus}');

      // 서비스 워커 등록 확인
      if (currentUser != null) {
        // VAPID 키가 올바른지 확인 후 토큰 업데이트
        await _updateFCMToken();
      }

      // 포그라운드 메시지 핸들러 등록
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('포그라운드 메시지 수신: ${message.notification?.title}');
        // 여기에 사용자 인터페이스에 알림을 표시하는 코드 추가
      });
    } catch (e) {
      print('웹 FCM 초기화 실패: $e');
    }
  }
}