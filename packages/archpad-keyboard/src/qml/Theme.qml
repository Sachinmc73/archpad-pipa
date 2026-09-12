import QtQuick

QtObject {
    // Dynamic Mode: Synced with km.resolvedDark (Follow System, Light, or Dark)
    readonly property bool isDark: (typeof km !== "undefined") ? km.resolvedDark : true

    // Surface & Window Colors: Pure white background in Light mode
    readonly property color backgroundColor: isDark ? "#14171A" : "#FFFFFF"
    readonly property color surfaceColor: isDark ? "#1C1F24" : "#FFFFFF"
    readonly property color headerColor: isDark ? "#181B20" : "#F4F5F7"
    readonly property color borderColor: isDark ? "#282D34" : "#D1D5DB"
    readonly property color dividerColor: isDark ? "#22262C" : "#E5E7EB"

    // Key Colors: Matte silver keys (#E5E7EB / #D1D5DB) in Light mode
    readonly property color keyColor: isDark ? "#242830" : "#E5E7EB"
    readonly property color keySpecialColor: isDark ? "#1C2026" : "#D1D5DB"
    readonly property color keyPressedColor: isDark ? "#363C47" : "#9CA3AF"
    readonly property color keyActiveColor: isDark ? "#2F81F7" : "#1A73E8"
    readonly property color keyAccentColor: isDark ? "#238636" : "#1E8E3E"
    readonly property color keyDeleteColor: isDark ? "#30363D" : "#D1D5DB"

    // Typography: Deep high-contrast charcoal (#111827) in Light mode
    readonly property color textColor: isDark ? "#F0F6FC" : "#111827"
    readonly property color textSecondaryColor: isDark ? "#8B949E" : "#4B5563"
    readonly property color textDimColor: isDark ? "#586069" : "#6B7280"
    readonly property color textActiveColor: "#FFFFFF"

    readonly property string fontFamily: "Inter, Noto Sans, Cantarell, sans-serif"
    readonly property int fontSizeNormal: 16
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeHeader: 14
    readonly property int fontSizeLarge: 18

    // Geometry & Layout
    readonly property real keyRadius: 6
    readonly property real cardRadius: 10
    readonly property real keyMargin: 3
    readonly property real headerHeight: 34
}
