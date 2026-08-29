# Sakan Firestore Structure

## Collection Tree

```text
users/{userId}

invitations/{code}

families/{familyId}
├── members/{memberId}
│   └── scheduleBlocks/{blockId}
├── availabilityBlocks/{blockId}
├── moments/{momentId}
├── momentInstances/{instanceId}
│   └── participants/{memberId}
├── careActions/{actionId}
├── rhythms/{momentId}
├── memories/{memoryId}
├── dailyReviews/{reviewId}
└── hubs/{hubId}                 # legacy/future optional; not required by MVP
```

## `users/{userId}`

Stores account-level data and the selected family.

Typical fields:

```text
email
displayName
photoUrl
familyIds
currentFamilyId
createdAt
updatedAt
```

A signed-in user may access only their own user document.

## `invitations/{code}`

Stores one temporary family invitation. The invitation code is the document ID so the app can perform a direct lookup without listing invitations.

Typical fields:

```text
code
familyId
familyName
createdBy
isActive
expiresAt
createdAt
```

Invitation collections should not be listable by normal clients.

## `families/{familyId}`

Stores shared family metadata.

Typical fields:

```text
name
createdBy
setupComplete
baselineCreatedAt
baselineCreatedBy
createdAt
updatedAt
```

## `families/{familyId}/members/{memberId}`

Represents one authenticated account inside the family. The document ID normally matches the user's Firebase Authentication UID.

Typical fields:

```text
familyId
displayName
role
ageGroup
relationship
photoUrl
interests
preferredDays
preferredStartMinutes
preferredEndMinutes
notificationPreferences
privacyConsent
isActive
joinedAt
updatedAt
```

## `members/{memberId}/scheduleBlocks/{blockId}`

Stores the member's private schedule details.

Typical concepts:

```text
weekly or one-time
private label
repeat weekdays
one-time date
start minutes
end minutes
createdAt
updatedAt
```

Only the owning member should read or modify these detailed schedule records.

## `families/{familyId}/availabilityBlocks/{blockId}`

Stores family-readable, label-free busy intervals derived from personal schedules.

Typical fields:

```text
familyId
memberId
kind
repeatDays or scheduledDate
startMinutes
endMinutes
createdAt
updatedAt
```

Family members may read availability, but only the owning member may create, update, or delete their blocks.

## `families/{familyId}/moments/{momentId}`

Stores one reusable Family Moment definition.

Typical fields:

```text
familyId
title
type
category
importanceLevel
expectedParticipantIds
startAt
endAt
expectedIntervalDays
location
notes
evidenceType
status
createdBy
createdAt
updatedAt
```

Adults/admins manage shared Moment definitions.

## `families/{familyId}/momentInstances/{instanceId}`

Stores one planned or actual occurrence.

Typical fields:

```text
familyId
momentId
titleSnapshot
typeSnapshot
categorySnapshot
importanceLevelSnapshot
locationSnapshot
expectedParticipantIds
source
status
scheduledStartAt
scheduledEndAt
actualStartAt
actualEndAt
actualDurationMinutes
startedBy
endedBy
confirmedParticipantIds
evidenceSignals
confirmationLevel
isPartial
createdBy
createdAt
updatedAt
```

Adults/admins may create and manage the shared occurrence document. Family members may read occurrences.

## `momentInstances/{instanceId}/participants/{memberId}`

Stores one member's participation record.

Typical fields:

```text
familyId
instanceId
memberId
state
checkInMethod
checkedInAt
checkedOutAt
nearbyDetectedAt
confirmedAt
createdAt
updatedAt
```

A family member may create or update only their own participant document.

## `families/{familyId}/careActions/{actionId}`

Stores personal preparation actions and reminders.

Typical fields:

```text
familyId
momentId
title
reason
assignedMemberId
dueAt
status
source
evidenceType
completedAt
createdAt
updatedAt
```

Adults/admins may manage permitted family actions. Other members may access only actions assigned to themselves.

## `families/{familyId}/rhythms/{momentId}`

Stores the calculated state of one recurring Family Moment.

Typical fields:

```text
familyId
momentId
expectedIntervalDays
lastOccurrenceAt
currentGapDays
occurrenceCount
status
confidence
updatedAt
```

The document ID may match the Moment ID.

## `families/{familyId}/memories/{memoryId}`

Stores one Family Memory.

Typical fields:

```text
familyId
momentId
instanceId
title
occurredAt
photoUrls
participantIds
note
aiReflection
createdAt
updatedAt
```

`instanceId` may be absent on older documents.

## `families/{familyId}/dailyReviews/{reviewId}`

Stores a review of recent unresolved occurrences.

Typical concepts:

```text
review date
reviewedBy
reviewedAt
resolved instance IDs
selected outcomes
confirmation of no additional unplanned Moments
```

Adults/admins may write a family review. Family members may read permitted family review data.

## `families/{familyId}/hubs/{hubId}`

This collection may remain in the repository for compatibility with the original architecture. A physical Hub is not required by the current MVP and should not be presented as a working dependency.

Future proximity evidence should remain optional.

## Security Principles

1. All protected reads and writes require authentication.
2. Family documents are accessible only to members of that family.
3. Admin-only operations stay restricted.
4. Children do not receive family-administration writes.
5. Members update only their own participant record.
6. Private schedule labels remain under the owning member.
7. Family-level availability contains no private labels.
8. Reminder ownership and assignment cannot be silently changed.
9. External AI credentials are never stored in Firestore client-readable documents.
