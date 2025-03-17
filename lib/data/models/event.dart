import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final Timestamp startTime;
  final Timestamp endTime;
  final String location;
  final String createdBy;
  final String createdByName;
  final Timestamp createdAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory Event.fromMap(Map<String, dynamic> map, String docId) {
    return Event(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: map['startTime'] ?? Timestamp.now(),
      endTime: map['endTime'] ?? Timestamp.now(),
      location: map['location'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
    };
  }

  // 일정 객체 복사본 생성 (필드 업데이트 시 사용)
  Event copyWith({
    String? id,
    String? title,
    String? description,
    Timestamp? startTime,
    Timestamp? endTime,
    String? location,
    String? createdBy,
    String? createdByName,
    Timestamp? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // 이벤트가 오늘인지 확인
  bool get isToday {
    final now = DateTime.now();
    final start = startTime.toDate();
    
    return start.year == now.year &&
           start.month == now.month &&
           start.day == now.day;
  }

  // 이벤트 날짜 문자열 (예: "2025년 3월 15일")
  String get dateString {
    final date = startTime.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 이벤트 시간 문자열 (예: "14:00 ~ 16:00")
  String get timeString {
    final start = startTime.toDate();
    final end = endTime.toDate();
    
    return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} ~ '
           '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
}