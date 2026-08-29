# AI Usage Log

This log records how AI tools supported Sakan's development. AI outputs were treated as drafts, critiques, or implementation options. The development team selected the scope, integrated accepted changes, reviewed behavior, and performed testing.

| Date | Tool | Purpose | Human Review |
|---|---|---|---|
| 2026-08-05 – 2026-08-09 | External AI Critique Tool and ChatGPT | Reviewed the initial family-technology concept; challenged the use of attendance duration as a relationship score; helped reframe the product around measurable family Moments, recurring rhythms, observable participation, privacy boundaries, and an initial development plan. | The team rejected unsupported emotional or psychological assumptions, selected only measurable concepts, and converted the accepted direction into the project specification and architecture notes. |
| 2026-08-10 – 2026-08-14 | ChatGPT | Assisted with the Flutter foundation: design tokens, reusable components, primary navigation, domain models, repository contracts, demo-data interfaces, Firebase architecture, and Firestore collection planning. | The team adapted the proposed structure to the Flutter project, implemented it incrementally, reviewed imports and naming, and checked changes through formatting, analyzer runs, and repository commits. |
| 2026-08-15 – 2026-08-17 | ChatGPT | Assisted with authentication, family creation, invitation-based joining, family relationships, role-aware access, the four-step Family Setup flow, and initial rhythm-baseline creation. | The team integrated the flows with Firebase Authentication and Firestore, corrected join/setup synchronization issues, and tested the behavior with separate family accounts before merging. |
| 2026-08-17 – 2026-08-20 | ChatGPT and External AI UI Prototyping Tool | Assisted with Profile and settings persistence, weekly schedule design, Calendar/Moments layout exploration, UAE-oriented rhythm setup, Firestore data flow, and the first conservative codebase cleanup and Q&A documentation. | The team selected the final UI direction rather than accepting every prototype, removed demo values, verified profile/settings persistence, reviewed the cleanup diff, retained only safe structural changes, and tested on web and Android. |
| 2026-08-21 – 2026-08-22 | ChatGPT | Assisted with one-time versus repeating schedule entries, multi-day weekly routines, Memory creation and viewing, All Memories, personal reminders, and the relationship between Calendar suggestions and Care Actions. | The team integrated the changes into existing repositories and screens, checked Firestore persistence, verified add/edit/delete/complete flows, and adjusted UI problems found during manual testing. |
| 2026-08-23 – 2026-08-24 | ChatGPT | Assisted with local Android notification scheduling, timezone handling, permission behavior, notification cancellation/rescheduling, Android SDK 36 configuration, Gradle/JDK troubleshooting, and diagnosis of disk-space and JVM-memory failures. | The team edited Android configuration locally, installed the required SDK, corrected Gradle properties, reduced build memory pressure, freed disk space, rebuilt on a physical Android phone, and kept reminder data independent from notification permission. |
| 2026-08-24 – 2026-08-27 | ChatGPT | Assisted with the deterministic Family Insight snapshot/report/service, insight priority rules, privacy-minimized future AI payload, Moment Instance and participant models, Firestore Security Rules, live family sessions, elapsed timer logic, manual self check-in, cross-device updates, and session summaries. | The team chose the final separation between personal Care Actions and shared Moments, integrated the models and repositories, deployed/reviewed rules, and manually verified live start, check-in, leave/rejoin, end, summary, and simultaneous-session prevention. |
| 2026-08-28 | ChatGPT | Assisted with Today Review, happened/missed/rescheduled outcomes, unplanned Moment logging, rhythm recalculation from actual instances, one-next-occurrence generation, and instance-linked Memories. | The team integrated the feature through a dedicated branch and pull request, reviewed the Firestore effects, preserved completed history, and tested the review and recurrence scenarios before merge. |
| 2026-08-29 | ChatGPT with GitHub access and External AI UI Prototyping Tool | Reviewed the current repository and implementation trail; assisted with instance-based Calendar integration, action-specific Family Insights, Digital Twin map/pattern layout, simplification of the Moment Library, dedicated Moments navigation, and a read-only Moment Details flow. | The team merged the instance-based Calendar and Digital Twin work, compared the prototypes against the product responsibilities, removed duplicated concepts from screen designs, and kept the Moments redesign in a focused branch pending analyzer and device verification. |
| 2026-08-29 | ChatGPT | Explained OpenAI API billing, credit usage, privacy, key security, and the protected-backend architecture for a future AI interpretation layer. No API key was shared and no runtime OpenAI request was added to Sakan. | The team decided to postpone external AI calls until the deterministic data loop and major screens are stable. The final plan keeps Sakan responsible for facts and uses AI only for bounded wording and interpretation. |

## Runtime AI Status

As of 29 August 2026:

```text
External generative-AI requests made by the Sakan application: 0
Deterministic Family Insight engine: implemented
AI-ready privacy-minimized report: implemented
Protected external AI backend: not yet connected
API key committed to GitHub: no
```

## Human Review Statement

AI tools supported product critique, architecture discussion, UI prototyping, file-level implementation drafts, debugging, testing plans, documentation, and technical explanation.

The development team remained responsible for:

- defining the final product scope;
- deciding which suggestions to accept or reject;
- adapting drafts to the existing Flutter project;
- reviewing Firebase Authentication and Firestore behavior;
- reviewing and deploying Security Rules;
- resolving analyzer, runtime, Android, and layout problems;
- testing on Edge and physical Android devices;
- testing multi-account and role-aware behavior;
- reviewing pull-request diffs and commit history;
- validating that public documentation matches the actual implementation.

AI-generated or AI-assisted suggestions were not treated as evidence that a feature worked. A feature was considered accepted only after human integration and testing.
