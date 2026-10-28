import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ramada_key_log/models/key_issuance.dart';
import 'package:ramada_key_log/services/api_service.dart';

void main() {
  group('ApiService', () {
    test('loads and manages authenticated dynamic staff roster', () async {
      final requests = <http.Request>[];
      final service = ApiService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' && request.url.path == '/staff-roster') {
            return http.Response(
              '[{"id":1,"name":"Jonayed","hours":"08:00 - 17:00","is_active":true}]',
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/admin/staff-roster') {
            return http.Response(
              '{"id":7,"name":"New Staff","hours":"09:00 - 18:00","is_active":true}',
              201,
            );
          }
          if (request.method == 'PUT' &&
              request.url.path == '/admin/staff-roster/7') {
            return http.Response(
              '{"id":7,"name":"New Staff","hours":"09:00 - 18:00","is_active":false}',
              200,
            );
          }
          if (request.method == 'DELETE' &&
              request.url.path == '/admin/staff-roster/7') {
            return http.Response('{"message":"Staff member removed"}', 200);
          }
          return http.Response('Not found', 404);
        }),
      );

      final roster = await service.getStaffRoster(token: 'staff-token');
      expect(roster.single.name, 'Jonayed');
      expect(roster.single.isActive, isTrue);
      final added = await service.addStaffRosterMember(
        name: 'New Staff',
        hours: '09:00 - 18:00',
        token: 'admin-token',
      );
      final inactive = await service.updateStaffRosterMember(
        member: added,
        name: added.name,
        hours: added.hours,
        isActive: false,
        token: 'admin-token',
      );
      expect(inactive.isActive, isFalse);
      await service.deleteStaffRosterMember(
        staffId: inactive.id,
        token: 'admin-token',
      );

      expect(requests.first.headers['authorization'], 'Bearer staff-token');
      expect(
        jsonDecode(requests[1].body),
        {'name': 'New Staff', 'hours': '09:00 - 18:00'},
      );
      expect(
        jsonDecode(requests[2].body),
        {
          'name': 'New Staff',
          'hours': '09:00 - 18:00',
          'is_active': false,
        },
      );
      expect(requests.last.method, 'DELETE');
    });

    test('requests idempotent shift carry-forward with authenticated data',
        () async {
      late http.Request capturedRequest;
      final service = ApiService(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"carried_count":2}', 200);
        }),
      );

      final carriedCount = await service.carryForwardLogs(
        shiftDate: '2026-10-28',
        shiftPeriod: 'Morning (07:00 - 15:00)',
        issuedDateTime: '28-Oct-2026 07:00 AM',
        staffName: 'Rehan Ahmed',
        token: 'session-token',
      );

      expect(carriedCount, 2);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/logs/carry-forward');
      expect(capturedRequest.headers['authorization'], 'Bearer session-token');
      expect(
        jsonDecode(capturedRequest.body),
        {
          'shift_date': '2026-10-28',
          'shift_period': 'Morning (07:00 - 15:00)',
          'issued_date': '28-Oct-2026 07:00 AM',
          'staff_name': 'Rehan Ahmed',
        },
      );
    });

    test('handles sign-up, login, restored sessions and password requests',
        () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.path == '/auth/signup') {
          return http.Response(
            '{"access_token":"frontdesk-token","expires_at":"2026-11-26T20:00:00Z","user":{"id":2,"username":"rehan","display_name":"Rehan Ahmed","role":"reception"}}',
            201,
          );
        }
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(
            '{"access_token":"frontdesk-token","expires_at":"2026-11-26T20:00:00Z","user":{"id":2,"username":"rehan","display_name":"Rehan Ahmed","role":"reception"}}',
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/auth/me') {
          return http.Response(
            '{"id":2,"username":"rehan","display_name":"Rehan Ahmed","role":"reception"}',
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/auth/forgot-password') {
          return http.Response('{"message":"request received"}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          expect(request.headers['authorization'], 'Bearer frontdesk-token');
          return http.Response('{"total_inventory":70}', 200);
        }
        if (request.method == 'PUT' && request.url.path == '/admin/inventory') {
          expect(request.headers['authorization'], 'Bearer admin-token');
          expect(
            jsonDecode(request.body),
            {'total_inventory': 80},
          );
          return http.Response('{"total_inventory":80}', 200);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/auth/me/password') {
          expect(request.headers['authorization'], 'Bearer frontdesk-token');
          expect(
            jsonDecode(request.body),
            {
              'current_password': 'frontdesk123',
              'new_password': 'new-frontdesk-password',
            },
          );
          return http.Response('{"message":"password changed"}', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/auth/admin/password-reset-requests') {
          return http.Response(
            '[{"id":7,"user_id":2,"requested_username":"rehan","created_at":"2026-10-27T18:00:00Z"}]',
            200,
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/auth/admin/users/2/password') {
          return http.Response('{"message":"password reset"}', 200);
        }
        if (request.method == 'POST' && request.url.path == '/auth/logout') {
          return http.Response('{"message":"signed out"}', 200);
        }
        return http.Response('Not found', 404);
      });
      final service = ApiService(client: client);

      final signup = await service.signUp(
        username: 'rehan',
        displayName: 'Rehan Ahmed',
        password: 'frontdesk123',
      );
      expect(signup.user.role, 'reception');
      expect(
        (jsonDecode(requests.first.body) as Map<String, dynamic>)
            .containsKey('role'),
        isFalse,
      );

      final login = await service.login(
        username: 'rehan',
        password: 'frontdesk123',
      );
      expect(login.user.isAdmin, isFalse);
      expect((await service.getCurrentUser(token: login.accessToken)).username,
          'rehan');
      await service.requestPasswordReset(username: 'rehan');
      await service.changeOwnPassword(
        currentPassword: 'frontdesk123',
        newPassword: 'new-frontdesk-password',
        token: login.accessToken,
      );
      expect(await service.getInventoryLimit(token: login.accessToken), 70);
      await service.updateInventoryLimit(
        totalInventory: 80,
        token: 'admin-token',
      );
      final requestsForAdmin = await service.getPasswordResetRequests(
        token: 'admin-token',
      );
      expect(requestsForAdmin.single.userId, 2);
      expect(requestsForAdmin.single.username, 'rehan');
      await service.resetReceptionPassword(
        userId: 2,
        password: 'new-password',
        token: 'admin-token',
      );
      await service.logout(token: login.accessToken);

      expect(
        requests
            .firstWhere((request) => request.url.path == '/auth/me')
            .headers['authorization'],
        'Bearer frontdesk-token',
      );
      expect(
        requests
            .firstWhere((request) =>
                request.url.path == '/auth/admin/password-reset-requests')
            .headers['authorization'],
        'Bearer admin-token',
      );
    });

    test('creates, reads, updates and deletes persisted key logs', () async {
      final requests = <http.Request>[];
      final stored = <String, dynamic>{
        'id': 42,
        'issued_date': '27-Oct-2026 08:15 AM',
        'staff_name': 'Front Desk',
        'room_no': 'Room 405',
        'qty_issue': 2,
        'qty_return': 0,
        'status': 'PENDING',
        'returned_time': '',
        'received_by': '',
        'remarks': 'Arrival',
        'guest_or_holder_name': 'Guest One',
        'shift_date': '2026-10-27',
        'shift_period': 'Morning (07:00 - 15:00)',
        'category': 'Guest Key Card',
        'is_missing': false,
        'missing_qty': 0,
        'is_carried_forward': false,
        'original_shift_date': null,
        'carried_from_id': null,
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.path == '/admin/login') {
          return http.Response('{"access_token":"test-token"}', 200);
        }
        if (request.method == 'POST' && request.url.path == '/admin/logout') {
          return http.Response('{"message":"logged out"}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          return http.Response(jsonEncode([stored]), 200);
        }
        if (request.method == 'POST' && request.url.path == '/logs') {
          return http.Response(jsonEncode(stored), 200);
        }
        if (request.method == 'PUT' && request.url.path == '/logs/42') {
          return http.Response('{"message":"updated"}', 200);
        }
        if (request.method == 'PUT' && request.url.path == '/admin/logs/42') {
          return http.Response('{"message":"admin updated"}', 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/admin/logs/42') {
          return http.Response('{"message":"deleted"}', 200);
        }
        return http.Response('Not found', 404);
      });
      final service = ApiService(
        client: client,
        baseUri: Uri.parse('http://localhost:8000'),
      );
      final item = KeyIssuanceItem(
        id: '42',
        sNo: 1,
        shiftDate: '2026-10-27',
        shiftPeriod: 'Morning (07:00 - 15:00)',
        issuedDateTime: '27-Oct-2026 08:15 AM',
        issuingStaff: 'Front Desk',
        roomOrAccess: 'Room 405',
        guestOrHolderName: 'Guest One',
        qtyIssued: 2,
        remarks: 'Arrival',
      );

      final created = await service.createLog(item);
      expect(created.id, '42');
      expect(created.guestOrHolderName, 'Guest One');
      expect(created.shiftDate, '2026-10-27');

      final logs = await service.getLogs();
      expect(logs, hasLength(1));
      expect(logs.single.roomOrAccess, 'Room 405');

      final returned = KeyIssuanceItem.fromMap(item.toMap())
        ..qtyReturned = 2
        ..returnedDateTime = '27-Oct-2026 11:30 AM'
        ..keyReceivedBy = 'Front Desk';
      await service.updateLog(returned);
      final token = await service.adminLogin('1981');
      await service.adminUpdateLog(
        returned,
        accessToken: token,
      );
      await service.adminDeleteLog('42', accessToken: token);
      await service.adminLogout(accessToken: token);

      final createRequest = requests.firstWhere(
        (request) => request.method == 'POST' && request.url.path == '/logs',
      );
      final createPayload =
          jsonDecode(createRequest.body) as Map<String, dynamic>;
      expect(createPayload['room_no'], 'Room 405');
      expect(createPayload['qty_issue'], 2);

      final updateRequest = requests.firstWhere(
        (request) => request.method == 'PUT' && request.url.path == '/logs/42',
      );
      final updatePayload =
          jsonDecode(updateRequest.body) as Map<String, dynamic>;
      expect(updatePayload['qty_return'], 2);
      expect(updatePayload['status'], 'RETURNED');
      expect(updatePayload['received_by'], 'Front Desk');

      final adminUpdateRequest = requests.firstWhere(
        (request) =>
            request.method == 'PUT' && request.url.path == '/admin/logs/42',
      );
      expect(
        adminUpdateRequest.headers['authorization'],
        'Bearer test-token',
      );
      final adminDeleteRequest = requests.firstWhere(
        (request) =>
            request.method == 'DELETE' && request.url.path == '/admin/logs/42',
      );
      expect(
        adminDeleteRequest.headers['authorization'],
        'Bearer test-token',
      );
    });

    test('reports API response errors with their detail', () async {
      final service = ApiService(
        client: MockClient((_) async =>
            http.Response('{"detail":"Database unavailable"}', 503)),
      );

      await expectLater(
        service.getLogs(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                  (error) => error.message, 'message', 'Database unavailable'),
        ),
      );
    });

    test('returns a friendly error when login cannot reach the backend',
        () async {
      final service = ApiService(
        client: MockClient((_) async {
          throw const SocketException('Connection refused');
        }),
      );

      await expectLater(
        service.login(username: 'rehan', password: 'password123'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 0)
              .having(
                (error) => error.message,
                'message',
                'Could not reach the sign-in service. Check your connection or start the local backend server.',
              ),
        ),
      );
    });

    test('returns a friendly error when sign-up times out', () async {
      final service = ApiService(
        client: MockClient((_) async {
          throw TimeoutException('Request timed out');
        }),
      );

      await expectLater(
        service.signUp(
          username: 'rehan',
          displayName: 'Rehan Ahmed',
          password: 'password123',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Could not reach the sign-in service. Check your connection or start the local backend server.',
          ),
        ),
      );
    });
  });
}
