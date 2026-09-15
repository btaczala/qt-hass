import QtQml

import QtHomeAssistant

// The dashboards in Home Assistant's /config/www/qthass/, for the settings
// page to choose from. Home Assistant doesn't list www directories over HTTP,
// so they come from the index.json next to them, which `just dashboard-sync`
// copies there from examples/index.json: a JSON array with an entry per
// directory, either its name (a dashboard in main.qml, the built-in
// screensaver) or an object naming its files:
//
//     ["office-panel", { "name": "area-panel", "main": "main.qml", "screensaver": "AreaScreensaver.qml" }]
QtObject {
    id: root

    // Directory names, as listed.
    readonly property var names: root.entries.map(entry => entry.name)
    // { name, main, screensaver } per dashboard, "main.qml" and "" filled in.
    property var entries: []
    property bool loading: false
    // Why the list couldn't be read; empty when it could.
    property string error

    // Replies to an earlier refresh() are dropped.
    property int request: 0

    // The entry named `name`, or null when the list lacks it.
    function entry(name) {
        return root.entries.find(entry => entry.name === name) ?? null;
    }

    function refresh() {
        const base = Controler.hassDashboardsUrl;
        const request = ++root.request;
        root.error = "";
        if (base === "") {
            root.entries = [];
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
                root.entries = [];
                root.error = qsTr("No index.json in /config/www/qthass/.");
                return;
            }
            if (xhr.status !== 200) {
                root.entries = [];
                root.error = xhr.status === 0 ? qsTr("Couldn't reach %1").arg(base) : qsTr("Home Assistant answered %1.").arg(xhr.status);
                return;
            }
            try {
                const list = JSON.parse(xhr.responseText);
                if (!Array.isArray(list))
                    throw new Error();
                root.entries = list.map(item => typeof item === "string" ? {
                        name: item
                    } : item).filter(item => typeof item?.name === "string" && item.name !== "").map(item => ({
                            name: item.name,
                            main: typeof item.main === "string" && item.main !== "" ? item.main : "main.qml",
                            screensaver: typeof item.screensaver === "string" ? item.screensaver : ""
                        }));
                if (root.entries.length === 0)
                    root.error = qsTr("No dashboards in /config/www/qthass/.");
            } catch (e) {
                root.entries = [];
                root.error = qsTr("index.json isn't a JSON array of dashboards.");
            }
        };
        // Past any cache: the list changes with each sync.
        xhr.open("GET", base + "index.json?t=" + Date.now());
        xhr.send();
    }
}
