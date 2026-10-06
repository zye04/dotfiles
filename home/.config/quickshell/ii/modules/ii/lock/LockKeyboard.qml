pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import "../onScreenKeyboard/layouts.js" as Layouts

// Mouse-only keyboard for the lock screen. Looks like the ii OSK, but writes
// straight into the password text instead of sending keycodes via ydotool,
// so it's independent of the active XKB layout (ydotool can't reach the lock anyway).
Item {
    id: root
    required property LockContext context
    property int shiftMode: 0 // 0 off, 1 one-shot, 2 caps
    property double lastShiftTap: 0

    // Drop fn row and modifier row; Tab becomes a spacer so rows stay aligned
    readonly property var rows: Layouts.byName[Layouts.defaultLayout].keys.slice(1, -1).map(row => row.map(k =>
        k.label === "Tab" ? { keytype: "spacer", label: "", shape: "tab" } : k))
        .concat([[{ keytype: "normal", label: "Space", shape: "space" }]])

    implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2

    function press(keyData) {
        const label = keyData.label;
        root.context.resetClearTimer();
        if (keyData.keytype === "modkey") {
            const now = Date.now();
            if (root.shiftMode === 1 && now - root.lastShiftTap < 300) root.shiftMode = 2;
            else root.shiftMode = root.shiftMode === 0 ? 1 : 0;
            root.lastShiftTap = now;
        } else if (label === "Backspace") {
            root.context.currentText = root.context.currentText.slice(0, -1);
        } else if (label === "Enter") {
            root.context.tryUnlock();
        } else {
            const ch = label === "Space" ? " " : (root.shiftMode > 0 ? (keyData.labelShift || label) : label);
            root.context.currentText += ch;
            if (root.shiftMode === 1) root.shiftMode = 0;
        }
    }

    StyledRectangularShadow {
        target: background
    }
    Rectangle {
        id: background
        anchors.centerIn: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        property real padding: 10
        implicitWidth: keyRows.implicitWidth + padding * 2
        implicitHeight: keyRows.implicitHeight + padding * 2

        ColumnLayout {
            id: keyRows
            anchors.centerIn: parent
            spacing: 5

            Repeater {
                model: root.rows
                delegate: RowLayout {
                    id: keyRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: keyRow.modelData
                        delegate: LockKey {}
                    }
                }
            }
        }
    }

    // Same sizing/colors as OskKey
    component LockKey: RippleButton {
        id: key
        required property var modelData
        readonly property string label: modelData.label
        readonly property string shape: modelData.shape
        readonly property bool isShift: modelData.keytype === "modkey"
        readonly property bool isBackspace: label === "Backspace"
        readonly property bool isEnter: label === "Enter"
        readonly property var widthMultiplier: ({ "normal": 1, "tab": 1.6, "shift": 2.5 })
        property real baseWidth: 45
        property real baseHeight: 45

        focusPolicy: Qt.NoFocus
        enabled: modelData.keytype !== "spacer"
        toggled: isShift && root.shiftMode > 0
        colBackground: enabled ? Appearance.colors.colLayer1 : ColorUtils.transparentize(Appearance.colors.colLayer1)
        buttonRadius: Appearance.rounding.small
        implicitWidth: baseWidth * (widthMultiplier[shape] || 1)
        implicitHeight: baseHeight
        Layout.fillWidth: shape === "space" || shape === "expand"
        downAction: () => root.press(key.modelData)

        contentItem: StyledText {
            anchors.fill: parent
            font.family: (key.isBackspace || key.isEnter) ? Appearance.font.family.iconMaterial : Appearance.font.family.main
            font.pixelSize: (key.isBackspace || key.isEnter) ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.large
            horizontalAlignment: Text.AlignHCenter
            color: key.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            text: key.isBackspace ? "backspace" : key.isEnter ? "subdirectory_arrow_left" :
                (key.isShift && root.shiftMode === 2) ? (key.modelData.labelCaps || key.label) :
                root.shiftMode > 0 ? (key.modelData.labelShift || key.label) : key.label
        }
    }
}
