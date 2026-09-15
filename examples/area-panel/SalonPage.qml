import QtQuick
import QtQuick.Controls

// The living room's page, which the Salon area card navigates to (as
// Home Assistant's rooms-salon view). Empty for now.
Item {
    Label {
        anchors.centerIn: parent
        text: qsTr("Salon")
        font.pixelSize: 32
    }
}
