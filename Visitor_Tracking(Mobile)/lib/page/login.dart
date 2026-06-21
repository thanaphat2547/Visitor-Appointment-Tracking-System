import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:beacon_tracking/page/menu.dart';
import '../auth/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/notification_service.dart';

// ============ DESIGN TOKENS ============
const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kBg = Color(0xFFF4F7F6);
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin(BuildContext context) async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar("กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }
    setState(() => _isLoading = true);

    final result = await _authService.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!context.mounted) return;
    setState(() => _isLoading = false);

    if (result["success"]) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userData = result["user"];
        final dynamic roleIdRaw = result["role_id"];
        final int roleId = roleIdRaw is int ? roleIdRaw : int.parse(roleIdRaw.toString());

        if (roleId == 0) {
          _showErrorSnackBar("ไม่สามารถเข้าถึงได้: แอปพลิเคชันนี้มีไว้สำหรับพนักงานและผู้มาติดต่อเท่านั้น.");
          return;
        }

        if (userData != null) {
          await prefs.setString('role_id', roleId.toString());
          String roleName = (roleId == 2) ? 'visitor' : 'officer';
          await prefs.setString('role', roleName);

          if (roleId == 2) {
            String visId = (userData['vis_id'] ?? userData['id']).toString();
            await prefs.setString('user_id', visId);
            await prefs.setString('vis_id', visId);
            await prefs.setString('bk_id', userData['bk_id']?.toString() ?? "");
          } else {
            String empId = userData['emp_id'].toString();
            await prefs.setString('user_id', empId);
            await prefs.setString('emp_id', empId);
          }
          await NotificationService().updateTokenAfterLogin();
        }
      } catch (e) {
        print("❌ Error during post-login: $e");
      }

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Menu(
            username: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        ),
      );
    } else {
      _showErrorSnackBar(result["message"] ?? "ข้อมูลการเข้าสู่ระบบไม่ถูกต้อง");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.prompt(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // ===== TOP SECTION (Green header) =====
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 40,
                  left: 28, right: 28, bottom: 40,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary, kPrimaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text("เข้าสู่ระบบ",
                      style: GoogleFonts.prompt(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text("ระบบติดตามการนัดหมายผู้มาติดต่อ",
                      style: GoogleFonts.prompt(color: Colors.white.withOpacity(0.8), fontSize: 13.5)),
                    const SizedBox(height: 16),
                    // Role indicator chips
                  ],
                ),
              ),

              // ===== BOTTOM SECTION (White card) =====
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text("ยินดีต้อนรับ",
                        style: GoogleFonts.prompt(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary)),
                      Text("กรอกข้อมูลเพื่อเข้าสู่ระบบ",
                        style: GoogleFonts.prompt(fontSize: 13.5, color: kTextSecondary)),
                      const SizedBox(height: 28),

                      // Username
                      _buildInputField(
                        controller: _usernameController,
                        label: "ชื่อผู้ใช้งาน / เบอร์โทรศัพท์",
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),

                      // Password
                      _buildInputField(
                        controller: _passwordController,
                        label: "รหัสผ่าน / รหัสนัดหมาย",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscure: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const Spacer(),

                      // Login button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleLogin(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            disabledBackgroundColor: kPrimary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text("เข้าสู่ระบบ",
                                  style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text("Visitor Tracking System v1.0",
                          style: GoogleFonts.prompt(color: Colors.grey[400], fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rolePill(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.prompt(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && obscure,
      style: GoogleFonts.prompt(fontSize: 15, color: kTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.prompt(color: kTextSecondary, fontSize: 13.5),
        prefixIcon: Icon(icon, color: kPrimary, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: kTextSecondary, size: 20),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF4F7F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}