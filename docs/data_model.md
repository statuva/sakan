# Sakan Data Model

## Purpose

Sakan stores observable, scheduled, or user-confirmed information about meaningful family Moments. The data model separates reusable definitions from concrete occurrences so the Digital Twin can distinguish planning from what actually happened.

```text
Family
├── Members
├── Moment Definitions
│   └── Moment Instances
│       └── Participant Records
├── Rhythm Records
├── Care Actions
├── Memories
├── Schedules and Availability
└── Daily Reviews
```

Computed Family Insights read from these records but are not the source of truth.

## Core Principles

1. A Calendar entry is not proof that an activity happened.
2. A recurring Moment definition remains reusable after one occurrence finishes.
3. Each member confirms only their own participation.
4. Rhythm state is derived from occurrence history.
5. Private schedule labels are not exposed through family availability.
6. The Digital Twin reports recorded patterns, not emotions or relationship quality.
7. External AI may interpret verified facts but may not determine factual state.

## User

Represents one Firebase Authentication account.

Account-level Firestore data may include:

| Field | Purpose |
|---|---|
| `email` | Sign-in/contact identifier |
| `displayName` | Account display name |
| `photoUrl` | Optional profile image reference |
| `familyIds` | Families linked to the account |
| `currentFamilyId` | Currently selected family |
| `createdAt`, `updatedAt` | Audit timestamps |

## Family

Represents one shared family space.

| Field | Purpose |
|---|---|
| `name` | Family name |
| `createdBy` | Creating account |
| `setupComplete` | Whether the baseline setup is complete |
| `baselineCreatedAt` | When initial rhythm setup was saved |
| `baselineCreatedBy` | Admin who completed setup |
| `createdAt`, `updatedAt` | Audit timestamps |

A Family contains members, Moment definitions, occurrences, reminders, rhythms, Memories, schedules, and reviews.

## Member

Represents one authenticated user inside one family.

| Field | Purpose |
|---|---|
| `id` | Member document ID, normally matching the user's UID |
| `familyId` | Parent family |
| `displayName` | Name visible inside the family |
| `role` | `admin`, `adult`, or `child` |
| `ageGroup` | Member age category |
| `relationship` | Parent, child, sibling, grandparent, and related values |
| `interests` | Selected interests |
| `preferredDays` | Preferred family-time days |
| `preferredStartMinutes`, `preferredEndMinutes` | Preferred time range |
| `isActive` | Whether the membership is active |
| `joinedAt`, `updatedAt` | Audit timestamps |

## Schedule Block

Stores one member's private schedule item.

Two forms are supported:

```text
Weekly routine
One-time unavailable period
```

A weekly routine may repeat on multiple selected weekdays. A one-time item stops affecting availability after it expires.

Private labels belong to the owning member.

## Availability Block

A label-free family-level representation of busy time.

It contains enough information to calculate overlap while avoiding exposure of private labels such as school, work, or medical appointments.

## Family Moment

A reusable definition of something meaningful to the family.

| Field | Purpose |
|---|---|
| `id` | Moment identifier |
| `familyId` | Parent family |
| `title` | Moment name |
| `type` | `recurring` or `singular` |
| `category` | Tradition, milestone, responsibility, care, family time, or memory |
| `importanceLevel` | Integer from 1 to 5 |
| `expectedParticipantIds` | Normally associated family members |
| `startAt`, `endAt` | Current/default planned timing |
| `expectedIntervalDays` | Recurring interval |
| `location` | Optional location |
| `notes` | Description |
| `evidenceType` | Configured evidence approach |
| `status` | Compatibility/planning status |
| `createdBy`, `createdAt`, `updatedAt` | Ownership and audit fields |

For recurring Moments, the definition does not become permanently completed after one occurrence.

## Moment Instance

Represents one planned or actual occurrence of a Family Moment.

