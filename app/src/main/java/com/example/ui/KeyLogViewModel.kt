package com.example.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.local.AppDatabase
import com.example.data.model.KeyIssuance
import com.example.data.repository.KeyLogRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class FilterTab(val label: String) {
    ALL("All Records"),
    PENDING("Active / Pending"),
    RETURNED("Returned"),
    MISSING("Missing"),
    CARRIED_FORWARD("Carried Forward")
}

data class InventoryMetrics(
    val totalKeys: Int = 70,
    val handoverToGuest: Int = 0,
    val returnFromGuest: Int = 0,
    val missingKeys: Int = 0,
    val remainingInFd: Int = 70,
    val activePendingCount: Int = 0
)

class KeyLogViewModel(application: Application) : AndroidViewModel(application) {

    private val repository: KeyLogRepository

    init {
        val db = AppDatabase.getDatabase(application)
        repository = KeyLogRepository(db.keyIssuanceDao())
        viewModelScope.launch {
            repository.seedInitialDataIfEmpty()
        }
    }

    private val todayString: String
        get() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private val _selectedDate = MutableStateFlow(todayString)
    val selectedDate: StateFlow<String> = _selectedDate.asStateFlow()

    private val _selectedShift = MutableStateFlow("Morning (07:00 - 15:00)")
    val selectedShift: StateFlow<String> = _selectedShift.asStateFlow()

    private val _totalInventory = MutableStateFlow(70)
    val totalInventory: StateFlow<Int> = _totalInventory.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _activeFilter = MutableStateFlow(FilterTab.ALL)
    val activeFilter: StateFlow<FilterTab> = _activeFilter.asStateFlow()

    private val _dutyStaffName = MutableStateFlow("Ahmad (FD)")
    val dutyStaffName: StateFlow<String> = _dutyStaffName.asStateFlow()

    private val _statusMessage = MutableStateFlow<String?>(null)
    val statusMessage: StateFlow<String?> = _statusMessage.asStateFlow()

