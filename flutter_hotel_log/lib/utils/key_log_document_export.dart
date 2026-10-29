import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/key_issuance.dart';

class KeyLogDocumentExport {
  static Uint8List toExcel(Iterable<KeyIssuanceItem> entries) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Key Log'];
    if (!workbook.setDefaultSheet('Key Log')) {
      throw StateError(
          'Could not set the key log worksheet as the first sheet.');
    }
    sheet.appendRow([
      for (final header in _headers) TextCellValue(header),
    ]);
    for (final entry in entries) {
      final values = _values(entry);
      sheet.appendRow([
        IntCellValue(entry.sNo),
        for (var index = 1; index < values.length; index++)
          if (index == 8)
            IntCellValue(entry.qtyIssued)
          else if (index == 9)
            IntCellValue(entry.qtyReturned)
          else
            TextCellValue(values[index]),
      ]);
    }
    final encodedWorkbook = workbook.encode();
    if (encodedWorkbook == null) {
      throw StateError('Could not encode the key log Excel workbook.');
    }
    return Uint8List.fromList(encodedWorkbook);
  }

  static Future<Uint8List> toPdf(Iterable<KeyIssuanceItem> entries) async {
    final document = pw.Document();
    final rows = entries.map(_values).toList();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'RAMADA BY WYNDHAM DOHA OLD TOWN',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#7A1426'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Key Log Export'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 7,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7A1426)),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#D1D9E3'),
              width: 0.5,
            ),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  static const _headers = [
    'S.No',
    'Room / Access',
    'Guest / Holder',
    'Shift Date',
    'Shift',
    'Issued At',
    'Issuing Staff',
    'Check-out Date',
    'Qty Issued',
    'Qty Returned',
    'Status',
    'Returned At',
    'Received By',
    'Remarks',
  ];

  static List<String> _values(KeyIssuanceItem entry) => [
        '${entry.sNo}',
        entry.roomOrAccess,
        entry.guestOrHolderName,
        entry.shiftDate,
        entry.shiftPeriod,
        entry.issuedDateTime,
        entry.issuingStaff,
        entry.checkOutDate ?? '',
        '${entry.qtyIssued}',
        '${entry.qtyReturned}',
        entry.isMissing
            ? 'Missing'
            : entry.isFullyReturned
                ? 'Returned'
                : 'Issued',
        entry.returnedDateTime ?? '',
        entry.keyReceivedBy ?? '',
        entry.remarks,
      ];
}
