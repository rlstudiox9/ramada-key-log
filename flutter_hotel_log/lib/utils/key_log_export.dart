import '../models/key_issuance.dart';

class KeyLogExport {
  static String toCsv(Iterable<KeyIssuanceItem> entries) {
    final rows = <List<String>>[
      [
        'S.No',
        'Shift Date',
        'Shift',
        'Issued Date/Time',
        'Check-out Date',
        'Issuing Staff',
        'Room/Access',
        'Guest/Holder',
        'Qty Issued',
        'Qty Returned',
        'Missing',
        'Missing Qty',
        'Returned Date/Time',
        'Key Received By',
        'Remarks',
        'Carried Forward',
        'Original Shift Date',
        'Category',
      ],
      ...entries.map((entry) => [
            '${entry.sNo}',
            entry.shiftDate,
            entry.shiftPeriod,
            entry.issuedDateTime,
            entry.checkOutDate ?? '',
            entry.issuingStaff,
            entry.roomOrAccess,
            entry.guestOrHolderName,
            '${entry.qtyIssued}',
            '${entry.qtyReturned}',
            '${entry.isMissing}',
            '${entry.missingQty}',
            entry.returnedDateTime ?? '',
            entry.keyReceivedBy ?? '',
            entry.remarks,
            '${entry.isCarriedForward}',
            entry.originalShiftDate ?? '',
            entry.category,
          ]),
    ];
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n');
  }

  static String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';
}
