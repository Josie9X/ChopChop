const STORAGE_BACKEND = "ddl_backend_url";
const STORAGE_TASKS = "chopchop_demo_tasks";
const STORAGE_CONVERSATIONS = "chopchop_demo_conversations";
const DEFAULT_BACKEND_URL = "https://sd7maaiccehg5j7macmeg.apigateway-cn-beijing.volceapi.com";
const DEFAULT_COURSE_NAME = "Coursework";
const SAMPLE_TASK_TEXT = "I need to finish an academic writing literature review about AI in education. It is due May 12 at 18:00 and I have only collected a few sources.";

const backendInput = document.querySelector("#backendUrl");
const backendToggle = document.querySelector("#backendToggle");
const backendFields = document.querySelector("#backendFields");
const historyBtn = document.querySelector("#historyBtn");
const newChatBtn = document.querySelector("#newChatBtn");
const taskHistoryBtn = document.querySelector("#taskHistoryBtn");
const taskNewChatBtn = document.querySelector("#taskNewChatBtn");
const conversationTitle = document.querySelector("#conversationTitle");
const historySheet = document.querySelector("#historySheet");
const historyBackdrop = document.querySelector("#historyBackdrop");
const closeHistoryBtn = document.querySelector("#closeHistoryBtn");
const historyList = document.querySelector("#historyList");
const taskText = document.querySelector("#taskText");
const fileInput = document.querySelector("#fileInput");
const fileButton = document.querySelector("#fileButton");
const fileChip = document.querySelector("#fileChip");
const generateMainBtn = document.querySelector("#generateMainBtn");
const floatingComposer = document.querySelector("#floatingComposer");
const floatingTaskText = document.querySelector("#floatingTaskText");
const floatingAttachBtn = document.querySelector("#floatingAttachBtn");
const floatingSendBtn = document.querySelector("#floatingSendBtn");
const statusStrip = document.querySelector("#statusStrip");
const statusDot = document.querySelector("#statusDot");
const statusTitle = document.querySelector("#statusTitle");
const statusText = document.querySelector("#statusText");
const liveModePill = document.querySelector("#liveModePill");
const inputCard = document.querySelector("#inputCard");
const loadingPanel = document.querySelector("#loadingPanel");
const loadingTitle = document.querySelector("#loadingTitle");
const loadingBar = document.querySelector("#loadingBar");
const analysisPanel = document.querySelector("#analysisPanel");
const planOverview = document.querySelector("#planOverview");
const planDetail = document.querySelector("#planDetail");
const taskList = document.querySelector("#taskList");
const taskDetail = document.querySelector("#taskDetail");
const taskSegments = document.querySelector("#taskSegments");
const ongoingTab = document.querySelector("#ongoingTab");
const completedTab = document.querySelector("#completedTab");
const tasksHeaderTitle = document.querySelector("#tasksHeaderTitle");
const tasksHeaderSubtitle = document.querySelector("#tasksHeaderSubtitle");
const taskEditSheet = document.querySelector("#taskEditSheet");
const taskEditBackdrop = document.querySelector("#taskEditBackdrop");
const cancelTaskEditBtn = document.querySelector("#cancelTaskEditBtn");
const saveTaskEditBtn = document.querySelector("#saveTaskEditBtn");
const taskEditEyebrow = document.querySelector("#taskEditEyebrow");
const taskEditTitle = document.querySelector("#taskEditTitle");
const taskEditLabel = document.querySelector("#taskEditLabel");
const taskEditField = document.querySelector("#taskEditField");

const loadingMessages = [
  "Analyzing task type...",
  "Matching academic task template...",
  "Estimating remaining workload...",
  "Generating robust and firefighting plans...",
];

const fallbackParseResponse = {
  taskType: "essay",
  confidence: 0.91,
  summary: "A literature review task with source collection started, but outline, synthesis, drafting, citation cleanup, and final review still need a clear execution plan.",
  clarifyingQuestions: [
    "Does the instructor require a specific citation style?",
    "How many academic sources are expected?",
  ],
  stages: [
    {
      id: "collect_sources",
      title: "Collect sources",
      detail: "Gather the minimum required academic sources and save citation details.",
    },
    {
      id: "synthesize_notes",
      title: "Synthesize notes",
      detail: "Group source ideas by theme and identify agreements, gaps, and contrasts.",
    },
    {
      id: "outline_argument",
      title: "Outline argument",
      detail: "Create a section outline with topic sentences and evidence placement.",
    },
    {
      id: "draft_review",
      title: "Draft review",
      detail: "Write the first complete version with citations inserted while drafting.",
    },
    {
      id: "revise_submit",
      title: "Revise and submit",
      detail: "Check flow, references, formatting, and upload before the deadline.",
    },
  ],
};

const fallbackGenerateResponse = {
  riskNote: "The deadline is close. Use Firefighting Mode if you have less than two focused work sessions left.",
  steps: [
    {
      id: "step-1",
      title: "Lock the topic and source list",
      description: "Choose the final angle, remove weak sources, and keep only sources that directly support the review question.",
      durationMin: 25,
      durationMax: 40,
      status: "todo",
      estimateReason: "Short because the task already has a few collected sources.",
      toolWarning: "Do not spend the whole session searching for more sources.",
      isCore: true,
    },
    {
      id: "step-2",
      title: "Build a theme matrix",
      description: "Create a quick table with source, method, key finding, limitation, and theme.",
      durationMin: 45,
      durationMax: 70,
      status: "todo",
      estimateReason: "Synthesis is the highest-value planning step for a literature review.",
      toolWarning: "Keep notes in your own words to avoid accidental patchwriting.",
      isCore: true,
    },
    {
      id: "step-3",
      title: "Write a section outline",
      description: "Plan introduction, three body themes, and conclusion with evidence assigned to each section.",
      durationMin: 25,
      durationMax: 45,
      status: "todo",
      estimateReason: "A detailed outline reduces rewrite time later.",
      toolWarning: "",
      isCore: true,
    },
    {
      id: "step-4",
      title: "Draft the body sections",
      description: "Write the theme sections first, using source comparisons rather than one paragraph per source.",
      durationMin: 90,
      durationMax: 140,
      status: "todo",
      estimateReason: "The body carries most of the word count and evidence work.",
      toolWarning: "Do not polish sentences during the first pass.",
      isCore: true,
    },
    {
      id: "step-5",
      title: "Write introduction and conclusion",
      description: "Add context, review scope, thesis direction, and a conclusion that reflects the main synthesis.",
      durationMin: 35,
      durationMax: 55,
      status: "todo",
      estimateReason: "These are easier once the body argument exists.",
      toolWarning: "",
      isCore: true,
    },
    {
      id: "step-6",
      title: "Citation and formatting sweep",
      description: "Check in-text citations, reference list, headings, file naming, and upload requirements.",
      durationMin: 30,
      durationMax: 50,
      status: "todo",
      estimateReason: "Submission errors are common under deadline pressure.",
      toolWarning: "Reserve this step even in Firefighting Mode.",
      isCore: false,
    },
    {
      id: "step-7",
      title: "Final readability pass",
      description: "Read once for flow, repeated claims, missing transitions, and obvious grammar issues.",
      durationMin: 25,
      durationMax: 40,
      status: "todo",
      estimateReason: "A final pass catches issues that automated tools miss.",
      toolWarning: "",
      isCore: false,
    },
  ],
};

