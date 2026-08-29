# Sakan

**A software-first family rhythm assistant that helps families define meaningful Moments, plan them, confirm what actually happened, preserve Memories, and understand which recurring family rhythms are stable or drifting.**

Sakan is designed around one connected loop:

```text
Define → Plan → Gather → Confirm → Learn → Remember → Act → Repeat
```

The application does not treat a calendar entry as proof that family time happened. It separates a reusable **Family Moment** from each real **Moment Instance**, records participation through member check-ins or review, updates the corresponding rhythm, and then surfaces a grounded next step.

## Why Sakan

Families often want to maintain traditions and prepare for important events, but their schedules change and meaningful routines can quietly disappear. Standard calendars can show what was planned, but they do not normally answer:

- Which family Moments matter most?
- When does the family have a shared opening?
- Did a planned Moment actually happen?
- Who confirmed participation?
- Is a recurring Moment stable, drifting, recovering, or still being learned?
- What is the most useful next action?

Sakan combines planning, participation evidence, rhythm tracking, Memories, personal reminders, and a Family Digital Twin to answer those questions without claiming to measure emotions or relationship quality.

## Product Areas

| Area | Purpose |
|---|---|
| **Home** | A personalized summary of what matters to the signed-in member. This screen is currently in progress. |
| **Digital Twin** | A visual and factual view of member-to-Moment connections and each recurring Moment's recorded rhythm. |
| **Moments** | The family's reusable Moment library: definitions, categories, importance, participants, timing, and evidence configuration. |
| **Calendar** | Concrete Moment occurrences in Month, Week, and Agenda views, plus planning and time-sensitive actions. |
| **Profile** | Personal information, schedules, reminders, preferences, notification settings, privacy, and authorized family settings. |

## Core Domain Model

### Family Moment

A reusable definition of something that matters to the family.

Examples:

- Friday Lunch
- Movie Night
- Weekend Breakfast
- Grandparents Visit
- Ali's Graduation

A Family Moment stores its category, importance, expected participants, timing, recurrence configuration, description, and evidence method.

### Moment Instance

One planned or actual occurrence of a Family Moment.

Example:

```text
Family Moment:
Movie Night — every 14 days

Moment Instances:
14 August — Completed
28 August — Missed
11 September — Scheduled
```

A Moment Instance stores its planned and actual times, status, duration, confirmed participants, evidence signals, and confirmation level.

### Moment Participant

One member's participation record for one Moment Instance.

Possible states include:

```text
Invited
Nearby
Checked In
Left
Declined
```

Members may update only their own participation record.

### Rhythm Record

The calculated state of one recurring Family Moment.

Possible states:

```text
Still Learning
Stable
Drifting
Recovering
Strengthening
```

Rhythms are derived from recorded Moment Instances, not from unsupported emotional or psychological assumptions.

### Care Action

A personal preparation task or reminder.

Examples:

- Buy a graduation gift
- Call Grandma
- Confirm transportation
- Prepare a family message

Care Actions are separate from shared family sessions.

### Family Memory

A note and optional media record connected to a completed Moment Instance. Memories preserve what the family wants to remember without being required as proof for every session.

## Current User Flow

```text
Create or join a family
        ↓
Complete Family Setup
        ↓
Define recurring and one-time Family Moments
        ↓
Create or generate a scheduled Moment Instance
        ↓
View it in Calendar
        ↓
Start the Moment or confirm it through Today Review
        ↓
Members check in to the live session
        ↓
End the session and save its actual duration and participants
        ↓
Update the corresponding Rhythm Record
        ↓
Create the next recurring occurrence when needed
        ↓
Optionally preserve a Memory
        ↓
Family Insights and Digital Twin reflect the new evidence
```

## Current Implementation Status

### Implemented and integrated

- Flutter application foundation and Material 3 theme.
- Firebase Authentication with email/password and password reset.
- Family creation, invitation codes, and join-by-code.
- Admin, adult, and child roles.
- Four-step Family Setup and initial rhythm baseline.
- Personal profile and family settings persistence.
- Weekly multi-day schedules and one-time unavailable periods.
- Family-level availability derived without exposing private schedule labels.
- Reusable Family Moments and concrete Moment Instances.
- Month, Week, and Agenda Calendar modes.
- Live Family Moment sessions.
- Real-time manual member check-ins.
- Elapsed session timer based on the stored start time.
- End-session summary with duration, participants, evidence, and confidence.
- Today Review for happened, missed, rescheduled, and unplanned Moments.
- Rhythm recalculation from completed and missed instances.
- Next-occurrence generation for recurring Moments.
- Instance-linked Memories and an All Memories view.
- Personal reminders and Calendar-sourced Care Actions.
- Local Android notification scheduling integration.
- Deterministic Family Insights.
- Instance-based Calendar integration.
- Interactive Digital Twin map and per-Moment rhythm views.

### Current refinement

- Dedicated Moments bottom-navigation tab.
- Simplified Moment cards showing only name, category, and importance.
- Read-only Moment Details screen with a separate Edit action.
- Simplification of the Digital Twin map and per-Moment interpretation layout.
- Final notification regression testing on physical Android devices.
- Final role and permission regression across admin, adult, and child accounts.

