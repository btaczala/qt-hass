import QtQuick

// One page of a Dashboard: the title and icon of its NavBar button, around
// whatever the page shows, which fills it -- declared inline or loaded from
// `source`:
//
//     DashboardPage {
//         title: qsTr("Cameras")
//         icon: "mdi:cctv"
//         MyCameras { anchors.fill: parent }
//     }
//     DashboardPage {
//         title: qsTr("Living room")
//         icon: "mdi:sofa"
//         source: "LivingRoom.qml"
//     }
//
// Only a page with a `source` can be navigated to (a "navigate" action, see
// Dashboard.showPage). Like every page it's created with the dashboard, not
// on navigation. The file has to be listed in the dashboard's qmldir, which is
// what gets it downloaded.
Item {
    id: root

    property string title
    // MDI name, e.g. "mdi:cctv".
    property string icon
    // A QML file relative to where the page is declared; empty for inline
    // content.
    property string source

    // `source` resolved where the page is declared: a plain binding to
    // Loader.source would resolve it next to this file, inside the app.
    readonly property url resolvedSource: root.source !== "" ? Qt.resolvedUrl(root.source, root) : ""

    Loader {
        anchors.fill: parent
        active: root.source !== ""
        source: root.resolvedSource
    }
}
