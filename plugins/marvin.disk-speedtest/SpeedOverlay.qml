import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Marvin's speed-test overlay: a centered card on a dim scrim, the two rates
// rendered as the biggest things on it — the design system's hero-number rule,
// the same one the weather temperature follows. Replaces the shell's shared
// gauge-cluster overlay so the look matches the rest of Marvin. Esc or the
// scrim dismiss it.
//
// Drop-in for the old SpeedTestOverlay: same property and signal surface, so
// the panels only change the component name. (An identical copy lives in each
// speed-test plugin, since plugins can't share a file across directories.)
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
  property var scaleStops: []      // accepted for API parity; the card has no dial

  signal closeRequested()
  signal runAgainRequested()

  // Hero numbers: integer once big, one decimal while small, an em dash before
  // the first reading.
  function fmt(v) {
    if (!isFinite(v) || v <= 0) return "—"
    return v >= 100 ? String(Math.round(v)) : v.toFixed(1)
  }

  // The window is mapped only once open, so focus has to be re-acquired after
  // it appears or Escape lands nowhere.
  onOpenChanged: if (open) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

  PanelWindow {
    visible: overlay.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: overlay.layerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Scrim: fixed dark so the card carries the contrast on any wallpaper.
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

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(Style.space(520), keyCatcher.width - Style.space(48))
        height: card.implicitHeight + Style.cornerRadius * 2
        radius: Style.cornerRadius
        color: Color.popups.background

        // Swallow clicks so only the scrim outside the card dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          id: card
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.cornerRadius
          spacing: Style.spacing.xl

          Text {
            textFormat: Text.PlainText
            text: overlay.title || "Speed test"
            color: Color.muted
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.caption
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignHCenter
          }

          // The two rates side by side, each a hero number with its unit as a
          // caption and its label beneath — a live phase glows in the accent.
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.spacing.huge

            Repeater {
              model: [
                { label: overlay.leftLabel,  value: overlay.leftValue,  live: overlay.leftLive },
                { label: overlay.rightLabel, value: overlay.rightValue, live: overlay.rightLive }
              ]

              ColumnLayout {
                required property var modelData
                spacing: Style.spacing.xs

                RowLayout {
                  spacing: Style.spacing.xs
                  Layout.alignment: Qt.AlignHCenter

                  Text {
                    textFormat: Text.PlainText
                    text: overlay.fmt(modelData.value)
                    color: modelData.live ? Color.accent : Color.popups.text
                    font.family: overlay.fontFamily
                    font.pixelSize: Style.font.displayLarge
                    font.letterSpacing: -Style.font.displayLarge * 0.03
                    font.weight: Font.Normal
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: overlay.unit
                    color: Color.muted
                    font.family: overlay.fontFamily
                    font.pixelSize: Style.font.body
                    Layout.alignment: Qt.AlignTop
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Color.muted
                  font.family: overlay.fontFamily
                  font.pixelSize: Style.font.caption
                  Layout.alignment: Qt.AlignHCenter
                }
              }
            }
          }

          // Status: the error, the live phase, or a quiet "done".
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: overlay.error !== "" ? overlay.error
                  : overlay.running ? "Measuring…"
                  : "Done"
            color: overlay.error !== "" ? Color.urgent : Color.muted
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.caption
          }

          // Run again — a filled pill, hidden while a run is in flight.
          Rectangle {
            visible: !overlay.running
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: againText.implicitWidth + Style.spacing.xl * 2
            implicitHeight: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: againArea.containsMouse
              ? Style.hoverFillFor(Color.popups.text, Color.accent)
              : Style.normalFillFor(Color.popups.text, Color.popups.text)

            Text {
              id: againText
              anchors.centerIn: parent
              text: "Run again"
              color: Color.popups.text
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
