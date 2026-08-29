# Sakan Application Flow

## Core Loop

```text
Define a Family Moment
        ↓
Plan one Moment Instance
        ↓
Start it live or resolve it through Today Review
        ↓
Members confirm their own participation
        ↓
Record actual duration and outcome
        ↓
Recalculate the recurring rhythm
        ↓
Create the next occurrence when needed
        ↓
Optionally preserve a Memory
        ↓
Family Insights and Digital Twin update
```

## Onboarding Flow

```text
Open Sakan
    ↓
Sign in or create account
    ↓
Create a family or join by invitation code
    ↓
Admin completes Family Setup
    ↓
Select recurring traditions
    ↓
Configure frequency, importance, and expected participants
    ↓
Create initial Moment definitions, Rhythm Records, and scheduled instances
    ↓
Enter the main application
```

Non-admin members who join before setup is complete wait for the family admin. The page updates when setup is completed.

## Recurring Family Moment Flow

```text
Moment Library
    ↓
Create or edit "Movie Night"
    ↓
First scheduled Moment Instance exists
    ↓
Occurrence appears in Calendar
    ↓
Adult/Admin selects Start This Now
    ↓
Active Moment screen opens
    ↓
Starter is checked in automatically
    ↓
Other members select I'm Here
    ↓
Timer reflects actualStartAt
    ↓
Adult/Admin ends the session
    ↓
Actual end, duration, participants, and evidence are saved
    ↓
Rhythm recalculates
    ↓
One next scheduled occurrence is created
    ↓
Digital Twin reflects the updated pattern
```

## One-Time Milestone or Care Flow

```text
Add one-time Family Moment
    ↓
Occurrence appears in Calendar
    ↓
Family Insight identifies preparation need
    ↓
User reviews suggestion
    ↓
User approves Add Reminder
    ↓
Care Action appears in My Reminders
    ↓
Local notification is scheduled
    ↓
User completes or updates the reminder
```

The preparation reminder is a personal task. It is not the shared family occurrence itself.

## Today Review Flow

```text
A planned occurrence passes without a live result
    ↓
Sakan marks it as needing review
    ↓
Adult/Admin opens Today Review
    ↓
Choose Happened, Didn't Happen, or Reschedule
```

### Happened

```text
Enter approximate time, duration, and participants
    ↓
Store completed Moment Instance with Today Review evidence
    ↓
Update rhythm
    ↓
Offer Memory creation
```

### Didn't Happen

```text
Mark occurrence Missed
    ↓
Update rhythm
    ↓
Create the next recurring occurrence
```

### Reschedule

```text
Update the open occurrence date
    ↓
Keep one occurrence instead of creating a duplicate
```

### Unplanned Moment

```text
Log something the family did together
    ↓
Create a completed one-time instance
    ↓
Optionally save it as a reusable recurring Moment
```

## Memory Flow

```text
Completed Moment Instance
    ↓
Create Memory
    ↓
Save title, date, participants, family note, and optional media references
    ↓
View from session summary, Calendar, or All Memories
```

## Digital Twin Flow

```text
Members + Moment definitions + instance history + rhythms
    ↓
Build member-to-Moment map
    ↓
Show the state of each recurring Moment
    ↓
Explain supporting evidence
    ↓
Surface a family-level interpretation
```

The Digital Twin is informational. Operational actions remain in Calendar, Live Moment, Moments, and My Reminders.

## Role-Aware Behavior

### Admin and Adult

May create/edit Moments, start/end shared sessions, submit Today Review, create Memories, and manage permitted family settings.

### Child

May view relevant content, join an active Moment, update only their own check-in state, and view session summaries and Memories. A child does not receive admin controls.

## Hardware and Proximity

The current MVP does not require a physical Hub.

Manual self check-in is the primary confirmation method. Bluetooth may later add optional nearby evidence during an active session, but it must not automatically prove participation or block the manual flow.
