import QtQuick
import qs.config
import qs.services
import qs.widgets

// Pixel robot with an antenna; bobs gently (stepped) while OpenCode works.
// Mac look (Skin.mac): the "bot" line icon — tinted by the state, or with
// `mono` one colour (`monoColor`: the menu bar's ink) and a state dot.
Item {
    id: root

    property int pixel: Theme.u
    property string state: OpencodeState.state
    property bool horns: Angel.demon || Theme.hell
    property bool hellLook: Theme.hell
    property int bob: 0

    property bool mono: false
    property color monoColor: Skin.text
    readonly property bool mac: Skin.mac && !hellLook

    readonly property var rows: horns ? hornRows : normalRows

    readonly property var normalRows: [
        "....oo....",
        "....##....",
        "..######..",
        ".########.",
        "#fwwffwwf#",
        "#fwwffwwf#",
        "#ffffffff#",
        "#fxxxxxxf#",
        ".########.",
        "..#....#.."
    ]

    readonly property var hornRows: [
        ".r......r.",
        ".rr####rr.",
        "..######..",
        ".########.",
        "#fwwffwwf#",
        "#fwwffwwf#",
        "#ffffffff#",
        "#fxxxxxxf#",
        ".########.",
        "..#....#.."
    ]

    implicitWidth: mac ? pixel * 10 : face.width
    implicitHeight: mac ? pixel * 10 : face.height + pixel

    Loader {
        active: root.mac
        visible: active
        sourceComponent: Item {
            width: root.pixel * 10
            height: root.pixel * 10
            MacIcon {
                name: "bot"
                size: root.pixel * 9
                stroke: 2
                color: root.mono ? root.monoColor : root.state === "none" ? Skin.textDim : OpencodeState.stateColor(root.state, Theme)
                opacity: root.state === "none" ? 0.7 : 1
            }
            Rectangle {
                visible: root.mono && root.state !== "none"
                width: Math.max(4, root.pixel * 2.6)
                height: width
                radius: width / 2
                x: parent.width - width * 0.8
                y: parent.height - width * 0.9
                color: OpencodeState.stateColor(root.state, Theme)
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.state === "working" && !root.mac
        onTriggered: root.bob = root.bob ? 0 : 1
        onRunningChanged: if (!running)
            root.bob = 0
    }
    PxIcon {
        id: face
        visible: !root.mac
        y: root.bob * root.pixel
        bitmap: root.rows
        pixel: root.pixel
        ink: root.hellLook ? Theme.hellRim : (Theme.dark ? Theme.text : Theme.edge)
        fill: root.hellLook ? Theme.hellEmber : Theme.accent
        fill2: root.hellLook ? OpencodeState.hellStateColor(root.state, Theme) : root.state === "none" ? Theme.textDim : OpencodeState.stateColor(root.state, Theme)
        light: root.hellLook ? Theme.hellText : Qt.color("white")
        body: root.hellLook ? Theme.hellFace : (Theme.dark ? Theme.faceAlt : Theme.sunken)
        bad: root.hellLook ? Theme.hellBlood : Theme.danger
        opacity: root.state === "none" ? 0.7 : 1
    }
}
