// lib/presentation/screens/admin/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/models/app_user.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AuthService _authService = AuthService();
  List<AppUser>? _users;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 모든 사용자 가져오기
      final users = await _authService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사용자 목록 로드 중 오류: $e')),
      );
    }
  }

  Future<void> _changeUserRole(AppUser user, String newRole) async {
    try {
      if (newRole == 'admin') {
        await _authService.promoteToAdmin(user.id);
      } else {
        await _authService.demoteToMember(user.id);
      }
      
      // 현재 사용자인 경우 UserProvider 새로고침
      if (user.id == _authService.currentUser?.uid) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshUser(_authService);
      }
      
      // 목록 새로고침
      _loadUsers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name}의 역할이 ${newRole == 'admin' ? '관리자' : '회원'}로 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('역할 변경 중 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 패널'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users == null || _users!.isEmpty
              ? const Center(child: Text('사용자가 없습니다.'))
              : ListView.builder(
                  itemCount: _users!.length,
                  itemBuilder: (context, index) {
                    final user = _users![index];
                    return ListTile(
                      leading: user.profileImage != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(user.profileImage!),
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(user.role == 'admin' ? '관리자' : '회원'),
                          PopupMenuButton<String>(
                            onSelected: (role) => _changeUserRole(user, role),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'admin',
                                child: Text('관리자로 변경'),
                              ),
                              const PopupMenuItem(
                                value: 'member',
                                child: Text('회원으로 변경'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}