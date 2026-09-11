import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// Base for a control stacked under a Tile -- the counterpart of a Lovelace tile
// card feature. List instances in Tile.features; the tile assigns `tile` and
// reparents them once it is complete.
//
// Bind declaratively off `tile` and `stateObj` only. `tile` is still null while
// a feature is being created, its own Component.onCompleted included, so an
// imperative read there sees nothing and the feature silently stays blank.
Item {
    id: root

    property Tile tile: null

    readonly property var stateObj: root.tile?.entity_data ?? null
    readonly property var attributes: root.stateObj?.attributes ?? ({})
    readonly property string domain: root.tile?.domain ?? ""

    // Lovelace's isSupported(): an unsupported feature takes no space at all,
    // since layouts skip invisible items.
    property bool supported: true

    visible: root.supported
    enabled: !(root.tile?.isUnavailable ?? true)

    Layout.fillWidth: true
    Layout.topMargin: 12
    implicitHeight: 42
}
