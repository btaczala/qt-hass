import QtQuick

// Logging in to Home Assistant over its HTTP auth API, the way its own
// frontend does: a login flow (username/password, then e.g. a 2FA code, each
// step a form described by `data_schema`) ends in an authorization code, which
// is exchanged for an access and a refresh token.
//
// Every call reports back through `done(result)`, where result is the reply's
// JSON on success and {error: "message"} otherwise.
QtObject {
    id: root

    // Base URL, e.g. http://192.168.1.40:8123.
    property string baseUrl
    // HA accepts any http(s) URL as client id without fetching it, as long as
    // the redirect URI is on the same host; neither is ever opened.
    readonly property string clientId: "https://github.com/btaczala/qt-hass"
    readonly property string redirectUri: root.clientId + "/auth-callback"
    readonly property int timeoutMs: 15000

    // The login flow in progress, from startLogin().
    property string flowId

    // "host:8123", "ws://host:8123/api/websocket", ... → "http://host:8123";
    // "" if it isn't a URL at all.
    function normalizeBaseUrl(text: string): string {
        let url = text.trim();
        if (!/^[a-z]+:\/\//i.test(url))
            url = "http://" + url;
        const m = /^(https?|wss?):\/\/([^\/?#\s]+)/i.exec(url);
        return m ? m[1].toLowerCase().replace(/^ws/, "http") + "://" + m[2] : "";
    }

    function webSocketUrl(base: string): string {
        return base.replace(/^http/, "ws") + "/api/websocket";
    }

    function request(method: string, path: string, body: var, form: bool, done: var) {
        // Captured: a late reply (e.g. to revoke()) can arrive after this
        // object is gone.
        const base = root.baseUrl;
        const xhr = new XMLHttpRequest();
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        let finished = false;
        // Reports once: aborting on timeout, for one, completes the request
        // too.
        const finish = result => {
            if (finished)
                return;
            finished = true;
            timer?.stop();
            timer?.destroy();
            done(result);
        };
        timer.interval = root.timeoutMs;
        timer.triggered.connect(() => {
            finish({
                error: qsTr("%1 didn't answer in time.").arg(base)
            });
            xhr.abort();
        });
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || finished)
                return;
            let json = null;
            try {
                json = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status === 0)
                finish({
                    error: qsTr("Can't reach %1.").arg(base)
                });
            else if (xhr.status >= 200 && xhr.status < 300 && json !== null)
                finish(json);
            else
                finish({
                    error: json?.message ?? json?.error_description ?? qsTr("%1 answered with HTTP %2.").arg(base).arg(xhr.status),
                    status: xhr.status
                });
        };
        xhr.open(method, base + path);
        if (body === undefined) {
            xhr.send();
        } else if (form) {
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            xhr.send(Object.keys(body).map(k => encodeURIComponent(k) + "=" + encodeURIComponent(body[k])).join("&"));
        } else {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(body));
        }
        timer.start();
    }

    // [{name, type, id}]; also tells whether baseUrl is a Home Assistant.
    function providers(done: var) {
        root.request("GET", "/auth/providers", undefined, false, result => {
            if (!result.error && !Array.isArray(result.providers))
                result = {
                    error: qsTr("%1 doesn't look like Home Assistant.").arg(root.baseUrl)
                };
            done(result);
        });
    }

    // Starts a login flow with `provider` ({type, id}); done gets its first
    // step.
    function startLogin(provider: var, done: var) {
        root.request("POST", "/auth/login_flow", {
            client_id: root.clientId,
            handler: [provider.type, provider.id],
            redirect_uri: root.redirectUri
        }, false, result => {
            root.flowId = result.flow_id ?? "";
            done(result);
        });
    }

    // Answers the current step's form; done gets the next step: another
    // `form`, `create_entry` (logged in, `result` is the code) or `abort`.
    function submitStep(values: var, done: var) {
        root.request("POST", "/auth/login_flow/" + root.flowId, Object.assign({
            client_id: root.clientId
        }, values), false, done);
    }

    // {access_token, refresh_token, expires_in}
    function exchangeCode(code: string, done: var) {
        root.request("POST", "/auth/token", {
            grant_type: "authorization_code",
            code: code,
            client_id: root.clientId
        }, true, done);
    }

    // A fresh {access_token, expires_in}.
    function refresh(refreshToken: string, done: var) {
        root.request("POST", "/auth/token", {
            grant_type: "refresh_token",
            refresh_token: refreshToken,
            client_id: root.clientId
        }, true, done);
    }

    // Revokes a refresh token and every access token issued from it.
    function revoke(refreshToken: string) {
        root.request("POST", "/auth/revoke", {
            token: refreshToken
        }, true, () => {});
    }
}