| Field | Purpose |
|---|---|
| `id` | Occurrence identifier |
| `familyId` | Parent family |
| `momentId` | Reusable Moment definition |
| `titleSnapshot` | Historical title at the time of the occurrence |
| `typeSnapshot`, `categorySnapshot` | Historical type/category |
| `importanceLevelSnapshot` | Historical importance |
| `locationSnapshot` | Historical optional location |
| `expectedParticipantIds` | Expected members for this occurrence |
| `source` | Calendar, Family Insight, manual, spontaneous, or Today Review |
| `status` | Proposed, scheduled, inviting, active, completed, missed, or cancelled |
| `scheduledStartAt`, `scheduledEndAt` | Planned times |
| `actualStartAt`, `actualEndAt` | Recorded actual times |
| `actualDurationMinutes` | Recorded duration |
| `startedBy`, `endedBy` | Accounts controlling the session |
| `confirmedParticipantIds` | Members with recorded participation evidence |
| `evidenceSignals` | Evidence collected for this occurrence |
| `confirmationLevel` | Low, medium, or high evidence confidence |
| `isPartial` | Whether Today Review recorded partial completion |
| `createdBy`, `createdAt`, `updatedAt` | Ownership and audit fields |

## Moment Participant

One member's record inside one Moment Instance.

| Field | Purpose |
|---|---|
| `familyId` | Parent family |
| `instanceId` | Parent occurrence |
| `memberId` | Member represented by this document |
| `state` | Invited, nearby, checked in, declined, or left |
| `checkInMethod` | Manual, Bluetooth, QR, or Today Review |
| `checkedInAt`, `checkedOutAt` | Participation timestamps |
| `nearbyDetectedAt` | Optional proximity timestamp |
| `confirmedAt` | Confirmation timestamp |
| `createdAt`, `updatedAt` | Audit timestamps |

Security Rules should allow a member to create or update only the document whose ID matches their authenticated UID.

## Rhythm Record

Stores the current calculated state of one recurring Moment.

| Field | Purpose |
|---|---|
| `momentId` | Recurring Moment |
| `expectedIntervalDays` | Intended frequency |
| `lastOccurrenceAt` | Latest confirmed occurrence |
| `currentGapDays` | Days since the latest confirmed occurrence |
| `occurrenceCount` | Number of recorded completed occurrences |
| `status` | Still Learning, Stable, Drifting, Recovering, or Strengthening |
| `confidence` | Low, medium, or high |
| `updatedAt` | Recalculation timestamp |

Rhythms are recalculated from completed and missed Moment Instances.

## Care Action

A personal preparation task or reminder.

| Field | Purpose |
|---|---|
| `familyId` | Parent family |
| `momentId` | Optional related Moment |
| `title` | Action title |
| `reason` | Supporting note |
| `assignedMemberId` | Member responsible |
| `dueAt` | Due date and time |
| `status` | Pending, in progress, completed, or skipped |
| `source` | Manual, Calendar, Digital Twin, or Schedule |
| `evidenceType` | Optional evidence approach |
| `completedAt` | Completion timestamp |
| `createdAt`, `updatedAt` | Audit timestamps |

Care Actions are not shared Moment sessions.

## Family Memory

A record connected to one meaningful completed occurrence.

| Field | Purpose |
|---|---|
| `familyId` | Parent family |
| `momentId` | Reusable Moment definition |
| `instanceId` | Optional exact Moment Instance |
| `title` | Memory title |
| `occurredAt` | Occurrence date |
| `photoUrls` | Optional media references |
| `participantIds` | Recorded participants |
| `note` | Family note |
| `aiReflection` | Optional future AI-written reflection |
| `createdAt`, `updatedAt` | Audit timestamps |

The current application can preserve separate Memories for separate Moment Instances.

## Daily Review

Stores the family's review of unresolved recent occurrences.

It supports:

```text
Happened
Didn't Happen
Reschedule
Log an unplanned Moment
```

Review results update the relevant Moment Instance and may trigger rhythm recalculation or next-occurrence creation.

## Family Insight Snapshot

A computed, read-only snapshot containing the current family context required for insight generation:

```text
Members
Moment definitions
Moment Instances
Rhythms
Availability
Care Actions
Memories
Active session
Upcoming occurrences
Completed and missed history
```

## Family Insight Report

A computed result containing:

```text
Primary insight
Secondary insights
Action type
Best recorded availability
Per-family metrics
Confidence
Privacy-minimized future AI payload
```

The report is derived data. Firestore entities remain the source of truth.

## Evidence Signals

Possible evidence signals include:

```text
Scheduled
Host started
Manual check-in
Multiple check-ins
Duration recorded
Bluetooth nearby
QR check-in
Today Review
Family note
Memory created
```

Bluetooth remains optional and is not currently required by the MVP.
