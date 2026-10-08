import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
    readonly property string status: MediaGen.state.status ?? "idle"
    readonly property bool errorShown: status === "error" && (MediaGen.state.job?.id ?? "recovered") !== MediaGen.dismissedJobId
    readonly property var btn: C.buttonFor(MediaGen.mode(), MediaGen.srcPath !== "")
    spacing: 8

    RowLayout {   // swap note
        visible: root.status === "idle" && MediaGen.agentLoaded
        Layout.leftMargin: 2; spacing: 6
        MaterialSymbol { text: "swap_horiz"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
        StyledText { text: "The agent model unloads first · it reloads on your next message"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
    }
    StyledText {   // submit rejection (422/409) or service offline
        visible: MediaGen.lastError !== "" || !MediaGen.connected
        Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.leftMargin: 2
        text: !MediaGen.connected ? "Media service is offline" : MediaGen.lastError
        color: Appearance.colors.colError; font.pixelSize: Appearance.font.pixelSize.smaller
        HoverHandler { id: offlineHover }
        property bool hovered: offlineHover.hovered
        StyledToolTip { text: !MediaGen.connected ? "Start it with systemctl --user start media.service" : MediaGen.lastError }
    }

    RippleButton {   // main button
        id: submitButton
        visible: root.status === "idle" || root.status === "error" && !root.errorShown
        Layout.fillWidth: true; implicitHeight: 46
        enabled: MediaGen.canSubmit()
        opacity: 1
        buttonColor: enabled ? (down ? Appearance.colors.colPrimaryContainerActive : hovered ? colBackgroundHover : colBackground) : Appearance.colors.colLayer2Disabled
        readonly property color foreground: enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2Disabled
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colPrimaryContainer
        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
        colRipple: Appearance.colors.colPrimaryContainerActive
        onClicked: MediaGen.submit()
        StyledToolTip { text: Ai.busy ? "The agent is replying…" : "Ctrl + Enter" }
        contentItem: RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            MaterialSymbol { text: root.btn[0]; fill: 1; color: submitButton.foreground }
            StyledText { text: root.btn[1]; font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; color: submitButton.foreground }
            Item { Layout.fillWidth: true }
            StyledText { text: MediaGen.fmtDuration(MediaGen.estimateS()); font.pixelSize: Appearance.font.pixelSize.smaller; color: ColorUtils.mix(submitButton.foreground, submitButton.buttonColor, 0.65) }
        }
    }

    RippleButtonWithIcon {
        visible: root.status === "error" && (MediaGen.state.error?.retryable ?? false) && !root.errorShown
        enabled: MediaGen.canRetry()
        Layout.fillWidth: true
        materialIcon: "refresh"; mainText: "Retry last failed job"
        onClicked: MediaGen.retry()
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
                        visible: modelData.state !== "now"
                        text: modelData.state === "done" ? "check_circle" : "radio_button_unchecked"
                        iconSize: Appearance.font.pixelSize.normal; color: modelData.state === "next" ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    }
                    MaterialLoadingIndicator { visible: modelData.state === "now"; loading: visible; implicitSize: Appearance.font.pixelSize.larger }
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
        visible: root.errorShown
        Layout.fillWidth: true; implicitHeight: err.implicitHeight + 24
        radius: Appearance.rounding.normal; color: Appearance.colors.colErrorContainer
        ColumnLayout {
            id: err; anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 } spacing: 8
            RowLayout { spacing: 8
                MaterialSymbol { text: "error"; color: Appearance.colors.colOnErrorContainer }
                StyledText { Layout.fillWidth: true; wrapMode: Text.Wrap; text: MediaGen.state.error?.message ?? ""; color: Appearance.colors.colOnErrorContainer; font.weight: Font.Medium } }
            StyledText {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnErrorContainer
                text: ((MediaGen.state.error?.saved_until_s ?? 0) > 0 ? "The first " + MediaGen.state.error.saved_until_s + " s were saved. " : "") + (MediaGen.state.error?.hint ?? "")
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                DialogButton { colEnabled: Appearance.colors.colOnErrorContainer; colBackgroundHover: Appearance.colors.colErrorContainerHover; colRipple: Appearance.colors.colErrorContainerActive; buttonText: "Dismiss"; onClicked: MediaGen.dismissError() }
                DialogButton { colEnabled: Appearance.colors.colOnErrorContainer; colBackgroundHover: Appearance.colors.colErrorContainerHover; colRipple: Appearance.colors.colErrorContainerActive; visible: MediaGen.state.error?.retryable ?? false; enabled: MediaGen.canRetry(); buttonText: (MediaGen.state.error?.saved_until_s ?? 0) > 0 ? "Retry from " + MediaGen.state.error.saved_until_s + " s" : "Retry"; onClicked: MediaGen.retry() }
            }
        }
    }
}
