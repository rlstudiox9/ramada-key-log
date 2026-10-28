package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.AssignmentLate
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.InventoryMetrics
import com.example.ui.theme.RamadaBurgundy
import com.example.ui.theme.RamadaGold
import com.example.ui.theme.RamadaGoldDark
import com.example.ui.theme.StatusDangerBg
import com.example.ui.theme.StatusDangerRed
import com.example.ui.theme.StatusSuccessBg
import com.example.ui.theme.StatusSuccessGreen
import com.example.ui.theme.StatusWarningBg
import com.example.ui.theme.StatusWarningAmber

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun InventoryMetricsWidget(
    metrics: InventoryMetrics,
    onEditTotalClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Inventory2,
                        contentDescription = "Inventory Box",
                        tint = RamadaBurgundy,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "FRONT DESK KEY INVENTORY & REAL-TIME AUDIT",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (metrics.remainingInFd >= 20) StatusSuccessBg else StatusWarningBg
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(RoundedCornerShape(3.dp))
                                .background(if (metrics.remainingInFd >= 20) StatusSuccessGreen else StatusWarningAmber)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = if (metrics.remainingInFd >= 20) "Stock Healthy" else "Stock Low",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (metrics.remainingInFd >= 20) StatusSuccessGreen else StatusWarningAmber
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // 5 Core Metric Cards
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                maxItemsInEachRow = 5
            ) {
                // 1. Total Keys (Configurable default 70)
                MetricTile(
                    title = "Total Keys",
                    count = "${metrics.totalKeys}",
                    unit = "Pcs",
                    icon = Icons.Default.Inventory2,
                    accentColor = RamadaBurgundy,
                    bgColor = RamadaBurgundy.copy(alpha = 0.08f),
                    subtitle = "FD Inventory",
                    isClickable = true,
                    onClick = onEditTotalClick,
                    testTag = "metric_total_keys"
                )

                // 2. Handover to Guest (Total Issued)
                MetricTile(
                    title = "Handover to Guest",
                    count = "${metrics.handoverToGuest}",
                    unit = "Issued",
                    icon = Icons.AutoMirrored.Filled.ArrowForward,
                    accentColor = Color(0xFF2563EB),
                    bgColor = Color(0xFFEFF6FF),
                    subtitle = "In Circulation",
                    testTag = "metric_handover_guest"
                )

                // 3. Return from Guest (Total Returned)
                MetricTile(
                    title = "Return from Guest",
                    count = "${metrics.returnFromGuest}",
                    unit = "Returned",
                    icon = Icons.AutoMirrored.Filled.Undo,
                    accentColor = StatusSuccessGreen,
                    bgColor = StatusSuccessBg,
                    subtitle = "Safely Restocked",
                    testTag = "metric_return_guest"
                )

                // 4. Missing Keys (Unreturned/Flagged)
                MetricTile(
                    title = "Missing Keys",
                    count = "${metrics.missingKeys}",
                    unit = "Missing",
                    icon = Icons.Default.AssignmentLate,
                    accentColor = StatusDangerRed,
                    bgColor = StatusDangerBg,
                    subtitle = if (metrics.missingKeys == 0) "Zero Loss" else "Requires Charge",
                    testTag = "metric_missing_keys"
                )

                // 5. Remaining in FD (Available in stock)
                MetricTile(
                    title = "Remaining in FD",
                    count = "${metrics.remainingInFd}",
                    unit = "Available",
                    icon = Icons.Default.CheckCircle,
                    accentColor = if (metrics.remainingInFd >= 20) RamadaGoldDark else StatusDangerRed,
                    bgColor = if (metrics.remainingInFd >= 20) RamadaGold.copy(alpha = 0.15f) else StatusDangerBg,
                    subtitle = "At Front Desk",
                    isHighlighted = true,
                    testTag = "metric_remaining_fd"
                )
            }
        }
    }
}

@Composable
fun MetricTile(
    title: String,
    count: String,
    unit: String,
    icon: ImageVector,
    accentColor: Color,
    bgColor: Color,
    subtitle: String,
    modifier: Modifier = Modifier,
    isClickable: Boolean = false,
    isHighlighted: Boolean = false,
    onClick: () -> Unit = {},
    testTag: String = ""
) {
    Surface(
        modifier = modifier
            .testTag(testTag)
            .clickable(enabled = isClickable, onClick = onClick),
        shape = RoundedCornerShape(10.dp),
        color = bgColor,
        border = if (isHighlighted) androidx.compose.foundation.BorderStroke(1.5.dp, accentColor) else null
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = title,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = accentColor
                )
                if (isClickable) {
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = "Edit",
                        tint = accentColor.copy(alpha = 0.7f),
                        modifier = Modifier.size(12.dp)
                    )
                } else {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = accentColor.copy(alpha = 0.8f),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = count,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = accentColor
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = unit,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = accentColor.copy(alpha = 0.8f),
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }

            Text(
                text = subtitle,
                fontSize = 9.sp,
                fontWeight = FontWeight.Normal,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
