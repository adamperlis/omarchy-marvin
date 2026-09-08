import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Marvin's speed-test overlay, in the battery panel's language: a card on a dim
// scrim with two sixty-tick rings — download and upload — the rate lit in ink
// and the rest at the normal fill, the value in the ring's centre. The live
// phase glows in the accent and breathes. Esc or the scrim dismiss it.
//
// Drop-in for the shell's SpeedTestOverlay: same property and signal surface,
// so the panels only change the component name. (An identical copy ships in
// each speed-test plugin, since plugins can't share a file across directories.)
Item {
  id: overlay

  property string layerNamespace: "omarchy-speedtest"
  property string fontFamily: Style.font.family
  property string title: ""
  property string leftLabel: "DOWNLOAD"
  property string rightLabel: "UPLOAD"
  property string unit: "Mbps"
  property real leftValue: 0
  property real rightValue: 0
  property bool leftLive: false
  property bool rightLive: false
  property bool running: false
  property string error: ""
  property bool open: false
  property string runAgainTooltip: "Measure again"
  // The thresholds that fill the ring. Disk passes its own; internet falls back
  // to a sensible Mbps ramp. Each stop is an equal slice of the ring, so the
  // scale is coarse at the top where the exact number matters less.
  property var scaleStops: []
  readonly property var stops: (scaleStops && scaleStops.length) ? scaleStops : [10, 25, 50, 100, 250, 500, 1000]

  readonly property color ink: Color.popups.text

  signal closeRequested()
  signal runAgainRequested()

  function fmt(v) {
    if (!isFinite(v) || v <= 0) return "—"
    return v >= 100 ? String(Math.round(v)) : v.toFixed(1)
  }

  // Value → 0..1 across the stops, each stop an equal arc.
  function fraction(v) {
    var s = overlay.stops
    if (!s.length || !isFinite(v) || v <= 0) return 0
    if (v >= s[s.length - 1]) return 1
    var prev = 0
    for (var i = 0; i < s.length; i++) {
      if (v < s[i]) return (i + (v - prev) / (s[i] - prev)) / s.length
      prev = s[i]
    }
    return 1
  }

  // The window is mapped only once open, so focus has to be re-acquired after
  // it appears or Escape lands nowhere.
  onOpenChanged: if (open) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

  // A sixty-tick ring with the value in its centre — the battery hero, reused.
  component Gauge: Column {
    id: g
    property real value: 0
    property string label: ""
    property bool live: false
    readonly property int dia: Style.spacing.huge * 2      // 96
    readonly property int lit: Math.round(overlay.fraction(value) * 60)
    spacing: Style.spacing.md

    Item {
      width: g.dia
      height: g.dia
      anchors.horizontalCenter: parent.horizontalCenter

      Repeater {
        model: 60
        Rectangle {
          required property int index
          width: Style.spacing.xxs
          height: Style.spacing.sm
          radius: 1
          x: g.dia / 2 - width / 2
          y: 0
          color: index < g.lit
            ? (g.live ? Color.accent : overlay.ink)
            : Util.alpha(overlay.ink, Style.normalFillAlpha)
          transform: Rotation { origin.x: Style.spacing.xxs / 2; origin.y: g.dia / 2; angle: index * 6 }
          Behavior on color { ColorAnimation { duration: 220 } }
        }
      }

      // Breathe while this phase is being measured.
      SequentialAnimation on opacity {
        running: g.live
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { from: 1.0; to: 0.6; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.6; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
      }

      Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: overlay.fmt(g.value)
          color: overlay.ink
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.Normal
        }
        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: overlay.unit
          color: Color.muted
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      text: g.label
      color: Color.muted
      font.family: overlay.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelWindow {
    visible: overlay.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: overlay.layerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
      MouseArea { anchors.fill: parent; onClicked: overlay.closeRequested() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: overlay.closeRequested()

      // The card — the same raised surface and radius as every Marvin popup.
      Rectangle {
        anchors.centerIn: parent
        width: Math.min(Style.space(460), keyCatcher.width - Style.space(48))
        height: cardCol.implicitHeight + Style.cornerRadius * 2
        radius: Style.cornerRadius
        color: Color.popups.background

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: cardCol
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.cornerRadius * 2
          spacing: Style.spacing.xl

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: overlay.title || "Speed test"
            color: Color.muted
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.caption
            font.weight: Font.Medium
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacing.huge
            Gauge { value: overlay.leftValue;  label: overlay.leftLabel;  live: overlay.leftLive }
            Gauge { value: overlay.rightValue; label: overlay.rightLabel; live: overlay.rightLive }
          }

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: overlay.error !== "" ? overlay.error
                  : overlay.running ? "Measuring…"
                  : "Done"
            color: overlay.error !== "" ? Color.urgent : Color.muted
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            visible: !overlay.running
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: againText.implicitWidth + Style.spacing.xl * 2
            width: implicitWidth
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: againArea.containsMouse
              ? Style.hoverFillFor(overlay.ink, Color.accent)
              : Style.normalFillFor(overlay.ink, overlay.ink)

            Text {
              id: againText
              anchors.centerIn: parent
              text: "Run again"
              color: overlay.ink
              font.family: overlay.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: againArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: overlay.runAgainRequested()
            }
          }
        }
      }
    }
  }
}
