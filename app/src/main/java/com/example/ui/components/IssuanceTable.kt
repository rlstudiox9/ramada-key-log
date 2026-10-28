package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AssignmentLate
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FiberNew
import androidx.compose.material.icons.filled.KeyOff
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.KeyIssuance
import com.example.ui.theme.RamadaBurgundy
import com.example.ui.theme.RamadaGold
import com.example.ui.theme.StatusDangerBg
import com.example.ui.theme.StatusDangerRed
import com.example.ui.theme.StatusPurpleBg
import com.example.ui.theme.StatusPurpleCarried
import com.example.ui.theme.StatusSuccessBg
import com.example.ui.theme.StatusSuccessGreen
import com.example.ui.theme.StatusWarningBg
import com.example.ui.theme.StatusWarningAmber

@Composable
fun IssuanceTable(
    issuances: List<KeyIssuance>,
    onMarkReturnClick: (KeyIssuance) -> Unit,
    onFlagMissingClick: (KeyIssuance) -> Unit,
    onEditClick: (KeyIssuance) -> Unit,
    onDeleteClick: (KeyIssuance) -> Unit,
    modifier: Modifier = Modifier
) {
    val horizontalScrollState = rememberScrollState()

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Table Header Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "KEY CARD & ACCESS ISSUANCE LOG (${issuances.size} RECORDS)",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "Swipe horizontally to view all columns",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }

            HorizontalDivider()

            if (issuances.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(36.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.KeyOff,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(42.dp)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "No key issuance records found for current filter",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                // Enterprise Grid Table (Horizontally scrollable for all enterprise columns)
                Box(modifier = Modifier.horizontalScroll(horizontalScrollState)) {
                    Column(modifier = Modifier.width(1080.dp)) {
                        // Columns Header
                        TableHeaderRow()
                        HorizontalDivider()

                        // Rows
                        issuances.forEachIndexed { index, item ->
                            TableRowItem(
                                index = index + 1,
                                item = item,
                                onMarkReturnClick = { onMarkReturnClick(item) },
                                onFlagMissingClick = { onFlagMissingClick(item) },
                                onEditClick = { onEditClick(item) },
                                onDeleteClick = { onDeleteClick(item) }
                            )
                            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TableHeaderRow() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(RamadaBurgundy.copy(alpha = 0.05f))
            .padding(vertical = 10.dp, horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        HeaderCell(text = "S.No", width = 50.dp, textAlign = TextAlign.Center)
        HeaderCell(text = "Issued Date & Time", width = 140.dp)
        HeaderCell(text = "Issuing Staff", width = 110.dp)
        HeaderCell(text = "Room / Access", width = 120.dp)
        HeaderCell(text = "Qty Issued", width = 75.dp, textAlign = TextAlign.Center)
        HeaderCell(text = "Qty Ret", width = 75.dp, textAlign = TextAlign.Center)
        HeaderCell(text = "Status", width = 110.dp, textAlign = TextAlign.Center)
        HeaderCell(text = "Returned Date", width = 130.dp)
        HeaderCell(text = "Key Received By", width = 110.dp)
        HeaderCell(text = "Remarks", width = 140.dp)
        HeaderCell(text = "Actions", width = 140.dp, textAlign = TextAlign.Center)
    }
}

@Composable
private fun HeaderCell(
    text: String,
    width: androidx.compose.ui.unit.Dp,
    textAlign: TextAlign = TextAlign.Start
) {
    Text(
        text = text,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        color = RamadaBurgundy,
        textAlign = textAlign,
        modifier = Modifier.width(width)
    )
}

@Composable
private fun TableRowItem(
    index: Int,
    item: KeyIssuance,
    onMarkReturnClick: () -> Unit,
    onFlagMissingClick: () -> Unit,
    onEditClick: () -> Unit,
    onDeleteClick: () -> Unit
) {
    val rowBg = if (item.isMissing) {
        StatusDangerBg.copy(alpha = 0.25f)
    } else if (item.isCarriedForward && item.isPending) {
        StatusPurpleBg.copy(alpha = 0.3f)
    } else if (index % 2 == 0) {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.15f)
    } else {
        MaterialTheme.colorScheme.surface
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(rowBg)
            .padding(vertical = 10.dp, horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 1. S.No
        Text(
            text = "$index",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(50.dp)
        )

        // 2. Issued Date & Time
        Column(modifier = Modifier.width(140.dp)) {
            Text(
                text = item.issuedDateTime,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (item.isCarriedForward) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Sync,
                        contentDescription = "Carried Forward",
                        tint = StatusPurpleCarried,
                        modifier = Modifier.size(10.dp)
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    Text(
                        text = "Carried Forward",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = StatusPurpleCarried
                    )
                }
            }
        }

        // 3. Issuing Staff
        Text(
            text = item.issuingStaff,
            fontSize = 11.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.width(110.dp)
        )

        // 4. Room No / Access
        Column(modifier = Modifier.width(120.dp)) {
            Text(
                text = item.roomOrAccess,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = RamadaBurgundy,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (item.guestOrHolderName.isNotBlank()) {
                Text(
                    text = item.guestOrHolderName,
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // 5. Qty Issued
        Text(
            text = "${item.qtyIssued} pcs",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(75.dp)
        )

        // 6. Qty Returned
        Text(
            text = "${item.qtyReturned} pcs",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = if (item.qtyReturned > 0) StatusSuccessGreen else MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(75.dp)
        )

        // 7. Status Badge
        Box(
            modifier = Modifier.width(110.dp),
            contentAlignment = Alignment.Center
        ) {
            when {
                item.isMissing -> {
                    StatusBadge(
                        label = "MISSING",
                        bgColor = StatusDangerBg,
                        textColor = StatusDangerRed
                    )
                }
                item.isFullyReturned -> {
                    StatusBadge(
                        label = "RETURNED",
                        bgColor = StatusSuccessBg,
                        textColor = StatusSuccessGreen
                    )
                }
                item.isCarriedForward -> {
                    StatusBadge(
                        label = "CARRIED [${item.qtyIssued - item.qtyReturned}]",
                        bgColor = StatusPurpleBg,
                        textColor = StatusPurpleCarried
                    )
                }
                else -> {
                    StatusBadge(
                        label = "PENDING [${item.qtyIssued - item.qtyReturned}]",
                        bgColor = StatusWarningBg,
                        textColor = StatusWarningAmber
                    )
                }
            }
        }

        // 8. Key Returned Date
        Text(
            text = item.returnedDateTime ?: "—",
            fontSize = 11.sp,
            color = if (item.returnedDateTime != null) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.width(130.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // 9. Key Received By
        Text(
            text = item.keyReceivedBy ?: "—",
            fontSize = 11.sp,
            color = if (item.keyReceivedBy != null) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.width(110.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // 10. Remarks
        Text(
            text = item.remarks.ifEmpty { "—" },
            fontSize = 10.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(140.dp)
        )

        // 11. Actions
        Row(
            modifier = Modifier.width(140.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (item.isPending) {
                // Quick Return button
                FilledTonalButton(
                    onClick = onMarkReturnClick,
                    shape = RoundedCornerShape(6.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = StatusSuccessBg,
                        contentColor = StatusSuccessGreen
                    ),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                    modifier = Modifier.testTag("action_return_${item.id}")
                ) {
                    Text("Return", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.width(4.dp))

                // Missing button
                IconButton(
                    onClick = onFlagMissingClick,
                    modifier = Modifier.size(28.dp).testTag("action_missing_${item.id}")
                ) {
                    Icon(
                        imageVector = Icons.Default.AssignmentLate,
                        contentDescription = "Flag Missing",
                        tint = StatusDangerRed,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            IconButton(
                onClick = onEditClick,
                modifier = Modifier.size(28.dp).testTag("action_edit_${item.id}")
            ) {
                Icon(
                    imageVector = Icons.Default.Edit,
                    contentDescription = "Edit Record",
                    tint = RamadaBurgundy,
                    modifier = Modifier.size(16.dp)
                )
            }

            IconButton(
                onClick = onDeleteClick,
                modifier = Modifier.size(28.dp).testTag("action_delete_${item.id}")
            ) {
                Icon(
                    imageVector = Icons.Default.DeleteOutline,
                    contentDescription = "Delete Record",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
fun StatusBadge(
    label: String,
    bgColor: Color,
    textColor: Color
) {
    Surface(
        shape = RoundedCornerShape(6.dp),
        color = bgColor
    ) {
        Text(
            text = label,
            fontSize = 9.sp,
            fontWeight = FontWeight.ExtraBold,
            color = textColor,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
        )
    }
}
