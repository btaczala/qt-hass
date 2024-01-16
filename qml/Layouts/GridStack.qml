import QtQuick
import QtQuick.Layouts

BaseLayout {
    id: root

    layout: GridLayout {
        id: grid
        anchors.fill: parent
        // anchors.leftMargin: 20
        columns: 3
    }
}
