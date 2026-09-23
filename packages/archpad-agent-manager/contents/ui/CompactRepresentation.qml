/* CompactRepresentation.qml
 * System tray icon: static monochrome bot when idle, animated bot + count when active
 * Proven debounce pattern from upstream kdeconnect applet.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot
    required property PlasmoidItem plasmoidItem
    readonly property var root: plasmoidItem

    Layout.minimumWidth: Kirigami.Units.iconSizes.smallMedium
    Layout.preferredWidth: contentRow.implicitWidth
    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: (compactRoot.root && compactRoot.root.currentBotIcon) ? compactRoot.root.currentBotIcon : ""
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            isMask: true
            color: Kirigami.Theme.textColor
        }

        PlasmaComponents3.Label {
            text: (compactRoot.root && compactRoot.root.activeCount > 0) ? compactRoot.root.activeCount : ""
            visible: compactRoot.root ? (compactRoot.root.activeCount > 0) : false
            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 1)
            font.bold: true
            color: "#2ec27e"
        }
    }

    MouseArea {
        anchors.fill: parent

        property bool wasExpanded: false

        onPressed: {
            wasExpanded = compactRoot.plasmoidItem ? compactRoot.plasmoidItem.expanded : false;
        }

        onClicked: {
            if (compactRoot.plasmoidItem) {
                compactRoot.plasmoidItem.expanded = !wasExpanded;
            }
        }
    }
}
