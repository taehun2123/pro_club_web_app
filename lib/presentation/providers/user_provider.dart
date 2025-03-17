// lib/presentation/providers/user_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/models/app_user.dart';
import 'package:flutter_application_1/data/services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get isAdmin => _user?.isAdmin ?? false;

  void setUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  void updateUser(AppUser updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  Future<void> refreshUser(AuthService authService) async {
    if (_user != null) {
      final updatedUser = await authService.getCurrentUserData();
      if (updatedUser != null) {
        setUser(updatedUser);
      }
    }
  }
}
