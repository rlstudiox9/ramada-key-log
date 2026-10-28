# Ramada Hotel Key Log

Flutter browser app for front-desk key issuance, returns, shift handover, and
inventory tracking.

## Run in Chrome or Edge

Start the FastAPI backend before running the app. From the repository root:

```sh
python3 -m venv hotel_backend/.venv
. hotel_backend/.venv/bin/activate
pip install -r hotel_backend/requirements.txt
python3 -m uvicorn hotel_backend.main:app --reload --port 8000
```

The SQLite database is created as `hotel_backend/hotel_keys.db` when the
backend is started from `hotel_backend/`.

In another terminal, run these commands from `flutter_hotel_log/`:

```sh
flutter pub get
flutter run -d chrome
```

The app uses `http://localhost:8000` by default. To use a different backend
address, pass `--dart-define=API_BASE_URL=http://host:port` to `flutter run`.
The backend must allow browser requests from the Flutter app origin.

## Accounts and admin access

Set the administrator account credentials on the backend before its first
start. Use a unique password in any shared or production deployment:

```sh
export RAMADA_ADMIN_USERNAME='admin'
export RAMADA_ADMIN_PASSWORD='replace-with-a-strong-unique-password'
```

The backend provisions this Admin account in SQLite. `RAMADA_ADMIN_PIN` (or
`ADMIN_PIN`) remains a legacy password fallback only when
`RAMADA_ADMIN_PASSWORD` is not set; do not use the example PIN on a production
deployment. New accounts created from the app are always Reception / Front Desk
accounts; users cannot select or promote themselves to Admin.

Successful sign-ins create random bearer sessions that persist in SQLite and
expire after 30 days. The browser stores the token locally, validates it with
the backend when the app starts, and revokes it on logout. Passwords are stored
as salted PBKDF2 hashes, and sign-in attempts are rate-limited. Forgot-password
requests do not disclose whether an account exists; an Admin reviews requests
and can set a new Reception password from the dashboard. Use HTTPS and restrict
network access to the backend for production deployments.

For Microsoft Edge, replace `chrome` with `edge` if Flutter lists Edge as an
available device. Web platform files are already checked into `web/`; if they
are removed, regenerate them with:

```sh
flutter create . --platforms web
```

`--web-renderer html` is not a supported Flutter 3.47 command-line option.
Flutter selects its supported web renderer automatically.

## Verify and build

```sh
flutter test
flutter analyze
flutter build web --release
```

The release build is written to `build/web/`.
Backend carry-forward and persistence tests can be run with
`cd hotel_backend && .venv/bin/python -m unittest -v test_main.py`.

## Browser storage and backups

Issuance records are loaded from and saved to the FastAPI `/logs` endpoints,
which persist them in SQLite. Returns use `PUT /logs/{id}` and deletes use
`PUT`/`DELETE /admin/logs/{id}` with an authenticated admin bearer token.
At sign-in and at each shift/day boundary, the backend automatically creates
an idempotent carry-forward record for every still-unreturned key. Original
shift records remain unchanged, so date-wise and shift-wise history is retained
in SQLite while the active shift dashboard shows its own carried inventory.
SQLite is always stored at `hotel_backend/hotel_keys.db` unless
`HOTEL_KEYS_DB` points to another location. The shared inventory count is stored
in SQLite; authenticated staff can view it, but only Admin accounts can change
it, and the backend prevents setting it below the number of keys still checked
out. The dashboard refreshes the shared inventory every five seconds so stock
changes made by an Admin appear in reception accounts without a page reload.
Issue and return dialogs use the fixed staff roster: Jonayed, Azizul, Wahaj,
Hanseef, Supervisor Hania, and Manager Mehbuba, with each member's shift hours
seeded into SQLite and shown in the dropdown. Admins can add, edit, deactivate,
reactivate, or remove roster members from Manage Staff Roster; inactive members
are excluded from issue and return dropdowns, while historical logs remain
unchanged. The last selected duty name is retained in browser `localStorage` as
a convenience. CSV, JSON, or text backups are available from the Export / Share
dialog.

Inventory metrics are calculated per selected date and shift, with outstanding
handover and missing keys counted separately so that
`Total Keys = Remaining in FD + Handover Issued + Missing Keys`.

The app starts with the records currently in the backend; an empty database
shows an empty log rather than local demonstration records.
