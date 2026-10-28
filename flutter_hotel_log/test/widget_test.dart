import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ramada_key_log/main.dart';
import 'package:ramada_key_log/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signup, persistent login session, role and logout',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    expect(
      (jsonDecode(_activeRosterJson()) as List)
          .map(
            (staff) => (
              (staff as Map<String, dynamic>)['name'],
              staff['hours'],
            ),
          )
          .toList(),
      [
        ('Jonayed', '08:00 - 17:00'),
        ('Azizul', '15:00 - 00:00'),
        ('Wahaj', '12:00 - 21:00'),
        ('Hanseef', '00:00 - 09:00'),
        ('Supervisor Hania', '08:00 - 17:00'),
        ('Manager Mehbuba', '08:00 - 17:00'),
      ],
    );
    final storedLogs = <Map<String, dynamic>>[];
    final requests = <http.Request>[];
    var nextId = 1;
    final service = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.path == '/auth/signup') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload.containsKey('role'), isFalse);
          return http.Response(
            jsonEncode(_sessionJson(role: 'reception')),
            201,
          );
        }
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(
              jsonEncode(_sessionJson(role: 'reception')), 200);
        }
        if (request.method == 'GET' && request.url.path == '/auth/me') {
          expect(
            request.headers['authorization'],
            'Bearer reception-session',
          );
          return http.Response(jsonEncode(_userJson(role: 'reception')), 200);
        }
        if (request.method == 'POST' && request.url.path == '/auth/logout') {
          return http.Response('{"message":"signed out"}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/auth/forgot-password') {
          expect(
            (jsonDecode(request.body) as Map<String, dynamic>)['username'],
            'rehan',
          );
          return http.Response('{"message":"request received"}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/staff-roster') {
          return http.Response(_activeRosterJson(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          return http.Response('{"total_inventory":70}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          expect(request.headers['authorization'], 'Bearer reception-session');
          return http.Response(jsonEncode(storedLogs.reversed.toList()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/logs/carry-forward') {
          return http.Response('{"carried_count":0}', 200);
        }
        if (request.method == 'POST' && request.url.path == '/logs') {
          expect(request.headers['authorization'], 'Bearer reception-session');
          final item = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          item['id'] = nextId++;
          storedLogs.add(item);
          return http.Response(jsonEncode(item), 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Admin access is provisioned by hotel management.'),
        findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('forgot-username')), 'rehan');
    await tester.tap(find.text('Request reset'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('If the account exists'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New staff member? Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Full name'), 'Rehan Ahmed');
    await tester.enterText(_field('Username'), 'rehan');
    await tester.enterText(_field('Password'), 'frontdesk123');
    await tester.enterText(
      _field('Re-type password'),
      'frontdesk123',
    );
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rehan Ahmed'), findsOneWidget);
    expect(find.textContaining('Reception / Front Desk'), findsOneWidget);
    expect(find.byTooltip('Manage key stock'), findsNothing);

    await tester.tap(find.text('Issue Key Card'));
    await tester.pumpAndSettle();
    final staffNameField = find.byKey(const ValueKey('issue:staff-name'));
    expect(staffNameField, findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(staffNameField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jonayed (08:00 - 17:00)').last);
    await tester.pumpAndSettle();
    final roomField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g. Room 405',
    );
    await tester.tap(roomField);
    await tester.enterText(roomField, 'Room 405');
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Issue'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      contains('POST /logs'),
    );
    expect(storedLogs.single['room_no'], 'Room 405');
    expect(storedLogs.single['staff_name'], 'Jonayed');
    expect(find.byTooltip('Delete log'), findsNothing);
    expect(find.byTooltip('Edit log'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsNothing);
    expect(find.text('Room 405'), findsOneWidget);
    expect(requests.any((request) => request.url.path == '/auth/me'), isTrue);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth_access_token'), isNull);

    await tester.enterText(_field('Username'), 'rehan');
    await tester.enterText(_field('Password'), 'frontdesk123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Room 405'), findsOneWidget);
  });

  testWidgets('admin session shows protected row controls', (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var inventory = 70;
    final roster = List<Map<String, dynamic>>.from(
      jsonDecode(_activeRosterJson()) as List,
    );
    final service = ApiService(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(jsonEncode(_sessionJson(role: 'admin')), 200);
        }
        if (request.method == 'GET' && request.url.path == '/staff-roster') {
          final includeInactive =
              request.url.queryParameters['include_inactive'] == 'true';
          return http.Response(
            jsonEncode(
              roster
                  .where(
                    (member) => includeInactive || member['is_active'] == true,
                  )
                  .toList(),
            ),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/admin/staff-roster') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final added = {
            'id': 7,
            ...payload,
            'is_active': true,
          };
          roster.add(added);
          return http.Response(jsonEncode(added), 201);
        }
        if (request.method == 'PUT' &&
            request.url.path.startsWith('/admin/staff-roster/')) {
          final id = int.parse(request.url.path.split('/').last);
          final member = roster.firstWhere((item) => item['id'] == id);
          member.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode(member), 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path.startsWith('/admin/staff-roster/')) {
          final id = int.parse(request.url.path.split('/').last);
          roster.removeWhere((item) => item['id'] == id);
          return http.Response('{"message":"Staff member removed"}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          return http.Response(
            jsonEncode({'total_inventory': inventory}),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          return http.Response(
            jsonEncode([
              {
                'id': 42,
                'issued_date': DateTime.now().toIso8601String(),
                'staff_name': 'Admin',
                'room_no': 'Room 405',
                'qty_issue': 5,
                'qty_return': 2,
                'status': 'PENDING',
                'shift_date': _todayStamp(),
                'shift_period': _currentShift(),
              },
            ]),
            200,
          );
        }
        if (request.method == 'PUT' && request.url.path == '/admin/inventory') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          inventory = payload['total_inventory'] as int;
          return http.Response(
            jsonEncode({'total_inventory': inventory}),
            200,
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/auth/me/password') {
          expect(request.headers['authorization'], 'Bearer admin-session');
          expect(
            jsonDecode(request.body),
            {
              'current_password': 'strong-password',
              'new_password': 'new-strong-password',
            },
          );
          return http.Response('{"message":"password changed"}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/logs/carry-forward') {
          return http.Response('{"carried_count":0}', 200);
        }
        return http.Response('Not found', 404);
      }),
    );
    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Username'), 'admin');
    await tester.enterText(_field('Password'), 'strong-password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Admin').first, findsOneWidget);
    expect(find.byTooltip('Manage key stock'), findsOneWidget);
    await tester.tap(find.byTooltip('Manage staff roster'));
    await tester.pumpAndSettle();
    expect(find.text('Manage Staff Roster'), findsOneWidget);
    expect(find.text('Jonayed'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('roster:add-name')),
      'Night Supervisor',
    );
    await tester.enterText(
      find.byKey(const ValueKey('roster:add-hours')),
      '22:00 - 07:00',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Night Supervisor'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      roster.firstWhere((member) => member['name'] == 'Azizul')['is_active'],
      isFalse,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();
    expect(
        roster.any((member) => member['name'] == 'Night Supervisor'), isTrue);

    await tester.tap(find.byTooltip('Manage key stock'));
    await tester.pumpAndSettle();
    final inventoryField = find.byKey(const ValueKey('inventory-limit-field'));
    await tester.enterText(inventoryField, '2');
    await tester.tap(find.text('Save stock limit'));
    await tester.pumpAndSettle();
    expect(find.text('At least 3 keys are checked out.'), findsOneWidget);

    await tester.enterText(inventoryField, '80');
    await tester.tap(find.text('Save stock limit'));
    await tester.pumpAndSettle();
    expect(find.text('Key stock limit updated.'), findsOneWidget);
    expect(inventory, 80);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Handover Issued'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Scope:'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('change-password:current')),
      'strong-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password:new')),
      'new-strong-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password:confirm')),
      'new-strong-password',
    );
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Your password has been updated.'), findsOneWidget);
  });

  testWidgets(
      'return dialog uses the fixed staff roster, table numbering starts at one, and dark table colors stay readable',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final logs = [
      _logJson(id: 41, room: 'Room 401', staff: 'Original Staff'),
      _logJson(id: 42, room: 'Room 402', staff: 'Original Staff'),
    ];
    Map<String, dynamic>? updatedPayload;
    final service = ApiService(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode(_sessionJson(role: 'reception')),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/staff-roster') {
          return http.Response(_activeRosterJson(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          return http.Response('{"total_inventory":70}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          return http.Response(jsonEncode(logs.reversed.toList()), 200);
        }
        if (request.method == 'PUT' && request.url.path == '/logs/42') {
          updatedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          logs.last.addAll(updatedPayload!);
          return http.Response('{"message":"updated"}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/logs/carry-forward') {
          return http.Response('{"carried_count":0}', 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Username'), 'rehan');
    await tester.enterText(_field('Password'), 'frontdesk123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
      table.rows.map((row) => (row.cells.first.child as Text).data),
      ['1', '2'],
    );

    await tester.tap(find.byTooltip('Dark theme'));
    await tester.pumpAndSettle();
    final darkTableTheme =
        Theme.of(tester.element(find.byType(DataTable))).dataTableTheme;
    expect(darkTableTheme.headingTextStyle?.color, RamadaColors.goldLight);
    expect(darkTableTheme.dataTextStyle?.color, const Color(0xFFF1F1F1));

    final returnButton = find.widgetWithText(ElevatedButton, 'Return').first;
    await tester.ensureVisible(returnButton);
    await tester.pumpAndSettle();
    await tester.tap(returnButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('return:staff-name')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(find.text('Confirm Return'));
    await tester.pumpAndSettle();
    expect(find.text('Select a staff member.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return:staff-name')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azizul (15:00 - 00:00)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Return'));
    await tester.pumpAndSettle();
    expect(updatedPayload?['received_by'], 'Azizul');
    expect(updatedPayload?['qty_return'], 3);
  });

  testWidgets('staff inventory refreshes after an admin-side stock update',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var inventory = 70;
    final service = ApiService(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode(_sessionJson(role: 'reception')),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/staff-roster') {
          return http.Response(_activeRosterJson(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          return http.Response(jsonEncode({'total_inventory': inventory}), 200);
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          return http.Response('[]', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/logs/carry-forward') {
          return http.Response('{"carried_count":0}', 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Username'), 'rehan');
    await tester.enterText(_field('Password'), 'frontdesk123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('70 Pcs'), findsOneWidget);
    expect(find.byTooltip('Manage key stock'), findsNothing);

    inventory = 85;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('85 Pcs'), findsOneWidget);
  });

  testWidgets('responsive login shows scrollable privacy and terms dialogs',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = ApiService(
      client: MockClient((_) async => http.Response('Not found', 404)),
    );

    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Powered by R & L Studio'), findsOneWidget);

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel operational data'), findsOneWidget);
    expect(find.text('Data security and retention'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Permitted use'), findsOneWidget);
    expect(find.text('Restrictions and ownership'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('premium login layout fits desktop, tablet and mobile widths',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = ApiService(
      client: MockClient((_) async => http.Response('Not found', 404)),
    );

    for (final (width, height) in [
      (1920.0, 1080.0),
      (1440.0, 900.0),
      (1280.0, 800.0),
      (1024.0, 768.0),
      (768.0, 1024.0),
      (480.0, 900.0),
      (390.0, 844.0),
      (375.0, 812.0),
    ]) {
      tester.view.physicalSize = Size(width, height);
      await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth:Username')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth:Password')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport $width×$height');
    }
    final passwordInput = find.descendant(
      of: find.byKey(const ValueKey('auth:Password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(passwordInput).obscureText,
      isFalse,
    );
  });

  testWidgets('startup shows branded progress while restoring session',
      (tester) async {
    _disableAnimationsForTest(tester);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'admin-session',
    });
    final currentUserResponse = Completer<http.Response>();
    final service = ApiService(
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/auth/me') {
          return currentUserResponse.future;
        }
        if (request.method == 'GET' && request.url.path == '/staff-roster') {
          return http.Response(_activeRosterJson(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/inventory') {
          return http.Response('{"total_inventory":70}', 200);
        }
        if (request.method == 'GET' && request.url.path == '/logs') {
          return http.Response('[]', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/logs/carry-forward') {
          return http.Response('{"carried_count":0}', 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    await tester.pumpWidget(RamadaKeyLogApp(apiService: service));
    await tester.pump();
    expect(find.text('RAMADA KEYS'), findsOneWidget);
    expect(find.text('Restoring your secure session...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    currentUserResponse.complete(
      http.Response(jsonEncode(_userJson(role: 'admin')), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsOneWidget);
  });
}

String _todayStamp() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _activeRosterJson() => jsonEncode([
      {'id': 1, 'name': 'Jonayed', 'hours': '08:00 - 17:00', 'is_active': true},
      {'id': 2, 'name': 'Azizul', 'hours': '15:00 - 00:00', 'is_active': true},
      {'id': 3, 'name': 'Wahaj', 'hours': '12:00 - 21:00', 'is_active': true},
      {'id': 4, 'name': 'Hanseef', 'hours': '00:00 - 09:00', 'is_active': true},
      {
        'id': 5,
        'name': 'Supervisor Hania',
        'hours': '08:00 - 17:00',
        'is_active': true,
      },
      {
        'id': 6,
        'name': 'Manager Mehbuba',
        'hours': '08:00 - 17:00',
        'is_active': true,
      },
    ]);

String _currentShift() {
  final hour = DateTime.now().hour;
  if (hour < 7 || hour >= 23) return 'Night (23:00 - 07:00)';
  if (hour < 15) return 'Morning (07:00 - 15:00)';
  return 'Afternoon (15:00 - 23:00)';
}

void _disableAnimationsForTest(WidgetTester tester) {
  final platformDispatcher = tester.binding.platformDispatcher;
  platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Finder _field(String label) => find.byKey(ValueKey('auth:$label'));

Map<String, dynamic> _userJson({required String role}) => {
      'id': role == 'admin' ? 1 : 2,
      'username': role == 'admin' ? 'admin' : 'rehan',
      'display_name': role == 'admin' ? 'Ramada Administrator' : 'Rehan Ahmed',
      'role': role,
    };

Map<String, dynamic> _sessionJson({required String role}) => {
      'access_token': '$role-session',
      'token_type': 'bearer',
      'expires_at': '2026-11-26T20:00:00Z',
      'user': _userJson(role: role),
    };

Map<String, dynamic> _logJson({
  required int id,
  required String room,
  required String staff,
}) =>
    {
      'id': id,
      'issued_date': DateTime.now().toIso8601String(),
      'staff_name': staff,
      'room_no': room,
      'qty_issue': 3,
      'qty_return': 0,
      'status': 'PENDING',
      'shift_date': _todayStamp(),
      'shift_period': _currentShift(),
    };
