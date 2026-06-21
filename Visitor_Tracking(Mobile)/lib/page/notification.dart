import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:beacon_tracking/api_constants.dart';
import 'package:beacon_tracking/service/notification_service.dart';

const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kBackground = Color(0xFFF4F7F6);
const kSurface = Colors.white;
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);
const kBorderColor = Color(0xFFE8F5F1);

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _displayNotifications = [];
  String? _visitorBkId;
  String? _userId;
  bool _isVisitor = false;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_updateNotifications);
    _loadVisitorPreferences();
    _notificationService.markAllRead();
  }

  Future<void> _loadVisitorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final roleId = prefs.getString('role_id');
    final bkId = prefs.getString('bk_id');
    final userId = prefs.getString('user_id') ?? prefs.getString('emp_id') ?? prefs.getString('vis_id');

    if (!mounted) return;

    setState(() {
      _isVisitor = roleId == '2';
      _visitorBkId = bkId;
      _userId = userId;
    });

    if (userId != null) {
      await _fetchNotificationHistory(userId);
    }
  }

  Future<void> _fetchNotificationHistory(String userId) async {
    try {
      final response = await http.get(ApiConstants.shownotificationHistory(userId: userId));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final notifications = (data['notifications'] as List<dynamic>?) ?? [];

      if (!mounted) return;
      setState(() {
        _notifications = notifications.map<Map<String, dynamic>>((notification) {
          final createdAt = notification['created_at'] != null
              ? DateTime.tryParse(notification['created_at'].toString())
              : null;
          return {
            'title': notification['title'] ?? '',
            'body': notification['body'] ?? '',
            'type': notification['eventtype'] ?? '',
            'bk_id': notification['bk_id'] ?? '',
            'receivedAt': createdAt,
          };
        }).toList();
        _filterNotifications();
      });
    } catch (e) {
      print('Error loading notification history: $e');
    }
  }

  void _filterNotifications() {
    _displayNotifications = _notifications.where((notification) {
      if (!_isVisitor) return true;
      if (_visitorBkId == null || _visitorBkId!.isEmpty) return true;
      return notification['bk_id']?.toString() == _visitorBkId;
    }).toList();
  }

  void _updateNotifications() {
    if (!mounted || _userId == null) return;
    _fetchNotificationHistory(_userId!);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_updateNotifications);
    super.dispose();
  }

  String _formatDateTime(DateTime dt) => DateFormat('dd MMM yyyy • HH:mm น.').format(dt);

  Color _getStatusColor(String type) {
    if (type.toUpperCase() == 'IN') return kPrimary;
    if (type.toUpperCase() == 'OUT') return const Color(0xFFEF4444);
    return kTextSecondary;
  }

  IconData _getStatusIcon(String type) {
    if (type.toUpperCase() == 'IN') return Icons.login_rounded;
    if (type.toUpperCase() == 'OUT') return Icons.logout_rounded;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      extendBody: true,
      body: _displayNotifications.isEmpty ? _buildEmptyState() : _buildNotificationList(),
      floatingActionButton: _displayNotifications.isNotEmpty
          ? FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _notificationService.clearAll();
                  _notifications.clear();
                  _displayNotifications.clear();
                });
              },
              backgroundColor: kPrimary,
              tooltip: "ล้างการแจ้งเตือนทั้งหมด",
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5F1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.notifications_off_outlined, size: 48, color: kPrimary),
        ),
        const SizedBox(height: 16),
        Text("ไม่มีการแจ้งเตือน", style: GoogleFonts.prompt(fontSize: 16, color: kTextSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text("การแจ้งเตือนการเช็คอินจะปรากฏที่นี่", style: GoogleFonts.prompt(fontSize: 13, color: Colors.grey[400])),
      ],
    ),
  );

  Widget _buildNotificationList() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    itemCount: _displayNotifications.length,
    itemBuilder: (ctx, i) {
      final n = _displayNotifications[_displayNotifications.length - 1 - i];
      final type = n['type']?.toString() ?? '';
      final statusColor = _getStatusColor(type);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getStatusIcon(type), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type.toUpperCase() == 'IN' ? 'เข้า' : 'ออก',
                            style: GoogleFonts.prompt(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            n['title'] ?? '',
                            style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 13.5, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['body'] ?? '',
                      style: GoogleFonts.prompt(fontSize: 12.5, color: kTextSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          n['receivedAt'] != null ? _formatDateTime(n['receivedAt'] as DateTime) : '',
                          style: GoogleFonts.prompt(fontSize: 11, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}