package com.example.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import com.example.data.model.KeyIssuance
import com.example.ui.theme.RamadaBurgundy

@Composable
fun EditEntryDialog(
    item: KeyIssuance,
    onDismiss: () -> Unit,
    onConfirm: (KeyIssuance) -> Unit
) {
    var roomOrAccess by remember { mutableStateOf(item.roomOrAccess) }
    var guestName by remember { mutableStateOf(item.guestOrHolderName) }
    var issuingStaff by remember { mutableStateOf(item.issuingStaff) }
    var qtyIssued by remember { mutableIntStateOf(item.qtyIssued) }
    var qtyReturned by remember { mutableIntStateOf(item.qtyReturned) }
    var keyReceivedBy by remember { mutableStateOf(item.keyReceivedBy ?: "") }
    var remarks by remember { mutableStateOf(item.remarks) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Edit,
                    contentDescription = null,
                    tint = RamadaBurgundy,
                    modifier = Modifier.size(22.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Edit Issuance #${item.sNo}",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = RamadaBurgundy
                )
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = roomOrAccess,
                    onValueChange = { roomOrAccess = it },
                    label = { Text("Room No / Access Card") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = guestName,
                    onValueChange = { guestName = it },
                    label = { Text("Guest / Holder Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = issuingStaff,
                    onValueChange = { issuingStaff = it },
                    label = { Text("Issuing Staff Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = qtyIssued.toString(),
                        onValueChange = { qtyIssued = it.toIntOrNull() ?: 1 },
                        label = { Text("Qty Issued") },
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = qtyReturned.toString(),
                        onValueChange = { qtyReturned = it.toIntOrNull() ?: 0 },
                        label = { Text("Qty Returned") },
                        modifier = Modifier.weight(1f)
                    )
                }
                OutlinedTextField(
                    value = keyReceivedBy,
                    onValueChange = { keyReceivedBy = it },
                    label = { Text("Key Received By") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = remarks,
                    onValueChange = { remarks = it },
                    label = { Text("Remarks") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val updated = item.copy(
                        roomOrAccess = roomOrAccess.trim(),
                        guestOrHolderName = guestName.trim(),
                        issuingStaff = issuingStaff.trim(),
                        qtyIssued = qtyIssued,
                        qtyReturned = qtyReturned,
                        keyReceivedBy = keyReceivedBy.trim().ifEmpty { null },
                        remarks = remarks.trim()
                    )
                    onConfirm(updated)
                },
                colors = ButtonDefaults.buttonColors(containerColor = RamadaBurgundy),
                modifier = Modifier.testTag("dialog_confirm_edit_button")
            ) {
                Text("Save Changes")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
