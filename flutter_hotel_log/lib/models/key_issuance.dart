class KeyIssuanceItem {
  final String id;
  int sNo;
  String shiftDate;
  String shiftPeriod;
  final String issuedDateTime;
  String issuingStaff;
  String roomOrAccess;
  String guestOrHolderName;
  int qtyIssued;
  int qtyReturned;
  bool isMissing;
  int missingQty;
  String? returnedDateTime;
  String? keyReceivedBy;
  String remarks;
  bool isCarriedForward;
  String? originalShiftDate;
  final String? carriedFromId;
  String category;

  KeyIssuanceItem({
    required this.id,
    required this.sNo,
    required this.shiftDate,
    required this.shiftPeriod,
    required this.issuedDateTime,
    required this.issuingStaff,
    required this.roomOrAccess,
    this.guestOrHolderName = '',
    required this.qtyIssued,
    this.qtyReturned = 0,
    this.isMissing = false,
    this.missingQty = 0,
    this.returnedDateTime,
    this.keyReceivedBy,
    this.remarks = '',
    this.isCarriedForward = false,
    this.originalShiftDate,
    this.carriedFromId,
    this.category = 'Guest Key Card',
  });

  bool get isFullyReturned => qtyReturned >= qtyIssued && !isMissing;
  bool get isPending => !isFullyReturned && !isMissing;
  int get remainingUnreturnedQty =>
      isFullyReturned ? 0 : (qtyIssued - qtyReturned).clamp(0, 999);
  int get missingQuantity => isMissing
      ? (missingQty > 0
          ? missingQty.clamp(0, remainingUnreturnedQty)
          : remainingUnreturnedQty)
      : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sNo': sNo,
        'shiftDate': shiftDate,
        'shiftPeriod': shiftPeriod,
        'issuedDateTime': issuedDateTime,
        'issuingStaff': issuingStaff,
        'roomOrAccess': roomOrAccess,
        'guestOrHolderName': guestOrHolderName,
        'qtyIssued': qtyIssued,
        'qtyReturned': qtyReturned,
        'isMissing': isMissing,
        'missingQty': missingQty,
        'returnedDateTime': returnedDateTime,
        'keyReceivedBy': keyReceivedBy,
        'remarks': remarks,
        'isCarriedForward': isCarriedForward,
        'originalShiftDate': originalShiftDate,
        'carriedFromId': carriedFromId,
        'category': category,
      };

  factory KeyIssuanceItem.fromMap(Map<String, dynamic> map) => KeyIssuanceItem(
        id: map['id'] as String,
        sNo: map['sNo'] as int? ?? 1,
        shiftDate: map['shiftDate'] as String,
        shiftPeriod: map['shiftPeriod'] as String,
        issuedDateTime: map['issuedDateTime'] as String,
        issuingStaff: map['issuingStaff'] as String,
        roomOrAccess: map['roomOrAccess'] as String,
        guestOrHolderName: map['guestOrHolderName'] as String? ?? '',
        qtyIssued: map['qtyIssued'] as int? ?? 1,
        qtyReturned: map['qtyReturned'] as int? ?? 0,
        isMissing: map['isMissing'] as bool? ?? false,
        missingQty: map['missingQty'] as int? ?? 0,
        returnedDateTime: map['returnedDateTime'] as String?,
        keyReceivedBy: map['keyReceivedBy'] as String?,
        remarks: map['remarks'] as String? ?? '',
        isCarriedForward: map['isCarriedForward'] as bool? ?? false,
        originalShiftDate: map['originalShiftDate'] as String?,
        carriedFromId: map['carriedFromId'] as String?,
        category: map['category'] as String? ?? 'Guest Key Card',
      );
}

class KeyLogMetrics {
  final int totalInventory;
  final int handoverToGuest;
  final int returnFromGuest;
  final int missingKeys;
  final int currentlyWithGuest;
  final int remainingInFd;

