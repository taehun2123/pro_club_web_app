// lib/main.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/data/models/app_user.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/auth/login_screen.dart';
import 'package:flutter_application_1/presentation/screens/home/home_screen.dart';
import 'package:flutter_application_1/presentation/screens/auth/user_info_screen.dart';
import 'package:flutter_application_1/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR';
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'PRO 동아리',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }
        
        // Firebase 사용자가 있으면 Firestore에서 추가 정보 확인
        return FutureBuilder<AppUser?>(
          future: authService.getCurrentUserData(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final appUser = userSnapshot.data;
            
            // AppUser 정보가 있고 프로필이 완료되었으면 홈 화면으로
            if (appUser != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<UserProvider>(context, listen: false).setUser(appUser);
              });
              
              if (appUser.profileCompleted) {
                return const HomeScreen();
              } else {
                // 프로필이 완료되지 않았으면 추가 정보 입력 화면으로
                return const UserInfoScreen();
              }
            } else {
              // AppUser 정보가 없는 경우, 생성 후 화면 전환을 위한 FutureBuilder 추가
              return FutureBuilder<void>(
                future: authService.createInitialUserRecord(firebaseUser),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  // 사용자 생성 완료 후 Provider 업데이트
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Provider.of<UserProvider>(context, listen: false).setUser(AppUser(
                      id: firebaseUser.uid,
                      email: firebaseUser.email ?? '',
                      name: firebaseUser.displayName ?? '',
                      profileImage: firebaseUser.photoURL,
                      role: 'member',
                      createdAt: Timestamp.now(),
                      profileCompleted: false,
                    ));
                  });
                  
                  return const UserInfoScreen();
                },
              );
            }
          },
        );
      },
    );
  }
}