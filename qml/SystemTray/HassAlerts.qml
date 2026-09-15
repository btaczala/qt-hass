import QtQuick

import QtHomeAssistant

// Home Assistant's own badges, worked out the way its sidebar does:
// persistent notifications (the bell) and, for the Settings badge, repairs
// issues that aren't ignored plus installable updates -- as lists, for
// SystemTrayPanel, and counts. Main.qml owns the one instance and hands it to
// both SystemTrays, so there's one set of subscriptions however many trays
// show it. Everything is empty while not watched or not connected; repairs
// and updates need an admin user, and stay empty without.
Item {
    id: root

    property bool watchNotifications: false
    property bool watchSettingsAlerts: false

    // Newest first: {id, title, message, created} (created in ms).
    property var notificationList: []
    // Newest first: {id, domain, severity, title, description, learnMoreUrl,
    // created}, title and description translated.
    property var repairList: []
    // {entityId, title, installed, latest}.
    property var updateList: []

    readonly property int notifications: root.notificationList.length
    readonly property int repairs: root.repairList.length
    readonly property int updates: root.updateList.length
    readonly property int settingsAlerts: root.repairs + root.updates

    // update.* entities that are on, not hidden and support INSTALL (bit 1),
    // as the frontend's updateCanInstall(); HA re-renders it whenever an
    // update entity changes. Renders a JSON array (as a string).
    readonly property string updatesTemplate: "[{% for s in states.update | selectattr('state', 'eq', 'on') | rejectattr('entity_id', 'is_hidden_entity') if (s.attributes.supported_features | default(0, true)) is odd %}" + "{{ {'entityId': s.entity_id, 'title': s.attributes.title or s.name, 'installed': s.attributes.installed_version, 'latest': s.attributes.latest_version} | tojson }}{{ ',' if not loop.last }}{% endfor %}]"

    readonly property bool notificationsLive: root.watchNotifications && HassAPI.connected
    readonly property bool settingsAlertsLive: root.watchSettingsAlerts && HassAPI.connected

    // By id, as the subscription delivers them: "added" and "updated" carry
    // only what changed.
    property var notificationsById: ({})
    // The user's Home Assistant language, for repair texts.
    property string language: "en"
    // "component.<domain>.issues.<key>.title" -> text, for every domain fetched.
    property var translations: ({})
    property var translatedDomains: ({})
    // Last repairs/list_issues reply, kept to rebuild once translations arrive.
    property var issues: []
    // Subscription ids, to end them when no longer watched.
    property var notificationSubscriptions: []
    property var settingsSubscriptions: []

    function unsubscribeAll(ids) {
        for (const id of ids)
            HassAPI.unsubscribe(id);
    }

    function subscribeNotifications() {
        root.notificationsById = {};
        const id = HassAPI.subscribe("persistent_notification/subscribe", {}, root, (ok, json, error) => {
            if (!ok) {
                console.warn("Notifications unavailable:", error);
                return;
            }
            const event = JSON.parse(json);
            const byId = root.notificationsById;
            for (const [key, notification] of Object.entries(event.notifications ?? {})) {
                if (event.type === "removed")
                    delete byId[key];
                else
                    byId[key] = notification;
            }
            root.notificationList = Object.values(byId).map(n => ({
                        id: n.notification_id,
                        title: n.title ?? "",
                        message: n.message ?? "",
                        created: Date.parse(n.created_at)
                    })).sort((a, b) => b.created - a.created);
        });
        root.notificationSubscriptions = id ? [id] : [];
    }

    // "{name}" placeholders, as HA's translations use them.
    function fill(text, placeholders) {
        return (text ?? "").replace(/\{(\w+)\}/g, (match, key) => placeholders && key in placeholders ? placeholders[key] : match);
    }

    function buildRepairs() {
        root.repairList = root.issues.filter(issue => !issue.ignored).map(issue => {
            const prefix = "component." + issue.domain + ".issues." + (issue.translation_key ?? issue.issue_id) + ".";
            const placeholders = issue.translation_placeholders;
            return {
                id: issue.domain + "/" + issue.issue_id,
                domain: issue.domain,
                severity: issue.severity,
                title: root.fill(root.translations[prefix + "title"] ?? issue.issue_id, placeholders),
                description: root.fill(root.translations[prefix + "description"], placeholders),
                learnMoreUrl: issue.learn_more_url ?? "",
                created: Date.parse(issue.created)
            };
        }).sort((a, b) => b.created - a.created);
    }

    function fetchRepairs() {
        HassAPI.command("repairs/list_issues", {}, root, (ok, json, error) => {
            if (!ok) {
                console.warn("Repairs unavailable:", error);
                return;
            }
            root.issues = JSON.parse(json).issues;
            const missing = [...new Set(root.issues.filter(issue => !issue.ignored).map(issue => issue.domain))].filter(domain => !root.translatedDomains[domain]);
            root.buildRepairs();
            if (missing.length === 0)
                return;
            HassAPI.command("frontend/get_translations", {
                language: root.language,
                category: "issues",
                integration: missing
            }, root, (ok, json, error) => {
                if (!ok) {
                    console.warn("Repair translations unavailable:", error);
                    return;
                }
                Object.assign(root.translations, JSON.parse(json).resources);
                for (const domain of missing)
                    root.translatedDomains[domain] = true;
                root.buildRepairs();
            });
        });
    }

    function subscribeSettingsAlerts() {
        HassAPI.command("frontend/get_user_data", {
            key: "language"
        }, root, (ok, json, error) => {
            const language = ok ? JSON.parse(json).value?.language : null;
            if (language && language !== root.language) {
                root.language = language;
                root.translations = {};
                root.translatedDomains = {};
            }
            root.fetchRepairs();
        });
        const repairs = HassAPI.subscribe("subscribe_events", {
            event_type: "repairs_issue_registry_updated"
        }, root, (ok, json, error) => {
            if (ok)
                refetchRepairs.restart();
        });
        const updates = HassAPI.subscribe("render_template", {
            template: root.updatesTemplate
        }, root, (ok, json, error) => {
            if (!ok) {
                console.warn("Updates unavailable:", error);
                return;
            }
            const event = JSON.parse(json);
            if (event.error) {
                console.warn("Updates template failed:", event.error);
                return;
            }
            // HA hands the rendered JSON back as a string, or already parsed.
            try {
                const list = typeof event.result === "string" ? JSON.parse(event.result) : event.result;
                if (Array.isArray(list))
                    root.updateList = list;
            } catch (e) {
                console.warn("Updates template result unreadable:", e);
            }
        });
        root.settingsSubscriptions = [repairs, updates].filter(id => id);
    }

    onNotificationsLiveChanged: {
        if (root.notificationsLive) {
            root.subscribeNotifications();
            return;
        }
        root.unsubscribeAll(root.notificationSubscriptions);
        root.notificationSubscriptions = [];
        root.notificationList = [];
    }

    onSettingsAlertsLiveChanged: {
        if (root.settingsAlertsLive) {
            root.subscribeSettingsAlerts();
            return;
        }
        root.unsubscribeAll(root.settingsSubscriptions);
        root.settingsSubscriptions = [];
        refetchRepairs.stop();
        root.issues = [];
        root.repairList = [];
        root.updateList = [];
    }

    Component.onCompleted: {
        if (root.notificationsLive)
            root.subscribeNotifications();
        if (root.settingsAlertsLive)
            root.subscribeSettingsAlerts();
    }

    // Changes tend to come in bursts, e.g. at startup; the frontend waits too.
    Timer {
        id: refetchRepairs
        interval: 500
        onTriggered: root.fetchRepairs()
    }
}
