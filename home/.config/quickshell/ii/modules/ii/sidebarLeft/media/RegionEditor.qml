import qs.services
import QtQuick

FocusScope {
    id: win
    property alias canvas: stage.canvas
    property var promptFocus: null
    onActiveFocusChanged: if (!activeFocus) canvas.spaceHeld = false

    property string initialState: ""
    readonly property string editSnapshot: { rev; return editState(); }
    readonly property bool hasEdits: editSnapshot !== initialState
    onEditSnapshotChanged: confirmCancel = false
    property bool confirmCancel: false
    readonly property int rev: canvas.rev
    readonly property var presetRegion: MediaGen.presets?.region
    readonly property real largeAreaPx: 2.5e6 * (presetRegion?.target_mp ?? 1.0)
    readonly property int nPainted: { rev; return canvas.regions.filter((r, i) => canvas.bbox(i)).length; }
    readonly property var perRegionS: {
        const img = MediaGen.presets?.estimates_s?.image;
        const v = img?.region ?? img?.edit;
        return typeof v === "object" && v !== null ? v[MediaGen.quality] : v;
    }
    readonly property bool invalidBox: { rev; return canvas.regions.some((r, i) => !!canvas.bbox(i) && !boxValid(i)); }
    property var lastApplied: null
    property bool applying: false
    property int applySerial: 0
    property bool closing: false
    property var pendingMasks: []

    function prompts() { return canvas.regions.map(r => r.prompt ?? ""); }
    function stateJson() { const s = JSON.parse(canvas.stateJson()); s.prompts = prompts(); return JSON.stringify(s); }
    function editState() { return JSON.stringify(canvas.regions.map(r => ({ seed: r.seed, prompt: r.prompt, strokes: r.strokes, box: r.boxLocked ? canvas.fitBox(r.box) : null }))); }
    function cancel() {
        if (hasEdits && !confirmCancel) { confirmCancel = true; return; }
        closing = true; applySerial++;
        canvas.cancelExport();
        canvas.discardMasks(pendingMasks); pendingMasks = [];
        applying = false;
        MediaGen.closeRegionEditor();
    }
    function boxValid(i) {
        const b = canvas.bbox(i), box = canvas.regions[i]?.box;
        return !b || !!box && Math.round(box[0]) <= b[0] && Math.round(box[1]) <= b[1] && Math.round(box[2]) >= b[2] && Math.round(box[3]) >= b[3];
    }
    function canApply() {
        rev;
        if (closing || applying || invalidBox || canvas.pendingSeeds || canvas.seedError || canvas.renderingMasks || MediaGen.busy || !MediaGen.connected || Ai.busy) return false;
        const painted = canvas.regions.filter((r, i) => canvas.bbox(i));
        return painted.length > 0 && painted.every(r => (r.prompt ?? "").trim().length);
    }
    function apply() {
        if (!canApply()) return;
        MediaGen.lastError = "";
        applying = true;
        const serial = ++applySerial;
        canvas.exportMasks((list) => {
            if (!win || closing || serial !== applySerial) { canvas.discardMasks(list); return; }
            if (!list) { applying = false; MediaGen.lastError = "Couldn't save the painted areas"; return; }
            const regions = list.map(m => ({ mask: m.mask, box: m.box.map(Math.round), prompt: (m.prompt ?? "").trim() }));
            if (!regions.length || regions.some(r => !r.prompt)) {
                canvas.discardMasks(list);
                applying = false; MediaGen.lastError = !regions.length ? "Paint an area and describe it" : "Give each painted area a prompt"; return;
            }
            pendingMasks = list;
            win.lastApplied = regions;
            MediaGen.submitRegions(regions, (ok) => {
                if (!win || closing || serial !== applySerial) return;
                applying = false;
                if (!ok) canvas.discardMasks(list);
                pendingMasks = [];
            });
        });
    }
    function handleKey(e, typing) {
        if (e.key === Qt.Key_Escape) { cancel(); return true; }
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { apply(); return true; }
        if (typing) return false;
        if (applying) return true;
        if (e.key === Qt.Key_BracketLeft) { canvas.brushSize = Math.max(4, canvas.brushSize - 8); return true; }
        if (e.key === Qt.Key_BracketRight) { canvas.brushSize = Math.min(400, canvas.brushSize + 8); return true; }
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { const i = e.key - Qt.Key_1; if (i < canvas.regions.length) canvas.current = i; return true; }
        if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) { if (e.modifiers & Qt.ShiftModifier) canvas.redo(); else canvas.undo(); return true; }
        if (e.key === Qt.Key_E && !(e.modifiers & Qt.ControlModifier)) { canvas.tool = canvas.tool === "brush" ? "eraser" : "brush"; return true; }
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) { canvas.spaceHeld = true; return true; }
        return false;
    }

    Component.onCompleted: {
        MediaGen.regionEditor = win;
        const seed = MediaGen.regionSeed;
        if (seed?.length) seed.forEach(r => canvas.addRegion(r.mask, r.box, r.prompt)); else canvas.addRegion();
        initialState = editState();
    }
    Component.onDestruction: {
        closing = true; applySerial++;
        canvas.cancelExport();
        canvas.discardMasks(pendingMasks); pendingMasks = [];
        if (MediaGen.regionEditor === win) MediaGen.regionEditor = null;
    }
    Connections { target: canvas; function onChanged() { win.confirmCancel = false; } function onInteracted() { win.forceActiveFocus(); } }

    RegionStage { id: stage; anchors.fill: parent; editor: win }
}
