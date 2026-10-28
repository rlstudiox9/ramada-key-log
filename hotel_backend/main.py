import hmac
import hashlib
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Iterator, Literal, Optional

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Ramada Hotel Key Log API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = Path(
    os.getenv("HOTEL_KEYS_DB", str(Path(__file__).with_name("hotel_keys.db")))
)
ADMIN_TOKEN_TTL_SECONDS = 8 * 60 * 60
AUTH_SESSION_TTL_DAYS = 30
ADMIN_LOGIN_WINDOW_SECONDS = 15 * 60
ADMIN_LOGIN_MAX_ATTEMPTS = 5
PASSWORD_HASH_ITERATIONS = 310_000
admin_tokens: Dict[str, float] = {}
admin_login_attempts: Dict[str, list[float]] = {}
auth_login_attempts: Dict[str, list[float]] = {}


@contextmanager
def _database() -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(DB_FILE, timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA busy_timeout = 10000")
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def init_db() -> None:
    with _database() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS key_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                issued_date TEXT,
                staff_name TEXT,
                room_no TEXT,
                qty_issue INTEGER,
                qty_return INTEGER,
                status TEXT,
                returned_time TEXT,
                received_by TEXT,
                remarks TEXT,
                guest_or_holder_name TEXT NOT NULL DEFAULT '',
                shift_date TEXT NOT NULL DEFAULT '',
                shift_period TEXT NOT NULL DEFAULT '',
                category TEXT NOT NULL DEFAULT 'Guest Key Card',
                is_missing INTEGER NOT NULL DEFAULT 0,
                missing_qty INTEGER NOT NULL DEFAULT 0,
                is_carried_forward INTEGER NOT NULL DEFAULT 0,
                original_shift_date TEXT,
                carried_from_id TEXT
            )
            """
        )
        columns = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(key_logs)").fetchall()
        }
        new_columns = {
            "guest_or_holder_name": "TEXT NOT NULL DEFAULT ''",
            "shift_date": "TEXT NOT NULL DEFAULT ''",
            "shift_period": "TEXT NOT NULL DEFAULT ''",
            "category": "TEXT NOT NULL DEFAULT 'Guest Key Card'",
            "is_missing": "INTEGER NOT NULL DEFAULT 0",
            "missing_qty": "INTEGER NOT NULL DEFAULT 0",
            "is_carried_forward": "INTEGER NOT NULL DEFAULT 0",
            "original_shift_date": "TEXT",
            "carried_from_id": "TEXT",
        }
        for column, definition in new_columns.items():
            if column not in columns:
                connection.execute(
                    f"ALTER TABLE key_logs ADD COLUMN {column} {definition}"
                )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_key_logs_shift_history
            ON key_logs (shift_date, shift_period, id)
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_key_logs_carried_from
            ON key_logs (carried_from_id)
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE COLLATE NOCASE,
                display_name TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL CHECK (role IN ('reception', 'admin')),
                created_at TEXT NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS auth_sessions (
                token_hash TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                revoked_at TEXT
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS password_reset_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                requested_username TEXT NOT NULL,
                created_at TEXT NOT NULL,
                resolved_at TEXT
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                setting_key TEXT PRIMARY KEY,
                setting_value TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            INSERT OR IGNORE INTO app_settings (setting_key, setting_value)
            VALUES ('total_inventory', '70')
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS staff_roster (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL COLLATE NOCASE UNIQUE,
                hours TEXT NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
                    CHECK (is_active IN (0, 1))
            )
            """
        )
        connection.executemany(
            """
            INSERT OR IGNORE INTO staff_roster (name, hours)
            VALUES (?, ?)
            """,
            [
                ("Jonayed", "08:00 - 17:00"),
                ("Azizul", "15:00 - 00:00"),
                ("Wahaj", "12:00 - 21:00"),
                ("Hanseef", "00:00 - 09:00"),
                ("Supervisor Hania", "08:00 - 17:00"),
                ("Manager Mehbuba", "08:00 - 17:00"),
            ],
        )


