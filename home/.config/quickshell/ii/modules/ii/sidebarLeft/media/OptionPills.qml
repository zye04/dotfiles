import qs.services
import qs.modules.common
import QtQuick
import "MediaCopy.js" as C

Flow {
    id: root
    readonly property string m: MediaGen.mode()
    readonly property bool showShape: (m === "t2i" || m === "t2v" || m === "long") && MediaGen.srcPath === ""
    readonly property bool showLength: MediaGen.kind === "video" && m !== "enhance"
    readonly property bool showScale: m === "upscale"
    readonly property bool showQuality: m !== "upscale" && m !== "enhance"
    visible: showShape || showLength || showScale || showQuality
    spacing: 6
    MediaChoice { visible: root.showShape; label: "Shape"; selectedValue: MediaGen.shape
        options: C.SHAPES.map(s => [s[0], s[0], s[1]]); onPicked: v => MediaGen.shape = v }
    MediaChoice { visible: root.showLength; label: "Length"; selectedValue: MediaGen.lengthS
        options: C.LENGTHS.map(l => [l[0], l[0] + " s", l[1]]); onPicked: v => MediaGen.setLength(v) }
    MediaChoice { visible: root.showScale; label: "Scale"; selectedValue: MediaGen.scale
        options: [[1.5, "1.5×", ""], [2.0, "2×", ""]]; onPicked: v => MediaGen.scale = v }
    MediaChoice { visible: root.showQuality; label: "Quality"; selectedValue: MediaGen.quality
        options: ["draft", "balanced", "realistic"].map(q => [q, q.charAt(0).toUpperCase() + q.slice(1), MediaGen.qualityHint(q)])
        onPicked: v => MediaGen.quality = v }
}
