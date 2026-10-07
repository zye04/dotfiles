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
    property var adv: ({ steps: null, cfg: null, seed: null })
    property string selectedId: ""

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
    function selectedItem() { return items.find(i => i.id === selectedId) ?? (items.length ? items[0] : null); }
    function estimateS() {
        if (!presets) return 0;
        const e = presets.estimates_s, m = mode();
        if (kind === "image") return m === "t2i" ? e.image[quality] : e.image[m];
        let beatsN = lengthS / 5, gen = e.video_per_beat[quality] * beatsN;
        if (m === "enhance") { const it = items.find(i => i.path === srcPath); beatsN = Math.max(1, Math.ceil((it?.duration_s ?? 5) / 5)); gen = 0; }
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
        if (busy || !connected) return false;
        const m = mode();
        if (m === "enhance") return finish.upscale || finish.cinematic24 || finish.grain;
        if (m === "upscale") return true;
        return prompt.trim().length > 0;
    }
    function buildSpec() {
        const m = apiMode();
        const s = { mode: m, prompt: prompt.trim(), shape: shape, quality: quality, finish: finish, advanced: adv };
        if (srcPath !== "") s.source = srcPath;
        if (m === "t2v" || m === "i2v") { s.length_s = lengthS; s.beats = beats.slice(0, lengthS / 5 - 1).map(b => ({ text: b.text, camera: b.camera || null })); }
        if (m === "upscale") s.scale = scale;
        return s;
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
    }
    function clearSource() { srcPath = ""; srcKind = ""; }
    function reuse(item) {
        const sp = item.spec ?? {};
        prompt = sp.prompt ?? ""; quality = item.quality ?? quality;
        if (sp.shape) shape = sp.shape;
        kind = item.kind === "video" ? "video" : "image";
        if (sp.length_s) setLength(sp.length_s);
        if (sp.beats) beats = sp.beats.map(b => ({ text: b.text, camera: b.camera ?? "" }));
        adv = { steps: sp.advanced?.steps ?? null, cfg: sp.advanced?.cfg ?? null, seed: item.seed ?? null };
        if (sp.source) setSource(sp.source); else clearSource();
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
    function refreshItems() { _request("GET", "/items?limit=60", null, (st, d) => { if (st === 200) { items = d; if (!items.find(i => i.id === selectedId)) selectedId = items.length ? items[0].id : ""; } }); }
    function refreshPresets() { _request("GET", "/presets", null, (st, d) => { if (st === 200) presets = d; }); }
    function submit() {
        if (!canSubmit()) return;
        lastError = "";
        _request("POST", "/jobs", buildSpec(), (st, d) => { if (st !== 202) lastError = d?.error ?? "Couldn't start the job"; });
    }
    function stop() { _request("POST", "/stop", {}, null); }
    function retry() { _request("POST", "/retry", {}, null); }
    function deleteItem(id) { _request("DELETE", "/items/" + id, null, (st) => refreshItems()); }

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
                    if ((prev === "running" || prev === "starting") && root.state.status === "idle") root.refreshItems();
                } catch (e) {}
            }
        }
        onExited: { root.connected = false; reconnect.start(); }
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
        onExited: (code) => { if (code === 0) root.setSource(out); }
    }
    function pasteSource() {
        const out = Quickshell.env("HOME") + "/.cache/local-suite/media/paste-" + Date.now() + ".png";
        pasteProc.out = out;
        pasteProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && wl-paste --type image/png > \"$1\" && [ -s \"$1\" ]", "sh", out];
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
                                    prompt: root.prompt, lengthS: root.lengthS, quality: root.quality, selectedId: root.selectedId,
                                    items: root.items.length, estimate: root.fmtDuration(root.estimateS()), busy: root.busy });
        }
        function submit(specJson: string): void { root._request("POST", "/jobs", JSON.parse(specJson), null); }
        function stop(): void { root.stop(); }
        function select(id: string): void { root.selectedId = id; }
        function setKind(k: string): void { root.kind = k; root.clearSource(); }
        function setSource(path: string): void { root.setSource(path); }
        function setPrompt(text: string): void { root.prompt = text; }
        function setLength(s: int): void { root.setLength(s); }
    }
}
