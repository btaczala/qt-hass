pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// A dashboard: its pages in a StackLayout, and a NavBar docked to one edge
// with a button per page (from each DashboardPage's title and icon) and one
// for the settings.
//
//     Dashboard {
//         pages: [
//             DashboardPage { title: qsTr("Overview"); icon: "mdi:view-dashboard"; MyOverview { anchors.fill: parent } },
//             DashboardPage { title: qsTr("Cameras"); icon: "mdi:cctv"; MyCameras { anchors.fill: parent } }
//         ]
//
//         // Anything else is part of the dashboard without being a page,
//         // e.g. a DashboardOverlay.
//         MyDoNotDisturb {}
//     }
//
// Every page is created with the dashboard and lives as long as it does, so
// its entities register with HassAPI exactly once. Don't go back to creating
// pages on each tab switch: an earlier StackView version that did crashed the
// QML engine's GC on a real device after a handful of switches.
Item {
    id: root

    // DashboardPages. list<Item>, not list<DashboardPage>: see Tile's features.
    property list<Item> pages
    // Where the navigation bar goes: "left", "right", "top" or "bottom". Set
    // by the app, from its settings.
    property string navPosition: "left"

    // What the screensaver shows under its clock while this dashboard is
    // loaded; nothing when empty. See WeatherSummary and EnergySummary.
    property string screensaverWeatherEntity
    property var screensaverEnergyEntities: null

    signal menuRequested

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
        children: root.pages
    }
}
