import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// Top-level shell: a NavBar docked to one edge over a StackLayout of pages.
// Each page is its own sibling .qml file in this directory. Add a page by
// dropping a new file next to this one, adding it to QML_FILES in
// CMakeLists.txt, and adding both a `pages` entry and the page itself below,
// in the same order.
Item {
    id: root

    // Where the navigation bar goes: "left", "right", "top" or "bottom".
    property string navPosition: "left"

    signal menuRequested

    readonly property var pages: [
        {
            icon: "mdi:view-dashboard",
            label: qsTr("Overview")
        },
        {
            icon: "mdi:lightning-bolt",
            label: qsTr("Energy")
        }
    ]
    readonly property real navMargin: 8

    NavBar {
        id: navBar
        position: root.navPosition
        items: root.pages
        onMenuRequested: root.menuRequested()

        // Centered along its edge.
        x: root.navPosition === "left" ? root.navMargin : root.navPosition === "right" ? root.width - width - root.navMargin : (root.width - width) / 2
        y: root.navPosition === "top" ? root.navMargin : root.navPosition === "bottom" ? root.height - height - root.navMargin : (root.height - height) / 2
    }

    StackLayout {
        anchors.fill: parent
        anchors.leftMargin: root.navPosition === "left" ? navBar.width + root.navMargin : 0
        anchors.rightMargin: root.navPosition === "right" ? navBar.width + root.navMargin : 0
        anchors.topMargin: root.navPosition === "top" ? navBar.height + root.navMargin : 0
        anchors.bottomMargin: root.navPosition === "bottom" ? navBar.height + root.navMargin : 0
        currentIndex: navBar.currentIndex

        PageOverview {}
        PageEnergy {}
    }
}
