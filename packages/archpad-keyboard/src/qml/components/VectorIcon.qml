import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string name: ""
    property color color: theme.textColor
    property real strokeWidth: 2.0
    property color fillColor: "transparent"

    readonly property bool isArrow: name.startsWith("arrow-")

    width: 18
    height: 18

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.width / 24.0

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.isArrow ? 1.2 : root.strokeWidth
            fillColor: root.isArrow ? root.color : root.fillColor
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: {
                    switch (root.name) {
                    case "arrow-left":
                        return "M17 5 L5 12 L17 19 Z"
                    case "arrow-right":
                        return "M7 5 L19 12 L7 19 Z"
                    case "arrow-up":
                        return "M5 17 L12 5 L19 17 Z"
                    case "arrow-down":
                        return "M5 7 L12 19 L19 7 Z"
                    case "push-up":
                        // Ceiling bar + upward arrow
                        return "M4 4 h16 M12 20 V8 M7 13 l5-5 5 5"
                    case "pop-out":
                    case "floating":
                        // Pop-out / Detach window
                        return "M18 13 v6 a2 2 0 0 1-2 2 H5 a2 2 0 0 1-2-2 V8 a2 2 0 0 1 2-2 h6 M15 3 h6 v6 M10 14 L21 3"
                    case "dock-bottom":
                        // Ground bar + downward arrow
                        return "M4 20 h16 M12 4 v12 M7 11 l5 5 5-5"
                    case "sun":
                        // Sun circle + 8 rays
                        return "M12 8 a4 4 0 1 0 0.001 0 M12 2 v2 M12 20 v2 M4.93 4.93 l1.41 1.41 M17.66 17.66 l1.41 1.41 M2 12 h2 M20 12 h2 M4.93 19.07 l1.41-1.41 M17.66 6.34 l1.41-1.41"
                    case "moon":
                        // Crescent moon
                        return "M21 12.79 A9 9 0 1 1 11.21 3 A7 7 0 0 0 21 12.79 z"
                    case "theme-system":
                        // Auto / System contrast circle (half-solid)
                        return "M12 3 A9 9 0 1 0 12 21 A9 9 0 0 0 12 3 M12 3 V21"
                    case "volume-on":
                        // Speaker + sound waves
                        return "M11 5 L6 9 H2 v6 h4 l5 4 V5 z M15.54 8.46 a5 5 0 0 1 0 7.07 M19.07 4.93 a10 10 0 0 1 0 14.14"
                    case "volume-off":
                        // Speaker + mute cross
                        return "M11 5 L6 9 H2 v6 h4 l5 4 V5 z M22 9 l-6 6 M16 9 l6 6"
                    case "settings":
                        // Clean gear
                        return "M12 15 a3 3 0 1 0 0-6 a3 3 0 0 0 0 6 z M19.4 15 a1.65 1.65 0 0 0 .33 1.82 l.06.06 a2 2 0 0 1-2.83 2.83 l-.06-.06 a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51 V21 a2 2 0 0 1-4 0 v-.09 A1.65 1.65 0 0 0 9 19.4 a1.65 1.65 0 0 0-1.82.33 l-.06.06 a2 2 0 0 1-2.83-2.83 l.06-.06 a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1 H3 a2 2 0 0 1 0-4 h.09 A1.65 1.65 0 0 0 4.6 9 a1.65 1.65 0 0 0-.33-1.82 l-.06-.06 a2 2 0 0 1 2.83-2.83 l.06.06 a1.65 1.65 0 0 0 1.82.33 H9 a1.65 1.65 0 0 0 1-1.51 V3 a2 2 0 0 1 4 0 v.09 a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33 l.06-.06 a2 2 0 0 1 2.83 2.83 l-.06.06 a1.65 1.65 0 0 0-.33 1.82 V9 a1.65 1.65 0 0 0 1.51 1 H21 a2 2 0 0 1 0 4 h-.09 a1.65 1.65 0 0 0-1.51 1 z"
                    case "split":
                        // Split keyboard: two clusters separated by gap
                        return "M4 5 h6 a1 1 0 0 1 1 1 v12 a1 1 0 0 1-1 1 H4 a1 1 0 0 1-1-1 V6 a1 1 0 0 1 1-1 z M14 5 h6 a1 1 0 0 1 1 1 v12 a1 1 0 0 1-1 1 h-6 a1 1 0 0 1-1-1 V6 a1 1 0 0 1 1-1 z M6 9 h2 M6 13 h2 M16 9 h2 M16 13 h2"
                    case "pin":
                        // Pinned pushpin
                        return "M16 4 v4 l2 3 v2 h-5 v7 l-1 1 l-1-1 v-7 H6 v-2 l2-3 V4 z"
                    case "height":
                        // Vertical height adjust arrows
                        return "M12 3 v18 M7 8 l5-5 5 5 M7 16 l5 5 5-5"
                    case "resize-corner":
                        // Diagonal corner grip lines
                        return "M4 12 L12 4 M4 18 L18 4 M4 24 L24 4"
                    case "chevron-down":
                    case "hide":
                        // Downward chevron
                        return "M6 9 l6 6 6-6"
                    case "close":
                        // Clean X
                        return "M18 6 L6 18 M6 6 l12 12"
                    default:
                        return ""
                    }
                }
            }
        }
    }
}
