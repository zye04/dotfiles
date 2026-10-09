import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
    signal advancedRequested()
    required property var editor
    readonly property var win: editor
    readonly property var canvas: editor.canvas
    spacing: 12
    StyledFlickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        contentWidth: width; contentHeight: controls.implicitHeight; clip: true
        ColumnLayout {
            id: controls; width: parent.width; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                RippleButton {
                    implicitWidth: 32; implicitHeight: 32; buttonRadius: Appearance.rounding.full
                    focusPolicy: Qt.NoFocus
                    onClicked: win.cancel()
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: "Cancel region edit" }
                }
                StyledText { text: "Region edit"; font.pixelSize: Appearance.font.pixelSize.larger; font.weight: Font.Medium }
            }
            StyledText {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small
                text: "Paint what should change. Then drag the box over where it should end up."
            }

            Repeater {
                model: canvas.regions.length
                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property var reg: win.rev >= 0 ? canvas.regions[index] : null
                    enabled: !win.applying
                    readonly property var box: win.rev >= 0 && reg ? reg.box : null
                    readonly property bool needsBox: win.rev >= 0 && !win.boxValid(index)
                    readonly property bool needsPrompt: win.rev >= 0 && !!canvas.bbox(index) && !(card.reg?.prompt ?? "").trim().length
                    readonly property bool large: !!box && (box[2] - box[0]) * (box[3] - box[1]) > win.largeAreaPx
                    Layout.fillWidth: true
                    implicitHeight: cardCol.implicitHeight + 20
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    MouseArea { anchors.fill: parent; onPressed: (m) => { canvas.current = card.index; m.accepted = false; } }
                    ColumnLayout {
                        id: cardCol
                        anchors { fill: parent; margins: 10 }
                        spacing: 6
                        RowLayout {
                            spacing: 8
                            Rectangle { implicitWidth: 14; implicitHeight: 14; radius: Appearance.rounding.full; color: canvas.colors[card.index] }
                            StyledText { text: "Area " + (card.index + 1); font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium }
                            Item { Layout.fillWidth: true }
                            RippleButton {
                                visible: canvas.regions.length > 1
                                implicitWidth: 28; implicitHeight: 28
                                buttonRadius: Appearance.rounding.full
                                focusPolicy: Qt.NoFocus
                                onClicked: canvas.removeRegion(card.index)
                                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                                StyledToolTip { text: "Remove this area" }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(56, promptEdit.implicitHeight + 18)
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer3
                            border.width: promptEdit.activeFocus ? 2 : 0
                            border.color: Appearance.colors.colPrimary
                            StyledTextArea {
                                id: promptEdit
                                anchors.fill: parent
                                padding: 10; background: null
                                wrapMode: TextEdit.Wrap
                                color: Appearance.colors.colOnLayer2
                                font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.smallie
                                placeholderText: "What should change here?"
                                text: card.reg?.prompt ?? ""
                                onTextChanged: if (!win.applying && card.reg && text !== (card.reg.prompt ?? "")) { card.reg.prompt = text; canvas.touch(); }
                                onActiveFocusChanged: {
                                    if (activeFocus) { canvas.current = card.index; win.promptFocus = promptEdit; }
                                    else if (win.promptFocus === promptEdit) win.promptFocus = null;
                                }
                                Keys.onPressed: (e) => { e.accepted = win.handleKey(e, true); }

                            }
                        }
                        StyledText {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: card.needsBox ? "Expand the box to include the whole painted area" : "Drag the box over where it should end up"
                            color: card.needsBox ? Appearance.colors.colError : Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            visible: card.needsPrompt
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Describe this area"
                            color: Appearance.m3colors.m3error; font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            visible: card.large
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Large area, detail will soften"
                            color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                visible: canvas.regions.length < 4
                enabled: !win.applying
                Layout.fillWidth: true
                materialIcon: "add"; mainText: "Add area"
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                focusPolicy: Qt.NoFocus
                onClicked: { const i = canvas.addRegion(); if (i >= 0) canvas.current = i; }
            }
            MediaChoice {
                Layout.fillWidth: true; enabled: !win.applying
                label: "Quality"; selectedValue: MediaGen.quality
                options: ["draft", "balanced", "realistic"].map(q => [q, q.charAt(0).toUpperCase() + q.slice(1), ""])
                onPicked: v => MediaGen.quality = v
            }
            SummaryCard { kind: "advanced"; Layout.fillWidth: true; Layout.minimumWidth: 0; enabled: !win.applying; onOpenRequested: root.advancedRequested() }
            StyledText {
                visible: win.perRegionS !== undefined && win.perRegionS !== null
                Layout.fillWidth: true
                text: MediaGen.fmtDuration(win.perRegionS) + " per area" + (win.nPainted > 1 ? " · " + MediaGen.fmtDuration(win.perRegionS * win.nPainted) : "")
                color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                visible: canvas.pendingSeeds > 0 || canvas.seedError !== ""
                text: canvas.seedError || "Loading saved areas…"
                color: canvas.seedError ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                wrapMode: Text.Wrap; Layout.fillWidth: true
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

        }
    }
    StyledText {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        visible: !win.canApply() && !win.applying
        text: canvas.pendingSeeds > 0 ? "Loading saved areas…" : canvas.seedError ? "Reload the saved masks to continue" : !MediaGen.connected ? "Connect the Media service to continue" : MediaGen.busy || Ai.busy ? "Wait for the current job to finish" : win.nPainted === 0 ? "Paint an area and describe it" : win.invalidBox ? "Expand the box to include the whole painted area" : "Describe every painted area"
        color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small
    }
    RowLayout {
        Layout.fillWidth: true
        DialogButton { buttonText: "Cancel"; onClicked: win.cancel() }
        Item { Layout.fillWidth: true }
        RippleButton {
            id: applyButton
            implicitHeight: 40; implicitWidth: applyRow.implicitWidth + 32
            buttonRadius: Appearance.rounding.full
            enabled: win.canApply()
            opacity: 1
            buttonColor: enabled || win.applying ? (pressed ? Appearance.colors.colPrimaryActive : hovered ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary) : Appearance.colors.colLayer2Disabled
            readonly property color foreground: enabled || win.applying ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2Disabled
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            Rectangle { anchors.fill: parent; radius: parent.buttonRadius; color: "transparent"; border.width: applyButton.enabled || win.applying ? 0 : 1; border.color: Appearance.colors.colOutlineVariant }
            onClicked: win.apply()
            StyledToolTip { text: "Ctrl + Enter" }
            contentItem: RowLayout {
                id: applyRow
                anchors.centerIn: parent; spacing: 6
                MaterialSymbol { text: C.BUTTON.region[0]; fill: 1; iconSize: Appearance.font.pixelSize.larger; color: applyButton.foreground }
                StyledText {
                    text: win.applying ? "Applying…" : C.BUTTON.region[1]
                    font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium
                    color: applyButton.foreground
                }
            }
        }
    }
}
