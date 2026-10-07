import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string source: ""
    readonly property int imgW: img.sourceSize.width
    readonly property int imgH: img.sourceSize.height
    property int current: 0
    property string tool: "brush"
    property real brushSize: 48
    property real zoom: 1
    property point pan: Qt.point(0, 0)
    property bool spaceHeld: false
    property bool showBoxes: true
    property var regions: []
    property int rev: 0
    property bool frozen: false
    property bool exporting: false
    readonly property bool locked: frozen || exporting
    readonly property int pendingSeeds: { rev; return regions.filter(r => r.seedState === "pending").length; }
    readonly property string seedError: {
        rev;
        const i = regions.findIndex(r => r.seedState === "error");
        return i < 0 ? "" : "Couldn't load the saved mask for Area " + (i + 1) + ": " + regions[i].seedError;
    }
    readonly property var colors: ["#ff5252", "#40c4ff", "#ffd740", "#69f0ae"]
    readonly property int minBox: 64
    signal changed()
    signal interacted()
    clip: true

    onImgWChanged: { repaintAll(); Qt.callLater(refitAll); }
    onImgHChanged: { repaintAll(); Qt.callLater(refitAll); }

    function refitAll() {
        if (!imgW || !imgH) return;
        for (const r of regions) if (r.box) r.box = fitBox(r.box);
        touch();
        seedLoader.next();
    }

    function layerAt(i) { return layers.itemAt(i); }
    function repaintAll() {
        for (let i = 0; i < regions.length; i++) {
            const l = layerAt(i);
            if (l) l.repaint(true);
        }
    }
    function touch() { rev++; }

    function addRegion(seed, box, prompt) {
        if (locked || regions.length >= colors.length) return -1;
        const r = { color: colors[regions.length], strokes: [], redo: [], box: box ? fitBox(box) : null, boxLocked: !!box,
                    seed: seed ?? "", prompt: prompt ?? "", seedData: null, seedBox: null,
                    seedState: seed ? "pending" : "none", seedError: "" };
        regions = regions.concat([r]);
        const i = regions.length - 1;
        if (r.seed) seedLoader.enqueue(r);
        touch();
        changed();
        return i;
    }

    function removeRegion(i) {
        if (locked || i < 0 || i >= regions.length) return;
        const next = regions.slice();
        next.splice(i, 1);
        next.forEach((r, k) => r.color = colors[k]);
        regions = next;
        current = Math.max(0, Math.min(current, regions.length - 1));
        repaintAll();
        touch();
        changed();
    }

    function updateAutoBox(i) {
        const r = regions[i];
        if (!r || r.boxLocked) return;
        const b = bbox(i);
        r.box = b ? autoBox(b) : null;
    }

    function undo() {
        if (locked) return;
        const r = regions[current];
        if (!r || !r.strokes.length) return;
        r.redo.push(r.strokes.pop());
        layerAt(current).repaint(true);
        updateAutoBox(current);
        touch();
        changed();
    }

    function redo() {
        if (locked) return;
        const r = regions[current];
        if (!r || !r.redo.length) return;
        r.strokes.push(r.redo.pop());
        layerAt(current).repaint(true);
        updateAutoBox(current);
        touch();
        changed();
    }

    function clearRegion() {
        if (locked) return;
        const r = regions[current];
        if (!r) return;
        r.strokes = [];
        r.redo = [];
        r.seed = "";
        r.seedData = null;
        r.seedBox = null;
        r.seedState = "none";
        r.seedError = "";
        r.box = null;
        r.boxLocked = false;
        layerAt(current).repaint(true);
        touch();
        changed();
    }

    function bbox(i) {
        const r = regions[i];
        if (!r) return null;
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const s of r.strokes) {
            if (s.erase) continue;
            const h = s.size / 2;
            for (const p of s.pts) {
                if (p[0] - h < x0) x0 = p[0] - h;
                if (p[1] - h < y0) y0 = p[1] - h;
                if (p[0] + h > x1) x1 = p[0] + h;
                if (p[1] + h > y1) y1 = p[1] + h;
            }
        }
        if (r.seedBox) {
            x0 = Math.min(x0, r.seedBox[0]); y0 = Math.min(y0, r.seedBox[1]);
            x1 = Math.max(x1, r.seedBox[2]); y1 = Math.max(y1, r.seedBox[3]);
        }
        return x1 < x0 ? null : [x0, y0, x1, y1];
    }

    function fitAxis(lo, hi, size) {
        const len = Math.min(size, Math.max(hi - lo, minBox));
        const start = Math.max(0, Math.min(size - len, (lo + hi) / 2 - len / 2));
        return [start, start + len];
    }

    function fitBox(b) {
        if (!imgW || !imgH) return b;
        const x = fitAxis(b[0], b[2], imgW), y = fitAxis(b[1], b[3], imgH);
        return [x[0], y[0], x[1], y[1]];
    }

    function autoBox(b) {
        const gx = (b[2] - b[0]) * 0.25, gy = (b[3] - b[1]) * 0.25;
        return fitBox([Math.max(0, b[0] - gx), Math.max(0, b[1] - gy), Math.min(imgW, b[2] + gx), Math.min(imgH, b[3] + gy)]);
    }

    function ensureRegion() {
        if (!regions.length) addRegion();
        current = Math.max(0, Math.min(current, regions.length - 1));
        return regions[current];
    }

    function addStroke(points, size, erase) {
        if (locked) return false;
        const r = ensureRegion();
        if (!r || !points || !points.length) return false;
        r.strokes.push({ pts: points, size: size, erase: !!erase });
        r.redo = [];
        layerAt(current).repaint(true);
        updateAutoBox(current);
        touch();
        changed();
        return true;
    }

    function exportMasks(cb) {
        exporter.start(cb);
    }

    function cancelExport() { exporter.finish(null); }
    function discardMasks(list) {
        if (list?.length) Quickshell.execDetached(["rm", "-f", "--"].concat(list.map(j => j.mask ?? j.path)));
    }
    Component.onDestruction: cancelExport()

    function stateJson() {
        return JSON.stringify({ imgW, imgH, current, tool, brushSize, pendingSeeds, seedError, exporting,
            regions: regions.map((r, i) => ({ strokes: r.strokes.length, box: r.box, boxLocked: r.boxLocked, bbox: bbox(i), seed: r.seed })) });
    }

    Image { id: img; source: root.source ? "file://" + root.source : ""; visible: false; asynchronous: false }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        enabled: !root.locked
        property string mode: ""
        property point startPos
        property point startPan
        property var gestureRegion: null
        property var gestureLayer: null
        property var moveOrigin

        function imgPoint(m) { return content.mapFromItem(mouseArea, m.x, m.y); }

        onPressed: m => {
            root.interacted();
            if (!root.imgW) return;
            if (m.button === Qt.MiddleButton || root.spaceHeld) {
                mode = "pan";
                startPos = Qt.point(m.x, m.y);
                startPan = root.pan;
                return;
            }
            const p = imgPoint(m);
            const r = root.ensureRegion();
            if (!r) return;
            gestureRegion = r;
            gestureLayer = root.layerAt(root.current);
            if ((m.modifiers & Qt.ShiftModifier) && r.box
                    && p.x >= r.box[0] && p.x <= r.box[2] && p.y >= r.box[1] && p.y <= r.box[3]) {
                mode = "box";
                moveOrigin = { p: p, box: r.box.slice() };
                return;
            }
            mode = "paint";
            const s = { pts: [[p.x, p.y]], size: root.brushSize, erase: root.tool === "eraser" };
            r.strokes.push(s);
            r.redo = [];
            const l = gestureLayer;
            l.live = s;
            l.drawn = 0;
            l.repaint(false);
        }

        onPositionChanged: m => {
            cursor.hx = m.x;
            cursor.hy = m.y;
            if (!pressed) return;
            if (mode === "pan") {
                root.pan = Qt.point(startPan.x + m.x - startPos.x, startPan.y + m.y - startPos.y);
            } else if (mode === "paint") {
                const l = gestureLayer;
                if (!l || !l.live) return;
                const p = imgPoint(m);
                const last = l.live.pts[l.live.pts.length - 1];
                if (Math.abs(p.x - last[0]) + Math.abs(p.y - last[1]) < 1) return;
                l.live.pts.push([p.x, p.y]);
                l.repaint(false);
            } else if (mode === "box") {
                const p = imgPoint(m);
                const r = gestureRegion;
                if (!r || !root.regions.includes(r)) return;
                const b = moveOrigin.box;
                const w = b[2] - b[0], h = b[3] - b[1];
                const nx = Math.max(0, Math.min(root.imgW - w, b[0] + p.x - moveOrigin.p.x));
                const ny = Math.max(0, Math.min(root.imgH - h, b[1] + p.y - moveOrigin.p.y));
                r.box = [nx, ny, nx + w, ny + h];
                r.boxLocked = true;
                root.touch();
            }
        }

        function finishGesture() {
            const r = gestureRegion, l = gestureLayer;
            if (mode === "paint" && l) {
                l.live = null;
                l.repaint(true);
                const i = root.regions.indexOf(r);
                if (i >= 0) root.updateAutoBox(i);
                root.touch();
                root.changed();
            } else if (mode === "box") {
                root.changed();
            }
            mode = "";
            gestureRegion = null;
            gestureLayer = null;
        }
        onReleased: finishGesture()
        onCanceled: finishGesture()

        onWheel: w => {
            if (!root.imgW) return;
            const old = content.scale;
            const z = Math.max(1, Math.min(8, root.zoom * Math.pow(1.15, w.angleDelta.y / 120)));
            if (z === root.zoom) return;
            const ix = (w.x - content.x) / old, iy = (w.y - content.y) / old;
            const s = content.fit * z;
            root.zoom = z;
            if (z === 1) {
                root.pan = Qt.point(0, 0);
            } else {
                root.pan = Qt.point(w.x - ix * s - (root.width - root.imgW * s) / 2,
                                    w.y - iy * s - (root.height - root.imgH * s) / 2);
            }
        }
    }

    Item {
        id: content
        width: root.imgW; height: root.imgH
        transformOrigin: Item.TopLeft
        readonly property real fit: root.imgW ? Math.min(root.width / root.imgW, root.height / root.imgH) * 0.96 : 1
        scale: fit * root.zoom
        x: (root.width - root.imgW * scale) / 2 + root.pan.x
        y: (root.height - root.imgH * scale) / 2 + root.pan.y

        Image { anchors.fill: parent; source: img.source; smooth: true; mipmap: true }

        Repeater {
            id: layers
            model: root.regions.length
            delegate: Item {
                id: lay
                required property int index
                readonly property var reg: root.regions[index] ?? null
                readonly property var box: root.rev >= 0 ? (root.regions[index]?.box ?? null) : null
                readonly property bool isCurrent: index === root.current
                property var live: null
                property int drawn: 0
                property bool full: true
                property bool dirty: false
                property alias canvas: canvas
                anchors.fill: parent

                function repaint(f) {
                    if (f) full = true;
                    dirty = true;
                    canvas.requestPaint();
                }

                Item {
                    anchors.fill: parent
                    opacity: 0.5
                    Canvas {
                        id: canvas
                        width: root.imgW; height: root.imgH
                        onWidthChanged: lay.full = true
                        onHeightChanged: lay.full = true

                        function seg(ctx, s, from, color) {
                            ctx.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
                            ctx.strokeStyle = color;
                            ctx.fillStyle = color;
                            ctx.lineWidth = s.size;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            const p0 = s.pts[0], pn = s.pts[s.pts.length - 1];
                            if (s.pts.length === 1 || (s.pts.length === 2 && p0[0] === pn[0] && p0[1] === pn[1])) {
                                ctx.beginPath();
                                ctx.arc(s.pts[0][0], s.pts[0][1], s.size / 2, 0, Math.PI * 2);
                                ctx.fill();
                                return;
                            }
                            ctx.beginPath();
                            ctx.moveTo(s.pts[from][0], s.pts[from][1]);
                            for (let k = from + 1; k < s.pts.length; k++) ctx.lineTo(s.pts[k][0], s.pts[k][1]);
                            ctx.stroke();
                        }

                        onPaint: {
                            const r = lay.reg;
                            if (!r || !root.imgW) { lay.dirty = false; return; }
                            const ctx = getContext("2d");
                            if (lay.full) {
                                ctx.globalCompositeOperation = "source-over";
                                ctx.clearRect(0, 0, width, height);
                                if (r.seedData) ctx.drawImage(r.seedData, 0, 0);
                                for (const s of r.strokes) seg(ctx, s, 0, r.color);
                                lay.full = false;
                                lay.drawn = lay.live ? lay.live.pts.length : 0;
                            } else if (lay.live) {
                                seg(ctx, lay.live, Math.max(0, lay.drawn - 1), r.color);
                                lay.drawn = lay.live.pts.length;
                            }
                            lay.dirty = false;
                        }
                    }
                }

                Rectangle {
                    id: boxRect
                    visible: root.showBoxes && lay.box !== null
                    x: lay.box ? lay.box[0] : 0
                    y: lay.box ? lay.box[1] : 0
                    width: lay.box ? lay.box[2] - lay.box[0] : 0
                    height: lay.box ? lay.box[3] - lay.box[1] : 0
                    readonly property color tint: lay.reg ? lay.reg.color : "transparent"
                    color: Qt.alpha(tint, lay.isCurrent ? 0.09 : 0.04)
                    radius: Math.min(8 / content.scale, width / 2, height / 2)
                    opacity: lay.isCurrent ? 1 : 0.6

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            id: outline
                            strokeColor: boxRect.tint
                            strokeWidth: (lay.isCurrent ? 2 : 1) / content.scale
                            fillColor: "transparent"
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [4, 3]
                            capStyle: ShapePath.FlatCap
                            readonly property real rr: Math.min(8 / content.scale, boxRect.width / 2, boxRect.height / 2)
                            startX: outline.rr; startY: 0
                            PathLine { x: boxRect.width - outline.rr; y: 0 }
                            PathArc { x: boxRect.width; y: outline.rr; radiusX: outline.rr; radiusY: outline.rr }
                            PathLine { x: boxRect.width; y: boxRect.height - outline.rr }
                            PathArc { x: boxRect.width - outline.rr; y: boxRect.height; radiusX: outline.rr; radiusY: outline.rr }
                            PathLine { x: outline.rr; y: boxRect.height }
                            PathArc { x: 0; y: boxRect.height - outline.rr; radiusX: outline.rr; radiusY: outline.rr }
                            PathLine { x: 0; y: outline.rr }
                            PathArc { x: outline.rr; y: 0; radiusX: outline.rr; radiusY: outline.rr }
                        }
                    }

                    Repeater {
                        model: lay.isCurrent && boxRect.visible ? 8 : 0
                        delegate: MouseArea {
                            id: handle
                            required property int index
                            readonly property var f: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]][index]
                            width: 14 / content.scale; height: width
                            x: f[0] * boxRect.width - width / 2
                            y: f[1] * boxRect.height - height / 2
                            hoverEnabled: true
                            enabled: !root.locked
                            cursorShape: (f[0] === 0.5 || f[1] === 0.5) ? (f[0] === 0.5 ? Qt.SizeVerCursor : Qt.SizeHorCursor)
                                : (f[0] === f[1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: boxRect.tint
                                border.width: 1 / content.scale
                                border.color: Appearance.colors.colOnLayer0
                            }

                            onPressed: root.interacted()
                            onPositionChanged: m => {
                                if (!pressed || !lay.reg) return;
                                const r = lay.reg;
                                const p = handle.mapToItem(content, m.x, m.y);
                                const b = r.box.slice();
                                const px = Math.max(0, Math.min(root.imgW, p.x));
                                const py = Math.max(0, Math.min(root.imgH, p.y));
                                const mw = Math.min(root.minBox, root.imgW), mh = Math.min(root.minBox, root.imgH);
                                if (f[0] === 0) b[0] = Math.min(px, b[2] - mw);
                                else if (f[0] === 1) b[2] = Math.max(px, b[0] + mw);
                                if (f[1] === 0) b[1] = Math.min(py, b[3] - mh);
                                else if (f[1] === 1) b[3] = Math.max(py, b[1] + mh);
                                r.box = [Math.max(0, b[0]), Math.max(0, b[1]), Math.min(root.imgW, b[2]), Math.min(root.imgH, b[3])];
                                r.boxLocked = true;
                                root.touch();
                            }
                            onReleased: root.changed()
                        }
                    }
                }
            }
        }
    }

    Canvas {
        id: scratch
        onAvailableChanged: if (available) seedLoader.next()
        width: Math.max(1, root.imgW); height: Math.max(1, root.imgH)
        opacity: 0
        z: -1
    }

    Canvas {
        id: exportCanvas
        width: Math.max(1, root.imgW); height: Math.max(1, root.imgH)
        property var pending: null
        onPaint: {
            if (!pending) return;
            getContext("2d").drawImage(pending, 0, 0);
            pending = null;
        }
        opacity: 0
        z: -1
    }

    QtObject {
        id: seedLoader
        property var queue: []
        property var active: null

        function enqueue(r) {
            queue.push(r);
            next();
        }

        function next() {
            if (active || !root.imgW || !root.imgH || !scratch.available) return;
            while (queue.length) {
                const r = queue.shift();
                if (!root.regions.includes(r) || r.seedState !== "pending") continue;
                active = r;
                watch.ticks = 0;
                scratch.loadImage("file://" + active.seed);
                return;
            }
        }

        function abandon(message) {
            if (active) {
                if (root.regions.includes(active) && active.seedState === "pending") {
                    active.seedState = "error"; active.seedError = message;
                    root.touch(); root.changed();
                }
                scratch.unloadImage("file://" + active.seed);
            }
            active = null;
            next();
        }

        property Timer watch: Timer {
            id: watch
            interval: 300
            repeat: true
            running: seedLoader.active !== null
            property int ticks: 0
            onTriggered: {
                if (scratch.isImageError("file://" + seedLoader.active.seed)) seedLoader.abandon("the file is unavailable");
                else if (++ticks > 20) seedLoader.abandon("loading timed out");
            }
        }
    }

    Connections {
        target: scratch
        function onImageLoaded() {
            const r = seedLoader.active;
            if (!r) return;
            const url = "file://" + r.seed;
            if (!scratch.isImageLoaded(url)) return;
            if (!root.regions.includes(r) || r.seedState !== "pending") { seedLoader.abandon(""); return; }
            try {
                const ctx = scratch.getContext("2d");
                ctx.globalCompositeOperation = "source-over";
                ctx.clearRect(0, 0, scratch.width, scratch.height);
                ctx.drawImage(url, 0, 0, root.imgW, root.imgH);
                const d = ctx.getImageData(0, 0, root.imgW, root.imgH);
                const px = d.data;
                const c = Qt.color(r.color);
                const cr = Math.round(c.r * 255), cg = Math.round(c.g * 255), cb = Math.round(c.b * 255);
                let x0 = root.imgW, y0 = root.imgH, x1 = -1, y1 = -1;
                for (let y = 0, k = 0; y < root.imgH; y++) {
                    for (let x = 0; x < root.imgW; x++, k += 4) {
                        if (px[k] > 127) {
                            px[k] = cr; px[k + 1] = cg; px[k + 2] = cb; px[k + 3] = 255;
                            if (x < x0) x0 = x;
                            if (x > x1) x1 = x;
                            if (y < y0) y0 = y;
                            if (y > y1) y1 = y;
                        } else {
                            px[k + 3] = 0;
                        }
                    }
                }
                if (x1 < 0) { seedLoader.abandon("the mask is empty"); return; }
                scratch.unloadImage(url);
                seedLoader.active = null;
                r.seedState = "loaded";
                const i = root.regions.indexOf(r);
                if (i >= 0 && x1 >= 0) {
                    r.seedData = d;
                    r.seedBox = [x0, y0, x1 + 1, y1 + 1];
                    root.layerAt(i).repaint(true);
                    root.updateAutoBox(i);
                    root.touch();
                    root.changed();
                }
                seedLoader.next();
            } catch (e) { seedLoader.abandon("the mask couldn't be decoded"); }
        }
    }

    Timer {
        id: exporter
        interval: 25
        property var cb: null
        property var jobs: []
        property var queue: []
        property var cur: null
        property real stamp: 0

        function start(callback) {
            if (root.exporting || root.pendingSeeds || root.seedError) { callback(null); return; }
            mouseArea.finishGesture();
            cb = callback;
            root.exporting = true;
            stamp = Date.now();
            jobs = [];
            queue = [];
            for (let i = 0; i < root.regions.length; i++) {
                const r = root.regions[i], b = root.bbox(i);
                if (b) queue.push({ index: i, box: (r.box ?? root.autoBox(b)).slice(), prompt: r.prompt });
            }
            exportDeadline.restart();
            restart();
        }

        onTriggered: {
            if (!cb) return;
            if (!root.imgW || !root.imgH) { finish(null); return; }
            for (let i = 0; i < root.regions.length; i++) {
                if (root.layerAt(i)?.dirty) { restart(); return; }
            }
            step();
        }

        function finish(res) {
            const f = cb;
            if (!f) return;
            cb = null;
            cur = null;
            exportCanvas.pending = null;
            stop(); exportDeadline.stop();
            if (!res) {
                writer.aborted = jobs.slice();
                writer.active = false;
                writer.running = false;
                root.discardMasks(jobs);
            }
            root.exporting = false;
            f(res);
        }

        function step() {
            if (!cb) return;
            try {
                while (queue.length) {
                    const entry = queue.shift();
                    const d = root.layerAt(entry.index).canvas.getContext("2d").getImageData(0, 0, root.imgW, root.imgH);
                    const px = d.data;
                    let any = false;
                    for (let k = 0; k < px.length; k += 4) {
                        const v = px[k + 3] > 127 ? 255 : 0;
                        if (v) any = true;
                        px[k] = px[k + 1] = px[k + 2] = v;
                        px[k + 3] = 255;
                    }
                    if (!any) continue;
                    exportCanvas.pending = d;
                    cur = entry;
                    exportCanvas.requestPaint();
                    return;
                }
                writer.run(jobs);
            } catch (e) { finish(null); }
        }

        function captured() {
            if (!cb || !cur) return;
            const entry = cur;
            cur = null;
            try {
                const url = exportCanvas.toDataURL("image/png"), comma = url.indexOf(",");
                if (comma < 0) { finish(null); return; }
                jobs.push({ b64: url.slice(comma + 1), path: MediaGen.regionsDir() + "/" + stamp + "-r" + (entry.index + 1) + ".png",
                            box: entry.box, prompt: entry.prompt, index: entry.index });
                step();
            } catch (e) { finish(null); }
        }
    }

    Timer { id: exportDeadline; interval: 15000; onTriggered: exporter.finish(null) }
    Connections {
        target: exportCanvas
        function onPainted() { exporter.captured(); }
    }

    // putImageData is a no-op on this Qt build (drawImage(ImageData) works), and Canvas.save() fails for every path on this Qt build ("QFile: No file name specified"), so the PNG goes out via toDataURL.
    Process {
        id: writer
        property var jobs: []
        property var aborted: []
        property int pos: 0
        property bool active: false
        property bool started: false
        stdinEnabled: true

        function run(list) {
            jobs = list; pos = 0; active = true; aborted = [];
            next();
        }

        function next() {
            if (!active) return;
            if (pos >= jobs.length) {
                active = false;
                exporter.finish(jobs.map(j => ({ mask: j.path, box: j.box, prompt: j.prompt, index: j.index })));
                return;
            }
            started = false;
            stdinEnabled = true;
            command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && base64 -d > \"$1\"", "sh", jobs[pos].path];
            running = true;
        }

        onRunningChanged: if (!running && !started && active) {
            Qt.callLater(() => { if (!running && !started && active) exporter.finish(null); });
        }
        onStarted: {
            started = true;
            if (!active) { running = false; return; }
            write(jobs[pos].b64);
            stdinEnabled = false;
        }
        onExited: (code, status) => {
            if (aborted.length) { root.discardMasks(aborted); aborted = []; }
            if (!active) return;
            if (code !== 0) { exporter.finish(null); return; }
            pos++;
            Qt.callLater(next);
        }
    }

    Rectangle {
        id: cursor
        property real hx: 0
        property real hy: 0
        width: root.brushSize * content.scale; height: width
        x: hx - width / 2; y: hy - height / 2
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Appearance.colors.colOnLayer0
        visible: mouseArea.containsMouse && root.imgW > 0 && mouseArea.mode !== "pan" && mouseArea.mode !== "box" && !root.spaceHeld
        enabled: false
    }
}
