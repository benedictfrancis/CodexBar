import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "Settings"
    width: 680; height: 720
    minimumWidth: 500; minimumHeight: 480
    property string feedback: ""
    property int section: 0
    onClosing: function(event) { event.accepted = false; hide(); }
    onVisibleChanged: if (visible) load()
    function load() {
        var s = desktop.settings;
        provider.editText = s.provider; source.currentIndex = source.model.indexOf(s.source);
        account.value = s.accountIndex; allAccounts.checked = s.allAccounts;
        identity.checked = s.showIdentity; costs.checked = s.showCosts; status.checked = s.showStatus;
        notices.checked = s.notifications; threshold.value = s.notifyThreshold; interval.value = s.refreshSeconds;
        refreshOnOpen.checked = s.refreshOnOpen;
        tray.checked = s.showTray; executable.text = s.executable; feedback = "";
    }
    Shortcut { sequence: "Escape"; onActivated: window.hide() }
    header: ToolBar {
        Label { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; font.pixelSize: 22; font.bold: true }
        implicitHeight: 64
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 12
        TabBar {
            Layout.fillWidth: true
            currentIndex: window.section
            TabButton { text: "General"; onClicked: window.section = 0 }
            TabButton { text: "Providers"; onClicked: window.section = 1 }
            TabButton { text: "Advanced"; onClicked: window.section = 2 }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth; clip: true
            ColumnLayout {
                width: scroll.availableWidth; spacing: 20
                GroupBox {
                    title: "Provider"; Layout.fillWidth: true; visible: window.section === 1
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Label { text: "Provider" }
                        ComboBox {
                            id: provider; Layout.fillWidth: true; editable: true
                            model: ["codex", "claude", "both", "enabled", "cursor", "gemini", "copilot", "antigravity", "all"]
                            validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]{1,80}$/ }
                        }
                        Label { text: "Choose enabled to use your CLI configuration. Other provider IDs can be typed here."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Source"; Layout.fillWidth: true }
                            ComboBox { id: source; model: ["auto", "oauth", "cli", "api", "web"] }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Account (0 = default)"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: account; from: 0; to: 999; editable: true }
                        }
                        Option { id: allAccounts; text: "All accounts" }
                        Option { id: identity; text: "Show account identity" }
                        Label { text: "Selects which account to display. Sign in with the provider CLI."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                    }
                }
                GroupBox {
                    title: "Updates"; Layout.fillWidth: true; visible: window.section === 0
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Refresh every (seconds)"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: interval; from: 60; to: 3600; stepSize: 60; editable: true }
                        }
                        Option { id: refreshOnOpen; text: "Refresh when opening usage" }
                        Option { id: notices; text: "Notify about low quota, resets, and outages" }
                        RowLayout {
                            Layout.fillWidth: true; enabled: notices.checked
                            Label { text: "Remaining quota threshold (%)"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: threshold; from: 1; to: 99; editable: true }
                        }
                        Option { id: status; text: "Service status" }
                    }
                }
                GroupBox {
                    title: "Desktop"; Layout.fillWidth: true; visible: window.section === 0
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Option { id: tray; text: "Tray icon" }
                        Label { text: "Optional with the Omarchy widget. CodexBar is also available in the application launcher."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        Option { id: costs; text: "Local spending" }
                    }
                }
                GroupBox {
                    title: "CLI"; Layout.fillWidth: true; visible: window.section === 2
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Label { text: "Executable" }
                        TextField { id: executable; Layout.fillWidth: true; selectByMouse: true; placeholderText: "codexbar" }
                    }
                }
            }
        }
        Label { text: desktop.configError || window.feedback; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Closing windows keeps CodexBar running."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65; font.pixelSize: 12 }
            Button { text: "Cancel"; onClicked: window.hide() }
            Button {
                text: "Save"; highlighted: true
                onClicked: {
                    if (desktop.saveSettings({provider: provider.editText.trim(), source: source.currentText,
                        accountIndex: account.value, allAccounts: allAccounts.checked, showIdentity: identity.checked,
                        showCosts: costs.checked, showStatus: status.checked, notifications: notices.checked,
                        notifyThreshold: threshold.value, refreshSeconds: interval.value,
                        refreshOnOpen: refreshOnOpen.checked, showTray: tray.checked, executable: executable.text.trim()})) window.feedback = "Settings saved";
                }
            }
        }
    }
    component Option: CheckBox {
        Layout.fillWidth: true
        contentItem: Text {
            text: parent.text
            font: parent.font
            color: parent.palette.windowText
            leftPadding: parent.indicator.width + parent.spacing
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }
}
