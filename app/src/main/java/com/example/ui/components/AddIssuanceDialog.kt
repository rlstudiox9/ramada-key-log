package com.example.ui.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.RamadaBurgundy
import com.example.ui.theme.RamadaGold

@Composable
fun AddIssuanceDialog(
    onDismiss: () -> Unit,
    onConfirm: (roomOrAccess: String, guestName: String, qty: Int, category: String, remarks: String) -> Unit
) {
    var roomOrAccess by remember { mutableStateOf("") }
    var guestName by remember { mutableStateOf("") }
    var qty by remember { mutableIntStateOf(1) }
    var category by remember { mutableStateOf("Guest Key Card") }
    var remarks by remember { mutableStateOf("") }

    val roomSuggestions = listOf("Room 105", "Room 204", "Room 304", "Room 405", "Room 512", "Room 701 (Suite)", "Master Key FD-01", "HK 3rd Floor", "Eng ENG-02")
    val categories = listOf("Guest Key Card", "Master / Floor Card", "System Access")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Key,
                    contentDescription = null,
                    tint = RamadaBurgundy,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "New Key / Access Issuance",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = RamadaBurgundy
                )
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Category Chips
                Text("Issuance Category:", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    categories.forEach { cat ->
                        FilterChip(
                            selected = category == cat,
                            onClick = { category = cat },
                            label = { Text(cat, fontSize = 11.sp) }
                        )
                    }
                }

                // Room / Access input
                OutlinedTextField(
                    value = roomOrAccess,
                    onValueChange = { roomOrAccess = it },
                    label = { Text("Room No / Access Card ID *") },
                    placeholder = { Text("e.g. Room 405 or Master Key FD-02") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_room_input")
                )

                // Quick Suggestions Chips
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    roomSuggestions.forEach { suggestion ->
                        Surface(
                            onClick = { roomOrAccess = suggestion },
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier.padding(vertical = 2.dp)
                        ) {
                            Text(
                                text = suggestion,
                                fontSize = 10.sp,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                // Guest or Holder Name
                OutlinedTextField(
                    value = guestName,
                    onValueChange = { guestName = it },
                    label = { Text("Guest / Card Holder Name") },
                    placeholder = { Text("e.g. Mr. David Miller or HK Staff") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_guest_input")
                )

                // Quantity Stepper
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Quantity Issued (Pcs):", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(
                            onClick = { if (qty > 1) qty-- },
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(Icons.Default.Remove, contentDescription = "Decrease")
                        }
                        Text(
                            text = "$qty pcs",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(horizontal = 8.dp)
                        )
                        IconButton(
                            onClick = { if (qty < 10) qty++ },
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = "Increase")
                        }
                    }
                }

                // Remarks
                OutlinedTextField(
                    value = remarks,
                    onValueChange = { remarks = it },
                    label = { Text("Remarks / Purpose") },
                    placeholder = { Text("e.g. Additional card for family / checkout tomorrow") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_remarks_input")
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (roomOrAccess.isNotBlank()) {
                        onConfirm(roomOrAccess, guestName, qty, category, remarks)
                    }
                },
                enabled = roomOrAccess.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = RamadaBurgundy),
                modifier = Modifier.testTag("dialog_confirm_add_button")
            ) {
                Text("Issue Card")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
