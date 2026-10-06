import QtQuick
import QtQuick.Controls
import SddmComponents 2.0

Rectangle {
    id: root
    width: 2560
    height: 1440
    color: "#181818"

    readonly property color textColor: config.textColor || "#d6e3ff"
    readonly property string userName: userModel.lastUser || userModel.data(userModel.index(0, 0), Qt.UserRole + 1) || ""
    property int sessionIndex: sessionModel.lastIndex
    property bool keyboardVisible: false

    FontLoader { id: sans; source: "assets/GoogleSansFlex.ttf" }

    function doLogin() {
        error.text = ""
        sddm.login(root.userName, password.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            error.text = "Wrong password"
            shake.start()
        }
    }

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Number(config.dim || 0.35)
    }

    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: 260
        color: root.textColor
        font.family: sans.font.family
        font.weight: Font.Medium
        font.pixelSize: 88
        text: Qt.formatTime(new Date(), "hh:mm")
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clock.bottom
        anchors.topMargin: 4
        color: root.textColor
        font.family: sans.font.family
        font.weight: Font.Medium
        font.pixelSize: 23
        text: Qt.formatDate(new Date(), "dddd, MMMM dd")
        id: date
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "hh:mm")
            date.text = Qt.formatDate(new Date(), "dddd, MMMM dd")
        }
    }

    TextField {
        id: password
        width: 250
        height: 50
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        echoMode: TextInput.Password
        passwordCharacter: "●"
        horizontalAlignment: TextInput.AlignHCenter
        placeholderText: "Password"
        placeholderTextColor: Qt.alpha(root.textColor, 0.5)
        color: root.textColor
        font.family: sans.font.family
        font.pixelSize: 16
        focus: true
        background: Rectangle {
            radius: height / 2
            color: config.entryBackground || "#11001b3c"
            border.width: 2
            border.color: password.activeFocus ? Qt.alpha(root.textColor, 0.6) : (config.entryBorder || "#558e9099")
        }
        onAccepted: root.doLogin()
        Keys.onEscapePressed: text = ""

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: password; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
            NumberAnimation { target: password; property: "anchors.horizontalCenterOffset"; to: 8; duration: 80 }
            NumberAnimation { target: password; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
        }
    }

    // Same look as the lock screen's keyboard toggle (ii IconToolbarButton)
    RippleButton {
        id: keyboardToggle
        width: 40
        height: 40
        radius: height / 2
        anchors.right: password.left
        anchors.rightMargin: 10
        anchors.verticalCenter: password.verticalCenter
        toggled: root.keyboardVisible
        colBackgroundHover: osk.colKeyHover
        colBackgroundToggled: osk.colSecondaryContainer
        colBackgroundToggledHover: osk.colSecondaryContainerHover
        colRipple: osk.colKeyRipple
        colRippleToggled: osk.colSecondaryContainerRipple
        onClicked: root.keyboardVisible = !root.keyboardVisible

        Text {
            anchors.centerIn: parent
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            color: keyboardToggle.toggled ? osk.colOnSecondaryContainer : osk.colText
            text: "keyboard"
        }
    }

    Text {
        id: error
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: password.bottom
        anchors.topMargin: 16
        color: root.textColor
        font.family: sans.font.family
        font.pixelSize: 17
        text: keyboard.capsLock ? "Caps Lock is on" : ""
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        spacing: 8
        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "assets/archlinux-logo.svg"
            sourceSize.height: 20
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.textColor
            font.family: sans.font.family
            font.weight: Font.Medium
            font.pixelSize: 17
            text: root.userName + "@" + sddm.hostName
        }
    }

    Keyboard {
        id: osk
        visible: root.keyboardVisible
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 90
        target: password
        fontFamily: sans.font.family
        onAccepted: root.doLogin()
    }

    component Link: Text {
        signal clicked
        color: area.containsMouse ? root.textColor : Qt.alpha(root.textColor, 0.7)
        font.family: sans.font.family
        font.pixelSize: 17
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        spacing: 24
        Link { text: "Suspend"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
        Link { text: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        Link { text: "Shut down"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }

    Component.onCompleted: password.forceActiveFocus()
}