### Not connected yet

- Personalized Home screen.
- Protected external generative-AI backend.
- AI-written Digital Twin interpretations and family-level synthesis.
- Reliable remote push invitations when the receiving app is closed.
- Optional Bluetooth proximity evidence.
- Complete cloud photo-upload workflow.
- Functional "What if?" simulation.

## Family Insights and AI

Family Insights currently work **without an external language model**.

Sakan deterministically calculates facts such as:

- A milestone is five days away.
- A reminder is overdue.
- A recurring Moment is drifting.
- A scheduled occurrence needs Today Review.
- A live Moment can be joined.
- A recorded shared window has fewer schedule conflicts.
- A preparation reminder already exists.

The future AI layer will receive a privacy-minimized, structured report and improve the wording or organization of an interpretation. It will not be allowed to decide factual state.

```text
Sakan calculates facts
        ↓
AI explains those facts
        ↓
The user reviews the result
        ↓
The user chooses whether to act
```

The AI must not invent:

- Whether a Moment happened
- Who participated
- Actual duration
- Availability
- Rhythm state
- Evidence strength
- Required action type

As of 29 August 2026, the application does not send runtime requests to an external generative-AI service. The deterministic Family Insight result remains the working fallback.

## Privacy and Access Control

Sakan follows these principles:

- A family member can update only their own check-in record.
- Child accounts do not receive family-administration controls.
- Private schedule labels are not exposed through family availability.
- The Digital Twin reports recorded behavior, not emotional health.
- AI input should exclude emails, invitation codes, private notes, raw identifiers, and private schedule labels.
- No API key should be stored in Flutter source code, assets, GitHub, or the compiled application.
- Manual check-in remains the primary participation method.
- Bluetooth, if added, will be optional proximity evidence rather than automatic proof.

## Architecture

```text
Presentation
    ↓
Repository and service contracts
    ↓
Firebase implementations
    ↓
Firebase Authentication and Cloud Firestore
```

Shared repositories and services are registered in:

```text
lib/app/app_dependencies.dart
```

Primary routes and the shell navigation are defined in:

```text
lib/routes/app_router.dart
lib/app/app_shell.dart
```

Important services include:

```text
CurrentFamilyService
FamilyInsightService
MomentOutcomeService
RhythmUpdateService
ReminderNotificationService
```

## Technology

- Flutter and Dart
- Material 3
- `go_router`
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Storage foundation
- `table_calendar`
- `intl`
- `flutter_local_notifications`
- `timezone`
- `flutter_timezone`
- `image_picker`

## Project Structure

```text
lib/
├── app/
├── core/
├── features/
│   ├── authentication/
│   ├── calendar/
│   ├── care/
│   ├── daily_review/
│   ├── digital_twin/
│   ├── family_setup/
│   ├── home/
│   ├── memories/
│   ├── moments/
│   ├── profile/
│   └── rhythm/
├── routes/
└── shared/
    ├── models/
    ├── repositories/
    ├── services/
    ├── utils/
    └── widgets/
```

## Run Locally

### Requirements

- Flutter SDK compatible with the checked-in lockfile
- Android Studio Android SDK for Android builds
- JDK used by the Flutter Android toolchain
- A configured Firebase project
- `google-services.json` for Android
- Sufficient free disk space for Gradle and Android build output

### Install dependencies

```powershell
flutter pub get
```

### Analyze and test

```powershell
flutter analyze
flutter test
```

### Run on Edge

```powershell
flutter run -d edge
```

### Run on a connected Android device

```powershell
flutter devices
flutter run -d <device-id>
```

### Deploy Firestore Security Rules

```powershell
firebase deploy --only firestore:rules --project=<firebase-project-id>
```

## Documentation

- [`docs/product_specification.md`](docs/product_specification.md)
- [`docs/app_flow.md`](docs/app_flow.md)
- [`docs/data_model.md`](docs/data_model.md)
- [`docs/firestore_structure.md`](docs/firestore_structure.md)
- [`docs/implementation_status.md`](docs/implementation_status.md)
- [`docs/ai_usage_log.md`](docs/ai_usage_log.md)

## Known Limitations

- Home is not yet the final personalized dashboard.
- External AI is not yet connected.
- Digital Twin interpretations are currently deterministic or in UI refinement.
- Local notification behavior still requires final regression across Android versions and manufacturers.
- Remote family invitations are not guaranteed while the app is fully closed.
- Bluetooth proximity is not part of the current MVP.
- Photo storage is not yet a complete user flow.
- Automated test coverage is still smaller than the manual test coverage.

## Team

- Rahma Reda
- Yasmine Yousof
- Hala Mohammed

## AI-Assisted Development

AI tools were used for architecture discussion, UI prototyping, implementation drafts, debugging, documentation, and technical explanation. All accepted changes were selected, integrated, reviewed, and tested by the team. See [`docs/ai_usage_log.md`](docs/ai_usage_log.md) for the dated record.
