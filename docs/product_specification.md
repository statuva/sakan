# Sakan Product Specification

## 1. Product Summary

Sakan is a software-first family rhythm assistant. It helps a household define meaningful recurring and one-time Moments, plan concrete occurrences, confirm what actually happened, preserve Memories, and understand changes in recurring family patterns.

The core product loop is:

```text
Define → Plan → Gather → Confirm → Learn → Remember → Act → Repeat
```

## 2. Problem

Families often want to preserve shared routines and prepare for important events, but:

- schedules conflict;
- plans are forgotten;
- recurring traditions quietly become less regular;
- calendar entries do not prove an activity happened;
- one person may carry all preparation work;
- family history is fragmented across chats and photo galleries;
- existing tools rarely distinguish planned activity from confirmed participation.

## 3. Product Goals

Sakan should:

1. Give the family one place to define meaningful Moments.
2. Separate reusable Moment definitions from concrete occurrences.
3. Help members find shared recorded availability.
4. Support live shared sessions and self check-in.
5. Capture outcomes when the app was not used through Today Review.
6. Update recurring rhythm states from recorded evidence.
7. Preserve optional Memories for completed occurrences.
8. Surface a grounded next action.
9. Present family patterns through a Digital Twin.
10. Keep adults, children, and private schedule data appropriately separated.

## 4. Non-Goals

The MVP does not attempt to:

- diagnose family health;
- infer emotions or relationship strength;
- monitor family members continuously;
- require a physical Hub;
- make Bluetooth mandatory;
- automatically mark a Moment complete from proximity alone;
- allow AI to change factual state;
- replace a full calendar provider;
- provide a general-purpose chatbot.

## 5. Users and Roles

### Admin

May manage family configuration, members, Moment definitions, shared sessions, Today Review, Memories, and family settings.

### Adult

May manage appropriate Moment definitions, start and end shared sessions, complete Today Review, create Memories, and manage personal schedules and reminders.

### Child

May view relevant Moments, join a live session, update only their own participation record, view summaries and Memories, and manage their own permitted settings. A child does not receive family-administration controls.

## 6. Core Product Areas

### Home

A personalized summary of what matters now. The final Home screen is still in progress.

### Digital Twin

A visual and factual view of family-member connections and the recorded state of each recurring Moment.

### Moments

The reusable Family Moment library. This area owns definition and configuration, not rhythm-health interpretation.

### Calendar

The date-based occurrence view. This area owns Month, Week, and Agenda planning, occurrence details, and time-sensitive actions.

### Profile

Personal and authorized family configuration, including schedules, reminders, notification settings, privacy, and family administration.

## 7. Core Functional Requirements

### Family Setup

- Admin selects or creates family traditions.
- Admin configures expected frequency, importance, and participants.
- Setup creates the Family Moment, Rhythm Record, and first scheduled Moment Instance.

### Family Moments

- Adult/admin can create, edit, or delete a definition.
- Child receives a read-only view.
- Outer cards show name, category, and importance.
- Rhythm status does not appear in the Moment Library.

### Moment Instances

- One instance represents one planned or actual occurrence.
- Statuses include proposed, scheduled, inviting, active, completed, missed, and cancelled.
- Recurring completion or a missed occurrence can generate one next scheduled instance.

### Calendar

- Supports Month, Week, and Agenda views.
- Displays concrete Moment Instances.
- Supports category and current-member filters.
- Opens details for the selected occurrence.
- Provides access to active sessions, Today Review, and grounded insight actions.

### Live Moment

- Adult/admin may start an eligible shared Moment.
- The starter is checked in automatically.
- Members may check themselves in or out.
- The timer is calculated from the stored start time.
- Adult/admin may end or cancel the session.
- Ending stores actual duration, confirmed participants, evidence signals, and confirmation level.

### Today Review

- Adult/admin can resolve past scheduled occurrences.
- Supported outcomes include Happened, Didn't Happen, and Reschedule.
- The family may log an unplanned completed Moment.
- Review evidence is recorded separately from live self check-ins.

### Rhythms

- Recurring Moments can be Still Learning, Stable, Drifting, Recovering, or Strengthening.
- Rhythm state is based on completed/missed instance history and expected interval.
- Rhythm state is not an emotional or relationship score.

### Care Actions and Reminders

- Personal tasks remain separate from shared sessions.
- A user may add, edit, complete, uncomplete, or delete a permitted reminder.
- Calendar and future AI suggestions require user approval before creating a reminder.
- Local Android notification scheduling is supported.

### Memories

- A Memory belongs to a completed Moment and may reference one exact Moment Instance.
- Current content includes a title, date, participants, note, and optional media references.
- The family can view the latest Memory and an All Memories list.

### Family Insights

- Deterministic logic selects a grounded observation or next action.
- Inputs include Moments, instances, rhythms, schedules, reminders, members, and Memories.
- Actions may include Join, Start, Review, Add Reminder, Open Reminders, Schedule, or Manage.
- External AI is not required for the deterministic fallback.

### Digital Twin

- Shows family-member and recurring-Moment connections.
- Shows rhythm state per Moment rather than one unsupported family score.
- Offers transparent supporting data.
- Must not infer emotions, blame individual members, or claim medical/psychological conclusions.

## 8. AI Design

The future AI layer will improve natural-language interpretation.

```text
Verified Sakan facts
        ↓
Privacy-minimized payload
        ↓
Protected backend
        ↓
External model
        ↓
Validated structured response
        ↓
Human-visible interpretation
```

Sakan remains responsible for dates, statuses, participants, availability, evidence, confidence, and action type. The AI may improve wording and organize suggestions but cannot silently create or complete actions.

## 9. Evidence Model

Current evidence may include:

- scheduled occurrence;
- host-started session;
- manual self check-in;
- multiple check-ins;
- recorded duration;
- Today Review;
- family note;
- Memory created.

Future optional evidence may include Bluetooth proximity or QR check-in. Proximity alone is not participation proof.

## 10. Privacy Requirements

- Private schedule labels stay private.
- Family availability uses label-free busy intervals.
- Members update only their own participation record.
- Child accounts receive restricted controls.
- Runtime AI payloads should exclude direct identifiers and private text unless strictly necessary and consented.
- API keys must remain on a protected backend.
- The Digital Twin must describe recorded patterns rather than emotional or psychological state.

## 11. MVP Completion Criteria

The MVP is complete when this flow passes with multiple family accounts:

```text
Create or join family
→ complete setup
→ create recurring Moment
→ schedule occurrence
→ start live session
→ another member checks in
→ end session
→ rhythm updates
→ next occurrence appears
→ Memory can be saved
→ Family Insight and Digital Twin update
→ personal preparation reminder can be created
→ notification can be delivered
```

The remaining major product work is the personalized Home screen, protected AI interpretation, full regression testing, final UI polish, and release documentation.
