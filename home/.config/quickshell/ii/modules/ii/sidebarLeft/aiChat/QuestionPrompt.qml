import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var messageData
    property var questions: messageData?.requestData?.questions ?? []
    property var answers: ({})
    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: row.implicitHeight + 4 + (messageData?.done ? 0 : 8)
    focus: !messageData?.done
    Component.onCompleted: if (!messageData?.done) forceActiveFocus()
    function submit() {
        const result = questions.map((q, i) => root.answers[i] ?? []);
        if (result.some(a => a.length === 0)) return;
        Ai.answerQuestion(messageData, result);
    }
    Keys.onEscapePressed: Ai.rejectQuestion(root.messageData)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 2
        visible: !root.messageData?.done
        color: Appearance.colors.colPrimary
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        anchors.topMargin: root.messageData?.done ? 0 : 8
        anchors.top: parent.top
        spacing: 10
        StyledText { Layout.alignment: Qt.AlignTop; Layout.preferredWidth: 10; text: "⎿"; color: Appearance.colors.colSubtext; visible: root.messageData?.done }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            StyledText {
                visible: root.messageData?.done
                text: root.messageData?.answer ?? ""
                color: Appearance.colors.colSubtext
            }
            Repeater {
                model: root.messageData?.done ? [] : root.questions
                delegate: ColumnLayout {
                    id: questionRow
                    required property int index
                    required property var modelData
                    property int selectedIndex: 0
                    Layout.fillWidth: true
                    spacing: 3
                    StyledText {
                        Layout.fillWidth: true
                        text: questionRow.modelData.header ?? "Question"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        font.weight: Font.Bold
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: questionRow.modelData.question ?? ""
                        wrapMode: Text.Wrap
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Ai.chatFontSize
                        color: Appearance.colors.colOnLayer1
                    }
                    Repeater {
                        model: questionRow.modelData.options ?? []
                        delegate: PromptOption {
                            required property int index
                            required property var modelData
                            number: index + 1
                            label: `${modelData.label}${modelData.description ? " <font color=\"" + Appearance.colors.colSubtext + "\">· " + modelData.description + "</font>" : ""}`
                            selected: index === questionRow.selectedIndex
                            onHovered: questionRow.selectedIndex = index
                            onClicked: {
                                root.answers[questionRow.index] = [modelData.label];
                                if (root.questions.length === 1) root.submit();
                            }
                        }
                    }
                    TextField {
                        Layout.fillWidth: true
                        visible: questionRow.modelData.custom !== false
                        placeholderText: "your answer…"
                        color: Appearance.colors.colOnLayer1
                        onAccepted: {
                            root.answers[questionRow.index] = [text];
                            root.submit();
                        }
                    }
                }
            }
            StyledText {
                visible: !root.messageData?.done && root.questions.length > 1
                text: "send answers ↵"
                color: Appearance.colors.colPrimary
                MouseArea { anchors.fill: parent; onClicked: root.submit() }
            }
            StyledText {
                visible: !root.messageData?.done
                text: "esc to skip"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Ai.chatFontSize
                color: Appearance.colors.colSubtext
            }
        }
    }
}