init_db()


class AdminLoginRequest(BaseModel):
    pin: str = Field(min_length=1, max_length=128)


class AuthCredentials(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class SignUpRequest(AuthCredentials):
    display_name: str = Field(min_length=1, max_length=100)


class PasswordResetRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)


class AdminPasswordReset(BaseModel):
    password: str = Field(min_length=8, max_length=128)


class OwnPasswordChange(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class InventoryLimitUpdate(BaseModel):
    total_inventory: int = Field(ge=0, le=1_000_000)


class KeyLogItem(BaseModel):
    issued_date: str
    staff_name: str
    room_no: str
    qty_issue: int = Field(ge=1)
    qty_return: int = Field(default=0, ge=0)
    status: Literal["PENDING", "RETURNED", "MISSING", "LOST"] = "PENDING"
    returned_time: Optional[str] = ""
    received_by: Optional[str] = ""
    remarks: Optional[str] = ""
    guest_or_holder_name: str = ""
    shift_date: str = ""
    shift_period: str = ""
    category: str = "Guest Key Card"
    is_missing: bool = False
    missing_qty: int = Field(default=0, ge=0)
    is_carried_forward: bool = False
    original_shift_date: Optional[str] = None
    carried_from_id: Optional[str] = None


class UpdateLogItem(BaseModel):
    qty_return: int = Field(ge=0)
    status: Literal["PENDING", "RETURNED", "MISSING", "LOST"]
    returned_time: str
    received_by: str
    remarks: Optional[str] = ""
    is_missing: bool = False
    missing_qty: int = Field(default=0, ge=0)


class CarryForwardRequest(BaseModel):
    shift_date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    shift_period: str = Field(min_length=1, max_length=64)
    issued_date: str = Field(min_length=1, max_length=64)
    staff_name: str = Field(min_length=1, max_length=100)


class StaffRosterCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    hours: str = Field(min_length=1, max_length=64)


class StaffRosterUpdate(StaffRosterCreate):
    is_active: bool


def _admin_pin() -> Optional[str]:
    return os.getenv("RAMADA_ADMIN_PIN") or os.getenv("ADMIN_PIN")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def _utc_iso(value: datetime) -> str:
    return value.isoformat().replace("+00:00", "Z")


def _hash_password(password: str, salt: Optional[bytes] = None) -> str:
    salt = salt or secrets.token_bytes(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt, PASSWORD_HASH_ITERATIONS
    )
    return (
        f"pbkdf2_sha256${PASSWORD_HASH_ITERATIONS}$"
        f"{salt.hex()}${derived.hex()}"
    )


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_text, salt_hex, expected_hash = stored_hash.split("$")
        if algorithm != "pbkdf2_sha256":
            return False
        derived = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            bytes.fromhex(salt_hex),
            int(iterations_text),
        )
        return hmac.compare_digest(derived.hex(), expected_hash)
    except (ValueError, TypeError):
        return False


def _public_user(user: sqlite3.Row) -> dict:
    return {
        "id": user["id"],
        "username": user["username"],
        "display_name": user["display_name"],
        "role": user["role"],
    }


def _create_auth_session(user: sqlite3.Row) -> dict:
    token = secrets.token_urlsafe(48)
    now = _utc_now()
    expires_at = now + timedelta(days=AUTH_SESSION_TTL_DAYS)
    with _database() as connection:
        connection.execute(
            """
            INSERT INTO auth_sessions (token_hash, user_id, created_at, expires_at)
            VALUES (?, ?, ?, ?)
            """,
            (
                hashlib.sha256(token.encode("ascii")).hexdigest(),
                user["id"],
                _utc_iso(now),
                _utc_iso(expires_at),
            ),
        )
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": _utc_iso(expires_at),
        "user": _public_user(user),
    }


