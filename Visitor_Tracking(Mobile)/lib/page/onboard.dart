import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beacon_tracking/page/login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beacon_tracking/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardPage extends StatefulWidget {
  const OnboardPage({super.key});
  @override
  State<OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<OnboardPage> {
  final _bkIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginAsVisitor() async {
    final bkId = _bkIdController.text.trim();
    if (bkId.isEmpty) {
      setState(() => _errorMessage = "กรุณากรอกรหัสนัดหมาย");
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.post(
        ApiConstants.visitorLogin,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bk_id': bkId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role_id', '2');
        await prefs.setString('bk_id', bkId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const Login()),
          );
        }
      } else {
        setState(() => _errorMessage = data['message'] ?? "รหัสนัดหมายไม่ถูกต้อง");
      }
    } catch (e) {
      setState(() => _errorMessage = "เกิดข้อผิดพลาด กรุณาลองใหม่");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C896), Color(0xFF00A877), Color(0xFF007A58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / Icon
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 24),
                Text("ยินดีต้อนรับ",
                  style: GoogleFonts.prompt(color: Colors.white.withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text("ระบบติดตาม\nการนัดหมาย",
                  style: GoogleFonts.prompt(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 8),
                Text("Visitor Appointment Tracking System",
                  style: GoogleFonts.prompt(color: Colors.white.withOpacity(0.7), fontSize: 13)),

                const Spacer(),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("เข้าสู่ระบบด้วยรหัสนัดหมาย",
                        style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0A2540))),
                      const SizedBox(height: 4),
                      Text("กรอกรหัสที่ได้รับจากเจ้าหน้าที่",
                        style: GoogleFonts.prompt(fontSize: 13, color: const Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bkIdController,
                        style: GoogleFonts.prompt(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "รหัสนัดหมาย (Booking ID)",
                          hintStyle: GoogleFonts.prompt(color: Colors.grey[400], fontSize: 13.5),
                          prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF00C896)),
                          filled: true,
                          fillColor: const Color(0xFFF4F7F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF00C896), width: 1.5),
                          ),
                          errorText: _errorMessage,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginAsVisitor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C896),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                            : Text("เข้าสู่ระบบ", style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.4))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("หรือ", style: GoogleFonts.prompt(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.4))),
                ]),
                const SizedBox(height: 16),

                // Staff login
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text("เข้าสู่ระบบเจ้าหน้าที่",
                      style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}