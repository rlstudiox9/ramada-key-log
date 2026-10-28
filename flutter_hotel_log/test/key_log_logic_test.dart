import 'package:flutter_test/flutter_test.dart';
import 'package:ramada_key_log/models/key_issuance.dart';
import 'package:ramada_key_log/utils/key_log_export.dart';

void main() {
  group('Key log logic', () {
    test('adds a key issuance to the active entries', () {
      final entries = <KeyIssuanceItem>[];

      final added = KeyLogLogic.addIssuance(
        entries: entries,
        id: 'key-1',
        shiftDate: '2026-10-27',
        shiftPeriod: 'Morning (07:00 - 15:00)',
        issuedDateTime: '27-Oct-2026 08:15 AM',
        issuingStaff: 'Front Desk',
        roomOrAccess: 'Room 405',
        guestOrHolderName: 'Guest One',
        qtyIssued: 2,
      );

      expect(entries, hasLength(1));
      expect(added, same(entries.single));
      expect(added.roomOrAccess, 'Room 405');
      expect(added.qtyIssued, 2);
      expect(added.isPending, isTrue);
    });

    test('carries unreturned quantity into a new shift once', () {
      final entries = <KeyIssuanceItem>[
        KeyIssuanceItem(
          id: 'key-1',
          sNo: 1,
          shiftDate: '2026-10-26',
          shiftPeriod: 'Night (23:00 - 07:00)',
          issuedDateTime: '26-Oct-2026 11:30 PM',
          issuingStaff: 'Night Auditor',
          roomOrAccess: 'Room 218',
          qtyIssued: 3,
          qtyReturned: 1,
        ),
      ];

      final carriedCount = KeyLogLogic.carryForwardPending(
        entries: entries,
        shiftDate: '2026-10-27',
        shiftPeriod: 'Morning (07:00 - 15:00)',
        issuedDateTime: '27-Oct-2026 07:00 AM',
        issuingStaff: 'Morning Staff',
      );

      expect(carriedCount, 1);
      final carried = entries.last;
      expect(carried.isCarriedForward, isTrue);
      expect(carried.carriedFromId, 'key-1');
      expect(carried.originalShiftDate, '2026-10-26');
      expect(carried.qtyIssued, 2);
      expect(carried.qtyReturned, 0);

      expect(
        KeyLogLogic.carryForwardPending(
          entries: entries,
          shiftDate: '2026-10-27',
          shiftPeriod: 'Morning (07:00 - 15:00)',
          issuedDateTime: '27-Oct-2026 07:01 AM',
          issuingStaff: 'Morning Staff',
        ),
        0,
      );
      expect(entries, hasLength(2));
    });

    test('does not re-carry the original after a carried record exists', () {
      final entries = [
        KeyIssuanceItem(
          id: 'key-1',
          sNo: 1,
          shiftDate: '2026-10-25',
          shiftPeriod: 'Morning (07:00 - 15:00)',
          issuedDateTime: '25-Oct-2026 08:00 AM',
          issuingStaff: 'Staff',
          roomOrAccess: 'Room 102',
          qtyIssued: 1,
        ),
      ];
      KeyLogLogic.carryForwardPending(
        entries: entries,
        shiftDate: '2026-10-26',
        shiftPeriod: 'Morning (07:00 - 15:00)',
        issuedDateTime: '26-Oct-2026 07:00 AM',
        issuingStaff: 'Staff',
      );

      expect(
        KeyLogLogic.carryForwardPending(
          entries: entries,
          shiftDate: '2026-10-27',
          shiftPeriod: 'Morning (07:00 - 15:00)',
          issuedDateTime: '27-Oct-2026 07:00 AM',
          issuingStaff: 'Staff',
        ),
        1,
      );
      expect(entries, hasLength(3));
      expect(entries.last.carriedFromId, entries[1].id);
    });

    test('calculates 70-key inventory including returned and missing keys', () {
      final entries = [
        KeyIssuanceItem(
          id: 'returned',
          sNo: 1,
          shiftDate: '2026-10-27',
          shiftPeriod: 'Morning (07:00 - 15:00)',
          issuedDateTime: '27-Oct-2026 08:00 AM',
          issuingStaff: 'Staff',
          roomOrAccess: 'Room 101',
          qtyIssued: 4,
          qtyReturned: 2,
        ),
        KeyIssuanceItem(
          id: 'missing',
          sNo: 2,
          shiftDate: '2026-10-27',
          shiftPeriod: 'Morning (07:00 - 15:00)',
          issuedDateTime: '27-Oct-2026 09:00 AM',
          issuingStaff: 'Staff',
          roomOrAccess: 'Room 102',
          qtyIssued: 1,
          isMissing: true,
          missingQty: 1,
        ),
      ];

      final metrics = KeyLogMetrics.calculate(
        entries,
        shiftPeriod: 'Morning (07:00 - 15:00)',
      );

      expect(metrics.totalInventory, 70);
      expect(metrics.handoverToGuest, 2);
      expect(metrics.returnFromGuest, 2);
      expect(metrics.missingKeys, 1);
      expect(metrics.currentlyWithGuest, 2);
      expect(metrics.remainingInFd, 67);
      expect(
        metrics.totalInventory,
        metrics.remainingInFd + metrics.handoverToGuest + metrics.missingKeys,
      );
    });

    test('exports CSV with escaped values', () {
      final csv = KeyLogExport.toCsv([
        KeyIssuanceItem(
          id: 'key-1',
          sNo: 1,
          shiftDate: '2026-10-27',
          shiftPeriod: 'Morning',
          issuedDateTime: '27-Oct-2026 08:00 AM',
          issuingStaff: 'Staff',
          roomOrAccess: 'Room 405',
          guestOrHolderName: 'Guest, One',
          qtyIssued: 1,
          remarks: 'Said "thank you"',
        ),
      ]);

      expect(csv, contains('"Guest, One"'));
      expect(csv, contains('"Said ""thank you"""'));
      expect(csv, startsWith('"S.No","Shift Date"'));
    });
  });
}
