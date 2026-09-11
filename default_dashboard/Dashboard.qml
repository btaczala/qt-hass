import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Top-level shell: a TabBar-driven StackView. Each tab is its own sibling
// .qml file in this directory, resolved relative to this file so it works
// loaded straight off disk (see Controler::pathFor). Add a page by dropping
// a new file next to this one and listing it in `pages` below.
ColumnLayout {
    id: root
    Material.theme: Material.Dark
    spacing: 0

    readonly property var pages: [
        Qt.resolvedUrl("PageOverview.qml"),
        Qt.resolvedUrl("PageTiles.qml"),
        Qt.resolvedUrl("PageLights.qml")
    ]

    // Pages are created once and kept alive for the app's lifetime, then
    // reused on every later visit. Replacing with a freshly created
    // Component on every tab switch was destroying and recreating every
    // Tile/Light on the outgoing page while the incoming page's items were
    // still being created -- confirmed on a real device to crash the QML
    // engine's GC after a handful of switches. StackView doesn't destroy an
    // Item instance it didn't create itself (only a Component/url it was
    // given), so reusing the same Item here means a page's entities are
    // registered with HassAPI exactly once, never torn down just for
    // switching tabs.
    property var pageItems: ({})

    function showPage(index) {
        let item = root.pageItems[index];
        if (!item) {
            const component = Qt.createComponent(root.pages[index]);
            if (component.status === Component.Error) {
                console.error("Failed to load page", root.pages[index], component.errorString());
                return;
            }
            item = component.createObject(root);
            root.pageItems[index] = item;
        }
        stackView.replace(null, item);
    }

    // Docked at the top, not the bottom: Android's immersive-sticky
    // navigation bar lives at the bottom edge and reappears on a touch
    // there, swallowing the first tap instead of passing it to the app --
    // confirmed on a real device, where a bottom TabBar was unreliable to
    // tap at all.
    TabBar {
        id: tabBar
        Layout.fillWidth: true

        onCurrentIndexChanged: root.showPage(currentIndex)

        TabButton {
            text: qsTr("Overview")
        }
        TabButton {
            text: qsTr("Tiles")
        }
        TabButton {
            text: qsTr("Lights")
        }
    }

    StackView {
        id: stackView
        Layout.fillWidth: true
        Layout.fillHeight: true

        Component.onCompleted: root.showPage(0)
    }
}
