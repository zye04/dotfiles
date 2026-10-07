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
    }
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier) && !MediaGen.busy) { MediaGen.pasteSource(); e.accepted = true; }
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { MediaGen.submit(); e.accepted = true; }
        else if (e.key === Qt.Key_Escape && MediaGen.busy) { MediaGen.stop(); e.accepted = true; }
    }

    RowLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 12

        ColumnLayout {
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

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 8
            Viewer { Layout.fillWidth: true; Layout.fillHeight: true }
            FilmStrip { Layout.fillWidth: true }
        }
    }

    DialogHost { id: finishDialog; sourceComponent: FinishDialog {} }
    DialogHost { id: advancedDialog; sourceComponent: AdvancedDialog {} }
    Loader { active: MediaGen.regionPath !== ""; sourceComponent: RegionEditor {} }

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

    component Seg: Rectangle {
        id: seg
        property var model: []
        property int currentIndex: 0
        signal picked(int index)
        implicitHeight: 38; radius: height / 2; color: Appearance.colors.colLayer2
        RowLayout {
            anchors { fill: parent; margins: 3 } spacing: 2
            Repeater {
                model: seg.model
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    readonly property bool on: index === seg.currentIndex
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: height / 2
                    color: on ? Appearance.colors.colSecondaryContainer : "transparent"
                    Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        MaterialSymbol { text: modelData.icon; iconSize: 18; color: on ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1 }
                        StyledText { text: modelData.name; color: on ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(index) }
                }
            }
        }
    }
}
