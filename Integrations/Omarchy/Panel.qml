import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Usage.js" as Usage

Panel {
    id: root
    moduleName: "steipete.codexbar"
    ipcTarget: moduleName
    manageIpc: false
    property var entries: []
    property string failure: ""
    property double now: Date.now()
    property double lastRefresh: 0
    property string output: ""
    property int lastExitCode: -1
    property bool settingsOpen: false
    property string activeRequest: ""
    property string dataRequest: ""
    readonly property string request: JSON.stringify(Usage.command(settings))
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property bool stale: lastRefresh > 0 && (failure !== "" || now - lastRefresh > 600000)
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function refresh() {
        if (probe.running) return;
        if (dataRequest !== request) {
            entries = [];
            lastRefresh = 0;
        }
        activeRequest = request;
        probe.command = JSON.parse(activeRequest);
        output = "";
        probe.running = true;
    }
    function saveSettings(changes) {
        if (!bar || !bar.shell) return;
        var merged = Object.assign({}, settings, changes);
        bar.shell.updateEntryInline(moduleName, merged);
    }
    Component.onCompleted: Qt.callLater(refresh)
    onSettingsChanged: Qt.callLater(refresh)
    IpcHandler {
        target: root.ipcTarget
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function refresh(): void { root.refresh(); }
        function status(): string {
            return JSON.stringify({running: probe.running, exitCode: root.lastExitCode,
                outputBytes: root.output.length, providers: root.entries.length,
                summary: Usage.summary(root.entries), failure: root.failure});
        }
    }
    Timer {
        interval: Math.max(60, Number(root.setting("refreshSeconds", 300)) || 300) * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
    Process {
        id: probe
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.output = text }
        // Provider diagnostics may contain personal data; never forward them to shell logs.
        stderr: StdioCollector {}
        onExited: function(code, status) {
            root.lastExitCode = code;
            if (root.activeRequest !== root.request) {
                Qt.callLater(root.refresh);
                return;
            }
            try {
                var parsed = Usage.rows(root.output, root.setting("showIdentity", false));
                root.entries = parsed;
                root.dataRequest = root.activeRequest;
                root.failure = "";
                root.lastRefresh = Date.now();
            } catch (error) {
                root.failure = code === 124 ? "Refresh timed out. Press R to retry." :
                    "Unable to fetch usage. Check the CLI path and provider login; press R to retry.";
            }
            root.now = Date.now();
        }
    }
    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: (root.stale ? "! " : "") + (root.entries.length ? Usage.summary(root.entries) : "CodexBar —")
        tooltipText: "CodexBar · quota remaining\nClick for details · middle-click to refresh"
        onPressed: function(code) {
            if (code === Qt.MiddleButton || code === Qt.RightButton) root.refresh();
            else root.toggle();
        }
    }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: fittedContentWidth(Style.space(360))
        contentHeight: fittedContentHeight(content.implicitHeight, Style.space(560))
        PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction); }
            onTextKey: function(text) { if (text.toLowerCase() === "r") root.refresh(); }
            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Column {
                    id: content
                    width: parent.width
                    spacing: Style.space(14)
                    Text {
                        text: "CodexBar"
                        color: root.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    DetailText {
                        text: probe.running ? "Refreshing…" : root.failure || (root.lastRefresh ?
                            "Quota remaining · updated " + Qt.formatTime(new Date(root.lastRefresh), "HH:mm") : "Waiting for usage…")
                    }
                    Repeater {
                        model: root.entries
                        Column {
                            required property var modelData
                            width: content.width
                            spacing: Style.space(8)
                            DetailText {
                                text: modelData.provider.toUpperCase() + (modelData.source ? " · " + modelData.source : "")
                                font.bold: true
                            }
                            DetailText {
                                text: (root.setting("showIdentity", false) ? modelData.accountLabel : "") || (root.setting("allAccounts", false) ? "Account " + modelData.accountNumber : "")
                                visible: text !== ""
                            }
                            DetailText { text: modelData.plan; visible: text !== ""; opacity: 0.7 }
                            DetailText { text: modelData.error; visible: text !== "" }
                            Repeater {
                                model: modelData.windows
                                Column {
                                    required property var modelData
                                    width: content.width
                                    spacing: Style.space(4)
                                    DetailText { text: modelData.label + " · " + modelData.remaining + "% left" }
                                    Rectangle {
                                        width: parent.width
                                        height: Style.space(6)
                                        radius: height / 2
                                        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
                                        Rectangle {
                                            width: parent.width * modelData.remaining / 100
                                            height: parent.height
                                            radius: height / 2
                                            color: modelData.remaining <= 10 ? Color.urgent : Color.accent
                                        }
                                    }
                                    DetailText {
                                        text: Usage.resetLabel(modelData.resetsAt, root.now)
                                        opacity: 0.65
                                    }
                                }
                            }
                            DetailText {
                                visible: modelData.credits !== null
                                text: "Credits: " + modelData.credits
                            }
                        }
                    }
                    DetailText { visible: root.stale; text: "Showing older data"; color: Color.urgent }
                    Button {
                        text: probe.running ? "Refreshing…" : "Refresh  ·  R"
                        enabled: !probe.running
                        onClicked: root.refresh()
                    }
                    Button {
                        text: root.settingsOpen ? "Hide settings" : "Settings"
                        onClicked: root.settingsOpen = !root.settingsOpen
                    }
                    Column {
                        width: parent.width
                        visible: root.settingsOpen
                        spacing: Style.space(8)
                        DetailText { text: "Provider ID (enabled uses your CodexBar configuration)" }
                        TextField {
                            id: providerInput
                            width: parent.width
                            text: String(root.setting("provider", "codex"))
                            placeholderText: "codex, claude, both, enabled…"
                            selectByMouse: true
                            validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]+$/ }
                        }
                        DetailText { text: "Source" }
                        ComboBox {
                            id: sourceInput
                            width: parent.width
                            model: ["auto", "oauth", "cli", "api", "web"]
                            currentIndex: Math.max(0, model.indexOf(root.setting("source", "auto")))
                        }
                        DetailText { text: "Account number (0 uses the default; single provider only)" }
                        SpinBox { id: accountInput; from: 0; to: 999; value: Number(root.setting("accountIndex", 0)) }
                        CheckBox { id: allInput; text: "Show all accounts"; checked: root.setting("allAccounts", false) }
                        CheckBox { id: identityInput; text: "Show account identity"; checked: root.setting("showIdentity", false) }
                        DetailText { text: "Refresh interval in seconds" }
                        SpinBox { id: intervalInput; from: 60; to: 3600; stepSize: 60; value: Number(root.setting("refreshSeconds", 300)) }
                        Button {
                            text: "Apply"
                            enabled: providerInput.acceptableInput
                            onClicked: {
                                root.saveSettings({provider: providerInput.text, source: sourceInput.currentText,
                                    accountIndex: accountInput.value, allAccounts: allInput.checked,
                                    showIdentity: identityInput.checked, refreshSeconds: intervalInput.value});
                                root.settingsOpen = false;
                            }
                        }
                        DetailText { text: "Account selection changes this display only. Sign in and manage credentials with the provider CLI."; opacity: 0.7 }
                    }
                }
            }
        }
    }
    component DetailText: Text {
        width: parent.width
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
}
