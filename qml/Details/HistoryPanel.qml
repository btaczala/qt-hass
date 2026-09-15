pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Base for an entity's history in the details overlay: tabs for the last 24
// hours or the 24 hours ending 1, 2, 3 or 7 days ago, the window's dates and
// the unit above whatever chart the subtype declares (appended below them).
//
// The subtype loads the window in loadRequested(request), then calls
// done(request, points) or failed(request, message); replies to a superseded
// request are dropped there. history() fetches the entity's states.
ColumnLayout {
    id: root

    required property string entityId
    readonly property alias entity: hassEntity

    property string unit
    // How often the last 24 hours are loaded again.
    property int refreshInterval: 5 * 60000

    // Days the shown 24 hours end before now.
    readonly property var offsets: [0, 1, 2, 3, 7]
    readonly property int offsetDays: root.offsets[tabs.currentIndex]

    property real windowEnd: Date.now()
    readonly property real windowStart: root.windowEnd - 24 * 3600000

    // Whatever the subtype's chart shows; empty means no history.
    property var points: []
    property bool loading: false
    property string error
    property int request: 0

    // What to show over the chart instead of data; empty while there is data.
    readonly property string placeholder: root.loading ? qsTr("Loading…") : root.error !== "" ? root.error : root.points.length === 0 ? qsTr("No history") : ""

    // A subtype may pick its data source from the attributes, so not before
    // the entity's state is known.
    readonly property bool ready: hassEntity.state !== ""

    signal loadRequested(int request)

    function fetch() {
        if (!root.ready)
            return;
        root.windowEnd = Date.now() - root.offsetDays * 24 * 3600000;
        root.loading = true;
        root.error = "";
        root.loadRequested(++root.request);
    }

    function done(request: int, points: var) {
        if (request !== root.request)
            return;
        root.points = points;
        root.loading = false;
    }

    function failed(request: int, message: string) {
        if (request !== root.request)
            return;
        root.points = [];
        root.error = message;
        root.loading = false;
    }

    // Calls back with the window's states ([{s, lu}], lu in seconds; the
    // first is the state at the window's start, which changed before it).
    function history(request: int, callback: var) {
        const sent = HassAPI.command("history/history_during_period", {
            start_time: new Date(root.windowStart).toISOString(),
            end_time: new Date(root.windowEnd).toISOString(),
            entity_ids: [root.entityId],
            minimal_response: true,
            no_attributes: true,
            significant_changes_only: false
        }, root, (ok, json, message) => {
            if (request !== root.request)
                return;
            if (ok)
                callback(JSON.parse(json)[root.entityId] ?? []);
            else
                root.failed(request, message);
        });
        if (!sent)
            root.failed(request, qsTr("Not connected"));
    }

    spacing: 4

    HassEntity {
        id: hassEntity
        entityId: root.entityId
    }

    TabBar {
        id: tabs
        Layout.fillWidth: true
        // The dialog's own color rather than a bar of Material's background.
        Material.background: "transparent"

        Repeater {
            model: root.offsets

            TabButton {
                required property int modelData
                text: modelData === 0 ? qsTr("24 h") : qsTr("−%1 d").arg(modelData)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Label {
            Layout.fillWidth: true
            text: qsTr("%1 – %2").arg(new Date(root.windowStart).toLocaleString(Qt.locale(), "d MMM HH:mm")).arg(new Date(root.windowEnd).toLocaleString(Qt.locale(), "d MMM HH:mm"))
            font.pixelSize: 12
            color: root.Material.secondaryTextColor
        }
        Label {
            text: root.unit
            font.pixelSize: 12
            color: root.Material.secondaryTextColor
        }
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.offsetDays === 0
        onTriggered: root.fetch()
    }

    // Not from the TabBar's currentIndexChanged, which can run before this
    // binding has followed it.
    onOffsetDaysChanged: root.fetch()
    // Later, because HassEntity sets the state before the attributes.
    onReadyChanged: Qt.callLater(root.fetch)
    Component.onCompleted: Qt.callLater(root.fetch)
}
