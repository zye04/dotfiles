import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

// local-suite: small rotating dotted globe in the theme's accent colour.
// follow: true (prompt area) shows the local model's state and is clickable:
//   not loaded -> dim, still      loading -> slow spin + breathing
//   ready      -> slow spin       generating -> fast spin, brighter
//   garbage output detected -> error colour for a moment
// follow: false (message bullets): still, or spinning while `spinning` is set.
Item {
    id: root
    property real size: 18
    property bool follow: true
    property bool spinning: false
    readonly property string modelState: follow ? Ai.localModelState : "ready" // off | starting | ready
    readonly property bool busy: follow ? Ai.busy : spinning
    property bool errorFlash: false

    implicitWidth: size
    implicitHeight: size

    // Theme colours only, so it follows the wallpaper like the rest of the shell.
    readonly property color dotColor: errorFlash ? Appearance.m3colors.m3error
        : modelState === "off" && !busy ? Appearance.colors.colSubtext
        : Appearance.colors.colPrimary
    readonly property real spinSpeed: busy ? 2.4 : !follow ? 0 : modelState === "starting" ? 0.9 : modelState === "ready" ? 0.35 : 0 // rad/s
    readonly property bool animating: spinSpeed > 0 || errorFlash

    property real angle: 0.6
    property real breathe: 1

    // Points spread evenly over a sphere (Fibonacci lattice), computed once.
    readonly property var points: {
        const n = root.size < 14 ? 48 : 90, pts = [], golden = Math.PI * (3 - Math.sqrt(5));
        for (let i = 0; i < n; i++) {
            const y = 1 - (i / (n - 1)) * 2, r = Math.sqrt(1 - y * y), t = golden * i;
            pts.push([Math.cos(t) * r, y, Math.sin(t) * r]);
        }
        return pts;
    }

    onDotColorChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Connections {
        target: Ai
        enabled: root.follow
        function onGarbageDetected() {
            root.errorFlash = true;
            errorTimer.restart();
        }
    }
    Timer {
        id: errorTimer
        interval: 2500
        onTriggered: root.errorFlash = false
    }

    Timer { // ~30 fps, only while something moves
        interval: 33
        repeat: true
        running: root.animating && root.visible
        onTriggered: {
            root.angle += root.spinSpeed * interval / 1000;
            root.breathe = root.modelState === "starting" && !root.busy ? 0.85 + 0.15 * Math.sin(Date.now() / 250) : 1;
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2, radius = (width / 2 - 1) * root.breathe;
            const cosA = Math.cos(root.angle), sinA = Math.sin(root.angle);
            const tilt = 0.35, cosT = Math.cos(tilt), sinT = Math.sin(tilt);
            const dim = root.modelState === "off" && !root.busy;
            ctx.fillStyle = root.dotColor;
            for (const p of root.points) {
                // spin around Y, then tilt around X
                const x = p[0] * cosA + p[2] * sinA;
                const z0 = -p[0] * sinA + p[2] * cosA;
                const y = p[1] * cosT - z0 * sinT;
                const z = p[1] * sinT + z0 * cosT; // +1 = facing the viewer
                const depth = (z + 1) / 2;
                ctx.globalAlpha = (dim ? 0.12 : 0.18) + (dim ? 0.38 : 0.82) * depth;
                const dot = 0.45 + 0.75 * depth;
                ctx.beginPath();
                ctx.arc(c + x * radius, c + y * radius, dot, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }

    MouseArea {
        id: mouse
        enabled: root.follow
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.modelState === "starting" ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (root.modelState === "ready") Ai.unloadLocalModel();
            else if (root.modelState === "off") Ai.wakeLocalModel();
        }
    }

    StyledToolTip {
        extraVisibleCondition: false
        alternativeVisibleCondition: root.follow && mouse.containsMouse
        text: root.busy ? Translation.tr("Generating…")
            : root.modelState === "ready" ? Translation.tr("Ready. Click to unload and free VRAM\nUnloads by itself after 5 min idle")
            : root.modelState === "starting" ? Translation.tr("Loading the model (~5-10 s)")
            : Translation.tr("Not loaded. Click (or send a message) to load it")
    }
}
