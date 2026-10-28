package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "key_issuances")
data class KeyIssuance(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val sNo: Int = 1,
    val shiftDate: String,            // e.g. "2026-10-27"
    val shiftPeriod: String,          // e.g. "Morning (07:00 - 15:00)"
    val issuedDateTime: String,       // e.g. "27-Oct-2026 08:30"
    val issuingStaff: String,         // e.g. "Ahmad (FD)"
    val roomOrAccess: String,         // e.g. "Room 405" or "Master Key FD-01"
    val guestOrHolderName: String = "",// e.g. "Mr. David Miller"
    val qtyIssued: Int = 1,           // Pcs
    val qtyReturned: Int = 0,          // Pcs
    val isMissing: Boolean = false,
    val missingQty: Int = 0,
    val returnedDateTime: String? = null,
    val keyReceivedBy: String? = null, // e.g. "Sarah Noor"
    val remarks: String = "",
    val isCarriedForward: Boolean = false,
    val originalShiftDate: String? = null,
    val category: String = "Guest Key Card", // "Guest Key Card", "Master / Floor Card", "System Access"
    val timestampMillis: Long = System.currentTimeMillis()
) {
    val isFullyReturned: Boolean
        get() = qtyReturned >= qtyIssued && !isMissing

    val isPending: Boolean
        get() = !isFullyReturned && !isMissing

    val remainingUnreturnedQty: Int
        get() = if (isFullyReturned) 0 else (qtyIssued - qtyReturned).coerceAtLeast(0)
}
