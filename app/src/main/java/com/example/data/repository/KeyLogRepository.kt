package com.example.data.repository

import com.example.data.local.KeyIssuanceDao
import com.example.data.model.KeyIssuance
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KeyLogRepository(private val dao: KeyIssuanceDao) {

    val allIssuances: Flow<List<KeyIssuance>> = dao.getAllIssuances()

    fun getIssuancesForDate(date: String): Flow<List<KeyIssuance>> {
        return dao.getIssuancesByDate(date)
    }

    suspend fun insert(issuance: KeyIssuance): Long {
        return dao.insert(issuance)
    }

    suspend fun update(issuance: KeyIssuance) {
        dao.update(issuance)
    }

    suspend fun delete(issuance: KeyIssuance) {
        dao.delete(issuance)
    }

    suspend fun deleteById(id: Long) {
        dao.deleteById(id)
    }

    suspend fun carryForwardUnreturnedKeys(targetDate: String, targetShift: String, staffName: String): Int {
        val priorUnreturned = dao.getUnreturnedFromPriorDays(targetDate)
        var count = 0
        val timestamp = SimpleDateFormat("dd-MMM-yyyy HH:mm", Locale.US).format(Date())

        for (item in priorUnreturned) {
            val unreturnedQty = item.qtyIssued - item.qtyReturned
            if (unreturnedQty > 0 && !item.isMissing) {
                val carried = KeyIssuance(
                    sNo = 0,
                    shiftDate = targetDate,
                    shiftPeriod = targetShift,
                    issuedDateTime = timestamp,
                    issuingStaff = "$staffName (Carried from ${item.shiftDate})",
                    roomOrAccess = item.roomOrAccess,
                    guestOrHolderName = item.guestOrHolderName,
                    qtyIssued = unreturnedQty,
                    qtyReturned = 0,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = null,
                    keyReceivedBy = null,
                    remarks = "Auto Carry-Forward: original issue #${item.sNo} on ${item.shiftDate}. ${item.remarks}".trim(),
                    isCarriedForward = true,
                    originalShiftDate = item.shiftDate,
                    category = item.category,
                    timestampMillis = System.currentTimeMillis()
                )
                dao.insert(carried)
                count++
            }
        }
        return count
    }

    suspend fun seedInitialDataIfEmpty() {
        if (dao.getCount() == 0) {
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val timeFmt = SimpleDateFormat("dd-MMM-yyyy", Locale.US).format(Date())

            val sampleData = listOf(
                KeyIssuance(
                    sNo = 1,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 07:15 AM",
                    issuingStaff = "Ahmad (FD)",
                    roomOrAccess = "Room 304",
                    guestOrHolderName = "Hassan Al-Kuwari",
                    qtyIssued = 2,
                    qtyReturned = 2,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = "$timeFmt 11:30 AM",
                    keyReceivedBy = "Fatima (FD)",
                    remarks = "Standard checkout return",
                    isCarriedForward = false,
                    category = "Guest Key Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 240
                ),
                KeyIssuance(
                    sNo = 2,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 08:20 AM",
                    issuingStaff = "Ahmad (FD)",
                    roomOrAccess = "Room 512",
                    guestOrHolderName = "Mr. Robert Sterling",
                    qtyIssued = 2,
                    qtyReturned = 0,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = null,
                    keyReceivedBy = null,
                    remarks = "Guest in-house, 2 keys issued at check-in",
                    isCarriedForward = false,
                    category = "Guest Key Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 180
                ),
                KeyIssuance(
                    sNo = 3,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 08:45 AM",
                    issuingStaff = "Fatima (FD)",
                    roomOrAccess = "Master Key FD-01",
                    guestOrHolderName = "Housekeeping Team - Floor 4",
                    qtyIssued = 1,
                    qtyReturned = 1,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = "$timeFmt 01:10 PM",
                    keyReceivedBy = "Ahmad (FD)",
                    remarks = "HK morning cleaning round",
                    isCarriedForward = false,
                    category = "Master / Floor Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 150
                ),
                KeyIssuance(
                    sNo = 4,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 09:10 AM",
                    issuingStaff = "Ahmad (FD)",
                    roomOrAccess = "Room 208",
                    guestOrHolderName = "Fatima Al-Sulaiti",
                    qtyIssued = 1,
                    qtyReturned = 0,
                    isMissing = true,
                    missingQty = 1,
                    returnedDateTime = null,
                    keyReceivedBy = null,
                    remarks = "Guest reported key lost at Souq Waqif, 50 QAR charge noted",
                    isCarriedForward = false,
                    category = "Guest Key Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 120
                ),
                KeyIssuance(
                    sNo = 5,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 09:30 AM",
                    issuingStaff = "Fatima (FD)",
                    roomOrAccess = "Room 701 (Suite)",
                    guestOrHolderName = "VIP - Sheikh Khalid",
                    qtyIssued = 3,
                    qtyReturned = 0,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = null,
                    keyReceivedBy = null,
                    remarks = "VIP Suite arrival, 3 keycards issued",
                    isCarriedForward = false,
                    category = "Guest Key Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 90
                ),
                KeyIssuance(
                    sNo = 6,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 06:30 AM",
                    issuingStaff = "Night Auditor Tariq",
                    roomOrAccess = "Room 114",
                    guestOrHolderName = "Dr. Michael Chen",
                    qtyIssued = 1,
                    qtyReturned = 0,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = null,
                    keyReceivedBy = null,
                    remarks = "Late arrival duplicate card. Carried forward from Night Shift.",
                    isCarriedForward = true,
                    originalShiftDate = todayStr,
                    category = "Guest Key Card",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 300
                ),
                KeyIssuance(
                    sNo = 7,
                    shiftDate = todayStr,
                    shiftPeriod = "Morning (07:00 - 15:00)",
                    issuedDateTime = "$timeFmt 10:15 AM",
                    issuingStaff = "Ahmad (FD)",
                    roomOrAccess = "Engineering Card ENG-02",
                    guestOrHolderName = "Maintenance Tech Bilal",
                    qtyIssued = 1,
                    qtyReturned = 1,
                    isMissing = false,
                    missingQty = 0,
                    returnedDateTime = "$timeFmt 11:45 AM",
                    keyReceivedBy = "Fatima (FD)",
                    remarks = "AC maintenance in 6th floor corridor",
                    isCarriedForward = false,
                    category = "System Access",
                    timestampMillis = System.currentTimeMillis() - 1000 * 60 * 60
                )
            )
            dao.insertAll(sampleData)
        }
    }

    fun exportToCsv(items: List<KeyIssuance>, totalKeys: Int): String {
        val sb = StringBuilder()
        sb.append("RAMADA BY WYNDHAM DOHA OLD TOWN - KEY CARD & SYSTEM ACCESS LOG\n")
        sb.append("Total Key Inventory: $totalKeys Pcs\n")
        sb.append("Export Date: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())}\n\n")
        sb.append("S.No,Shift Date,Shift,Issued Date Time,Issuing Staff,Room / Access,Guest/Holder Name,Qty Issued,Qty Returned,Missing,Missing Qty,Key Returned Date,Key Received By,Carried Forward,Remarks\n")

        items.forEachIndexed { index, item ->
            val sNo = index + 1
            val escape = { text: String? ->
                val str = text ?: ""
                "\"${str.replace("\"", "\"\"")}\""
            }
            sb.append("$sNo,")
            sb.append("${escape(item.shiftDate)},")
            sb.append("${escape(item.shiftPeriod)},")
            sb.append("${escape(item.issuedDateTime)},")
            sb.append("${escape(item.issuingStaff)},")
            sb.append("${escape(item.roomOrAccess)},")
            sb.append("${escape(item.guestOrHolderName)},")
            sb.append("${item.qtyIssued},")
            sb.append("${item.qtyReturned},")
            sb.append("${if (item.isMissing) "YES" else "NO"},")
            sb.append("${item.missingQty},")
            sb.append("${escape(item.returnedDateTime)},")
            sb.append("${escape(item.keyReceivedBy)},")
            sb.append("${if (item.isCarriedForward) "YES" else "NO"},")
            sb.append("${escape(item.remarks)}\n")
        }
        return sb.toString()
    }

    fun exportToJson(items: List<KeyIssuance>, totalKeys: Int): String {
        val sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"hotel\": \"Ramada by Wyndham Doha Old Town\",\n")
        sb.append("  \"totalKeyInventory\": $totalKeys,\n")
        sb.append("  \"exportedAt\": \"${SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())}\",\n")
        sb.append("  \"recordsCount\": ${items.size},\n")
        sb.append("  \"records\": [\n")
        items.forEachIndexed { i, item ->
            sb.append("    {\n")
            sb.append("      \"sNo\": ${i + 1},\n")
            sb.append("      \"shiftDate\": \"${item.shiftDate}\",\n")
            sb.append("      \"shiftPeriod\": \"${item.shiftPeriod}\",\n")
            sb.append("      \"issuedDateTime\": \"${item.issuedDateTime}\",\n")
            sb.append("      \"issuingStaff\": \"${item.issuingStaff.replace("\"", "\\\"")}\",\n")
            sb.append("      \"roomOrAccess\": \"${item.roomOrAccess.replace("\"", "\\\"")}\",\n")
            sb.append("      \"guestOrHolderName\": \"${item.guestOrHolderName.replace("\"", "\\\"")}\",\n")
            sb.append("      \"qtyIssued\": ${item.qtyIssued},\n")
            sb.append("      \"qtyReturned\": ${item.qtyReturned},\n")
            sb.append("      \"isMissing\": ${item.isMissing},\n")
            sb.append("      \"missingQty\": ${item.missingQty},\n")
            sb.append("      \"returnedDateTime\": ${if (item.returnedDateTime != null) "\"${item.returnedDateTime}\"" else "null"},\n")
            sb.append("      \"keyReceivedBy\": ${if (item.keyReceivedBy != null) "\"${item.keyReceivedBy}\"" else "null"},\n")
            sb.append("      \"isCarriedForward\": ${item.isCarriedForward},\n")
            sb.append("      \"remarks\": \"${item.remarks.replace("\"", "\\\"")}\"\n")
            sb.append(if (i == items.size - 1) "    }\n" else "    },\n")
        }
        sb.append("  ]\n")
        sb.append("}\n")
        return sb.toString()
    }

    fun generateShiftHandoverReport(
        items: List<KeyIssuance>,
        totalKeys: Int,
        activeShift: String,
        activeDate: String,
        dutyStaff: String
    ): String {
        val totalIssued = items.sumOf { it.qtyIssued }
        val totalReturned = items.sumOf { it.qtyReturned }
        val missingCount = items.filter { it.isMissing }.sumOf { if (it.missingQty > 0) it.missingQty else (it.qtyIssued - it.qtyReturned).coerceAtLeast(1) }
        val currentlyOut = (totalIssued - totalReturned - missingCount).coerceAtLeast(0)
        val remainingInFd = (totalKeys - currentlyOut - missingCount).coerceAtLeast(0)
        val unreturnedList = items.filter { it.isPending }

        val sb = StringBuilder()
        sb.append("🏨 *RAMADA BY WYNDHAM DOHA OLD TOWN*\n")
        sb.append("🔑 *FRONT DESK KEY CARD & SYSTEM ACCESS HANDOVER*\n")
        sb.append("━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        sb.append("📅 Date: $activeDate\n")
        sb.append("⏱️ Shift: $activeShift\n")
        sb.append("👤 Logged By: $dutyStaff\n\n")
        sb.append("📊 *INVENTORY METRICS (Real-time):*\n")
        sb.append("• Total Key Inventory: $totalKeys Pcs\n")
        sb.append("• Handover to Guest/Staff: $totalIssued Pcs\n")
        sb.append("• Returned to Front Desk: $totalReturned Pcs\n")
        sb.append("• Missing / Lost Keys: $missingCount Pcs\n")
        sb.append("• Currently Out with Guest/Staff: $currentlyOut Pcs\n")
        sb.append("• *Remaining Available in FD: $remainingInFd Pcs*\n\n")

        sb.append("📋 *UNRETURNED / PENDING KEYS (${unreturnedList.size} entries):*\n")
        if (unreturnedList.isEmpty()) {
            sb.append("✅ All issued keys for this shift have been accounted for / returned.\n")
        } else {
            unreturnedList.forEachIndexed { idx, it ->
                val badge = if (it.isCarriedForward) "[CF] " else ""
                sb.append("${idx + 1}. $badge*${it.roomOrAccess}* - Qty: ${it.qtyIssued - it.qtyReturned} pcs | Issued by ${it.issuingStaff} | Guest: ${it.guestOrHolderName.ifEmpty { "N/A" }}\n")
            }
        }

        val missingList = items.filter { it.isMissing }
        if (missingList.isNotEmpty()) {
            sb.append("\n⚠️ *FLAGGED MISSING KEYS:*\n")
            missingList.forEachIndexed { idx, it ->
                sb.append("${idx + 1}. *${it.roomOrAccess}* (${it.missingQty.coerceAtLeast(1)} pcs) - ${it.remarks}\n")
            }
        }

        sb.append("\n━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        sb.append("Handover confirmed by Front Desk Operations.")
        return sb.toString()
    }
}
