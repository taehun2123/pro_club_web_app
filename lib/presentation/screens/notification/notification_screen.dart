import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/notification.dart';
import 'package:flutter_application_1/presentation/providers/notification_provider.dart';
import 'package:flutter_application_1/presentation/providers/user_provider.dart';
import 'package:flutter_application_1/presentation/screens/board/post_detail_screen.dart';
import 'package:flutter_application_1/presentation/screens/notice/notice_detail_screen.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    
    final user = userProvider.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    final notifications = notificationProvider.notifications;
    final isLoading = notificationProvider.isLoading;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: () {
                // 변경된 메서드 호출 방식: userId 매개변수 제거
                notificationProvider.markAllAsRead();
              },
              child: const Text(
                '모두 읽음 처리',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: notifications.isEmpty 
                ? null 
                : () => _showDeleteConfirmDialog(context),
            tooltip: '모든 알림 삭제',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('알림이 없습니다'))
              : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationItem(context, notification);
                  },
                ),
    );
  }
  
  Widget _buildNotificationItem(BuildContext context, AppNotification notification) {
    // 읽지 않은 알림 배경색 설정
    final backgroundColor = notification.isRead 
        ? Colors.transparent 
        : AppColors.primary.withOpacity(0.05);
        
    // 알림 타입에 따른 아이콘 설정
    IconData iconData;
    Color iconColor;
    
    switch (notification.type) {
      case NotificationType.mention:
        iconData = Icons.alternate_email;
        iconColor = Colors.blue;
        break;
      case NotificationType.newNotice:
        iconData = Icons.announcement;
        iconColor = AppColors.primary;
        break;
      case NotificationType.newComment:
        iconData = Icons.comment;
        iconColor = Colors.green;
        break;
      case NotificationType.newReply:
        iconData = Icons.question_answer;
        iconColor = Colors.purple;
        break;
      case NotificationType.hotPost:
        iconData = Icons.local_fire_department;
        iconColor = Colors.red;
        break;
      case NotificationType.adminMessage:
      iconData = Icons.campaign;
        iconColor = Colors.orange;
        break;
    }
    
    // 날짜 포맷
    final createdDate = DateFormat('yyyy.MM.dd HH:mm').format(notification.createdAt.toDate());
    
    return InkWell(
      onTap: () => _handleNotificationTap(context, notification),
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 알림 타입 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // 알림 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 알림 제목
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // 알림 내용
                  Text(
                    notification.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // 날짜
                  Text(
                    createdDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // 삭제 버튼
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                final notificationProvider = 
                    Provider.of<NotificationProvider>(context, listen: false);
                notificationProvider.deleteNotification(notification.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
  
  // 알림 탭 처리 함수
  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // 읽음 처리
    if (!notification.isRead) {
      Provider.of<NotificationProvider>(context, listen: false)
          .markAsRead(notification.id);
    }
    
    // 알림 타입에 따라 적절한 화면으로 이동
    if (notification.sourceId == null) return;
    
    switch (notification.type) {
      case NotificationType.mention:
      case NotificationType.newComment:
      case NotificationType.newReply:
      case NotificationType.hotPost:
        // 게시글 상세 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: notification.sourceId!,
            ),
          ),
        );
        break;
      case NotificationType.newNotice:
        // 공지사항 상세 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoticeDetailScreen(
              noticeId: notification.sourceId!,
            ),
          ),
        );
        break;
      default:
        break;
    }
  }
  
  // 모든 알림 삭제 확인 다이얼로그
  // userId 매개변수 제거
  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 전체 삭제'),
        content: const Text('모든 알림을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final notificationProvider = 
          Provider.of<NotificationProvider>(context, listen: false);
      // 변경된 메서드 호출 방식: userId 매개변수 제거
      notificationProvider.deleteAllNotifications();
    }
  }
}