def _user_for_token(token: str) -> Optional[dict]:
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    with _database() as connection:
        user = connection.execute(
            """
            SELECT users.id, users.username, users.display_name, users.role
            FROM auth_sessions
            JOIN users ON users.id = auth_sessions.user_id
            WHERE auth_sessions.token_hash = ?
              AND auth_sessions.revoked_at IS NULL
              AND auth_sessions.expires_at > ?
              AND users.is_active = 1
            """,
            (token_hash, _utc_iso(_utc_now())),
        ).fetchone()
    return dict(user) if user is not None else None


def _request_user(authorization: Optional[str]) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication required")
    token = authorization.removeprefix("Bearer ").strip()
    user = _user_for_token(token)
    if user is None:
        raise HTTPException(status_code=401, detail="Session expired; sign in again")
    return user


def _auth_rate_key(request: Request, username: str) -> str:
    client_ip = request.client.host if request.client else "unknown"
    return f"{client_ip}:{username.lower()}"


def _auth_rate_limited(request: Request, username: str) -> bool:
    key = _auth_rate_key(request, username)
    now = time.monotonic()
    attempts = [
        attempt
        for attempt in auth_login_attempts.get(key, [])
        if now - attempt < ADMIN_LOGIN_WINDOW_SECONDS
    ]
    auth_login_attempts[key] = attempts
    return len(attempts) >= ADMIN_LOGIN_MAX_ATTEMPTS


def _record_auth_failure(request: Request, username: str) -> None:
    key = _auth_rate_key(request, username)
    auth_login_attempts.setdefault(key, []).append(time.monotonic())


def _seed_admin_account() -> None:
    password = os.getenv("RAMADA_ADMIN_PASSWORD") or _admin_pin()
    if not password:
        return
    username = (
        os.getenv("RAMADA_ADMIN_USERNAME", "admin").strip().lower() or "admin"
    )
    if not re.fullmatch(r"[a-z0-9._-]{3,64}", username):
        raise RuntimeError("RAMADA_ADMIN_USERNAME must be 3-64 valid username characters")
    now = _utc_iso(_utc_now())
    with _database() as connection:
        account = connection.execute(
            "SELECT id FROM users WHERE username = ? COLLATE NOCASE", (username,)
        ).fetchone()
        if account is None:
            connection.execute(
                """
                INSERT INTO users
                    (username, display_name, password_hash, role, created_at)
                VALUES (?, 'Ramada Administrator', ?, 'admin', ?)
                """,
                (username, _hash_password(password), now),
            )
        else:
            connection.execute(
                """
                UPDATE users
                SET display_name = 'Ramada Administrator',
                    password_hash = ?, role = 'admin', is_active = 1
                WHERE id = ?
                """,
                (_hash_password(password), account["id"]),
            )


def _require_admin(authorization: Optional[str]) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Admin authentication required")
    token = authorization.removeprefix("Bearer ").strip()
    user = _user_for_token(token)
    if user is not None:
        if user["role"] != "admin":
            raise HTTPException(status_code=403, detail="Admin role required")
        return
    expires_at = admin_tokens.get(token)
    if expires_at is None or expires_at <= time.monotonic():
        admin_tokens.pop(token, None)
        raise HTTPException(status_code=401, detail="Admin session expired")


