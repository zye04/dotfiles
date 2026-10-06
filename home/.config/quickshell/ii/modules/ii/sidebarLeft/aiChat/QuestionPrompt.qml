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
    implicitHeight: row.implicitHeight + 4
    focus: !messageData?.done
    Component.onCompleted: if (!messageData?.done) forceActiveFocus()
    function submit() {
        const result = questions.map((q, i) => root.answers[i] ?? []);
        if (result.some(a => a.length === 0)) return;
        Ai.answerQuestion(messageData, result);
    }
    Keys.onEscapePressed: Ai.rejectQuestion(root.messageData)

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 10
        StyledText { Layout.alignment: Qt.AlignTop; Layout.preferredWidth: 10; text: "⎿"; color: Appearance.colors.colSubtext }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
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
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: questionRow.modelData.question ?? ""
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                    }
                    Repeater {
                        model: questionRow.modelData.options ?? []
                        delegate: StyledText {
                            required property int index
                            required property var modelData
                            text: `${index + 1}. ${modelData.label}${modelData.description ? " · " + modelData.description : ""}`
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.answers[questionRow.index] = [modelData.label];
                                    if (root.questions.length === 1) root.submit();
                                }
                            }
                        }
                    }
                    TextField {
                        Layout.fillWidth: true
                        visible: questionRow.modelData.custom !== false
                        placeholderText: "your answer…"
                        color: Appearance.colors.colOnLayer2
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
        }
    }
}
