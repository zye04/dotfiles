import qs.services
import qs.modules.common
import QtQuick
import "MediaCopy.js" as C

Flow {
    id: root
    readonly property string m: MediaGen.mode()
    readonly property bool showShape: m === "t2i"
    readonly property bool showScale: m === "upscale"
    readonly property bool showQuality: m !== "upscale" && m !== "interp"
    readonly property bool showFactor: m === "interp"
    readonly property bool showLength: m === "i2v"
    visible: showShape || showScale || showQuality || showFactor || showLength
    spacing: 6
    MediaChoice { visible: root.showShape; label: "Shape"; selectedValue: MediaGen.shape
        options: C.SHAPES.map(s => [s[0], s[0], s[1]]); onPicked: v => MediaGen.shape = v }
    MediaChoice { visible: root.showScale; label: "Scale"; selectedValue: MediaGen.scale
        options: [[1.5, "1.5×", ""], [2.0, "2×", ""]]; onPicked: v => MediaGen.scale = v }
    MediaChoice { visible: root.showFactor; label: "Frames"; selectedValue: MediaGen.factor
        options: [2, 3].map(f => [f, f + "×", MediaGen.interpHint(f)]); onPicked: v => MediaGen.factor = v }
    MediaChoice { visible: root.showLength; label: "Length"; selectedValue: MediaGen.clipLength
        options: (MediaGen.presets?.video?.lengths ?? [5]).map(l => [l, l + " s", l > 5 ? l / 5 + " parts, joined" : ""]); onPicked: v => MediaGen.clipLength = v }
    MediaChoice { visible: root.showQuality; label: "Quality"; selectedValue: MediaGen.quality
        options: ["draft", "balanced", "realistic"].map(q => [q, q.charAt(0).toUpperCase() + q.slice(1), MediaGen.qualityHint(q)])
        onPicked: v => MediaGen.quality = v }
}