  const KeyLogMetrics({
    required this.totalInventory,
    required this.handoverToGuest,
    required this.returnFromGuest,
    required this.missingKeys,
    required this.currentlyWithGuest,
    required this.remainingInFd,
  });

  factory KeyLogMetrics.calculate(
    Iterable<KeyIssuanceItem> entries, {
    int totalInventory = 70,
    String? shiftDate,
    String? shiftPeriod,
  }) {
    final selectedEntries = entries.where((entry) =>
        (shiftDate == null || entry.shiftDate == shiftDate) &&
        (shiftPeriod == null ||
            shiftPeriod == 'All Shifts' ||
            entry.shiftPeriod == shiftPeriod));
    var handover = 0;
    var returned = 0;
    var missing = 0;
    for (final entry in selectedEntries) {
      returned += entry.qtyReturned;
      final unreturned = entry.remainingUnreturnedQty;
      final missingForEntry = entry.missingQuantity;
      missing += missingForEntry;
      handover += unreturned - missingForEntry;
    }

    final inFrontDesk = totalInventory - handover - missing;
    return KeyLogMetrics(
      totalInventory: totalInventory,
      handoverToGuest: handover,
      returnFromGuest: returned,
      missingKeys: missing,
      currentlyWithGuest: handover,
      remainingInFd: inFrontDesk,
    );
  }
}

class KeyLogLogic {
  static KeyIssuanceItem addIssuance({
    required List<KeyIssuanceItem> entries,
    required String id,
    required String shiftDate,
    required String shiftPeriod,
    required String issuedDateTime,
    required String issuingStaff,
    required String roomOrAccess,
    required int qtyIssued,
    String guestOrHolderName = '',
    String category = 'Guest Key Card',
    String remarks = '',
  }) {
    final entry = KeyIssuanceItem(
      id: id,
      sNo: entries.length + 1,
      shiftDate: shiftDate,
      shiftPeriod: shiftPeriod,
      issuedDateTime: issuedDateTime,
      issuingStaff: issuingStaff,
      roomOrAccess: roomOrAccess,
      guestOrHolderName: guestOrHolderName,
      qtyIssued: qtyIssued,
      category: category,
      remarks: remarks,
    );
    entries.add(entry);
    return entry;
  }

  static int carryForwardPending({
    required List<KeyIssuanceItem> entries,
    required String shiftDate,
    required String shiftPeriod,
    required String issuedDateTime,
    required String issuingStaff,
  }) {
    final pendingEntries = entries
        .where((entry) =>
            entry.isPending &&
            (entry.shiftDate != shiftDate ||
                entry.shiftPeriod != shiftPeriod) &&
            !entries.any((candidate) => candidate.carriedFromId == entry.id))
        .toList();
    var carriedCount = 0;

    for (final entry in pendingEntries) {
      final alreadyCarried = entries.any((candidate) =>
          candidate.carriedFromId == entry.id &&
          candidate.shiftDate == shiftDate &&
          candidate.shiftPeriod == shiftPeriod);
      if (alreadyCarried) continue;

      entries.add(
        KeyIssuanceItem(
          id: 'carry:${entry.id}:$shiftDate:$shiftPeriod',
          sNo: entries.length + 1,
          shiftDate: shiftDate,
          shiftPeriod: shiftPeriod,
          issuedDateTime: issuedDateTime,
          issuingStaff: issuingStaff,
          roomOrAccess: entry.roomOrAccess,
          guestOrHolderName: entry.guestOrHolderName,
          qtyIssued: entry.remainingUnreturnedQty,
          isCarriedForward: true,
          originalShiftDate: entry.originalShiftDate ?? entry.shiftDate,
          carriedFromId: entry.id,
          category: entry.category,
          remarks:
              'Carried forward from ${entry.shiftPeriod}: ${entry.remarks}',
        ),
      );
      carriedCount++;
    }

    return carriedCount;
  }
}
