import QtQuick
import Qt5Compat.GraphicalEffects

// Trimmed port of illogical-impulse's RippleButton (same animations; colors passed in).
Item {
    id: root
    signal pressed
    signal clicked
    property bool toggled: false
    property bool down: area.pressed
    property bool hovered: area.containsMouse
    property real radius: 12
    property color colBackground: "transparent"
    property color colBackgroundHover: colBackground
    property color colBackgroundToggled: colBackground
    property color colBackgroundToggledHover: colBackgroundToggled
    property color colRipple: "transparent"
    property color colRippleToggled: colRipple
    readonly property color rippleColor: toggled ? colRippleToggled : colRipple
    readonly property int rippleDuration: 1200
    default property alias content: contentHolder.data

    component RippleAnim: NumberAnimation {
        duration: root.rippleDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
    }
    component FastColor: ColorAnimation {
        duration: 200
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        color: root.toggled ? (root.hovered ? root.colBackgroundToggledHover : root.colBackgroundToggled)
            : (root.hovered ? root.colBackgroundHover : root.colBackground)
        Behavior on color { FastColor {} }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: root.radius
            }
        }

        Item {
            id: ripple
            width: 0
            height: 0
            opacity: 0
            visible: width > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.rippleColor }
                    GradientStop { position: 0.3; color: root.rippleColor }
                    GradientStop { position: 0.5; color: Qt.rgba(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, 0) }
                }
            }
            transform: Translate { x: -ripple.width / 2; y: -ripple.height / 2 }
        }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }

    SequentialAnimation {
        id: rippleAnim
        property real x
        property real y
        property real size
        PropertyAction { target: ripple; property: "x"; value: rippleAnim.x }
        PropertyAction { target: ripple; property: "y"; value: rippleAnim.y }
        PropertyAction { target: ripple; property: "opacity"; value: 1 }
        RippleAnim { target: ripple; properties: "width,height"; from: 0; to: rippleAnim.size }
    }
    RippleAnim {
        id: rippleFade
        duration: root.rippleDuration * 2
        target: ripple
        property: "opacity"
        to: 0
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => {
            root.pressed();
            const corners = [[0, 0], [width, 0], [0, height], [width, height]];
            rippleAnim.x = event.x;
            rippleAnim.y = event.y;
            rippleAnim.size = 2 * Math.max(...corners.map(([cx, cy]) => Math.hypot(cx - event.x, cy - event.y)));
            rippleFade.complete();
            rippleAnim.restart();
        }
        onReleased: {
            root.clicked();
            rippleFade.restart();
        }
        onCanceled: rippleFade.restart()
    }
}
