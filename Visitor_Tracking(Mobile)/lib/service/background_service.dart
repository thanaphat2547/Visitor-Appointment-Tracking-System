import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:beacon_tracking/api_constants.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background task executed: $task");
    
    final prefs = await SharedPreferences.getInstance();
    final roleId = prefs.getString('role_id');
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    
    if (username == null || password == null) return Future.value(true);
    
    try {
      // Fetch today's bookings
      String url = ApiConstants.showBooking.toString();
      if (roleId == '1') {
        final empId = prefs.getString('emp_id');
        url += "?emp_id=$empId&role_id=1";
      } else if (roleId == '2') {
        final bkId = prefs.getString('bk_id');
        url += "?bk_id=$bkId&role_id=2";
      }
      
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      final response = await http.get(Uri.parse(url), headers: {'Authorization': auth});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data["data"] ?? [];
        
        final now = DateTime.now();
        final today = DateFormat('yyyy-MM-dd').format(now);
        
        // Find bookings that are coming up in the next 45 minutes or currently happening
        bool shouldScan = false;
        
        for (var b in list) {
          final startStr = b['appointment_start']?.toString() ?? '';
          if (startStr.startsWith(today)) {
            final startTime = DateTime.parse(startStr).toLocal();
            final difference = startTime.difference(now).inMinutes;
            
            // If appointment is within -30 to 45 mins
            if (difference >= -30 && difference <= 45) {
              shouldScan = true;
              break;
            }
          }
        }
        
        // If should scan, trigger BLE scan
        if (shouldScan) {
          print("Background task: Starting BLE scan");
          // Check permissions briefly (background tasks might not be able to request, but assume granted)
          
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
          
          FlutterBluePlus.scanResults.listen((results) async {
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
              if (bcUuid != null && r.rssi > -95) {
                // Calculate and save location
                final res = await http.post(ApiConstants.calculate,
                    headers: {"Content-Type": "application/json"},
                    body: json.encode({"bc_uuid": bcUuid, "lat": pos.latitude, "long": pos.longitude}));
                
                if (res.statusCode == 200) {
                  final inside = json.decode(res.body)['data']?['inside_radius'] ?? false;
                  if (inside) {
                    final userId = prefs.getString('emp_id') ?? prefs.getString('vis_id') ?? username;
                    await http.put(ApiConstants.savelocation,
                        headers: {"Content-Type": "application/json"},
                        body: json.encode({"bc_uuid": bcUuid, "loc_lat": pos.latitude, "loc_long": pos.longitude, "status": "IN", "vis_id": userId}));
                    FlutterBluePlus.stopScan(); // Stop scan once found and synced
                  }
                }
              }
            }
          });
          
          await Future.delayed(const Duration(seconds: 16)); // Wait for scan to finish
        }
      }
    } catch (e) {
      print("Background task error: $e");
    }
    
    return Future.value(true);
  });
}

class BackgroundService {
  static void initialize() {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static void registerPeriodicTask() {
    Workmanager().registerPeriodicTask(
      "beacon_tracking_task",
      "beacon_tracking",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
