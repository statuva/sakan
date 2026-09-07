# AI Usage

This document explains where artificial intelligence is used in Sakan's product and how AI tools supported the development process. In both cases, AI is treated as an assistive layer: recorded family data and human decisions remain authoritative.

## AI Inside the Application

Sakan combines deterministic application logic with a protected generative-AI service.

The deterministic layer calculates facts such as:

- scheduled, completed, missed, cancelled, or unresolved occurrences;
- recorded participants and duration;
- member availability and schedule conflicts;
- recurring rhythm state and confidence;
- recommendation urgency and valid user actions;
- whether a reminder or preparation task already exists.

The AI layer receives a privacy-minimized summary of relevant facts and produces concise, useful language. It is used for:

| Product area | AI contribution |
|---|---|
| **Ask Sakan** | Answers grounded family questions, identifies one relevant pattern, explains why it matters, and suggests one specific next step. |
| **Home** | Expresses the highest-priority current action briefly and clearly. |
| **Calendar** | Helps present event-specific and role-appropriate preparation recommendations. |
| **Digital Twin** | Summarizes the family's overall recorded rhythm without repeating every per-Moment pattern. |
| **Simulation** | Explains the practical benefit of a proposed activity and helps present a schedule-aware option before the user chooses whether to create it. |
| **Memories** | Reflects on the family value visible in a completed Memory instead of simply rewording its note. |
| **Weekly report** | Interprets the week's recorded evidence while keeping incomplete data and low confidence explicit. |

Recommendations may lead to actions such as starting a Moment, reviewing an occurrence, adding a reminder, preparing a message or gift, coordinating a participant, or trying a simulation. The exact recommendation depends on the Moment, urgency, schedule, history, and the signed-in member's role and age group.

## Runtime Safeguards

- Runtime requests pass through authenticated Firebase Cloud Functions.
- AI credentials are kept on the server and are not included in the Flutter application.
- Inputs are validated and minimized before being sent to the model.
- Access is checked against family membership, role, age group, active status, and privacy consent where required.
- Rate and usage controls protect the shared service.
- Responses are constrained to the supplied family evidence.
- Deterministic fallbacks support core insight surfaces when the AI service is unavailable.
- Users approve actions before Sakan creates or changes Moments and reminders.

The AI is not permitted to determine or invent:

- whether a Moment happened;
- who participated;
- actual duration;
- schedule availability;
- rhythm state or confidence;
- private family information not included in the request;
- a completed action that the user did not confirm.

## Development Support

During development, AI tools were used as supporting resources in the following areas:

| Area | How AI supported the team | Team responsibility |
|---|---|---|
| **Concept review** | Challenged early assumptions and helped distinguish measurable family activity from unsupported emotional scoring. | The team chose the final problem, scope, ethical boundaries, and product direction. |
| **Architecture discussion** | Helped compare data structures, Firebase approaches, privacy boundaries, and deterministic-versus-generative responsibilities. | The team selected the architecture, configured Firebase, and validated application behavior. |
| **Interface exploration** | Helped explore layouts, information hierarchy, wording, visual identity, and accessibility considerations. | The team chose the final designs and tested them on target devices. |
| **Troubleshooting** | Helped investigate authentication, permissions, Firestore, notifications, Android builds, layout overflow, and integration errors. | The team reproduced issues, applied selected fixes, and confirmed outcomes in the application. |
| **AI behavior design** | Helped refine prompts, shorten responses, define role-aware recommendations, and strengthen privacy and grounding rules. | The team decided the expected behavior and evaluated responses using controlled family data. |
| **Testing and documentation** | Helped organize test cases, review edge cases, and improve technical and submission documentation. | The team performed the tests and verified that documentation matched the implemented product. |

AI suggestions were not accepted automatically. The team reviewed proposed changes, checked repository differences, tested multi-account behavior, and rejected outputs that were inaccurate, repetitive, visually unsuitable, or inconsistent with Sakan's principles.

## Human Accountability

The development team remained responsible for:

- defining Sakan's purpose and feature priorities;
- deciding which suggestions to accept, revise, or reject;
- managing the repository and pull-request workflow;
- configuring Firebase services and protected backend access;
- reviewing authentication, permissions, privacy, and Security Rules;
- testing admin, adult, teen, and child experiences;
- validating schedule, Moment, Memory, rhythm, and recommendation data;
- testing on physical mobile devices;
- confirming that runtime AI responses remain grounded and useful;
- ensuring that public documentation accurately represents the application.

## Current Status

As of 7 September 2026:

```text
Protected runtime AI backend: connected
Deterministic family insight and fallback layer: connected
Ask Sakan: connected
AI-supported Home, Calendar, Digital Twin, Simulation, Memory, and report experiences: connected
API key committed to the client or repository: no
User approval required before application actions: yes
```

Sakan's core principle is unchanged: **the application establishes the facts, AI helps explain them, and the family decides what to do.**
