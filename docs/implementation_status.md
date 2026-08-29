# Sakan Implementation Status

**Status date:** 29 August 2026

This document distinguishes implemented functionality from current refinement and future scope. It should be updated before final submission.

## Implemented

| Area | Current state |
|---|---|
| Flutter foundation | Material 3 application, routing, shared theme, reusable widgets |
| Authentication | Sign up, sign in, password reset, persisted Firebase Authentication session |
| Family access | Create family, invitation code, join family |
| Roles | Admin, adult, child |
| Family Setup | Member review, tradition selection, rhythm configuration, baseline creation |
| Profile | Personal information and family-linked persistence |
| Preferences and privacy | Family-time preferences, notification preferences, privacy settings |
| Schedules | Weekly multi-day routines and one-time unavailable periods |
| Availability | Label-free family busy intervals |
| Moment definitions | Recurring and one-time Family Moments |
| Moment Instances | Scheduled, active, completed, missed, cancelled occurrence records |
| Calendar | Month, Week, Agenda, filters, instance-based history |
| Live Moment | Start, timer, manual self check-in, leave/rejoin, end/cancel |
| Session summary | Actual duration, participants, evidence, confirmation level |
| Today Review | Happened, missed, reschedule, unplanned Moment |
| Rhythms | Still Learning, Stable, Drifting, Recovering, Strengthening |
| Recurrence | One next open instance generated after recurring outcomes |
| Memories | Add, edit, view, All Memories, optional instance link |
| Reminders | Add, edit, complete, uncomplete, delete, Calendar source |
| Notifications | Local Android scheduling integration |
| Family Insights | Deterministic priority/action engine and availability analysis |
| Digital Twin | Interactive map and per-Moment pattern information |

## Current Refinement

| Area | Remaining refinement |
|---|---|
| Moments navigation | Dedicated bottom tab and simplified archive cards |
| Moment Details | Read-only definition page before editing |
| Digital Twin map | Reduce line clutter and improve focused interaction |
| Digital Twin interpretation | Replace duplicate Calendar-style insight with family-pattern synthesis |
| Per-Moment Twin details | Add human interpretation first, supporting facts second |
| Notification testing | Complete Android permission, reschedule, cancellation, and tap regression |
| Role testing | Repeat full flow with admin, adult, and child accounts |
| UI polish | Resolve overflow, spacing, empty states, and small-screen issues |

## Not Implemented Yet

| Area | Planned role |
|---|---|
| Personalized Home | Unified summary and entry point |
| Protected external AI backend | Natural-language interpretation grounded in Sakan facts |
| What-if simulation | Explore hypothetical timing/frequency changes |
| Remote push invitation | Notify family members when an app is fully closed |
| Bluetooth proximity | Optional nearby evidence during a live Moment |
| Complete photo upload | Store and manage Memory photos |
| Full automated coverage | Expand beyond current model/service tests |

## Removed from the Required MVP

| Item | Decision |
|---|---|
| Physical Sakan Hub | Not required; creates cost and adoption friction |
| Mandatory Bluetooth | Manual self check-in remains the reliable core |
| Continuous location/proximity tracking | Outside current privacy and scope boundaries |
| General AI chatbot | Does not support the core rhythm loop |
| Automatic AI actions | User approval remains required |

## Final Completion Order

```text
1. Finish and test the dedicated Moments page
2. Refine Digital Twin interaction and interpretation layout
3. Build personalized Home
4. Connect one protected external AI interpretation flow
5. Run full admin/adult/child regression
6. Fix UI and reliability issues
7. Update documentation and AI log
8. Seed a stable demo family
9. Build and back up the Android APK
10. Rehearse the demo and Q&A
```

## Runtime AI Status

As of this status date:

```text
Deterministic Family Insights: implemented
External generative-AI calls from Sakan: not connected
OpenAI API key in Flutter or GitHub: none
Rule-based fallback: implemented
```
