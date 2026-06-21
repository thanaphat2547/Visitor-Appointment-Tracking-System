import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beacon_tracking/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kBackground = Color(0xFFF4F7F6);
const kSurface = Colors.white;
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);
const kBorderColor = Color(0xFFE8F5F1);

class AddBookingPage extends StatefulWidget {
  final String username;
  final String password;
  const AddBookingPage({super.key, required this.username, required this.password});

  @override
  State<AddBookingPage> createState() => _AddBookingPageState();
}

class _AddBookingPageState extends State<AddBookingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 1
  String? _selectedVisitorId;
  String? _selectedBuildingId;
  String? _purposeText;
  final _purposeController = TextEditingController();

  // Page 2
  String? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  final _carRegController = TextEditingController();

  // Data lists
  List<dynamic> _visitors = [];
  List<dynamic> _buildings = [];
  bool _isLoadingData = true;
  bool _isSaving = false;

  // Current user info
  String? _empId;
  String? _empName;
  String? _empDepartment;
  String? _empSection;
  String? _empPosition;

  @override
  void initState() {
    super.initState();
    _purposeController.addListener(_updateFormState);
    _carRegController.addListener(_updateFormState);
    _loadData();
  }

  @override
  void dispose() {
    _purposeController.removeListener(_updateFormState);
    _purposeController.dispose();
    _carRegController.removeListener(_updateFormState);
    _carRegController.dispose();
    super.dispose();
  }

  void _updateFormState() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    final prefs = await SharedPreferences.getInstance();
    _empId = prefs.getString('emp_id');
    final auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
    final headers = {'Authorization': auth, 'Content-Type': 'application/json'};

    try {
      final results = await Future.wait([
        http.get(ApiConstants.showVisitor, headers: headers),
        http.get(ApiConstants.showBuilding, headers: headers),
        http.post(ApiConstants.profile, headers: headers, body: jsonEncode({'emp_id': _empId})),
      ]);

      final visData = json.decode(results[0].body);
      final buildData = json.decode(results[1].body);
      final empData = json.decode(results[2].body);

      if (mounted) {
        setState(() {
          _visitors = visData is List ? visData : (visData['data'] ?? []);
          _buildings = buildData is List ? buildData : (buildData['data'] ?? []);
          final p = empData['data'];
          if (p != null) {
            _empName = "${p['emp_firstname']} ${p['emp_lastname']}";
            _empDepartment = p['emp_department']?.toString();
            _empSection = p['emp_section']?.toString();
            _empPosition = p['emp_position']?.toString();
          } else {
            _empName = widget.username;
          }
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print("Add booking load error: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  String _formatDate(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = _formatDate(picked));
    }
  }

  Future<void> _pickTime(bool isStart) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        initialEntryMode: TimePickerEntryMode.input, 
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary, 
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          if (isStart) _selectedStartTime = picked;
          else _selectedEndTime = picked;
        });
      }
    }

  bool _isPage1Valid() => _selectedVisitorId != null && _selectedBuildingId != null && _purposeController.text.trim().isNotEmpty;

  bool _isPage2Valid() =>
      _selectedDate != null &&
      _selectedStartTime != null &&
      _selectedEndTime != null &&
      _carRegController.text.trim().isNotEmpty;

  Future<void> _submitBooking() async {
    if (!_isPage1Valid() || !_isPage2Valid()) {
      _showSnack("กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }
    setState(() => _isSaving = true);

    try {
      // Parse date and times
      final dateParts = _selectedDate!.split('/');
      final day = dateParts[0].padLeft(2, '0');
      final month = dateParts[1].padLeft(2, '0');
      final year = dateParts[2];

      String startStr = "$year-$month-$day ${_selectedStartTime!.hour.toString().padLeft(2,'0')}:${_selectedStartTime!.minute.toString().padLeft(2,'0')}:00";
      String endStr = "$year-$month-$day ${_selectedEndTime!.hour.toString().padLeft(2,'0')}:${_selectedEndTime!.minute.toString().padLeft(2,'0')}:00";

      final auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
      final payload = {
        'vis_id': _selectedVisitorId,
        'emp_id': _empId,
        'b_id': _selectedBuildingId,
        'purpose': _purposeController.text.trim(),
        'car_registration': _carRegController.text.trim(),
        'appointment_start': startStr,
        'appointment_end': endStr,
        if (_empDepartment != null) 'emp_department': _empDepartment,
        if (_empSection != null) 'emp_section': _empSection,
        if (_empPosition != null) 'emp_position': _empPosition,
      };

      final res = await http.put(
        ApiConstants.addBooking,
        headers: {'Authorization': auth, 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          _showSnack("บันทึกการนัดหมายสำเร็จ ✅");
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.pop(context, true);
        }
      } else {
        final err = json.decode(res.body);
        _showSnack(err['message'] ?? "บันทึกไม่สำเร็จ");
      }
    } catch (e) {
      _showSnack("เกิดข้อผิดพลาด: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.prompt()),
        backgroundColor: msg.contains('สำเร็จ') ? kPrimary : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(_currentPage == 0 ? "สร้างนัดหมาย" : "รายละเอียดเพิ่มเติม",
          style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [kPrimary, kPrimaryDark]),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_currentPage == 0) Navigator.pop(context);
            else _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          },
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(
              children: [
                // Progress indicator
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      _progressStep(1, _currentPage >= 0, "ข้อมูลพื้นฐาน"),
                      Expanded(child: Divider(color: _currentPage >= 1 ? kPrimary : Colors.grey[300], thickness: 2)),
                      _progressStep(2, _currentPage >= 1, "รายละเอียด"),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [_buildPage1(), _buildPage2()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _progressStep(int step, bool active, String label) => Column(
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text("$step",
            style: GoogleFonts.prompt(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.prompt(fontSize: 10, color: active ? kPrimary : kTextSecondary)),
    ],
  );

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Visitor selector
          _sectionLabel("ชื่อผู้มาติดต่อ *"),
          _dropdownCard(
            hint: "เลือกผู้มาติดต่อ",
            icon: Icons.person_outline_rounded,
            value: _selectedVisitorId,
            items: _visitors.map((v) {
              final id = v['vis_id']?.toString() ?? '';
              final name = "${v['vis_firstname'] ?? ''} ${v['vis_lastname'] ?? ''}".trim();
              return DropdownMenuItem(value: id, child: Text(name, style: GoogleFonts.prompt(fontSize: 14)));
            }).toList(),
            onChanged: (val) => setState(() => _selectedVisitorId = val),
          ),
          const SizedBox(height: 16),

          // Employee (read-only)
          _sectionLabel("บุคคลที่กำหนดนัด"),
          _readOnlyField(Icons.badge_outlined, _empName ?? "กำลังโหลด..."),
          const SizedBox(height: 16),

          // Building
          _sectionLabel("อาคารที่นัดหมาย *"),
          _dropdownCard(
            hint: "เลือกอาคาร",
            icon: Icons.apartment_rounded,
            value: _selectedBuildingId,
            items: _buildings.map((b) {
              final id = b['b_id']?.toString() ?? '';
              final name = b['b_name']?.toString() ?? '';
              return DropdownMenuItem(value: id, child: Text(name, style: GoogleFonts.prompt(fontSize: 14)));
            }).toList(),
            onChanged: (val) => setState(() => _selectedBuildingId = val),
          ),
          const SizedBox(height: 16),

          // Purpose
          _sectionLabel("หัวข้อการนัดหมาย *"),
          _textField(Icons.notes_rounded, "กรอกหัวข้อ/วัตถุประสงค์", _purposeController),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isPage1Valid()
                  ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: Text("ถัดไป", style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Date picker
          _sectionLabel("วันที่นัดหมาย *"),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _selectedDate != null ? kPrimary : kBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 20),
                  const SizedBox(width: 12),
                  Text(_selectedDate ?? "เลือกวันที่",
                    style: GoogleFonts.prompt(
                      color: _selectedDate != null ? kTextPrimary : kTextSecondary,
                      fontSize: 15,
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time pickers
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("เวลาเริ่ม *"),
                  GestureDetector(
                    onTap: () => _pickTime(true),
                    child: _timeTile(_selectedStartTime, "เวลาเริ่ม"),
                  ),
                ],
              )),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("เวลาสิ้นสุด *"),
                  GestureDetector(
                    onTap: () => _pickTime(false),
                    child: _timeTile(_selectedEndTime, "เวลาสิ้นสุด"),
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 16),

          // Car registration
          _sectionLabel("ทะเบียนรถ *"),
          _textField(Icons.directions_car_outlined, "เช่น กข1234", _carRegController),
          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isSaving || !_isPage2Valid()) ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                  : Text("ยืนยันการนัดหมาย",
                      style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: GoogleFonts.prompt(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _dropdownCard({
    required String hint,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value != null ? kPrimary : kBorderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, color: kPrimary, size: 18),
            const SizedBox(width: 10),
            Text(hint, style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 14)),
          ]),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _readOnlyField(IconData icon, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FBFA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorderColor),
    ),
    child: Row(
      children: [
        Icon(icon, color: kPrimary, size: 20),
        const SizedBox(width: 12),
        Text(value, style: GoogleFonts.prompt(fontSize: 15, color: kTextPrimary, fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _textField(IconData icon, String hint, TextEditingController ctrl) => TextField(
    controller: ctrl,
    style: GoogleFonts.prompt(fontSize: 15, color: kTextPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.prompt(color: kTextSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: kPrimary, size: 20),
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kBorderColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  Widget _timeTile(TimeOfDay? time, String hint) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: time != null ? kPrimary : kBorderColor),
    ),
    child: Row(
      children: [
        const Icon(Icons.access_time_rounded, color: kPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          time != null ? "${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}" : hint,
          style: GoogleFonts.prompt(color: time != null ? kTextPrimary : kTextSecondary, fontSize: 14),
        ),
      ],
    ),
  );
}
