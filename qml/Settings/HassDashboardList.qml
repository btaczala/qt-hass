import QtQml

import QtHomeAssistant

// The dashboards in Home Assistant's /config/www/qthass/, for the settings
// page to choose from. Home Assistant doesn't list www directories over HTTP,
// so they come from the index.json next to them -- a JSON array of directory
// names, each holding a main.qml -- which `just dashboard-sync` copies there
// from examples/index.json.
QtObject {
    id: root

    // Directory names, as listed.
    property var names: []
    property bool loading: false
    // Why the list couldn't be read; empty when it could.
    property string error

    // Replies to an earlier refresh() are dropped.
    property int request: 0

    function refresh() {
        const base = Controler.hassDashboardsUrl;
        const request = ++root.request;
        root.error = "";
        if (base === "") {
            root.names = [];
            root.error = qsTr("Set the Home Assistant address first.");
            return;
        }
        root.loading = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== root.request)
                return;
            root.loading = false;
            if (xhr.status === 404) {
                root.names = [];
                root.error = qsTr("No index.json in /config/www/qthass/.");
                return;
            }
            if (xhr.status !== 200) {
                root.names = [];
                root.error = xhr.status === 0 ? qsTr("Couldn't reach %1").arg(base) : qsTr("Home Assistant answered %1.").arg(xhr.status);
                return;
            }
            try {
                const names = JSON.parse(xhr.responseText);
                if (!Array.isArray(names))
                    throw new Error();
                root.names = names.filter(name => typeof name === "string" && name !== "");
                if (root.names.length === 0)
                    root.error = qsTr("No dashboards in /config/www/qthass/.");
            } catch (e) {
                root.names = [];
                root.error = qsTr("index.json isn't a JSON array of names.");
            }
        };
        // Past any cache: the list changes with each sync.
        xhr.open("GET", base + "index.json?t=" + Date.now());
        xhr.send();
    }
}
