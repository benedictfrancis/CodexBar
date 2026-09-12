import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "Settings"
    width: 680; height: 720
    minimumWidth: 500; minimumHeight: 480
    property string feedback: ""
    onClosing: function(event) { event.accepted = false; hide(); }
    onVisibleChanged: if (visible) load()
    function load() {
        var s = desktop.settings;
        provider.editText = s.provider; source.currentIndex = source.model.indexOf(s.source);
        account.value = s.accountIndex; allAccounts.checked = s.allAccounts;
        identity.checked = s.showIdentity; costs.checked = s.showCosts; status.checked = s.showStatus;
        notices.checked = s.notifications; threshold.value = s.notifyThreshold; interval.value = s.refreshSeconds;
        tray.checked = s.showTray; executable.text = s.executable; feedback = "";
    }
    Shortcut { sequence: "Escape"; onActivated: window.hide() }
    header: ToolBar {
        Label { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; font.pixelSize: 22; font.bold: true }
        implicitHeight: 64
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 24; spacing: 16
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth; clip: true
            ColumnLayout {
                width: scroll.availableWidth; spacing: 20
                GroupBox {
                    title: "Providers & Accounts"; Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Label { text: "Provider" }
                        ComboBox {
                            id: provider; Layout.fillWidth: true; editable: true
                            model: ["codex", "claude", "both", "enabled", "cursor", "gemini", "copilot", "antigravity", "all"]
                            validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]{1,80}$/ }
                        }
                        Label { text: "Use enabled to follow your CodexBar provider configuration, or enter another provider ID."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Source"; Layout.fillWidth: true }
                            ComboBox { id: source; model: ["auto", "oauth", "cli", "api", "web"] }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Account number (0 = default)"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: account; from: 0; to: 999; editable: true }
                        }
                        CheckBox { id: allAccounts; text: "Show all accounts for the selected provider" }
                        CheckBox { id: identity; text: "Show account identity in application windows" }
                        Label { text: "Account selection changes the displayed account. Sign in and manage credentials with the provider CLI."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                    }
                }
                GroupBox {
                    title: "Refresh & Notifications"; Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Refresh interval (seconds)"; Layout.fillWidth: true }
                            SpinBox { id: interval; from: 60; to: 3600; stepSize: 60; editable: true }
                        }
                        CheckBox { id: notices; text: "Notify on low quota, resets and service changes" }
                        RowLayout {
                            Layout.fillWidth: true; enabled: notices.checked
                            Label { text: "Low quota threshold (%)"; Layout.fillWidth: true }
                            SpinBox { id: threshold; from: 1; to: 99; editable: true }
                        }
                        CheckBox { id: status; text: "Fetch provider service status" }
                    }
                }
                GroupBox {
                    title: "Desktop & Data"; Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        CheckBox { id: tray; text: "Show the standard Linux tray icon" }
                        Label { text: "Turn this off when using the Omarchy bar widget. You can always reopen CodexBar from your application launcher."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        CheckBox { id: costs; text: "Show local spending from Codex and Claude history" }
                        Label { text: "CodexBar CLI executable" }
                        TextField { id: executable; Layout.fillWidth: true; selectByMouse: true; placeholderText: "codexbar" }
                    }
                }
            }
        }
        Label { text: desktop.configError || window.feedback; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Background refresh continues when windows close."; Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65; font.pixelSize: 12 }
            Button { text: "Cancel"; onClicked: window.hide() }
            Button {
                text: "Save"; highlighted: true
                onClicked: {
                    if (desktop.saveSettings({provider: provider.editText.trim(), source: source.currentText,
                        accountIndex: account.value, allAccounts: allAccounts.checked, showIdentity: identity.checked,
                        showCosts: costs.checked, showStatus: status.checked, notifications: notices.checked,
                        notifyThreshold: threshold.value, refreshSeconds: interval.value,
                        showTray: tray.checked, executable: executable.text.trim()})) window.feedback = "Settings saved";
                }
            }
        }
    }
}
