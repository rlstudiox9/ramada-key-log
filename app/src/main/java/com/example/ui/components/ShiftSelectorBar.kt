package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.example.ui.FilterTab
import com.example.ui.theme.RamadaBurgundy
import com.example.ui.theme.RamadaGold
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
fun ShiftSelectorBar(
    selectedDate: String,
    selectedShift: String,
    searchQuery: String,
    activeFilter: FilterTab,
    onDateSelect: (String) -> Unit,
    onShiftSelect: (String) -> Unit,
    onSearchChange: (String) -> Unit,
    onFilterChange: (FilterTab) -> Unit,
    modifier: Modifier = Modifier
) {
    var showShiftDropdown by remember { mutableStateOf(false) }
    var showDateDropdown by remember { mutableStateOf(false) }

    val todayStr = remember { SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()) }
    val yesterdayStr = remember {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -1)
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)
    }

    val shifts = listOf(
        "Morning (07:00 - 15:00)",
        "Afternoon (15:00 - 23:00)",
        "Night (23:00 - 07:00)",
        "All Shifts"
    )

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Controls Row: Date Selector & Shift Dropdown
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Date Switcher
            Box {
                OutlinedButton(
                    onClick = { showDateDropdown = true },
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.testTag("date_picker_button")
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = "Date",
                        tint = RamadaBurgundy,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = when (selectedDate) {
                            todayStr -> "Today ($selectedDate)"
                            yesterdayStr -> "Yesterday ($selectedDate)"
                            "ALL" -> "All Dates"
                            else -> selectedDate
                        },
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                DropdownMenu(
                    expanded = showDateDropdown,
                    onDismissRequest = { showDateDropdown = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Today ($todayStr)") },
                        onClick = {
                            onDateSelect(todayStr)
                            showDateDropdown = false
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Yesterday ($yesterdayStr)") },
                        onClick = {
                            onDateSelect(yesterdayStr)
                            showDateDropdown = false
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("All Dates (Full Archive)") },
                        onClick = {
                            onDateSelect("ALL")
                            showDateDropdown = false
                        }
                    )
                }
            }

            // Shift Selector
            Box {
                OutlinedButton(
                    onClick = { showShiftDropdown = true },
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.testTag("shift_selector_button")
                ) {
                    Icon(
                        imageVector = Icons.Default.Schedule,
                        contentDescription = "Shift",
                        tint = RamadaBurgundy,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = selectedShift,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                DropdownMenu(
                    expanded = showShiftDropdown,
                    onDismissRequest = { showShiftDropdown = false }
                ) {
                    shifts.forEach { shift ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    text = shift,
                                    fontWeight = if (shift == selectedShift) FontWeight.Bold else FontWeight.Normal,
                                    color = if (shift == selectedShift) RamadaBurgundy else MaterialTheme.colorScheme.onSurface
                                )
                            },
                            onClick = {
                                onShiftSelect(shift)
                                showShiftDropdown = false
                            }
                        )
                    }
                }
            }
        }

        // Search Bar
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchChange,
            placeholder = { Text("Search by Room (e.g. 405), Staff, Guest or Card...", fontSize = 12.sp) },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Search",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            },
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(imageVector = Icons.Default.Clear, contentDescription = "Clear Search")
                    }
                }
            },
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .testTag("search_input_field")
        )

        // Filter Tabs (Horizontal scrollable chips)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            FilterTab.values().forEach { tab ->
                val isSelected = activeFilter == tab
                FilterChip(
                    selected = isSelected,
                    onClick = { onFilterChange(tab) },
                    label = {
                        Text(
                            text = tab.label,
                            fontSize = 11.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                        )
                    },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = RamadaBurgundy,
                        selectedLabelColor = Color.White
                    ),
                    modifier = Modifier.testTag("filter_chip_${tab.name.lowercase()}")
                )
            }
        }
    }
}
