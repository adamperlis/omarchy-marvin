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
          // Saturation and contrast live on the effect, which is the reliable
          // way to get punch here. A Qt5Compat Blend was tried first and is the
          // obvious answer, but a layer-effect item cannot also serve as a
          // Blend source — the composite collapsed to the flat base colour.
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            autoPaddingEnabled: false
            saturation: 1.45
            contrast: 0.12
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

          // Sampled off the current wallpaper, but few and large rather than
          // many and small: eight overlapping semi-opaque warm fields averaged
          // into flat cream and took the hue variety with them. The wallpaper
          // is alive because warm gold sits against cool periwinkle, so the
          // set is kept to five with real hue separation and enough weight to
          // survive the blur.
          Field {
            width: plate.width * 0.46; height: width
            color: "#b38d41"; opacity: 0.72
            ax: plate.width * 0.02;  ay: plate.height * 0.06
            bx: plate.width * 0.30;  by: plate.height * 0.40
            spin: 19000
            driftX: 9000; driftY: 11000; breathe: 7000
          }
          Field {
            width: plate.width * 0.38; height: width
            color: "#7881ae"; opacity: 0.88
            ax: plate.width * 0.54;  ay: plate.height * 0.04
            bx: plate.width * 0.18;  by: plate.height * 0.36
            spin: 23000
            driftX: 13000; driftY: 8000; breathe: 6000
          }
          Field {
            width: plate.width * 0.42; height: width
            color: "#c8bc9e"; opacity: 0.34
            ax: plate.width * 0.28;  ay: plate.height * 0.46
            bx: plate.width * 0.58;  by: plate.height * 0.16
            spin: 17000
            driftX: 10000; driftY: 14000; breathe: 9000
          }
          Field {
            width: plate.width * 0.34; height: width
            color: "#8d714b"; opacity: 0.62
            ax: plate.width * 0.14;  ay: plate.height * 0.50
            bx: plate.width * 0.46;  by: plate.height * 0.24
            spin: 27000
            driftX: 12000; driftY: 9000; breathe: 5000
          }
          Field {
            width: plate.width * 0.36; height: width
            color: "#968b97"; opacity: 0.66
            ax: plate.width * 0.56;  ay: plate.height * 0.50
            bx: plate.width * 0.26;  by: plate.height * 0.32
            spin: 21000
            driftX: 15000; driftY: 12000; breathe: 8000
          }

          // Colour pops. The wash is deliberately muted to sit near the
          // wallpaper, which leaves it a little inert, so these three saturated
          // fields spend most of their cycle at zero and briefly surface. The
          // frame gets an event rather than a constant, and because they ride
          // inside the plate they are blurred and turned with everything else
          // instead of reading as discs laid on top.
          component Pop: Rectangle {
            id: pop
            property int cycle: 31000
            property real peak: 0.5
            property int offset: 0
            radius: width / 2
            opacity: 0
            transformOrigin: Item.Center
            SequentialAnimation on opacity {
              running: true
              loops: Animation.Infinite
              PauseAnimation { duration: pop.offset }
              NumberAnimation { to: pop.peak; duration: Math.round(pop.cycle * 0.24); easing.type: Easing.InOutSine }
              NumberAnimation { to: 0; duration: Math.round(pop.cycle * 0.32); easing.type: Easing.InOutSine }
              PauseAnimation { duration: Math.round(pop.cycle * 0.44) }
            }
            SequentialAnimation on scale {
              running: true
              loops: Animation.Infinite
              NumberAnimation { from: 0.7; to: 1.25; duration: pop.cycle; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.7; duration: pop.cycle; easing.type: Easing.InOutSine }
            }
          }

          Pop {
            width: plate.width * 0.26; height: width
            color: "#ffb02e"
            x: plate.width * 0.20; y: plate.height * 0.16
            cycle: 31000; peak: 0.55; offset: 2000
          }
          Pop {
            width: plate.width * 0.22; height: width
            color: "#ff5f8f"
            x: plate.width * 0.52; y: plate.height * 0.44
            cycle: 43000; peak: 0.45; offset: 13000
          }
          Pop {
            width: plate.width * 0.24; height: width
            color: "#3fc8f0"
            x: plate.width * 0.14; y: plate.height * 0.52
            cycle: 37000; peak: 0.40; offset: 25000
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
            opacity: 0.12
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

        // Film grain, the same tile and the same trick the weather panel uses:
        // drawn at 2x and scaled to 0.5 so each speck lands near a single
        // device pixel rather than a chunky 2px dot on HiDPI. Over everything,
        // mark included, so the frame reads as one exposure instead of a logo
        // sitting on a gradient. It also breaks up the last of the banding the
        // blur leaves behind.
        // Two continuous-tone tiles, one lightening and one darkening, because
        // real grain moves both ways — a white-only overlay just fogs the frame.
        // The weather panel's tile is bilevel: specks are hard on or off with no
        // midtone, which is what read as pixelated once it was scaled.
        //
        // Drawn at 3x and scaled to a third. This display runs at
        // devicePixelRatio 1.5, so a texel at 1 logical px lands on 1.5 device
        // px and reads as a dot; at a third it sits under a single device pixel,
        // and smoothing is on because at that size hard texel edges are the
        // pixelation rather than the cure for it.
        Repeater {
          model: [
            { src: "grain-light.png", weight: 0.85 },
            { src: "grain-dark.png", weight: 0.70 }
          ]
          Image {
            required property var modelData
            x: 0
            y: 0
            width: stage.width * 3
            height: stage.height * 3
            transformOrigin: Item.TopLeft
            scale: 1 / 3
            source: Qt.resolvedUrl(modelData.src)
            fillMode: Image.Tile
            opacity: modelData.weight
            smooth: true
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
