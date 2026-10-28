package com.example.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import com.example.ui.theme.StatusSuccessGreen

@Composable
fun ReturnKeyDialog(
    item: KeyIssuance,
    defaultReceiver: String,
    onDismiss: () -> Unit,
    onConfirm: (returnQty: Int, receiver: String, remarks: String) -> Unit
) {
    val pendingQty = (item.qtyIssued - item.qtyReturned).coerceAtLeast(1)
    var returnQty by remember { mutableIntStateOf(pendingQty) }
    var receiver by remember { mutableStateOf(defaultReceiver) }
    var returnNotes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Undo,
                    contentDescription = null,
                    tint = StatusSuccessGreen,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Mark Key as Returned",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = StatusSuccessGreen
                )
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = "Room/Card: ${item.roomOrAccess} (${item.guestOrHolderName.ifEmpty { "Guest" }})",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Issued: ${item.qtyIssued} pcs | Already returned: ${item.qtyReturned} pcs | Pending: $pendingQty pcs",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // Return Quantity Stepper
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Qty Returning Now:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(
                            onClick = { if (returnQty > 1) returnQty-- },
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(Icons.Default.Remove, contentDescription = "Decrease")
                        }
                        Text(
                            text = "$returnQty pcs",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(horizontal = 8.dp)
                        )
                        IconButton(
                            onClick = { if (returnQty < pendingQty) returnQty++ },
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = "Increase")
                        }
                    }
                }

                OutlinedTextField(
                    value = receiver,
                    onValueChange = { receiver = it },
                    label = { Text("Key Received By (Staff Name) *") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_receiver_input")
                )

                OutlinedTextField(
                    value = returnNotes,
                    onValueChange = { returnNotes = it },
                    label = { Text("Return Condition / Notes") },
                    placeholder = { Text("e.g. Card in good condition, guest departed") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_return_notes_input")
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (receiver.isNotBlank()) {
                        onConfirm(returnQty, receiver, returnNotes)
                    }
                },
                enabled = receiver.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = StatusSuccessGreen),
                modifier = Modifier.testTag("dialog_confirm_return_button")
            ) {
                Text("Confirm Return")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
