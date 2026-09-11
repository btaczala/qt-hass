import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// Base for a control shown on a Tile -- the counterpart of a Lovelace tile card
// feature. List instances in Tile.features; the tile assigns `tile` and
// reparents them once it is complete: stacked below its header, or the first
// supported one into the header row when the tile is too short for the stack.
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

    // Lovelace's isSupported().
    property bool supported: true

    readonly property bool isInline: root.tile?.inlineFeature === root
    // Inline, a feature takes half the row beside the tile's name, as in Lovelace.
    readonly property real inlineWidth: ((root.tile?.availableWidth ?? 0) - (root.tile?.featureSpacing ?? 0)) / 2

    // Layouts skip invisible items, so neither an unsupported feature nor one an
    // inline tile has no room for takes any space.
    visible: root.supported && (root.isInline || !(root.tile?.inlineFeatures ?? false))
    enabled: !(root.tile?.isUnavailable ?? true)

    Layout.fillWidth: !root.isInline
    Layout.preferredWidth: root.isInline ? root.inlineWidth : -1
    Layout.minimumWidth: root.isInline ? root.inlineWidth : 0
    Layout.topMargin: root.isInline ? 0 : root.tile?.featureSpacing ?? 0
    implicitHeight: 42
}
