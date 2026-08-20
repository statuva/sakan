# First Codebase Cleanup Report

## Goal

This pass improves codebase clarity without changing Sakan’s visible UI, user experience, Firestore schema, navigation order, permissions, or feature behavior.

Branch:

```text
chore/first-codebase-cleanup
```

Recommended GitHub label/title:

```text
First codebase cleanup and Q&A documentation
```

## Guardrails used

- No UI or UX redesign.
- No Firestore collection/path changes.
- No Security Rules changes.
- No repository method behavior changes.
- No removal of active runtime dependencies.
- No removal of future feature contracts unless they were empty or clearly superseded implementation leftovers.
- Generated Firebase files remain untouched.

## Safe changes included

### 1. Removed empty Profile widget placeholders

The following files contained no Dart implementation and were not imported by the active Profile screens:

```text
lib/features/profile/presentation/widgets/admin_settings_section.dart
lib/features/profile/presentation/widgets/profile_header.dart
lib/features/profile/presentation/widgets/profile_section_tile.dart
lib/features/profile/presentation/widgets/schedule_block_card.dart
```

Reason: empty tracked files increase the apparent architecture surface without providing code or documentation.

### 2. Removed superseded Calendar implementation files

The following files belonged to an older, self-contained Calendar UI attempt and were not imported by the current `calendar_screen.dart`:

```text
lib/features/calendar/presentation/widgets/calendar_views.dart
lib/features/calendar/presentation/widgets/calendar_insights.dart
lib/features/calendar/presentation/widgets/calendar_visuals.dart
```

The active Calendar already uses the more focused files:

```text
calendar_month_view.dart
calendar_week_view.dart
calendar_agenda_view.dart
calendar_support_cards.dart
calendar_palette.dart
calendar_moment_style.dart
calendar_insight_service.dart
```

Reason: keeping two competing Calendar widget systems makes maintenance and Q&A harder and creates a risk of editing the wrong implementation.

### 3. Fixed route import casing

The router import was normalized from:

```dart
sign_in_Screen.dart
```

to the exact tracked filename:

```dart
sign_in_screen.dart
```

Reason: Windows is case-insensitive, but Linux/CI and some build environments are case-sensitive.

### 4. Standardized the entry-point import layout

`main.dart` was reorganized into package imports followed by local imports. Initialization behavior is unchanged.

### 5. Replaced the outdated README

The previous README still said Firebase was planned and the Flutter foundation was in progress. The updated README now reflects the actual implemented modules, honest limitations, architecture, local commands, and documentation links.

### 6. Added a codebase and Q&A guide

Created:

```text
docs/CODEBASE_QA_GUIDE.md
```

It explains:

- architecture layers;
- every active feature area;
- shared models, repositories, and services;
- end-to-end data flows;
- role and privacy boundaries;
- current deterministic recommendation logic;
- honest implementation status;
- likely technical Q&A answers;
- recommended code-walkthrough order.

## Files intentionally kept

### Placeholder screens

```text
features/home/presentation/home_screen.dart
features/digital_twin/presentation/digital_twin_screen.dart
```

They are incomplete features, not accidental dead files.

### Future engine contracts

```text
shared/services/rhythm_engine.dart
shared/services/care_engine.dart
```

They document the intended boundary for future deterministic engines.

### Demo/environment infrastructure

```text
core/config/app_environment.dart
shared/services/demo_data_service.dart
```

These are useful for controlled demo-mode development and should be removed only after the final demo strategy is settled.

### Legacy/reserved repository contracts

```text
family_repository.dart
hub_repository.dart
moment_repository.dart
rhythm_repository.dart
```

They are not registered in `AppDependencies`, but they represent earlier generic contracts. They are documented as inactive/reserved rather than deleted in this first conservative pass.

### Shared feedback components

```text
feature_placeholder.dart
offline_banner.dart
```

`feature_placeholder.dart` is still used by Home and Digital Twin. `offline_banner.dart` is a valid reusable component even though full connectivity orchestration is not connected yet.

## Known architectural debt not changed in this pass

### ProfileRepository duplicates schedule operations

`ProfileRepository`/`FirebaseProfileRepository` still expose schedule CRUD even though `ScheduleRepository`/`FirebaseScheduleRepository` are the active schedule path. Search results indicate current UI uses `scheduleRepository`, but removing the duplicate API should be a separate tested refactor.

### FamilySetupScreen reads Firestore directly for currentFamilyId

Most features use `CurrentFamilyService`, while Family Setup still performs part of this lookup directly. Migrating it should be a separate behavior-tested change because setup routing is critical.

### Calendar uses nested StreamBuilders

The approach works, but the screen coordinates several streams. A future controller/state object could combine them without altering UI. This should happen after Home and Digital Twin requirements stabilize.

### Hub settings are still local/demo behavior

The screen should not be described as NFC-complete. Persistence and real NFC integration remain future work.

### Some dependencies may be unused

The current `pubspec.yaml` includes packages such as Riverpod, Google Fonts, Flutter SVG, and Cached Network Image. They were not removed because dependency cleanup must update `pubspec.lock` locally and verify all platform builds.

## Required local verification before merge

Run from the project root:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d edge
flutter devices
flutter run -d <android-device-id>
```

Manual smoke test:

```text
Launch
-> Sign in
-> Home placeholder
-> Digital Twin placeholder
-> Profile
-> Calendar
-> Manage Moments
-> Back navigation
```

Also verify:

- create/join family still works;
- setup completion still routes to Home;
- profile values still persist;
- schedule CRUD still persists;
- Calendar Month/Week/Agenda still load;
- adult/admin edit controls and child read-only controls remain unchanged.

## Suggested next cleanup pass

After local validation and merge:

1. Remove duplicate schedule methods from ProfileRepository and FirebaseProfileRepository.
2. Run a dependency audit and remove unused packages with `flutter pub remove`.
3. Move Family Setup current-family resolution behind `CurrentFamilyService`.
4. Add repository unit tests with Firebase emulators/fakes.
5. Add widget tests for role visibility, startup redirects, and Calendar filters.
6. Introduce controllers only where screens are demonstrably hard to maintain; do not add architecture for its own sake.

## Merge rule

This PR should remain draft until the local analyzer, tests, Edge smoke test, and Android smoke test pass. The cleanup is successful only if behavior is unchanged and the codebase is easier to explain.
