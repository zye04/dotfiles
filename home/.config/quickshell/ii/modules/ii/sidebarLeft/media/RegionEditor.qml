import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "MediaCopy.js" as C

PanelWindow {
    id: win
    WlrLayershell.namespace: "quickshell:mediaRegion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property bool confirmCancel: false
    readonly property int rev: canvas.rev
    readonly property var presetRegion: MediaGen.presets?.region
    readonly property real largeAreaPx: 2.5e6 * (presetRegion?.target_mp ?? 1.0)
    readonly property int nPainted: { rev; return canvas.regions.filter((r, i) => canvas.bbox(i)).length; }
    readonly property var perRegionS: {
        const v = MediaGen.presets?.estimates_s?.image?.region;
        return typeof v === "object" && v !== null ? v[MediaGen.quality] : v;
    }
    property var lastApplied: null

    function prompts() { return canvas.regions.map(r => r.prompt ?? ""); }
    function stateJson() { const s = JSON.parse(canvas.stateJson()); s.prompts = prompts(); return JSON.stringify(s); }
    function cancel() {
        if (canvas.regions.some(r => r.strokes.length) && !confirmCancel) { confirmCancel = true; return; }
        MediaGen.closeRegionEditor();
    }
    function canApply() {
        rev;
        return !MediaGen.busy && MediaGen.connected && !Ai.busy && canvas.regions.some((r, i) => canvas.bbox(i) && (r.prompt ?? "").trim().length);
    }
    function apply() {
        if (!canApply()) return;
        canvas.exportMasks((list) => {
            if (!list) { MediaGen.lastError = "Couldn't save the painted areas"; return; }
            const regions = list.map(m => ({ mask: m.mask, box: m.box.map(Math.round), prompt: (canvas.regions[m.index]?.prompt ?? "").trim() }))
                                .filter(r => r.prompt.length);
            if (!regions.length) { MediaGen.lastError = "Give each painted area a prompt"; return; }
            win.lastApplied = regions;
            MediaGen.submitRegions(regions);
        });
    }
    function handleKey(e, typing) {
        if (e.key === Qt.Key_Escape) { cancel(); return true; }
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { apply(); return true; }
        if (typing) return false;
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
    }
    Component.onDestruction: if (MediaGen.regionEditor === win) MediaGen.regionEditor = null

    Connections { target: canvas; function onChanged() { win.confirmCancel = false; } }

    Rectangle { anchors.fill: parent; color: Appearance.m3colors.m3scrim; opacity: 0.82 }
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => { e.accepted = win.handleKey(e, false); }
        Keys.onReleased: (e) => { if (e.key === Qt.Key_Space && !e.isAutoRepeat) { canvas.spaceHeld = false; e.accepted = true; } }
        onActiveFocusChanged: if (!activeFocus) canvas.spaceHeld = false

        RowLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignLeft
                    implicitHeight: 48
                    implicitWidth: toolRow.implicitWidth + 24
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer1
                    RowLayout {
                        id: toolRow
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                        spacing: 4
                        component ToolButton: RippleButton {
                            id: tb
                            property string sym
                            property string tip
                            property bool active: false
                            implicitWidth: 36; implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            toggled: active
                            focusPolicy: Qt.NoFocus
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: tb.sym; iconSize: 20; color: tb.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1 }
                            StyledToolTip { text: tb.tip }
                        }
                        ToolButton { sym: "brush"; tip: "Brush (E)"; active: canvas.tool === "brush"; onClicked: canvas.tool = "brush" }
                        ToolButton { sym: "ink_eraser"; tip: "Eraser (E)"; active: canvas.tool === "eraser"; onClicked: canvas.tool = "eraser" }
                        ToolButton { sym: "undo"; tip: "Undo (Ctrl+Z)"; onClicked: canvas.undo() }
                        ToolButton { sym: "redo"; tip: "Redo (Ctrl+Shift+Z)"; onClicked: canvas.redo() }
                        ToolButton { sym: "delete"; tip: "Clear this area"; onClicked: canvas.clearRegion() }
                        StyledSlider {
                            Layout.preferredWidth: 160
                            Layout.leftMargin: 8
                            from: 4; to: 400; stepSize: 1
                            value: canvas.brushSize
                            onMoved: canvas.brushSize = value
                            focusPolicy: Qt.NoFocus
                        }
                        StyledText {
                            Layout.preferredWidth: 48
                            text: Math.round(canvas.brushSize) + " px"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledText {
                            Layout.leftMargin: 8
                            text: "Scroll zoom · Space+drag pan · [ ] brush size"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    RegionCanvas { id: canvas; anchors.fill: parent; source: MediaGen.regionPath }
                    TapHandler {
                        onPressedChanged: if (pressed) keys.forceActiveFocus()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 12
                    StyledText { text: "Region edit"; font.pixelSize: Appearance.font.pixelSize.larger; font.weight: Font.Medium }
                    StyledText {
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                        text: "Paint what should change. Then drag the box over where it should end up."
                    }

                    Repeater {
                        model: canvas.regions
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: canvas.current === index
                            readonly property var box: win.rev >= 0 ? modelData.box : null
                            readonly property bool large: !!box && (box[2] - box[0]) * (box[3] - box[1]) > win.largeAreaPx
                            Layout.fillWidth: true
                            implicitHeight: cardCol.implicitHeight + 20
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: isCurrent ? 2 : 0
                            border.color: Appearance.colors.colPrimary
                            MouseArea { anchors.fill: parent; onPressed: (m) => { canvas.current = card.index; m.accepted = false; } }
                            ColumnLayout {
                                id: cardCol
                                anchors { fill: parent; margins: 10 }
                                spacing: 6
                                RowLayout {
                                    spacing: 8
                                    Rectangle { implicitWidth: 14; implicitHeight: 14; radius: 7; color: card.modelData.color }
                                    StyledText { text: "Area " + (card.index + 1); font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium }
                                    Item { Layout.fillWidth: true }
                                    RippleButton {
                                        visible: canvas.regions.length > 1
                                        implicitWidth: 28; implicitHeight: 28
                                        buttonRadius: Appearance.rounding.full
                                        focusPolicy: Qt.NoFocus
                                        onClicked: canvas.removeRegion(card.index)
                                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.colors.colSubtext }
                                        StyledToolTip { text: "Remove this area" }
                                    }
                                }
                                TextEdit {
                                    id: promptEdit
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 40
                                    wrapMode: TextEdit.Wrap
                                    color: Appearance.colors.colOnLayer2
                                    font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.smallie
                                    selectionColor: Appearance.colors.colPrimaryContainer
                                    text: card.modelData.prompt ?? ""
                                    onTextChanged: if (text !== (card.modelData.prompt ?? "")) { card.modelData.prompt = text; canvas.touch(); }
                                    onActiveFocusChanged: if (activeFocus) canvas.current = card.index
                                    Keys.onPressed: (e) => { e.accepted = win.handleKey(e, true); }
                                    StyledText {
                                        anchors.fill: parent; visible: promptEdit.text.length === 0; wrapMode: Text.Wrap
                                        text: "What should change here?"; color: Appearance.colors.colSubtext; opacity: 0.6
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                    text: "Drag the box over where it should end up"
                                    color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                StyledText {
                                    visible: card.large
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                    text: "Large area, detail will soften"
                                    color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                        }
                    }

                    RippleButton {
                        visible: canvas.regions.length < 4
                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        focusPolicy: Qt.NoFocus
                        onClicked: { const i = canvas.addRegion(); if (i >= 0) canvas.current = i; }
                        contentItem: StyledText { anchors.centerIn: parent; text: "+ Add area"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.smallie }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: ["draft", "balanced", "realistic"]
                            delegate: RippleButton {
                                required property string modelData
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                toggled: MediaGen.quality === modelData
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                focusPolicy: Qt.NoFocus
                                onClicked: MediaGen.quality = modelData
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData.charAt(0).toUpperCase() + parent.modelData.slice(1)
                                    font.pixelSize: Appearance.font.pixelSize.smallie
                                    color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                    StyledText {
                        visible: win.perRegionS !== undefined && win.perRegionS !== null && win.nPainted > 0
                        Layout.fillWidth: true
                        text: MediaGen.fmtDuration((win.perRegionS ?? 0) * win.nPainted)
                        color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    StyledText {
                        visible: MediaGen.lastError !== ""
                        text: MediaGen.lastError
                        color: Appearance.m3colors.m3error; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                    StyledText {
                        visible: win.confirmCancel
                        text: "Discard the painted areas? Press Cancel again."
                        color: Appearance.colors.colSubtext; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        DialogButton { buttonText: "Cancel"; onClicked: win.cancel() }
                        Item { Layout.fillWidth: true }
                        DialogButton { buttonText: C.BUTTON.region[1]; enabled: win.canApply(); onClicked: win.apply() }
                    }
                }
            }
        }
    }
}
