import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

_test_database = tempfile.TemporaryDirectory()
os.environ["HOTEL_KEYS_DB"] = str(Path(_test_database.name) / "tests.db")

import main


class CarryForwardTests(unittest.TestCase):
    def setUp(self):
        self.database = tempfile.TemporaryDirectory()
        main.DB_FILE = Path(self.database.name) / "hotel_keys.db"
        main.init_db()

    def tearDown(self):
        self.database.cleanup()

    def _insert_log(
        self,
        *,
        shift_date,
        shift_period,
        qty_issue=2,
        qty_return=0,
        room_no="Room 101",
        is_missing=0,
        status="PENDING",
    ):
        with main._database() as connection:
            cursor = connection.execute(
                """
                INSERT INTO key_logs (
                    issued_date, staff_name, room_no, qty_issue, qty_return,
                    status, shift_date, shift_period, is_missing
                )
                VALUES ('issued', 'Staff', ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    room_no,
                    qty_issue,
                    qty_return,
                    status,
                    shift_date,
                    shift_period,
                    is_missing,
                ),
            )
            return cursor.lastrowid

    def _carry(self, shift_date, shift_period):
        item = main.CarryForwardRequest(
            shift_date=shift_date,
            shift_period=shift_period,
            issued_date="new shift",
            staff_name="New Shift Staff",
        )
        with patch.object(main, "_request_user", return_value={"id": 1}):
            return main.carry_forward_logs(item, authorization="Bearer test")

    def test_carries_only_open_prior_keys_and_keeps_history_idempotently(self):
        previous_night = self._insert_log(
            shift_date="2026-10-27",
            shift_period="Night (23:00 - 07:00)",
            qty_issue=4,
            qty_return=1,
        )
        same_day_night = self._insert_log(
            shift_date="2026-10-28",
            shift_period="Night (23:00 - 07:00)",
            room_no="Room 102",
        )
        self._insert_log(
            shift_date="2026-10-28",
            shift_period="Afternoon (15:00 - 23:00)",
            room_no="Future Shift Room",
        )
        self._insert_log(
            shift_date="2026-10-27",
            shift_period="Morning (07:00 - 15:00)",
            room_no="Returned Room",
            qty_issue=1,
            qty_return=1,
            status="RETURNED",
        )
        self._insert_log(
            shift_date="2026-10-27",
            shift_period="Morning (07:00 - 15:00)",
            room_no="Missing Room",
            is_missing=1,
            status="MISSING",
        )

        self.assertEqual(self._carry("2026-10-28", "Morning (07:00 - 15:00)"), {
            "carried_count": 2
        })
        self.assertEqual(self._carry("2026-10-28", "Morning (07:00 - 15:00)"), {
            "carried_count": 0
        })

        with main._database() as connection:
            rows = connection.execute(
                "SELECT * FROM key_logs ORDER BY id"
            ).fetchall()
        self.assertEqual(len(rows), 7)
        carried = [row for row in rows if row["is_carried_forward"]]
        self.assertEqual(
            {row["carried_from_id"] for row in carried},
            {str(previous_night), str(same_day_night)},
        )
        prior_carry = next(
            row for row in carried if row["carried_from_id"] == str(previous_night)
        )
        self.assertEqual(prior_carry["qty_issue"], 3)
        self.assertEqual(prior_carry["shift_date"], "2026-10-28")
        self.assertEqual(prior_carry["shift_period"], "Morning (07:00 - 15:00)")
        self.assertEqual(prior_carry["original_shift_date"], "2026-10-27")

    def test_next_shift_carries_the_active_snapshot_not_its_historical_parent(self):
        old_id = self._insert_log(
            shift_date="2026-10-27",
            shift_period="Night (23:00 - 07:00)",
            qty_issue=3,
            qty_return=1,
        )
        self._carry("2026-10-28", "Morning (07:00 - 15:00)")
        self.assertEqual(
            self._carry("2026-10-28", "Afternoon (15:00 - 23:00)"),
            {"carried_count": 1},
        )

        with main._database() as connection:
            rows = connection.execute(
                "SELECT * FROM key_logs ORDER BY id"
            ).fetchall()
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[1]["carried_from_id"], str(old_id))
        self.assertEqual(rows[2]["carried_from_id"], str(rows[1]["id"]))
        self.assertEqual(rows[2]["qty_issue"], 2)

    def test_afternoon_catches_up_unreturned_keys_from_same_day_night_shift(self):
        night_id = self._insert_log(
            shift_date="2026-10-28",
            shift_period="Night (23:00 - 07:00)",
            room_no="Overnight Room",
        )

        self.assertEqual(
            self._carry("2026-10-28", "Afternoon (15:00 - 23:00)"),
            {"carried_count": 1},
        )

        with main._database() as connection:
            carried = connection.execute(
                "SELECT * FROM key_logs WHERE carried_from_id = ?",
                (str(night_id),),
            ).fetchone()
        self.assertIsNotNone(carried)
        self.assertEqual(carried["shift_period"], "Afternoon (15:00 - 23:00)")

    def test_staff_cannot_forge_server_managed_carry_forward_rows(self):
        item = main.KeyLogItem(
            issued_date="28-Oct-2026 08:00 AM",
            staff_name="Staff",
            room_no="Room 103",
            qty_issue=1,
            is_carried_forward=True,
            carried_from_id="42",
        )
        with patch.object(main, "_request_user", return_value={"id": 1}):
            with self.assertRaises(main.HTTPException) as error:
                main.add_log(item, authorization="Bearer test")
        self.assertEqual(error.exception.status_code, 403)


class StaffRosterTests(unittest.TestCase):
    def setUp(self):
        self.database = tempfile.TemporaryDirectory()
        main.DB_FILE = Path(self.database.name) / "hotel_keys.db"
        main.init_db()

    def tearDown(self):
        self.database.cleanup()

    def test_seeded_roster_is_persisted_and_active_by_default(self):
        with main._database() as connection:
            rows = connection.execute(
                "SELECT name, hours, is_active FROM staff_roster ORDER BY id"
            ).fetchall()
        self.assertEqual(
            [(row["name"], row["hours"], row["is_active"]) for row in rows],
            [
                ("Jonayed", "08:00 - 17:00", 1),
                ("Azizul", "15:00 - 00:00", 1),
                ("Wahaj", "12:00 - 21:00", 1),
                ("Hanseef", "00:00 - 09:00", 1),
                ("Supervisor Hania", "08:00 - 17:00", 1),
                ("Manager Mehbuba", "08:00 - 17:00", 1),
            ],
        )

    def test_admin_can_add_edit_deactivate_and_remove_staff(self):
        admin = {"id": 1, "role": "admin"}
        with patch.object(main, "_require_admin"):
            added = main.add_staff_roster_member(
                main.StaffRosterCreate(name=" New Staff ", hours="09:00 - 18:00"),
                authorization="Bearer admin",
            )
            member_id = added["id"]
            edited = main.update_staff_roster_member(
                member_id,
                main.StaffRosterUpdate(
                    name="New Staff",
                    hours="10:00 - 19:00",
                    is_active=False,
                ),
                authorization="Bearer admin",
            )
            self.assertEqual(
                edited,
                {
                    "id": member_id,
                    "name": "New Staff",
                    "hours": "10:00 - 19:00",
                    "is_active": False,
                },
            )
            with patch.object(main, "_request_user", return_value=admin):
                active_rows = main.get_staff_roster(
                    include_inactive=False, authorization="Bearer admin"
                )
                all_rows = main.get_staff_roster(
                    include_inactive=True, authorization="Bearer admin"
                )
                self.assertNotIn(member_id, {row["id"] for row in active_rows})
                self.assertIn(member_id, {row["id"] for row in all_rows})
            removed = main.delete_staff_roster_member(
                member_id, authorization="Bearer admin"
            )
        self.assertEqual(removed, {"message": "Staff member removed"})

    def test_reception_cannot_view_inactive_roster_entries(self):
        with patch.object(
            main, "_request_user", return_value={"id": 2, "role": "reception"}
        ):
            with self.assertRaises(main.HTTPException) as error:
                main.get_staff_roster(
                    include_inactive=True, authorization="Bearer reception"
                )
        self.assertEqual(error.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
