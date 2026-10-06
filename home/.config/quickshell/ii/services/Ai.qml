pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai

/**
 * Basic service to handle LLM chats over the OpenAI chat-completions API.
 * local-suite: trimmed to local models served by llama-swap (models come from
 * `ai.extraModels` in config.json). Tool calling is disabled here; the Phase 2
 * agent service will own tools.
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()
    signal garbageDetected() // the orb flashes red
    signal inputTextRequested(string text)
    signal commandRequested(string text)
    // Live status line: "idle" | "thinking" | "streaming" | "tool" | "waiting"
    property string liveState: "idle"
    property real turnStartedAt: 0
    readonly property int liveOutputTokens: turnFinishedTokens + Math.round(turnStreamChars / 4)
    property int turnFinishedTokens: 0
    property int turnStreamChars: 0
    property var turnTokensByMessage: ({})
    property bool turnInterrupted: false
    property var lastPartMessage: null
    property var todoMessage: null
    property var childToolSeen: ({})
    readonly property bool busy: root.frontierRunning || requester.running || (root.effectiveMode === "agent" && root.agentBusy)
    readonly property int chatFontSize: 13
    property string mode: "agent"
    readonly property string effectiveMode: mode === "agent" && opencode.connected ? "agent" : "chat"
    property bool agentBusy: false
    property bool planNext: false
    property bool acceptEdits: false
    property var childSessions: ({})
    property var partMessages: ({})
    property var messageRoles: ({})
    property var activeRequestIDs: ({})
    property var userMessageIDs: []
    property var sessions: []
    property int contextLimit: 0
    property real lastAgentActivityAt: 0
    property bool waitingForUser: false
    property var activePermission: null
    readonly property string sessionID: opencode.sessionID
    property alias agentDirectory: opencode.directory

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            // prompt = prompt.replaceAll(key, root.promptSubstitutions[key]);
            // QML/JS doesn't support replaceAll, so use split/join
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }
    // property var messages: []
    property var messageIDs: []
    property var messageByID: ({})
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded
    readonly property bool currentModelHasApiKey: {
        const model = models[currentModelId];
        if (!model || !model.requires_key) return true;
        if (!apiKeysLoaded) return false;
        const key = apiKeys[model.key_id];
        return (key?.length > 0);
    }
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    // Reasoning effort. A model's `efforts` map (config.json) turns it into the
    // model name sent to llama-swap, e.g. "low" -> "qwen:think".
    readonly property list<string> effortLevels: ["off", "low", "medium", "high"]
    // Current session's effort. Starts at the default from Settings (config.json);
    // /effort and the sidebar chip change it for this session only.
    property string effort: Config.options?.ai?.reasoningEffort ?? "off"
    // Frontier planner (tools/frontier-plan): per-session overrides of the Settings defaults.
    readonly property list<string> frontierModels: ["opus", "sonnet", "haiku"]
    readonly property list<string> frontierEfforts: ["low", "medium", "high", "xhigh", "max"]
    property string frontierModel: Config.options?.ai?.frontierModel ?? "opus"
    property string frontierEffort: Config.options?.ai?.frontierEffort ?? "high"
    property bool frontierRunning: false
    property bool frontierPending: false
    property string frontierPlan: ""
    property var frontierRow: null
    property var frontierLines: []
    property bool frontierEnded: false
    signal frontierPlanEdit(string plan)
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    OpencodeClient {
        id: opencode
        onEventReceived: payload => root.handleAgentEvent(payload)
        onDisconnected: {
            if (root.mode === "agent") root.addMessage("⎿ agent disconnected · using chat until it reconnects", root.interfaceRole);
        }
        onReconnected: {
            const note = () => { if (root.mode === "agent") root.addMessage("⎿ agent reconnected", root.interfaceRole); };
            if (opencode.sessionID) root.syncAgentHistory(note); else note();
        }
    }

    IpcHandler {
        target: "aiAgent"
        function send(text: string): void { root.sendUserMessage(text); }
        function permission(reply: string): void { if (root.activePermission) root.answerPermission(root.activePermission, reply); }
        function answer(label: string): void {
            const q = root.messageIDs.map(id => root.messageByID[id]).find(m => m.partType === "question" && !m.done);
            if (q) root.answerQuestion(q, q.requestData.questions.map(() => [label]));
        }
        function stop(): void { root.stop(); }
        function loadSession(id: string): void { root.loadAgentSession(id); }
        function setInput(text: string): void { root.inputTextRequested(text); }
        function command(text: string): void { root.commandRequested(text); }
        function newSession(): void { root.newAgentSession(); }
        function cwd(path: string): void { root.setAgentDirectory(path); }
        function rewind(messageID: string): void { root.rewind(messageID); }
        function unrevert(): void { root.unrevert(); }
        function mode(value: string): void { root.setMode(value); }
        function accept(on: bool): void { root.setAcceptEdits(on); }
        function planFrontier(task: string): void { root.planFrontier(task); }
        function planDecision(choice: string): void { root.planDecision(choice); }
        function frontierSet(model: string, effort: string): void { root.setFrontierModel(model); root.setFrontierEffort(effort); }
        function state(): string {
            const p = root.activePermission?.requestData;
            return JSON.stringify({
                mode: root.mode, acceptEdits: root.acceptEdits, frontier: { running: root.frontierRunning, pending: root.frontierPending, model: root.frontierModel, effort: root.frontierEffort }, effectiveMode: root.effectiveMode, connected: opencode.connected, busy: root.agentBusy,
                sessionID: root.sessionID, directory: opencode.directory, waitingForUser: root.waitingForUser,
                activePermission: p ? { id: p.id, permission: p.permission, patterns: p.patterns } : null,
                tokenTotal: root.tokenCount.total, liveState: root.liveState, turnStartedAt: root.turnStartedAt, liveOutputTokens: root.liveOutputTokens,
                messages: root.messageIDs.slice(-30).map(id => {
                    const m = root.messageByID[id];
                    return { role: m.role, partType: m.partType, tool: m.toolPart?.tool, status: m.toolPart?.state?.status, done: m.done, queued: m.queued, tools: m.tools.length ? m.tools : undefined, text: (m.content ?? "").slice(0, 120) };
                }),
                userMessageIDs: root.userMessageIDs.map(m => m.id)
            });
        }
    }

    FileView {
        id: agentConfig
        path: Qt.resolvedUrl("/home/zye/Projects/dev/local-suite/config/opencode/opencode.json")
        onLoadedChanged: {
            if (!loaded) return;
            try { root.contextLimit = JSON.parse(text()).provider.local.models.qwen.limit.input; }
            catch (e) { console.warn("[Ai] could not read agent context limit"); }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.agentBusy
        onTriggered: {
            if (!root.waitingForUser && root.lastAgentActivityAt > 0 && Date.now() - root.lastAgentActivityAt > 90000
                && !Object.values(root.partMessages).some(m => m.toolPart?.state?.status === "running" || m.tools.some(t => t.status === "running")))
                root.agentGarbage();
        }
    }

    // ---- Frontier planner -------------------------------------------------
    FileView {
        id: executorFile
        path: Qt.resolvedUrl("/home/zye/Projects/dev/local-suite/tools/frontier-plan/executor.md")
    }

    Process {
        id: frontierProc
        property string task: ""
        command: ["python3", "/home/zye/Projects/dev/local-suite/tools/frontier-plan/frontier_plan.py",
            "--cwd", opencode.directory, "--model", root.frontierModel, "--effort", root.frontierEffort, "--task", frontierProc.task]
        stdout: SplitParser { onRead: line => root.handleFrontierLine(line) }
        onExited: {
            root.frontierRunning = false;
            root.setFrontierRow("completed");
            if (!root.frontierEnded) root.addMessage("⎿ planner exited without a plan", root.interfaceRole);
        }
    }

    Process {
        id: planWriter
        onExited: (code) => {
            if (code !== 0) { root.addMessage("⎿ could not write PLAN.md", root.interfaceRole); return; }
            root.sendUserMessage(executorFile.text().trim());
        }
    }

    function setFrontierModel(value) {
        if (root.frontierModels.indexOf(value) === -1) { root.addMessage(Translation.tr("Frontier model is %1. Options: %2").arg(root.frontierModel).arg(root.frontierModels.join(", ")), root.interfaceRole); return; }
        root.frontierModel = value; // breaks the binding to the default, on purpose
    }

    function setFrontierEffort(value) {
        if (root.frontierEfforts.indexOf(value) === -1) { root.addMessage(Translation.tr("Frontier effort is %1. Options: %2").arg(root.frontierEffort).arg(root.frontierEfforts.join(", ")), root.interfaceRole); return; }
        root.frontierEffort = value;
    }

    function setFrontierRow(status) {
        if (!root.frontierRow) return;
        root.frontierRow.toolPart = { tool: "frontier", state: { status: status, title: `${root.frontierModel}·${root.frontierEffort}`, output: root.frontierLines.join("\n") } };
        root.frontierRow.done = status !== "running";
    }

    function planFrontier(task) {
        task = (task ?? "").trim();
        if (task.length === 0) { root.addMessage(Translation.tr("Usage: /plan-frontier TASK"), root.interfaceRole); return; }
        if (root.frontierRunning) { root.addMessage("⎿ a plan is already running · Esc to stop", root.interfaceRole); return; }
        root.frontierPending = false;
        root.frontierEnded = false;
        root.frontierLines = [];
        root.addMessage(task, "user");
        const row = root.aiMessageComponent.createObject(root, { role: "assistant", partType: "tool", content: "", rawContent: "", done: false });
        const id = root.idForMessage(row);
        root.messageByID[id] = row;
        root.messageIDs = [...root.messageIDs, id];
        root.frontierRow = row;
        root.setFrontierRow("running");
        frontierProc.task = task;
        root.frontierRunning = true;
        frontierProc.running = true;
    }

    function handleFrontierLine(line) {
        let ev;
        try { ev = JSON.parse(line); } catch (e) { return; }
        if (ev.type === "tool") {
            root.frontierLines = [...root.frontierLines, `${ev.name}(${ev.target})`];
            root.setFrontierRow("running");
        } else if (ev.type === "done") {
            root.frontierEnded = true;
            root.addMessage(ev.plan, "assistant");
            const tokens = ((ev.input_tokens + ev.output_tokens) / 1000).toFixed(1);
            root.addMessage(`⎿ ${ev.model} · ${Math.round(ev.duration_s)}s · ${tokens}k tok · $${ev.cost_usd.toFixed(2)}`, root.interfaceRole);
            root.frontierPlan = ev.plan;
            root.frontierPending = true;
        } else if (ev.type === "error") {
            root.frontierEnded = true;
            const login = /log ?in|auth|credential|401/i.test(ev.text) ? " · log in via Settings → Services → AI → Frontier planner" : "";
            root.addMessage(`⎿ planner: ${ev.text}${login}`, root.interfaceRole);
        }
    }

    function planDecision(choice) {
        if (!root.frontierPending) return;
        const c = String(choice);
        const plan = root.frontierPlan;
        if (c === "3" || c === "discard") {
            root.frontierPending = false;
            root.addMessage("⎿ plan discarded", root.interfaceRole);
        } else if (c === "2" || c === "edit") {
            root.frontierPending = false;
            root.frontierPlanEdit(plan);
        } else if (c === "1" || c === "run") {
            if (root.effectiveMode !== "agent") { root.addMessage("⎿ the local agent is not available · plan kept", root.interfaceRole); return; }
            root.frontierPending = false;
            planWriter.command = ["bash", "-c", 'printf "%s\\n" "$1" > "$2/PLAN.md"', "_", plan, opencode.directory];
            planWriter.running = true;
        }
    }

    function agentGarbage() {
        if (!root.agentBusy) return;
        root.agentBusy = false;
        opencode.abort();
        root.unloadLocalModel();
        root.garbageDetected();
        root.addMessage("⎿ model stalled or produced garbage · try /retry", root.interfaceRole);
    }

    function newAgentSession() {
        opencode.createSession((data, ok) => {
            if (!ok) { root.addMessage("⎿ could not create agent session", root.interfaceRole); return; }
            root.clearMessages();
            root.agentBusy = false;
            root.acceptEdits = false;
        });
    }

    function setAcceptEdits(on) {
        root.acceptEdits = on;
    }

    function setMode(value) {
        if (value !== "agent" && value !== "chat") return;
        root.mode = value;
    }

    function addAgentPart(part) {
        if (!part?.id || !part.sessionID || part.sessionID !== opencode.sessionID) return;
        if (root.messageRoles[part.messageID] === "user") return;
        if (!["text", "reasoning", "tool"].includes(part.type)) return;
        if (part.type === "tool" && part.tool === "todowrite") {
            if (Array.isArray(part.state?.input?.todos)) root.showTodos(part.state.input.todos);
            return;
        }
        if (part.type === "tool" && ["read", "glob", "grep", "list"].includes(part.tool)) {
            root.updateToolGroup(part);
            root.refreshLive();
            return;
        }
        let message = root.partMessages[part.id];
        if (!message) {
            message = root.aiMessageComponent.createObject(root, {
                role: "assistant", partType: part.type, partID: part.id,
                opencodeMessageID: part.messageID, content: "", rawContent: "",
                thinking: false, done: part.type !== "text" && part.type !== "reasoning",
                startedAt: part.time?.start ?? Date.now()
            });
            root.partMessages[part.id] = message;
            const id = root.idForMessage(message);
            root.messageByID[id] = message;
            root.messageIDs = [...root.messageIDs, id];
        }
        if (part.type === "tool") {
            const childID = part.state?.metadata?.sessionId;
            if (part.tool === "task" && childID) {
                root.childSessions[childID] = message;
                message.toolUses = Math.max(Object.keys(root.childToolSeen).filter(k => root.childToolSeen[k] === childID).length, part.state?.metadata?.summary?.length ?? 0);
            }
            message.toolPart = part;
            message.done = ["completed", "error"].includes(part.state?.status);
            message.errorText = part.state?.status === "error" ? String(part.state?.error ?? "").split("\n")[0] : "";
        } else if (part.text !== undefined) {
            message.rawContent = part.text;
            message.content = part.type === "reasoning" ? `<think>${part.text}</think>` : part.type === "text" ? part.text.replace(/^\s+/, "") : part.text;
        }
        if (part.time?.end) {
            message.done = true;
            if (part.time.start) message.startedAt = part.time.start;
            message.finishedAt = part.time.end;
        }
        root.lastPartMessage = message;
        root.refreshLive();
    }

    function relPath(path) {
        const dir = opencode.directory, p = String(path ?? "");
        if (p === dir) return ".";
        return p.startsWith(dir + "/") ? p.slice(dir.length + 1) : p;
    }

    function toolEntry(part) {
        const st = part.state ?? {}, input = st.input ?? {}, out = String(st.output ?? "");
        const entry = { partID: part.id, tool: part.tool, status: st.status ?? "pending", target: "", summary: "", dir: false, errorText: "" };
        if (part.tool === "read" || part.tool === "list") {
            entry.target = root.relPath(input.filePath ?? input.path ?? "");
            if (part.tool === "list" || out.includes("<type>directory</type>")) {
                entry.dir = true;
                entry.summary = `${out.match(/\((\d+) entries\)/)?.[1] ?? 0} entries`;
            } else {
                const n = out.split("\n").filter(l => /^\d+: /.test(l)).length || Number(out.match(/total (\d+) lines/)?.[1] ?? 0);
                entry.summary = `${n} line${n === 1 ? "" : "s"}`;
            }
        } else {
            entry.target = String(input.pattern ?? "") + (input.path ? ` in ${root.relPath(input.path)}` : "");
            const n = part.tool === "grep" ? Number(out.match(/Found (\d+) match/)?.[1] ?? 0) : out.split("\n").filter(l => l.trim() && !l.startsWith("No files")).length;
            entry.summary = part.tool === "grep" ? `${n} match${n === 1 ? "" : "es"}` : `${n} file${n === 1 ? "" : "s"}`;
        }
        if (entry.status === "error") entry.errorText = String(st.error ?? "").split("\n")[0];
        if (entry.status !== "completed") entry.summary = "";
        return entry;
    }

    function updateToolGroup(part) {
        let group = root.partMessages[part.id];
        if (!group) {
            for (let i = root.messageIDs.length - 1; i >= 0; i--) {
                const m = root.messageByID[root.messageIDs[i]];
                if (!m.visibleToUser || ((m.partType === "text" || m.partType === "reasoning") && !m.rawContent.trim())) continue;
                if (m.partType === "toolgroup") group = m;
                break;
            }
        }
        if (!group) {
            group = root.aiMessageComponent.createObject(root, {
                role: "assistant", partType: "toolgroup", opencodeMessageID: part.messageID,
                content: "", rawContent: "", thinking: false, done: false, startedAt: part.state?.time?.start ?? Date.now()
            });
            const id = root.idForMessage(group);
            root.messageByID[id] = group;
            root.messageIDs = [...root.messageIDs, id];
        }
        root.partMessages[part.id] = group;
        const entry = root.toolEntry(part);
        const tools = group.tools.slice();
        const at = tools.findIndex(t => t.partID === part.id);
        if (at >= 0) tools[at] = entry; else tools.push(entry);
        group.tools = tools;
        group.done = tools.every(t => t.status === "completed" || t.status === "error");
        if (group.done) group.finishedAt = Date.now();
        root.lastPartMessage = group;
    }

    function refreshLive() {
        let state = "idle";
        if (root.agentBusy || root.frontierRunning) {
            const last = root.lastPartMessage;
            if (root.waitingForUser) state = "waiting";
            else if (last && !last.done) state = last.partType === "text" ? "streaming" : last.partType === "reasoning" ? "thinking" : "tool";
            else state = "thinking";
        }
        if (root.liveState !== state) root.liveState = state;
    }

    function appendMarker(partType, fields) {
        const message = root.aiMessageComponent.createObject(root, Object.assign({ role: "interface", partType, content: "", rawContent: "", done: true }, fields));
        const id = root.idForMessage(message);
        root.messageByID[id] = message;
        root.messageIDs = [...root.messageIDs, id];
    }

    function addAgentRequest(type, data) {
        if (!data?.id || (data.sessionID !== opencode.sessionID && !root.childSessions[data.sessionID])) return;
        if (root.activeRequestIDs[data.id]) return;
        const message = root.aiMessageComponent.createObject(root, {
            role: "interface", partType: type, requestData: data, content: "", rawContent: "", done: false
        });
        const id = root.idForMessage(message);
        root.messageByID[id] = message;
        if (type !== "permission") root.messageIDs = [...root.messageIDs, id];
        root.activeRequestIDs[data.id] = message;
        root.waitingForUser = true;
        if (type === "permission" && !root.activePermission) root.activePermission = message;
    }

    function resolveAgentRequest(requestID, reply) {
        const message = root.activeRequestIDs[requestID];
        if (!message || message.done) return;
        message.answer = reply === "once" ? "allowed once" : reply === "always" ? "always allowed" : reply === "reject" ? "denied" : reply;
        message.done = true;
        const open = Object.values(root.activeRequestIDs).filter(m => !m.done);
        root.waitingForUser = open.length > 0;
        if (root.activePermission === message) root.activePermission = open.find(m => m.partType === "permission") ?? null;
    }

    function answerPermission(message, reply) {
        if (message.done) return;
        opencode.replyPermission(message.requestData.id, reply, (data, ok) => {
            root.resolveAgentRequest(message.requestData.id, reply);
            if (!ok) root.addMessage("⎿ approval was already resolved or could not be sent", root.interfaceRole);
        });
    }

    function answerQuestion(message, answers) {
        if (message.done) return;
        opencode.replyQuestion(message.requestData.id, answers, (data, ok) => {
            if (ok) root.resolveAgentRequest(message.requestData.id, "answered");
            else root.addMessage("⎿ question reply failed", root.interfaceRole);
        });
    }

    function rejectQuestion(message) {
        if (message.done) return;
        opencode.rejectQuestion(message.requestData.id, (data, ok) => {
            root.resolveAgentRequest(message.requestData.id, "skipped");
        });
    }

    function handleAgentEvent(payload) {
        const type = payload?.type ?? "";
        const props = payload?.properties ?? payload?.data ?? {};
        const session = props.sessionID ?? props.part?.sessionID ?? props.info?.sessionID;
        if (type === "session.created" && props.info?.parentID && (props.info.parentID === opencode.sessionID || root.childSessions[props.info.parentID])) {
            root.childSessions[props.info.id] = true;
            return;
        }
        if (root.childSessions[session]) {
            root.lastAgentActivityAt = Date.now();
            const part = props.part;
            if (type === "message.part.updated" && part?.type === "tool" && !root.childToolSeen[part.id]) {
                root.childToolSeen[part.id] = session;
                const task = root.childSessions[session];
                if (task?.partType) task.toolUses += 1;
            }
            if (!/^(permission|question)(\.v2)?\./.test(type)) return;
        } else if (session !== opencode.sessionID) return;
        root.lastAgentActivityAt = Date.now();
        if (type === "message.part.updated") root.addAgentPart(props.part);
        else if (type === "message.part.delta") {
            const message = root.partMessages[props.partID];
            if (!message || props.field !== "text") return;
            message.rawContent += props.delta ?? "";
            root.turnStreamChars += (props.delta ?? "").length;
            root.lastPartMessage = message;
            root.refreshLive();
            message.content = message.partType === "reasoning" ? `<think>${message.rawContent}</think>` : message.partType === "text" ? message.rawContent.replace(/^\s+/, "") : message.rawContent;
            if (/\/{24,}|!{24,}/.test(message.rawContent.slice(-128))) root.agentGarbage();
        } else if (type === "message.updated" && props.info) {
            root.messageRoles[props.info.id] = props.info.role;
            if (props.info.role === "user" && !root.userMessageIDs.some(m => m.id === props.info.id)) {
                const pending = root.userMessageIDs.findIndex(m => !m.id);
                if (pending >= 0) {
                    root.userMessageIDs = root.userMessageIDs.map((m, i) => i === pending ? { id: props.info.id, text: m.text } : m);
                    const mine = root.messageIDs.map(id => root.messageByID[id]).filter(m => m.role === "user" && !m.opencodeMessageID);
                    const target = mine.find(m => m.queued) ?? mine[0];
                    if (target) target.opencodeMessageID = props.info.id;
                }
            }
            if (props.info.role === "assistant" && props.info.parentID) {
                const queued = root.messageIDs.map(id => root.messageByID[id]).find(m => m.queued && m.opencodeMessageID === props.info.parentID);
                if (queued) queued.queued = false;
            }
            const tokens = props.info.tokens;
            if (tokens && props.info.role === "assistant" && tokens.output > 0 && root.turnTokensByMessage[props.info.id] !== tokens.output) {
                root.turnTokensByMessage[props.info.id] = tokens.output;
                root.turnFinishedTokens = Object.values(root.turnTokensByMessage).reduce((a, b) => a + b, 0);
                root.turnStreamChars = 0;
            }
            if (tokens && props.info.role === "assistant") {
                root.tokenCount.input = (tokens.input ?? 0) + (tokens.cache?.read ?? 0);
                root.tokenCount.output = tokens.output ?? 0;
                root.tokenCount.total = root.tokenCount.input;
            }
        } else if (type === "permission.asked" || type === "question.asked" || type === "question.v2.asked") {
            root.addAgentRequest(type.startsWith("permission") ? "permission" : "question", props);
        } else if (/^(permission|question)(\.v2)?\.(replied|rejected)$/.test(type)) {
            root.resolveAgentRequest(props.requestID ?? props.id, props.reply ?? (type.endsWith("rejected") ? "skipped" : "answered"));
        } else if (type === "todo.updated") {
            root.showTodos(props.todos ?? []);
        } else if (type === "session.status") {
            root.agentBusy = props.status?.type === "busy";
            if (root.agentBusy && !root.turnStartedAt) root.turnStartedAt = Date.now();
            root.refreshLive();
        } else if (type === "session.idle") {
            root.agentBusy = false;
            root.waitingForUser = false;
            for (const partID in root.partMessages) {
                const message = root.partMessages[partID];
                if (!message.done) {
                    message.done = true;
                    message.finishedAt = Date.now();
                }
            }
            for (const id of root.messageIDs) root.messageByID[id].queued = false;
            if (root.turnStartedAt > 0 && !root.turnInterrupted) {
                const now = Date.now();
                root.appendMarker("turnend", { durationMs: now - root.turnStartedAt, outputTokens: root.liveOutputTokens, doneAt: now });
            }
            root.turnStartedAt = 0;
            root.turnInterrupted = false;
            root.turnTokensByMessage = ({});
            root.turnFinishedTokens = 0;
            root.turnStreamChars = 0;
            root.refreshLive();
            root.responseFinished();
        } else if (type === "session.error") {
            root.agentBusy = false;
            if (props.error?.name !== "MessageAbortedError") root.addMessage(`⎿ ${props.error?.data?.message ?? props.error?.name ?? "agent session error"}`, root.interfaceRole);
        }
    }

    function showTodos(items) {
        if (root.todoMessage) {
            root.todoMessage.todos = items;
            root.todoMessage.visibleToUser = items.length > 0;
            return;
        }
        if (!items.length) return;
        const message = root.aiMessageComponent.createObject(root, {
            role: "interface", partType: "todo", todos: items, content: "", rawContent: "", done: true
        });
        const id = root.idForMessage(message);
        root.messageByID[id] = message;
        root.messageIDs = [...root.messageIDs, id];
        root.todoMessage = message;
    }

    function syncAgentHistory(done) {
        opencode.messages((items, ok) => {
            if (!ok || !Array.isArray(items)) { if (done) done(); return; }
            root.clearMessages();
            // Rebuild the turn-end lines: one per user turn whose last assistant message has completed.
            let turn = null;
            const closeTurn = () => {
                if (turn && turn.doneAt > 0) root.appendMarker("turnend", { durationMs: turn.doneAt - turn.startedAt, outputTokens: turn.tokens, doneAt: turn.doneAt });
                turn = null;
            };
            for (const item of items) {
                const info = item.info;
                root.messageRoles[info.id] = info.role;
                if (info.role === "user") {
                    closeTurn();
                    turn = { startedAt: info.time?.created ?? 0, doneAt: 0, tokens: 0 };
                    const content = (item.parts ?? []).filter(p => p.type === "text").map(p => p.text ?? "").join("\n");
                    root.addMessage(content, "user");
                    root.userMessageIDs = [...root.userMessageIDs, { id: info.id, text: content }];
                } else {
                    for (const part of item.parts ?? []) root.addAgentPart(part);
                }
                if (info.role === "assistant" && info.tokens) {
                    root.tokenCount.input = (info.tokens.input ?? 0) + (info.tokens.cache?.read ?? 0);
                    root.tokenCount.output = info.tokens.output ?? 0;
                    root.tokenCount.total = root.tokenCount.input;
                }
                if (info.role === "assistant" && turn) {
                    turn.doneAt = info.time?.completed ?? 0;
                    turn.tokens += info.tokens?.output ?? 0;
                }
            }
            closeTurn();
            root.syncPendingRequests();
            if (done) done();
        });
    }

    function syncPendingRequests() {
        opencode.pendingPermissions((items, ok) => {
            if (ok && Array.isArray(items)) for (const item of items) root.addAgentRequest("permission", item);
        });
        opencode.pendingQuestions((items, ok) => {
            if (ok && Array.isArray(items)) for (const item of items) root.addAgentRequest("question", item);
        });
    }

    function listAgentSessions() {
        opencode.listSessions((items, ok) => {
            if (ok && Array.isArray(items)) root.sessions = items.sort((a, b) => (b.time?.updated ?? 0) - (a.time?.updated ?? 0));
        });
    }

    function loadAgentSession(id) { opencode.loadSession(id, (items, ok) => { if (ok) { root.setAgentDirectory(opencode.directory); root.syncAgentHistory(); } }); }
    function setAgentDirectory(path) {
        const normalized = path.replace(/^~/, "/home/zye").replace(/\/$/, "") || "/";
        if (opencode.directory !== normalized) {
            opencode.sessionID = "";
            root.clearMessages();
            root.agentBusy = false;
            root.acceptEdits = false;
        }
        opencode.directory = normalized;
        Config.options.ai.agentDirectory = normalized;
        const recent = Config.options.ai.recentDirectories ?? [];
        Config.options.ai.recentDirectories = [normalized, ...recent.filter(p => p !== normalized)].slice(0, 12);
    }
    function rewind(messageID) { opencode.revert(messageID, (data, ok) => { if (ok) root.syncAgentHistory(); else root.addMessage("⎿ rewind failed", root.interfaceRole); }); }
    function unrevert() { opencode.unrevert((data, ok) => { if (ok) root.syncAgentHistory(); else root.addMessage("⎿ unrevert failed", root.interfaceRole); }); }
    function compact() { opencode.summarize(root.requestModelName(root.getModel()), (data, ok) => root.addMessage(ok ? "⎿ context compacted" : "⎿ compact failed", root.interfaceRole)); }
    function stop() {
        if (root.frontierRunning) frontierProc.signal(15);
        else if (root.effectiveMode === "agent") {
            const wasBusy = root.agentBusy || root.turnStartedAt > 0;
            opencode.abort();
            root.agentBusy = false;
            if (wasBusy) {
                root.turnInterrupted = true;
                root.appendMarker("interrupted", {});
                root.refreshLive();
            }
        } else requester.running = false;
    }
    function fetchTodos() { opencode.todos((items, ok) => { if (ok) root.showTodos(items); }); }
    function showPermissions() {
        opencode.pendingPermissions((pending, ok) => {
            if (!ok) { root.addMessage("⎿ could not load permissions", root.interfaceRole); return; }
            opencode.savedPermissions((saved, savedOK) => {
                const current = (pending ?? []).filter(p => p.sessionID === opencode.sessionID);
                const pendingLines = current.map(p => `- ${p.permission}: ${(p.patterns ?? []).join(", ")}`);
                const savedLines = savedOK ? (saved?.data ?? []).map(p => `- ${p.action}: ${p.resource}`) : [];
                root.addMessage(`pending permissions: ${current.length}\n${pendingLines.join("\n") || "none"}\n\nsaved approvals: ${savedLines.length}\n${savedLines.join("\n") || "none"}`, root.interfaceRole);
            });
        });
    }

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function safeModelName(modelName) {
        return modelName.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-")
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})` 
    }

    // Tool calling is off for now (the OpenAI strategy doesn't parse tool calls).
    property string currentTool: "none"
    property var tools: ({ "openai": { "none": [] } })

    // Model properties:
    // - name: Name of the model
    // - icon: Icon name of the model
    // - description: Description of the model
    // - endpoint: Endpoint of the model
    // - model: Model name of the model
    // - requires_key: Whether the model requires an API key
    // - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
    // - key_get_link: Link to get an API key
    // - key_get_description: Description of pricing and how to get an API key
    // - api_format: The API format of the model. Only "openai" is supported here.
    // - extraParams: Extra parameters to be passed to the model. This is a JSON object.
    // - efforts: Map of effort level -> model name to request, e.g. {"low": "qwen:think"}.
    // All models come from `ai.extraModels` in config.json (see addUserModels).
    property var models: ({})
    property var modelList: Object.keys(root.models)
    // Fall back to the first configured model if the saved one no longer exists.
    property var currentModelId: (Persistent.states?.ai?.model in root.models) ? Persistent.states.ai.model : (modelList[0] ?? "")

    property var apiStrategies: {
        "openai": openaiApiStrategy.createObject(this),
    }
    property ApiStrategy currentApiStrategy: apiStrategies[models[currentModelId]?.api_format || "openai"]

    function addUserModels() {
        (Config?.options.ai?.extraModels ?? []).forEach(model => {
            const safeModelName = root.safeModelName(model["model"]);
            root.addModel(safeModelName, model)
        });
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return;
            root.addUserModels()
        }
    }

    property string requestScriptFilePath: "/tmp/quickshell/ai/request.sh"
    // The request body goes in a file: a long chat would exceed the per-argument
    // size limit (128 KiB) if passed to curl inline.
    property string requestBodyFilePath: "/tmp/quickshell/ai/request.json"
    property string pendingFilePath: ""

    Component.onCompleted: {
        setModel(currentModelId, false, false); // Do necessary setup for model
        root.addUserModels() // Config onReadyChanged above might not fire if config is loaded before this service
    }

    function addModel(modelName, data) {
        root.models = Object.assign({}, root.models, {
            [modelName]: aiModelComponent.createObject(this, data)
        });
        root.modelList = Object.keys(root.models);
    }

    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
        promptLoader.path = "" // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0) return;
        if (role === root.interfaceRole) message = message.replace(/^⎿\s*/, "");
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
    }

    function addApiKeyAdvice(model) {
        root.addMessage(
            Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3')
                .arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), 
            Ai.interfaceRole
        );
    }

    function getModel() {
        return models[currentModelId];
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = ""
        modelId = modelId.toLowerCase()
        if (modelList.indexOf(modelId) !== -1) {
            const model = models[modelId]
            // See if policy prevents online models
            if (Config.options.policies.ai === 2 && !/localhost|127\.0\.0\.1/.test(model.endpoint)) {
                root.addMessage(
                    Translation.tr("Online models disallowed\n\nControlled by `policies.ai` config option"),
                    root.interfaceRole
                );
                return;
            }
            if (setPersistentState) Persistent.states.ai.model = modelId;
            if (model.requires_key) {
                // If key not there show advice
                if (root.apiKeysLoaded && (!root.apiKeys[model.key_id] || root.apiKeys[model.key_id].length === 0)) {
                    root.addApiKeyAdvice(model)
                }
            }
        } else {
            if (feedback) root.addMessage(Translation.tr("Invalid model. Supported: \n```\n") + modelList.join("\n```\n```\n"), Ai.interfaceRole) + "\n```"
        }
    }

    function setEffort(level) {
        if (root.effortLevels.indexOf(level) === -1) {
            root.addMessage(Translation.tr("Effort is %1. Options: %2").arg(root.effort).arg(root.effortLevels.join(", ")), root.interfaceRole);
            return;
        }
        root.effort = level; // breaks the binding to the default, on purpose
    }

    // Model name to send: the model's `efforts` entry for the current effort, if any.
    function requestModelName(model) {
        return model.efforts?.[root.effort] ?? model.model;
    }

    // --- Local server status (llama-swap) ---
    // Polled only while the chat is visible (AiChat sets statusPolling).
    property bool statusPolling: false
    // "off" (not in VRAM), "starting" (loading) or "ready", from llama-swap /running.
    property string localModelState: "off"
    readonly property bool localModelLoaded: localModelState === "ready"
    property int vramUsedMiB: -1
    property int vramTotalMiB: -1
    readonly property string localServer: "http://127.0.0.1:8080"

    Timer {
        interval: 3000
        running: root.statusPolling
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        // Line 1: llama-swap /running JSON; line 2: "used, total" VRAM in MiB.
        command: ["bash", "-c", `curl -fsS --max-time 2 ${root.localServer}/running | tr -d '\n'; echo; nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                try {
                    const running = JSON.parse(lines[0]).running ?? [];
                    const states = running.map(m => m.state);
                    root.localModelState = states.includes("ready") ? "ready" : (states.includes("starting") || wakeProc.running) ? "starting" : "off";
                } catch (e) {
                    root.localModelState = "off";
                }
                const vram = (lines[1] ?? "").split(",").map(v => parseInt(v));
                root.vramUsedMiB = vram[0] ?? -1;
                root.vramTotalMiB = vram[1] ?? -1;
            }
        }
    }

    function printStatus() {
        const model = root.getModel();
        const used = root.tokenCount.total > 0 ? root.tokenCount.total : 0;
        root.addMessage(Translation.tr("**Model**: %1 (effort: %2, requests `%3`)\n\n**Server**: %4\n\n**VRAM**: %5 / %6 MiB\n\n**Context**: %7 / %8 tokens")
            .arg(model?.name ?? "-").arg(root.effort).arg(model ? root.requestModelName(model) : "-")
            .arg(root.localModelLoaded ? Translation.tr("loaded") : Translation.tr("not loaded (loads on next message)"))
            .arg(root.vramUsedMiB).arg(root.vramTotalMiB)
            .arg(used).arg(model?.context_size ?? "?"), root.interfaceRole);
    }

    Process {
        id: unloadProc
        command: ["curl", "-fsS", "-X", "POST", `${root.localServer}/api/models/unload`]
        onExited: (exitCode, exitStatus) => {
            root.addMessage(exitCode === 0 ? Translation.tr("Local model unloaded. The next message loads it again.")
                                           : Translation.tr("Unload failed (is llama-swap running?)"), root.interfaceRole);
            statusProc.running = true;
        }
    }

    function unloadLocalModel() {
        unloadProc.running = true;
    }

    // Load the current model without sending a prompt (llama-swap starts a model
    // on any request routed to it). Used when the sidebar opens.
    Process {
        id: wakeProc
        command: ["curl", "-fsS", "-o", "/dev/null", "--max-time", "180",
            `${root.localServer}/upstream/${root.getModel()?.model ?? ""}/health`]
        onExited: statusProc.running = true
    }

    function wakeLocalModel() {
        if (root.localModelState !== "off" || wakeProc.running || !root.getModel()) return;
        root.localModelState = "starting";
        wakeProc.running = true;
    }

    function getTemperature() {
        return root.temperature;
    }

    function setTemperature(value) {
        if (value == NaN || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), Ai.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
    }

    function setApiKey(key) {
        const model = models[currentModelId];
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            const model = models[currentModelId];
            root.addApiKeyAdvice(model)
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        root.addMessage(Translation.tr("API key set for %1").arg(model.name), Ai.interfaceRole);
    }

    function printApiKey() {
        const model = models[currentModelId];
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                root.addMessage(Translation.tr("API key:\n\n```txt\n%1\n```").arg(key), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
        root.partMessages = ({});
        root.messageRoles = ({});
        root.activeRequestIDs = ({});
        root.userMessageIDs = [];
        root.activePermission = null;
        root.frontierPending = false;
        root.waitingForUser = false;
        root.childSessions = ({});
        root.childToolSeen = ({});
        root.todoMessage = null;
        root.lastPartMessage = null;
    }

    FileView {
        id: requesterScriptFile
    }

    FileView {
        id: requestBodyFile
    }

    Process {
        id: requester
        property list<string> baseCommand: ["bash"]
        property AiMessageData message
        property ApiStrategy currentStrategy

        function markDone() {
            if (requester.message.done) return;
            requester.message.done = true;
            requester.message.finishedAt = Date.now();
            // All-NaN logits stream "////..." (llama.cpp CUDA bug) or "!!!!..."
            if (/\/{24,}|!{24,}/.test(requester.message.content)) {
                root.garbageDetected();
                root.addMessage(Translation.tr("The model produced garbage (all-NaN logits on a long prompt). Use /unload, then /retry or /clear."), root.interfaceRole);
            }
            if (root.postResponseHook) {
                root.postResponseHook();
                root.postResponseHook = null; // Reset hook after use
            }
            root.saveChat("lastSession")
            root.responseFinished()
        }

        function makeRequest() {
            const model = models[currentModelId];

            // Fetch API keys if needed
            if (model?.requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
            
            requester.currentStrategy = root.currentApiStrategy;
            requester.currentStrategy.reset(); // Reset strategy state

            /* Put API key in environment variable */
            if (model.requires_key) requester.environment[`${root.apiKeyEnvVarName}`] = root.apiKeys ? (root.apiKeys[model.key_id] ?? "") : ""

            /* Build endpoint, request data */
            const endpoint = root.currentApiStrategy.buildEndpoint(model);
            const messageArray = root.messageIDs.map(id => root.messageByID[id]);
            const filteredMessageArray = messageArray.filter(message => message.role !== Ai.interfaceRole);
            const data = root.currentApiStrategy.buildRequestData(model, filteredMessageArray, root.systemPrompt, root.temperature, root.tools[model.api_format][root.currentTool], "");
            data.model = root.requestModelName(model);
            // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));

            let requestHeaders = {
                "Content-Type": "application/json",
            }
            
            /* Create local message object */
            requester.message = root.aiMessageComponent.createObject(root, {
                "startedAt": Date.now(),
                "role": "assistant",
                "model": currentModelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(requester.message);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = requester.message;

            /* Build header string for curl */ 
            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            // console.log("Request headers: ", JSON.stringify(requestHeaders));
            // console.log("Header string: ", headerString);

            /* Get authorization header from strategy */
            const authHeader = requester.currentStrategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
            
            /* Script shebang */
            const scriptShebang = "#!/usr/bin/env bash\n";

            /* Write the body; inline attached images as base64 data URLs if any */
            const bodyPath = CF.FileUtils.trimFileProtocol(root.requestBodyFilePath)
            const bodyText = JSON.stringify(data)
            requestBodyFile.path = Qt.resolvedUrl(bodyPath)
            requestBodyFile.setText(bodyText)
            let scriptFileSetupContent = ""
            if (bodyText.includes("@@IMAGE:")) {
                scriptFileSetupContent = `python3 - '${bodyPath}' <<'PY'
import base64, mimetypes, re, sys
path = sys.argv[1]
body = open(path).read()
def data_url(m):
    f = m.group(1)
    mime = mimetypes.guess_type(f)[0] or "image/png"
    return "data:" + mime + ";base64," + base64.b64encode(open(f, "rb").read()).decode()
open(path, "w").write(re.sub(r"@@IMAGE:(.*?)@@", data_url, body))
PY
`
            }

            /* Create command string */
            let scriptRequestContent = ""
            scriptRequestContent += `curl --no-buffer "${endpoint}"`
                + ` ${headerString}`
                + (authHeader ? ` ${authHeader}` : "")
                + ` --data-binary '@${bodyPath}'`
                + "\n"
            
            /* Send the request */
            const scriptContent = requester.currentStrategy.finalizeScriptContent(scriptShebang + scriptFileSetupContent + scriptRequestContent)
            const shellScriptPath = CF.FileUtils.trimFileProtocol(root.requestScriptFilePath)
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath)
            requesterScriptFile.setText(scriptContent)
            requester.command = baseCommand.concat([shellScriptPath]);
            requester.running = true
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;
                if (requester.message.thinking) requester.message.thinking = false;
                // console.log("[Ai] Raw response line: ", data);

                // Handle response line
                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);
                    // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));

                    if (result.functionCall) {
                        requester.message.functionCall = result.functionCall;
                        root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        root.tokenCount.input = result.tokenUsage.input;
                        root.tokenCount.output = result.tokenUsage.output;
                        root.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                    
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    requester.message.rawContent += data;
                    requester.message.content += data;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const result = requester.currentStrategy.onRequestFinished(requester.message);
            
            if (result.finished) {
                requester.markDone();
            } else if (!requester.message.done) {
                requester.markDone();
            }

            // Handle error responses
            if (requester.message.content.includes("API key not valid")) {
                root.addApiKeyAdvice(models[requester.message.model]);
            }
        }
    }

    function sendUserMessage(message) {
        if (message.length === 0) return;
        if (root.effectiveMode === "agent") {
            const send = () => {
                const wasBusy = root.agentBusy;
                root.addMessage(message, "user");
                root.messageByID[root.messageIDs[root.messageIDs.length - 1]].queued = wasBusy;
                root.userMessageIDs = [...root.userMessageIDs, { id: "", text: message }];
                root.agentBusy = true;
                if (!wasBusy) {
                    root.turnStartedAt = Date.now();
                    root.turnTokensByMessage = ({});
                    root.turnFinishedTokens = 0;
                    root.turnStreamChars = 0;
                    root.turnInterrupted = false;
                }
                root.refreshLive();
                root.lastAgentActivityAt = Date.now();
                const agent = root.planNext ? "plan" : root.acceptEdits ? "local-accept" : "";
                root.planNext = false;
                opencode.prompt(message, root.requestModelName(root.getModel()), root.pendingFilePath, agent, (data, ok) => {
                    if (!ok) { root.agentBusy = false; root.addMessage("⎿ agent prompt failed", root.interfaceRole); }
                });
                root.pendingFilePath = "";
            };
            if (!opencode.sessionID) opencode.createSession((data, ok) => { if (ok) send(); else root.addMessage("⎿ agent session failed", root.interfaceRole); });
            else send();
            return;
        }
        root.addMessage(message, "user");
        if (root.pendingFilePath.length > 0) {
            // The image belongs to this user message, so it is re-sent with it on every turn.
            root.messageByID[root.messageIDs[root.messageIDs.length - 1]].localFilePath = root.pendingFilePath;
            root.pendingFilePath = "";
        }
        requester.makeRequest();
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function retryLast() {
        if (root.effectiveMode === "agent") {
            const last = root.userMessageIDs[root.userMessageIDs.length - 1];
            if (last) root.sendUserMessage(last.text);
            else root.addMessage("⎿ nothing to retry", root.interfaceRole);
            return;
        }
        for (let i = root.messageIDs.length - 1; i >= 0; i--) {
            if (root.messageByID[root.messageIDs[i]].role === "assistant") {
                root.regenerate(i);
                return;
            }
        }
        root.addMessage(Translation.tr("Nothing to retry"), root.interfaceRole);
    }

    // Copy the last `count` user/assistant messages (all if count <= 0) as markdown.
    function copyMessages(count) {
        let messages = root.messageIDs.map(id => root.messageByID[id]).filter(m => m.role === "user" || m.role === "assistant");
        if (count > 0) messages = messages.slice(-count);
        Quickshell.clipboardText = messages.map(m => (m.role === "user" ? "> " : "") + m.rawContent.replace(/<think>[\s\S]*?<\/think>\s*/g, "").trim()).join("\n\n");
        root.addMessage(Translation.tr("Copied %1 message(s)").arg(messages.length), root.interfaceRole);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;
        // Remove all messages after this one
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
        requester.makeRequest();
    }

    function createFunctionOutputMessage(name, output, includeOutputInChat = true) {
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionResponse": output,
            "thinking": false,
            "done": true,
            // "visibleToUser": false,
        });
    }

    function addFunctionOutputMessage(name, output) {
        const aiMessage = createFunctionOutputMessage(name, output);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"))
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"

        const responseMessage = createFunctionOutputMessage(message.functionName, "", false);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true; // Start the command execution
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        command: ["bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: (output) => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                const updatedContent = commandExecutionProc.baseMessageContent + `\n\n<think>\n<tt>${commandExecutionProc.message.functionResponse}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            requester.makeRequest(); // Continue
        }
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options)
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            requester.makeRequest();
        } else if (name === "set_shell_config") {
            if (!args.key || !args.value) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `key` and `value`."));
                return;
            }
            const key = args.key;
            const value = args.value;
            Config.setNestedValue(key, value);
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true; // Use thinking to indicate the command is waiting for approval
        }
        else root.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
    }

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id]
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
            })
        })
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true // Prevent race conditions
    }

    /**
     * Saves chat to a JSON list of message objects.
     * @param chatName name of the chat
     */
    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim()
        const saveContent = JSON.stringify(root.chatToJson())
        chatSaveFile.setText(saveContent)
        getSavedChats.running = true;
    }

    /**
     * Loads chat from a JSON list of message objects.
     * @param chatName name of the chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim()
            chatSaveFile.reload()
            const saveContent = chatSaveFile.text()
            // console.log(saveContent)
            const saveData = JSON.parse(saveContent)
            root.clearMessages()
            root.messageIDs = saveData.map((_, i) => {
                return i
            })
            // console.log(JSON.stringify(messageIDs))
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            getSavedChats.running = true;
        }
    }
}
