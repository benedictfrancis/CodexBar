import QtQuick
import qs.Commons

Column {
    id: root
    required property var chart
    property color foreground: Color.foreground
    property int selected: -1
    readonly property var points: chart ? chart.points : []
    readonly property real minimum: Math.min(0, ...points.map(p => p.value))
    readonly property real maximum: Math.max(1, ...points.map(p => p.value))
    spacing: Style.space(4)
    visible: points.length > 0
    Text {
        width: parent.width
        text: root.chart ? root.chart.title : ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
    }
    Canvas {
        id: canvas
        width: parent.width
        height: Style.space(65)
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.points.length) return;
            var step = width / root.points.length;
            var range = root.maximum - root.minimum;
            var baseline = height * root.maximum / range;
            ctx.strokeStyle = root.foreground;
            ctx.globalAlpha = 0.25;
            ctx.beginPath(); ctx.moveTo(0, baseline); ctx.lineTo(width, baseline); ctx.stroke();
            ctx.globalAlpha = 1;
            ctx.fillStyle = Color.accent;
            ctx.strokeStyle = Color.accent;
            ctx.lineWidth = Style.space(2);
            ctx.beginPath();
            root.points.forEach(function(point, index) {
                var y = height * (root.maximum - point.value) / range;
                if (root.chart.kind === "line") {
                    if (index === 0) ctx.moveTo(step * (index + 0.5), y);
                    else ctx.lineTo(step * (index + 0.5), y);
                } else ctx.fillRect(step * index + 1, Math.min(y, baseline), Math.max(1, step - 2), Math.max(1, Math.abs(baseline - y)));
            });
            if (root.chart.kind === "line") ctx.stroke();
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function(mouse) {
                root.selected = Math.min(root.points.length - 1, Math.floor(mouse.x / width * root.points.length));
            }
            onExited: root.selected = -1
        }
    }
    onChartChanged: { selected = -1; canvas.requestPaint(); }
    onForegroundChanged: canvas.requestPaint()
    Connections { target: Color; function onAccentChanged() { canvas.requestPaint(); } }
    Text {
        width: parent.width
        text: root.selected >= 0 && root.selected < root.points.length ?
            root.points[root.selected].label + " · " + root.points[root.selected].value.toFixed(2) + " " + root.chart.unit :
            (root.points.length ? root.points[0].label + " → " + root.points[root.points.length - 1].label : "")
        textFormat: Text.PlainText
        color: root.foreground
        opacity: 0.65
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
    }
}
