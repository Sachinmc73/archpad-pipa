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
    required property PlasmoidItem plasmoidItem

    RowLayout {
        anchors.centerIn: parent
        spacing: 2

        // Bot icon — cycles frames when active
        Image {
            id: botIcon
            source: root.currentBotIcon
            Layout.preferredWidth: Math.min(compactRoot.height, Kirigami.Units.iconSizes.smallMedium)
            Layout.preferredHeight: Layout.preferredWidth
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        // Active session count badge — only visible when > 0
        PlasmaComponents3.Label {
            text: root.activeCount > 0 ? root.activeCount : ""
            visible: root.activeCount > 0
            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 1)
            font.bold: true
            color: "#2ec27e"
        }
    }

    // Toggle popup on tap
    TapHandler {
        onTapped: compactRoot.plasmoidItem.expanded = !compactRoot.plasmoidItem.expanded
    }
}
