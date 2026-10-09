import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    focus: true
    Connections {
        target: MediaGen
        function onBusyChanged() { if (MediaGen.busy) root.forceActiveFocus(); }
        function onRegionPathChanged() { if (MediaGen.regionPath === "") root.forceActiveFocus(); }
    }
    Keys.onReleased: (e) => {
        if (regionEditor.item && MediaGen.regionPath !== "" && e.key === Qt.Key_Space && !e.isAutoRepeat) { regionEditor.item.canvas.spaceHeld = false; e.accepted = true; }
    }
    Keys.onPressed: (e) => {
        if (MediaGen.regionPath !== "") { e.accepted = regionEditor.item ? regionEditor.item.handleKey(e, regionEditor.item.promptFocus !== null) : true; return; }
        if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier) && !MediaGen.busy) { MediaGen.pasteSource(); e.accepted = true; }
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { MediaGen.submit(); e.accepted = true; }
        else if (e.key === Qt.Key_Escape && MediaGen.busy) { MediaGen.stop(); e.accepted = true; }
    }

    RowLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 12

        ColumnLayout {
            visible: MediaGen.regionPath === ""
            Layout.preferredWidth: 360; Layout.minimumWidth: 360; Layout.maximumWidth: 360; Layout.fillHeight: true
            spacing: 12
            StyledFlickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: width; contentHeight: controls.implicitHeight; clip: true
                enabled: !MediaGen.busy
                opacity: MediaGen.busy ? 0.45 : 1
                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                ColumnLayout {
                    id: controls; width: parent.width; spacing: 12
                    Seg {
                        Layout.fillWidth: true
                        model: [{ "icon": "image", "name": "Image" }, { "icon": "movie", "name": "Video" }]
                        currentIndex: MediaGen.kind === "video" ? 1 : 0
                        onPicked: (i) => { const k = i === 1 ? "video" : "image"; if (k !== MediaGen.kind) { MediaGen.kind = k; MediaGen.clearSource(); } }
                    }
                    SourceRow { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    Seg {
                        visible: MediaGen.kind === "image" && MediaGen.srcPath !== ""
                        Layout.fillWidth: true
                        model: [{ "icon": "edit", "name": "Edit" }, { "icon": "hd", "name": "Upscale" }, { "icon": "brush", "name": "Region" }]
                        currentIndex: MediaGen.task === "upscale" ? 1 : 0
                        onPicked: (i) => { if (i === 2) MediaGen.openRegionEditor(MediaGen.srcPath, null); else MediaGen.task = i === 1 ? "upscale" : "edit"; }
                    }
                    PromptField { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    StoryRows { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    OptionPills { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    SummaryCard { kind: "finish"; Layout.fillWidth: true; Layout.minimumWidth: 0; onOpenRequested: finishDialog.show = true }
                    SummaryCard { kind: "advanced"; Layout.fillWidth: true; Layout.minimumWidth: 0; onOpenRequested: advancedDialog.show = true }
                }
            }
            ActionArea { Layout.fillWidth: true }
        }

        Loader {
            active: !!regionEditor.item
            visible: active
            Layout.preferredWidth: 360; Layout.minimumWidth: 360; Layout.maximumWidth: 360; Layout.fillHeight: true
            sourceComponent: RegionPanel { editor: regionEditor.item; onAdvancedRequested: advancedDialog.show = true }
        }
        Loader {
            id: regionEditor
            active: MediaGen.regionPath !== ""
            visible: active
            Layout.fillWidth: true; Layout.fillHeight: true
            sourceComponent: RegionEditor {}
            onLoaded: item.forceActiveFocus()
        }
        ColumnLayout {
            visible: MediaGen.regionPath === ""
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 8
            Viewer { Layout.fillWidth: true; Layout.fillHeight: true }
            FilmStrip { Layout.fillWidth: true }
        }
    }

    DialogHost { id: finishDialog; sourceComponent: FinishDialog {} }
    DialogHost { id: advancedDialog; sourceComponent: AdvancedDialog {} }

    component DialogHost: Loader {
        id: host
        property bool show: false
        anchors.fill: parent
        active: show
        onActiveChanged: if (active) { item.show = true; item.forceActiveFocus(); }
        Connections {
            target: host.item
            function onVisibleChanged() { if (!host.item.visible && !host.item.show) host.show = false; }
        }
    }

    component Seg: ButtonGroup {
        id: seg
        property var model: []
        property int currentIndex: 0
        signal picked(int index)
        spacing: 4
        uniformCellSizes: true
        Repeater {
            model: seg.model
            delegate: SelectionGroupButton {
                required property int index
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 38
                buttonText: modelData.name
                buttonIcon: modelData.icon
                toggled: index === seg.currentIndex
                leftmost: index === 0
                rightmost: index === seg.model.length - 1
                onClicked: seg.picked(index)
            }
        }
    }
}
