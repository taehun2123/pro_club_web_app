import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/models/event.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 컬렉션 참조
  CollectionReference get _eventsRef => _firestore.collection('events');
  
  // 모든 일정 가져오기
  Future<List<Event>> getAllEvents() async {
    final querySnapshot = await _eventsRef
        .orderBy('startTime')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Event.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 오늘 일정 가져오기
  Future<List<Event>> getTodayEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final querySnapshot = await _eventsRef
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Event.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 특정 월의 일정 가져오기
  Future<List<Event>> getMonthEvents(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    
    final querySnapshot = await _eventsRef
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('startTime')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Event.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 특정 날짜의 일정 가져오기
  Future<List<Event>> getDayEvents(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final querySnapshot = await _eventsRef
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Event.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  // 일정 상세 가져오기
  Future<Event?> getEventById(String eventId) async {
    final docSnapshot = await _eventsRef.doc(eventId).get();
    
    if (docSnapshot.exists) {
      return Event.fromMap(
        docSnapshot.data() as Map<String, dynamic>,
        docSnapshot.id,
      );
    }
    
    return null;
  }
  
  // 일정 추가
  Future<String> addEvent(Event event) async {
    final docRef = await _eventsRef.add(event.toMap());
    return docRef.id;
  }
  
  // 일정 수정
  Future<void> updateEvent(Event event) async {
    await _eventsRef.doc(event.id).update(event.toMap());
  }
  
  // 일정 삭제
  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }
}