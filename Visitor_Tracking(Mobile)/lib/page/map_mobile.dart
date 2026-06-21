import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beacon_tracking/api_constants.dart';

const kPrimary = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00A877);
const kBackground = Color(0xFFF4F7F6);
const kTextPrimary = Color(0xFF0A2540);
const kTextSecondary = Color(0xFF64748B);

class MapMobilePage extends StatefulWidget {
  final String username;
  final String password;
  const MapMobilePage({super.key, required this.username, required this.password});

  @override
  State<MapMobilePage> createState() => _MapMobilePageState();
}

class _MapMobilePageState extends State<MapMobilePage> {
  final MapController _mapController = MapController();
  List<dynamic> _locationData = [];
  List<dynamic> _buildingData = [];
  bool _isLoading = true;
  bool _showList = false;
  bool _isMapReady = false;

  LatLng _mapCenter = _defaultCenter;
  double _mapZoom = 8.0;

  // Center map on Thailand
  static const LatLng _defaultCenter = LatLng(13.7563, 100.5018);

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    await Future.wait([_fetchLocationData(), _fetchBuildingData()]);
  }

  Future<void> _fetchLocationData() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
      final res = await http.get(
        ApiConstants.showlocation,
        headers: {'Authorization': auth},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data;
        if (mounted) {
          setState(() {
            _locationData = list is List ? list : [];
            _updateMapCenterFromMarkers();
          });
        }
      }
    } catch (e) {
      debugPrint("Map fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBuildingData() async {
    if (!mounted) {
      return;
    }
    try {
      setState(() => _isLoading = true);
      final auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';
      final res = await http.get(
        ApiConstants.showBuilding,
        headers: {'Authorization': auth},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data;
        if (mounted) {
          setState(() => _buildingData = list is List ? list : []);
        }
      }
    } catch (e) {
      debugPrint("Building fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IN': return kPrimary;
      default: return kTextSecondary;
    }
  }

  String _displayVisitorName(dynamic item) {
    final rawName = item['visitor_name']?.toString().trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName;
    }
    return item['vis_id']?.toString() ?? item['building_name']?.toString() ?? item['b_name']?.toString() ?? 'Unknown';
  }

  String _displayBuildingName(dynamic item) {
    return item['building_name']?.toString() ?? item['b_name']?.toString() ?? '-';
  }

  List<dynamic> get _visibleLocationData {
    return _locationData.where((item) {
      final String? timeString = item['lobc_time_in']?.toString() ??
          item['updated_at']?.toString() ??
          item['created_at']?.toString();
      if (timeString == null || timeString.isEmpty) return true;
      try {
        final parsed = DateTime.parse(timeString).toLocal();
        return DateTime.now().difference(parsed).inHours <= 24;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  void _updateMapCenterFromMarkers() {
    final points = _visibleLocationData.map((item) {
      final lat = double.tryParse(item['loc_lat']?.toString() ?? '');
      final lng = double.tryParse(item['loc_long']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }).whereType<LatLng>().toList();

    if (points.isEmpty) {
      _mapCenter = _defaultCenter;
      _mapZoom = 14.0;
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapCenter = bounds.center;
    _mapZoom = 14.0;

    if (_isMapReady) {
      _mapController.move(_mapCenter, _mapZoom);
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final item in _visibleLocationData) {
      final lat = double.tryParse(item['loc_lat']?.toString() ?? '');
      final lng = double.tryParse(item['loc_long']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final status = item['status']?.toString() ?? 'IN';
      final color = _getStatusColor(status);
      final name = _displayVisitorName(item);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showMarkerInfo(item),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: color.withAlpha((0.4 * 255).round()), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(
                  name.length > 10 ? name.substring(0, 10) + '...' : name,
                  style: GoogleFonts.prompt(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.location_pin, color: color, size: 28),
            ],
          ),
        ),
      ));
    }
    return markers;
  }

  List<CircleMarker> _buildBuildingCircles() {
    final circles = <CircleMarker>[];
    for (final item in _buildingData) {
      final lat = double.tryParse(item['b_lat']?.toString() ?? '');
      final lng = double.tryParse(item['b_long']?.toString() ?? '');
      final radius = double.tryParse(item['b_radius']?.toString() ?? '0') ?? 0;
      if (lat == null || lng == null || radius <= 0) continue;

      circles.add(CircleMarker(
        point: LatLng(lat, lng),
        radius: radius,
        useRadiusInMeter: true,
        color: Colors.blue.withAlpha((0.12 * 255).round()),
        borderColor: Colors.blue.withAlpha((0.8 * 255).round()),
        borderStrokeWidth: 2,
      ));
    }
    return circles;
  }

  List<Marker> _buildBuildingMarkers() {
    final markers = <Marker>[];
    for (final item in _buildingData) {
      final lat = double.tryParse(item['b_lat']?.toString() ?? '');
      final lng = double.tryParse(item['b_long']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 120,
        height: 48,
        child: GestureDetector(
          onTap: () => _showBuildingInfo(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimary.withAlpha((0.9 * 255).round()), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.08 * 255).round()), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment_rounded, size: 16, color: kPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item['b_name']?.toString() ?? 'อาคาร',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.prompt(fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return markers;
  }

  void _showBuildingInfo(dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [kPrimary, kPrimaryDark]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['b_name']?.toString() ?? 'อาคาร',
                      style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 16, color: kTextPrimary)),
                    const SizedBox(height: 4),
                    Text(item['b_description']?.toString() ?? item['b_address']?.toString() ?? '-',
                      style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.my_location_rounded, "พิกัด", "${item['b_lat'] ?? '-'}, ${item['b_long'] ?? '-'}"),
            _infoRow(Icons.height, "รัศมี (เมตร)", item['b_radius']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  void _showMarkerInfo(dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [kPrimary, kPrimaryDark]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['visitor_name']?.toString() ?? item['vis_id']?.toString() ?? 'Unknown',
                      style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 16, color: kTextPrimary)),
                    const SizedBox(height: 4),
                    Text(item['building_name']?.toString() ?? '-',
                      style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.my_location_rounded, "พิกัด", "${item['loc_lat'] ?? '-'}, ${item['loc_long'] ?? '-'}"),
            _infoRow(Icons.timeline, "สถานะ", item['status']?.toString().toUpperCase() ?? '-'),
            _infoRow(Icons.phone, "โทรศัพท์", item['visitor_contact']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 8),
        Text("$label: ", style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 13)),
        Expanded(child: Text(val, style: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 13, color: kTextPrimary))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
              onMapReady: () {
                if (!mounted) {
                  return;
                }
                setState(() => _isMapReady = true);
                _updateMapCenterFromMarkers();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.beacon_tracking',
              ),
              if (_buildingData.isNotEmpty) CircleLayer(circles: _buildBuildingCircles()),
              if (_buildingData.isNotEmpty) MarkerLayer(markers: _buildBuildingMarkers()),
              MarkerLayer(markers: markers),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              child: const Center(child: CircularProgressIndicator(color: kPrimary)),
            ),

          // Top stats bar
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_rounded, color: kPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text("ผู้มาติดต่อในพื้นที่: ",
                    style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 13)),
                  Text("${markers.length} คน",
                    style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary)),
                  const Spacer(),
                  // IN  legend
                  _legendDot(kPrimary, "IN"),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),

          // Bottom list panel
          if (_showList)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22, color: kTextSecondary),
                            onPressed: () => setState(() => _showList = false),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text("รายการผู้มาติดต่อ",
                            style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 15, color: kTextPrimary)),
                          const Spacer(),
                          Text("${_visibleLocationData.length} คน",
                            style: GoogleFonts.prompt(color: kTextSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _visibleLocationData.isEmpty
                          ? Center(child: Text("ไม่มีข้อมูล", style: GoogleFonts.prompt(color: kTextSecondary)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _visibleLocationData.length,
                              itemBuilder: (ctx, i) {
                                final item = _visibleLocationData[i];
                                final status = item['status']?.toString() ?? '';
                                final color = _getStatusColor(status);
                                final lat = double.tryParse(item['loc_lat']?.toString() ?? '');
                                final lng = double.tryParse(item['loc_long']?.toString() ?? '');
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withAlpha((0.1 * 255).round()),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.person_rounded, color: color, size: 18),
                                  ),
                      title: Text(_displayVisitorName(item),
                                    style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 13, color: kTextPrimary)),
                                  subtitle: Text(_displayBuildingName(item),
                                    style: GoogleFonts.prompt(fontSize: 11.5, color: kTextSecondary)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha((0.1 * 255).round()),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status, style: GoogleFonts.prompt(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                  onTap: lat != null && lng != null
                                      ? () {
                                          _mapController.move(LatLng(lat, lng), 16);
                                          setState(() => _showList = false);
                                        }
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

          // Toggle list button
          Positioned(
            bottom: _showList ? 320 : 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'list',
              backgroundColor: Colors.white,
              onPressed: () => setState(() => _showList = !_showList),
              child: Icon(_showList ? Icons.map_rounded : Icons.list_rounded, color: kTextPrimary),
            ),
          ),

          // Refresh button
          Positioned(
            bottom: _showList ? 380 : 150,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh',
              backgroundColor: kPrimary,
              onPressed: _loadMapData,
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.prompt(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
    ],
  );
}
