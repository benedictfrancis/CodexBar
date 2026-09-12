import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/Usage.js" as Usage

ApplicationWindow {
    id: window
    title: "Usage & Spend"
    width: 820; height: 700
    minimumWidth: 480; minimumHeight: 420
    property int selectedTab: 0
    onClosing: function(event) { event.accepted = false; hide(); }
    Shortcut { sequence: "Ctrl+R"; onActivated: { desktop.refresh(); desktop.refreshCosts(); } }
    Shortcut { sequence: "Ctrl+,"; onActivated: desktop.showWindow("settings") }
    Shortcut { sequence: "Escape"; onActivated: window.hide() }
    header: ToolBar {
        RowLayout {
            anchors.fill: parent; anchors.margins: 10
            Label { text: "CodexBar"; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            ToolButton { text: "Quit"; onClicked: Qt.quit() }
            ToolButton { text: "Settings…"; onClicked: desktop.showWindow("settings") }
        }
        implicitHeight: 64
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 24
        spacing: 18
        TabBar {
            Layout.fillWidth: true
            currentIndex: window.selectedTab
            TabButton { text: "Usage"; onClicked: window.selectedTab = 0 }
            TabButton { text: "Local Spending"; onClicked: { window.selectedTab = 1; desktop.showWindow("spending"); } }
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            visible: window.selectedTab === 0
            text: desktop.error || (desktop.busy ? "Refreshing usage…" : desktop.stale ? "Showing older usage · refresh to update" :
                desktop.updated ? "Quota remaining · updated " + desktop.updated : "Waiting for usage…")
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 16
                Repeater {
                    model: window.selectedTab === 0 ? desktop.entries : []
                    UsageCard { required property var modelData; entry: modelData }
                }
                Label {
                    visible: window.selectedTab === 1
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Codex and Claude sessions on this machine, across accounts. List-price estimates are not invoices."
                    opacity: 0.7
                }
                Label {
                    visible: window.selectedTab === 1
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: !desktop.settings.showCosts ? "Enable local spending in Settings." : desktop.costBusy ? "Reading local history…" : desktop.costError
                }
                Repeater {
                    model: window.selectedTab === 1 && desktop.settings.showCosts ? desktop.spending : []
                    Frame {
                        required property var modelData
                        Layout.fillWidth: true; padding: 20
                        ColumnLayout {
                            width: parent.width; spacing: 12
                            Label { text: modelData.provider.toUpperCase(); font.pixelSize: 18; font.bold: true }
                            Label { text: Usage.provenance(modelData.provenance); opacity: 0.65 }
                            Label { text: modelData.error; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Label { text: "Today  " + Usage.money(modelData.today) + "     30 days  " + Usage.money(modelData.month); font.pixelSize: 20; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Label { text: Usage.count(modelData.tokens) + " tokens" }
                            Label {
                                Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.7
                                text: "Input " + Usage.count(modelData.input) + " · output " + Usage.count(modelData.output) + " · cached " + Usage.count(modelData.cached)
                            }
                            Label { text: modelData.coverage; opacity: 0.7 }
                            UsageChart { Layout.fillWidth: true; chart: modelData.chart }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button { text: desktop.busy ? "Refreshing…" : "Refresh"; enabled: !desktop.busy; onClicked: { desktop.refresh(); if (window.selectedTab === 1) desktop.refreshCosts(); } }
            Button { text: "Copy summary"; visible: window.selectedTab === 0; enabled: desktop.entries.length > 0; onClicked: desktop.copySummary() }
            Item { Layout.fillWidth: true }
            Button { text: "Close"; onClicked: window.hide() }
        }
    }
}