let uploadedFile = null;
let parsedTask = null;
let generatedPlan = null;
let availablePlans = {};
let completedStageIds = new Set();
let currentConversationId = null;
let confirmedDeadline = "";
let taskFilter = "ongoing";
let selectedTaskId = null;
let taskView = "list";
let loadingTimer = null;
let taskEditTarget = null;

init();

function init() {
  backendInput.value = localStorage.getItem(STORAGE_BACKEND) || defaultBackendURL();
  renderTasks();
  bindEvents();
}

function bindEvents() {
  backendToggle.addEventListener("click", () => {
    backendFields.hidden = !backendFields.hidden;
  });

  backendInput.addEventListener("change", () => {
    localStorage.setItem(STORAGE_BACKEND, backendInput.value.trim());
  });

  fileButton.addEventListener("click", () => fileInput.click());
  floatingAttachBtn.addEventListener("click", () => fileInput.click());
  fileInput.addEventListener("change", handleFileSelect);
  generateMainBtn.addEventListener("click", sendTaskForAnalysis);
  floatingTaskText.addEventListener("input", updateFloatingSendState);
  floatingSendBtn.addEventListener("click", sendFloatingMessage);
  newChatBtn.addEventListener("click", startNewChat);
  taskNewChatBtn.addEventListener("click", startNewChat);
  historyBtn.addEventListener("click", openHistorySheet);
  taskHistoryBtn.addEventListener("click", openHistorySheet);
  closeHistoryBtn.addEventListener("click", closeHistorySheet);
  historyBackdrop.addEventListener("click", closeHistorySheet);
  taskEditBackdrop.addEventListener("click", closeTaskEditSheet);
  cancelTaskEditBtn.addEventListener("click", closeTaskEditSheet);
  saveTaskEditBtn.addEventListener("click", saveTaskEditSheet);

  document.addEventListener("click", (event) => {
    if (!event.target.closest(".task-menu-wrap")) {
      closeTaskMenus();
    }
  });

  document.querySelectorAll("[data-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      switchScreen(button.dataset.tab);
      if (button.dataset.tab === "tasks") {
        taskFilter = "ongoing";
        taskView = "list";
        selectedTaskId = null;
        renderTasks();
      }
    });
  });

  [ongoingTab, completedTab].forEach((button) => {
    button.addEventListener("click", () => {
      taskFilter = button.dataset.taskFilter;
      taskView = "list";
      selectedTaskId = null;
      renderTasks();
    });
  });
}

function defaultBackendURL() {
  return DEFAULT_BACKEND_URL;
}

function joinURL(base, path) {
  const cleanBase = String(base || "").trim().replace(/\/+$/, "");
  let cleanPath = String(path || "").trim();

  if (!cleanPath.startsWith("/")) {
    cleanPath = `/${cleanPath}`;
  }

  if (cleanBase.endsWith("/api") && cleanPath.startsWith("/api/")) {
    cleanPath = cleanPath.slice(4);
  }

  return `${cleanBase}${cleanPath}`;
}

async function handleFileSelect() {
  const file = fileInput.files?.[0];
  if (!file) {
    uploadedFile = null;
    renderFileChip();
    return;
  }

  uploadedFile = {
    fileName: file.name,
    mimeType: file.type || inferMimeType(file.name),
    fileSize: file.size,
    extractedFileText: "",
  };

  if (isTextLike(file)) {
    try {
      uploadedFile.extractedFileText = (await file.text()).slice(0, 1200);
    } catch (error) {
      uploadedFile.extractedFileText = "";
      setStatus("warn", "File attached", "Could not read text preview, so only file metadata will be sent.");
    }
  }

  renderFileChip();
}

function renderFileChip() {
  if (!uploadedFile) {
    fileChip.className = "file-chip empty";
    fileChip.textContent = "No file attached";
    floatingAttachBtn.classList.remove("has-file");
    return;
  }

  fileChip.className = "file-chip";
  fileChip.textContent = `${uploadedFile.fileName} · ${formatBytes(uploadedFile.fileSize)}`;
  floatingAttachBtn.classList.add("has-file");
}

function sendFloatingMessage() {
  const supplement = floatingTaskText.value.trim();
  if (!supplement) return;

  const previous = getTaskInputText();
  taskText.value = previous ? `${previous}\n\nAdditional context: ${supplement}` : supplement;
  floatingTaskText.value = "";
  updateFloatingSendState();
  sendTaskForAnalysis();
}

function updateFloatingSendState() {
  floatingSendBtn.disabled = floatingTaskText.value.trim().length === 0;
}

function showFloatingComposer() {
  floatingComposer.classList.remove("hidden");
  updateFloatingSendState();
}

function hideFloatingComposer() {
  floatingComposer.classList.add("hidden");
  floatingTaskText.value = "";
  updateFloatingSendState();
}

async function sendTaskForAnalysis() {
  const taskBody = getTaskInputText();
  if (!taskBody) {
    setStatus("warn", "Add your task first", "Type your own task description in the box above, then send it for analysis.");
    taskText.focus();
    return;
  }

  resetGeneratedViews();
  currentConversationId = currentConversationId || `chat-${Date.now()}`;
  confirmedDeadline = inferDeadlineInput();
  setButtonState(generateMainBtn, "loading", "Sending...");
  setStatus(
    "loading",
    uploadedFile ? "Analyzing file and task..." : "Analyzing task...",
    "Calling /api/plan/parse. You will confirm the result before generating plans."
  );

  try {
    await parseTask();
    saveCurrentConversation();
    renderAnalysisPanel();
  } finally {
    setButtonState(generateMainBtn, "done", "Send Again");
  }
}

async function confirmAndGeneratePlan() {
  syncConfirmedDeadlineFromInputs();

  setStatus("loading", "Generating plan options...", "Calling /api/plan/generate with your confirmed stages.");
  setButtonState(analysisPanel.querySelector("#confirmGenerateBtn"), "loading", "Generating...");
  startLoadingMessages();

  try {
    await generatePlan();
    saveCurrentConversation();
    renderPlanOverview();
  } finally {
    stopLoadingMessages();
  }
}

