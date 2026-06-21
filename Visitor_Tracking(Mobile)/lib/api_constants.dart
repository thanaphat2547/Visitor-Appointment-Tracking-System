class ApiConstants {
  static const String baseUrl = "http://192.168.1.33:3001";

  static Uri get showBooking => Uri.parse("$baseUrl/booking/show_booking");
  static Uri get visitorLogin => Uri.parse("$baseUrl/booking/visitor_login");
  static Uri get addBooking => Uri.parse("$baseUrl/booking/add_booking");
  static Uri get showVisitor => Uri.parse("$baseUrl/visitor/show_visitor");
  static Uri get showEmployee => Uri.parse("$baseUrl/employee/show_employee");
  static Uri get showBuilding => Uri.parse("$baseUrl/building/show_building");

  static Uri get login => Uri.parse("$baseUrl/employee/login");
  static Uri get checkBeacon => Uri.parse("$baseUrl/checkbeacon");
  static Uri get calculate => Uri.parse("$baseUrl/location_beacon/Calculate");   
  static Uri get profile => Uri.parse("$baseUrl/employee/profile");

  static Uri get addBeaconLocation => Uri.parse("$baseUrl/location_beacon/add_location_beacon");
  static Uri get getBuilding => Uri.parse("$baseUrl/company/getbuilding");
  static Uri get showlocationbeacon => Uri.parse("$baseUrl/location_beacon/show_location_beacon");
  static Uri BeaconLog(String bc_id) => Uri.parse("$baseUrl/location_beacon/show_location_beacon?bc_id=$bc_id");
  static Uri get showBeacon => Uri.parse("$baseUrl/beacon/show_beacon");
  static Uri get savelocation => Uri.parse("$baseUrl/location_beacon/put");
  static Uri get showlocation => Uri.parse("$baseUrl/location_beacon/show_location_beacon");
  static Uri get savetoken => Uri.parse("$baseUrl/notification/save-fcm-token");
  static Uri get filteremployee => Uri.parse("$baseUrl/beacon/filteremployee");
  static Uri get filterhistory => Uri.parse("$baseUrl/beacon_history/condition");

  static Uri shownotificationHistory({String? userId}) {
    final params = userId != null ? {'user_id': userId} : <String, String>{};
    return Uri.parse("$baseUrl/notification/history").replace(queryParameters: params);
  }
  static Uri get clearNotification => Uri.parse("$baseUrl/notification/clear");
}