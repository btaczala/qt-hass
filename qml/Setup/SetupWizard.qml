pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// First-run setup, shown by Main.qml until Controler.setupCompleted: find Home
// Assistant, log in with a Home Assistant account, then pick this device's
// options.
//
// Logging in gives a refresh token for this app. On finish that is used once
// to connect, create a long-lived access token named after the device (which
// is what the app keeps, like a token pasted into the settings), and is then
// revoked, so only the long-lived token stays valid.
Pane {
    id: root

    enum Step {
        Server,
        Login,
        Options
    }

    property int step: SetupWizard.Step.Server
    property bool busy
    property string error
    // The login provider in use ({type, id}) and the step it's at.
    property var provider: null
    property var loginForm: null
    // From logging in; revoked once the long-lived token exists.
    property string refreshToken
    // What the options step chose, kept for a retry of finish().
    property var options: null
    // Between reconnecting with the fresh access token and it authenticating.
    property bool awaitingConnection
    // The connection set up before finish(), put back if it fails: the
    // short-lived access token it connects with mustn't replace a working
    // token for good.
    property var previousConnection: null

    function fail(message: string) {
        if (root.previousConnection) {
            Controler.hassUrl = root.previousConnection.url;
            Controler.hassToken = root.previousConnection.token;
            root.previousConnection = null;
            HassAPI.reconnect();
        }
        root.awaitingConnection = false;
        connectTimeout.stop();
        root.busy = false;
        root.error = message;
    }

    function checkServer() {
        const base = auth.normalizeBaseUrl(serverStep.url);
        if (base === "") {
            root.fail(qsTr("That doesn't look like an address."));
            return;
        }
        auth.baseUrl = base;
        root.busy = true;
        root.error = "";
        auth.providers(result => {
            if (result.error) {
                root.fail(result.error);
                return;
            }
            // Home Assistant's own users, unless that's switched off.
            root.provider = result.providers.find(p => p.type === "homeassistant") ?? result.providers[0] ?? null;
            if (!root.provider) {
                root.fail(qsTr("%1 offers no way to log in.").arg(base));
                return;
            }
            auth.startLogin(root.provider, root.handleLoginStep);
        });
    }

    function stepError(errors: var): string {
        switch (errors?.base) {
        case undefined:
            return "";
        case "invalid_auth":
            return qsTr("Wrong username or password.");
        case "invalid_code":
            return qsTr("Wrong code.");
        default:
            return qsTr("Login failed (%1).").arg(errors.base);
        }
    }

    function handleLoginStep(result: var) {
        root.busy = false;
        if (result.error) {
            // The login flow is gone: it timed out, or HA restarted.
            if (result.status === 404 && root.step === SetupWizard.Step.Login) {
                root.fail(qsTr("The login expired, please try again."));
                root.step = SetupWizard.Step.Server;
                return;
            }
            root.fail(result.error);
            return;
        }
        switch (result.type) {
        case "form":
            root.loginForm = result;
            root.error = root.stepError(result.errors);
            root.step = SetupWizard.Step.Login;
            break;
        case "create_entry":
            root.busy = true;
            auth.exchangeCode(result.result, tokens => {
                if (tokens.error) {
                    root.fail(tokens.error);
                    return;
                }
                root.busy = false;
                root.error = "";
                root.refreshToken = tokens.refresh_token;
                root.step = SetupWizard.Step.Options;
            });
            break;
        case "abort":
            root.fail(result.reason === "login_expired" ? qsTr("The login expired, please try again.") : qsTr("Login stopped (%1).").arg(result.reason));
            root.step = SetupWizard.Step.Server;
            break;
        default:
            root.fail(qsTr("Unexpected answer from Home Assistant."));
        }
    }

    function submitLogin(values: var) {
        root.busy = true;
        root.error = "";
        auth.submitStep(values, root.handleLoginStep);
    }

    function finish(options: var) {
        root.options = options;
        root.busy = true;
        root.error = "";
        // The access token from logging in lasts 30 minutes; get a new one in
        // case the options took a while.
        auth.refresh(root.refreshToken, result => {
            if (result.error) {
                root.fail(result.error);
                return;
            }
            root.previousConnection = {
                url: Controler.hassUrl,
                token: Controler.hassToken
            };
            Controler.hassUrl = auth.webSocketUrl(auth.baseUrl);
            Controler.hassToken = result.access_token;
            root.awaitingConnection = true;
            connectTimeout.restart();
            HassAPI.reconnect();
        });
    }

    function createLongLivedToken() {
        root.awaitingConnection = false;
        connectTimeout.stop();
        // Token names have to be unique per user.
        const name = qsTr("Qt Home Assistant: %1 (%2)").arg(root.options.deviceName).arg(new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm"));
        const sent = HassAPI.command("auth/long_lived_access_token", {
            client_name: name,
            lifespan: 3650
        }, root, (ok, json) => {
            const token = ok ? JSON.parse(json) : null;
            if (typeof token !== "string" || token === "") {
                root.fail(qsTr("Home Assistant didn't create an access token for this device."));
                return;
            }
            const options = root.options;
            Controler.deviceName = options.deviceName;
            Controler.keepScreenOn = options.keepScreenOn;
            Controler.idleTimeoutSeconds = options.idleTimeoutSeconds;
            Controler.setRemoteAdminConfig(options.remoteAdminEnabled, options.remoteAdminPassword, options.remoteAdminPort);
            Controler.hassToken = token;
            root.previousConnection = null;
            auth.revoke(root.refreshToken);
            root.refreshToken = "";
            HassAPI.reconnect();
            // Last: this removes the wizard.
            Controler.setupCompleted = true;
        });
        if (!sent)
            root.fail(qsTr("Lost the connection to Home Assistant."));
    }

    padding: 0
    background: Rectangle {
        color: root.Material.background
    }

    HassAuth {
        id: auth
    }


    Timer {
        id: connectTimeout
        interval: 30000
        onTriggered: root.fail(qsTr("Couldn't connect to %1.").arg(auth.webSocketUrl(auth.baseUrl)))
    }

    Connections {
        target: HassAPI
        enabled: root.awaitingConnection

        function onConnectedChanged() {
            if (HassAPI.connected)
                root.createLongLivedToken();
        }
        function onAuthenticationFailed(message: string) {
            root.fail(qsTr("Home Assistant rejected the login: %1").arg(message));
        }
    }

    // Top-aligned rather than centered, so an on-screen keyboard covers as
    // little of it as possible.
    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            x: (scroll.availableWidth - width) / 2
            width: Math.min(scroll.availableWidth - 32, 520)
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.min(64, scroll.height * 0.06)
                spacing: 16

                MdiIcon {
                    icon: "mdi:home-assistant"
                    iconSize: 48
                    color: "#18bcf2"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: qsTr("Welcome to Qt Home Assistant")
                        font.pixelSize: 24
                    }
                    Label {
                        text: [qsTr("Step 1 of 3: Server"), qsTr("Step 2 of 3: Log in"), qsTr("Step 3 of 3: This device")][root.step]
                        color: root.Material.hintTextColor
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 32
                currentIndex: root.step

                ServerStep {
                    id: serverStep
                    busy: root.busy
                    error: root.step === SetupWizard.Step.Server ? root.error : ""
                    canSkip: Controler.hassToken !== ""
                    url: auth.normalizeBaseUrl(Controler.hassUrl)
                    onNext: root.checkServer()
                    onSkip: {
                        Controler.setupCompleted = true;
                        HassAPI.connect();
                    }
                }
                LoginStep {
                    busy: root.busy
                    error: root.step === SetupWizard.Step.Login ? root.error : ""
                    form: root.loginForm
                    server: auth.baseUrl
                    onSubmit: values => root.submitLogin(values)
                    onBack: {
                        root.error = "";
                        root.step = SetupWizard.Step.Server;
                    }
                }
                OptionsStep {
                    busy: root.busy
                    error: root.step === SetupWizard.Step.Options ? root.error : ""
                    onFinish: options => root.finish(options)
                }
            }
        }
    }
}
