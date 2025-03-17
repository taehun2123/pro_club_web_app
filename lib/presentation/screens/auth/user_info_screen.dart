import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/home/home_screen.dart';
import 'package:flutter_application_1/presentation/widgets/custom_button.dart';
import 'package:flutter_application_1/presentation/widgets/custom_text_field.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 로그인된 사용자
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      // 추가 정보 Firestore에 저장
      await _authService.updateUserAdditionalInfo(
        name: _nameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        phone: _phoneController.text.trim(),
        nickname: _nicknameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
      );

      // UserProvider 업데이트
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final updatedUser = await _authService.getCurrentUserData();
      if (updatedUser != null) {
        userProvider.setUser(updatedUser);
      }

      // 홈 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('정보 저장 중 오류가 발생했습니다: $e')));
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
      appBar: AppBar(
        title: const Text('추가 정보 입력'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PRO 동아리 가입을 위한 추가 정보를 입력해주세요.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                controller: _nameController,
                label: '이름',
                hintText: '실명을 입력하세요',
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _studentIdController,
                label: '학번',
                hintText: '학번을 입력하세요',
                keyboardType: TextInputType.number,
                validator: (value) => Validators.validateRequired(value, '학번'),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _phoneController,
                label: '전화번호',
                hintText: '010-XXXX-XXXX',
                keyboardType: TextInputType.phone,
                validator:
                    (value) => Validators.validateRequired(value, '전화번호'),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _nicknameController,
                label: '별명 (닉네임)',
                hintText: '사용할 별명을 입력하세요',
                validator: (value) => Validators.validateRequired(value, '별명'),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _ageController,
                label: '나이',
                hintText: '나이를 입력하세요',
                keyboardType: TextInputType.number,
                validator: (value) => Validators.validateRequired(value, '나이'),
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: '가입 완료',
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