async function parseTask() {
  const request = buildParseRequest();

  try {
    const response = await postJSON("/api/plan/parse", request);
    parsedTask = normalizeParseResponse(response, false);
    confirmedDeadline = deadlinePartsToInput(parsedTask.deadline || confirmedDeadline || inferDeadlineInput());
    setStatus("ok", "Task recognized", "Confirm the details and choose completed stages.");
  } catch (error) {
    parsedTask = normalizeParseResponse(fallbackParseResponse, true);
    confirmedDeadline = deadlinePartsToInput(parsedTask.deadline || confirmedDeadline || inferDeadlineInput());
    setStatus("warn", "Live API unavailable. Showing built-in demo data.", readableError(error));
  }

  completedStageIds.clear();
}

async function generatePlan() {
  const request = buildGenerateRequest();

  try {
    const response = await postJSON("/api/plan/generate", request);
    if (!Array.isArray(response.steps) || response.steps.length === 0) {
      throw new Error("Backend returned no steps.");
    }
    generatedPlan = normalizeGenerateResponse(response, false);
    setStatus("ok", "Plan options ready", "Choose a mode from the overview cards below.");
  } catch (error) {
    generatedPlan = normalizeGenerateResponse(fallbackGenerateResponse, true);
    setStatus("warn", "Live API unavailable. Showing built-in demo data.", readableError(error));
  }

  availablePlans = {
    robust: buildRobustPlan(generatedPlan.steps),
    fire: buildFirefightingPlan(generatedPlan.steps, generatedPlan.riskNote),
  };
}

function buildParseRequest() {
  const attachment = uploadedFile ? getAttachmentMetadata() : null;

  return {
    title: buildTaskTitle(),
    text: getTaskInputText(),
    courseName: inferCourseName(),
    deadline: toISODeadline(),
    documentName: uploadedFile?.fileName || null,
    attachment,
    extractedFileText: uploadedFile?.extractedFileText || "",
  };
}

function buildGenerateRequest() {
  const attachment = uploadedFile ? getAttachmentMetadata() : null;

  return {
    title: buildTaskTitle(),
    text: getTaskInputText(),
    courseName: inferCourseName(),
    taskType: parsedTask?.taskType || "unknown",
    deadline: toISODeadline(),
    completedStageIds: Array.from(completedStageIds),
    attachment,
    extractedFileText: uploadedFile?.extractedFileText || "",
    taskSummary: parsedTask?.summary || "",
    fileSummary: uploadedFile ? summarizeFile(uploadedFile) : "",
  };
}

