# Technical Route

ChopChop uses a dual-entry demo strategy: a native iOS app for the full mobile experience and a Web-accessible demo layer for competition review through a browser URL.

## Native iOS App

The Native iOS App is developed with Xcode and represents the complete native prototype. It is responsible for:

- Full mobile interaction design.
- Task execution pages.
- Task status updates.
- Native iOS navigation and interaction patterns.

This project remains the primary expression of the intended mobile App experience.

## Web Demo

The Web Demo is built with HTML, CSS, and JavaScript, and is intended to be deployed to Vercel. It serves as the competition-friendly demo entry for the preliminary Demo URL requirement.

The Web Demo reproduces the core task planning loop:

1. The user enters a task description.
2. The system recognizes the task type and DDL.
3. The user confirms completed stages.
4. The system generates Robust Mode and Firefighting Mode plans.
5. The user selects a plan and tracks progress in My Tasks.

The Web Demo is an online demo adaptation for browser access. It is not intended to replace the Native iOS App.

## AI Capability

ChopChop uses Doubao_Seed_2.0_Mini for natural language understanding and plan refinement. The AI layer helps with:

- Understanding user task descriptions.
- Recognizing academic task types.
- Extracting DDL information.
- Judging task complexity.
- Refining step descriptions so they are clear and actionable.

## Task Decomposition Strategy

ChopChop uses a hybrid approach: template rules plus AI dynamic tuning.

Template rules provide the stable structure:

- Reliable task type categories.
- Standard stage structures.
- Baseline time estimates.
- Predictable planning behavior for common academic work.

AI dynamic tuning personalizes the plan:

- Adapts steps based on the user's wording.
- Uses attachment metadata or extracted text when available.
- Adjusts the plan according to remaining time.
- Accounts for stages the user has already completed.
- Improves wording and prioritization for the final step list.

This hybrid path keeps the demo stable for review while still allowing plans to respond to individual task context.
