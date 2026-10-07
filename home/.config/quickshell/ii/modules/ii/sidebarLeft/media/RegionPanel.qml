import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MediaCopy.js" as C

ColumnLayout {
    id: root
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
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: "Cancel region edit" }
                }
                StyledText { text: "Region edit"; font.pixelSize: Appearance.font.pixelSize.larger; font.weight: Font.Medium }
            }
            StyledText {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                text: "Paint what should change. Then drag the box over where it should end up."
            }

            Repeater {
                model: canvas.regions.length
                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property var reg: win.rev >= 0 ? canvas.regions[index] : null
                    readonly property bool isCurrent: canvas.current === index
                    enabled: !win.applying
                    readonly property var box: win.rev >= 0 && reg ? reg.box : null
                    readonly property bool needsPrompt: win.rev >= 0 && !!canvas.bbox(index) && !(card.reg?.prompt ?? "").trim().length
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
                            Rectangle { implicitWidth: 14; implicitHeight: 14; radius: 7; color: card.reg?.color ?? "transparent" }
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
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(56, promptEdit.implicitHeight + 18)
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer3
                            border.width: promptEdit.activeFocus ? 2 : 0
                            border.color: Appearance.colors.colPrimary
                            TextEdit {
                                id: promptEdit
                                anchors { fill: parent; margins: 9; leftMargin: 11; rightMargin: 11 }
                                wrapMode: TextEdit.Wrap
                                color: Appearance.colors.colOnLayer2
                                font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.smallie
                                selectionColor: Appearance.colors.colPrimaryContainer
                                text: card.reg?.prompt ?? ""
                                onTextChanged: if (!win.applying && card.reg && text !== (card.reg.prompt ?? "")) { card.reg.prompt = text; canvas.touch(); }
                                onActiveFocusChanged: {
                                    if (activeFocus) { canvas.current = card.index; win.promptFocus = promptEdit; }
                                    else if (win.promptFocus === promptEdit) win.promptFocus = null;
                                }
                                Keys.onPressed: (e) => { e.accepted = win.handleKey(e, true); }
                                StyledText {
                                    anchors.fill: parent; visible: promptEdit.text.length === 0; wrapMode: Text.Wrap
                                    text: "What should change here?"; color: Appearance.colors.colSubtext; opacity: 0.6
                                    font.pixelSize: Appearance.font.pixelSize.smallie
                                }
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Drag the box over where it should end up"
                            color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledText {
                            visible: card.needsPrompt
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Describe this area"
                            color: Appearance.m3colors.m3error; font.pixelSize: Appearance.font.pixelSize.smaller
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
                enabled: !win.applying
                Layout.fillWidth: true
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                focusPolicy: Qt.NoFocus
                onClicked: { const i = canvas.addRegion(); if (i >= 0) canvas.current = i; }
                contentItem: StyledText { anchors.centerIn: parent; text: "+ Add area"; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.smallie }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                enabled: !win.applying
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
                visible: win.perRegionS !== undefined && win.perRegionS !== null
                Layout.fillWidth: true
                text: MediaGen.fmtDuration(win.perRegionS) + " per area" + (win.nPainted > 1 ? " · " + MediaGen.fmtDuration(win.perRegionS * win.nPainted) : "")
                color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller
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
    RowLayout {
        Layout.fillWidth: true
        DialogButton { buttonText: "Cancel"; onClicked: win.cancel() }
        Item { Layout.fillWidth: true }
        RippleButton {
            implicitHeight: 40; implicitWidth: applyRow.implicitWidth + 32
            buttonRadius: Appearance.rounding.full
            enabled: win.canApply()
            opacity: enabled || win.applying ? 1 : 0.4
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: win.apply()
            StyledToolTip { text: "Ctrl + Enter" }
            contentItem: RowLayout {
                id: applyRow
                anchors.centerIn: parent; spacing: 6
                MaterialSymbol { text: C.BUTTON.region[0]; fill: 1; iconSize: 20; color: Appearance.colors.colOnPrimary }
                StyledText {
                    text: win.applying ? "Applying…" : C.BUTTON.region[1]
                    font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }
}
