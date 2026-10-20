pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

// local-suite: client for the media service (tools/media, 127.0.0.1:8190) plus the Media tab's UI state.
Singleton {
    id: root
    readonly property string base: "http://127.0.0.1:8190"

    // server state
    property var state: ({ status: "idle", stages: [] })
    readonly property bool busy: state.status === "running" || state.status === "starting"
    property bool connected: false
    property var items: []
    property var presets: null
    property bool agentLoaded: false
    property string lastError: ""

    // UI state
    property string srcPath: ""
    property var refs: []
    property string task: "edit"
    property string prompt: ""
    property string shape: "16:9"
    property string quality: "realistic"
    property real scale: 2.0
    property var adv: ({ steps: null, cfg: null, seed: null, models: ({}), loras: ({}) })
    property string selectedId: ""
    property string regionPath: ""
    property var regionSeed: null
    property var regionEditor: null
    property bool tabVisible: false          // set by SidebarLeftContent: sidebar open and Media tab current
    property string dismissedJobId: ""
    property string draftNotice: ""          // set when the agent filled the form (media_fill); cleared on prompt edit or submit
    property string draftAppliedId: ""
    property var pendingDraft: null          // a fresh draft waits here while a job runs or the region editor is open
    property bool _applying: false
    property bool _stateSeen: false
    onPromptChanged: { draftNotice = ""; if (!_applying && pendingDraft) { draftAppliedId = pendingDraft.id; pendingDraft = null; } }
    onBusyChanged: applyPendingDraft()
    onRegionPathChanged: applyPendingDraft()

    function mode() { return srcPath === "" ? "t2i" : (task === "upscale" ? "upscale" : "edit"); }
    function presetValue(key) {
        if (!presets) return null;
        return key === "steps" ? presets.image[quality].steps : presets.image.cfg;
    }
    function itemForPath(path) { return items.find(i => i.path === path) ?? null; }
    function qualityHint(q) {
        const e = presets?.estimates_s;
        return e ? "~" + e.image[q] + " s" : "";
    }
    function selectedItem() { return items.find(i => i.id === selectedId) ?? (items.length ? items[0] : null); }
    function estimateS() {
        if (!presets) return 0;
        const e = presets.estimates_s, m = mode();
        return m === "t2i" ? e.image[quality] : e.image[m];
    }
    function fmtDuration(s) {
        if (s < 60) return "~" + Math.max(1, Math.round(s)) + " s";
        if (s < 3600) return "~" + Math.round(s / 60) + " min";
        return "~" + (s / 3600).toFixed(1).replace(".0", "") + " h";
    }
    function canSubmit() {
        if (busy || !connected || Ai.busy) return false;
        return mode() === "upscale" || prompt.trim().length > 0;
    }
    function buildSpec() {
        const m = mode();
        const s = { mode: m, prompt: prompt.trim(), shape: shape, quality: quality, advanced: adv };
        const ov = presets?.models ? adv.models ?? {} : {};
        const lo = loraOverrides(m);
        const a = Object.assign({}, adv); delete a.models; delete a.loras;
        if (Object.keys(ov).length) a.models = ov;
        if (Object.keys(lo).length) a.loras = lo;
        s.advanced = a;
        if (srcPath !== "") s.source = srcPath;
        if (m === "edit" && refs.length) s.refs = refs;
        if (m === "upscale") s.scale = scale;
        return s;
    }
    function modelRoles() {
        if (!presets?.models) return [];
        return regionPath === "" && mode() === "upscale" ? ["upscaler"] : ["image"];
    }
    function modelKey(role) { return adv.models?.[role] ?? presets?.models?.[role]?.default ?? ""; }
    function setModel(role, key) {
        const o = Object.assign({}, adv.models ?? {});
        if (key === presets?.models?.[role]?.default) delete o[role]; else o[role] = key;
        adv = Object.assign({}, adv, { models: o });
    }
    function loraOverrides(m) {
        const out = {}, keys = loraKeys(m);
        for (const [k, v] of Object.entries(adv.loras ?? {})) if (keys.includes(k)) out[k] = v;
        return out;
    }
    function loraMeta(key) {
        return presets?.models?.image?.options?.[modelKey("image")]?.loras?.[key];
    }
    function loraKeys(m = regionEditor ? "region" : mode()) {
        if (!["t2i", "edit", "region"].includes(m)) return [];
        const meta = presets?.models?.image?.options?.[modelKey("image")]?.loras ?? {};
        return Object.keys(meta).filter(k => !meta[k].modes || meta[k].modes.includes(m));
    }
    function loraDefault(key) { return loraMeta(key)?.default_strength; }
    function loraValue(key) { return adv.loras?.[key] ?? loraDefault(key) ?? 1; }
    function setLora(key, v) {
        const o = Object.assign({}, adv.loras ?? {}), r = Math.round(v * 20) / 20;
        if (r === loraDefault(key)) delete o[key]; else o[key] = r;
        adv = Object.assign({}, adv, { loras: o });
    }
    function setSource(path) { srcPath = path; refs = []; }
    function clearSource() { srcPath = ""; refs = []; }
    // Removing photo 1 promotes photo 2, so the remaining photos keep their order.
    function removeImage(i) {
        if (i > 0) { refs = refs.filter((_, j) => j !== i - 1); return; }
        if (!refs.length) { clearSource(); return; }
        const rest = refs.slice(1); setSource(refs[0]); refs = rest;
    }
    // User-added images: the first becomes the source, later ones become references.
    function addImage(path) {
        if (path === srcPath || refs.includes(path)) return;
        if (srcPath !== "") {
            if (refs.length < 3) refs = refs.concat([path]); else lastError = "Up to 3 reference images";
        } else setSource(path);
    }
    function reuse(item) {
        const sp = item.spec ?? {};
        prompt = sp.prompt ?? ""; quality = item.quality ?? quality;
        if (sp.shape) shape = sp.shape;
        adv = { steps: sp.advanced?.steps ?? null, cfg: sp.advanced?.cfg ?? null, seed: item.seed ?? null, models: {}, loras: {} };
        for (const [role, key] of Object.entries(sp.advanced?.models ?? {})) setModel(role, key);
        for (const [k, v] of Object.entries(sp.advanced?.loras ?? {})) setLora(k, v);
        if (sp.source) setSource(sp.source); else clearSource();
        refs = (sp.refs ?? []).slice();
        if (sp.mode === "region") { openRegionEditor(sp.source, sp.regions); return; }
        task = sp.mode === "upscale" ? "upscale" : "edit";
        if (sp.scale) scale = sp.scale;
    }
    function considerDraft() {
        const d = state.draft;
        if (!_stateSeen) { _stateSeen = true; draftAppliedId = d?.id ?? ""; return; }
        pendingDraft = d && d.id !== draftAppliedId && Date.now() / 1000 - d.at < 600 ? d : null;
        applyPendingDraft();
    }
    function applyPendingDraft() {
        const d = pendingDraft;
        if (!d || busy || regionPath !== "") return;
        pendingDraft = null;
        if (Date.now() / 1000 - d.at >= 600) return;
        draftAppliedId = d.id;
        if (d.prompt != null) { _applying = true; prompt = d.prompt; _applying = false; }
        if (d.quality != null && presets?.image?.[d.quality]) quality = d.quality;
        if (d.shape != null) shape = d.shape;
        if (d.model != null && presets?.models?.image?.options?.[d.model]) setModel("image", d.model);
        for (const [k, v] of Object.entries(d.loras ?? {})) setLora(k, v);
        if (d.seed != null) adv = Object.assign({}, adv, { seed: d.seed });
        if (d.mode === "t2i") { if (d.source == null) clearSource(); }
        else if (d.mode === "edit" || d.mode === "upscale") { if (d.source != null) setSource(d.source); task = d.mode; }
        draftNotice = "Filled by the agent · " + Qt.formatTime(new Date(d.at * 1000), "HH:mm");
    }
    function thumbUrl(id) { return base + "/thumb/" + id; }

    // ---- REST (serial queue, one curl at a time)
    property var _queue: []
    function _request(method, path, body, cb) { _queue.push({ method, path, body, cb }); _next(); }
    function _next() {
        if (rest.running || rest.job !== null || _queue.length === 0) return;
        const j = _queue[0];
        const args = ["curl", "-sS", "--max-time", "15", "-X", j.method, "-w", "\n%{http_code}"];
        if (j.body !== null) args.push("-H", "Content-Type: application/json", "--data-binary", JSON.stringify(j.body));
        args.push(base + j.path);
        rest.job = j; rest.started = false;
        rest.command = args; rest.running = true;
    }
    property Process rest: Process {
        property var job: null
        property bool started: false
        function complete(status, data) {
            const j = job;
            if (!j) return;
            job = null;
            root._queue.shift();
            if (j.cb) j.cb(status, data);
            Qt.callLater(root._next);
        }
        onStarted: started = true
        onRunningChanged: if (!running && !started && job) {
            const j = job;
            Qt.callLater(() => { if (!running && !started && job === j) complete(0, null); });
        }
        stdout: StdioCollector { id: restOut }
        onExited: (code) => {
            const txt = restOut.text, nl = txt.lastIndexOf("\n");
            const status = parseInt(txt.slice(nl + 1)) || 0, body = txt.slice(0, nl);
            let data = null; try { data = JSON.parse(body); } catch (e) {}
            complete(status, data);
        }
    }
    function refreshItems(selectNewest) {
        _request("GET", "/items?limit=60", null, (st, d) => {
            if (st !== 200) return;
            items = d;
            if (selectNewest && items.length) selectedId = items[0].id;
            else if (!items.find(i => i.id === selectedId)) selectedId = items.length ? items[0].id : "";
        });
    }
    function refreshPresets() { _request("GET", "/presets", null, (st, d) => { if (st === 200) presets = d; }); }
    function submit() {
        if (!canSubmit()) return;
        lastError = ""; dismissedJobId = ""; draftNotice = "";
        _request("POST", "/jobs", buildSpec(), (st, d) => { if (st !== 202) { const e = d?.error; lastError = !e ? "Couldn't start the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e); } });
    }
    function stop() { _request("POST", "/stop", {}, null); }
    function dismissError() { dismissedJobId = state.job?.id ?? "recovered"; }
    function canRetry() { return !busy && connected && !Ai.busy && state.status === "error" && !!state.error?.retryable; }
    function retry() {
        if (!canRetry()) return;
        lastError = ""; dismissedJobId = "";
        _request("POST", "/retry", {}, (st, d) => {
            if (st !== 202) { const e = d?.error; lastError = !e ? "Couldn't retry the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e); }
        });
    }
    function deleteItem(id) { _request("DELETE", "/items/" + id, null, (st) => refreshItems()); }
    function regionsDir() { return Quickshell.env("HOME") + "/.cache/local-suite/media/regions"; }
    function openRegionEditor(path, regions) { if (busy) return; lastError = ""; regionSeed = regions ?? null; regionPath = path; }
    function closeRegionEditor() { regionPath = ""; regionSeed = null; }
    function submitRegions(regions, cb) {
        if (busy || !connected) {
            lastError = busy ? "A job is already running" : "The media service is disconnected";
            if (cb) cb(false);
            return;
        }
        lastError = ""; dismissedJobId = "";
        const a = Object.assign({}, adv);
        const lo = loraOverrides("region");
        if (Object.keys(lo).length) a.loras = lo; else delete a.loras;
        if (!Object.keys(a.models ?? {}).length || !presets?.models) delete a.models;
        const editor = regionEditor, path = regionPath;
        const body = { mode: "region", source: regionPath, quality: quality, advanced: a, regions: regions };
        if (refs.length && regionPath === srcPath) body.refs = refs;
        _request("POST", "/jobs", body, (st, d) => {
            if (st === 202) { if (cb) cb(true); if (regionEditor === editor && regionPath === path) closeRegionEditor(); return; }
            const e = d?.error; lastError = !e ? "Couldn't start the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e);
            if (cb) cb(false);
        });
    }

    // ---- SSE
    property Process stream: Process {
        command: ["curl", "-sN", "--max-time", "0", root.base + "/events"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (!line.startsWith("data:")) return;
                try {
                    const prev = root.state.status;
                    root.state = JSON.parse(line.slice(5));
                    root.connected = true;
                    root.considerDraft();
                    if ((prev === "running" || prev === "starting") && root.state.status !== "running" && root.state.status !== "starting") root.refreshItems(root.state.status === "idle");
                } catch (e) {}
            }
        }
        onExited: { root.connected = false; root.state = ({ status: "idle", stages: [] }); reconnect.start(); }
    }
    Timer { id: reconnect; interval: 3000; onTriggered: { root.stream.running = true; root.refreshItems(); root.refreshPresets(); } }

    // ---- agent model loaded? (llama-swap)
    property Process runningProc: Process {
        command: ["curl", "-sS", "--max-time", "3", "http://127.0.0.1:8080/running"]
        stdout: StdioCollector { onStreamFinished: { try { root.agentLoaded = JSON.parse(text).running.some(m => m.model.startsWith("qwen")); } catch (e) { root.agentLoaded = false; } } }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.runningProc.running = true }

    // ---- sources: clipboard paste and file picker
    property Process pasteProc: Process {
        property string out: ""
        onExited: (code) => { if (code === 0) root.addImage(out); else root.lastError = "Nothing to paste"; }
    }
    function pasteSource() {
        const out = Quickshell.env("HOME") + "/.cache/local-suite/media/paste-" + Date.now() + ".png";
        pasteProc.out = out;
        pasteProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && { wl-paste --type image/png > \"$1\" && [ -s \"$1\" ] || { rm -f \"$1\"; exit 1; }; }", "sh", out];
        pasteProc.running = true;
    }
    property Process pickProc: Process {
        stdout: StdioCollector { onStreamFinished: { for (const p of text.split("\n").map(l => l.trim()).filter(l => l)) root.addImage(p); } }
    }
    function pickSource() {
        pickProc.command = ["kdialog", "--getopenfilename", "--multiple", "--separate-output", Quickshell.env("HOME") + "/agent", "Images (*.png *.jpg *.jpeg *.webp)"];
        pickProc.running = true;
    }

    Component.onCompleted: { refreshItems(); refreshPresets(); }

    IpcHandler {
        target: "media"
        function state(): string {
            return JSON.stringify({ server: root.state, connected: root.connected, mode: root.mode(), srcPath: root.srcPath, refs: root.refs,
                                    prompt: root.prompt, quality: root.quality, shape: root.shape, draftNotice: root.draftNotice, draftAppliedId: root.draftAppliedId, selectedId: root.selectedId, regionPath: root.regionPath,
                                    items: root.items.length, estimate: root.fmtDuration(root.estimateS()), busy: root.busy, tabVisible: root.tabVisible, models: root.adv.models, loras: root.adv.loras });
        }
        function submit(specJson: string): void { root._request("POST", "/jobs", JSON.parse(specJson), null); }
        function stop(): void { root.stop(); }
        function select(id: string): void { root.selectedId = id; }
        function openRegionEditor(path: string): void { root.openRegionEditor(path, null); }
        function closeRegionEditor(): void { root.closeRegionEditor(); }
        function regionState(): string { return root.regionEditor ? root.regionEditor.stateJson() : "{}"; }
        function setSource(path: string): void { root.setSource(path); }
        function addImage(path: string): void { root.addImage(path); }
        function setPrompt(text: string): void { root.prompt = text; }
        function setModel(role: string, key: string): void { root.setModel(role, key); }
        function setLora(key: string, value: real): void { root.setLora(key, value); }
    }
}
