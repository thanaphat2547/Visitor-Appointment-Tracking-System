import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:beacon_tracking/page/menu.dart';
import 'package:beacon_tracking/page/profile.dart';
import 'package:beacon_tracking/page/notification.dart';
import 'package:beacon_tracking/service/notification_service.dart';

class Navigation extends StatefulWidget {
  final String username;
  final String password;
  final String role;

  const Navigation({
    super.key,
    required this.username,
    required this.password,
    required this.role,
  });

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _selectedIndex = 0;
  // เรียกใช้ Singleton ของ NotificationService
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    // ติดตามการแจ้งเตือนเพื่อให้ Icon อัปเดตตัวเลขทันที
    _notificationService.addListener(_onNotificationUpdate);
    _updateUnreadCount();
  }

  void _onNotificationUpdate() {
    if (mounted) _updateUnreadCount();
  }

  void _updateUnreadCount() {
    setState(() {
      _unreadCount = _notificationService.unreadCount;
    });
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  // เช็คว่าเป็น Visitor หรือไม่
  bool get _isVisitor => widget.role == 'visitor' || widget.role == '2';

  List<Widget> _getPages() {
    if (_isVisitor) {
      return [
        Menu(username: widget.username, password: widget.password),
        Profile(username: widget.username, password: widget.password),
      ];
    } else {
      return [
        Menu(username: widget.username, password: widget.password),
        const NotificationPage(),
        Profile(username: widget.username, password: widget.password),
      ];
    }
  }

  List<Widget> _getIcons() {
    if (_isVisitor) {
      return [
        const Icon(Icons.home, size: 30, color: Colors.white),
        const Icon(Icons.person, size: 30, color: Colors.white),
      ];
    } else {
      return [
        const Icon(Icons.home, size: 30, color: Colors.white),
        // Badge แจ้งเตือนบนไอคอนกระดิ่ง
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications, size: 30, color: Colors.white),
            if (_unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF09203F), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$_unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const Icon(Icons.person, size: 30, color: Colors.white),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    
    // กัน Error กรณี Index หลุดขอบเมื่อเปลี่ยน Role
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: const Color(0xFF09203F),
        buttonBackgroundColor: const Color(0xFF09203F),
        height: 65,
        items: _getIcons(),
        index: _selectedIndex,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}