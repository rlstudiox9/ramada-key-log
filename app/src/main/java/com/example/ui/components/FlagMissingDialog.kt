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
import androidx.compose.material.icons.filled.AssignmentLate
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
import com.example.ui.theme.StatusDangerRed

@Composable
fun FlagMissingDialog(
    item: KeyIssuance,
    onDismiss: () -> Unit,
    onConfirm: (missingQty: Int, reason: String) -> Unit
) {
    val pendingQty = (item.qtyIssued - item.qtyReturned).coerceAtLeast(1)
    var missingQty by remember { mutableIntStateOf(pendingQty) }
    var reason by remember { mutableStateOf("Guest reported lost outside hotel. Replacement card issued.") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.AssignmentLate,
                    contentDescription = null,
                    tint = StatusDangerRed,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Flag Key as Missing / Lost",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = StatusDangerRed
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

                OutlinedTextField(
                    value = reason,
                    onValueChange = { reason = it },
                    label = { Text("Incident Reason / Billing Note *") },
                    placeholder = { Text("e.g. Card not returned on checkout / lost by guest") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dialog_missing_reason_input")
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (reason.isNotBlank()) {
                        onConfirm(missingQty, reason)
                    }
                },
                enabled = reason.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = StatusDangerRed),
                modifier = Modifier.testTag("dialog_confirm_missing_button")
            ) {
                Text("Flag as Missing")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
