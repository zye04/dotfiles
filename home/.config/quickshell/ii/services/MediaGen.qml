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
    property var state: ({ status: "idle", stages: [], beats: [] })
    readonly property bool busy: state.status === "running" || state.status === "starting"
    property bool connected: false
    property var items: []
    property var presets: null
    property bool agentLoaded: false
    property string lastError: ""

    // UI state
    property string kind: "image"
    property string srcPath: ""
    property string srcKind: ""
    property string task: "edit"
    property string prompt: ""
    property var beats: []
    property string shape: "16:9"
    property int lengthS: 5
    property string quality: "realistic"
    property real scale: 2.0
    property var finish: ({ upscale: true, cinematic24: true, grain: false })
    property var adv: ({ steps: null, cfg: null, seed: null, models: ({}), loras: ({}) })
    property string selectedId: ""
    property string regionPath: ""
    property var regionSeed: null
    property var regionEditor: null
    property bool tabVisible: false          // set by SidebarLeftContent: sidebar open and Media tab current
    property string dismissedJobId: ""

    function mode() {
        if (kind === "image") return srcPath === "" ? "t2i" : (task === "upscale" ? "upscale" : "edit");
        if (srcKind === "video") return "enhance";
        if (lengthS > 5) return "long";
        return srcPath === "" ? "t2v" : "i2v";
    }
    function apiMode() { const m = mode(); return m === "long" ? (srcPath === "" ? "t2v" : "i2v") : m; }
    function presetValue(key) {
        if (!presets) return null;
        if (kind === "image") return key === "steps" ? presets.image[quality].steps : presets.image.cfg;
        return key === "steps" ? presets.video[quality].steps : presets.video[quality].cfg_hi;
    }
    function itemForPath(path) { return items.find(i => i.path === path) ?? null; }
    // Our own videos: 16 fps as generated, 24 fps once Cinematic ran. Anything else is unknown.
    function itemFps(it) {
        const sp = it?.spec ?? {};
        if (sp.finish?.cinematic24) return 24;
        return sp.mode === "t2v" || sp.mode === "i2v" ? 16 : null;
    }
    function srcDuration() { return itemForPath(srcPath)?.duration_s ?? 5; }
    function costBeats() { return mode() === "enhance" ? Math.max(1, Math.ceil(srcDuration() / 5)) : lengthS / 5; }
    function qualityHint(q) {
        const e = presets?.estimates_s;
        if (!e) return "";
        if (kind === "video") return "~" + Math.max(1, Math.round(e.video_per_beat[q] / 60)) + " min / 5 s";
        return "~" + e.image[q] + " s";
    }
    // Resolution a generated video comes out at (mirrors the service's video_dims); null when unknown.
    function videoDims() {
        if (!presets) return null;
        if (srcKind === "video") { const it = itemForPath(srcPath); return it ? [it.w, it.h] : null; }
        const table = presets.video.res[presets.video[quality].res], it = srcPath !== "" ? itemForPath(srcPath) : null;
        if (it && it.w && it.h) {
            const bw = table["16:9"][0], bh = table["16:9"][1], a = it.w / it.h, h = Math.sqrt(bw * bh / a);
            const r16 = x => Math.max(16, Math.round(x / 16) * 16);
            return [r16(h * a), r16(h)];
        }
        return table[shape] ?? null;
    }
    function selectedItem() { return items.find(i => i.id === selectedId) ?? (items.length ? items[0] : null); }
    function estimateS() {
        if (!presets) return 0;
        const e = presets.estimates_s, m = mode();
        if (kind === "image") return m === "t2i" ? e.image[quality] : e.image[m];
        let beatsN = lengthS / 5, gen = e.video_per_beat[quality] * beatsN;
        if (m === "enhance") { beatsN = costBeats(); gen = 0; }
        let fin = 0;
        for (const k of ["upscale", "cinematic24", "grain"]) if (finish[k]) fin += e.finish_per_beat[k];
        return Math.round(gen + fin * beatsN);
    }
    function fmtDuration(s) {
        if (s < 60) return "~" + Math.max(1, Math.round(s)) + " s";
        if (s < 3600) return "~" + Math.round(s / 60) + " min";
        return "~" + (s / 3600).toFixed(1).replace(".0", "") + " h";
    }
    function canSubmit() {
        if (busy || !connected || Ai.busy) return false;
        const m = mode();
        if (m === "enhance") return finish.upscale || finish.cinematic24 || finish.grain;
        if (m === "upscale") return true;
        return prompt.trim().length > 0;
    }
    function buildSpec() {
        const m = apiMode();
        const s = { mode: m, prompt: prompt.trim(), shape: shape, quality: quality, finish: finish, advanced: adv };
        const ov = presets?.models ? adv.models ?? {} : {};
        const lo = (m === "t2v" || m === "i2v") ? adv.loras ?? {} : {};
        const a = Object.assign({}, adv); delete a.models; delete a.loras;
        if (Object.keys(ov).length) a.models = ov;
        if (Object.keys(lo).length) a.loras = lo;
        s.advanced = a;
        if (srcPath !== "") s.source = srcPath;
        if (m === "t2v" || m === "i2v") { s.length_s = lengthS; s.beats = beats.slice(0, lengthS / 5 - 1).map(b => ({ text: b.text, camera: b.camera || null })); }
        if (m === "upscale") s.scale = scale;
        return s;
    }
    function modelRoles() {
        if (!presets?.models) return [];
        const m = mode(), r = [];
        if (kind === "image") return m === "upscale" ? ["upscaler"] : ["image"];
        if (m !== "enhance") r.push("video");
        if (finish.upscale) r.push("upscaler");
        if (finish.cinematic24) r.push("interpolation");
        return r;
    }
    function modelKey(role) { return adv.models?.[role] ?? presets?.models?.[role]?.default ?? ""; }
    function setModel(role, key) {
        const o = Object.assign({}, adv.models ?? {});
        if (key === presets?.models?.[role]?.default) delete o[role]; else o[role] = key;
        adv = Object.assign({}, adv, { models: o });
    }
    function loraKeys() {
        const m = apiMode();
        if (kind !== "video" || (m !== "t2v" && m !== "i2v")) return [];
        return Object.keys(presets?.models?.video?.options?.[modelKey("video")]?.loras ?? {});
    }
    function loraDefault(key) { return presets?.video?.[quality]?.loras?.[key]; }
    function loraValue(key) { return adv.loras?.[key] ?? loraDefault(key) ?? 1; }
    function setLora(key, v) {
        const o = Object.assign({}, adv.loras ?? {}), r = Math.round(v * 20) / 20;
        if (r === loraDefault(key)) delete o[key]; else o[key] = r;
        adv = Object.assign({}, adv, { loras: o });
    }
    function setLength(s) {
        lengthS = s;
        const need = s / 5 - 1, b = beats.slice(0, need);
        while (b.length < need) b.push({ text: "", camera: "" });
        beats = b;
    }
    function setSource(path) {
        const ext = path.split(".").pop().toLowerCase();
        srcKind = ["mp4", "webm", "mkv", "mov"].includes(ext) ? "video" : "image";
        if (srcKind === "video") kind = "video";
        srcPath = path;
        if (srcKind === "video") {   // only offer steps that make sense for this source
            const it = itemForPath(path), fps = itemFps(it);
            finish = { upscale: it ? it.h < 1440 : true, cinematic24: fps !== null && fps < 24, grain: false };
        }
    }
    function clearSource() { srcPath = ""; srcKind = ""; }
    function reuse(item) {
        if (item.spec?.mode === "region") { quality = item.quality ?? quality; openRegionEditor(item.spec.source, item.spec.regions); return; }
        const sp = item.spec ?? {};
        prompt = sp.prompt ?? ""; quality = item.quality ?? quality;
        if (sp.shape) shape = sp.shape;
        kind = item.kind === "video" ? "video" : "image";
        if (sp.length_s) setLength(sp.length_s);
        if (sp.beats) beats = sp.beats.map(b => ({ text: b.text, camera: b.camera ?? "" }));
        adv = { steps: sp.advanced?.steps ?? null, cfg: sp.advanced?.cfg ?? null, seed: item.seed ?? null, models: {}, loras: {} };
        for (const [role, key] of Object.entries(sp.advanced?.models ?? {})) setModel(role, key);
        for (const [k, v] of Object.entries(sp.advanced?.loras ?? {})) setLora(k, v);
        if (sp.source) setSource(sp.source); else clearSource();
        task = sp.mode === "upscale" ? "upscale" : "edit";
        if (sp.scale) scale = sp.scale;
        if (sp.finish) finish = Object.assign({}, sp.finish);
    }
    function thumbUrl(id) { return base + "/thumb/" + id; }

    // ---- REST (serial queue, one curl at a time)
    property var _queue: []
    function _request(method, path, body, cb) { _queue.push({ method, path, body, cb }); _next(); }
    function _next() {
        if (rest.running || _queue.length === 0) return;
        const j = _queue[0];
        const args = ["curl", "-sS", "--max-time", "15", "-X", j.method, "-w", "\n%{http_code}"];
        if (j.body !== null) args.push("-H", "Content-Type: application/json", "--data-binary", JSON.stringify(j.body));
        args.push(base + j.path);
        rest.command = args; rest.running = true;
    }
    property Process rest: Process {
        stdout: StdioCollector { id: restOut }
        onExited: (code) => {
            const j = root._queue.shift();
            const txt = restOut.text, nl = txt.lastIndexOf("\n");
            const status = parseInt(txt.slice(nl + 1)) || 0, body = txt.slice(0, nl);
            let data = null; try { data = JSON.parse(body); } catch (e) {}
            if (j?.cb) j.cb(status, data);
            root._next();
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
        lastError = ""; dismissedJobId = "";
        _request("POST", "/jobs", buildSpec(), (st, d) => { if (st !== 202) { const e = d?.error; lastError = !e ? "Couldn't start the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e); } });
    }
    function stop() { _request("POST", "/stop", {}, null); }
    function dismissError() { dismissedJobId = state.job?.id ?? "recovered"; }
    function retry(finishOverride) {
        lastError = "";
        _request("POST", "/retry", finishOverride ? { finish: finishOverride } : {}, (st, d) => {
            if (st !== 202) { const e = d?.error; lastError = !e ? "Couldn't retry the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e); }
        });
    }
    function deleteItem(id) { _request("DELETE", "/items/" + id, null, (st) => refreshItems()); }
    function regionsDir() { return Quickshell.env("HOME") + "/.cache/local-suite/media/regions"; }
    function openRegionEditor(path, regions) { if (busy) return; lastError = ""; regionSeed = regions ?? null; regionPath = path; }
    function closeRegionEditor() { regionPath = ""; regionSeed = null; }
    function submitRegions(regions) {
        if (busy || !connected) return;
        lastError = ""; dismissedJobId = "";
        const a = Object.assign({}, adv); delete a.loras;
        if (!Object.keys(a.models ?? {}).length || !presets?.models) delete a.models;
        _request("POST", "/jobs", { mode: "region", source: regionPath, quality: quality, advanced: a, regions: regions }, (st, d) => {
            if (st === 202) { closeRegionEditor(); return; }
            const e = d?.error; lastError = !e ? "Couldn't start the job" : e === "busy" ? "A job is already running" : typeof e === "string" ? e : JSON.stringify(e);
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
                    if ((prev === "running" || prev === "starting") && root.state.status !== "running" && root.state.status !== "starting") root.refreshItems(root.state.status === "idle");
                } catch (e) {}
            }
        }
        onExited: { root.connected = false; root.state = ({ status: "idle", stages: [], beats: [] }); reconnect.start(); }
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
        onExited: (code) => { if (code === 0) root.setSource(out); else root.lastError = "Nothing to paste"; }
    }
    function pasteSource() {
        const out = Quickshell.env("HOME") + "/.cache/local-suite/media/paste-" + Date.now() + ".png";
        pasteProc.out = out;
        pasteProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && { wl-paste --type image/png > \"$1\" && [ -s \"$1\" ] || { rm -f \"$1\"; exit 1; }; }", "sh", out];
        pasteProc.running = true;
    }
    property Process pickProc: Process {
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) root.setSource(p); } }
    }
    function pickSource() {
        const filter = kind === "video" ? "Images and videos (*.png *.jpg *.jpeg *.webp *.mp4 *.webm *.mkv *.mov)" : "Images (*.png *.jpg *.jpeg *.webp)";
        pickProc.command = ["kdialog", "--getopenfilename", Quickshell.env("HOME") + "/agent", filter];
        pickProc.running = true;
    }

    Component.onCompleted: { refreshItems(); refreshPresets(); }

    IpcHandler {
        target: "media"
        function state(): string {
            return JSON.stringify({ server: root.state, connected: root.connected, kind: root.kind, mode: root.mode(), srcPath: root.srcPath,
                                    prompt: root.prompt, lengthS: root.lengthS, quality: root.quality, selectedId: root.selectedId, regionPath: root.regionPath,
                                    items: root.items.length, estimate: root.fmtDuration(root.estimateS()), busy: root.busy, tabVisible: root.tabVisible, models: root.adv.models, loras: root.adv.loras });
        }
        function submit(specJson: string): void { root._request("POST", "/jobs", JSON.parse(specJson), null); }
        function stop(): void { root.stop(); }
        function select(id: string): void { root.selectedId = id; }
        function openRegionEditor(path: string): void { root.openRegionEditor(path, null); }
        function closeRegionEditor(): void { root.closeRegionEditor(); }
        function regionState(): string { return root.regionEditor ? root.regionEditor.stateJson() : "{}"; }
        function setKind(k: string): void { root.kind = k; root.clearSource(); }
        function setSource(path: string): void { root.setSource(path); }
        function setPrompt(text: string): void { root.prompt = text; }
        function setLength(s: int): void { root.setLength(s); }
        function setModel(role: string, key: string): void { root.setModel(role, key); }
        function setLora(key: string, value: real): void { root.setLora(key, value); }
    }
}
