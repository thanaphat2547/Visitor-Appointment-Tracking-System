import 'package:flutter/material.dart';
import 'package:beacon_tracking/page/login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:beacon_tracking/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_tracking/service/notification_service.dart';

const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kBackground = Color(0xFFF4F7F6);
const kSurface = Colors.white;
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);
const kBorderColor = Color(0xFFE8F5F1);

class ProfileModel {
  final String id;
  final String firstname;
  final String lastname;
  final String email;
  final String phone;
  final String? department;
  final String? section;
  final String? position;
  final String? bkId;

  ProfileModel({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phone,
    this.department,
    this.section,
    this.position,
    this.bkId,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json, String roleId) {
    if (roleId == '2') {
      return ProfileModel(
        id: json['vis_id']?.toString() ?? '',
        firstname: json['vis_firstname']?.toString() ?? '',
        lastname: json['vis_lastname']?.toString() ?? '',
        email: json['vis_email']?.toString() ?? '-',
        phone: json['vis_phone']?.toString() ?? '',
        bkId: json['bk_id']?.toString() ?? '',
      );
    } else {
      return ProfileModel(
        id: json['emp_id']?.toString() ?? '',
        firstname: json['emp_firstname']?.toString() ?? '',
        lastname: json['emp_lastname']?.toString() ?? '',
        email: json['emp_email']?.toString() ?? '',
        phone: json['emp_phone']?.toString() ?? '',
        department: json['emp_department']?.toString() ?? '-',
        section: json['emp_section']?.toString() ?? '-',
        position: json['emp_position']?.toString() ?? '-',
      );
    }
  }
}

class Profile extends StatefulWidget {
  final String username;
  final String password;
  const Profile({super.key, required this.username, required this.password});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  late Future<ProfileModel> profileFuture;
  String? roleId;

  Future<ProfileModel> fetchProfile(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    roleId = prefs.getString('role_id');
    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    Map<String, String> body = {};
    if (roleId == '2') {
      body['bk_id'] = prefs.getString('bk_id') ?? '';
    } else {
      body['emp_id'] = prefs.getString('emp_id') ?? '';
    }
    final response = await http.post(
      ApiConstants.profile,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ProfileModel.fromJson(jsonData['data'], roleId!);
    } else {
      throw Exception('Failed to load profile data');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    // Clear notifications from backend
    if (userId != null) {
      try {
        await http.post(
          ApiConstants.clearNotification,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId}),
        );
      } catch (e) {
        print('Error clearing notifications: $e');
      }
    }

    // Reset local notification service state
    NotificationService().clearAll();

    // Clear all preferences
    await prefs.clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("ออกจากระบบ", style: GoogleFonts.prompt(fontWeight: FontWeight.w700, color: kTextPrimary)),
        content: Text("คุณต้องการออกจากระบบหรือไม่?", style: GoogleFonts.prompt(color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("ยกเลิก", style: GoogleFonts.prompt(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _logout(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("ออกจากระบบ", style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    profileFuture = fetchProfile(widget.username, widget.password);
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: kPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.prompt(fontSize: 11.5, color: kTextSecondary, fontWeight: FontWeight.w500)),
              Text(value, style: GoogleFonts.prompt(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: FutureBuilder<ProfileModel>(
        future: profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: GoogleFonts.prompt()));
          }

          final profile = snapshot.data!;
          final initials = (profile.firstname.isNotEmpty ? profile.firstname[0] : '?').toUpperCase();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kPrimary, kPrimaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                        ),
                        child: Center(
                          child: Text(initials,
                            style: GoogleFonts.prompt(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${profile.firstname} ${profile.lastname}",
                        style: GoogleFonts.prompt(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Text(
                          roleId == '2' ? 'ผู้มาติดต่อ' : 'พนักงาน',
                          style: GoogleFonts.prompt(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoCard("เบอร์โทรศัพท์", profile.phone, Icons.phone_outlined),
                      if (roleId == '1') ...[
                        _buildInfoCard("อีเมล", profile.email, Icons.email_outlined),
                        _buildInfoCard("ฝ่าย", profile.department ?? '-', Icons.business_outlined),
                        _buildInfoCard("แผนก", profile.section ?? '-', Icons.account_tree_outlined),
                        _buildInfoCard("ตำแหน่ง", profile.position ?? '-', Icons.badge_outlined),
                      ],
                      if (roleId == '2') ...[
                        _buildInfoCard("อีเมล", profile.email, Icons.email_outlined),
                        _buildInfoCard("รหัสนัดหมาย", profile.bkId ?? '-', Icons.confirmation_number_outlined),
                      ],
                      const SizedBox(height: 24),
                      // Logout button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showLogoutDialog,
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                          label: Text('ออกจากระบบ', style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}