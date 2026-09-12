import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Usage.js" as Usage
import "Notifications.js" as Notices

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
    property int page: 0
    property string activeRequest: ""
    property string dataRequest: ""
    property var costEntries: []
    property double costUpdated: 0
    property string costOutput: ""
    property string costFailure: ""
    property var noticeState: ({})
    property string noticeSettings: ""
    property string clipboardMessage: ""
    readonly property string request: JSON.stringify(Usage.command(settings))
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property bool stale: lastRefresh > 0 && (failure !== "" || now - lastRefresh >
        Math.max(600000, (Number(setting("refreshSeconds", 300)) || 300) * 2000))
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function refresh() {
        if (opened) refreshCosts();
        if (probe.running) return;
        if (dataRequest !== request) {
            entries = [];
            lastRefresh = 0;
            noticeState = {};
        }
        activeRequest = request;
        probe.command = JSON.parse(activeRequest);
        output = "";
        probe.running = true;
    }
    function notifyChanges(parsed) {
        var configuration = JSON.stringify([request, setting("notifications", false), setting("notifyThreshold", 10)]);
        if (noticeSettings !== configuration) { noticeState = {}; noticeSettings = configuration; }
        var result = Notices.transition(noticeState, parsed, setting("notifyThreshold", 10));
        noticeState = result.state;
        if (!setting("notifications", false)) return;
        // Each monitor has a widget; only the first bar sends desktop notifications.
        if (bar && typeof bar.moduleWidgets === "function" && bar.moduleWidgets(moduleName)[0] !== root) return;
        result.events.forEach(function(event) {
            Quickshell.execDetached(["notify-send", "--app-name=CodexBar", "--",
                "CodexBar · " + event.provider, event.message]);
        });
    }
    function refreshCosts() {
        if (costProbe.running || !setting("showCosts", true)) return;
        costOutput = "";
        costProbe.command = ["timeout", "--kill-after=5", "60", String(setting("executable", "codexbar")),
            "cost", "--provider", "both", "--format", "json", "--days", "30"];
        costProbe.running = true;
    }
    onOpenedChanged: if (opened && Date.now() - costUpdated > 300000) refreshCosts()
    function saveSettings(changes) {
        if (!bar || !bar.shell) return;
        var merged = Object.assign({}, settings, changes);
        bar.shell.updateEntryInline(moduleName, merged);
    }
    Component.onCompleted: Qt.callLater(refresh)
    onSettingsChanged: {
        if (output && dataRequest === request) {
            try { entries = Usage.rows(output, setting("showIdentity", false)); } catch (error) {}
        }
        Qt.callLater(refresh);
    }
    IpcHandler {
        target: root.ipcTarget
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function refresh(): void { root.refresh(); }
        function view(index: int): void { root.page = Math.max(0, Math.min(2, index)); root.open(); }
        function status(): string {
            return JSON.stringify({running: probe.running, exitCode: root.lastExitCode,
                outputBytes: root.output.length, providers: root.entries.length,
                summary: Usage.summary(root.entries), failure: root.failure,
                costProviders: root.costEntries.length, costFailure: root.costFailure, page: root.page});
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
        id: clipboard
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: { write(Notices.summary(root.entries)); stdinEnabled = false; }
        onExited: function(code) { root.clipboardMessage = code === 0 ? "Copied usage summary" : "Copy failed (wl-copy required)"; }
    }
    Process {
        id: costProbe
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.costOutput = text }
        stderr: StdioCollector {}
        onExited: function(code) {
            try {
                root.costEntries = Usage.costs(root.costOutput);
                root.costFailure = "";
                root.costUpdated = Date.now();
            } catch (error) { root.costFailure = "Local cost refresh failed. Previous results may be stale."; }
        }
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
                root.notifyChanges(parsed);
                root.entries = parsed;
                root.dataRequest = root.activeRequest;
                root.failure = "";
                root.lastRefresh = Date.now();
            } catch (error) {
                root.noticeState = {};
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
        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.priority: Keys.AfterItem
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
                else if (event.key === Qt.Key_R && !providerInput.activeFocus) { root.refresh(); event.accepted = true; }
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height,
                        scroll.contentY + (event.key === Qt.Key_Down ? 40 : -40)));
                    event.accepted = true;
                }
            }
            Flickable {
                id: scroll
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
                    Row {
                        width: parent.width
                        spacing: Style.space(4)
                        Repeater {
                            model: ["Usage", "Spending", "Settings"]
                            Button {
                                focusable: true
                                required property string modelData
                                required property int index
                                text: modelData
                                width: (content.width - Style.space(8)) / 3
                                selected: root.page === index
                                onClicked: { root.page = index; scroll.contentY = 0; }
                            }
                        }
                    }
                    DetailText {
                        visible: root.page === 0
                        text: probe.running ? "Refreshing…" : root.failure || (root.lastRefresh ?
                            "Quota remaining · updated " + Qt.formatTime(new Date(root.lastRefresh), "HH:mm") : "Waiting for usage…")
                    }
                    Repeater {
                        model: root.page === 0 ? root.entries : []
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
                            DetailText { text: modelData.status; visible: text !== ""; opacity: 0.7 }
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
                                    DetailText { text: modelData.pace; visible: text !== ""; opacity: 0.7 }
                                }
                            }
                            DetailText {
                                visible: modelData.credits !== null
                                text: "Credits: " + modelData.credits
                            }
                            Repeater {
                                model: modelData.details
                                Column {
                                    required property var modelData
                                    width: content.width
                                    spacing: Style.space(5)
                                    DetailText { text: modelData.title; visible: text !== ""; font.bold: true }
                                    Repeater {
                                        model: modelData.rows
                                        DetailText {
                                            required property var modelData
                                            text: modelData.label + ": " + modelData.value + (modelData.secondaryValue ? " · " + modelData.secondaryValue : "")
                                        }
                                    }
                                    UsageChart { width: parent.width; chart: modelData.chart; foreground: root.foreground }
                                }
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.page === 1 && root.setting("showCosts", true)
                        spacing: Style.space(10)
                        DetailText { text: "LOCAL SPENDING · CODEX & CLAUDE"; font.bold: true }
                        DetailText { text: "All local sessions, independent of the selected account. List-price estimates are not invoices."; opacity: 0.65 }
                        DetailText {
                            text: costProbe.running ? "Loading local history…" : root.costFailure
                            visible: text !== ""
                        }
                        Repeater {
                            model: root.costEntries
                            Column {
                                required property var modelData
                                width: content.width
                                spacing: Style.space(5)
                                DetailText { text: modelData.provider.toUpperCase() + " · " + Usage.provenance(modelData.provenance); font.bold: true }
                                DetailText { text: modelData.error; visible: text !== "" }
                                DetailText { text: "Today " + Usage.money(modelData.today) + " · 30 days " + Usage.money(modelData.month) }
                                DetailText { text: "Tokens · " + Usage.count(modelData.tokens) }
                                DetailText { text: "Input " + Usage.count(modelData.input) + " · output " + Usage.count(modelData.output) + " · cached " + Usage.count(modelData.cached); opacity: 0.7 }
                                DetailText { text: modelData.coverage; opacity: 0.7 }
                                UsageChart { width: parent.width; chart: modelData.chart; foreground: root.foreground }
                            }
                        }
                    }
                    DetailText { visible: root.stale; text: "Showing older data"; color: Color.urgent }
                    Button {
                        focusable: true
                        text: probe.running ? "Refreshing…" : "Refresh  ·  R"
                        enabled: !probe.running
                        onClicked: root.refresh()
                    }
                    Button {
                        focusable: true
                        text: "Copy usage summary"
                        visible: root.page === 0
                        enabled: root.entries.length > 0 && !clipboard.running
                        onClicked: { clipboard.stdinEnabled = true; clipboard.running = true; }
                    }
                    DetailText { text: root.clipboardMessage; visible: root.page === 0 && text !== "" }
                    DetailText { visible: root.page === 1 && !root.setting("showCosts", true); text: "Enable local spending in Settings." }
                    Column {
                        width: parent.width
                        visible: root.page === 2
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
                        Dropdown {
                            id: sourceInput
                            width: parent.width
                            options: ["auto", "oauth", "cli", "api", "web"]
                            value: root.setting("source", "auto")
                            onChanged: function(value) { sourceInput.value = value; }
                        }
                        DetailText { text: "Account number (0 uses the default; single provider only)" }
                        NumberField { onModified: function(next) { value = next; } id: accountInput; from: 0; to: 999; value: Number(root.setting("accountIndex", 0)) }
                        Toggle { width: parent.width; onClicked: checked = !checked; id: allInput; label: "Show all accounts"; checked: root.setting("allAccounts", false) }
                        Toggle { width: parent.width; onClicked: checked = !checked; id: identityInput; label: "Show account identity"; checked: root.setting("showIdentity", false) }
                        Toggle { width: parent.width; onClicked: checked = !checked; id: costsInput; label: "Show local spending"; checked: root.setting("showCosts", true) }
                        Toggle { width: parent.width; onClicked: checked = !checked; id: statusInput; label: "Service status"; checked: root.setting("showStatus", true) }
                        Toggle { width: parent.width; onClicked: checked = !checked; id: noticesInput; label: "Notifications"; description: "Low quota, resets and service changes"; checked: root.setting("notifications", false) }
                        DetailText { text: "Low quota threshold (%)" }
                        NumberField { onModified: function(next) { value = next; } id: thresholdInput; from: 1; to: 99; value: Number(root.setting("notifyThreshold", 10)) }
                        DetailText { text: "Refresh interval in seconds" }
                        NumberField { onModified: function(next) { value = next; } id: intervalInput; from: 60; to: 3600; stepSize: 60; value: Number(root.setting("refreshSeconds", 300)) }
                        Button {
                            focusable: true
                            text: "Apply"
                            enabled: providerInput.acceptableInput
                            onClicked: {
                                root.saveSettings({provider: providerInput.text, source: sourceInput.value,
                                    accountIndex: accountInput.value, allAccounts: allInput.checked,
                                    showIdentity: identityInput.checked, showCosts: costsInput.checked,
                                    showStatus: statusInput.checked, notifications: noticesInput.checked,
                                    notifyThreshold: thresholdInput.value, refreshSeconds: intervalInput.value});
                                root.page = 0;
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
