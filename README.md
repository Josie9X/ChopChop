# ChopChop — Turn deadlines into action

ChopChop is an AI-driven task decomposition app that helps students turn messy deadlines into clear execution plans. Instead of acting like another reminder app, ChopChop focuses on the harder question: **what should I do next, and in what order?**

Users can describe an assignment, upload a PDF brief, clarify their progress, and receive structured plans that break the work into realistic steps. The app is designed for deadline-heavy coursework where the hardest part is often not remembering the due date, but figuring out how to start.

## Demo / Highlights

- **PDF-based task understanding**: upload assignment briefs or requirement sheets and let ChopChop extract useful context.
- **Structured execution plans**: generate step-by-step plans with estimated time ranges, risk notes, and progress states.
- **Dual planning modes**: choose between **Steady Mode** for safer pacing and **Emergency Mode** for compressed last-minute execution.
- **Conversation-first workflow**: refine a task through follow-up messages instead of restarting from scratch.

## How to Review the Demo

ChopChop provides two demo entry points for different review needs.

### Web Demo (Vercel)

The Web Demo is the online experience prepared for the preliminary competition Demo URL requirement. It is deployed on Vercel as a browser-accessible prototype and focuses on the core planning loop:

1. Enter a task description.
2. Click **Send** to run task recognition.
3. Confirm the task type, DDL, and completed stages.
4. Generate **Robust Mode** and **Firefighting Mode** plans.
5. Choose a plan and enter **My Tasks**.
6. Update step status until the task is completed.

### Native iOS App (Xcode)

The Native iOS App is the complete native prototype. Reviewers can run it with Xcode Simulator:

1. Clone the GitHub repository.
2. Open `ChopChop.xcodeproj`.
3. Select an iPhone simulator.
4. Click **Run**.

## Key Features

### Task Decomposition

ChopChop converts vague task descriptions into actionable work stages. It supports common coursework types such as essays, reports, presentations, coding assignments, design projects, and revision tasks.

### Context-Aware Conversation

The app keeps local task context, including task summaries, file summaries, recent conversation history, selected task type, deadline, and completion progress. Follow-up messages can update the plan without losing previous context.

### PDF Understanding

PDF support is a core feature. Users can upload assignment documents, and ChopChop uses extracted text to improve task understanding and planning quality.

### Adaptive Plan Regeneration

When users add new requirements, change the task scope, update progress, or say that a task is harder than expected, ChopChop can regenerate the plan based on the latest context.

### Local + Cloud Hybrid Architecture

ChopChop stores task state locally on iOS while using a lightweight cloud function for model calls. This keeps the user experience responsive while avoiding hardcoded model credentials inside the app.

## System Architecture

```text
iOS App -> API Gateway -> veFaaS -> Ark LLM
```

### iOS App

The iOS app handles the user interface, local persistence, file text extraction, conversation state, and task progress management. It stores task summaries, file summaries, selected plans, and step-level completion states locally.

### API Gateway

API Gateway provides the public HTTPS entry point for the app. It routes requests such as health checks, task parsing, and plan generation to the serverless backend.

### veFaaS

The Volcengine veFaaS function contains the backend planning logic. It validates incoming requests, builds compact prompts, manages timeout-safe model calls, and returns structured JSON responses to the iOS app.

### Ark LLM

Ark powers the task understanding and plan generation. The model returns structured planning data that the app renders into Steady and Emergency modes.

## How PDF Works

ChopChop does **not** send an entire PDF directly to the model.

The PDF pipeline is:

```text
PDF upload -> local text extraction -> file summary -> plan generation
```

This design keeps model input compact and reduces request latency. It also avoids sending long raw documents into the prompt, which helps prevent cloud function timeouts and improves generation stability.

During planning, the backend sends only the information needed for the current request:

```text
taskSummary + fileSummary + recentContext + current user input
```

This makes the system more efficient than repeatedly sending full files and full conversation history.

## Tech Stack

- **iOS**: Swift, SwiftUI, SwiftData
- **File Understanding**: PDFKit, Vision OCR, UniformTypeIdentifiers
- **Cloud Runtime**: Volcengine veFaaS Web Application Function
- **API Layer**: Volcengine API Gateway
- **LLM Provider**: Ark LLM
- **Model**: Doubao-Seed-2.0-mini

## Project Structure

