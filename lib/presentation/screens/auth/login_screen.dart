// lib/presentation/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/auth/user_info_screen.dart';
import 'package:flutter_application_1/presentation/screens/home/home_screen.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 구글 로그인 실행
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      // 사용자 정보 확인
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userData = await _authService.getCurrentUserData();

      if (userData != null) {
        userProvider.setUser(userData);

        // 프로필 완료 여부에 따라 다른 화면으로 이동
        if (userData.profileCompleted) {
          // 프로필이 완료된 사용자는 홈 화면으로
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // 프로필이 완료되지 않은 사용자는 추가 정보 화면으로
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserInfoScreen()),
          );
        }
      } else {
        // 사용자 데이터가 없는 경우 (신규 가입)
        // 기본 정보로 생성 후 추가 정보 화면으로 이동
        await _authService.createInitialUserRecord(_authService.currentUser!);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UserInfoScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 로그인 중 오류가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 로고
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 제목
                  const Center(
                    child: Text(
                      'PRO 동아리',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  Center(
                    child: Text(
                      '울산과학대학교 컴퓨터공학과',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 80),

                  // 앱 설명
                  Center(
                    child: Text(
                      'PRO 동아리 앱에 오신 것을 환영합니다',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '구글 계정으로 로그인하여 시작하세요',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 구글 로그인 버튼
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                      : ElevatedButton.icon(
                        icon: Image.asset('images/google_logo.png', height: 24),
                        label: const Text(
                          'Google로 로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.darkGray,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  const SizedBox(height: 24),

                  // 개인정보 처리방침 링크
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // 개인정보 처리방침 페이지로 이동
                      },
                      child: Text(
                        '개인정보 처리방침',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
