# Sakan

**A family rhythm assistant that turns shared intentions into meaningful, repeatable family Moments.**

Sakan helps a family plan time together, act on upcoming needs, confirm what actually happened, preserve Memories, and learn which recurring rhythms are stable or need attention.

```text
Plan → Prepare → Gather → Confirm → Remember → Learn → Act
```

Unlike a standard calendar, Sakan does not assume that a scheduled event happened. It connects plans with real outcomes, participation, Memories, recurring patterns, and practical next steps.

## The Problem

Families may share a home while still struggling to protect meaningful time together. Important occasions are forgotten, routines slowly disappear, responsibilities fall onto one person, and a calendar rarely explains what the family should do next.

Sakan addresses this by answering four questions:

- What matters to this family now?
- When can the family realistically do it?
- What happened, and who participated?
- What is the most useful next action for each person?

Sakan reports recorded family activity. It does not claim to diagnose emotions, relationships, or wellbeing.

## What Makes Sakan Different

Most family organizers stop at shared schedules and task lists. Sakan connects the full family loop:

- **Moments** define activities, responsibilities, traditions, and milestones that matter.
- **Moment Instances** record each scheduled or completed occurrence separately.
- **Schedules** help avoid members' busy times without revealing private schedule labels.
- **Role-aware recommendations** give parents, teens, and children suitable actions for the same event.
- **Memories** preserve meaningful completed occurrences.
- **Rhythms** show whether recurring Moments are stable, drifting, recovering, strengthening, or still being learned.
- **The Family Digital Twin** turns recorded activity into an understandable map of the family's routines.
- **Sakan AI** explains grounded evidence and offers one clear next step instead of returning generic advice.

## Main Features

### Personalized Home

Home shows the signed-in member the single most relevant action right now. This may be an upcoming preparation, an overdue review, a live Moment, or another time-sensitive family need. The card stays short and leads directly to an action.

### Family Moments

A Family Moment is a reusable definition of something that matters to the family, such as Friday Lunch, Movie Night, a grandparents visit, a responsibility, or a graduation.

Moments can be recurring or one-time and include:

- category and importance;
- expected participants;
- preferred timing and recurrence;
- shared-session or review-based evidence;
- schedule-aware planning information.

Each occurrence becomes a separate Moment Instance, so one missed week does not erase the history of the whole tradition.

### Calendar and Recommendations

Month, Week, and Agenda views show concrete Moment occurrences. Sakan can surface:

- one urgent primary action;
- a small number of secondary preparation tasks;
- actions tailored to the member's role and age group;
- options such as starting a Moment, reviewing an outcome, adding a reminder, preparing for an event, or trying a simulation.

Recommendations consider the Moment type, date, recorded history, member role, existing reminders, and relevant schedule information. For example, a parent may coordinate a graduation plan, a teen may prepare a personal message, and a child may help with a simple age-appropriate task.

### Live Family Sessions and Review

Families can start a shared Moment, check in from separate accounts, and end it with a recorded duration and participant list. When a live session is unnecessary, Today Review records whether an occurrence happened, was missed, was cancelled, or was rescheduled.

### Personal Reminders

Members can keep private reminders and approve relevant Sakan recommendations as personal tasks. Reminder completion is personal and does not alter the shared Moment record.

### Memories

A Memory belongs to a specific completed occurrence. Families can save a note and supported media so recurring traditions build a real history over time. Sakan's reflection focuses on the value visible in the Memory rather than merely paraphrasing the note.

### Family Digital Twin

The Digital Twin visualizes members, Moments, and recurring rhythms using recorded evidence. It provides a concise family-level interpretation while each Moment retains its own pattern details.

Rhythm states include:

```text
Still Learning
Stable
Drifting
Recovering
Strengthening
```

### What-If Simulation

Simulation lets a family explore an idea even when it is not already an existing Moment. Sakan considers participants and schedule constraints, explains the likely practical benefit, and proposes a suitable time. The user can then create the Moment at the approved time or leave without changing family data.

### Weekly Family Report

The report summarizes the completed week using recorded outcomes, participation, time, and recurring-pattern evidence. It distinguishes facts from interpretation and avoids presenting incomplete tracking as a definite conclusion.

### Ask Sakan

Ask Sakan is the conversational assistant for grounded family questions. It can use relevant Moments, schedules, rhythm history, Memories, and current actions to provide:

- one noticeable pattern;
- a short explanation of the evidence;
- one specific next step;
- an alternative recommendation when requested.

Responses are intentionally concise and should not invent family events or claim facts that are absent from the family's records.

## How Sakan AI Works

Sakan uses a hybrid approach:

```text
Verified family records
        ↓
Deterministic facts and priorities
        ↓
Privacy-minimized AI context
        ↓
Short explanation or recommendation
        ↓
User approval before any change
```

The application calculates factual state—such as occurrence status, participants, duration, availability, rhythm state, and urgency. Generative AI explains that evidence and helps shape useful recommendations. Deterministic fallbacks keep essential insights available when an AI response is unavailable.

AI requests are sent through protected Firebase Cloud Functions. API credentials are not stored in the Flutter application.

## Privacy and Roles

- Family administration is restricted to authorized roles.
- Recommendations are adapted for admins, adults, teens, and children.
- Members update only their own participation where appropriate.
- Private schedule labels are not exposed as family availability details.
- AI context excludes invitation codes, raw identifiers, and unnecessary personal data.
- The Digital Twin describes recorded behavior rather than emotional health.
- Sakan does not automatically create a Moment or task without user confirmation.

## Technology

- Flutter and Dart
- Material 3
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Functions
- Firebase Storage foundation
- Protected OpenAI integration
- `go_router`
- `table_calendar`
- local Android notifications and timezone support

## Project Structure

```text
lib/
├── app/
├── core/
├── features/
│   ├── assistant/
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
│   ├── rhythm/
│   └── weekly_report/
├── routes/
└── shared/

functions/src/
├── auth.ts
├── context.ts
├── index.ts
├── openai.ts
├── prompts.ts
├── rate_limit.ts
└── validation.ts
```

## Run Locally

Requirements:

- a Flutter SDK compatible with the lockfile;
- Android Studio and the Android SDK for Android builds;
- a configured Firebase project;
- the platform Firebase configuration files;
- authorized backend configuration for runtime AI features.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

## Documentation

- [`docs/product_specification.md`](docs/product_specification.md)
- [`docs/app_flow.md`](docs/app_flow.md)
- [`docs/data_model.md`](docs/data_model.md)
- [`docs/firestore_structure.md`](docs/firestore_structure.md)
- [`docs/implementation_status.md`](docs/implementation_status.md)
- [`docs/ai_usage_log.md`](docs/ai_usage_log.md)

## Known Limitations

- Remote push invitations are not guaranteed while the receiving application is fully closed.
- Bluetooth proximity evidence is not part of the current MVP.
- Photo storage remains a limited workflow.
- AI output depends on backend and model availability; factual fallbacks remain available.
- Final regression testing is still required across different Android versions and screen sizes.

## Team

- Rahma Reda
- Yasmine Yousof
- Hala Mohammed

## Responsible AI Use

AI tools supported research, product critique, interface exploration, debugging, testing guidance, prompt refinement, and documentation. The team made the product decisions, reviewed every accepted change, configured the services, validated the data behavior, and tested the application. See [`docs/ai_usage_log.md`](docs/ai_usage_log.md) for details.
