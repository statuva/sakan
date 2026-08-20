# Memory Firestore Example

Create memories only from real completed family moments. Do not use this as evidence of research results.

Path:

```text
families/{familyId}/memories/{memoryId}
```

Expected fields:

```text
familyId: string
momentId: string
title: string
occurredAt: timestamp
photoUrls: array<string>
participantIds: array<string>
note: string | null
aiReflection: string | null
createdAt: timestamp
updatedAt: timestamp
```

Example:

```text
title: "Ali's School Celebration"
photoUrls: ["https://.../photo1.jpg", "https://.../photo2.jpg"]
note: "The family celebrated together after the ceremony."
aiReflection: "This memory records a similar family milestone and may help the family prepare the practical details for Ali's upcoming graduation."
```

The Calendar intentionally hides the Memory card when no memory with photos exists.