def _normalize_admin_item(item: KeyLogItem) -> KeyLogItem:
    values = item.dict()
    is_missing = item.is_missing or item.status in {"MISSING", "LOST"}
    if item.qty_return > item.qty_issue:
        raise HTTPException(
            status_code=422, detail="Returned quantity cannot exceed issued quantity"
        )
    missing_qty = item.missing_qty
    if is_missing:
        if item.qty_return == item.qty_issue:
            raise HTTPException(
                status_code=422,
                detail="A fully returned entry cannot also be missing",
            )
        missing_qty = missing_qty or item.qty_issue - item.qty_return
        if missing_qty > item.qty_issue - item.qty_return:
            raise HTTPException(
                status_code=422,
                detail="Missing quantity cannot exceed unreturned quantity",
            )
    else:
        missing_qty = 0
        if item.status == "RETURNED" and item.qty_return != item.qty_issue:
            raise HTTPException(
                status_code=422,
                detail="A returned entry must have all issued keys returned",
            )
        if item.status == "PENDING" and item.qty_return == item.qty_issue:
            raise HTTPException(
                status_code=422,
                detail="A fully returned entry cannot remain pending",
            )
    values["is_missing"] = is_missing
    values["missing_qty"] = missing_qty
    values["status"] = "MISSING" if is_missing else item.status
    return KeyLogItem(**values)


_seed_admin_account()


@app.post("/auth/signup", status_code=201)
def sign_up(item: SignUpRequest):
    username = item.username.strip().lower()
    display_name = item.display_name.strip()
    if not re.fullmatch(r"[a-z0-9._-]{3,64}", username):
        raise HTTPException(
            status_code=422,
            detail="Username must be 3-64 letters, numbers, dots, underscores or hyphens",
        )
    if len(display_name) < 2:
        raise HTTPException(status_code=422, detail="Enter your full display name")
    if len(item.password) < 8:
        raise HTTPException(
            status_code=422, detail="Password must be at least 8 characters"
        )
    try:
        with _database() as connection:
            connection.execute(
                """
                INSERT INTO users
                    (username, display_name, password_hash, role, created_at)
                VALUES (?, ?, ?, 'reception', ?)
                """,
                (username, display_name, _hash_password(item.password), _utc_iso(_utc_now())),
            )
            user = connection.execute(
                "SELECT * FROM users WHERE username = ?", (username,)
            ).fetchone()
    except sqlite3.IntegrityError as error:
        raise HTTPException(status_code=409, detail="Username is already registered") from error
    return _create_auth_session(user)


@app.post("/auth/login")
def sign_in(item: AuthCredentials, request: Request):
    username = item.username.strip().lower()
    if _auth_rate_limited(request, username):
        raise HTTPException(
            status_code=429,
            detail="Too many sign-in attempts; try again in 15 minutes",
        )
    with _database() as connection:
        user = connection.execute(
            "SELECT * FROM users WHERE username = ? COLLATE NOCASE AND is_active = 1",
            (username,),
        ).fetchone()
    if user is None or not _verify_password(item.password, user["password_hash"]):
        _record_auth_failure(request, username)
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    auth_login_attempts.pop(_auth_rate_key(request, username), None)
    return _create_auth_session(user)


@app.get("/auth/me")
def get_current_user(authorization: Optional[str] = Header(default=None)):
    user = _request_user(authorization)
    return {
        "id": user["id"],
        "username": user["username"],
        "display_name": user["display_name"],
        "role": user["role"],
    }


@app.put("/auth/me/password")
def change_own_password(
    item: OwnPasswordChange,
    authorization: Optional[str] = Header(default=None),
):
    user = _request_user(authorization)
    with _database() as connection:
        account = connection.execute(
            "SELECT password_hash FROM users WHERE id = ? AND is_active = 1",
            (user["id"],),
        ).fetchone()
        if account is None or not _verify_password(
            item.current_password, account["password_hash"]
        ):
            raise HTTPException(status_code=400, detail="Current password is incorrect")
        connection.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (_hash_password(item.new_password), user["id"]),
        )
    return {"message": "Password changed successfully"}


@app.post("/auth/logout")
def sign_out(authorization: Optional[str] = Header(default=None)):
    _request_user(authorization)
    token = authorization.removeprefix("Bearer ").strip()
    with _database() as connection:
        connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE token_hash = ?",
            (
                _utc_iso(_utc_now()),
                hashlib.sha256(token.encode("utf-8")).hexdigest(),
            ),
        )
    return {"message": "Signed out"}


