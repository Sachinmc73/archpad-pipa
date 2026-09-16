/* CompactRepresentation.qml
 * System tray icon: static bot when idle, animated bot + count when active
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot
    property var plasmoidItem: null
    readonly property var root: plasmoidItem

    PlasmaComponents3.ToolButton {
        anchors.fill: parent
        checkable: true
        checked: compactRoot.plasmoidItem ? compactRoot.plasmoidItem.expanded : false
        onClicked: {
            if (compactRoot.plasmoidItem) {
                compactRoot.plasmoidItem.expanded = !compactRoot.plasmoidItem.expanded;
            }
        }

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Image {
                source: (compactRoot.root && compactRoot.root.currentBotIcon) ? compactRoot.root.currentBotIcon : ""
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            PlasmaComponents3.Label {
                text: (compactRoot.root && compactRoot.root.activeCount > 0) ? compactRoot.root.activeCount : ""
                visible: compactRoot.root ? (compactRoot.root.activeCount > 0) : false
                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 1)
                font.bold: true
                color: "#2ec27e"
            }
        }
    }
}
