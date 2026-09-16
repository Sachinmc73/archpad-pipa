/*
    SPDX-FileCopyrightText: 2016 Boudhayan Gupta <bgupta@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

FocusScope {
    id: sceneBackground

    property var sceneBackgroundType
    property alias sceneBackgroundColor: sceneColorBackground.color
    property alias sceneBackgroundImage: sceneImageBackground.source

    Rectangle {
        id: sceneColorBackground
        anchors.fill: parent
    }

    Image {
        id: sceneImageBackground
        anchors.fill: parent
        sourceSize.width: parent.width
        sourceSize.height: parent.height
        fillMode: Image.PreserveAspectCrop
        smooth: true;
        onStatusChanged: {
            if (status === Image.Error && source != "file:///usr/share/wallpapers/ArchPad/contents/images/2880x1800.png") {
                source = "file:///usr/share/wallpapers/ArchPad/contents/images/2880x1800.png";
            }
        }
    }

    states: [
        State {
            name: "imageBackground"
            when: sceneBackgroundType === "image"
            PropertyChanges {
                sceneColorBackground.visible: false
            }
            PropertyChanges {
                sceneImageBackground.visible: true
            }
        },
        State {
            name: "colorBackground"
            when: sceneBackgroundType !== "image"
            PropertyChanges {
                sceneColorBackground.visible: true
            }
            PropertyChanges {
                sceneImageBackground.visible: false
            }
        }
    ]
}
