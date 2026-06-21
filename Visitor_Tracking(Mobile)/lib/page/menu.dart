import 'package:beacon_tracking/page/add_booking.dart';
import 'package:beacon_tracking/page/map_mobile.dart';
import 'package:beacon_tracking/service/notification_service.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:beacon_tracking/page/profile.dart';
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:beacon_tracking/page/notification.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:beacon_tracking/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kVisitorColor = Color(0xFF00C896);
const kBackground = Color(0xFFF4F7F6);
const kSurface = Colors.white;
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);
const kBorderColor = Color(0xFFE8F5F1);

class Menu extends StatefulWidget {
  final String username;
  final String password;
  const Menu({super.key, required this.username, required this.password});
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final NotificationService _notificationService;
  int _unreadCount = 0;
  int _currentIndex = 0;
  String? _roleId;

  List<dynamic> _allBookings = [];
  bool _isLoading = true;

  final List<String> _insideBeacons = [];
  final Map<String, DateTime> _beaconLastSeen = {};
  final _lastCalculateTime = <String, DateTime>{};
  Timer? _beaconTimeoutTimer;
  static const int _beaconTimeoutSeconds = 20;
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  // Officer tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationService = NotificationService();
    _notificationService.addListener(_onNotificationUpdate);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() {
        _roleId = prefs.getString('role_id');
        _unreadCount = _notificationService.unreadCount;
      });
      await _fetchMyBookings();
      _startScan();
      _startBeaconTimeoutTimer();
    });
  }

  void _onNotificationUpdate() {
    if (mounted) setState(() => _unreadCount = _notificationService.unreadCount);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationService.removeListener(_onNotificationUpdate);
    WidgetsBinding.instance.removeObserver(this);
    _scanSubscription?.cancel();
    _beaconTimeoutTimer?.cancel();
    super.dispose();
  }

  bool get _isVisitor => _roleId == '2';
  Color get _themeColor => _isVisitor ? kVisitorColor : kPrimary;
  Color get _themeColorDark => _isVisitor ? kPrimaryDark : kPrimaryDark;

  // ---------- Navigation ----------
  List<Widget> _getPages() {
    if (_isVisitor) {
      return [
        _visitorHomeBody(),
        const NotificationPage(),
        Profile(username: widget.username, password: widget.password),
      ];
    }
    return [
      _officerHomeBody(),
      MapMobilePage(username: widget.username, password: widget.password),
      const NotificationPage(),
      Profile(username: widget.username, password: widget.password),
    ];
  }

  List<BottomNavigationBarItem> _getNavItems() {
    final notificationIcon = Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (_unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );

    if (_isVisitor) {
      return [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'หน้าแรก'),
        BottomNavigationBarItem(icon: notificationIcon, activeIcon: const Icon(Icons.notifications_rounded), label: 'แจ้งเตือน'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'โปรไฟล์'),
      ];
    }
    return [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'หน้าแรก'),
      const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map_rounded), label: 'แผนที่'),
      BottomNavigationBarItem(icon: notificationIcon, activeIcon: const Icon(Icons.notifications_rounded), label: 'แจ้งเตือน'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'โปรไฟล์'),
    ];
  }

  String _getPageTitle() {
    if (_isVisitor) {
      switch (_currentIndex) {
        case 0: return "รายการนัดหมาย";
        case 1: return "การแจ้งเตือน";
        default: return "โปรไฟล์";
      }
    }
    switch (_currentIndex) {
      case 0: return "รายการนัดหมาย";
      case 1: return "แผนที่ติดตาม";
      case 2: return "การแจ้งเตือน";
      default: return "โปรไฟล์";
    }
  }

  // ---------- Data ----------
  Future<void> _fetchMyBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getString('role_id');
      String url = ApiConstants.showBooking.toString();
      if (roleId == '1') {
        final empId = prefs.getString('emp_id');
        url += "?emp_id=$empId&role_id=1";
      } else if (roleId == '2') {
        final bkId = prefs.getString('bk_id');
        url += "?bk_id=$bkId&role_id=2";
      }
      final auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
      final response = await http.get(Uri.parse(url), headers: {'Authorization': auth});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data["data"] ?? [];
        if (mounted) setState(() => _allBookings = list);
        // Schedule advance reminders
        await _notificationService.scheduleAppointmentReminders(list);
      }
    } catch (e) { print("Error fetching bookings: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  // ---------- Beacon ----------
  Future<void> _startScan() async {
    if (!mounted || _isScanning) return;
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('emp_id') ?? prefs.getString('vis_id');
    if (userId == null) return;
    setState(() => _isScanning = true);
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      if (_roleId != '2') return;
      for (ScanResult r in results) {
        String? bcUuid;
        for (var entry in r.advertisementData.manufacturerData.entries) {
          final bytes = entry.value;
          if (bytes.length >= 23) {
            final uuidBytes = bytes.sublist(2, 18);
            final hex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            bcUuid = "${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}";
          }
        }
        if (bcUuid == null || r.rssi <= -100) continue;
        final now = DateTime.now();
        final last = _lastCalculateTime[bcUuid];
        if (last != null && now.difference(last).inSeconds < 15) continue;
        _lastCalculateTime[bcUuid] = now;
        final pos = await Geolocator.getCurrentPosition();
        final inside = await _callCalculate(bcUuid, pos.latitude, pos.longitude);

        if (inside || _insideBeacons.contains(bcUuid)) {
          _beaconLastSeen[bcUuid] = now;
        }

        if (inside && !_insideBeacons.contains(bcUuid)) {
          _insideBeacons.add(bcUuid);
          await _saveBeaconLocation(bcUuid, pos.latitude, pos.longitude, status: "IN");
          Future.delayed(const Duration(seconds: 1), _fetchMyBookings);
        } else if (!inside && _insideBeacons.contains(bcUuid)) {
          await _saveBeaconLocation(bcUuid, pos.latitude, pos.longitude, status: "OUT");
          _insideBeacons.remove(bcUuid);
          _beaconLastSeen.remove(bcUuid);
          Future.delayed(const Duration(seconds: 1), _fetchMyBookings);
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: const Duration(minutes: 5), androidUsesFineLocation: true);
  }

  Future<bool> _callCalculate(String uuid, double lat, double lng) async {
    try {
      final res = await http.post(ApiConstants.calculate,
          headers: {"Content-Type": "application/json"},
          body: json.encode({"bc_uuid": uuid, "lat": lat, "long": lng}));
      if (res.statusCode == 200) return json.decode(res.body)['data']?['inside_radius'] ?? false;
    } catch (_) {}
    return false;
  }

  Future<void> _saveBeaconLocation(String uuid, double lat, double lng, {required String status}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final visId = prefs.getString('vis_id'); 
    
    if (visId == null) return;

    await http.put(ApiConstants.savelocation,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "bc_uuid": uuid,
          "loc_lat": lat,
          "loc_long": lng,
          "status": status,
          "vis_id": visId
        }));
  } catch (_) {}
}

  void _startBeaconTimeoutTimer() {
    _beaconTimeoutTimer?.cancel();
    _beaconTimeoutTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (_insideBeacons.isEmpty) return;
      final now = DateTime.now();
      final expiredBeacons = _insideBeacons.where((bcUuid) {
        final lastSeen = _beaconLastSeen[bcUuid];
        return lastSeen == null || now.difference(lastSeen).inSeconds > _beaconTimeoutSeconds;
      }).toList();

      if (expiredBeacons.isEmpty) return;

      for (final bcUuid in expiredBeacons) {
        try {
          final pos = await Geolocator.getCurrentPosition();
          await _saveBeaconLocation(bcUuid, pos.latitude, pos.longitude, status: "OUT");
        } catch (_) {
          await _saveBeaconLocation(bcUuid, 0.0, 0.0, status: "OUT");
        }
        _insideBeacons.remove(bcUuid);
        _beaconLastSeen.remove(bcUuid);
      }

      if (mounted) Future.delayed(const Duration(seconds: 1), _fetchMyBookings);
    });
  }

  // ---------- Helpers ----------
  String _formatDateTime(String? s) {
    if (s == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(s).toLocal());
  }

  Color _statusColor(String s) {
    switch (s) {
      case '0': return const Color(0xFF3B82F6);
      case '1': return kPrimary;
      case '2': return const Color(0xFF0891B2);
      case '3': return const Color(0xFFF59E0B);
      case '4': return const Color(0xFFEF4444);
      default: return kTextSecondary;
    }
  }

  String _statusText(String s) {
    const m = {'0':'รอดำเนินการ','1':'มาถึงแล้ว','2':'เสร็จสิ้น','3':'เกินกำหนดนัด','4':'ยกเลิก'};
    return m[s] ?? 'ไม่ทราบ';
  }

  List<dynamic> get _todayBookings {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _allBookings.where((b) {
      final start = b['appointment_start']?.toString() ?? '';
      return start.startsWith(today);
    }).toList();
  }

  List<dynamic> get _historyBookings => _allBookings;

  // ---------- Google Maps Launch ----------
  Future<void> _openGoogleMaps(dynamic item) async {
    final buildingName = item['building_name']?.toString() ?? '';
    final lat = double.tryParse(item['b_lat']?.toString() ?? '');
    final lng = double.tryParse(item['b_long']?.toString() ?? '');

    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    } else if (buildingName.isNotEmpty) {
      final encoded = Uri.encodeComponent(buildingName);
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ไม่มีข้อมูลตำแหน่ง", style: GoogleFonts.prompt()),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16)));
      return;
    }
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------- Detail Modal ----------
  void _showDetail(dynamic item) {
    final status = item['bk_status'].toString();
    final color = _statusColor(status);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 4), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20,12,20,0), child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [_themeColor, _themeColorDark]), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Text("รายละเอียดนัดหมาย", style: GoogleFonts.prompt(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: kTextSecondary))),
          ])),
          Divider(height: 16, color: kBorderColor),
          Padding(padding: const EdgeInsets.fromLTRB(20,0,20,0), child: Column(children: [
            if (_isVisitor) ...[
              _detailRow(Icons.person_outline_rounded, "ผู้ติดต่อ (Officer)", item['employee_name']),
              _detailRow(Icons.phone_rounded, "เบอร์โทร Officer", item['employee_phone']),
            ] else ...[
              _detailRow(Icons.person_outline_rounded, "ผู้มาติดต่อ", item['visitor_name']),
              _detailRow(Icons.phone_rounded, "เบอร์โทรติดต่อ", item['vis_phone']),
            ],
            _detailRow(Icons.badge_outlined, "รหัส Booking", item['bk_id'], highlight: true),
            _detailRow(Icons.access_time_rounded, "วันเวลานัด", "${_formatDateTime(item['appointment_start'])} น."),
            _detailRow(Icons.apartment_rounded, "อาคาร", item['building_name']),
            _detailRow(Icons.directions_car_rounded, "ทะเบียนรถ", item['car_registration']),
            _detailRow(Icons.notes_rounded, "วัตถุประสงค์", item['purpose']),
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
              child: Row(children: [
                Text("สถานะ: ", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 13.5)),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_statusText(status), style: GoogleFonts.prompt(color: color, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ])),
            const SizedBox(height: 16),
            // Navigate button for visitor
            if (_isVisitor)
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _openGoogleMaps(item); },
                icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                label: Text("นำทางไปยังสถานที่", style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kVisitorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
              )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(backgroundColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text("ปิด", style: GoogleFonts.prompt(color: kTextSecondary, fontWeight: FontWeight.w600)))),
          ])),
          SafeArea(child: const SizedBox(height: 16)),
        ])),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String? val, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 17, color: _themeColor),
      const SizedBox(width: 10),
      Text("$label: ", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 13.5)),
      Expanded(child: Text(val ?? "-", textAlign: TextAlign.right,
        style: GoogleFonts.prompt(fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13.5, color: highlight ? _themeColor : kTextPrimary))),
    ]),
  );

  // ---------- Booking Card ----------
  Widget _bookingCard(dynamic item) {
    final status = item['bk_status'].toString();
    final color = _statusColor(status);
    return GestureDetector(
      onTap: () => _showDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item['visitor_name'] ?? item['vis_id'] ?? item['bk_id'] ?? '-',
              style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 15, color: kTextPrimary))),
            if (_isVisitor)
              GestureDetector(
                onTap: () => _openGoogleMaps(item),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kVisitorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.navigation_rounded, color: kVisitorColor, size: 18)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 20),
          ]),
          const SizedBox(height: 8),
          Divider(height: 1, color: kBorderColor),
          const SizedBox(height: 8),
          _infoRow(Icons.apartment_rounded, "อาคาร", item['building_name']),
          _infoRow(Icons.access_time_rounded, "เวลานัด", "${_formatDateTime(item['appointment_start'])} น."),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(_statusText(status), style: GoogleFonts.prompt(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ])),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 15, color: _themeColor),
      const SizedBox(width: 8),
      Text("$label: ", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12.5)),
      Expanded(child: Text(val ?? "-", style: GoogleFonts.prompt(fontWeight: FontWeight.w500, fontSize: 12.5, color: kTextPrimary))),
    ]),
  );

  Widget _emptyState(String text) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80,
      decoration: BoxDecoration(color: const Color(0xFFE8F5F1), borderRadius: BorderRadius.circular(20)),
      child: Icon(Icons.calendar_today_outlined, size: 40, color: _themeColor)),
    const SizedBox(height: 14),
    Text(text, style: GoogleFonts.prompt(fontSize: 15, color: kTextSecondary, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    Text("ดึงข้อมูลลงมาเพื่อรีเฟรช", style: GoogleFonts.prompt(fontSize: 12.5, color: Colors.grey[400])),
  ]));

  Widget _listView(List<dynamic> items) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _themeColor));
    if (items.isEmpty) return _emptyState("ไม่มีรายการนัดหมาย");
    return RefreshIndicator(
      onRefresh: _fetchMyBookings,
      color: _themeColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: items.length,
        itemBuilder: (_, i) => _bookingCard(items[i]),
      ),
    );
  }

  // ---------- Officer Home ----------
  Widget _officerHomeBody() {
    return Column(children: [
      // Role indicator bar
      Container(
        color: kPrimary.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.badge_outlined, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text("OFFICER", style: GoogleFonts.prompt(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ])),
          const Spacer(),
          Text("${_allBookings.length} รายการทั้งหมด", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12)),
        ]),
      ),
      // TabBar
      Container(
        color: kSurface,
        child: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.prompt(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            Tab(text: "วันนี้ (${_todayBookings.length})"),
            Tab(text: "ทั้งหมด (${_historyBookings.length})"),
          ],
        ),
      ),
      Expanded(child: Stack(children: [
        TabBarView(
          controller: _tabController,
          children: [
            _listView(_todayBookings),
            _listView(_historyBookings),
          ],
        ),
        // FAB add booking
        Positioned(
          bottom: 90, right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddBookingPage(username: widget.username, password: widget.password)));
              if (result == true) _fetchMyBookings();
            },
            backgroundColor: kPrimary,
            elevation: 4,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ])),
    ]);
  }

  // ---------- Visitor Home ----------
  Widget _visitorHomeBody() {
    return Column(children: [
      // Role indicator bar
      Container(
        color: kVisitorColor.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: kVisitorColor, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_outlined, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text("VISITOR", style: GoogleFonts.prompt(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ])),
          const Spacer(),
          Text("${_allBookings.length} การนัดหมาย", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12)),
        ]),
      ),
      Expanded(child: _listView(_allBookings)),
    ]);
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    if (_currentIndex >= pages.length) _currentIndex = 0;
    return Scaffold(
      extendBody: true,
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(_getPageTitle(), style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_themeColor, _themeColorDark], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          if (_currentIndex == 0)
            IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _fetchMyBookings),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: _themeColor,
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedLabelStyle: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w500),
            elevation: 0,
            items: _getNavItems(),
          ),
        ),
      ),
    );
  }
}