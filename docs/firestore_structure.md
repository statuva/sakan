users/{userId}

families/{familyId}
├── members/{userId}
├── moments/{momentId}
├── momentInstances/{instanceId}
│   └── participants/{userId}
├── careActions/{careActionId}
├── rhythms/{momentId}
└── hubs/{hubId}


## users/{userId}
Stores account-level information for each authenticated user.
Fields:

- email
- displayName
- photoUrl
- familyIds
- currentFamilyId
- createdAt
- updatedAt


## families/{familyId}
Stores shared information about one family.

Fields:

- name
- createdBy
- countryCode
- city
- preferredLanguage
- setupComplete
- createdAt
- updatedAt

## families/{familyId}/members/{userId}
Represents a user inside a specific family.

The document ID should match the authenticated user's UID.

Fields:

- familyId
- displayName
- role
- ageGroup
- photoUrl
- interests
- preferredDays
- preferredStartMinutes
- preferredEndMinutes
- isActive
- joinedAt
- updatedAt


## families/{familyId}/moments/{momentId}
Stores both recurring traditions and one-time meaningful events.

Examples:

- Friday Lunch
- Family Majlis
- Grandparents Visit
- Ali's Graduation
- Grandma's Birthday

Fields:

- title
- type
- category
- importanceLevel
- expectedParticipantIds
- startAt
- endAt
- expectedIntervalDays
- location
- notes
- evidenceType
- status
- createdBy
- createdAt
- updatedAt


## families/{familyId}/momentInstances/{instanceId}
Stores one real occurrence of a Family Moment.

For example, "Friday Lunch" is a Family Moment, while the Friday Lunch that happened on August 14 is a Moment Instance.
Fields:

- momentId
- scheduledAt
- startedAt
- endedAt
- status
- evidenceType
- actualParticipantIds
- checkedInMemberIds
- checkedOutMemberIds
- createdAt
- updatedAt


## families/{familyId}/momentInstances/{instanceId}/participants/{userId}
Stores the participation evidence for one member during one Moment Instance.

Fields:

- memberId
- checkedInAt
- checkedOutAt
- checkInMethod
- checkOutMethod
- updatedAt

Possible methods:

- nfc
- manual
- userConfirmed

This structure will later allow Firestore Security Rules to ensure that a member can update only their own check-in/check-out record.


## families/{familyId}/careActions/{careActionId}
Stores an action connected to an important one-time Family Moment.

Example:
Ali's Graduation
Care Action:
"Prepare Ali's graduation gift"

Fields:

- momentId
- title
- reason
- assignedMemberId
- dueAt
- status
- evidenceType
- completedAt
- createdAt
- updatedAt


## families/{familyId}/rhythms/{momentId}
Stores the calculated state of a recurring Family Moment.
The document ID can match the recurring Moment ID.

Fields:
- momentId
- expectedIntervalDays
- lastOccurrenceAt
- currentGapDays
- occurrenceCount
- status
- confidence
- updatedAt

Possible rhythm statuses:
- stillLearning
- stable
- drifting
- recovering
- strengthening

Possible confidence values:
- low
- medium
- high


## families/{familyId}/hubs/{hubId}
Stores information about the family's registered Sakan Hub.

Fields:

- name
- locationLabel
- tagIdHash
- isActive
- registeredBy
- registeredAt
- lastScannedAt

Example:

- name: Sakan Hub
- locationLabel: Dining Room



## invitations/{code}

Stores a temporary invitation that allows an authenticated user to join a family.

The invitation code is used as the document ID so the app can perform a direct document lookup without listing all invitations.

Fields:

- code
- familyId
- familyName
- createdBy
- isActive
- expiresAt
- createdAt

Security requirements:

- A user must be authenticated to retrieve an invitation.
- Invitation collections cannot be listed.
- An invitation must be active and unexpired.
- A joining user may create only their own family-member record.
