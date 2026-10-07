import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
    readonly property string status: MediaGen.state.status ?? "idle"
    readonly property var btn: C.buttonFor(MediaGen.mode(), MediaGen.srcPath !== "")
    spacing: 8

    RowLayout {   // swap note
        visible: root.status === "idle" && MediaGen.agentLoaded
        Layout.leftMargin: 2; spacing: 6
        MaterialSymbol { text: "swap_horiz"; iconSize: 16; color: Appearance.colors.colSubtext }
        StyledText { text: "The agent model unloads first · it reloads on your next message"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
    }
    StyledText {   // submit rejection (422/409) or service offline
        visible: MediaGen.lastError !== "" || !MediaGen.connected
        Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.leftMargin: 2
        text: !MediaGen.connected ? "Media service is not running · systemctl --user start media" : MediaGen.lastError
        color: Appearance.m3colors.m3error; font.pixelSize: Appearance.font.pixelSize.smaller
    }

    RippleButton {   // main button
        visible: root.status === "idle" || root.status === "error" && !MediaGen.state.error?.retryable
        Layout.fillWidth: true; implicitHeight: 46
        enabled: MediaGen.canSubmit()
        opacity: enabled ? 1 : 0.4
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colPrimaryContainer
        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
        onClicked: MediaGen.submit()
        StyledToolTip { text: "Ctrl + Enter" }
        contentItem: RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            MaterialSymbol { text: root.btn[0]; fill: 1; color: Appearance.colors.colOnPrimaryContainer }
            StyledText { text: root.btn[1]; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; color: Appearance.colors.colOnPrimaryContainer }
            Item { Layout.fillWidth: true }
            StyledText { text: MediaGen.fmtDuration(MediaGen.estimateS()); opacity: 0.65; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer }
        }
    }

    Rectangle {   // run card
        visible: root.status === "running" || root.status === "starting"
        Layout.fillWidth: true; implicitHeight: run.implicitHeight + 24
        radius: Appearance.rounding.normal; color: Appearance.colors.colLayer1
        ColumnLayout {
            id: run; anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 } spacing: 9
            RowLayout {
                StyledText { text: MediaGen.state.title ?? ""; font.weight: Font.Medium; font.pixelSize: Appearance.font.pixelSize.smallie }
                Item { Layout.fillWidth: true }
                StyledText {
                    color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                    text: root.status === "starting" ? "Starting the generator…" : C.mmss(MediaGen.state.elapsed_s) + " · " + MediaGen.fmtDuration(Math.max(0, (MediaGen.state.eta_s ?? 0) - (MediaGen.state.elapsed_s ?? 0))) + " left"
                }
            }
            StyledProgressBar { Layout.fillWidth: true; value: MediaGen.state.progress ?? 0 }
            Repeater {
                model: MediaGen.state.stages ?? []
                delegate: RowLayout {
                    required property var modelData
                    spacing: 8
                    MaterialSymbol {
                        text: modelData.state === "done" ? "check_circle" : modelData.state === "now" ? "progress_activity" : "radio_button_unchecked"
                        iconSize: 16; color: modelData.state === "next" ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                        RotationAnimation on rotation { running: modelData.state === "now"; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                    }
                    StyledText { text: modelData.label; font.pixelSize: Appearance.font.pixelSize.smaller
                                 color: modelData.state === "now" ? Appearance.colors.colOnLayer1 : modelData.state === "done" ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext }
                }
            }
            RowLayout {
                StyledText { text: "Esc stops · finished parts are kept"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                Item { Layout.fillWidth: true }
                RippleButtonWithIcon { materialIcon: "stop"; mainText: "Stop"; onClicked: MediaGen.stop() }
            }
        }
    }

    Rectangle {   // error card
        visible: root.status === "error" && (MediaGen.state.error?.retryable ?? false)
        Layout.fillWidth: true; implicitHeight: err.implicitHeight + 24
        radius: Appearance.rounding.normal; color: Qt.alpha(Appearance.m3colors.m3errorContainer, 0.35)
        ColumnLayout {
            id: err; anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 } spacing: 8
            RowLayout { spacing: 8
                MaterialSymbol { text: "error"; color: Appearance.m3colors.m3error }
                StyledText { Layout.fillWidth: true; wrapMode: Text.Wrap; text: MediaGen.state.error?.message ?? ""; color: Appearance.m3colors.m3error; font.weight: Font.Medium } }
            StyledText {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1
                text: ((MediaGen.state.error?.saved_until_s ?? 0) > 0 ? "The first " + MediaGen.state.error.saved_until_s + " s were saved. " : "") + (MediaGen.state.error?.hint ?? "")
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                DialogButton { buttonText: "Dismiss"; onClicked: MediaGen.state = Object.assign({}, MediaGen.state, { status: "idle", error: null }) }
                DialogButton { buttonText: (MediaGen.state.error?.saved_until_s ?? 0) > 0 ? "Retry from " + MediaGen.state.error.saved_until_s + " s" : "Retry"; onClicked: MediaGen.retry() }
            }
        }
    }
}
