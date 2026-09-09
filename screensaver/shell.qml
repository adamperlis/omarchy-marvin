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

  property color base: "#eef0f7"
  property color ink: "#2b3350"

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

        Rectangle { anchors.fill: parent; color: root.base }

        // The plate is oversized and centred so it can rotate without ever
        // bringing an edge into frame.
        // Blurred twice. One pass at blurMax 64 still left the fields reading
        // as circles with visible arcs; passing the already-blurred plate
        // through a second blur melts the edges completely and what is left is
        // the wash between them, which is the whole point of the look.
        Item {
          id: softened
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            autoPaddingEnabled: false
          }

        Item {
          id: plate
          width: parent.width * 1.9
          height: parent.height * 1.9
          anchors.centerIn: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            autoPaddingEnabled: false
          }

          NumberAnimation on rotation {
            running: true
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 48000
          }

          // One colour field. A rigid circle sliding around still reads as a
          // circle no matter how hard it is blurred — what sells fluid is the
          // shape changing while it travels. So each field is an ellipse that
          // stretches on one axis while squashing on the other, turns on its
          // own axis, and drifts, all on clocks that never line up. The arcs
          // dissolve into each other and the result moves like liquid rather
          // than like sprites.
          component Field: Rectangle {
            id: field
            property real ax: 0
            property real ay: 0
            property real bx: 0
            property real by: 0
            property int driftX: 6500
            property int driftY: 8500
            property int breathe: 5500
            property int spin: 20000
            property real minScale: 0.75
            property real maxScale: 1.35
            radius: width / 2
            transformOrigin: Item.Center

            transform: Scale {
              id: morph
              origin.x: field.width / 2
              origin.y: field.height / 2
              xScale: 1
              yScale: 1
              SequentialAnimation on xScale {
                loops: Animation.Infinite
                NumberAnimation { from: field.minScale; to: field.maxScale; duration: field.breathe; easing.type: Easing.InOutSine }
                NumberAnimation { to: field.minScale; duration: field.breathe; easing.type: Easing.InOutSine }
              }
              SequentialAnimation on yScale {
                loops: Animation.Infinite
                NumberAnimation { from: field.maxScale; to: field.minScale; duration: Math.round(field.breathe * 1.37); easing.type: Easing.InOutSine }
                NumberAnimation { to: field.maxScale; duration: Math.round(field.breathe * 1.37); easing.type: Easing.InOutSine }
              }
            }

            NumberAnimation on rotation {
              running: true
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: field.spin
            }

            SequentialAnimation on x {
              loops: Animation.Infinite
              NumberAnimation { from: field.ax; to: field.bx; duration: field.driftX; easing.type: Easing.InOutSine }
              NumberAnimation { to: field.ax; duration: field.driftX; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
              loops: Animation.Infinite
              NumberAnimation { from: field.ay; to: field.by; duration: field.driftY; easing.type: Easing.InOutSine }
              NumberAnimation { to: field.ay; duration: field.driftY; easing.type: Easing.InOutSine }
            }
          }

          Field {
            width: plate.width * 0.52; height: width
            color: "#8fa3ec"; opacity: 0.55
            ax: plate.width * 0.02;  ay: plate.height * 0.05
            bx: plate.width * 0.42;  by: plate.height * 0.46
            spin: 19000
            driftX: 9000; driftY: 11000; breathe: 7000
          }

          Field {
            width: plate.width * 0.34; height: width
            color: "#e9b463"; opacity: 0.50
            ax: plate.width * 0.58;  ay: plate.height * 0.04
            bx: plate.width * 0.18;  by: plate.height * 0.44
            spin: 23000
            driftX: 13000; driftY: 8000; breathe: 6000
            minScale: 0.8; maxScale: 1.25
          }

          Field {
            width: plate.width * 0.40; height: width
            color: "#cfa4de"; opacity: 0.45
            ax: plate.width * 0.34;  ay: plate.height * 0.52
            bx: plate.width * 0.66;  by: plate.height * 0.18
            spin: 17000
            driftX: 10000; driftY: 14000; breathe: 9000
          }

          Field {
            width: plate.width * 0.30; height: width
            color: "#f0a9b8"; opacity: 0.32
            ax: plate.width * 0.08;  ay: plate.height * 0.56
            bx: plate.width * 0.44;  by: plate.height * 0.28
            spin: 27000
            driftX: 12000; driftY: 9000; breathe: 5000
            minScale: 0.9; maxScale: 1.3
          }

          Field {
            width: plate.width * 0.26; height: width
            color: "#9fd8d2"; opacity: 0.28
            ax: plate.width * 0.62;  ay: plate.height * 0.58
            bx: plate.width * 0.26;  by: plate.height * 0.40
            spin: 21000
            driftX: 15000; driftY: 12000; breathe: 8000
          }

          // Keeps the middle luminous so the name always has quiet to sit on.
          Rectangle {
            width: plate.width * 0.62; height: width
            radius: width / 2
            color: "#ffffff"
            anchors.centerIn: parent
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { from: 0.46; to: 0.70; duration: 6000; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.46; duration: 6000; easing.type: Easing.InOutSine }
            }
          }
        }

        }

        // A slow specular pass — a wide soft band crossing the frame every
        // couple of minutes. It is the one event in the composition.
        Item {
          anchors.fill: parent
          clip: true
          Rectangle {
            id: sweep
            width: parent.width * 0.5
            height: parent.height * 2.2
            y: -parent.height * 0.6
            rotation: 18
            opacity: 0.22
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "#00ffffff" }
              GradientStop { position: 0.5; color: "#ffffffff" }
              GradientStop { position: 1.0; color: "#00ffffff" }
            }
            SequentialAnimation on x {
              loops: Animation.Infinite
              NumberAnimation { from: -sweep.width; to: win.width + sweep.width; duration: 8500; easing.type: Easing.InOutSine }
              PauseAnimation { duration: 13000 }
            }
          }
        }

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
