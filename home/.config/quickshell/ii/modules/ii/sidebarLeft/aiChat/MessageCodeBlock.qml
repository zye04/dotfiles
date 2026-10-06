pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import org.kde.syntaxhighlighting

ColumnLayout {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var segmentLang: "txt"
    property var messageData: {}
    property bool isCommandRequest: segmentLang === "command"
    property var displayLang: (isCommandRequest ? "bash" : segmentLang)

    property real codeBlockBackgroundRounding: Appearance.rounding.small

    spacing: 0
    // local-suite: no header bar. A subtle tint; language and copy/save show dim on hover only.
    property real indentCols: 0 // list-item indent, in characters
    Layout.leftMargin: indentCols * charMetrics.advanceWidth("0")
    FontMetrics {
        id: charMetrics
        font.family: Appearance.font.family.monospace
        font.pixelSize: Ai.chatFontSize
    }
    HoverHandler { id: hover }

    Rectangle { // Code background
        Layout.fillWidth: true
        radius: codeBlockBackgroundRounding
        color: Appearance.colors.colLayer2
        implicitHeight: codeColumnLayout.implicitHeight

        ColumnLayout {
            id: codeColumnLayout
            anchors.fill: parent
            spacing: 0
            TextArea { // Code
                id: codeTextArea
                Layout.fillWidth: true
                padding: 8
                readOnly: !editing
                selectByMouse: enableMouseSelection || editing
                renderType: Text.NativeRendering
                font.family: Appearance.font.family.monospace
                font.hintingPreference: Font.PreferNoHinting // Prevent weird bold text
                font.pixelSize: Ai.chatFontSize
                selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                selectionColor: Appearance.colors.colSecondaryContainer
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                color: messageData.thinking ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1

                text: segmentContent
                onTextChanged: {
                    segmentContent = text
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Tab) {
                        // Insert 4 spaces at cursor
                        const cursor = codeTextArea.cursorPosition;
                        codeTextArea.insert(cursor, "    ");
                        codeTextArea.cursorPosition = cursor + 4;
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                        codeTextArea.copy();
                        event.accepted = true;
                    }
                }

                SyntaxHighlighter {
                    id: highlighter
                    textEdit: codeTextArea
                    repository: Repository
                    definition: Repository.definitionForName(root.displayLang || "plaintext")
                    theme: Appearance.syntaxHighlightingTheme
                }
        }
            Loader {
                active: root.isCommandRequest && root.messageData.functionPending
                visible: active
                Layout.fillWidth: true
                Layout.margins: 6
                Layout.topMargin: 0
                sourceComponent: RowLayout {
                    Item { Layout.fillWidth: true }
                    ButtonGroup {
                        GroupButton {
                            contentItem: StyledText {
                                text: Translation.tr("Reject")
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Ai.chatFontSize
                                color: Appearance.colors.colOnLayer2
                            }
                            onClicked: Ai.rejectCommand(root.messageData)
                        }
                        GroupButton {
                            toggled: true
                            contentItem: StyledText {
                                text: Translation.tr("Approve")
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Ai.chatFontSize
                                color: Appearance.colors.colOnPrimary
                            }
                            onClicked: Ai.approveCommand(root.messageData)
                        }
                    }
                }
            }
        }

        Row { // Language label and copy/save, dim, on hover only
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            spacing: 6
            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
                text: root.displayLang ? Repository.definitionForName(root.displayLang).name : "plain"
            }
            MaterialSymbol {
                id: copyIcon
                property bool activated: false
                text: activated ? "inventory" : "content_copy"
                iconSize: Appearance.font.pixelSize.large
                color: copyMouse.containsMouse ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.clipboardText = segmentContent
                        copyIcon.activated = true
                        copyIconTimer.restart()
                    }
                }
                Timer {
                    id: copyIconTimer
                    interval: 1500
                    onTriggered: copyIcon.activated = false
                }
            }
            MaterialSymbol {
                id: saveIcon
                property bool activated: false
                text: activated ? "check" : "save"
                iconSize: Appearance.font.pixelSize.large
                color: saveMouse.containsMouse ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const downloadPath = FileUtils.trimFileProtocol(Directories.downloads)
                        Quickshell.execDetached(["bash", "-c",
                            `echo '${StringUtils.shellSingleQuoteEscape(segmentContent)}' > '${downloadPath}/code.${segmentLang || "txt"}'`
                        ])
                        Quickshell.execDetached(["notify-send",
                            Translation.tr("Code saved to file"),
                            Translation.tr("Saved to %1").arg(`${downloadPath}/code.${segmentLang || "txt"}`),
                            "-a", "Shell"
                        ])
                        saveIcon.activated = true
                        saveIconTimer.restart()
                    }
                }
                Timer {
                    id: saveIconTimer
                    interval: 1500
                    onTriggered: saveIcon.activated = false
                }
            }
        }

        // MouseArea to block scrolling
        // MouseArea {
        //     id: codeBlockMouseArea
        //     anchors.fill: parent
        //     acceptedButtons: editing ? Qt.NoButton : Qt.LeftButton
        //     cursorShape: (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
        //     onWheel: (event) => {
        //         event.accepted = false
        //     }
        // }
    }
}