```text
.
├── ChopChop.xcodeproj          # Xcode project
├── ChopChop/                   # iOS app source
│   ├── App/                    # App entry, tab state, runtime config
│   ├── Assets.xcassets/        # App icon and asset catalog
│   ├── Models/                 # SwiftData models, DTOs, enums, deadline parsing
│   ├── Services/               # Backend client, file extraction, planning services
│   ├── ViewModels/             # Conversation and plan generation state
│   └── Views/                  # SwiftUI screens and reusable components
├── ChopChopTests/              # Unit tests for planning and parsing helpers
├── vefaas/                     # Serverless backend source
├── vefaas.zip                  # Deployment package for veFaaS
├── backend/                    # Optional local Spring Boot reference backend
├── mobile-web/                 # Minimal web prototype / protocol demo
└── README.md
```

## Setup & Run

### Run the iOS App

1. Install Xcode.
2. Open `ChopChop.xcodeproj`.
3. Select the `ChopChop` scheme.
4. Choose an iOS simulator or connected iPhone.
5. Build and run.

The app is configured to use the cloud API Gateway by default, so a local backend is not required for normal use.

### Configure the Base URL

The production API Gateway base URL is configured in `AppConfig`:

```text
https://sd7maaiccehg5j7macmeg.apigateway-cn-beijing.volceapi.com
```

For development, the app resolves the backend URL in this order:

1. `UserDefaults` override: `BackendBaseURL`
2. Info.plist key: `BACKEND_BASE_URL`
3. `AppConfig.productionBackendBaseURLString`

Do not ship `localhost`, `127.0.0.1`, or LAN IP addresses in production builds.

## Configuration

### iOS Configuration

The iOS app should point to the API Gateway HTTPS endpoint in production:

```text
https://sd7maaiccehg5j7macmeg.apigateway-cn-beijing.volceapi.com
```

### veFaaS Environment Variables

Configure these environment variables in the Volcengine veFaaS console:

```text
ARK_API_KEY=your_ark_api_key
ARK_MODEL=doubao-seed-2-0-mini-260215
ARK_API_URL=https://ark.cn-beijing.volces.com/api/v3/chat/completions
ARK_TIMEOUT_SECONDS=90
```

The Ark API key must stay in the cloud environment. It should never be stored in the iOS app or committed to the repository.

Recommended function timeout:

```text
180 seconds or higher
```

### Backend Routes

```text
GET  /health
GET  /health/ark
POST /api/plan/parse
POST /api/plan/generate
```

### Deployment Package

To rebuild the veFaaS package:

```bash
cd vefaas
zip -r ../vefaas.zip index.js package.json README.md
```

Upload `vefaas.zip` to the Volcengine veFaaS Web Application Function and publish a new version.

## Troubleshooting

### `request timed out`

**Cause:** The app waited longer than the configured network timeout, usually because the backend or Ark model call took too long.

**Fix:** Make sure the iOS timeout is long enough, keep `ARK_TIMEOUT_SECONDS` below the function timeout, and avoid sending full PDF text to the model. ChopChop currently sends compact `fileSummary` and `taskSummary` context instead of raw PDF content.

### `function_invoke_timeout`

**Cause:** The veFaaS function exceeded the platform timeout before returning a response.

**Fix:** Increase the function timeout in the Volcengine console, keep Ark requests bounded, and deploy the latest `vefaas.zip`. The backend logs total route duration and Ark duration to help identify slow requests.

### Simulator cannot connect

**Cause:** The simulator may be using a stale local backend URL such as `localhost`, `127.0.0.1`, or a LAN IP address.

**Fix:** Clear any `BackendBaseURL` override and confirm that the app is using the API Gateway HTTPS endpoint. The simulator does not need a local backend for the production cloud flow.

### `/health/ark` returns 401

**Cause:** The Ark API key is missing, invalid, or not configured in veFaaS.

**Fix:** Update `ARK_API_KEY` in the Volcengine environment variables and redeploy or restart the function.

### Plan generation asks for clarification

**Cause:** The model or backend could not identify required planning information such as task type, deadline, or completion status.

**Fix:** Reply in the conversation with the missing information, then generate the plan again.

## Future Improvements

- Add asynchronous job processing for long-running PDF-heavy planning tasks.
- Improve PDF parsing for scanned documents and complex formatting.
- Cache file summaries and model responses for faster regeneration.
- Add richer plan version history and side-by-side comparison.
- Improve time-estimation calibration based on user feedback.
- Add export and sharing options for generated plans.
- Add a developer settings screen for controlled environment switching.
