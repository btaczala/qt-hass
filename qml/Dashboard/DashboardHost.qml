pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// The user's dashboard on the main screen. DashboardSync downloads it from
// Controler.dashboardUrl each time the app connects and on reload(); it is
// loaded from that local copy (the last good one when a download fails) and
// shown while `active`. Without a dashboard -- none defined, still loading, a
// failed download, errors in its QML -- a DashboardMessage says why.
Item {
    id: root

    // Whether the dashboard should exist: connected and set up. It's
    // destroyed while not.
    property bool active: false
    // Passed on to the dashboard.
    property string navPosition: "left"

    // The loaded dashboard, or null.
    readonly property Dashboard dashboard: loader.item as Dashboard
    // One line on the dashboard's state, for the settings page.
    readonly property string statusText: {
        if (Controler.dashboardUrl === "")
            return qsTr("No dashboard defined");
        if (DashboardSync.syncing)
            return qsTr("Downloading...");
        const synced = DashboardSync.syncedAt.toLocaleString(Qt.locale(), Locale.ShortFormat);
        if (DashboardSync.error !== "")
            return DashboardSync.localUrl.toString() !== "" ? qsTr("Download failed, using the copy from %1: %2").arg(synced).arg(DashboardSync.error) : DashboardSync.error;
        if (message.hasErrors)
            return qsTr("The dashboard has errors");
        if (!root.active)
            return qsTr("Downloaded %1, shown once connected").arg(synced);
        return root.dashboard ? qsTr("Loaded, downloaded %1").arg(synced) : qsTr("Not loaded");
    }

    signal settingsRequested

    // Downloads the dashboard again and loads it from scratch, even when it
    // hasn't changed.
    function reload() {
        root.reloadPending = true;
        DashboardSync.sync(Controler.dashboardUrl);
    }

    // The compiled dashboard, once DashboardSync.localUrl has loaded.
    property Component component: null
    // Why it didn't compile.
    property string loadError
    property bool reloadPending: false

    function load() {
        root.component = null;
        root.loadError = "";
        DashboardSync.clearWarnings();
        const url = DashboardSync.localUrl.toString();
        if (url === "")
            return;
        const component = Qt.createComponent(url, Component.Asynchronous);
        const finish = () => {
            // A newer load() started meanwhile.
            if (DashboardSync.localUrl.toString() !== url || component.status === Component.Loading)
                return;
            // Paths relative to the dashboard, not to the cache.
            if (component.status === Component.Error)
                root.loadError = component.errorString().split(url.substring(0, url.lastIndexOf("/") + 1)).join("").trim();
            else
                root.component = component;
        };
        if (component.status === Component.Loading)
            component.statusChanged.connect(finish);
        else
            finish();
    }

    onActiveChanged: if (root.active)
        DashboardSync.sync(Controler.dashboardUrl)

    Component.onCompleted: {
        root.load();
        if (root.active)
            DashboardSync.sync(Controler.dashboardUrl);
    }

    Connections {
        target: DashboardSync
        function onLocalUrlChanged() {
            root.reloadPending = false;
            root.load();
        }
        function onSynced() {
            if (root.reloadPending) {
                root.reloadPending = false;
                root.load();
            }
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: root.active && root.component !== null
        // Not something else in its place, see DashboardMessage.
        visible: root.dashboard !== null
        sourceComponent: root.component
    }

    Binding {
        target: root.dashboard
        property: "navPosition"
        value: root.navPosition
        when: root.dashboard !== null
    }

    Connections {
        target: root.dashboard
        function onMenuRequested() {
            root.settingsRequested();
        }
    }

    DashboardMessage {
        id: message
        anchors.fill: parent
        visible: root.active && !root.dashboard

        readonly property bool notDashboard: loader.item !== null && !root.dashboard
        // Compiled, but creating it failed: see DashboardSync.warnings.
        readonly property bool creationFailed: loader.active && loader.status !== Loader.Loading && loader.item === null
        readonly property bool hasErrors: root.loadError !== "" || notDashboard || creationFailed
        readonly property bool downloadFailed: DashboardSync.error !== "" && DashboardSync.localUrl.toString() === ""

        busy: !hasErrors && !downloadFailed && Controler.dashboardUrl !== ""
        canReload: Controler.dashboardUrl !== "" && !DashboardSync.syncing
        icon: hasErrors || downloadFailed ? "mdi:alert-circle-outline" : "mdi:view-dashboard-edit-outline"
        title: Controler.dashboardUrl === "" ? qsTr("No dashboard defined") : hasErrors ? qsTr("The dashboard has errors") : downloadFailed ? qsTr("Couldn't download the dashboard") : qsTr("Loading the dashboard...")
        text: Controler.dashboardUrl === "" ? qsTr("A dashboard has to be defined in the settings.") : notDashboard ? qsTr("Its root has to be a Dashboard.") : downloadFailed || hasErrors ? Controler.dashboardUrl : ""
        details: hasErrors ? [root.loadError].concat(DashboardSync.warnings).filter(line => line !== "").join("\n") : downloadFailed ? DashboardSync.error : ""

        onSettingsRequested: root.settingsRequested()
        onReloadRequested: root.reload()
    }
}