    val rawIssuances: StateFlow<List<KeyIssuance>> = repository.allIssuances
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Filtered list based on date, shift, search query and filter tab
    val filteredIssuances: StateFlow<List<KeyIssuance>> = combine(
        rawIssuances,
        _selectedDate,
        _selectedShift,
        _searchQuery,
        _activeFilter
    ) { list, date, shift, query, filter ->
        list.filter { item ->
            // Date filter (allow viewing all or specific date)
            val matchesDate = if (date.isEmpty() || date == "ALL") true else item.shiftDate == date
            val matchesShift = if (shift.isEmpty() || shift == "All Shifts") true else item.shiftPeriod == shift
            val matchesQuery = if (query.isBlank()) true else {
                item.roomOrAccess.contains(query, ignoreCase = true) ||
                item.guestOrHolderName.contains(query, ignoreCase = true) ||
                item.issuingStaff.contains(query, ignoreCase = true) ||
                (item.keyReceivedBy?.contains(query, ignoreCase = true) == true) ||
                item.remarks.contains(query, ignoreCase = true)
            }
            val matchesTab = when (filter) {
                FilterTab.ALL -> true
                FilterTab.PENDING -> item.isPending
                FilterTab.RETURNED -> item.isFullyReturned
                FilterTab.MISSING -> item.isMissing
                FilterTab.CARRIED_FORWARD -> item.isCarriedForward
            }
            matchesDate && matchesShift && matchesQuery && matchesTab
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Metrics computed from the active view / shift items
    val metrics: StateFlow<InventoryMetrics> = combine(
        rawIssuances,
        _selectedDate,
        _selectedShift,
        _totalInventory
    ) { allItems, date, shift, totalCap ->
        val relevantItems = allItems.filter {
            (date.isEmpty() || date == "ALL" || it.shiftDate == date) &&
            (shift.isEmpty() || shift == "All Shifts" || it.shiftPeriod == shift)
        }
        val issuedSum = relevantItems.sumOf { it.qtyIssued }
        val returnedSum = relevantItems.sumOf { it.qtyReturned }
        val missingSum = relevantItems.filter { it.isMissing }.sumOf {
            if (it.missingQty > 0) it.missingQty else (it.qtyIssued - it.qtyReturned).coerceAtLeast(1)
        }
        val pendingCount = relevantItems.count { it.isPending }
        // Out in circulation:
        val currentlyWithGuest = (issuedSum - returnedSum - missingSum).coerceAtLeast(0)
        val remainingFd = (totalCap - currentlyWithGuest - missingSum).coerceIn(0, totalCap)

        InventoryMetrics(
            totalKeys = totalCap,
            handoverToGuest = issuedSum,
            returnFromGuest = returnedSum,
            missingKeys = missingSum,
            remainingInFd = remainingFd,
            activePendingCount = pendingCount
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), InventoryMetrics())

    fun setSelectedDate(date: String) {
        _selectedDate.value = date
    }

    fun setSelectedShift(shift: String) {
        _selectedShift.value = shift
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setActiveFilter(filter: FilterTab) {
        _activeFilter.value = filter
    }

    fun setDutyStaffName(name: String) {
        _dutyStaffName.value = name
    }

    fun setTotalInventory(total: Int) {
        _totalInventory.value = total.coerceAtLeast(1)
    }

    fun clearStatusMessage() {
        _statusMessage.value = null
    }

    fun addIssuance(
        roomOrAccess: String,
        guestOrHolderName: String,
        qtyIssued: Int,
        category: String,
        remarks: String
    ) {
        viewModelScope.launch {
            val nowFmt = SimpleDateFormat("dd-MMM-yyyy hh:mm a", Locale.US).format(Date())
            val currentList = rawIssuances.value.filter { it.shiftDate == _selectedDate.value }
            val nextSNo = currentList.size + 1

            val newRecord = KeyIssuance(
                sNo = nextSNo,
                shiftDate = _selectedDate.value,
                shiftPeriod = _selectedShift.value,
                issuedDateTime = nowFmt,
                issuingStaff = _dutyStaffName.value,
                roomOrAccess = roomOrAccess.trim(),
                guestOrHolderName = guestOrHolderName.trim(),
                qtyIssued = qtyIssued,
                qtyReturned = 0,
                isMissing = false,
                missingQty = 0,
                returnedDateTime = null,
                keyReceivedBy = null,
                remarks = remarks.trim(),
                isCarriedForward = false,
                category = category,
                timestampMillis = System.currentTimeMillis()
            )
            repository.insert(newRecord)
            _statusMessage.value = "Card issued for ${newRecord.roomOrAccess} successfully"
        }
    }

    fun markAsReturned(
        id: Long,
        qtyReturned: Int,
        receivedBy: String,
        returnNotes: String = ""
    ) {
        viewModelScope.launch {
            val existing = rawIssuances.value.firstOrNull { it.id == id } ?: return@launch
            val nowFmt = SimpleDateFormat("dd-MMM-yyyy hh:mm a", Locale.US).format(Date())
            val updatedRemarks = if (returnNotes.isNotBlank()) {
                if (existing.remarks.isNotBlank()) "${existing.remarks} | Return notes: $returnNotes" else "Return notes: $returnNotes"
            } else existing.remarks

            val updated = existing.copy(
                qtyReturned = (existing.qtyReturned + qtyReturned).coerceAtMost(existing.qtyIssued),
                returnedDateTime = nowFmt,
                keyReceivedBy = receivedBy.ifBlank { _dutyStaffName.value },
                remarks = updatedRemarks,
                isMissing = false
            )
            repository.update(updated)
            _statusMessage.value = "Key returned for ${existing.roomOrAccess} ($qtyReturned pcs)"
        }
    }

    fun flagAsMissing(
        id: Long,
        missingQty: Int,
        reason: String
    ) {
        viewModelScope.launch {
            val existing = rawIssuances.value.firstOrNull { it.id == id } ?: return@launch
            val updatedRemarks = if (reason.isNotBlank()) {
                if (existing.remarks.isNotBlank()) "${existing.remarks} | MISSING: $reason" else "MISSING: $reason"
            } else existing.remarks

            val updated = existing.copy(
                isMissing = true,
                missingQty = if (missingQty > 0) missingQty else (existing.qtyIssued - existing.qtyReturned).coerceAtLeast(1),
                remarks = updatedRemarks
            )
            repository.update(updated)
            _statusMessage.value = "Key flagged as MISSING for ${existing.roomOrAccess}"
        }
    }

    fun updateEntry(updated: KeyIssuance) {
        viewModelScope.launch {
            repository.update(updated)
            _statusMessage.value = "Record #${updated.sNo} updated"
        }
    }

    fun deleteEntry(id: Long) {
        viewModelScope.launch {
            repository.deleteById(id)
            _statusMessage.value = "Entry deleted"
        }
    }

    fun runAutoCarryForward() {
        viewModelScope.launch {
            val count = repository.carryForwardUnreturnedKeys(
                targetDate = _selectedDate.value,
                targetShift = _selectedShift.value,
                staffName = _dutyStaffName.value
            )
            if (count > 0) {
                _statusMessage.value = "Auto Carry-Forward: $count unreturned key records brought into active shift"
            } else {
                _statusMessage.value = "No unreturned keys pending from prior days"
            }
        }
    }

    fun getExportCsv(): String {
        return repository.exportToCsv(rawIssuances.value, _totalInventory.value)
    }

    fun getExportJson(): String {
        return repository.exportToJson(rawIssuances.value, _totalInventory.value)
    }

    fun getHandoverText(): String {
        return repository.generateShiftHandoverReport(
            items = filteredIssuances.value.ifEmpty { rawIssuances.value },
            totalKeys = _totalInventory.value,
            activeShift = _selectedShift.value,
            activeDate = _selectedDate.value,
            dutyStaff = _dutyStaffName.value
        )
    }
}
