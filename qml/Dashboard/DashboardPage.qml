import QtQuick

// One page of a Dashboard: the title and icon of its NavBar button, around
// whatever the page shows, which fills it:
//
//     DashboardPage {
//         title: qsTr("Cameras")
//         icon: "mdi:cctv"
//         MyCameras { anchors.fill: parent }
//     }
Item {
    property string title
    // MDI name, e.g. "mdi:cctv".
    property string icon
}
