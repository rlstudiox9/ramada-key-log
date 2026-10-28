package com.example.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.KeyIssuance
import kotlinx.coroutines.flow.Flow

@Dao
interface KeyIssuanceDao {
    @Query("SELECT * FROM key_issuances ORDER BY timestampMillis DESC")
    fun getAllIssuances(): Flow<List<KeyIssuance>>

    @Query("SELECT * FROM key_issuances WHERE shiftDate = :date ORDER BY sNo ASC")
    fun getIssuancesByDate(date: String): Flow<List<KeyIssuance>>

    @Query("SELECT * FROM key_issuances WHERE shiftDate = :date AND shiftPeriod = :shift ORDER BY sNo ASC")
    fun getIssuancesByDateAndShift(date: String, shift: String): Flow<List<KeyIssuance>>

    @Query("SELECT * FROM key_issuances WHERE qtyReturned < qtyIssued AND shiftDate < :currentDate")
    suspend fun getUnreturnedFromPriorDays(currentDate: String): List<KeyIssuance>

    @Query("SELECT * FROM key_issuances WHERE id = :id")
    suspend fun getById(id: Long): KeyIssuance?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(issuance: KeyIssuance): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(issuances: List<KeyIssuance>)

    @Update
    suspend fun update(issuance: KeyIssuance)

    @Delete
    suspend fun delete(issuance: KeyIssuance)

    @Query("DELETE FROM key_issuances WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("SELECT COUNT(*) FROM key_issuances")
    suspend fun getCount(): Int
}
