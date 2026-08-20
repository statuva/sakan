# Sakan

**A family coordination app built around meaningful moments, recurring rhythms, shared availability, and a Family Digital Twin data foundation.**

Sakan helps a family define the moments that matter, prepare for important one-time events, preserve recurring traditions, and coordinate time without exposing private schedule labels.

## Current product model

- **Family Moments:** recurring traditions and meaningful one-time events.
- **Rhythms:** measured recurrence state for recurring moments.
- **Care Actions:** practical preparation tasks assigned to family members.
- **Availability:** private personal schedules converted into label-free family busy intervals.
- **Memories:** family photos/notes associated with completed moments.
- **Digital Twin:** the planned graph and simulation layer that will combine these records.

## Current implementation

### Working foundations

- Flutter application shell with four tabs.
- Firebase Authentication with email/password and password reset.
- Family creation, invitation codes, and join-by-code.
- Role-aware family membership: admin, adult, and child.
- Four-step Family Setup and cold-start rhythm baseline.
- Profile, family-time preferences, notification settings, privacy settings, and family settings.
- Private recurring schedules and family-level label-free availability.
- Firestore-backed Family Moments and Month/Week/Agenda Calendar.
- Rule-based Calendar insights, Care Action persistence, and Memory reading foundation.

### Still in progress

- Home screen implementation.
- Visible Digital Twin graph and simulation.
- Memory photo-upload creation flow.
- NFC Hub integration.
- Real device-notification delivery.
- Protected external generative-AI backend.

The current Calendar recommendation layer is deterministic and grounded in stored moments, rhythms, participants, and availability. It is not an external LLM call.

## Technology

- Flutter / Dart
- Material 3
- `go_router`
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- FlutterFire
- `table_calendar`
- `intl`

## Architecture

```text
Presentation screens
  -> repository/service contracts
      -> Firebase implementations
          -> Firebase Authentication / Firestore
```

Global repository and service instances are registered in:

```text
lib/app/app_dependencies.dart
```

The four-tab shell and application routes are defined in:

```text
lib/app/app_shell.dart
lib/routes/app_router.dart
```

## Run locally

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge
```

For a connected Android device:

```powershell
flutter devices
flutter run -d <device-id>
```

## Documentation

- [`docs/product_specification.md`](docs/product_specification.md)
- [`docs/app_flow.md`](docs/app_flow.md)
- [`docs/data_model.md`](docs/data_model.md)
- [`docs/firestore_structure.md`](docs/firestore_structure.md)
- [`docs/ai_usage_log.md`](docs/ai_usage_log.md)

## Team

- Rahma Reda
- Yasmine Yousof
- Hala Mohammed
