import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Mouse-only keyboard styled after the illogical-impulse OSK.
// Writes into `target` directly, so the greeter's XKB layout doesn't matter.
Item {
    id: root
    property var target
    property string fontFamily
    signal accepted

    property int shiftMode: 0 // 0 off, 1 one-shot, 2 caps
    property double lastShiftTap: 0

    // Derived the same way as ii's Appearance.qml (automatic transparency: contentTransparency 0.9)
    // from the matugen palette in generated/theme.conf
    readonly property real contentTransparency: 0.9
    readonly property color colPrimary: config.m3primary || "#a8c8ff"
    readonly property color colOnPrimary: config.m3onPrimary || "#06305f"
    readonly property color colText: config.m3onSurfaceVariant || "#c4c6cf"
    readonly property color colSecondaryContainer: config.m3secondaryContainer || "#3e4758"
    readonly property color colOnSecondaryContainer: config.m3onSecondaryContainer || "#d9e3f8"
    readonly property color colPanel: mix(config.m3background || "#111318", colPrimary, 0.99)
    readonly property color colKey: solveOverlayColor(colPanel, config.m3surfaceContainerLow || "#191c20", 1 - contentTransparency)
    readonly property color colKeyHover: transparentize(mix(colKey, colText, 0.92), contentTransparency)
    readonly property color colKeyRipple: transparentize(mix(colKey, colText, 0.85), contentTransparency)
    readonly property color colPrimaryHover: mix(colPrimary, colKeyHover, 0.87)
    readonly property color colPrimaryRipple: mix(colPrimary, colKeyRipple, 0.7)
    readonly property color colSecondaryContainerHover: mix(colSecondaryContainer, colOnSecondaryContainer, 0.9)
    readonly property color colSecondaryContainerRipple: mix(colSecondaryContainer, colOnSecondaryContainer, 0.54)

    function mix(a, b, p) {
        a = Qt.color(a); b = Qt.color(b);
        return Qt.rgba(p * a.r + (1 - p) * b.r, p * a.g + (1 - p) * b.g, p * a.b + (1 - p) * b.b, p * a.a + (1 - p) * b.a);
    }
    function transparentize(c, p) {
        c = Qt.color(c);
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - p));
    }
    function solveOverlayColor(base, target, opacity) {
        base = Qt.color(base); target = Qt.color(target);
        const f = (t, b) => Math.max(0, Math.min(1, (t - b * (1 - opacity)) / opacity));
        return Qt.rgba(f(target.r, base.r), f(target.g, base.g), f(target.b, base.b), opacity);
    }

    readonly property var rows: [
        [["`", "~"], ["1", "!"], ["2", "@"], ["3", "#"], ["4", "$"], ["5", "%"], ["6", "^"], ["7", "&"], ["8", "*"], ["9", "("], ["0", ")"], ["-", "_"], ["=", "+"], ["Backspace", "", "expand"]],
        [["", "", "tab"], ["q", "Q"], ["w", "W"], ["e", "E"], ["r", "R"], ["t", "T"], ["y", "Y"], ["u", "U"], ["i", "I"], ["o", "O"], ["p", "P"], ["[", "{"], ["]", "}"], ["\\", "|", "expand"]],
        [["", "", "empty"], ["", "", "empty"], ["a", "A"], ["s", "S"], ["d", "D"], ["f", "F"], ["g", "G"], ["h", "H"], ["j", "J"], ["k", "K"], ["l", "L"], [";", ":"], ["'", "\""], ["Enter", "", "expand"]],
        [["Shift", "", "shift"], ["z", "Z"], ["x", "X"], ["c", "C"], ["v", "V"], ["b", "B"], ["n", "N"], ["m", "M"], [",", "<"], [".", ">"], ["/", "?"], ["Shift", "", "expand"]],
        [["Space", "", "space"]]
    ]

    implicitWidth: background.implicitWidth + 20
    implicitHeight: background.implicitHeight + 20

    function press(label, shifted) {
        if (label === "Shift") {
            const now = Date.now();
            if (shiftMode === 1 && now - lastShiftTap < 300) shiftMode = 2;
            else shiftMode = shiftMode === 0 ? 1 : 0;
            lastShiftTap = now;
        } else if (label === "Backspace") {
            target.text = target.text.slice(0, -1);
        } else if (label === "Enter") {
            accepted();
        } else {
            target.text += label === "Space" ? " " : (shiftMode > 0 ? shifted : label);
            if (shiftMode === 1) shiftMode = 0;
        }
    }

    RectangularShadow {
        anchors.fill: background
        radius: background.radius
        blur: 9
        offset: Qt.vector2d(0, 1)
        spread: 1
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        id: background
        anchors.centerIn: parent
        color: root.colPanel
        radius: 18
        implicitWidth: keyRows.implicitWidth + 20
        implicitHeight: keyRows.implicitHeight + 20

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
                        delegate: RippleButton {
                            id: key
                            required property var modelData
                            readonly property string label: modelData[0]
                            readonly property string shifted: modelData[1]
                            readonly property string shape: modelData[2] || "normal"
                            readonly property bool isIcon: label === "Backspace" || label === "Enter"
                            readonly property bool spacer: shape === "empty" || shape === "tab"
                            toggled: label === "Shift" && root.shiftMode > 0

                            implicitWidth: 45 * ({ "tab": 1.6, "shift": 2.5 }[shape] || 1)
                            implicitHeight: 45
                            Layout.fillWidth: shape === "space" || shape === "expand"
                            radius: 12
                            opacity: spacer ? 0 : 1
                            enabled: !spacer
                            colBackground: root.colKey
                            colBackgroundHover: root.colKeyHover
                            colBackgroundToggled: root.colPrimary
                            colBackgroundToggledHover: root.colPrimaryHover
                            colRipple: root.colKeyRipple
                            colRippleToggled: root.colPrimaryRipple
                            onPressed: root.press(key.label, key.shifted)

                            Text {
                                anchors.centerIn: parent
                                font.family: key.isIcon ? "Material Symbols Rounded" : root.fontFamily
                                font.pixelSize: key.isIcon ? 22 : 17
                                color: key.toggled ? root.colOnPrimary : root.colText
                                text: key.label === "Backspace" ? "backspace"
                                    : key.label === "Enter" ? "subdirectory_arrow_left"
                                    : (key.label === "Shift" && root.shiftMode === 2) ? "Caps"
                                    : root.shiftMode > 0 && key.shifted ? key.shifted : key.label
                            }
                        }
                    }
                }
            }
        }
    }
}
