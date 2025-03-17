// lib/data/models/app_user.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? profileImage;
  final String role; // 'admin', 'member'
  final Timestamp createdAt;
  final String? studentId;
  final String? phone;
  final String? nickname;
  final int? age;
  final bool profileCompleted;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.profileImage,
    required this.role,
    required this.createdAt,
    this.studentId,
    this.phone,
    this.nickname,
    this.age,
    this.profileCompleted = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profileImage: map['profileImage'],
      role: map['role'] ?? 'member',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      studentId: map['studentId'],
      phone: map['phone'],
      nickname: map['nickname'],
      age: map['age'],
      profileCompleted: map['profileCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'role': role,
      'createdAt': createdAt,
      'studentId': studentId,
      'phone': phone,
      'nickname': nickname,
      'age': age,
      'profileCompleted': profileCompleted,
    };
  }


  // 사용자 객체 복사본 생성 (필드 업데이트 시 사용)
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImage,
    String? role,
    Timestamp? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // 관리자 여부 확인
  bool get isAdmin => role == 'admin';
}