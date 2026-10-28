package com.example.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.data.model.KeyIssuance
import com.example.ui.components.AddIssuanceDialog
import com.example.ui.components.EditEntryDialog
import com.example.ui.components.ExportAndHandoverDialog
import com.example.ui.components.FlagMissingDialog
import com.example.ui.components.HotelHeader
import com.example.ui.components.InventoryConfigDialog
import com.example.ui.components.InventoryMetricsWidget
import com.example.ui.components.IssuanceTable
import com.example.ui.components.ReturnKeyDialog
import com.example.ui.components.ShiftSelectorBar
import com.example.ui.components.StaffConfigDialog
import com.example.ui.theme.RamadaBurgundy
import com.example.ui.theme.RamadaGold
import com.example.ui.theme.StatusPurpleBg
import com.example.ui.theme.StatusPurpleCarried

@Composable
fun HotelKeyLogScreen(
    viewModel: KeyLogViewModel,
    modifier: Modifier = Modifier
) {
    val issuances by viewModel.filteredIssuances.collectAsStateWithLifecycle()
    val metrics by viewModel.metrics.collectAsStateWithLifecycle()
    val selectedDate by viewModel.selectedDate.collectAsStateWithLifecycle()
    val selectedShift by viewModel.selectedShift.collectAsStateWithLifecycle()
    val searchQuery by viewModel.searchQuery.collectAsStateWithLifecycle()
    val activeFilter by viewModel.activeFilter.collectAsStateWithLifecycle()
    val dutyStaffName by viewModel.dutyStaffName.collectAsStateWithLifecycle()
    val totalInventory by viewModel.totalInventory.collectAsStateWithLifecycle()
    val statusMsg by viewModel.statusMessage.collectAsStateWithLifecycle()

    val snackbarHostState = remember { SnackbarHostState() }

    // Dialog state
    var showAddDialog by remember { mutableStateOf(false) }
    var itemToReturn by remember { mutableStateOf<KeyIssuance?>(null) }
    var itemToFlagMissing by remember { mutableStateOf<KeyIssuance?>(null) }
    var itemToEdit by remember { mutableStateOf<KeyIssuance?>(null) }
    var showExportDialog by remember { mutableStateOf(false) }
    var exportInitialTab by remember { mutableStateOf(0) }
    var showInventoryDialog by remember { mutableStateOf(false) }
    var showStaffDialog by remember { mutableStateOf(false) }

    LaunchedEffect(statusMsg) {
        statusMsg?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearStatusMessage()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            HotelHeader(
                dutyStaffName = dutyStaffName,
                onEditStaffClick = { showStaffDialog = true },
                onSettingsClick = { showInventoryDialog = true },
                onExportClick = {
                    exportInitialTab = 1
                    showExportDialog = true
                },
                onHandoverClick = {
                    exportInitialTab = 0
                    showExportDialog = true
                },
                onCarryForwardClick = { viewModel.runAutoCarryForward() }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showAddDialog = true },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Issue Key / Card", fontWeight = FontWeight.Bold) },
                containerColor = RamadaBurgundy,
                contentColor = Color.White,
                modifier = Modifier.testTag("fab_issue_key")
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. Inventory Metrics Box (Real-time calculation widget)
            item {
                InventoryMetricsWidget(
                    metrics = metrics,
                    onEditTotalClick = { showInventoryDialog = true },
                    modifier = Modifier.testTag("inventory_metrics_box")
                )
            }

            // 2. Daily Shift & Auto Carry-Forward Engine Banner
            item {
                Card(
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(containerColor = StatusPurpleBg),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Sync,
                                contentDescription = null,
                                tint = StatusPurpleCarried,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = "Daily Shift & Auto Carry-Forward Engine",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = StatusPurpleCarried
                                )
                                Text(
                                    text = "Unreturned keys from previous 24h shifts automatically carry forward as active opening pending items.",
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = { viewModel.runAutoCarryForward() },
                            colors = ButtonDefaults.buttonColors(containerColor = StatusPurpleCarried),
                            shape = RoundedCornerShape(6.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.testTag("sync_carry_forward_button")
                        ) {
                            Text("Sync Now", fontSize = 11.sp, color = Color.White)
                        }
                    }
                }
            }

            // 3. Shift Selector, Search and Filter Tabs
            item {
                ShiftSelectorBar(
                    selectedDate = selectedDate,
                    selectedShift = selectedShift,
                    searchQuery = searchQuery,
                    activeFilter = activeFilter,
                    onDateSelect = { viewModel.setSelectedDate(it) },
                    onShiftSelect = { viewModel.setSelectedShift(it) },
                    onSearchChange = { viewModel.setSearchQuery(it) },
                    onFilterChange = { viewModel.setActiveFilter(it) }
                )
            }

            // 4. Issuance Log Table
            item {
                IssuanceTable(
                    issuances = issuances,
                    onMarkReturnClick = { itemToReturn = it },
                    onFlagMissingClick = { itemToFlagMissing = it },
                    onEditClick = { itemToEdit = it },
                    onDeleteClick = { viewModel.deleteEntry(it.id) }
                )
            }

            item {
                Spacer(modifier = Modifier.height(60.dp))
            }
        }
    }

    // Dialogs
    if (showAddDialog) {
        AddIssuanceDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { room, guest, qty, cat, remarks ->
                viewModel.addIssuance(room, guest, qty, cat, remarks)
                showAddDialog = false
            }
        )
    }

    itemToReturn?.let { item ->
        ReturnKeyDialog(
            item = item,
            defaultReceiver = dutyStaffName,
            onDismiss = { itemToReturn = null },
            onConfirm = { qty, receiver, notes ->
                viewModel.markAsReturned(item.id, qty, receiver, notes)
                itemToReturn = null
            }
        )
    }

    itemToFlagMissing?.let { item ->
        FlagMissingDialog(
            item = item,
            onDismiss = { itemToFlagMissing = null },
            onConfirm = { qty, reason ->
                viewModel.flagAsMissing(item.id, qty, reason)
                itemToFlagMissing = null
            }
        )
    }

    itemToEdit?.let { item ->
        EditEntryDialog(
            item = item,
            onDismiss = { itemToEdit = null },
            onConfirm = { updated ->
                viewModel.updateEntry(updated)
                itemToEdit = null
            }
        )
    }

    if (showExportDialog) {
        ExportAndHandoverDialog(
            handoverText = viewModel.getHandoverText(),
            csvContent = viewModel.getExportCsv(),
            jsonContent = viewModel.getExportJson(),
            initialTab = exportInitialTab,
            onDismiss = { showExportDialog = false }
        )
    }

    if (showInventoryDialog) {
        InventoryConfigDialog(
            currentTotal = totalInventory,
            onDismiss = { showInventoryDialog = false },
            onConfirm = { newTotal ->
                viewModel.setTotalInventory(newTotal)
                showInventoryDialog = false
            }
        )
    }

    if (showStaffDialog) {
        StaffConfigDialog(
            currentStaff = dutyStaffName,
            onDismiss = { showStaffDialog = false },
            onConfirm = { newStaff ->
                viewModel.setDutyStaffName(newStaff)
                showStaffDialog = false
            }
        )
    }
}
