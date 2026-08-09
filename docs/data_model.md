# Sakan Data Model

## purpose
This document defines the core data architecture of Sakan.

Sakan is built around a **Family Digital Twin**, which models meaningful family moments, recurring traditions, participation history, and important one-time events.

The system only stores **observable or user-confirmed information**.

The Digital Twin must never infer emotions, relationship strength, or psychological states directly. Instead, it analyzes measurable family behavior over time.

---

# System Architecture
```
User
        │
        ▼
Family Member
        │
        ▼
Family
        │
        ├───────────────┐
        │               │
        ▼               ▼
Family Moment      Family Session
        │               │
        │               ▼
        │        NFC Check-in / Check-out
        │
        ├───────────────┐
        ▼               ▼
Rhythm Record      Care Actions
        │               │
        └───────┬───────┘
                ▼
        Family Digital Twin
                │
                ▼
 Recommendations
 Weekly Reports
 What-if Simulation
 ```
--- 
# Core Entities

# User
## Purpose
Represents one authenticated account.

Authentication information belongs here.

## Fields
| Field | Description |
|--------|-------------|
| userId | Unique account identifier |
| email | Login email |
| displayName | User display name |
| profileImage | Profile picture |
| createdAt | Account creation date |
| lastLogin | Last login |
| notificationSettings | User notification preferences |

## Relationships
- One User belongs to one Family.
- One User owns one Family Member profile.

---

# Family
## Purpose
Represents one family inside Sakan.

Everything else belongs to a Family.

## Fields
| Field | Description |
|--------|-------------|
| familyId | Unique family identifier |
| familyName | Family name |
| country | Country |
| city | City |
| language | Preferred language |
| adminId | Family owner |
| createdAt | Creation date |


## Relationships
A Family contains:

- Family Members
- Family Moments
- Family Sessions
- Rhythm Records
- Care Actions
- Weekly Reports
- One Sakan Hub

---

# Family Member
## Purpose
Represents one member inside a family.

## Fields

| Field | Description |
|--------|-------------|
| memberId | Unique member ID |
| userId | Linked User |
| familyId | Parent family |
| name | Display name |
| role | Parent / Child / Grandparent |
| avatar | Profile image |
| preferredTimes | Preferred family activity times |
| interests | Selected interests |

## Relationships
A Family Member:

- Participates in Family Moments
- Completes Care Actions
- Checks into Sessions
- Appears in the Family Moment Graph

---

# Family Moment
## Purpose
Represents one meaningful family moment.

A Family Moment can be:

- Recurring
- One-time

## Fields
| Field | Description |
|--------|-------------|
| momentId | Unique identifier |
| familyId | Parent family |
| title | Moment title |
| type | Recurring / Singular |
| category | Tradition / Milestone / Care / Responsibility |
| importance | Low / Medium / High |
| expectedParticipants | Expected family members |
| recurrencePattern | Weekly / Monthly / None |
| scheduledDate | Planned date |
| location | Optional |
| notes | Optional |

## Relationships
A Family Moment:

- Has many Moment Instances
- Can generate Care Actions
- Can generate Rhythm Records
- Appears in the Family Moment Graph

---


# Moment Instance
## Purpose
Represents one occurrence of a Family Moment.

Example:

Friday Lunch is recurring.

Each Friday Lunch is one Moment Instance.

## Fields

| Field | Description |
|--------|-------------|
| instanceId | Unique identifier |
| momentId | Parent moment |
| scheduledAt | Planned time |
| startedAt | Actual start |
| endedAt | Actual end |
| duration | Total duration |
| participants | Actual participants |
| evidenceType | NFC / User Confirmation / Photo |
| status | Completed / Missed |

## Relationships
Belongs to one Family Moment.

Updates the Rhythm Engine.

---


# Family Session
## Purpose
Represents an active family activity.

Usually started using the Sakan Hub.

## Fields
| Field : Description |
| Field | Description |
|--------|-------------|
| sessionId | Unique identifier |
| familyId | Parent family |
| momentId | Related Family Moment |
| startedAt | Session start |
| endedAt | Session end |
| duration | Total time |
| participantIds | Members present |
| checkInEvidence | NFC records |
| checkOutEvidence | NFC records |

## Relationships
Creates a Moment Instance.

Updates Rhythm Records.

Updates the Digital Twin.

---

# Care Action
## Purpose
Represents one meaningful preparation task.

## Example
Ali's Graduation
↓
Prepare gift
Leave work early
Bring camera

## Fields
| Field | Description |
|--------|-------------|
| actionId | Unique identifier |
| momentId | Related moment |
| assignedTo | Family member |
| title | Action title |
| dueDate | Deadline |
| status | Pending / Completed |
| evidence | Optional proof |

## Relationships
Belongs to one Family Moment.

Displayed inside Calendar and Digital Twin.

---

# Rhythm Record
## Purpose
Tracks recurring family traditions.

## Fields
| Field | Description |
|--------|-------------|
| rhythmId | Unique identifier |
| momentId | Related recurring moment |
| expectedInterval | Expected frequency |
| currentGap | Days since last occurrence |
| confidence | Low / Medium / High |
| status | Stable / Drifting / Recovering / Strengthening / Still Learning |
| history | Previous occurrences |

## Relationships
Generated from Moment Instances.

Displayed inside the Digital Twin.

---

# Sakan Hub
## Purpose
Represents the shared NFC Hub.

The Hub records intentional participation in home-based family activities.

## Fields
| Field | Description |
|--------|-------------|
| hubId | Unique hub ID |
| familyId | Linked family |
| location | Dining room / Majlis / Living room |
| registeredAt | Registration date |
| status | Active / Inactive |

## Relationships
Verifies:

- Check-in
- Check-out
- Family Sessions

---

# Recommendation
## Purpose
Represents one AI recommendation.

Recommendations are generated only from:

1. Rhythm Drift
2. Upcoming Significant Moment
3. Family Priority

## Fields
| Field | Description |
|--------|-------------|
| recommendationId | Unique identifier |
| familyId | Parent family |
| title | Recommendation |
| reason | Explanation |
| trigger | Rhythm / Care / Priority |
| createdAt | Generation time |
| completed | Yes / No |

---

# Weekly Report
## Purpose
Summarizes one week of family activity.

## Fields
| Field | Description |
|--------|-------------|
| reportId | Unique identifier |
| familyId | Parent family |
| weekStart | Start date |
| weekEnd | End date |
| stableRhythms | List |
| driftingRhythms | List |
| careCompleted | List |
| nextBestAction | Recommendation |


---

# Notification
## Purpose
Stores all app notifications.

## Types
- Rhythm Alert
- Care Reminder
- Upcoming Moment
- Family Session
- Weekly Report

---

# Evidence Types
Every completed moment must specify its evidence source.

Possible values:

- NFC Verified
- User Confirmed
- Photo Attached
- Scheduled Only

This allows the Digital Twin to distinguish between verified and self-reported participation.

---

# Data Principles

1. Never infer emotions.
2. Never calculate fake relationship scores.
3. Every AI insight must reference measurable data.
4. Every recommendation must explain its reasoning.
5. Recurring moments are handled by the Rhythm Engine.
6. One-time moments are handled by the Care Engine.
7. The Family Digital Twin combines all entities into one behavioral model.

