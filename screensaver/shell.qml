// Marvin screensaver. A standalone Quickshell config, not a shell plugin: it
// runs as its own short-lived process, so an idle machine is not holding a
// second copy of the bar's engine and input can kill it outright.
//
// The look is the theme's wallpapers — soft mesh gradients in periwinkle,
// amber and lilac over near-white. There is no qsb on this system, so no
// compiled shaders: the fields are large solid circles under a heavy blur,
// which is what a blurred circle is for.
//
// Motion is layered on purpose. Every field drifts, breathes and the whole
// plate turns, all on long durations that share no common multiple, so the
// composition never returns to a pose you have already seen. Nothing moves
// fast enough to read as an animation while you are looking at it — it should
// look different when you glance back, not busy while you watch.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root

  property color base: "#968b76"
  property color ink: "#3a3527"

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      color: "transparent"

      readonly property real markSize: Math.max(34, Math.min(width * 0.055, 92))
      readonly property real tracking: markSize * 0.22

      Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: stage.opacity = 1
        Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }

        // The wash, shared with the lock screen — see Backdrop.qml.
        Backdrop { anchors.fill: parent; base: root.base }

        // The original mark, tinted out of its flat black into the theme ink
        // and set smaller than it wants to be, so it reads as a signature on
        // the wash rather than a headline across it.
        Item {
          anchors.centerIn: parent
          width: Math.min(win.width * 0.26, 420)
          height: width * (285 / 1215)

          Image {
            id: mark
            anchors.fill: parent
            source: "file:///usr/share/omarchy/logo.svg"
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
          }
          MultiEffect {
            anchors.fill: parent
            source: mark
            colorization: 1.0
            colorizationColor: root.ink
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { from: 0.70; to: 0.88; duration: 7000; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.70; duration: 7000; easing.type: Easing.InOutSine }
            }
          }
        }

        // Over everything, mark included.
        Grain { anchors.fill: parent }
      }

      // Any input ends it — but not the input of it appearing. The surface maps
      // under wherever the pointer already is, and hoverEnabled reports that as
      // a position change, which quit the screensaver in the frame it opened.
      // So input arms only once it has settled, and the pointer has to travel.
      property bool armed: false
      property real originX: -1
      property real originY: -1
      Timer { interval: 1200; running: true; onTriggered: win.armed = true }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: function(mouse) {
          if (!win.armed) return
          if (win.originX < 0) { win.originX = mouse.x; win.originY = mouse.y; return }
          if (Math.abs(mouse.x - win.originX) + Math.abs(mouse.y - win.originY) > 12) Qt.quit()
        }
        onClicked: if (win.armed) Qt.quit()
        onWheel: if (win.armed) Qt.quit()
      }
      Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: if (win.armed) Qt.quit()
      }
    }
  }
}