@app.post("/auth/forgot-password")
def forgot_password(item: PasswordResetRequest):
    username = item.username.strip().lower()
    with _database() as connection:
        user = connection.execute(
            "SELECT id FROM users WHERE username = ? COLLATE NOCASE", (username,)
        ).fetchone()
        if user is not None:
            connection.execute(
                """
                INSERT INTO password_reset_requests
                    (user_id, requested_username, created_at)
                VALUES (?, ?, ?)
                """,
                (user["id"], username, _utc_iso(_utc_now())),
            )
    return {
        "message": "If that account exists, a password reset request has been sent to an administrator."
    }


@app.get("/auth/admin/password-reset-requests")
def list_password_reset_requests(
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    with _database() as connection:
        rows = connection.execute(
            """
            SELECT id, user_id, requested_username, created_at
            FROM password_reset_requests
            WHERE resolved_at IS NULL
            ORDER BY id ASC
            """
        ).fetchall()
    return [dict(row) for row in rows]


@app.put("/auth/admin/users/{user_id}/password")
def admin_reset_user_password(
    user_id: int,
    item: AdminPasswordReset,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    with _database() as connection:
        cursor = connection.execute(
            "UPDATE users SET password_hash = ? WHERE id = ? AND role = 'reception'",
            (_hash_password(item.password), user_id),
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Reception user not found")
        connection.execute(
            """
            UPDATE password_reset_requests
            SET resolved_at = ?
            WHERE user_id = ? AND resolved_at IS NULL
            """,
            (_utc_iso(_utc_now()), user_id),
        )
        connection.execute(
            """
            UPDATE auth_sessions SET revoked_at = ?
            WHERE user_id = ? AND revoked_at IS NULL
            """,
            (_utc_iso(_utc_now()), user_id),
        )
    return {"message": "Password reset successfully"}


@app.get("/inventory")
def get_inventory(authorization: Optional[str] = Header(default=None)):
    _request_user(authorization)
    with _database() as connection:
        setting = connection.execute(
            "SELECT setting_value FROM app_settings WHERE setting_key = ?",
            ("total_inventory",),
        ).fetchone()
    if setting is None:
        raise HTTPException(status_code=500, detail="Inventory setting is unavailable")
    return {"total_inventory": int(setting["setting_value"])}


@app.put("/admin/inventory")
def update_inventory(
    item: InventoryLimitUpdate,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    with _database() as connection:
        rows = connection.execute(
            "SELECT id, qty_issue, qty_return, carried_from_id FROM key_logs"
        ).fetchall()
        carried_entry_ids = {
            str(row["carried_from_id"])
            for row in rows
            if row["carried_from_id"] is not None
        }
        minimum_inventory = sum(
            max(0, int(row["qty_issue"] or 0) - int(row["qty_return"] or 0))
            for row in rows
            if str(row["id"]) not in carried_entry_ids
        )
        if item.total_inventory < minimum_inventory:
            raise HTTPException(
                status_code=422,
                detail=(
                    "Total key stock cannot be lower than "
                    f"{minimum_inventory} keys currently checked out"
                ),
            )
        connection.execute(
            """
            UPDATE app_settings
            SET setting_value = ?
            WHERE setting_key = 'total_inventory'
            """,
            (str(item.total_inventory),),
        )
    return {"total_inventory": item.total_inventory}


@app.post("/admin/login")
def admin_login(item: AdminLoginRequest, request: Request):
    configured_pin = _admin_pin()
    if configured_pin is None:
        raise HTTPException(
            status_code=503, detail="Admin access is not configured on the server"
        )
    client_ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    attempts = [
        attempt
        for attempt in admin_login_attempts.get(client_ip, [])
        if now - attempt < ADMIN_LOGIN_WINDOW_SECONDS
    ]
    if len(attempts) >= ADMIN_LOGIN_MAX_ATTEMPTS:
        admin_login_attempts[client_ip] = attempts
        raise HTTPException(
            status_code=429,
            detail="Too many failed admin login attempts; try again in 15 minutes",
        )
    if not hmac.compare_digest(item.pin, configured_pin):
        attempts.append(now)
        admin_login_attempts[client_ip] = attempts
        raise HTTPException(status_code=401, detail="Invalid admin PIN")

    admin_login_attempts.pop(client_ip, None)
    token = secrets.token_urlsafe(32)
    admin_tokens[token] = time.monotonic() + ADMIN_TOKEN_TTL_SECONDS
    return {"access_token": token, "token_type": "bearer"}


@app.post("/admin/logout")
def admin_logout(authorization: Optional[str] = Header(default=None)):
    _require_admin(authorization)
    token = authorization.removeprefix("Bearer ").strip()
    admin_tokens.pop(token, None)
    return {"message": "Admin session ended"}


@app.get("/logs")
def get_logs(authorization: Optional[str] = Header(default=None)):
    _request_user(authorization)
    with _database() as connection:
        rows = connection.execute("SELECT * FROM key_logs ORDER BY id DESC").fetchall()
        return [dict(row) for row in rows]


def _staff_roster_item(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "hours": row["hours"],
        "is_active": bool(row["is_active"]),
    }


@app.get("/staff-roster")
def get_staff_roster(
    include_inactive: bool = False,
    authorization: Optional[str] = Header(default=None),
):
    user = _request_user(authorization)
    if include_inactive and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    with _database() as connection:
        rows = connection.execute(
            """
            SELECT id, name, hours, is_active
            FROM staff_roster
            WHERE is_active = 1 OR ?
            ORDER BY name COLLATE NOCASE
            """,
            (int(include_inactive),),
        ).fetchall()
    return [_staff_roster_item(row) for row in rows]


@app.post("/admin/staff-roster", status_code=201)
def add_staff_roster_member(
    item: StaffRosterCreate,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    name = item.name.strip()
    hours = item.hours.strip()
    if not name or not hours:
        raise HTTPException(status_code=422, detail="Name and shift hours are required")
    try:
        with _database() as connection:
            cursor = connection.execute(
                "INSERT INTO staff_roster (name, hours) VALUES (?, ?)",
                (name, hours),
            )
            row = connection.execute(
                "SELECT id, name, hours, is_active FROM staff_roster WHERE id = ?",
                (cursor.lastrowid,),
            ).fetchone()
    except sqlite3.IntegrityError as error:
        raise HTTPException(
            status_code=409, detail="A staff member with that name already exists"
        ) from error
    return _staff_roster_item(row)


@app.put("/admin/staff-roster/{staff_id}")
def update_staff_roster_member(
    staff_id: int,
    item: StaffRosterUpdate,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    name = item.name.strip()
    hours = item.hours.strip()
    if not name or not hours:
        raise HTTPException(status_code=422, detail="Name and shift hours are required")
    try:
        with _database() as connection:
            cursor = connection.execute(
                """
                UPDATE staff_roster
                SET name = ?, hours = ?, is_active = ?
                WHERE id = ?
                """,
                (name, hours, item.is_active, staff_id),
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Staff member not found")
            row = connection.execute(
                "SELECT id, name, hours, is_active FROM staff_roster WHERE id = ?",
                (staff_id,),
            ).fetchone()
    except sqlite3.IntegrityError as error:
        raise HTTPException(
            status_code=409, detail="A staff member with that name already exists"
        ) from error
    return _staff_roster_item(row)


@app.delete("/admin/staff-roster/{staff_id}")
def delete_staff_roster_member(
    staff_id: int,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    with _database() as connection:
        cursor = connection.execute(
            "DELETE FROM staff_roster WHERE id = ?", (staff_id,)
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Staff member not found")
    return {"message": "Staff member removed"}


@app.post("/logs/carry-forward")
def carry_forward_logs(
    item: CarryForwardRequest,
    authorization: Optional[str] = Header(default=None),
):
    _request_user(authorization)
    try:
        datetime.strptime(item.shift_date, "%Y-%m-%d")
    except ValueError as error:
        raise HTTPException(status_code=422, detail="Invalid shift date") from error
    if not item.staff_name.strip():
        raise HTTPException(status_code=422, detail="Staff name is required")
    if item.shift_period.split(" ", 1)[0] not in {
        "Morning",
        "Afternoon",
        "Night",
    }:
        raise HTTPException(status_code=422, detail="Invalid shift period")

    shift_order = {
        "Morning": {"Night"},
        "Afternoon": {"Morning", "Night"},
        "Night": {"Morning", "Afternoon"},
    }
    target_shift = item.shift_period.split(" ", 1)[0]
    with _database() as connection:
        connection.execute("BEGIN IMMEDIATE")
        possible_sources = connection.execute(
            """
            SELECT source.*
            FROM key_logs AS source
            WHERE source.qty_issue > source.qty_return
              AND source.is_missing = 0
              AND source.status = 'PENDING'
              AND source.shift_date <= ?
              AND NOT EXISTS (
                    SELECT 1
                    FROM key_logs AS child
                    WHERE child.carried_from_id = CAST(source.id AS TEXT)
              )
            ORDER BY source.id
            """,
            (item.shift_date,),
        ).fetchall()
        candidates = [
            source
            for source in possible_sources
            if source["shift_date"] < item.shift_date
            or source["shift_period"].split(" ", 1)[0]
            in shift_order[target_shift]
        ]

        for source in candidates:
            remaining = int(source["qty_issue"]) - int(source["qty_return"])
            connection.execute(
                """
                INSERT INTO key_logs (
                    issued_date, staff_name, room_no, qty_issue, qty_return,
                    status, returned_time, received_by, remarks,
                    guest_or_holder_name, shift_date, shift_period, category,
                    is_missing, missing_qty, is_carried_forward,
                    original_shift_date, carried_from_id
                )
                VALUES (?, ?, ?, ?, 0, 'PENDING', '', '', ?, ?, ?, ?, ?, 0, 0, 1, ?, ?)
                """,
                (
                    item.issued_date,
                    item.staff_name.strip(),
                    source["room_no"],
                    remaining,
                    f"Carried forward from {source['shift_period']}: "
                    f"{source['remarks'] or ''}".rstrip(),
                    source["guest_or_holder_name"],
                    item.shift_date,
                    item.shift_period,
                    source["category"],
                    source["original_shift_date"] or source["shift_date"],
                    str(source["id"]),
                ),
            )

    return {"carried_count": len(candidates)}


@app.post("/logs")
def add_log(
    item: KeyLogItem,
    authorization: Optional[str] = Header(default=None),
):
    _request_user(authorization)
    if item.qty_return > item.qty_issue:
        raise HTTPException(
            status_code=422, detail="Returned quantity cannot exceed issued quantity"
        )
    if item.is_carried_forward or item.carried_from_id is not None:
        raise HTTPException(
            status_code=403,
            detail="Carry-forward records are created automatically by the server",
        )
    if item.status != "PENDING" or item.is_missing or item.missing_qty > 0:
        raise HTTPException(
            status_code=403,
            detail="New issuance records must start as pending; use admin edit for corrections",
        )
    columns = (
        "issued_date, staff_name, room_no, qty_issue, qty_return, status, "
        "returned_time, received_by, remarks, guest_or_holder_name, shift_date, "
        "shift_period, category, is_missing, missing_qty, is_carried_forward, "
        "original_shift_date, carried_from_id"
    )
    values = item.dict()
    with _database() as connection:
        cursor = connection.execute(
            f"INSERT INTO key_logs ({columns}) VALUES "
            "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                values["issued_date"],
                values["staff_name"],
                values["room_no"],
                values["qty_issue"],
                values["qty_return"],
                values["status"],
                values["returned_time"],
                values["received_by"],
                values["remarks"],
                values["guest_or_holder_name"],
                values["shift_date"],
                values["shift_period"],
                values["category"],
                values["is_missing"],
                values["missing_qty"],
                values["is_carried_forward"],
                values["original_shift_date"],
                values["carried_from_id"],
            ),
        )
        log_id = cursor.lastrowid
    return {"id": log_id, **values}


@app.put("/logs/{log_id}")
def update_log(
    log_id: int,
    item: UpdateLogItem,
    authorization: Optional[str] = Header(default=None),
):
    _request_user(authorization)
    if item.is_missing or item.status in {"MISSING", "LOST"}:
        raise HTTPException(
            status_code=403,
            detail="Marking a key missing requires an authenticated admin edit",
        )
    with _database() as connection:
        existing = connection.execute(
            "SELECT qty_issue, qty_return FROM key_logs WHERE id = ?", (log_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail=f"Log {log_id} not found")
        if item.qty_return < existing["qty_return"]:
            raise HTTPException(
                status_code=422, detail="Returned quantity cannot be decreased"
            )
        if item.qty_return > existing["qty_issue"]:
            raise HTTPException(
                status_code=422,
                detail="Returned quantity cannot exceed issued quantity",
            )
        if item.status == "RETURNED" and item.qty_return != existing["qty_issue"]:
            raise HTTPException(
                status_code=422,
                detail="A returned entry must have all issued keys returned",
            )
        status = "RETURNED" if item.qty_return == existing["qty_issue"] else "PENDING"
        cursor = connection.execute(
            """
            UPDATE key_logs
            SET qty_return = ?, status = ?, returned_time = ?, received_by = ?,
                remarks = ?, is_missing = 0, missing_qty = 0
            WHERE id = ?
            """,
            (
                item.qty_return,
                status,
                item.returned_time,
                item.received_by,
                item.remarks,
                log_id,
            ),
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Log {log_id} not found")
    return {"message": f"Log {log_id} updated successfully!"}


@app.put("/admin/logs/{log_id}")
def admin_update_log(
    log_id: int,
    item: KeyLogItem,
    authorization: Optional[str] = Header(default=None),
):
    _require_admin(authorization)
    item = _normalize_admin_item(item)
    values = item.dict()
    with _database() as connection:
        cursor = connection.execute(
            """
            UPDATE key_logs
            SET issued_date = ?, staff_name = ?, room_no = ?, qty_issue = ?,
                qty_return = ?, status = ?, returned_time = ?, received_by = ?,
                remarks = ?, guest_or_holder_name = ?, shift_date = ?,
                shift_period = ?, category = ?, is_missing = ?, missing_qty = ?,
                is_carried_forward = ?, original_shift_date = ?, carried_from_id = ?
            WHERE id = ?
            """,
            (
                values["issued_date"],
                values["staff_name"],
                values["room_no"],
                values["qty_issue"],
                values["qty_return"],
                values["status"],
                values["returned_time"],
                values["received_by"],
                values["remarks"],
                values["guest_or_holder_name"],
                values["shift_date"],
                values["shift_period"],
                values["category"],
                values["is_missing"],
                values["missing_qty"],
                values["is_carried_forward"],
                values["original_shift_date"],
                values["carried_from_id"],
                log_id,
            ),
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Log {log_id} not found")
    return {"message": f"Admin updated entry {log_id} successfully!"}


@app.delete("/admin/logs/{log_id}")
def delete_log(log_id: int, authorization: Optional[str] = Header(default=None)):
    _require_admin(authorization)
    with _database() as connection:
        cursor = connection.execute("DELETE FROM key_logs WHERE id = ?", (log_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Log {log_id} not found")
    return {"message": f"Admin deleted entry {log_id} successfully!"}