async function postJSON(path, body) {
  const response = await fetch(joinURL(getBackendURL(), path), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await response.text();

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 240)}`);
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error("Backend returned non-JSON response.");
  }
}

function normalizeParseResponse(response, isFallback) {
  const stages = response.stages || response.standardStages || response.taskStages || [];
  const stageSource = stages.length ? stages : fallbackParseResponse.stages;

  return {
    ...response,
    isFallback,
    taskType: response.taskType || response.type || "unknown",
    confidence: Number(response.confidence ?? response.score ?? 0.82),
    summary: response.summary || response.taskSummary || "Task recognized. Choose a planning mode below.",
    deadline: response.deadline || response.ddl || response.dueDate || "",
    stages: stageSource.map((stage, index) => ({
      id: stage.id || `stage-${index + 1}`,
      title: stage.title || stage.name || `Stage ${index + 1}`,
      detail: stage.detail || stage.description || stage.summary || "Complete this stage before moving forward.",
    })),
  };
}

function normalizeGenerateResponse(response, isFallback) {
  return {
    ...response,
    isFallback,
    riskNote: response.riskNote || response.risk || "",
    steps: response.steps.map((step, index) => ({
      id: step.id || `step-${index + 1}`,
      title: step.title || `Step ${index + 1}`,
      description: step.description || step.detail || "",
      durationMin: Number(step.durationMin ?? step.minMinutes ?? 20),
      durationMax: Number(step.durationMax ?? step.maxMinutes ?? step.durationMin ?? 40),
      status: ["todo", "doing", "done"].includes(step.status) ? step.status : "todo",
      estimateReason: step.estimateReason || step.reason || "Estimated from task type and remaining workload.",
      toolWarning: step.toolWarning || "",
      isCore: typeof step.isCore === "boolean" ? step.isCore : undefined,
    })),
  };
}

function resetGeneratedViews() {
  analysisPanel.classList.add("hidden");
  planOverview.classList.add("hidden");
  planDetail.classList.add("hidden");
  analysisPanel.innerHTML = "";
  planOverview.innerHTML = "";
  planDetail.innerHTML = "";
  inputCard.classList.remove("hidden");
}

function renderAnalysisPanel() {
  const fallbackBadge = parsedTask.isFallback ? `<span class="badge fallback">Demo Fallback</span>` : "";
  const deadlineParts = parseDeadlineToDateTime(confirmedDeadline || parsedTask.deadline || inferDeadlineInput());
  liveModePill.textContent = parsedTask.isFallback ? "Demo Fallback" : "Live API";
  liveModePill.className = parsedTask.isFallback ? "live-pill fallback" : "live-pill";

  analysisPanel.innerHTML = `
    <section class="panel result-summary">
      <div class="section-title">
        <div>
          <p class="eyebrow">Task Analysis</p>
          <h2>Confirm details</h2>
          <p>${escapeHTML(parsedTask.summary)}</p>
        </div>
        ${fallbackBadge}
      </div>
      <div class="insight-grid compact">
        <article><span>Task Type</span><strong>${titleCase(parsedTask.taskType)}</strong></article>
        <article><span>Confidence</span><strong>${Math.round(parsedTask.confidence * 100)}%</strong></article>
      </div>
      <div class="deadline-row">
        <div>
          <label for="confirmedDate">Date</label>
          <input id="confirmedDate" type="date" value="${escapeAttribute(deadlineParts.date)}" />
        </div>
        <div>
          <label for="confirmedTime">Time</label>
          <input id="confirmedTime" type="time" value="${escapeAttribute(deadlineParts.time)}" />
        </div>
      </div>
      <p class="deadline-preview">DDL: ${escapeHTML(formatDeadlineDisplay(combineDateAndTime(deadlineParts.date, deadlineParts.time)))}</p>
    </section>
    <section class="panel">
      <div class="section-title compact">
        <h3>Standard Stages</h3>
        <button class="text-toggle" id="notStartedBtn" type="button">Not Started Yet</button>
      </div>
      <p class="hint">Tap stages you have already completed.</p>
      <div class="stage-grid" id="stageGrid">
        ${parsedTask.stages.map(renderStageCard).join("")}
      </div>
      <button class="primary-btn" id="confirmGenerateBtn" type="button">Confirm & Generate Plan</button>
    </section>
  `;

  analysisPanel.classList.remove("hidden");
  planOverview.classList.add("hidden");
  planDetail.classList.add("hidden");
  inputCard.classList.add("hidden");
  showFloatingComposer();

  analysisPanel.querySelector("#notStartedBtn").addEventListener("click", () => {
    completedStageIds.clear();
    renderAnalysisPanel();
  });
  ["#confirmedDate", "#confirmedTime"].forEach((selector) => {
    analysisPanel.querySelector(selector).addEventListener("change", () => {
      syncConfirmedDeadlineFromInputs();
      renderAnalysisPanel();
    });
  });
  analysisPanel.querySelector("#confirmedDate").addEventListener("input", () => {
    syncConfirmedDeadlineFromInputs();
  });
  analysisPanel.querySelector("#confirmedTime").addEventListener("input", () => {
    syncConfirmedDeadlineFromInputs();
  });
  analysisPanel.querySelectorAll("[data-stage-id]").forEach((button) => {
    button.addEventListener("click", () => toggleCompletedStage(button.dataset.stageId));
  });
  analysisPanel.querySelector("#confirmGenerateBtn").addEventListener("click", confirmAndGeneratePlan);
}

function renderStageCard(stage) {
  const selected = completedStageIds.has(stage.id);
  return `
    <button class="${selected ? "stage-card selected" : "stage-card"}" type="button" data-stage-id="${escapeAttribute(stage.id)}">
      <span class="stage-state">${selected ? "completed" : "not completed"}</span>
      <strong>${escapeHTML(stage.title)}</strong>
      <p>${escapeHTML(stage.detail)}</p>
    </button>
  `;
}

function toggleCompletedStage(stageId) {
  if (completedStageIds.has(stageId)) {
    completedStageIds.delete(stageId);
  } else {
    completedStageIds.add(stageId);
  }
  saveCurrentConversation();
  renderAnalysisPanel();
}

function renderPlanOverview() {
  const fallbackBadge = generatedPlan.isFallback ? `<span class="badge fallback">Demo Fallback</span>` : "";
  liveModePill.textContent = generatedPlan.isFallback ? "Demo Fallback" : "Live API";
  liveModePill.className = generatedPlan.isFallback ? "live-pill fallback" : "live-pill";

  planOverview.innerHTML = `
    <section class="panel result-summary">
      <div class="section-title">
        <div>
          <p class="eyebrow">Plan Overview</p>
          <h2>${titleCase(parsedTask.taskType)} task recognized</h2>
          <p>${escapeHTML(parsedTask.summary)}</p>
        </div>
        ${fallbackBadge}
      </div>
      <div class="insight-grid compact">
        <article><span>Task Type</span><strong>${titleCase(parsedTask.taskType)}</strong></article>
        <article><span>Confidence</span><strong>${Math.round(parsedTask.confidence * 100)}%</strong></article>
      </div>
    </section>
    <article class="plan-card robust">${renderPlanSummaryCard(availablePlans.robust)}</article>
    <article class="plan-card firefighting">${renderPlanSummaryCard(availablePlans.fire)}</article>
  `;

  planOverview.classList.remove("hidden");
  planDetail.classList.add("hidden");
  inputCard.classList.add("hidden");
  analysisPanel.classList.add("hidden");
  showFloatingComposer();
  saveCurrentConversation();

  planOverview.querySelectorAll("[data-view-plan]").forEach((button) => {
    button.addEventListener("click", () => renderPlanDetail(button.dataset.viewPlan));
  });

  planOverview.querySelectorAll("[data-start-plan]").forEach((button) => {
    button.addEventListener("click", () => startPlan(availablePlans[button.dataset.startPlan]));
  });
}

function startNewChat() {
  switchScreen("generate");
  currentConversationId = null;
  parsedTask = null;
  generatedPlan = null;
  availablePlans = {};
  completedStageIds.clear();
  confirmedDeadline = "";
  uploadedFile = null;
  fileInput.value = "";
  taskText.value = "";
  renderFileChip();
  resetGeneratedViews();
  hideFloatingComposer();
  setButtonState(generateMainBtn, "idle", "Send");
  conversationTitle.textContent = "ChopChop";
  liveModePill.textContent = "Live API";
  liveModePill.className = "live-pill";
  setStatus("idle", "New chat", "Describe a task to start a fresh planning conversation.");
}

function openHistorySheet() {
  renderHistoryList();
  historySheet.classList.remove("hidden");
}

function closeHistorySheet() {
  historySheet.classList.add("hidden");
}

function renderHistoryList() {
  const conversations = readConversations();
  historyList.innerHTML = "";

  if (conversations.length === 0) {
    historyList.innerHTML = `<article class="empty-state">No chat history yet.</article>`;
    return;
  }

  conversations.forEach((conversation) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "history-item";
    button.innerHTML = `
      <strong>${escapeHTML(conversation.title)}</strong>
      <span>${formatDeadline(conversation.createdAt)}</span>
      <p>${escapeHTML(conversation.taskDescription.slice(0, 120))}</p>
    `;
    button.addEventListener("click", () => restoreConversation(conversation.id));
    historyList.appendChild(button);
  });
}

function restoreConversation(conversationId) {
  const conversation = readConversations().find((item) => item.id === conversationId);
  if (!conversation) return;

  switchScreen("generate");
  currentConversationId = conversation.id;
  taskText.value = conversation.taskDescription || "";
  parsedTask = conversation.parseResult || null;
  generatedPlan = conversation.planResult || null;
  completedStageIds = new Set(conversation.completedStageIds || []);
  confirmedDeadline = deadlinePartsToInput(conversation.confirmedDeadline || inferDeadlineInput());
  availablePlans = generatedPlan ? {
    robust: buildRobustPlan(generatedPlan.steps),
    fire: buildFirefightingPlan(generatedPlan.steps, generatedPlan.riskNote),
  } : {};
  conversationTitle.textContent = conversation.title || "ChopChop";
  resetGeneratedViews();

  if (generatedPlan) {
    renderPlanOverview();
  } else if (parsedTask) {
    renderAnalysisPanel();
  }

  setButtonState(generateMainBtn, "done", "Send Again");
  setStatus("ok", "Chat restored", "You can continue from the saved analysis or generated plan.");
  closeHistorySheet();
}

function saveCurrentConversation() {
  const taskDescription = getTaskInputText();
  if (!taskDescription) return;

  currentConversationId = currentConversationId || `chat-${Date.now()}`;
  const conversations = readConversations().filter((item) => item.id !== currentConversationId);
  const title = buildConversationTitle(taskDescription);
  conversations.unshift({
    id: currentConversationId,
    title,
    taskDescription,
    createdAt: new Date().toISOString(),
    parseResult: parsedTask,
    planResult: generatedPlan,
    completedStageIds: Array.from(completedStageIds),
    confirmedDeadline: deadlinePartsToInput(confirmedDeadline || inferDeadlineInput()),
  });
  localStorage.setItem(STORAGE_CONVERSATIONS, JSON.stringify(conversations.slice(0, 20)));
  conversationTitle.textContent = title;
}

function renderPlanSummaryCard(plan) {
  const previewSteps = plan.steps.slice(0, 3);

  return `
    <div class="plan-head">
      <div>
        <p class="eyebrow">${plan.tone === "fire" ? "Deadline-first" : "Complete route"}</p>
        <h2>${plan.mode}</h2>
        <p>${escapeHTML(plan.summary)}</p>
      </div>
    </div>
    <div class="summary-metrics">
      <span>${plan.duration.min}-${plan.duration.max} min</span>
      <span>${plan.steps.length} steps</span>
    </div>
    <ol class="preview-list">
      ${previewSteps.map((step) => `<li>${escapeHTML(step.title)}</li>`).join("")}
    </ol>
    <div class="card-actions">
      <button class="secondary-btn" type="button" data-view-plan="${plan.tone}">View Details</button>
      <button class="primary-btn" type="button" data-start-plan="${plan.tone}">Start Plan</button>
    </div>
  `;
}

function renderPlanDetail(planKey) {
  const plan = availablePlans[planKey];
  if (!plan) return;

  const riskHTML = plan.riskNote ? `<div class="risk-note">${escapeHTML(plan.riskNote)}</div>` : "";

  planDetail.innerHTML = `
    <button class="back-btn" type="button" id="backToOverview">Back</button>
    <article class="panel detail-hero ${plan.tone === "fire" ? "fire" : "robust"}">
      <p class="eyebrow">${plan.tone === "fire" ? "High-risk option" : "Recommended baseline"}</p>
      <h2>${plan.mode}</h2>
      <p>${escapeHTML(plan.summary)}</p>
      <div class="summary-metrics">
        <span>${plan.duration.min}-${plan.duration.max} min</span>
        <span>${plan.steps.length} steps</span>
      </div>
      ${riskHTML}
      <button class="primary-btn" type="button" data-start-plan="${plan.tone}">Start This Plan</button>
    </article>
    <div class="detail-step-list">
      ${plan.steps.map(renderStepForPlan).join("")}
    </div>
  `;

  planOverview.classList.add("hidden");
  planDetail.classList.remove("hidden");
  planDetail.querySelector("#backToOverview").addEventListener("click", renderPlanOverview);
  planDetail.querySelector("[data-start-plan]").addEventListener("click", () => startPlan(plan));
}

function buildRobustPlan(steps) {
  return {
    mode: "Robust Mode",
    tone: "robust",
    summary: "Full workflow with planning, drafting, checking, and submission safety.",
    duration: sumDurations(steps),
    steps: steps.map((step) => ({ ...step, planTreatment: "full" })),
  };
}

function buildFirefightingPlan(steps, riskNote) {
  const hasCoreFlags = steps.some((step) => typeof step.isCore === "boolean");
  const coreLimit = Math.max(1, Math.ceil(steps.length * 0.65));
  const selectedSteps = steps.map((step, index) => {
    const isCore = hasCoreFlags ? step.isCore === true : index < coreLimit;
    return {
      ...step,
      isCore,
      planTreatment: isCore ? "core" : "compressed",
      title: isCore ? step.title : `Compress: ${step.title}`,
      description: isCore ? step.description : "Compressed / skipped / merge into final check.",
      durationMin: isCore ? step.durationMin : Math.max(5, Math.round(step.durationMin * 0.25)),
      durationMax: isCore ? step.durationMax : Math.max(10, Math.round(step.durationMax * 0.35)),
    };
  });

  return {
    mode: "Firefighting Mode",
    tone: "fire",
    summary: "Deadline-first route that protects the highest-impact work and compresses lower-value polishing.",
    riskNote,
    duration: sumDurations(selectedSteps),
    steps: selectedSteps,
  };
}

function renderStepForPlan(step) {
  const coreBadge = step.isCore === true ? `<span class="mini-badge core">Core</span>` : "";
  const treatmentBadge = step.planTreatment === "compressed" ? `<span class="mini-badge skipped">Compressed</span>` : "";
  const warning = step.toolWarning ? `<p class="tool-warning">${escapeHTML(step.toolWarning)}</p>` : "";

  return `
    <article class="step-card ${step.planTreatment === "compressed" ? "compressed" : ""}">
      <div class="step-top">
        <strong>${escapeHTML(step.title)}</strong>
        <span>${step.durationMin}-${step.durationMax} min</span>
      </div>
      <p>${escapeHTML(step.description)}</p>
      <div class="step-meta">
        <span class="mini-badge">${escapeHTML(step.status)}</span>
        ${coreBadge}
        ${treatmentBadge}
      </div>
      <p class="estimate">${escapeHTML(step.estimateReason)}</p>
      ${warning}
    </article>
  `;
}

function startPlan(plan) {
  const steps = plan.steps.map((step, index) => ({
    ...step,
    status: index === 0 ? "doing" : "todo",
  }));

  const task = {
    id: `task-${Date.now()}`,
    title: buildTaskTitle(),
    description: getTaskInputText(),
    taskType: parsedTask?.taskType || "unknown",
    adjustments: [],
    mode: plan.mode,
    deadline: toISODeadline(),
    status: "in_progress",
    createdAt: new Date().toISOString(),
    riskNote: plan.riskNote || "",
    steps,
  };

  const tasks = readTasks();
  tasks.unshift(task);
  writeTasks(tasks);
  taskFilter = "ongoing";
  taskView = "list";
  selectedTaskId = null;
  switchScreen("tasks");
  renderTasks();
}

function renderTasks() {
  const tasks = readTasks().map(updateTaskStatus);
  writeTasks(tasks);

  ongoingTab.classList.toggle("active", taskFilter === "ongoing");
  completedTab.classList.toggle("active", taskFilter === "completed");

  if (taskView === "detail" && selectedTaskId) {
    const task = tasks.find((item) => item.id === selectedTaskId);
    if (task) {
      renderTaskDetail(task);
      return;
    }
  }

  renderTaskList(tasks);
}

function renderTaskList(tasks) {
  const visibleTasks = tasks.filter((task) => (
    taskFilter === "completed" ? task.status === "completed" : task.status !== "completed"
  ));

  taskView = "list";
  selectedTaskId = null;
  taskSegments.classList.remove("hidden");
  taskList.classList.remove("hidden");
  taskDetail.classList.add("hidden");
  taskDetail.innerHTML = "";
  tasksHeaderTitle.textContent = taskFilter === "completed" ? "Completed" : "Ongoing";
  tasksHeaderSubtitle.textContent = taskFilter === "completed"
    ? "Finished plans stay here for review."
    : "Tap a task card to continue execution.";
  taskList.innerHTML = "";

  if (visibleTasks.length === 0) {
    taskList.innerHTML = `<article class="empty-state">No ${taskFilter === "completed" ? "completed" : "ongoing"} tasks yet.</article>`;
    return;
  }

  visibleTasks.forEach((task) => {
    const progress = getTaskProgress(task);
    const card = document.createElement("button");
    card.type = "button";
    card.className = "task-card";
    card.innerHTML = `
      <div class="task-card-top">
        <div>
          <strong>${escapeHTML(task.title)}</strong>
          <span>${escapeHTML(task.mode)} · ${escapeHTML(formatDeadlineDisplay(task.deadline))}</span>
        </div>
        <span class="badge ${task.status}">${escapeHTML(task.status)}</span>
      </div>
      <div class="progress-track"><span style="width: ${progress.percent}%"></span></div>
      <div class="task-foot">
        <span>${progress.done}/${progress.total} done</span>
        <span>${progress.remaining} remaining</span>
      </div>
    `;
    card.addEventListener("click", () => {
      selectedTaskId = task.id;
      taskView = "detail";
      renderTasks();
    });
    taskList.appendChild(card);
  });
}

function renderTaskDetail(task) {
  const progress = getTaskProgress(task);
  const isCompleted = task.status === "completed";

  taskSegments.classList.add("hidden");
  taskList.classList.add("hidden");
  taskDetail.classList.remove("hidden");
  tasksHeaderTitle.textContent = isCompleted ? "Completed Detail" : "Task Detail";
  tasksHeaderSubtitle.textContent = isCompleted
    ? "Review the finished plan, rename it, or delete it."
    : "Update progress, rename, modify the plan, or delete this task.";

  taskDetail.innerHTML = `
    <div class="detail-nav">
      <button class="back-btn" type="button" id="backToTaskList">Back</button>
      <div class="task-menu-wrap">
        <button class="overflow-btn" type="button" id="taskMenuBtn" aria-label="Task actions">...</button>
        <div class="task-menu hidden" id="taskMenu">
          <button type="button" data-task-action="rename">Rename</button>
          ${isCompleted ? "" : `<button type="button" data-task-action="plan">Modify Plan</button>`}
          <button class="danger-action" type="button" data-task-action="delete">Delete</button>
        </div>
      </div>
    </div>
    <article class="overview-card">
      <div class="task-card-top">
        <div>
          <p class="eyebrow">${isCompleted ? "Completed Task" : "Ongoing Task"}</p>
          <h2>${escapeHTML(task.title)}</h2>
          <p>${escapeHTML(task.mode)} · ${escapeHTML(formatDeadlineDisplay(task.deadline))}</p>
        </div>
        <span class="badge ${task.status}">${escapeHTML(task.status)}</span>
      </div>
      <div class="progress-track large"><span style="width: ${progress.percent}%"></span></div>
      <div class="task-foot">
        <span>${progress.done}/${progress.total} done</span>
        <span>${progress.remaining} remaining</span>
      </div>
    </article>

    <div class="detail-step-list">
      ${task.steps.map((step) => renderTaskStepHTML(task.id, step, isCompleted)).join("")}
    </div>
  `;

  taskDetail.querySelector("#backToTaskList").addEventListener("click", () => {
    taskView = "list";
    selectedTaskId = null;
    renderTasks();
  });
  taskDetail.querySelector("#taskMenuBtn").addEventListener("click", (event) => {
    event.stopPropagation();
    taskDetail.querySelector("#taskMenu").classList.toggle("hidden");
  });
  taskDetail.querySelectorAll("[data-task-action]").forEach((button) => {
    button.addEventListener("click", () => handleTaskMenuAction(task.id, button.dataset.taskAction));
  });

  if (!isCompleted) {
    taskDetail.querySelectorAll("[data-mark-done]").forEach((button) => {
      button.addEventListener("click", () => markStepDone(button.dataset.taskId, button.dataset.stepId));
    });
    taskDetail.querySelectorAll("[data-undo-step]").forEach((button) => {
      button.addEventListener("click", () => undoStep(button.dataset.taskId, button.dataset.stepId));
    });
  }
}

function renderTaskStepHTML(taskId, step, isCompleted) {
  const warning = step.toolWarning ? `<p class="tool-warning">${escapeHTML(step.toolWarning)}</p>` : "";
  const coreBadge = step.isCore ? `<span class="mini-badge core">Core</span>` : "";
  const controls = isCompleted ? "" : `
    <div class="card-actions step-actions">
      <button class="secondary-btn" type="button" data-mark-done="true" data-task-id="${taskId}" data-step-id="${step.id}" ${step.status === "done" ? "disabled" : ""}>Mark as Done</button>
      <button class="secondary-btn" type="button" data-undo-step="true" data-task-id="${taskId}" data-step-id="${step.id}" ${step.status !== "done" ? "disabled" : ""}>Undo</button>
    </div>
  `;

  return `
    <article class="step-card task-step ${step.status}">
      <div class="step-top">
        <strong>${escapeHTML(step.title)}</strong>
        <span class="mini-badge">${escapeHTML(step.status)}</span>
      </div>
      <p>${escapeHTML(step.description)}</p>
      <div class="step-meta">
        <span>${step.durationMin}-${step.durationMax} min</span>
        ${coreBadge}
      </div>
      <p class="estimate">${escapeHTML(step.estimateReason)}</p>
      ${warning}
      ${controls}
    </article>
  `;
}

function closeTaskMenus() {
  taskDetail.querySelectorAll?.(".task-menu").forEach((menu) => menu.classList.add("hidden"));
}

function handleTaskMenuAction(taskId, action) {
  closeTaskMenus();
  if (action === "rename") openTaskEditSheet(taskId, "rename");
  if (action === "plan") openTaskEditSheet(taskId, "plan");
  if (action === "delete") deleteTask(taskId);
}

function openTaskEditSheet(taskId, mode) {
  const tasks = readTasks();
  const task = tasks.find((item) => item.id === taskId);
  if (!task) return;

  taskEditTarget = { taskId, mode };
  taskEditEyebrow.textContent = mode === "rename" ? "Rename" : "Modify Plan";
  taskEditTitle.textContent = mode === "rename" ? "Rename task" : "Add details to adjust this plan";
  taskEditLabel.textContent = mode === "rename" ? "Task title" : "Add more details to adjust this plan.";
  taskEditField.rows = mode === "rename" ? 2 : 6;
  taskEditField.placeholder = mode === "rename"
    ? "Enter a new task title"
    : "For example: I have already finished the outline, but I still need references and final checking.";
  taskEditField.value = mode === "rename" ? task.title : "";
  saveTaskEditBtn.textContent = mode === "rename" ? "Save" : "Update Plan";
  taskEditSheet.classList.remove("hidden");
  window.setTimeout(() => taskEditField.focus(), 30);
}

function closeTaskEditSheet() {
  taskEditSheet.classList.add("hidden");
  taskEditTarget = null;
  saveTaskEditBtn.disabled = false;
  saveTaskEditBtn.textContent = "Save";
}

async function saveTaskEditSheet() {
  if (!taskEditTarget) return;

  const tasks = readTasks();
  const task = tasks.find((item) => item.id === taskEditTarget.taskId);
  if (!task) return;

  const nextValue = taskEditField.value.trim();
  if (taskEditTarget.mode === "rename") {
    if (!nextValue) return;
    task.title = nextValue;
    writeTasks(tasks);
    closeTaskEditSheet();
    renderTasks();
  } else {
    if (!nextValue) return;
    saveTaskEditBtn.disabled = true;
    saveTaskEditBtn.textContent = "Updating...";
    await updateTaskPlan(task, nextValue, tasks);
  }
}

async function updateTaskPlan(task, details, tasks) {
  const request = buildTaskUpdateRequest(task, details);
  let normalizedPlan;
  let usedFallback = false;

  try {
    const response = await postJSON("/api/plan/generate", request);
    if (!Array.isArray(response.steps) || response.steps.length === 0) {
      throw new Error("Backend returned no steps.");
    }
    normalizedPlan = normalizeGenerateResponse(response, false);
    setStatus("ok", "Plan updated", "Your current task was adjusted with the new details.");
  } catch (error) {
    normalizedPlan = normalizeGenerateResponse(fallbackGenerateResponse, true);
    usedFallback = true;
    setStatus("warn", "Live API unavailable. Plan updated with demo fallback.", readableError(error));
  }

  const adjustedPlan = task.mode === "Firefighting Mode"
    ? buildFirefightingPlan(normalizedPlan.steps, normalizedPlan.riskNote)
    : buildRobustPlan(normalizedPlan.steps);
  task.steps = reconcileAdjustedSteps(task.steps, adjustedPlan.steps);
  task.riskNote = adjustedPlan.riskNote || normalizedPlan.riskNote || task.riskNote || "";
  task.status = "in_progress";
  task.adjustments = [
    {
      details,
      createdAt: new Date().toISOString(),
      fallback: usedFallback,
    },
    ...(task.adjustments || []),
  ].slice(0, 5);

  writeTasks(tasks);
  closeTaskEditSheet();
  taskView = "detail";
  selectedTaskId = task.id;
  renderTasks();
}

function buildTaskUpdateRequest(task, details) {
  const completedSteps = task.steps.filter((step) => step.status === "done");

  return {
    title: task.title,
    text: `${task.description || task.title}\n\nNew details: ${details}`,
    courseName: inferCourseNameFromText(task.description || task.title),
    taskType: task.taskType || "unknown",
    deadline: task.deadline || "",
    completedStageIds: completedSteps.map((step) => step.id),
    completedStepTitles: completedSteps.map((step) => step.title),
    currentMode: task.mode,
    currentStepsSummary: task.steps.map((step) => ({
      title: step.title,
      status: step.status,
      durationMin: step.durationMin,
      durationMax: step.durationMax,
      isCore: step.isCore,
    })),
    adjustmentDetails: details,
    attachment: null,
    extractedFileText: "",
    taskSummary: task.description || "",
    fileSummary: "",
  };
}

function reconcileAdjustedSteps(previousSteps, nextSteps) {
  const completedById = new Set(previousSteps.filter((step) => step.status === "done").map((step) => step.id));
  const completedByTitle = new Set(previousSteps.filter((step) => step.status === "done").map((step) => normalizeStepTitle(step.title)));
  const completedCount = previousSteps.filter((step) => step.status === "done").length;
  let completedAssigned = 0;
  let doingAssigned = false;

  return nextSteps.map((step) => {
    const matchedDone = completedById.has(step.id) || completedByTitle.has(normalizeStepTitle(step.title));
    const fallbackDone = !matchedDone && completedAssigned < completedCount;
    let status = "todo";

    if (matchedDone || fallbackDone) {
      status = "done";
      completedAssigned += 1;
    } else if (!doingAssigned) {
      status = "doing";
      doingAssigned = true;
    }

    return { ...step, status };
  });
}

function normalizeStepTitle(title) {
  return String(title || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function deleteTask(taskId) {
  const confirmed = window.confirm("Delete this task?");
  if (!confirmed) return;

  const tasks = readTasks().filter((task) => task.id !== taskId);
  writeTasks(tasks);
  taskView = "list";
  selectedTaskId = null;
  renderTasks();
}

function markStepDone(taskId, stepId) {
  const tasks = readTasks();
  const task = tasks.find((item) => item.id === taskId);
  if (!task) return;

  const step = task.steps.find((item) => item.id === stepId);
  if (!step) return;

  step.status = "done";
  const nextTodo = task.steps.find((item) => item.status === "todo");
  if (nextTodo) {
    nextTodo.status = "doing";
  }

  updateTaskStatus(task);
  writeTasks(tasks);

  if (task.status === "completed") {
    taskFilter = "completed";
    taskView = "list";
    selectedTaskId = null;
  }

  renderTasks();
}

function undoStep(taskId, stepId) {
  const tasks = readTasks();
  const task = tasks.find((item) => item.id === taskId);
  const step = task?.steps.find((item) => item.id === stepId);
  if (!task || !step) return;

  step.status = "todo";
  if (!task.steps.some((item) => item.status === "doing")) {
    const firstTodo = task.steps.find((item) => item.status === "todo");
    if (firstTodo) firstTodo.status = "doing";
  }

  updateTaskStatus(task);
  writeTasks(tasks);
  renderTasks();
}

function updateTaskStatus(task) {
  if (task.steps.every((step) => step.status === "done")) {
    task.status = "completed";
    return task;
  }

  if (task.deadline && new Date(task.deadline).getTime() < Date.now()) {
    task.status = "overdue";
    return task;
  }

  task.status = "in_progress";
  return task;
}

function switchScreen(screenName) {
  document.querySelectorAll(".screen").forEach((screen) => {
    screen.classList.toggle("active", screen.dataset.screen === screenName);
  });
  document.querySelectorAll("[data-tab]").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === screenName);
  });
}

function startLoadingMessages() {
  let index = 0;
  loadingPanel.classList.remove("hidden");
  loadingBar.style.width = "18%";
  loadingTitle.textContent = loadingMessages[index];

  loadingTimer = window.setInterval(() => {
    index = Math.min(index + 1, loadingMessages.length - 1);
    loadingTitle.textContent = loadingMessages[index];
    loadingBar.style.width = `${25 + index * 23}%`;
  }, 650);
}

function stopLoadingMessages() {
  window.clearInterval(loadingTimer);
  loadingTimer = null;
  loadingBar.style.width = "100%";
  window.setTimeout(() => loadingPanel.classList.add("hidden"), 260);
}

function setButtonState(button, state, label) {
  button.dataset.state = state;
  button.textContent = label;
  button.disabled = state === "loading";
}

function setStatus(kind, title, text) {
  statusStrip.dataset.kind = kind;
  statusDot.className = `status-dot ${kind}`;
  statusTitle.textContent = title;
  statusText.textContent = text;
}

function getBackendURL() {
  return backendInput.value.trim() || defaultBackendURL();
}

function getTaskInputText() {
  return taskText.value.trim();
}

function inferCourseName() {
  return inferCourseNameFromText(getTaskInputText());
}

function inferCourseNameFromText(text) {
  if (/academic writing/i.test(text)) return "Academic Writing";
  if (/web programming|coding|programming/i.test(text)) return "Web Programming";
  if (/design|figma|prototype|ux/i.test(text)) return "Interaction Design";
  return DEFAULT_COURSE_NAME;
}

function inferDeadlineInput() {
  const text = getTaskInputText();
  const match = text.match(/(?:due|deadline).*?\b(may|jun|june|apr|april)\s+(\d{1,2})(?:\s+at\s+(\d{1,2})(?::(\d{2}))?)?/i);
  if (!match) return "2026-05-12T18:00";

  const monthMap = {
    apr: "04",
    april: "04",
    may: "05",
    jun: "06",
    june: "06",
  };
  const month = monthMap[match[1].toLowerCase()] || "05";
  const day = match[2].padStart(2, "0");
  const hour = String(match[3] || "18").padStart(2, "0");
  const minute = String(match[4] || "00").padStart(2, "0");
  return `2026-${month}-${day}T${hour}:${minute}`;
}

function parseDeadlineToDateTime(deadline) {
  const fallback = { date: "2026-05-12", time: "18:00" };
  if (!deadline) return fallback;

  const raw = String(deadline).trim();
  const numericMatch = raw.match(/(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:[T\s]+(\d{1,2})(?::(\d{2}))?)?/);
  if (numericMatch) {
    return {
      date: `${numericMatch[1]}-${numericMatch[2].padStart(2, "0")}-${numericMatch[3].padStart(2, "0")}`,
      time: `${String(numericMatch[4] || "18").padStart(2, "0")}:${String(numericMatch[5] || "00").padStart(2, "0")}`,
    };
  }

  const monthMatch = raw.match(/\b(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)\s+(\d{1,2})(?:[,\s]+(\d{4}))?(?:\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?)?/i);
  if (monthMatch) {
    const monthMap = {
      jan: "01", january: "01", feb: "02", february: "02", mar: "03", march: "03",
      apr: "04", april: "04", may: "05", jun: "06", june: "06", jul: "07", july: "07",
      aug: "08", august: "08", sep: "09", sept: "09", september: "09", oct: "10", october: "10",
      nov: "11", november: "11", dec: "12", december: "12",
    };
    return {
      date: `${monthMatch[3] || "2026"}-${monthMap[monthMatch[1].toLowerCase()]}-${monthMatch[2].padStart(2, "0")}`,
      time: `${String(monthMatch[4] || "18").padStart(2, "0")}:${String(monthMatch[5] || "00").padStart(2, "0")}`,
    };
  }

  const parsed = new Date(raw);
  if (!Number.isNaN(parsed.getTime())) {
    return {
      date: `${parsed.getFullYear()}-${String(parsed.getMonth() + 1).padStart(2, "0")}-${String(parsed.getDate()).padStart(2, "0")}`,
      time: `${String(parsed.getHours()).padStart(2, "0")}:${String(parsed.getMinutes()).padStart(2, "0")}`,
    };
  }

  return fallback;
}

function combineDateAndTime(date, time) {
  const safeDate = /^\d{4}-\d{2}-\d{2}$/.test(date || "") ? date : "2026-05-12";
  const safeTime = /^\d{2}:\d{2}$/.test(time || "") ? time : "18:00";
  return `${safeDate}T${safeTime}`;
}

function deadlinePartsToInput(deadline) {
  const { date, time } = parseDeadlineToDateTime(deadline);
  return combineDateAndTime(date, time);
}

function formatDeadlineDisplay(deadline) {
  const { date, time } = parseDeadlineToDateTime(deadline);
  return `${date.replace(/-/g, "/")} ${time}`;
}

function syncConfirmedDeadlineFromInputs() {
  const date = analysisPanel.querySelector("#confirmedDate")?.value;
  const time = analysisPanel.querySelector("#confirmedTime")?.value;
  confirmedDeadline = combineDateAndTime(date, time);
  saveCurrentConversation();
}

function getAttachmentMetadata() {
  return {
    fileName: uploadedFile.fileName,
    mimeType: uploadedFile.mimeType,
    fileSize: uploadedFile.fileSize,
  };
}

function isTextLike(file) {
  const name = file.name.toLowerCase();
  return file.type.startsWith("text/") || name.endsWith(".txt") || name.endsWith(".md");
}

function inferMimeType(fileName) {
  const lower = fileName.toLowerCase();
  if (lower.endsWith(".pdf")) return "application/pdf";
  if (lower.endsWith(".doc")) return "application/msword";
  if (lower.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
  if (lower.endsWith(".md")) return "text/markdown";
  return "application/octet-stream";
}

function summarizeFile(file) {
  const preview = file.extractedFileText ? ` Text preview: ${file.extractedFileText.slice(0, 220)}` : "";
  return `${file.fileName}, ${file.mimeType}, ${formatBytes(file.fileSize)}.${preview}`;
}

function buildTaskTitle() {
  const course = inferCourseName();
  const type = parsedTask?.taskType ? titleCase(parsedTask.taskType) : "DDL Task";
  return `${course} ${type}`;
}

function toISODeadline() {
  return `${deadlinePartsToInput(confirmedDeadline || inferDeadlineInput())}:00+08:00`;
}

function sumDurations(steps) {
  return steps.reduce(
    (total, step) => ({
      min: total.min + step.durationMin,
      max: total.max + step.durationMax,
    }),
    { min: 0, max: 0 }
  );
}

function getTaskProgress(task) {
  const total = task.steps.length;
  const done = task.steps.filter((step) => step.status === "done").length;
  return {
    total,
    done,
    remaining: Math.max(0, total - done),
    percent: total ? Math.round((done / total) * 100) : 0,
  };
}

function readTasks() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_TASKS) || "[]");
  } catch (error) {
    return [];
  }
}

function writeTasks(tasks) {
  localStorage.setItem(STORAGE_TASKS, JSON.stringify(tasks));
}

function readConversations() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_CONVERSATIONS) || "[]");
  } catch (error) {
    return [];
  }
}

function buildConversationTitle(text) {
  const compact = text.replace(/\s+/g, " ").trim();
  if (!compact) return "Untitled task";
  return compact.length > 22 ? `${compact.slice(0, 22)}...` : compact;
}

function formatBytes(size) {
  if (!size) return "0 KB";
  if (size < 1024 * 1024) return `${Math.max(1, Math.round(size / 1024))} KB`;
  return `${(size / 1024 / 1024).toFixed(1)} MB`;
}

function formatDeadline(value) {
  if (!value) return "No deadline";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function titleCase(value) {
  return String(value)
    .replace(/[_-]/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function readableError(error) {
  return error?.message || "Network, CORS, or response parsing failed.";
}

function escapeHTML(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttribute(value) {
  return escapeHTML(value).replace(/`/g, "&#096;");
}
