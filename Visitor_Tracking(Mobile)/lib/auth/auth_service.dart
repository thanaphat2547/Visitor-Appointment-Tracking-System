import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beacon_tracking/api_constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_tracking/service/notification_service.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final String basicAuth =
          'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      print('🔐 DEBUG: Sending Basic Auth: $basicAuth');

      final response = await http.post(
        ApiConstants.profile,
        headers: {
          "Authorization": basicAuth,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data']; 

        // จัดการ Role ID และแปลงเป็นชื่อ Role สำหรับแจ้งเตือน
        final dynamic roleIdRaw = data['role_id'];
        final int roleId = roleIdRaw is int ? roleIdRaw : int.parse(roleIdRaw.toString());
        String roleName = (roleId == 2) ? 'visitor' : 'officer';

        // แยก ID ตามประเภท
        String userId = "";
        if (roleId == 0 || roleId == 1) {
          userId = data['emp_id']?.toString() ?? "";
        } else if (roleId == 2) {
          userId = (data['vis_id'] ?? data['id'])?.toString() ?? "";
        }

        // เตรียม FCM Token
        final fcm = FirebaseMessaging.instance;
        String? fcmToken;
        try {
          fcmToken = await fcm.getToken();
        } catch (e) {
          print("⚠️ FCM Token Error: $e");
        }

        // บันทึกข้อมูลลง SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role_id', roleId.toString());
          await prefs.setString('role', roleName); 
          await prefs.setString('user_id', userId); 
          await prefs.setString('username', username);
          
          if (roleId == 2) {
            await prefs.setString('vis_id', userId);
            await prefs.setString('bk_id', data['bk_id']?.toString() ?? "");
          } else {
            await prefs.setString('emp_id', userId);
          }
        } catch (prefsError) {
          print('❌ SharedPreferences Error: $prefsError');
        }

        // บันทึก FCM Token ลง Server (ส่ง Role ไปด้วย)
        if (userId.isNotEmpty && fcmToken != null) {
          await saveFcmToken(userId, fcmToken, roleName);
        }

        return {
          "success": true,
          "role_id": roleId,
          "user": data,
          "message": "เข้าสู่ระบบสำเร็จ"
        };
        
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['message'] ?? "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง",
        };
      }
    } catch (err) {
      print('❌ Login error: $err');
      return {"success": false, "message": "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้"};
    }
  }

  // ปรับปรุงให้รับ role และใช้ชื่อตัวแปรที่ตรงกับ Backend
  Future<void> saveFcmToken(String userId, String fcmToken, String role) async {
    try {
      await http.post(
        Uri.parse(ApiConstants.savetoken.toString()), 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'user_id': userId,
          'fcm_token': fcmToken, 
          'role': role,          
        }),
      );
      print('✅ FCM Token update request sent for $role');
    } catch (e) {
      print("❌ Error saving FCM token: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear notifications from backend
    try {
      final userId = prefs.getString('user_id') ?? prefs.getString('emp_id') ?? prefs.getString('vis_id');
      if (userId != null && userId.isNotEmpty) {
        await http.post(
          ApiConstants.clearNotification,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId}),
        );
        print('✅ Cleared notifications on backend for user: $userId');
      }
    } catch (e) {
      print('❌ Error clearing notifications on backend: $e');
    }

    // Clear local notifications
    try {
      NotificationService().clearAll();
    } catch (e) {
      print('❌ Error clearing NotificationService: $e');
    }

    await prefs.clear();
    print('✅ Logged out and cleared storage');
  }
}