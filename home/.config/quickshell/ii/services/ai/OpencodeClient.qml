import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property string serverUrl: Config.options?.ai?.agentServerUrl ?? "http://127.0.0.1:4096"
    property string directory: Config.options?.ai?.agentDirectory ?? "/home/zye/agent"
    property string sessionID: ""
    property bool connected: false
    property bool interrupted: false
    property int retryDelay: 1000
    property var jobs: []
    property var activeJob: null
    property string responseText: ""
    property var pendingArgs: []
    readonly property string bodyPath: "/home/zye/.config/local-suite/sidebar-request.json"

    signal eventReceived(var payload)
    signal reconnected()
    signal disconnected()

    function url(path) { return serverUrl.replace(/\/$/, "") + path; }
    function directoryQuery() { return "?directory=" + encodeURIComponent(directory); }
    function sessionPath(suffix) { return `/session/${encodeURIComponent(sessionID)}${suffix}${directoryQuery()}`; }

    function request(method, path, body, callback, imagePath) {
        root.jobs = [...root.jobs, { method, path, body, callback, imagePath }];
        root.nextRequest();
    }

    function nextRequest() {
        if (root.activeJob || root.jobs.length === 0) return;
        root.activeJob = root.jobs[0];
        root.jobs = root.jobs.slice(1);
        root.responseText = "";
        const job = root.activeJob;
        const args = ["curl", "-fsS", "--max-time", "20", "-K", "/home/zye/.config/local-suite/curlrc", "-X", job.method];
        if (job.body !== null && job.body !== undefined) {
            bodyFile.path = Qt.resolvedUrl(root.bodyPath);
            bodyFile.setText(JSON.stringify(job.body));
            args.push("-H", "Content-Type: application/json", "--data-binary", "@" + root.bodyPath);
        }
        args.push(root.url(job.path));
        root.pendingArgs = args;
        sendDelay.restart();
    }

    property Timer sendDelay: Timer {
        interval: 60
        onTriggered: {
            const job = root.activeJob;
            if (!job) return;
            if (!job.imagePath) {
                rest.command = root.pendingArgs;
                rest.running = true;
                return;
            }
            encoder.exec(["python3", "-c", `import base64, json, mimetypes, os, sys
body_path, image_path = sys.argv[1:]
with open(body_path) as f:
    body = json.load(f)
with open(image_path, 'rb') as f:
    content = base64.b64encode(f.read()).decode()
for part in body['parts']:
    if part['type'] == 'file':
        part['mime'] = mimetypes.guess_type(image_path)[0] or 'image/png'
        part['filename'] = os.path.basename(image_path)
        part['url'] = 'data:' + part['mime'] + ';base64,' + content
with open(body_path, 'w') as f:
    json.dump(body, f)`, root.bodyPath, job.imagePath]);
        }
    }

    function createSession(callback) {
        const path = "/session?directory=" + encodeURIComponent(directory.replace(/^~/, "/home/zye"));
        request("POST", path, { title: "Sidebar" }, (data, ok) => {
            if (ok && data?.id) root.sessionID = data.id;
            if (callback) callback(data, ok);
        });
    }

    function prompt(text, modelId, imagePath, agent, callback) {
        const parts = [{ type: "text", text }];
        if (imagePath) parts.push({ type: "file", mime: "image/png", url: "" });
        const body = { parts, model: { providerID: "local", modelID: modelId } };
        if (agent) body.agent = agent;
        request("POST", sessionPath("/prompt_async"), body, callback, imagePath);
    }

    function abort() {
        if (abortProc.running) return;
        abortProc.command = ["curl", "-fsS", "--max-time", "10", "-K", "/home/zye/.config/local-suite/curlrc", "-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", root.url(sessionPath("/abort"))];
        abortProc.running = true;
    }
    function replyPermission(id, reply, callback) {
        request("POST", `/permission/${encodeURIComponent(id)}/reply?directory=${encodeURIComponent(directory.replace(/^~/, "/home/zye"))}`, { reply }, callback);
    }
    function replyQuestion(id, answers, callback) { request("POST", `/question/${encodeURIComponent(id)}/reply${directoryQuery()}`, { answers }, callback); }
    function rejectQuestion(id, callback) { request("POST", `/question/${encodeURIComponent(id)}/reject${directoryQuery()}`, {}, callback); }
    function revert(messageID, callback) { request("POST", sessionPath("/revert"), { messageID }, callback); }
    function unrevert(callback) { request("POST", sessionPath("/unrevert"), {}, callback); }
    function summarize(modelID, callback) { request("POST", sessionPath("/summarize"), { providerID: "local", modelID }, callback); }
    function listSessions(callback) { request("GET", "/experimental/session?roots=true&limit=10000", null, callback); }
    function loadSession(id, callback) {
        request("GET", `/session/${encodeURIComponent(id)}`, null, (session, ok) => {
            if (!ok || !session?.directory) { if (callback) callback(null, false); return; }
            root.sessionID = id;
            root.directory = session.directory;
            request("GET", sessionPath("/message"), null, callback);
        });
    }
    function messages(callback) { request("GET", sessionPath("/message"), null, callback); }
    function todos(callback) { request("GET", sessionPath("/todo"), null, callback); }
    function pendingPermissions(callback) { request("GET", "/permission" + directoryQuery(), null, callback); }
    function pendingQuestions(callback) { request("GET", "/question" + directoryQuery(), null, callback); }
    function savedPermissions(callback) { request("GET", "/api/permission/saved", null, callback); }

    property FileView bodyFile: FileView { blockWrites: true }

    property Process encoder: Process {
        onExited: (code, status) => {
            if (code !== 0) {
                const job = root.activeJob;
                root.activeJob = null;
                if (job?.callback) job.callback(null, false);
                root.nextRequest();
                return;
            }
            rest.command = root.pendingArgs;
            rest.running = true;
        }
    }

    property Process rest: Process {
        stdout: StdioCollector { onStreamFinished: root.responseText = text }
        onExited: (code, status) => Qt.callLater(() => {
            const job = root.activeJob;
            let data = null;
            try { data = root.responseText ? JSON.parse(root.responseText) : null; } catch (e) {}
            root.activeJob = null;
            if (job?.callback) job.callback(data, code === 0);
            root.nextRequest();
        })
    }

    property Process abortProc: Process {}

    property Process stream: Process {
        command: ["curl", "-sN", "-K", "/home/zye/.config/local-suite/curlrc", root.url("/global/event")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const eventLine = line.trim();
                if (!eventLine.startsWith("data:")) return;
                if (!root.connected) {
                    root.connected = true;
                    root.retryDelay = 1000;
                    if (root.interrupted) root.reconnected();
                    root.interrupted = false;
                }
                try {
                    const item = JSON.parse(eventLine.substring(5).trim());
                    root.eventReceived(item.payload);
                } catch (e) { console.warn("[OpencodeClient] invalid event JSON"); }
            }
        }
        onExited: {
            const wasConnected = root.connected;
            root.interrupted = root.interrupted || wasConnected;
            root.connected = false;
            if (wasConnected) root.disconnected();
            reconnect.interval = root.retryDelay;
            root.retryDelay = Math.min(30000, root.retryDelay * 2);
            reconnect.restart();
        }
    }

    property Timer reconnect: Timer {
        onTriggered: root.stream.running = true
    }
}
