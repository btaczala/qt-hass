import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

// Top-level shell: a TabBar-driven StackLayout. Each tab is its own sibling
// .qml file in this directory. Add a page by dropping a new file next to this
// one, adding it to QML_FILES in CMakeLists.txt, and adding both a TabButton
// and the page itself below, in the same order.
ColumnLayout {
    id: root
    spacing: 0

    // Width of the space kept free at the TabBar's left end, where Main.qml's
    // drawer button sits on top of it.
    property real leadingInset: 0

    TabBar {
        id: tabBar
        Layout.fillWidth: true
        // Padding, not a layout margin: the tabs move right, but the TabBar's
        // background still spans the full width, behind the drawer button.
        leftPadding: root.leadingInset

        TabButton {
            text: qsTr("Overview")
        }
        TabButton {
            text: qsTr("Energy overview")
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabBar.currentIndex

        PageOverview {}
        PageEnergy {}
    }
}
