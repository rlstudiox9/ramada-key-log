import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'network_exception_stub.dart'
    if (dart.library.io) 'network_exception_io.dart' as network_errors;

import '../models/auth_session.dart';
import '../models/key_issuance.dart';
import '../models/staff_roster_member.dart';

const _signInConnectionError =
    'Could not reach the sign-in service. Check your connection or start the local backend server.';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API request failed ($statusCode): $message';
}

class DailyKeyLogReport {
  final String reportDate;
  final String generatedAt;
  final String csvContent;

  const DailyKeyLogReport({
    required this.reportDate,
    required this.generatedAt,
    required this.csvContent,
  });

  factory DailyKeyLogReport.fromJson(Map<String, dynamic> json) =>
      DailyKeyLogReport(
        reportDate: json['report_date'] as String,
        generatedAt: json['generated_at'] as String,
        csvContent: json['csv_content'] as String,
      );
}

class ApiService {
  ApiService({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ??
            Uri.parse(const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://ramada-key-log.onrender.com',
            ));

  final http.Client _client;
  final Uri _baseUri;
  String? accessToken;

  Map<String, String> get _authHeaders =>
      accessToken == null ? const {} : {'authorization': 'Bearer $accessToken'};

  Future<bool> wakeBackend() async {
    try {
      final response = await _client
          .get(_baseUri.resolve('/health'))
          .timeout(const Duration(seconds: 60));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _authPost(
      _baseUri.resolve('/auth/login'),
      {'username': username, 'password': password},
      retryTransientFailures: true,
    );
    _checkResponse(response, expectedStatusCode: 200);
    return AuthSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<AuthSession> signUp({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final response = await _authPost(
      _baseUri.resolve('/auth/signup'),
      {
        'username': username,
        'display_name': displayName,
        'password': password,
      },
    );
    _checkResponse(response, expectedStatusCode: 201);
    return AuthSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<AuthUser> getCurrentUser({required String token}) async {
    final response = await _client.get(
      _baseUri.resolve('/auth/me'),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
    return AuthUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<void> logout({required String token}) async {
    final response = await _client.post(
      _baseUri.resolve('/auth/logout'),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> requestPasswordReset({required String username}) async {
    final response = await _client.post(
      _baseUri.resolve('/auth/forgot-password'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/auth/me/password'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<List<PasswordResetRequestItem>> getPasswordResetRequests({
    required String token,
  }) async {
    final response = await _client.get(
      _baseUri.resolve('/auth/admin/password-reset-requests'),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Expected password reset requests to be a list.',
      );
    }
    return [
      for (final item in decoded)
        PasswordResetRequestItem.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
    ];
  }

  Future<int> getInventoryLimit({required String token}) async {
    final response = await _client.get(
      _baseUri.resolve('/inventory'),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['total_inventory'] is! num) {
      throw const FormatException(
        'Expected the /inventory response to contain a numeric total_inventory.',
      );
    }
    final totalInventory = (decoded['total_inventory'] as num).toInt();
    if (totalInventory < 0) {
      throw const FormatException(
        'Expected the /inventory total_inventory to be non-negative.',
      );
    }
    return totalInventory;
  }

  Future<void> updateInventoryLimit({
    required int totalInventory,
    required String token,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/admin/inventory'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({'total_inventory': totalInventory}),
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['total_inventory'] != totalInventory) {
      throw const FormatException(
        'Expected the /admin/inventory response to confirm the saved total_inventory.',
      );
    }
  }

  Future<void> resetReceptionPassword({
    required int userId,
    required String password,
    required String token,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/auth/admin/users/$userId/password'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<List<KeyIssuanceItem>> getLogs() async {
    final response = await _client.get(
      _baseUri.resolve('/logs'),
      headers: _authHeaders,
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Expected the /logs response to be a list.');
    }

    return [
      for (var index = 0; index < decoded.length; index++)
        _itemFromApi(
          Map<String, dynamic>.from(decoded[index] as Map),
          sNo: decoded.length - index,
        ),
    ];
  }

  Future<DailyKeyLogReport?> getLatestDailyReport() async {
    final response = await _client.get(
      _baseUri.resolve('/reports/daily/latest'),
      headers: _authHeaders,
    );
    if (response.statusCode == 404) return null;
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || !decoded.containsKey('report')) {
      throw const FormatException(
        'Expected the latest daily report response to contain report.',
      );
    }
    final report = decoded['report'];
    if (report == null) return null;
    if (report is! Map) {
      throw const FormatException('Expected the daily report to be an object.');
    }
    return DailyKeyLogReport.fromJson(Map<String, dynamic>.from(report));
  }

  Future<int> carryForwardLogs({
    required String shiftDate,
    required String shiftPeriod,
    required String issuedDateTime,
    required String staffName,
    required String token,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/logs/carry-forward'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'shift_date': shiftDate,
        'shift_period': shiftPeriod,
        'issued_date': issuedDateTime,
        'staff_name': staffName,
      }),
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['carried_count'] is! num) {
      throw const FormatException(
        'Expected carry-forward response to contain numeric carried_count.',
      );
    }
    return (decoded['carried_count'] as num).toInt();
  }

  Future<List<StaffRosterMember>> getStaffRoster({
    required String token,
    bool includeInactive = false,
  }) async {
    final response = await _client.get(
      _baseUri.resolve(
        '/staff-roster${includeInactive ? '?include_inactive=true' : ''}',
      ),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Expected the staff roster to be a list.');
    }
    return [
      for (final item in decoded)
        StaffRosterMember.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<String?> getStaffShiftAssignment({
    required String shiftDate,
    required String token,
  }) async {
    final response = await _client.get(
      _baseUri.resolve('/staff/shift-assignment').replace(
        queryParameters: {'shift_date': shiftDate},
      ),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404) return null;
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map ||
        (decoded['shift_period'] != null &&
            decoded['shift_period'] is! String)) {
      throw const FormatException(
        'Expected shift assignment response to contain a shift period or null.',
      );
    }
    return decoded['shift_period'] as String?;
  }

  Future<bool> setStaffShiftAssignment({
    required String shiftDate,
    required String shiftPeriod,
    required String token,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/staff/shift-assignment'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'shift_date': shiftDate,
        'shift_period': shiftPeriod,
      }),
    );
    if (response.statusCode == 404) return false;
    _checkResponse(response, expectedStatusCode: 200);
    return true;
  }

  Future<StaffRosterMember> addStaffRosterMember({
    required String name,
    required String hours,
    required String token,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/admin/staff-roster'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name, 'hours': hours}),
    );
    _checkResponse(response, expectedStatusCode: 201);
    return StaffRosterMember.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<StaffRosterMember> updateStaffRosterMember({
    required StaffRosterMember member,
    required String name,
    required String hours,
    required bool isActive,
    required String token,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/admin/staff-roster/${member.id}'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'hours': hours,
        'is_active': isActive,
      }),
    );
    _checkResponse(response, expectedStatusCode: 200);
    return StaffRosterMember.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<void> deleteStaffRosterMember({
    required int staffId,
    required String token,
  }) async {
    final response = await _client.delete(
      _baseUri.resolve('/admin/staff-roster/$staffId'),
      headers: {'authorization': 'Bearer $token'},
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<KeyIssuanceItem> createLog(KeyIssuanceItem item) async {
    final response = await _client.post(
      _baseUri.resolve('/logs'),
      headers: {'content-type': 'application/json', ..._authHeaders},
      body: jsonEncode(_toApiPayload(item)),
    );
    _checkResponse(response, expectedStatusCode: 200);
    return _itemFromApi(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      sNo: item.sNo,
    );
  }

  Future<void> updateLog(KeyIssuanceItem item) async {
    final response = await _client.put(
      _baseUri.resolve('/logs/${Uri.encodeComponent(item.id)}'),
      headers: {'content-type': 'application/json', ..._authHeaders},
      body: jsonEncode(_toApiPayload(item)),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> correctLog(
    KeyIssuanceItem item, {
    required String accessToken,
  }) async {
    final response = await _client.put(
      _baseUri.resolve(
        '/logs/${Uri.encodeComponent(item.id)}/correction',
      ),
      headers: {
        'content-type': 'application/json',
        'authorization': '******',
      },
      body: jsonEncode({
        'staff_name': item.issuingStaff,
        'room_no': item.roomOrAccess,
        'guest_or_holder_name': item.guestOrHolderName,
        'qty_issue': item.qtyIssued,
        'remarks': item.remarks,
      }),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> deleteLog(
    String id, {
    required String accessToken,
  }) async {
    final response = await _client.delete(
      _baseUri.resolve('/logs/${Uri.encodeComponent(id)}'),
      headers: {'authorization': '******'},
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<String> adminLogin(String pin) async {
    final response = await _client.post(
      _baseUri.resolve('/admin/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    );
    _checkResponse(response, expectedStatusCode: 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['access_token'] is! String) {
      throw const FormatException(
        'Expected the /admin/login response to contain an access token.',
      );
    }
    return decoded['access_token'] as String;
  }

  Future<void> adminUpdateLog(
    KeyIssuanceItem item, {
    required String accessToken,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/admin/logs/${Uri.encodeComponent(item.id)}'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(_toApiPayload(item)),
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> adminDeleteLog(
    String id, {
    required String accessToken,
  }) async {
    final response = await _client.delete(
      _baseUri.resolve('/admin/logs/${Uri.encodeComponent(id)}'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  Future<void> adminLogout({required String accessToken}) async {
    final response = await _client.post(
      _baseUri.resolve('/admin/logout'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    _checkResponse(response, expectedStatusCode: 200);
  }

  static Map<String, dynamic> _toApiPayload(KeyIssuanceItem item) => {
        'issued_date': item.issuedDateTime,
        'check_out_date': item.checkOutDate,
        'staff_name': item.issuingStaff,
        'room_no': item.roomOrAccess,
        'qty_issue': item.qtyIssued,
        'qty_return': item.qtyReturned,
        'status': item.isMissing
            ? 'MISSING'
            : item.isFullyReturned
                ? 'RETURNED'
                : 'PENDING',
        'returned_time': item.returnedDateTime ?? '',
        'received_by': item.keyReceivedBy ?? '',
        'remarks': item.remarks,
        'guest_or_holder_name': item.guestOrHolderName,
        'shift_date': item.shiftDate,
        'shift_period': item.shiftPeriod,
        'category': item.category,
        'is_missing': item.isMissing,
        'missing_qty': item.missingQty,
        'is_carried_forward': item.isCarriedForward,
        'original_shift_date': item.originalShiftDate,
        'carried_from_id': item.carriedFromId,
      };

  static KeyIssuanceItem _itemFromApi(
    Map<String, dynamic> data, {
    required int sNo,
  }) {
    final issueDate = data['issued_date']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(issueDate) ??
        DateFormat('dd-MMM-yyyy hh:mm a').tryParse(issueDate);
    final shiftDate = data['shift_date']?.toString();
    final status = data['status']?.toString().toUpperCase();
    final isMissing =
        _asBool(data['is_missing']) || status == 'MISSING' || status == 'LOST';
    final shiftPeriod = data['shift_period']?.toString();

    return KeyIssuanceItem(
      id: data['id'].toString(),
      sNo: sNo,
      shiftDate: shiftDate == null || shiftDate.isEmpty
          ? DateFormat('yyyy-MM-dd').format(
              parsedDate ?? DateTime.now(),
            )
          : shiftDate,
      shiftPeriod: shiftPeriod?.isNotEmpty == true
          ? shiftPeriod!
          : _shiftFromDate(parsedDate),
      issuedDateTime: issueDate,
      checkOutDate: _asNullableString(data['check_out_date']),
      issuingStaff: data['staff_name']?.toString() ?? '',
      roomOrAccess: data['room_no']?.toString() ?? '',
      guestOrHolderName: data['guest_or_holder_name']?.toString() ?? '',
      qtyIssued: _asInt(data['qty_issue'], fallback: 1),
      qtyReturned: _asInt(data['qty_return']),
      isMissing: isMissing,
      missingQty: _asInt(data['missing_qty']),
      returnedDateTime: _asNullableString(data['returned_time']),
      keyReceivedBy: _asNullableString(data['received_by']),
      remarks: data['remarks']?.toString() ?? '',
      isCarriedForward: _asBool(data['is_carried_forward']),
      originalShiftDate: _asNullableString(data['original_shift_date']),
      carriedFromId: _asNullableString(data['carried_from_id']),
      category: data['category']?.toString() ?? 'Guest Key Card',
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static bool _asBool(dynamic value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true';

  static String _shiftFromDate(DateTime? issuedAt) {
    if (issuedAt == null) return 'All Shifts';
    if (issuedAt.hour < 9) return 'Night (00:00 - 09:00)';
    if (issuedAt.hour < 15) return 'Morning (08:00 - 17:00)';
    if (issuedAt.hour < 18) return 'Afternoon (15:00 - 00:00)';
    return 'Swing/Evening (18:00 - 03:00)';
  }

  static String? _asNullableString(dynamic value) {
    final stringValue = value?.toString();
    return stringValue == null || stringValue.isEmpty ? null : stringValue;
  }

  Future<http.Response> _authPost(Uri uri, Map<String, String> body,
      {bool retryTransientFailures = false}) async {
    const retryDelays = [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ];
    var attempt = 0;
    while (true) {
      try {
        final response = await _client
            .post(
              uri,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 35));
        if (retryTransientFailures &&
            response.statusCode >= 500 &&
            attempt < retryDelays.length) {
          await Future<void>.delayed(retryDelays[attempt++]);
          continue;
        }
        return response;
      } on TimeoutException {
        if (retryTransientFailures && attempt < retryDelays.length) {
          await Future<void>.delayed(retryDelays[attempt++]);
          continue;
        }
        throw const ApiException(0, _signInConnectionError);
      } on http.ClientException {
        if (retryTransientFailures && attempt < retryDelays.length) {
          await Future<void>.delayed(retryDelays[attempt++]);
          continue;
        }
        throw const ApiException(0, _signInConnectionError);
      } catch (error) {
        if (network_errors.isSocketException(error)) {
          if (retryTransientFailures && attempt < retryDelays.length) {
            await Future<void>.delayed(retryDelays[attempt++]);
            continue;
          }
          throw const ApiException(0, _signInConnectionError);
        }
        rethrow;
      }
    }
  }

  static void _checkResponse(
    http.Response response, {
    required int expectedStatusCode,
  }) {
    if (response.statusCode == expectedStatusCode) return;

    var message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } on FormatException {
      // Keep the response body as the error detail when it is not JSON.
    }
    throw ApiException(response.statusCode, message);
  }
}
